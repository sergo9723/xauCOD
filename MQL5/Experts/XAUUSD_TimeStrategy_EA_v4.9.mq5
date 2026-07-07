//+------------------------------------------------------------------+
//|              XAUUSD_TimeStrategy_EA v4.9 READABLE PANEL           |
//|                                                                  |
//|  CHANGELOG v4.9 — до 4 окон анализ→вход в сутки вместо 2         |
//|  (по запросу: часы 11:00, 12:00, 13:00, 14:00 все показали       |
//|  устойчивую прибыль в бэктесте v4.8, а не только пара 12→13).    |
//|                                                                  |
//|  АРХИТЕКТУРА: раньше SHORT и LONG были двумя отдельными,          |
//|  почти продублированными блоками кода (свой набор переменных,    |
//|  своя копия анализа фильтров). Теперь это массив из 4 "окон"      |
//|  (TradeWindow), каждое — направление + время анализа/входа +     |
//|  своё состояние. Общий цикл обрабатывает все окна одинаково —    |
//|  фильтры считаются один раз в CountFilters(direction,...) вместо |
//|  двух копий CountShortFilters/CountLongFilters.                  |
//|                                                                  |
//|  По умолчанию:                                                    |
//|  • SHORT#1: анализ 11:00-11:50 → вход 12:00                     |
//|  • SHORT#2: анализ 12:00-12:50 → вход 13:00                     |
//|  • LONG#1:  анализ 13:00-13:50 → вход 14:00                     |
//|  • LONG#2:  анализ 14:00-14:50 → вход 15:00                     |
//|  До 4 сделок в день вместо 2. TP=1000/SL=2500 (из v4.8) —        |
//|  общие на все окна, отдельно по окнам не настраиваются.          |
//|                                                                  |
//|  ВАЖНО ПРО MAGIC: каждое окно торгует под ОТДЕЛЬНЫМ под-magic    |
//|  (InpMagicNumber+0..3) — иначе "уже открыта позиция" от окна #1  |
//|  заблокировала бы вход окна #2 (SL=2500 может держать позицию    |
//|  открытой днями, а её направление — то же самое). Если помимо    |
//|  этого планируете НЕСКОЛЬКО ИНСТАНСОВ EA на разных графиках      |
//|  (см. v4.7), разносите InpMagicNumber между инстансами минимум   |
//|  на 10 (напр. 202500 и 202510), а не на 1 — иначе диапазоны      |
//|  +0..+3 у соседних инстансов пересекутся.                         |
//|                                                                  |
//|  Всё из v4.3-v4.8 сохранено без изменений: фильтр объёма,        |
//|  риск % от баланса, безубыток/частичное закрытие/трейлинг,       |
//|  проверка hedging-счёта, персистентная стоп-машина,              |
//|  минуты-от-полуночи для окон, опциональный H1-фильтр тренда.     |
//+------------------------------------------------------------------+
#property copyright   "Custom EA v4.9 READABLE PANEL — audited"
#property version     "4.90"
#property strict
#property description "XAUUSD Time EA v4.9 — до 4 окон анализ/вход в сутки (11-12-13-14ч)"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#define TRADE_WINDOWS 4  // SHORT#1, SHORT#2, LONG#1, LONG#2

CTrade        trade;
CPositionInfo posInfo;

//--- Входные параметры
input group "=== ИДЕНТИФИКАЦИЯ ==="
input int     InpMagicNumber      = 202507;  // База magic. Реально используется InpMagicNumber+0..3
                                              // (по одному под-magic на каждое из 4 окон). Если
                                              // планируете НЕСКОЛЬКО ИНСТАНСОВ EA — разносите базы
                                              // минимум на 10, чтобы диапазоны +0..+3 не пересекались.

input group "=== ТОРГОВЫЕ ПАРАМЕТРЫ ==="
input bool    InpUseFixedLot      = true;    // true=фикс.лот InpLotSize, false=риск % от баланса
input double  InpLotSize          = 0.01;
input double  InpRiskPct          = 1.0;     // % риска от баланса (если InpUseFixedLot=false)
input int     InpTakeProfit       = 1000;    // TP в пунктах, общий на все окна
input int     InpStopLoss         = 2500;    // SL в пунктах, общий на все окна

input group "=== ДИНАМИЧЕСКИЕ SL/TP ПО ATR (опционально) ==="
input bool    InpUseATRStops      = false;   // true = SL/TP считаются от ATR, а не фиксированно
input int     InpATRPeriod        = 14;
input double  InpATRSLMult        = 2.5;     // SL = ATR * множитель
input double  InpATRTPMult        = 0.8;     // TP = ATR * множитель

input group "=== УПРАВЛЕНИЕ ОТКРЫТОЙ ПОЗИЦИЕЙ (сокращение убытков) ==="
input bool    InpUseBreakEven        = true;
input int     InpBreakEvenTriggerPts = 300;  // профит в пунктах для переноса SL в БУ
input int     InpBreakEvenLockPts    = 50;   // сколько пунктов профита фиксируем
input bool    InpUsePartialClose     = true;
input double  InpPartialClosePct     = 50.0; // % объёма закрыть частично
input double  InpPartialCloseAtTPPct = 60.0; // на скольки % от TP делать частичное закрытие
input bool    InpUseTrailingStop     = true;
input int     InpTrailingStartPts    = 500;  // профит для начала трейлинга (после безубытка)
input int     InpTrailingStepPts     = 150;  // дистанция трейлинга от текущей цены

input group "=== ЗАЩИТА КАПИТАЛА ==="
input int     InpMaxConsecutiveLosses = 3;   // 0 = отключено; пауза до понедельника (на весь EA сразу)
input bool    InpRequireHedging       = true; // требовать hedging-счёт (иначе INIT_FAILED)

input group "=== ОКНО SHORT #1 (фейд роста цены → продажа) ==="
input int     InpShort1AnalysisHour   = 11;
input int     InpShort1AnalysisMinute = 0;
input int     InpShort1AnalysisEndMin = 50;
input int     InpShort1EntryHour      = 12;
input int     InpShort1EntryMinute    = 0;
input int     InpShort1EntryWindow    = 5;

input group "=== ОКНО SHORT #2 ==="
input int     InpShort2AnalysisHour   = 12;
input int     InpShort2AnalysisMinute = 0;
input int     InpShort2AnalysisEndMin = 50;
input int     InpShort2EntryHour      = 13;
input int     InpShort2EntryMinute    = 0;
input int     InpShort2EntryWindow    = 5;

