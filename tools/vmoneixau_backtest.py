"""
Approximate Python backtest of vMoneixau_EA logic.

IMPORTANT DATA CAVEAT: the only historical data available here is M15 OHLC
(xau_m15.csv). The real EA uses genuine H4 and M5 timeframes. Here:
  - H4 is built by resampling M15 -> H4 (this is faithful, no approximation).
  - "M5" (the LTF zone/entry layer) is approximated using the RAW M15 bars
    themselves (NOT a true M5 series) -- lookback/period parameters below are
    time-scaled to cover roughly the same real-world duration as the EA's M5
    settings, but the bar-by-bar granularity is 3x coarser than real M5. This
    means: swing points, zone touches, and the candle-close breakout trigger
    are all less precise than what the real EA sees intraday. Treat every
    number from this script as a rough directional sanity check, not a
    reliable performance estimate. Real validation = MT5 Strategy Tester with
    true M5 data, which only the user can run.
"""
import pandas as pd
import numpy as np

PATH = "/tmp/claude-0/-home-user-xauCOD/b475e5f0-5e70-5d19-af32-d30e5f487d46/scratchpad/xau_m15.csv"
POINT = 0.01
START_BALANCE = 1000.0
LOT = 0.01
DOLLAR_PER_POINT = 0.01  # 0.01 lot

# --- Step 1: H4 zones + swing structure ---
H4_LEG_BARS = 3
H4_LOOKBACK_BARS = 150          # ~25 days of H4
H4_CLUSTER_PTS = 300
H4_MIN_TOUCHES = 2
ZONE_PROXIMITY_PTS = 400        # widened from 150 -- see diagnostic: median gap to nearest zone was 1622pts
MAX_RANGE_WIDTH_PTS = 3000      # NEW: only trade when support/resistance are a genuinely tight range
                                 # (gold trended hard this year -- median H4 "range" width was 7564pts,
                                 # i.e. usually NOT a real range at all, just distant old levels)
SWING_CONFIRM_COUNT = 2

# --- Step 2: session window + MA filter ---
SESSION_START_HOUR = 16
SESSION_START_MIN = 30
SESSION_WINDOW_MIN = 600        # widened from 240 -- was cutting ~82% of remaining candidates
SKIP_FIRST_CANDLE = True
MA_PERIOD_M15_PROXY = 17   # time-scaled from "50 on real M5" (50*5min = 250min =~ 17 M15 bars)

# --- Step 3-4: LTF ("M5"-proxied-by-M15) zones + breakout entry ---
LTF_LEG_BARS = 2
LTF_LOOKBACK_BARS = 50      # time-scaled from "150 on real M5" (150*5=750min =~ 50 M15 bars)
LTF_CLUSTER_PTS = 80
LTF_MIN_TOUCHES = 2

