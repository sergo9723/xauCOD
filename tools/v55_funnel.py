"""
v5.5 entry-funnel diagnostic (Python mirror of vMoneixau_EA v5.5).

Same data caveat as vmoneixau_backtest.py: only M15 history exists here.
H4 = faithful resample. M15 confirmation layer = FAITHFUL (native M15).
"M5" entry layer = approximated by M15 bars (3x coarser) -> breakout/momentum
counts are rough. Funnel percentages are directional, not exact.
"""
import pandas as pd
import numpy as np
from vmoneixau_backtest import (load_m15, resample_h4, detect_swings,
                                cluster_zones, get_active_range,
                                swing_trend_bias, POINT)

# --- v5.5 parameters (mirroring the .mq5 defaults) ---
H4_LEG, H4_LOOKBACK, H4_CLUSTER, H4_TOUCH = 3, 150, 300, 2
ZONE_PROX = 700
MAX_RANGE_W = 0   # 0 = disabled
SWING_CONFIRM = 2

SESS_H, SESS_M, SESS_WIN = 16, 30, 60          # narrow NY-open entry window
MA_PERIOD = 17                                  # ~ MA(50) on M5, time-scaled
MA_BUFFER_PTS = 20
MA_SLOPE_BARS = 2                               # ~ 5 M5 bars, time-scaled

M15_LEG, M15_LOOKBACK, M15_CLUSTER, M15_TOUCH = 2, 150, 150, 2
M15_PROX = 300

LTF_LEG, LTF_LOOKBACK, LTF_CLUSTER, LTF_TOUCH = 2, 50, 80, 2  # "M5" proxied
MOMENTUM_LOOKBACK = 4

SIDEWAYS_PAUSE_MIN = 45

MIN_TP, MAX_TP, MAX_SL, SL_BUF = 50, 1000, 2500, 50
TP_OPP_PCT = 80.0
MAX_HOLD_BARS = 6      # 90 min / 15
STALL_MAX_MIN = 12     # faster banking of small profit (was 30)
LOCK_ACTIVATE, LOCK_GIVEBACK, LOCK_FLOOR = 70, 25, 50  # profit-lock
USE_MA_FILTER = False      # v5.53: MA filter contradicts fade -> OFF by default
REQUIRE_SWING_BIAS = False # v5.53: swing-bias requirement -> OFF by default
EOD_H, EOD_M = 22, 0

FUNNEL_KEYS = ["bars_in_window", "after_pause", "have_h4_range", "width_ok",
               "near_zone", "bias_ok", "ma_dir_ok", "m15_confirm",
               "ltf_breakout", "momentum_ok", "TRADES"]