input group "=== ОКНО LONG #1 (фейд падения цены → покупка) ==="
input int     InpLong1AnalysisHour    = 13;
input int     InpLong1AnalysisMinute  = 0;
input int     InpLong1AnalysisEndMin  = 50;
input int     InpLong1EntryHour       = 14;
input int     InpLong1EntryMinute     = 0;
input int     InpLong1EntryWindow     = 5;

input group "=== ОКНО LONG #2 ==="
input int     InpLong2AnalysisHour    = 14;
input int     InpLong2AnalysisMinute  = 0;
input int     InpLong2AnalysisEndMin  = 50;
input int     InpLong2EntryHour       = 15;
input int     InpLong2EntryMinute     = 0;
input int     InpLong2EntryWindow     = 5;

input group "=== ФИЛЬТРЫ ПОДТВЕРЖДЕНИЯ ==="
input int     InpMinScore          = 4;     // мин счёт фильтров (макс 6)
input double  InpMinPriceMovePct   = 0.15;  // мин движение % за окно
input double  InpRSIThresholdShort = 55.0;  // RSI для SHORT (выше)
input double  InpRSIThresholdLong  = 45.0;  // RSI для LONG (ниже)
input double  InpMinADX            = 18.0;  // мин ADX для входа
input int     InpEMA_Period        = 21;    // EMA на M15
input bool    InpUseH1TrendFilter  = false;  // true = фильтр EMA считать на H1, а не на M15

input group "=== ЗАЩИТНЫЕ ФИЛЬТРЫ ==="
input int     InpMaxSpread         = 80;
input bool    InpUseCalendar       = true;
input int     InpNewsBlockMins     = 30;

input group "=== ИНДИКАТОРЫ АНАЛИЗА ==="
input int     InpADXPeriod        = 14;
input int     InpRSIPeriod        = 14;
input int     InpVolPeriod        = 20;

input group "=== ОТОБРАЖЕНИЕ ==="
input bool    InpShowInfo          = true;
input int     InpPanelX            = 15;
input int     InpPanelY            = 30;
input int     InpPanelFontSize     = 11;
input string  InpPanelFontName     = "Consolas";
input color   InpColorTitle        = clrAqua;
input color   InpColorHeader       = clrGold;
input color   InpColorText         = clrWhite;
input color   InpColorGood         = clrLime;
input color   InpColorBad          = clrTomato;
input color   InpColorNeutral      = clrLightGray;
input color   InpColorWaiting      = clrYellow;
input bool    InpDarkBackground    = true;

//--- Окно анализ→вход (SHORT#1/SHORT#2/LONG#1/LONG#2) со своим состоянием
struct TradeWindow
{
   int    direction;      // -1 = SHORT (фейд роста), +1 = LONG (фейд падения)
   string label;
   int    analHour, analMinute, analEndMin;
   int    entryHour, entryMinute, entryWindow;
   // состояние на сегодня:
   bool   doneToday;
   bool   approved;
   bool   analysisActive;
   double analStartPrice;
   int    score;
   string filtersDetail;
};
TradeWindow g_win[TRADE_WINDOWS];

//--- Глобальные переменные
datetime g_last_day = 0;
int      g_magic    = 0; // реальное значение берётся из InpMagicNumber в OnInit

// Индикаторы
int      h_ma         = INVALID_HANDLE;  // EMA на M15
int      h_ma_h1      = INVALID_HANDLE;  // EMA на H1 (для InpUseH1TrendFilter)
int      h_adx        = INVALID_HANDLE;
int      h_rsi        = INVALID_HANDLE;
int      h_atr        = INVALID_HANDLE;

// Статистика (агрегирована по направлению, не по конкретному окну)
int      g_total_trades  = 0;
int      g_win_trades    = 0;
int      g_loss_trades   = 0;
double   g_total_profit  = 0.0;
int      g_short_count   = 0;
int      g_long_count    = 0;
int      g_short_wins    = 0;
int      g_long_wins     = 0;
int      g_short_skipped = 0;
int      g_long_skipped  = 0;

// Защита капитала — общая на весь EA (все окна сразу)
int      g_consecutive_losses = 0;
bool     g_trading_paused     = false;

ENUM_ORDER_TYPE_FILLING g_fillType = ORDER_FILLING_IOC;

string PANEL_PREFIX = "TimeRev_";

//--- Учёт PnL/управления по каждой позиции (нужно для частичных закрытий)
struct PosPnlEntry  { ulong posId; double pnl; };
struct PosMgmtState { ulong posId; bool beDone; bool partialDone; };
PosPnlEntry  g_posPnl[];
PosMgmtState g_posMgmt[];

//+------------------------------------------------------------------+
//| УТИЛИТЫ                                                          |
//+------------------------------------------------------------------+

string GVName(string suffix)
{
   return "XAUTimeEA_" + _Symbol + "_" + IntegerToString(g_magic) + "_" + suffix;
}

void PersistCircuitBreaker()
{
   GlobalVariableSet(GVName("ConsecLosses"), (double)g_consecutive_losses);
   GlobalVariableSet(GVName("Paused"), g_trading_paused ? 1.0 : 0.0);
}

// Под-magic для конкретного окна (SHORT#1..LONG#2) — каждое окно торгует под
// СВОИМ magic, чтобы "уже открыта позиция" от одного окна не блокировала вход
// другого окна того же направления (позиция может висеть днями при SL=2500).
int WindowMagic(int w)
{
   return g_magic + w;
}

ENUM_ORDER_TYPE_FILLING DetectFillType()
{
   uint f = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

int GetMinStopPoints()
{
   int sl = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int fz = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int mn = MathMax(sl, fz) + 10;
   return (mn < 30) ? 30 : mn;
}

double GetSpread()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return 0.0;
   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK)
         - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
}

double BufferVal(int handle, int bufIdx, int shift)
{
   if(handle == INVALID_HANDLE) return EMPTY_VALUE;
   double v[1];
   if(CopyBuffer(handle, bufIdx, shift, 1, v) != 1) return EMPTY_VALUE;
   return v[0];
}