SL_BUFFER_PTS = 50
TP_AT_OPPOSITE_ZONE_PCT = 80.0
MAX_HOLD_MINUTES = 90
MAX_HOLD_BARS_M15 = max(1, MAX_HOLD_MINUTES // 15)

# --- v5.4: don't enter against a clear immediate run of candles against the
# trade direction (this exact bug reported: "4 red candles in a row, then it
# opened long"). Lookback is in M15-proxy bars (coarser than the real EA's
# true M5 candles).
REQUIRE_MOMENTUM_AGREE = True
MOMENTUM_LOOKBACK = 4

# --- New: TP/SL corridor + stall-based best-profit banking (by request) ---
MIN_TP_PTS = 50
MAX_TP_PTS = 1000
MAX_SL_PTS = 2500
STALL_UPPER_REF_PTS = 800   # "прыгает от 50 до 800"
STALL_MIN_MINUTES = 5       # required stall time when profit is near STALL_UPPER_REF_PTS (take it fast)
STALL_MAX_MINUTES = 30      # required stall time when profit is near MIN_TP_PTS (be patient)
STALL_EPSILON_PTS = 20      # noise tolerance for "new peak"


def load_m15():
    df = pd.read_csv(PATH)
    df['datetime'] = pd.to_datetime(df['datetime'], format='%Y.%m.%d %H:%M')
    df = df.sort_values('datetime').reset_index(drop=True)
    return df


def resample_h4(m15):
    h4 = m15.set_index('datetime')[['open', 'high', 'low', 'close']].resample('4h').agg(
        {'open': 'first', 'high': 'max', 'low': 'min', 'close': 'last'}).dropna().reset_index()
    return h4


def detect_swings(df, leg, lookback_end_idx):
    """Fractal swing detection over df[:lookback_end_idx] (exclusive of the last `leg` bars
    to avoid lookahead). Returns list of dicts sorted by time ascending."""
    highs = df['high'].values
    lows = df['low'].values
    opens = df['open'].values
    closes = df['close'].values
    times = df['datetime'].values

    swings = []
    start = max(leg, lookback_end_idx - 100000)
    end = lookback_end_idx - leg  # need `leg` bars after for confirmation
    for i in range(start, max(start, end)):
        h = highs[i]; l = lows[i]
        is_high = all(highs[i-k] <= h for k in range(1, leg+1)) and all(highs[i+k] <= h for k in range(1, leg+1))
        is_low = all(lows[i-k] >= l for k in range(1, leg+1)) and all(lows[i+k] >= l for k in range(1, leg+1))
        if is_high:
            swings.append(dict(time=times[i], price=h, body_edge=max(opens[i], closes[i]), is_high=True))
        if is_low:
            swings.append(dict(time=times[i], price=l, body_edge=min(opens[i], closes[i]), is_high=False))
    swings.sort(key=lambda s: s['time'])
    return swings


def cluster_zones(swings, cluster_pts, min_touches):
    # Matches vMoneixau_EA.mq5 fix: compare new touches against the zone's
    # ANCHOR (first swing that formed it), not its current (already-widened)
    # center -- otherwise slow price drift chain-merges distinct levels into
    # one runaway-wide "zone".
    cluster_dist = cluster_pts * POINT
    zones = []  # each: {lo, hi, touches, is_resistance, anchor}
    for s in swings:
        matched = False
        for z in zones:
            if z['is_resistance'] != s['is_high']:
                continue
            if abs(s['price'] - z['anchor']) <= cluster_dist:
                if s['is_high']:
                    z['hi'] = max(z['hi'], s['price'])
                    z['lo'] = min(z['lo'], s['body_edge'])
                else:
                    z['lo'] = min(z['lo'], s['price'])
                    z['hi'] = max(z['hi'], s['body_edge'])
                z['touches'] += 1
                matched = True
                break
        if not matched:
            if s['is_high']:
                zones.append(dict(lo=s['body_edge'], hi=s['price'], touches=1, is_resistance=True, anchor=s['price']))
            else:
                zones.append(dict(lo=s['price'], hi=s['body_edge'], touches=1, is_resistance=False, anchor=s['price']))
    return [z for z in zones if z['touches'] >= min_touches]


def get_active_range(zones, cur_price):
    res = None; sup = None
    for z in zones:
        if z['is_resistance'] and z['lo'] > cur_price:
            if res is None or z['lo'] < res['lo']:
                res = z
        if not z['is_resistance'] and z['hi'] < cur_price:
            if sup is None or z['hi'] > sup['hi']:
                sup = z
    return res, sup


def swing_trend_bias(swings, confirm_count):
    # Bounded scan window (matches EA fix): don't let highs/lows come from
    # arbitrarily distant, temporally-incoherent stretches of history.
    window = swings[-(confirm_count * 6):] if len(swings) > confirm_count * 6 else swings
    highs = [s['price'] for s in reversed(window) if s['is_high']][:confirm_count]
    lows = [s['price'] for s in reversed(window) if not s['is_high']][:confirm_count]
    if len(highs) < confirm_count or len(lows) < confirm_count:
        return 0
    asc_highs = all(highs[i] > highs[i+1] for i in range(confirm_count-1))
    desc_highs = all(highs[i] < highs[i+1] for i in range(confirm_count-1))
    asc_lows = all(lows[i] > lows[i+1] for i in range(confirm_count-1))
    desc_lows = all(lows[i] < lows[i+1] for i in range(confirm_count-1))
    if asc_highs and asc_lows:
        return 1
    if desc_highs and desc_lows:
        return -1
    return 0


def run_backtest():
    m15 = load_m15()
    h4 = resample_h4(m15)

    closes = m15['close'].values
    opens = m15['open'].values
    highs = m15['high'].values
    lows = m15['low'].values
    times = m15['datetime']
    n = len(m15)

    ma = m15['close'].rolling(MA_PERIOD_M15_PROXY).mean().values

    h4_times = h4['datetime'].values

    trades = []
    open_trade = None  # dict with direction, entry, sl, tp, entry_idx

    last_h4_idx_used = -1
    h4_zones = []
    h4_swings = []
    ltf_zones = []

    warmup = max(H4_LEG_BARS*20, LTF_LOOKBACK_BARS + LTF_LEG_BARS + 5, MA_PERIOD_M15_PROXY + 5)

    for i in range(warmup, n - 1):
        cur_time = times.iloc[i]

        # --- manage open trade first ---
        if open_trade is not None:
            hi = highs[i]; lo = lows[i]
            direction = open_trade['direction']
            entry = open_trade['entry']
            exit_reason = None
            pnl_pts = None
            if direction == 1:
                if lo <= open_trade['sl']:
                    pnl_pts = (open_trade['sl'] - entry) / POINT
                    exit_reason = 'SL'
                elif hi >= open_trade['tp']:
                    pnl_pts = (open_trade['tp'] - entry) / POINT
                    exit_reason = 'TP'
            else:
                if hi >= open_trade['sl']:
                    pnl_pts = (entry - open_trade['sl']) / POINT
                    exit_reason = 'SL'
                elif lo <= open_trade['tp']:
                    pnl_pts = (entry - open_trade['tp']) / POINT
                    exit_reason = 'TP'

            # --- Stall-based best-profit banking (by request): "if it rose to at
            # least +50 and bounces between 50-800, close in profit if price
            # stalls for 5-30 minutes -- take the best available take by
            # situation." Required stall time interpolates: patient (30min) near
            # the low end (+50pts), quick (5min) near the high end (+800pts) --
            # the more profit banked, the less patience before locking it in. ---
            if exit_reason is None:
                close_profit_pts = ((closes[i] - entry) if direction == 1 else (entry - closes[i])) / POINT
                if close_profit_pts > open_trade['peak_pts'] + STALL_EPSILON_PTS:
                    open_trade['peak_pts'] = close_profit_pts
                    open_trade['peak_bar'] = i
                if close_profit_pts >= MIN_TP_PTS:
                    frac = np.clip((close_profit_pts - MIN_TP_PTS) / (STALL_UPPER_REF_PTS - MIN_TP_PTS), 0.0, 1.0)
                    required_minutes = STALL_MAX_MINUTES + frac * (STALL_MIN_MINUTES - STALL_MAX_MINUTES)
                    stalled_bars = i - open_trade['peak_bar']
                    if stalled_bars * 15 >= required_minutes:
                        pnl_pts = close_profit_pts
                        exit_reason = 'STALL'

            if exit_reason is None and (i - open_trade['entry_idx']) >= MAX_HOLD_BARS_M15:
                # time exit at this bar's close
                if direction == 1:
                    pnl_pts = (closes[i] - entry) / POINT
                else:
                    pnl_pts = (entry - closes[i]) / POINT
                exit_reason = 'TIME'
            if exit_reason is not None:
                trades.append(dict(entry_time=open_trade['entry_time'], direction=direction,
                                    pnl_pts=pnl_pts, exit_reason=exit_reason))
                open_trade = None
            continue  # one trade at a time; don't look for new entries while one is open

        # --- Step 1: refresh H4 zones once per new H4 bar ---
        h4_idx = np.searchsorted(h4_times, np.datetime64(cur_time), side='right') - 1
        if h4_idx > last_h4_idx_used and h4_idx >= H4_LEG_BARS * 2:
            last_h4_idx_used = h4_idx
            lookback_start = max(0, h4_idx - H4_LOOKBACK_BARS)
            h4_swings = detect_swings(h4.iloc[lookback_start:h4_idx+1].reset_index(drop=True),
                                       H4_LEG_BARS, h4_idx - lookback_start + 1)
            h4_zones = cluster_zones(h4_swings, H4_CLUSTER_PTS, H4_MIN_TOUCHES)

        cur_price = closes[i]
        res, sup = get_active_range(h4_zones, cur_price)
        if res is None or sup is None:
            continue
        if (res['lo'] - sup['hi']) / POINT > MAX_RANGE_WIDTH_PTS:
            continue  # not a genuine tight range -- just two distant old levels

        near_support = (cur_price >= sup['lo']) and ((cur_price - sup['hi']) / POINT <= ZONE_PROXIMITY_PTS)
        near_resistance = (cur_price <= res['hi']) and ((res['lo'] - cur_price) / POINT <= ZONE_PROXIMITY_PTS)
        if not (near_support or near_resistance):
            continue

        swing_bias = swing_trend_bias(h4_swings, SWING_CONFIRM_COUNT)

        ma_v = ma[i]
        if np.isnan(ma_v):
            continue
        ma_long = cur_price > ma_v
        ma_short = cur_price < ma_v

        want_long = near_support and (swing_bias >= 0) and ma_long
        want_short = near_resistance and (swing_bias <= 0) and ma_short
        if not (want_long or want_short):
            continue

        # --- Step 2: session window ---
        dt = cur_time
        cur_hm = dt.hour * 60 + dt.minute
        start_hm = SESSION_START_HOUR * 60 + SESSION_START_MIN
        end_hm = start_hm + SESSION_WINDOW_MIN
        if not (start_hm <= cur_hm < end_hm):
            continue
        if SKIP_FIRST_CANDLE and cur_hm < start_hm + 15:
            continue

        # --- Step 3: LTF zones (M15-as-M5-proxy), refreshed each bar for simplicity ---
        ltf_start = max(0, i - LTF_LOOKBACK_BARS)
        ltf_df = m15.iloc[ltf_start:i+1].reset_index(drop=True)
        ltf_swings = detect_swings(ltf_df, LTF_LEG_BARS, len(ltf_df))
        ltf_zones = cluster_zones(ltf_swings, LTF_CLUSTER_PTS, LTF_MIN_TOUCHES)

        # --- Step 4: breakout with confirmed close ---
        close_now = closes[i]
        close_prev = closes[i-1]
        triggered = False
        if want_long:
            for z in ltf_zones:
                if z['is_resistance'] and close_now > z['hi'] and close_prev <= z['hi']:
                    triggered = True
                    break
            direction = 1
        else:
            for z in ltf_zones:
                if not z['is_resistance'] and close_now < z['lo'] and close_prev >= z['lo']:
                    triggered = True
                    break
            direction = -1

        if triggered and REQUIRE_MOMENTUM_AGREE:
            # Majority rule (matches EA fix): "one red candle among a bunch of
            # green" must NOT be enough to green-light a short -- require a
            # real bullish/bearish majority in the trade's favor, not just
            # "not literally all candles against".
            bull_n = 0; bear_n = 0
            for shift in range(1, MOMENTUM_LOOKBACK + 1):
                o = opens[i - shift + 1]
                c = closes[i - shift + 1]
                if c > o:
                    bull_n += 1
                elif c < o:
                    bear_n += 1
            has_majority = (bull_n > bear_n) if direction == 1 else (bear_n > bull_n)
            if not has_majority:
                triggered = False

        if not triggered:
            continue

        entry_i = i + 1
        entry_price = opens[entry_i]
        if direction == 1:
            sl_pts_raw = (entry_price - (sup['lo'] - SL_BUFFER_PTS * POINT)) / POINT
            sl_pts = min(sl_pts_raw, MAX_SL_PTS)
            sl = entry_price - sl_pts * POINT
            dist_to_res = res['lo'] - entry_price
            if dist_to_res <= 0:
                continue
            tp_pts_raw = (dist_to_res * (TP_AT_OPPOSITE_ZONE_PCT / 100.0)) / POINT
            tp_pts = np.clip(tp_pts_raw, MIN_TP_PTS, MAX_TP_PTS)
            tp = entry_price + tp_pts * POINT
        else:
            sl_pts_raw = ((res['hi'] + SL_BUFFER_PTS * POINT) - entry_price) / POINT
            sl_pts = min(sl_pts_raw, MAX_SL_PTS)
            sl = entry_price + sl_pts * POINT
            dist_to_sup = entry_price - sup['hi']
            if dist_to_sup <= 0:
                continue
            tp_pts_raw = (dist_to_sup * (TP_AT_OPPOSITE_ZONE_PCT / 100.0)) / POINT
            tp_pts = np.clip(tp_pts_raw, MIN_TP_PTS, MAX_TP_PTS)
            tp = entry_price - tp_pts * POINT

        if direction == 1 and not (sl < entry_price < tp):
            continue
        if direction == -1 and not (tp < entry_price < sl):
            continue

        open_trade = dict(direction=direction, entry=entry_price, sl=sl, tp=tp,
                           entry_idx=entry_i, entry_time=times.iloc[entry_i],
                           peak_pts=0.0, peak_bar=entry_i)

    return pd.DataFrame(trades)


if __name__ == '__main__':
    res = run_backtest()
    print(f"Всего сделок: {len(res)}")
    if len(res) == 0:
        print("Сигналов не найдено с текущими настройками (возможно, слишком строгие фильтры).")
    else:
        res['pnl_usd'] = res['pnl_pts'] * DOLLAR_PER_POINT
        wins = res[res['pnl_pts'] > 0]
        losses = res[res['pnl_pts'] < 0]
        print(f"Win: {len(wins)} | Loss: {len(losses)} | Winrate: {100*len(wins)/len(res):.1f}%")
        print(f"Средняя победа: ${wins['pnl_usd'].mean():.2f}" if len(wins) else "нет побед")
        print(f"Средний убыток: ${losses['pnl_usd'].mean():.2f}" if len(losses) else "нет убытков")
        print(f"PnL: ${res['pnl_usd'].sum():.2f} (лот {LOT}), баланс {START_BALANCE}->{START_BALANCE+res['pnl_usd'].sum():.2f}")
        print(res['exit_reason'].value_counts())
        print(res.head(20).to_string())
        res.to_csv('/tmp/claude-0/-home-user-xauCOD/b475e5f0-5e70-5d19-af32-d30e5f487d46/scratchpad/vmoneixau_trades.csv', index=False)