def run(date_from=None, date_to=None, label=""):
    m15 = load_m15()
    if date_from:
        pass  # keep full history for lookbacks; filter at decision time
    h4 = resample_h4(m15)
    closes = m15['close'].values
    opens = m15['open'].values
    highs = m15['high'].values
    lows = m15['low'].values
    times = m15['datetime']
    ma = m15['close'].rolling(MA_PERIOD).mean().values

    funnel = {k: 0 for k in FUNNEL_KEYS}
    trades = []
    pause_until = pd.Timestamp.min
    last_h4_idx = -1
    h4_zones, bias = [], 0
    m15_zone_cache_idx = -1
    m15_zones = []
    open_pos = None  # dict(direction, entry, sl, tp, open_i)

    h4_times = h4['datetime'].values

    for i in range(max(MA_PERIOD, 300), len(m15) - 1):
        t = times.iloc[i]
        if date_from is not None and t < date_from:
            continue
        if date_to is not None and t > date_to:
            break

        # --- manage open position on this bar (rough) ---
        if open_pos is not None:
            d = open_pos['d']
            hit_sl = (lows[i] <= open_pos['sl']) if d == 1 else (highs[i] >= open_pos['sl'])
            hit_tp = (highs[i] >= open_pos['tp']) if d == 1 else (lows[i] <= open_pos['tp'])
            eod = (t.hour, t.minute) >= (EOD_H, EOD_M)
            timeout = (i - open_pos['i']) >= MAX_HOLD_BARS
            # profit-lock (bar-resolution approximation): lock peak was set from
            # PRIOR bars; if activated and this bar trades back to the floor,
            # bank at the floor before SL/timeout can act.
            lp = open_pos.get('lockpeak', 0.0)
            locked = False
            if lp >= LOCK_ACTIVATE:
                floor = max(LOCK_FLOOR, lp - LOCK_GIVEBACK)
                floor_price = open_pos['entry'] + floor * POINT * d
                reached_floor = (lows[i] <= floor_price) if d == 1 else (highs[i] >= floor_price)
                if reached_floor and not hit_tp:
                    trades.append(dict(t=t, d=d, exit='LOCK', pts=floor)); open_pos = None; locked = True
            if locked:
                pass
            elif hit_sl:
                pnl = -abs(open_pos['entry'] - open_pos['sl']) / POINT
                trades.append(dict(t=t, d=open_pos['d'], exit='SL', pts=pnl)); open_pos = None
            elif hit_tp:
                pnl = abs(open_pos['tp'] - open_pos['entry']) / POINT
                trades.append(dict(t=t, d=open_pos['d'], exit='TP', pts=pnl)); open_pos = None
            elif eod or timeout:
                pnl = (closes[i] - open_pos['entry']) / POINT * d
                trades.append(dict(t=t, d=d, exit='EOD' if eod else 'TIME', pts=pnl)); open_pos = None
            if open_pos is not None:
                fav = (highs[i] - open_pos['entry']) / POINT if d == 1 else (open_pos['entry'] - lows[i]) / POINT
                open_pos['lockpeak'] = max(open_pos.get('lockpeak', 0.0), fav)

        # --- H4 recalc on each new completed H4 bar ---
        h4_idx = np.searchsorted(h4_times, np.datetime64(t)) - 1
        if h4_idx != last_h4_idx and h4_idx >= H4_LEG + 5:
            last_h4_idx = h4_idx
            sw = detect_swings(h4, H4_LEG, h4_idx)
            sw = sw[-(H4_LOOKBACK):]
            h4_zones = cluster_zones(sw, H4_CLUSTER, H4_TOUCH)
            bias = swing_trend_bias(sw, SWING_CONFIRM)
            cur_p = closes[i]
            res0, sup0 = get_active_range(h4_zones, cur_p)
            if res0 is None or sup0 is None:
                j0 = h4_idx
                if j0 >= 18:
                    hh0 = h4['high'].values[j0-18:j0].max()
                    ll0 = h4['low'].values[j0-18:j0].min()
                    if hh0 > cur_p > ll0:
                        res0 = sup0 = True  # fallback frame exists -> no pause
            if res0 is None or sup0 is None:
                pause_until = t + pd.Timedelta(minutes=SIDEWAYS_PAUSE_MIN)

        # --- session window (16:30 + 60min, skip first candle) ---
        hm = t.hour * 60 + t.minute
        start_hm = SESS_H * 60 + SESS_M
        if not (start_hm < hm < start_hm + SESS_WIN):  # strict > start = skip first
            continue
        funnel["bars_in_window"] += 1
        if open_pos is not None:
            continue

        if t < pause_until:
            continue
        funnel["after_pause"] += 1

        cur_p = closes[i]
        res, sup = get_active_range(h4_zones, cur_p)
        if res is None or sup is None:
            # HL-fallback frame: max/min of last 18 completed H4 bars (~3 days)
            j = np.searchsorted(h4_times, np.datetime64(t)) - 1
            if j >= 18:
                hh = h4['high'].values[j-18:j].max()
                ll = h4['low'].values[j-18:j].min()
                if hh > cur_p > ll:
                    zw = H4_CLUSTER * POINT
                    res = dict(lo=hh - zw, hi=hh, touches=1, is_resistance=True, anchor=hh)
                    sup = dict(lo=ll, hi=ll + zw, touches=1, is_resistance=False, anchor=ll)
        if res is None or sup is None:
            continue
        funnel["have_h4_range"] += 1

        width = (res['lo'] - sup['hi']) / POINT
        if MAX_RANGE_W > 0 and width > MAX_RANGE_W:
            continue
        funnel["width_ok"] += 1

        near_sup = cur_p >= sup['lo'] and (cur_p - sup['hi']) / POINT <= ZONE_PROX
        near_res = cur_p <= res['hi'] and (res['lo'] - cur_p) / POINT <= ZONE_PROX
        if not (near_sup or near_res):
            continue
        funnel["near_zone"] += 1

        want_long_side = near_sup and (bias >= 0 if REQUIRE_SWING_BIAS else True)
        want_short_side = near_res and (bias <= 0 if REQUIRE_SWING_BIAS else True)
        if not (want_long_side or want_short_side):
            continue
        funnel["bias_ok"] += 1

        # MA buffer + slope
        ma_now, ma_prev = ma[i], ma[i - MA_SLOPE_BARS]
        if np.isnan(ma_now) or np.isnan(ma_prev):
            continue
        if USE_MA_FILTER:
            ma_long = cur_p > ma_now + MA_BUFFER_PTS * POINT
            ma_short = cur_p < ma_now - MA_BUFFER_PTS * POINT
        else:
            ma_long = ma_short = True   # MA filter OFF (v5.53): fade carries direction
        want_long = want_long_side and ma_long
        want_short = want_short_side and ma_short
        if not (want_long or want_short):
            continue
        funnel["ma_dir_ok"] += 1

        # M15 confirmation layer (native M15 -> faithful)
        if i != m15_zone_cache_idx:
            sw15 = detect_swings(m15.iloc[max(0, i - M15_LOOKBACK - M15_LEG):i + 1].reset_index(drop=True),
                                 M15_LEG, min(M15_LOOKBACK, i))
            m15_zones = cluster_zones(sw15, M15_CLUSTER, M15_TOUCH)
            m15_zone_cache_idx = i
        # v5.5 fix: nearest zone of matching type within proximity, INCLUDING
        # the zone price currently sits inside (old strict below/above scan
        # excluded exactly the zone we bounce from).
        conf_sup = conf_res = False
        for z in m15_zones:
            if z['touches'] < M15_TOUCH:
                continue
            if cur_p < z['lo']:
                d = (z['lo'] - cur_p) / POINT
            elif cur_p > z['hi']:
                d = (cur_p - z['hi']) / POINT
            else:
                d = 0.0
            if d > M15_PROX:
                continue
            if z['is_resistance']:
                conf_res = True
            else:
                conf_sup = True
        want_long = want_long and conf_sup
        want_short = want_short and conf_res
        if not (want_long or want_short):
            continue
        funnel["m15_confirm"] += 1

        # LTF breakout ("M5" proxied by M15): close beyond an LTF zone edge
        sub = m15.iloc[max(0, i - LTF_LOOKBACK - LTF_LEG):i + 1].reset_index(drop=True)
        swl = detect_swings(sub, LTF_LEG, len(sub) - 1)
        ltf_zones = cluster_zones(swl, LTF_CLUSTER, LTF_TOUCH)
        close_now, close_prev = closes[i], closes[i - 1]
        brk = 0
        if want_long:
            for z in ltf_zones:
                if z['is_resistance'] and close_now > z['hi'] >= close_prev:
                    brk = 1; break
        if want_short and brk == 0:
            for z in ltf_zones:
                if (not z['is_resistance']) and close_now < z['lo'] <= close_prev:
                    brk = -1; break
        if brk == 0:
            # simple-breakout fallback: close beyond extreme of prior bars
            # (6 M5 bars = 30 min ~= 2 M15 bars in this proxy)
            SB = 2
            if want_long and close_now > max(highs[i - SB:i]):
                brk = 1
            elif want_short and close_now < min(lows[i - SB:i]):
                brk = -1
        if brk == 0:
            continue
        funnel["ltf_breakout"] += 1

        # momentum majority over last 4 candles
        bull = sum(1 for k in range(i - MOMENTUM_LOOKBACK + 1, i + 1) if closes[k] > opens[k])
        bear = sum(1 for k in range(i - MOMENTUM_LOOKBACK + 1, i + 1) if closes[k] < opens[k])
        if (brk == 1 and not bull > bear) or (brk == -1 and not bear > bull):
            continue
        funnel["momentum_ok"] += 1

        # open trade at next bar open
        entry = opens[i + 1]
        if brk == 1:
            sl = max(entry - MAX_SL * POINT, sup['lo'] - SL_BUF * POINT)
            tp_pts = min(MAX_TP, max(MIN_TP, (res['lo'] - entry) / POINT * TP_OPP_PCT / 100.0))
            tp = entry + tp_pts * POINT
        else:
            sl = min(entry + MAX_SL * POINT, res['hi'] + SL_BUF * POINT)
            tp_pts = min(MAX_TP, max(MIN_TP, (entry - sup['hi']) / POINT * TP_OPP_PCT / 100.0))
            tp = entry - tp_pts * POINT
        open_pos = dict(d=brk, entry=entry, sl=sl, tp=tp, i=i + 1, lockpeak=0.0)
        funnel["TRADES"] += 1

    print(f"\n===== {label} =====")
    prev = None
    for k in FUNNEL_KEYS:
        pct = "" if prev in (None, 0) else f"  ({100.0*funnel[k]/prev:.1f}% of prev)"
        print(f"{k:16s}: {funnel[k]}{pct}")
        prev = funnel[k]
    if trades:
        df = pd.DataFrame(trades)
        print(f"trades: {len(df)} | wins {sum(df.pts>0)} | losses {sum(df.pts<0)} | net {df.pts.sum():.0f} pts")
        print(df.to_string(index=False))
    return funnel, trades


if __name__ == "__main__":
    run(pd.Timestamp("2026-06-01"), pd.Timestamp("2026-07-08"), "user's tester window: 2026-06-01..07-07")
    run(None, None, "FULL YEAR of available data")