bool VolumeConfirmed()
{
   int need = InpVolPeriod + 1;
   long vol[];
   ArraySetAsSeries(vol, true); // index 0 = самый свежий запрошенный бар (shift=1)
   if(CopyTickVolume(_Symbol, PERIOD_M5, 1, need, vol) != need) return false;

   long curVol = vol[0];
   long sum = 0;
   for(int i = 1; i < need; i++) sum += vol[i];
   double avg = (double)sum / (need - 1);

   return ((double)curVol > avg);
}

//+------------------------------------------------------------------+
//| Валидация лота                                                   |
//+------------------------------------------------------------------+
double NormalizeAndValidateLot(double rawLot, int direction, double price)
{
   if(rawLot <= 0.0) return 0.0;

   double lotMin   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotMax   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lotLimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(lotStep <= 0.0) lotStep = 0.01;
   if(lotMin  <= 0.0) lotMin  = 0.01;
   if(lotLimit > 0.0 && lotLimit < lotMax) lotMax = lotLimit;

   double lot = MathFloor(rawLot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);

   if(lot < lotMin)
   {
      Print("❌ Лот < lotMin");
      return 0.0;
   }
   if(lot > lotMax) lot = lotMax;

   double margin = 0.0;
   ENUM_ORDER_TYPE oType = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(oType, _Symbol, lot, price, margin))
   {
      Print("⚠️ WARN: OrderCalcMargin не сработал");
   }
   else
   {
      double free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(margin > free * 0.9)
      {
         Print("❌ Недостаточно маржи: $",
               DoubleToString(margin, 2), " > 90% свободной $",
               DoubleToString(free, 2));
         return 0.0;
      }
   }
   return lot;
}

double CalcLotByRisk(int slPoints)
{
   if(slPoints <= 0) return 0.0;
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt  = balance * InpRiskPct / 100.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickVal <= 0.0 || tickSize <= 0.0 || point <= 0.0) return 0.0;
   double valPerPt = tickVal / (tickSize / point);
   if(valPerPt <= 0.0) return 0.0;
   return riskAmt / (slPoints * valPerPt);
}

bool SpreadOK()
{
   double spread = GetSpread();
   if(spread > InpMaxSpread)
   {
      Print("⚠️ Спред=", DoubleToString(spread, 1),
            "pts > макс ", InpMaxSpread);
      return false;
   }
   return true;
}

bool CalendarClear()
{
   if(!InpUseCalendar) return true;
   datetime now = TimeCurrent();
   datetime t1 = (datetime)(now - 5 * 60);
   datetime t2 = (datetime)(now + (long)InpNewsBlockMins * 60);

   MqlCalendarValue v1[], v2[];
   int n1 = CalendarValueHistory(v1, t1, t2, "USD", NULL);
   int n2 = CalendarValueHistory(v2, t1, t2, "XAU", NULL);
   if(n1 < 0) n1 = 0;
   if(n2 < 0) n2 = 0;

   for(int i = 0; i < n1; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(v1[i].event_id, ev)) continue;
      if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
      {
         Print("📰 Блок USD: '", ev.name, "'");
         return false;
      }
   }
   for(int i = 0; i < n2; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(v2[i].event_id, ev)) continue;
      if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
      {
         Print("📰 Блок XAU: '", ev.name, "'");
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| ПОДСЧЁТ ФИЛЬТРОВ — единая функция для SHORT (direction=-1,        |
//| фейд роста цены) и LONG (direction=+1, фейд падения цены).        |
//| Раньше это были две почти идентичные функции (CountShortFilters/  |
//| CountLongFilters) — унифицировано, т.к. теперь окон 4, а не 2.    |
//+------------------------------------------------------------------+
int CountFilters(int direction, double startPrice, string &outDetail)
{
   int score = 0;
   string detail = "";

   double curPrice = SymbolInfoDouble(_Symbol, direction == -1 ? SYMBOL_BID : SYMBOL_ASK);

   // 1. Движение цены (вверх для SHORT-фейда, вниз для LONG-фейда)
   if(startPrice > 0.0)
   {
      double movePct = (curPrice - startPrice) / startPrice * 100.0;
      bool moveOk = (direction == -1) ? (movePct >= InpMinPriceMovePct) : (movePct <= -InpMinPriceMovePct);
      if(moveOk) { score++; detail += StringFormat("✅ Движ. %+.2f%% ", movePct); }
      else       detail += StringFormat("❌ Движ. %+.2f%% ", movePct);
   }
   else
   {
      detail += "❌ Движ. N/A ";
   }

   // 2. RSI (выше порога для SHORT, ниже порога для LONG)
   double rsi = BufferVal(h_rsi, 0, 1);
   bool rsiOk = (rsi != EMPTY_VALUE) &&
                ((direction == -1) ? (rsi > InpRSIThresholdShort) : (rsi < InpRSIThresholdLong));
   if(rsiOk) { score++; detail += StringFormat("✅ RSI %.1f ", rsi); }
   else       detail += StringFormat("❌ RSI %.1f ", rsi);

   // 3. ADX > порог (одинаково для обоих направлений)
   double adx = BufferVal(h_adx, 0, 1);
   if(adx != EMPTY_VALUE && adx > InpMinADX)
   {
      score++;
      detail += StringFormat("✅ ADX %.1f ", adx);
   }
   else
   {
      detail += StringFormat("❌ ADX %.1f ", adx);
   }

   // 4. Последняя свеча M5 (зелёная для SHORT-сетапа, красная для LONG-сетапа)
   double o1 = iOpen(_Symbol, PERIOD_M5, 1);
   double c1 = iClose(_Symbol, PERIOD_M5, 1);
   bool candleOk = (direction == -1) ? (c1 > o1) : (c1 < o1);
   if(candleOk) { score++; detail += (direction == -1) ? "✅ Свеча🟢 " : "✅ Свеча🔴 "; }
   else          detail += (direction == -1) ? "❌ Свеча🔴 " : "❌ Свеча🟢 ";

   // 5. Цена относительно EMA21 (M15, либо H1 если включён InpUseH1TrendFilter)
   double ema = InpUseH1TrendFilter ? BufferVal(h_ma_h1, 0, 1) : BufferVal(h_ma, 0, 1);
   bool emaOk = (ema != EMPTY_VALUE) && ((direction == -1) ? (curPrice > ema) : (curPrice < ema));
   string emaTag = InpUseH1TrendFilter ? "EMA(H1)" : "EMA";
   if(emaOk) { score++; detail += (direction == -1) ? ("✅ >" + emaTag + " ") : ("✅ <" + emaTag + " "); }
   else       detail += (direction == -1) ? ("❌ <" + emaTag + " ") : ("❌ >" + emaTag + " ");

   // 6. Объём выше среднего (одинаково для обоих направлений)
   if(VolumeConfirmed())
   {
      score++;
      detail += "✅ Vol↑ ";
   }
   else
   {
      detail += "❌ Vol↓ ";
   }

   outDetail = detail;
   return score;
}

//+------------------------------------------------------------------+
//| Проверка "уже открыта позиция от ЭТОГО конкретного окна"          |
//| (по под-magic окна, не по всему EA сразу — иначе окно #2 не      |
//| смогло бы войти, пока висит позиция от окна #1).                  |
//+------------------------------------------------------------------+
bool HasOpenPositionForWindow(int w)
{
   int wantMagic = WindowMagic(w);
   ENUM_POSITION_TYPE wantType = (g_win[w].direction == 1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol &&
            posInfo.Magic() == wantMagic &&
            posInfo.PositionType() == wantType)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Учёт PnL/управления по position_id (для частичных закрытий)      |
//+------------------------------------------------------------------+
int GetOrCreateMgmt(ulong posId)
{
   for(int i = 0; i < ArraySize(g_posMgmt); i++)
      if(g_posMgmt[i].posId == posId) return i;

   int n = ArraySize(g_posMgmt);
   ArrayResize(g_posMgmt, n + 1);
   g_posMgmt[n].posId       = posId;
   g_posMgmt[n].beDone      = false;
   g_posMgmt[n].partialDone = false;
   return n;
}

void RemovePosMgmt(ulong posId)
{
   for(int i = 0; i < ArraySize(g_posMgmt); i++)
   {
      if(g_posMgmt[i].posId == posId)
      {
         ArrayRemove(g_posMgmt, i, 1);
         return;
      }
   }
}

void AddPosPnl(ulong posId, double pnl)
{
   for(int i = 0; i < ArraySize(g_posPnl); i++)
   {
      if(g_posPnl[i].posId == posId)
      {
         g_posPnl[i].pnl += pnl;
         return;
      }
   }
   int n = ArraySize(g_posPnl);
   ArrayResize(g_posPnl, n + 1);
   g_posPnl[n].posId = posId;
   g_posPnl[n].pnl   = pnl;
}

double PopPosPnl(ulong posId)
{
   for(int i = 0; i < ArraySize(g_posPnl); i++)
   {
      if(g_posPnl[i].posId == posId)
      {
         double v = g_posPnl[i].pnl;
         ArrayRemove(g_posPnl, i, 1);
         return v;
      }
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Управление уже открытой позицией: безубыток / частичное          |
//| закрытие / трейлинг. Отбираем позиции ЛЮБОГО из наших 4 окон     |
//| (magic в диапазоне g_magic..g_magic+TRADE_WINDOWS-1).            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int    minStop = GetMinStopPoints();

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      long posMagic = posInfo.Magic();
      if(posMagic < g_magic || posMagic >= g_magic + TRADE_WINDOWS) continue;

      ulong ticket = posInfo.Ticket();
      ulong posId  = posInfo.Identifier();
      ENUM_POSITION_TYPE type = posInfo.PositionType();
      double openPrice = posInfo.PriceOpen();
      double curSL = posInfo.StopLoss();
      double curTP = posInfo.TakeProfit();
      double volume = posInfo.Volume();

      double profitPts = (type == POSITION_TYPE_BUY)
                          ? (bid - openPrice) / point
                          : (openPrice - ask) / point;

      int mIdx = GetOrCreateMgmt(posId);

      // --- Безубыток ---
      if(InpUseBreakEven && !g_posMgmt[mIdx].beDone &&
         profitPts >= InpBreakEvenTriggerPts)
      {
         int lockPts = MathMax(InpBreakEvenLockPts, minStop);
         double newSL = (type == POSITION_TYPE_BUY)
                         ? NormalizeDouble(openPrice + lockPts * point, digits)
                         : NormalizeDouble(openPrice - lockPts * point, digits);

         bool improves = (type == POSITION_TYPE_BUY)
                          ? (curSL < newSL)
                          : (curSL == 0.0 || curSL > newSL);

         if(improves)
         {
            if(trade.PositionModify(ticket, newSL, curTP))
            {
               g_posMgmt[mIdx].beDone = true;
               curSL = newSL;
               Print("🔒 Безубыток: тикет ", ticket, " SL→", DoubleToString(newSL, digits));
            }
         }
         else
            g_posMgmt[mIdx].beDone = true;
      }

      // --- Частичное закрытие ---
      if(InpUsePartialClose && !g_posMgmt[mIdx].partialDone)
      {
         double tpDist = (curTP != 0.0) ? MathAbs(curTP - openPrice) / point : InpTakeProfit;
         double target = tpDist * (InpPartialCloseAtTPPct / 100.0);

         if(profitPts >= target)
         {
            double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            double lotMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            if(lotStep <= 0.0) lotStep = 0.01;
            if(lotMin  <= 0.0) lotMin  = 0.01;

            double closeVol = MathFloor(volume * (InpPartialClosePct / 100.0) / lotStep) * lotStep;
            closeVol = NormalizeDouble(closeVol, 2);
            double remain = NormalizeDouble(volume - closeVol, 2);

            if(closeVol >= lotMin && remain >= lotMin)
            {
               if(trade.PositionClosePartial(ticket, closeVol))
               {
                  g_posMgmt[mIdx].partialDone = true;
                  Print("💰 Частичное закрытие: тикет ", ticket,
                        " объём ", DoubleToString(closeVol, 2));
               }
            }
            else
               g_posMgmt[mIdx].partialDone = true;
         }
      }

      // --- Трейлинг-стоп (только после безубытка) ---
      if(InpUseTrailingStop && g_posMgmt[mIdx].beDone &&
         profitPts >= InpTrailingStartPts)
      {
         int stepPts = MathMax(InpTrailingStepPts, minStop);
         if(type == POSITION_TYPE_BUY)
         {
            double newSL = NormalizeDouble(bid - stepPts * point, digits);
            if(newSL > curSL)
            {
               if(trade.PositionModify(ticket, newSL, curTP)) curSL = newSL;
            }
         }
         else
         {
            double newSL = NormalizeDouble(ask + stepPts * point, digits);
            if(curSL == 0.0 || newSL < curSL)
            {
               if(trade.PositionModify(ticket, newSL, curTP)) curSL = newSL;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Заполняет g_win[] из входных параметров (4 группы инпутов)        |
//+------------------------------------------------------------------+
void InitTradeWindows()
{
   g_win[0].direction = -1; g_win[0].label = "SHORT#1";
   g_win[0].analHour = InpShort1AnalysisHour; g_win[0].analMinute = InpShort1AnalysisMinute;
   g_win[0].analEndMin = InpShort1AnalysisEndMin;
   g_win[0].entryHour = InpShort1EntryHour; g_win[0].entryMinute = InpShort1EntryMinute;
   g_win[0].entryWindow = InpShort1EntryWindow;

   g_win[1].direction = -1; g_win[1].label = "SHORT#2";
   g_win[1].analHour = InpShort2AnalysisHour; g_win[1].analMinute = InpShort2AnalysisMinute;
   g_win[1].analEndMin = InpShort2AnalysisEndMin;
   g_win[1].entryHour = InpShort2EntryHour; g_win[1].entryMinute = InpShort2EntryMinute;
   g_win[1].entryWindow = InpShort2EntryWindow;

   g_win[2].direction = 1; g_win[2].label = "LONG#1";
   g_win[2].analHour = InpLong1AnalysisHour; g_win[2].analMinute = InpLong1AnalysisMinute;
   g_win[2].analEndMin = InpLong1AnalysisEndMin;
   g_win[2].entryHour = InpLong1EntryHour; g_win[2].entryMinute = InpLong1EntryMinute;
   g_win[2].entryWindow = InpLong1EntryWindow;

   g_win[3].direction = 1; g_win[3].label = "LONG#2";
   g_win[3].analHour = InpLong2AnalysisHour; g_win[3].analMinute = InpLong2AnalysisMinute;
   g_win[3].analEndMin = InpLong2AnalysisEndMin;
   g_win[3].entryHour = InpLong2EntryHour; g_win[3].entryMinute = InpLong2EntryMinute;
   g_win[3].entryWindow = InpLong2EntryWindow;

   for(int w = 0; w < TRADE_WINDOWS; w++)
   {
      g_win[w].doneToday = false;
      g_win[w].approved = false;
      g_win[w].analysisActive = false;
      g_win[w].analStartPrice = 0.0;
      g_win[w].score = 0;
      g_win[w].filtersDetail = "";
   }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   g_magic = InpMagicNumber;
   if(g_magic <= 0)
   {
      Print("❌ ERROR: InpMagicNumber должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_fillType = DetectFillType();
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(g_fillType);

   int minStop = GetMinStopPoints();

   if(InpStopLoss <= 0 || InpTakeProfit <= 0)
   {
      Print("❌ ERROR: SL/TP должны быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMinScore < 1 || InpMinScore > 6)
   {
      Print("❌ ERROR: InpMinScore должен быть 1-6");
      return INIT_PARAMETERS_INCORRECT;
   }

   InitTradeWindows();

   // Валидация каждого из 4 окон — раньше это были два продублированных
   // блока (для SHORT и LONG отдельно), теперь один цикл на все окна.
   for(int w = 0; w < TRADE_WINDOWS; w++)
   {
      if(g_win[w].analHour < 0 || g_win[w].analHour > 23 ||
         g_win[w].entryHour < 0 || g_win[w].entryHour > 23)
      {
         Print("❌ ERROR: часы окна ", g_win[w].label, " должны быть 0-23");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(g_win[w].analMinute < 0 || g_win[w].analMinute > 59 ||
         g_win[w].analEndMin < 0 || g_win[w].analEndMin > 59 ||
         g_win[w].entryMinute < 0 || g_win[w].entryMinute > 59)
      {
         Print("❌ ERROR: минуты окна ", g_win[w].label, " должны быть 0-59");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(g_win[w].entryWindow <= 0 || g_win[w].entryWindow > 60)
      {
         Print("❌ ERROR: EntryWindow окна ", g_win[w].label, " должен быть 1-60");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(g_win[w].analEndMin <= g_win[w].analMinute)
      {
         Print("❌ ERROR: AnalysisEndMin окна ", g_win[w].label, " должен быть > AnalysisMinute");
         return INIT_PARAMETERS_INCORRECT;
      }
      int analEndKey = g_win[w].analHour * 60 + g_win[w].analEndMin;
      int entryKey   = g_win[w].entryHour * 60 + g_win[w].entryMinute;
      if(entryKey <= analEndKey)
      {
         Print("❌ ERROR: вход окна ", g_win[w].label, " должен быть строго после конца анализа");
         return INIT_PARAMETERS_INCORRECT;
      }
   }

   if(InpMaxConsecutiveLosses < 0)
   {
      Print("❌ ERROR: InpMaxConsecutiveLosses не может быть отрицательным");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUsePartialClose && (InpPartialClosePct <= 0.0 || InpPartialClosePct >= 100.0))
   {
      Print("❌ ERROR: InpPartialClosePct должен быть в диапазоне (0,100)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUsePartialClose && InpPartialCloseAtTPPct <= 0.0)
   {
      Print("❌ ERROR: InpPartialCloseAtTPPct должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseBreakEven)
   {
      if(InpBreakEvenTriggerPts <= 0 || InpBreakEvenLockPts <= 0)
      {
         Print("❌ ERROR: InpBreakEvenTriggerPts и InpBreakEvenLockPts должны быть > 0");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(InpBreakEvenLockPts >= InpBreakEvenTriggerPts)
      {
         Print("❌ ERROR: InpBreakEvenLockPts должен быть МЕНЬШЕ InpBreakEvenTriggerPts ",
               "(иначе SL попытается встать за пределы текущей цены)");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(InpUseTrailingStop && (InpTrailingStartPts <= 0 || InpTrailingStepPts <= 0))
   {
      Print("❌ ERROR: InpTrailingStartPts и InpTrailingStepPts должны быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   ENUM_ACCOUNT_MARGIN_MODE marginMode =
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(InpRequireHedging && marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("❌ ERROR: счёт не в режиме hedging (", EnumToString(marginMode),
            "). Одновременные разнонаправленные позиции будут схлопываться. ",
            "Отключите InpRequireHedging только если понимаете последствия.");
      return INIT_PARAMETERS_INCORRECT;
   }

   h_ma    = iMA(_Symbol, PERIOD_M15, InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_ma_h1 = iMA(_Symbol, PERIOD_H1, InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   h_adx   = iADX(_Symbol, PERIOD_M15, InpADXPeriod);
   h_rsi   = iRSI(_Symbol, PERIOD_M15, InpRSIPeriod, PRICE_CLOSE);
   h_atr   = iATR(_Symbol, PERIOD_M15, InpATRPeriod);

   if(h_ma == INVALID_HANDLE || h_ma_h1 == INVALID_HANDLE || h_adx == INVALID_HANDLE ||
      h_rsi == INVALID_HANDLE || h_atr == INVALID_HANDLE)
   {
      Print("❌ Ошибка индикаторов");
      return INIT_FAILED;
   }

   double tmp[];
   CopyBuffer(h_ma, 0, 0, 300, tmp);
   CopyBuffer(h_ma_h1, 0, 0, 100, tmp);
   CopyBuffer(h_adx, 0, 0, 100, tmp);
   CopyBuffer(h_rsi, 0, 0, 100, tmp);
   CopyBuffer(h_atr, 0, 0, 100, tmp);

   g_last_day = 0;
   g_consecutive_losses = 0;
   g_trading_paused = false;

   if(GlobalVariableCheck(GVName("Paused")))
      g_trading_paused = (GlobalVariableGet(GVName("Paused")) != 0.0);
   if(GlobalVariableCheck(GVName("ConsecLosses")))
      g_consecutive_losses = (int)GlobalVariableGet(GVName("ConsecLosses"));
   if(g_trading_paused)
      Print("🔁 Восстановлено состояние стоп-машины после перезапуска: ПАУЗА (",
            g_consecutive_losses, " убытков подряд)");

   ArrayResize(g_posPnl, 0);
   ArrayResize(g_posMgmt, 0);

   EventSetTimer(1);

   double rr = (double)InpTakeProfit / (double)InpStopLoss;
   double breakEvenWinRate = 100.0 * InpStopLoss / (InpStopLoss + InpTakeProfit);

   Print("════════════════════════════════════════════");
   Print("XAUUSD Time EA v4.9 READABLE PANEL запущен | magic-база=", g_magic);
   for(int w = 0; w < TRADE_WINDOWS; w++)
   {
      Print(g_win[w].direction == -1 ? "📉 " : "📈 ", g_win[w].label,
            " (magic ", WindowMagic(w), "): анализ ",
            StringFormat("%02d:%02d", g_win[w].analHour, g_win[w].analMinute), "-",
            StringFormat("%02d:%02d", g_win[w].analHour, g_win[w].analEndMin),
            " → вход ", StringFormat("%02d:%02d", g_win[w].entryHour, g_win[w].entryMinute));
   }
   Print("Мин счёт фильтров: ", InpMinScore, "/6");
   Print("TP=", InpTakeProfit, "pts SL=", InpStopLoss,
         "pts R:R=1:", DoubleToString(1.0/rr, 2),
         " | нужен винрейт ≥", DoubleToString(breakEvenWinRate, 1),
         "% чтобы не уходить в минус БЕЗ учёта безубытка/трейлинга");
   Print("Безубыток: ", (InpUseBreakEven ? "ON" : "OFF"),
         " | Частичное закрытие: ", (InpUsePartialClose ? "ON" : "OFF"),
         " | Трейлинг: ", (InpUseTrailingStop ? "ON" : "OFF"));
   Print("Стоп-машина после ", InpMaxConsecutiveLosses, " убытков подряд (на весь EA сразу)");
   Print("Min broker stop: ", minStop, "pts");
   Print("════════════════════════════════════════════");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, PANEL_PREFIX);
   Comment("");

   if(h_ma    != INVALID_HANDLE) IndicatorRelease(h_ma);
   if(h_ma_h1 != INVALID_HANDLE) IndicatorRelease(h_ma_h1);
   if(h_adx   != INVALID_HANDLE) IndicatorRelease(h_adx);
   if(h_rsi   != INVALID_HANDLE) IndicatorRelease(h_rsi);
   if(h_atr   != INVALID_HANDLE) IndicatorRelease(h_atr);

   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE)
   {
      GlobalVariableDel(GVName("ConsecLosses"));
      GlobalVariableDel(GVName("Paused"));
   }

   Print("════════════════════════════════════════════");
   Print("EA v4.9 остановлен");
   Print("Сделок: ", g_total_trades,
         " (S:", g_short_count, " L:", g_long_count, ")");
   Print("Win: ", g_win_trades, " | Loss: ", g_loss_trades);
   Print("Пропущено дней SHORT: ", g_short_skipped,
         " | LONG: ", g_long_skipped);
   if(g_total_trades > 0)
      Print("Winrate: ",
            DoubleToString(100.0*g_win_trades/g_total_trades, 1), "%");
   Print("PnL: $", DoubleToString(g_total_profit, 2));
   Print("════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| OnTimer — обновляем панель                                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(InpShowInfo) DrawPanel();
}

//+------------------------------------------------------------------+
//| OnTick — главная логика. Один цикл по всем 4 окнам вместо двух   |
//| продублированных блоков (SHORT/LONG) — каждое окно независимо.   |
//+------------------------------------------------------------------+
void OnTick()
{
   ManageOpenPositions();

   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   datetime todayStart = StringToTime(
      StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
   if(todayStart != g_last_day)
   {
      for(int w = 0; w < TRADE_WINDOWS; w++)
      {
         g_win[w].doneToday = false;
         g_win[w].approved = false;
         g_win[w].analysisActive = false;
         g_win[w].analStartPrice = 0.0;
         g_win[w].score = 0;
         g_win[w].filtersDetail = "";
      }
      g_last_day = todayStart;
      Print("🌅 Новый день: ", TimeToString(todayStart, TIME_DATE));

      if(dt.day_of_week == 1 && g_trading_paused)
      {
         g_trading_paused = false;
         g_consecutive_losses = 0;
         PersistCircuitBreaker();
         Print("🔓 Новая торговая неделя — торговля возобновлена");
      }
   }

   int curHM = dt.hour * 60 + dt.min; // минуты от полуночи

   for(int w = 0; w < TRADE_WINDOWS; w++)
   {
      int analStart = g_win[w].analHour * 60 + g_win[w].analMinute;
      int analEnd   = g_win[w].analHour * 60 + g_win[w].analEndMin;
      int entryFrom = g_win[w].entryHour * 60 + g_win[w].entryMinute;
      int entryTo   = entryFrom + g_win[w].entryWindow;

      // ---------- Окно анализа ----------
      if(curHM >= analStart && curHM <= analEnd &&
         !g_win[w].doneToday && !g_win[w].approved)
      {
         if(!g_win[w].analysisActive)
         {
            g_win[w].analysisActive = true;
            g_win[w].analStartPrice = SymbolInfoDouble(_Symbol,
               g_win[w].direction == -1 ? SYMBOL_BID : SYMBOL_ASK);
            Print("🔍 Старт анализа ", g_win[w].label, " в ",
                  TimeToString(serverTime, TIME_MINUTES),
                  " | стартовая цена=",
                  DoubleToString(g_win[w].analStartPrice, _Digits));
         }

         string detail;
         g_win[w].score = CountFilters(g_win[w].direction, g_win[w].analStartPrice, detail);
         g_win[w].filtersDetail = detail;

         if(curHM >= analEnd)
         {
            if(g_win[w].score >= InpMinScore)
            {
               g_win[w].approved = true;
               Print("✅ ", g_win[w].label, " ПОДТВЕРЖДЁН: счёт ", g_win[w].score,
                     "/6 | ", g_win[w].filtersDetail);
            }
            else
            {
               g_win[w].doneToday = true;
               if(g_win[w].direction == -1) g_short_skipped++; else g_long_skipped++;
               Print("❌ ", g_win[w].label, " НЕ ПОДТВЕРЖДЁН: счёт ", g_win[w].score,
                     "/6 < мин ", InpMinScore, " | ",
                     g_win[w].filtersDetail, " — пропуск дня");
            }
         }
      }

      // ---------- Окно входа ----------
      if(curHM >= entryFrom && curHM < entryTo &&
         g_win[w].approved && !g_win[w].doneToday)
      {
         if(g_trading_paused)
         {
            Print("⛔ Вход ", g_win[w].label, " пропущен — торговля приостановлена (стоп-машина)");
            g_win[w].doneToday = true;
            continue; // не return: соседние окна в этом же тике всё ещё нужно обработать
         }

         if(HasOpenPositionForWindow(w))
         {
            Print("⚠️ ", g_win[w].label, " уже открыт — пропуск нового входа");
            g_win[w].doneToday = true;
            continue;
         }

         if(!SpreadOK()) continue;
         if(!CalendarClear()) continue;

         if(OpenPosition(g_win[w].direction, WindowMagic(w), g_win[w].label))
         {
            g_win[w].doneToday = true;
            g_total_trades++;
            if(g_win[w].direction == -1) g_short_count++; else g_long_count++;
            Print("✅✅ ", g_win[w].label, " ОТКРЫТ в ",
                  TimeToString(serverTime, TIME_MINUTES),
                  " | счёт был ", g_win[w].score, "/6");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Открытие позиции под magic конкретного окна                      |
//+------------------------------------------------------------------+
bool OpenPosition(int direction, int magicForTrade, string label)
{
   trade.SetExpertMagicNumber(magicForTrade);

   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   int minStop = GetMinStopPoints();

   int slPts = InpStopLoss;
   int tpPts = InpTakeProfit;

   if(InpUseATRStops)
   {
      double atr = BufferVal(h_atr, 0, 1);
      if(atr > 0.0 && point > 0.0)
      {
         int atrPts = (int)MathRound(atr / point);
         slPts = (int)MathRound(atrPts * InpATRSLMult);
         tpPts = (int)MathRound(atrPts * InpATRTPMult);
      }
   }
   slPts = MathMax(slPts, minStop);
   tpPts = MathMax(tpPts, minStop);

   double entry, sl, tp;
   if(direction == 1)
   {
      entry = ask;
      sl = NormalizeDouble(entry - slPts * point, digits);
      tp = NormalizeDouble(entry + tpPts * point, digits);
   }
   else
   {
      entry = bid;
      sl = NormalizeDouble(entry + slPts * point, digits);
      tp = NormalizeDouble(entry - tpPts * point, digits);
   }

   double lot;
   if(InpUseFixedLot)
      lot = InpLotSize;
   else
      lot = CalcLotByRisk(slPts);

   lot = NormalizeAndValidateLot(lot, direction, entry);
   if(lot <= 0.0) return false;

   Print(direction > 0 ? "📈 BUY (" : "📉 SELL (", label, ")",
         " | Цена=", DoubleToString(entry, digits),
         " SL=", DoubleToString(sl, digits),
         " TP=", DoubleToString(tp, digits),
         " Лот=", DoubleToString(lot, 2),
         " Magic=", magicForTrade);

   bool ok;
   if(direction == 1)
      ok = trade.Buy(lot, _Symbol, entry, sl, tp, "v4.9 " + label);
   else
      ok = trade.Sell(lot, _Symbol, entry, sl, tp, "v4.9 " + label);

   if(!ok)
   {
      Print("❌ Ошибка: ", trade.ResultRetcode(),
            " — ", trade.ResultRetcodeDescription());
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| OnTradeTransaction — учёт win/loss. Магic-фильтр теперь диапазон  |
//| g_magic..g_magic+TRADE_WINDOWS-1 (любое из наших 4 окон), а не    |
//| точное равенство одному magic.                                    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;

   long dealMagic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(dealMagic < g_magic || dealMagic >= g_magic + TRADE_WINDOWS) return;

   if((long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   double pnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
              + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
              + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   g_total_profit += pnl;

   ulong posId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   AddPosPnl(posId, pnl);

   long dealType = (long)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   bool wasShort = (dealType == DEAL_TYPE_BUY);   // BUY-deal закрывает SHORT
   bool wasLong  = (dealType == DEAL_TYPE_SELL);  // SELL-deal закрывает LONG

   bool stillOpen = PositionSelectByTicket(posId);
   if(stillOpen)
   {
      Print(pnl >= 0.0 ? "💰 Частичное закрытие +$" : "💰 Частичное закрытие $",
            DoubleToString(pnl, 2), " (позиция ещё открыта)");
      return;
   }

   double finalPnl = PopPosPnl(posId);
   RemovePosMgmt(posId);

   if(finalPnl > 0.0)
   {
      g_win_trades++;
      g_consecutive_losses = 0;
      if(wasShort) g_short_wins++;
      if(wasLong)  g_long_wins++;
      PersistCircuitBreaker();
      Print("✅ Позиция закрыта +$", DoubleToString(finalPnl, 2),
            " | PnL: $", DoubleToString(g_total_profit, 2));
   }
   else if(finalPnl < 0.0)
   {
      g_loss_trades++;
      g_consecutive_losses++;
      Print("❌ Позиция закрыта $", DoubleToString(finalPnl, 2),
            " | PnL: $", DoubleToString(g_total_profit, 2));

      if(InpMaxConsecutiveLosses > 0 && g_consecutive_losses >= InpMaxConsecutiveLosses)
      {
         g_trading_paused = true;
         Print("⛔ СТОП-МАШИНА: ", g_consecutive_losses,
               " убытков подряд — торговля приостановлена до понедельника");
      }
      PersistCircuitBreaker();
   }
}

//+------------------------------------------------------------------+
//| ПАНЕЛЬ — фон + текст                                              |
//+------------------------------------------------------------------+

void DrawPanelBackground(int totalLines)
{
   string bgName = PANEL_PREFIX + "_BG";
   int width  = 380;
   int height = totalLines * (InpPanelFontSize + 6) + 20;

   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpPanelX - 8);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpPanelY - 8);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'15,15,25');
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDarkSlateGray);
      ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpPanelX - 8);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpPanelY - 8);
}

void DrawPanelLine(int line, string text, color clr)
{
   string fullName = PANEL_PREFIX + IntegerToString(line);
   int lineHeight = InpPanelFontSize + 6;
   if(ObjectFind(0, fullName) < 0)
   {
      ObjectCreate(0, fullName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, fullName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, InpPanelX);
      ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, InpPanelY + line * lineHeight);
      ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, InpPanelFontSize);
      ObjectSetString(0, fullName, OBJPROP_FONT, InpPanelFontName);
      ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, fullName, OBJPROP_BACK, false);
      ObjectSetInteger(0, fullName, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, InpPanelY + line * lineHeight);
   ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, InpPanelFontSize);
   ObjectSetString(0, fullName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
}

// Статус конкретного окна для панели (заменяет две ранее продублированные
// цепочки if/else для SHORT и LONG).
string WindowStatusText(int w, int curHM, color &outColor)
{
   int analStart = g_win[w].analHour * 60 + g_win[w].analMinute;
   int analEnd   = g_win[w].analHour * 60 + g_win[w].analEndMin;
   int entryFrom = g_win[w].entryHour * 60 + g_win[w].entryMinute;

   if(g_win[w].doneToday && g_win[w].approved)
   { outColor = InpColorGood; return "✓ ОТКРЫТ"; }
   if(g_win[w].doneToday)
   { outColor = InpColorBad; return "✗ пропуск"; }
   if(curHM >= analStart && curHM <= analEnd)
   { outColor = InpColorWaiting; return StringFormat("🔍 АНАЛИЗ %d/6", g_win[w].score); }
   if(g_win[w].approved && curHM < entryFrom)
   { outColor = InpColorGood; return StringFormat("✅ ОДОБРЕН %d/6", g_win[w].score); }
   if(curHM < analStart)
   {
      outColor = InpColorNeutral;
      return StringFormat("⏳ ждём %02d:%02d", g_win[w].analHour, g_win[w].analMinute);
   }
   outColor = InpColorNeutral;
   return "❌ упущено";
}

void DrawPanel()
{
   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   int curHM = dt.hour * 60 + dt.min;

   double winRate = 0.0;
   if(g_total_trades > 0)
      winRate = 100.0 * g_win_trades / g_total_trades;
   double spread = GetSpread();

   string texts[40];
   color  colors[40];
   int n = 0;

   texts[n] = "═══ XAUUSD Reversal v4.9 ═══"; colors[n] = InpColorTitle; n++;
   texts[n] = StringFormat("Время: %02d:%02d  |  Magic-база: %d", dt.hour, dt.min, g_magic);
   colors[n] = InpColorText; n++;
   texts[n] = ""; colors[n] = InpColorText; n++;

   for(int w = 0; w < TRADE_WINDOWS; w++)
   {
      color wc;
      string status = WindowStatusText(w, curHM, wc);

      texts[n] = StringFormat("─── %s (%02d:%02d→%02d:%02d) ───", g_win[w].label,
         g_win[w].analHour, g_win[w].analMinute, g_win[w].entryHour, g_win[w].entryMinute);
      colors[n] = InpColorHeader; n++;

      texts[n] = StringFormat("Статус: %s", status); colors[n] = wc; n++;

      if(g_win[w].analStartPrice > 0.0)
      { texts[n] = StringFormat("Старт. цена: %.2f", g_win[w].analStartPrice); colors[n] = InpColorText; n++; }
      if(g_win[w].filtersDetail != "")
      { texts[n] = g_win[w].filtersDetail; colors[n] = InpColorText; n++; }

      texts[n] = ""; colors[n] = InpColorText; n++;
   }

   texts[n] = "─── СТАТИСТИКА ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Сделок: %d (S:%d L:%d)", g_total_trades, g_short_count, g_long_count);
   colors[n] = InpColorText; n++;
   texts[n] = StringFormat("Win: %d | Loss: %d (%.0f%%)", g_win_trades, g_loss_trades, winRate);
   colors[n] = InpColorText; n++;
   texts[n] = StringFormat("Пропусков: S=%d L=%d", g_short_skipped, g_long_skipped);
   colors[n] = InpColorNeutral; n++;
   texts[n] = StringFormat("PnL: $%.2f", g_total_profit);
   colors[n] = (g_total_profit >= 0 ? InpColorGood : InpColorBad); n++;
   texts[n] = StringFormat("Серия убытков: %d/%d", g_consecutive_losses,
                            InpMaxConsecutiveLosses);
   colors[n] = (g_trading_paused ? InpColorBad : InpColorNeutral); n++;
   if(g_trading_paused)
   { texts[n] = "⛔ ТОРГОВЛЯ ПРИОСТАНОВЛЕНА до понедельника"; colors[n] = InpColorBad; n++; }
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = StringFormat("Spread: %.0fpts | TP/SL: %d/%d", spread, InpTakeProfit, InpStopLoss);
   colors[n] = InpColorNeutral; n++;

   if(InpDarkBackground) DrawPanelBackground(n);
   for(int i = 0; i < n; i++)
      DrawPanelLine(i, texts[i], colors[i]);

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
