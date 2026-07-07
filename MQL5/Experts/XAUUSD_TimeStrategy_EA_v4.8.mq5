//+------------------------------------------------------------------+
//|              XAUUSD_TimeStrategy_EA v4.8 READABLE PANEL           |
//|                                                                  |
//|  CHANGELOG v4.8 — времена и TP по результатам бэктеста на        |
//|  259 торговых днях реальной истории XAUUSD (M15), с делением      |
//|  train/test (см. отчёт в чате) — та же 6-фильтровая логика,      |
//|  что и в коде, прогнана по каждому часу суток отдельно:          |
//|                                                                  |
//|  НАХОДКА: усреднённо по ВСЕМ часам суток винрейт составил 78.1%  |
//|  — это ТОЧНО совпадает с порогом безубытка для TP=700/SL=2500    |
//|  (тоже 78.1%). Иными словами, старый выбор времени (03:00 и      |
//|  15:00) был близок к случайному относительно этого набора       |
//|  фильтров — отсюда и "то плюс, то минус" на практике.            |
//|                                                                  |
//|  Единственное окно, прибыльное И в SHORT, И в LONG, И в первой,  |
//|  И во второй половине года одновременно — 11:00-14:00 (время    |
//|  сервера). Часы 03:00 и 15:00 (старые окна) показали результат   |
//|  в лучшем случае около нуля за весь год.                         |
//|                                                                  |
//|  ИЗМЕНЕНО (входные параметры, всё как раньше настраивается):    |
//|  • SHORT: анализ 03:00-03:50→вход 04:00  ⇒  12:00-12:50→13:00   |
//|  • LONG:  анализ 15:00-15:50→вход 16:00  ⇒  13:00-13:50→14:00   |
//|  • TP: 700 → 1000 пунктов (SL не менялся, остался 2500) —        |
//|    перебор ~40 комбинаций TP/SL на новых часах показал, что      |
//|    более широкий TP при той же вероятности выигрыша даёт         |
//|    заметно больше прибыли, не проседая по винрейту ниже          |
//|    комфортного запаса над порогом безубытка.                     |
//|                                                                  |
//|  ПОПУТНО НАЙДЕН БАГ: заголовки блоков "SHORT (03:00→04:00)" /   |
//|  "LONG (15:00→16:00)" и статус "ждём 03:00/15:00" на панели      |
//|  были захардкожены строками с самой первой версии — при смене   |
//|  времени входа через input-параметры панель продолжала бы        |
//|  показывать старые часы. Теперь строятся из реальных input-      |
//|  параметров.                                                      |
//|                                                                  |
//|  ЧЕСТНЫЕ ОГОВОРКИ: цвет свечи в бэктесте считался на M15 (не на  |
//|  M5, т.к. в выгруженном файле не было M5-данных); спред и        |
//|  проскальзывание не учтены; выборка ~55-90 сделок на час за год  |
//|  — обязательно проверяйте на демо перед реальным счётом.        |
//|                                                                  |
//|  Всё из v4.3/v4.4/v4.5/v4.6/v4.7 сохранено без изменений:        |
//|  фильтр объёма (исправлен в v4.5), риск % от баланса, безубыток/ |
//|  частичное закрытие/трейлинг, проверка hedging-счёта, magic как  |
//|  input (v4.7), персистентная стоп-машина (v4.6).                 |
//|                                                                  |
//|  ЛОГИКА ВХОДОВ:                                                   |
//|  • 12:00-12:50 анализ SHORT → если ≥4/6 → 13:00 ВХОД           |
//|  • 13:00-13:50 анализ LONG → если ≥4/6 → 14:00 ВХОД            |
//|  • Обе позиции одновременно возможны (нужен hedging-счёт)       |
//+------------------------------------------------------------------+
#property copyright   "Custom EA v4.8 READABLE PANEL — audited"
#property version     "4.80"
#property strict
#property description "XAUUSD Time EA v4.8 — окна входа и TP по бэктесту 259 дней истории"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;

//--- Входные параметры
input group "=== ИДЕНТИФИКАЦИЯ ==="
input int     InpMagicNumber      = 202507;  // FIX v4.7: уникальный magic для КАЖДОГО инстанса EA
                                              // (если планируете несколько окон/сессий — у каждого
                                              // инстанса должен быть СВОЙ magic, иначе они будут
                                              // видеть чужие позиции и путать друг друга статистику)

input group "=== ТОРГОВЫЕ ПАРАМЕТРЫ ==="
input bool    InpUseFixedLot      = true;    // true=фикс.лот InpLotSize, false=риск % от баланса
input double  InpLotSize          = 0.01;
input double  InpRiskPct          = 1.0;     // % риска от баланса (если InpUseFixedLot=false)
input int     InpTakeProfit       = 1000;    // TP в пунктах (FIX v4.8: было 700 — см. changelog, бэктест)
input int     InpStopLoss         = 2500;    // SL в пунктах

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
input int     InpMaxConsecutiveLosses = 3;   // 0 = отключено; пауза до понедельника
input bool    InpRequireHedging       = true; // требовать hedging-счёт (иначе INIT_FAILED)

input group "=== ВРЕМЕНА АНАЛИЗА И ВХОДА (FIX v4.8: см. changelog, бэктест на 259 днях) ==="
input int     InpShortAnalysisHour    = 12;  // Анализ SHORT: с 12:00 (было 03:00)
input int     InpShortAnalysisMinute  = 0;
input int     InpShortAnalysisEndMin  = 50;  // до 12:50
input int     InpShortEntryHour       = 13;  // Вход SHORT: 13:00 (было 04:00)
input int     InpShortEntryMinute     = 0;
input int     InpShortEntryWindow     = 5;   // окно входа 5 мин

input int     InpLongAnalysisHour     = 13;  // Анализ LONG: с 13:00 (было 15:00)
input int     InpLongAnalysisMinute   = 0;
input int     InpLongAnalysisEndMin   = 50;  // до 13:50
input int     InpLongEntryHour        = 14;  // Вход LONG: 14:00 (было 16:00)
input int     InpLongEntryMinute      = 0;
input int     InpLongEntryWindow      = 5;

input group "=== ФИЛЬТРЫ ПОДТВЕРЖДЕНИЯ ==="
input int     InpMinScore          = 4;     // мин счёт фильтров (макс 6)
input double  InpMinPriceMovePct   = 0.15;  // мин движение % за окно
input double  InpRSIThresholdShort = 55.0;  // RSI для SHORT (выше)
input double  InpRSIThresholdLong  = 45.0;  // RSI для LONG (ниже)
input double  InpMinADX            = 18.0;  // мин ADX для входа
input int     InpEMA_Period        = 21;    // EMA на M15
input bool    InpUseH1TrendFilter  = false;  // true = фильтр EMA считать на H1 (независимое ТФ), а не на M15

input group "=== ЗАЩИТНЫЕ ФИЛЬТРЫ ==="
input int     InpMaxSpread         = 80;
input bool    InpUseCalendar       = true;
input int     InpNewsBlockMins     = 30;

input group "=== ИНДИКАТОРЫ АНАЛИЗА ==="
input int     InpADXPeriod        = 14;
input int     InpRSIPeriod        = 14;
input int     InpVolPeriod        = 20;   // теперь реально используется в фильтре объёма

input group "=== ОТОБРАЖЕНИЕ ==="
input bool    InpShowInfo          = true;
input int     InpPanelX            = 15;     // отступ слева (px)
input int     InpPanelY            = 30;     // отступ сверху (px)
input int     InpPanelFontSize     = 11;     // размер шрифта (8-16)
input string  InpPanelFontName     = "Consolas"; // шрифт
input color   InpColorTitle        = clrAqua;     // цвет заголовков
input color   InpColorHeader       = clrGold;     // цвет разделителей
input color   InpColorText         = clrWhite;    // основной текст
input color   InpColorGood         = clrLime;     // успех/прибыль
input color   InpColorBad          = clrTomato;   // ошибка/убыток
input color   InpColorNeutral      = clrLightGray; // нейтральный
input color   InpColorWaiting      = clrYellow;   // ожидание
input bool    InpDarkBackground    = true;        // тёмный фон под панель

//--- Глобальные переменные
bool     g_short_done_today = false;
bool     g_long_done_today  = false;
datetime g_last_day         = 0;
int      g_magic            = 0; // FIX v4.7: реальное значение берётся из InpMagicNumber в OnInit

// Состояние анализа
bool     g_short_analysis_active = false;
bool     g_long_analysis_active  = false;
double   g_short_anal_start_price = 0.0;
double   g_long_anal_start_price  = 0.0;
int      g_short_score = 0;     // итог анализа SHORT
int      g_long_score  = 0;     // итог анализа LONG
string   g_short_filters_detail = "";
string   g_long_filters_detail  = "";
bool     g_short_approved = false;  // финальное решение
bool     g_long_approved  = false;

// Индикаторы
int      h_ma         = INVALID_HANDLE;  // EMA на M15
int      h_ma_h1      = INVALID_HANDLE;  // EMA на H1 (для InpUseH1TrendFilter)
int      h_adx        = INVALID_HANDLE;
int      h_rsi        = INVALID_HANDLE;
int      h_atr        = INVALID_HANDLE;

// Статистика
int      g_total_trades  = 0;
int      g_win_trades    = 0;
int      g_loss_trades   = 0;
double   g_total_profit  = 0.0;
int      g_short_count   = 0;
int      g_long_count    = 0;
int      g_short_wins    = 0;
int      g_long_wins     = 0;
int      g_short_skipped = 0;   // дней без сигнала на SHORT
int      g_long_skipped  = 0;

// Защита капитала
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

// FIX v4.6: имя терминальной глобальной переменной, персонализированное под
// символ+magic — чтобы не пересекаться с другими инстансами EA.
string GVName(string suffix)
{
   return "XAUTimeEA_" + _Symbol + "_" + IntegerToString(g_magic) + "_" + suffix;
}

// FIX v4.6 (важно для стоп-машины): состояние "приостановлена ли торговля" и
// "сколько убытков подряд" раньше жили только в оперативной памяти EA — при
// любом перезапуске (перезагрузка VPS, падение терминала, смена параметров)
// они молча сбрасывались в 0/false, и стоп-машина, которая должна была
// защищать капитал после серии убытков, переставала действовать. Сохраняем
// оба значения в терминальные глобальные переменные, переживающие рестарт.
void PersistCircuitBreaker()
{
   GlobalVariableSet(GVName("ConsecLosses"), (double)g_consecutive_losses);
   GlobalVariableSet(GVName("Paused"), g_trading_paused ? 1.0 : 0.0);
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
   ArraySetAsSeries(vol, true); // FIX v4.5: явно как таймсерия — index 0 = самый
                                // свежий запрошенный бар (shift=1).
   if(CopyTickVolume(_Symbol, PERIOD_M5, 1, need, vol) != need) return false;

   // FIX v4.5 (КРИТИЧНО): для динамических массивов MQL5 сам переводит их в
   // таймсерию при копировании через Copy*-функции — index 0 соответствует
   // САМОМУ СВЕЖЕМУ запрошенному бару (shift=1), а последний index — самому
   // старому. В v4.3/v4.4 код брал vol[need-1] как "текущий" бар и усреднял
   // vol[0..need-2] — то есть фактически сравнивал САМЫЙ СТАРЫЙ бар со
   // средним по более свежим барам. Фильтр объёма был инвертирован
   // относительно задуманного с момента появления в v4.3.
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
//| ПОДСЧЁТ ФИЛЬТРОВ ДЛЯ SHORT                                       |
//| Возвращает счёт 0-6 + заполняет g_short_filters_detail            |
//+------------------------------------------------------------------+
int CountShortFilters(double startPrice)
{
   int score = 0;
   string detail = "";

   double curPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 1. Движение цены за окно
   if(startPrice > 0.0)
   {
      double movePct = (curPrice - startPrice) / startPrice * 100.0;
      if(movePct >= InpMinPriceMovePct)
      {
         score++;
         detail += StringFormat("✅ Движ. +%.2f%% ", movePct);
      }
      else
      {
         detail += StringFormat("❌ Движ. %+.2f%% ", movePct);
      }
   }
   else
   {
      detail += "❌ Движ. N/A ";
   }

   // 2. RSI > порог
   double rsi = BufferVal(h_rsi, 0, 1);
   if(rsi != EMPTY_VALUE && rsi > InpRSIThresholdShort)
   {
      score++;
      detail += StringFormat("✅ RSI %.1f ", rsi);
   }
   else
   {
      detail += StringFormat("❌ RSI %.1f ", rsi);
   }

   // 3. ADX > порог
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

   // 4. Последняя свеча M5 зелёная (бычья)
   double o1 = iOpen(_Symbol, PERIOD_M5, 1);
   double c1 = iClose(_Symbol, PERIOD_M5, 1);
   if(c1 > o1)
   {
      score++;
      detail += "✅ Свеча🟢 ";
   }
   else
   {
      detail += "❌ Свеча🔴 ";
   }

   // 5. Цена > EMA21 (M15, либо H1 если включён InpUseH1TrendFilter —
   //    так фильтр не дублирует "движение цены"/"свеча" тем же таймфреймом)
   double ema = InpUseH1TrendFilter ? BufferVal(h_ma_h1, 0, 1) : BufferVal(h_ma, 0, 1);
   if(ema != EMPTY_VALUE && curPrice > ema)
   {
      score++;
      detail += InpUseH1TrendFilter ? "✅ >EMA(H1) " : "✅ >EMA ";
   }
   else
   {
      detail += InpUseH1TrendFilter ? "❌ <EMA(H1) " : "❌ <EMA ";
   }

   // 6. Объём выше среднего
   if(VolumeConfirmed())
   {
      score++;
      detail += "✅ Vol↑ ";
   }
   else
   {
      detail += "❌ Vol↓ ";
   }

   g_short_filters_detail = detail;
   return score;
}

//+------------------------------------------------------------------+
//| ПОДСЧЁТ ФИЛЬТРОВ ДЛЯ LONG (зеркально SHORT)                      |
//+------------------------------------------------------------------+
int CountLongFilters(double startPrice)
{
   int score = 0;
   string detail = "";

   double curPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // 1. Движение цены ВНИЗ
   if(startPrice > 0.0)
   {
      double movePct = (curPrice - startPrice) / startPrice * 100.0;
      if(movePct <= -InpMinPriceMovePct)
      {
         score++;
         detail += StringFormat("✅ Движ. %.2f%% ", movePct);
      }
      else
      {
         detail += StringFormat("❌ Движ. %+.2f%% ", movePct);
      }
   }
   else
   {
      detail += "❌ Движ. N/A ";
   }

   // 2. RSI < порог (перепродано)
   double rsi = BufferVal(h_rsi, 0, 1);
   if(rsi != EMPTY_VALUE && rsi < InpRSIThresholdLong)
   {
      score++;
      detail += StringFormat("✅ RSI %.1f ", rsi);
   }
   else
   {
      detail += StringFormat("❌ RSI %.1f ", rsi);
   }

   // 3. ADX > порог
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

   // 4. Последняя свеча M5 красная (медвежья)
   double o1 = iOpen(_Symbol, PERIOD_M5, 1);
   double c1 = iClose(_Symbol, PERIOD_M5, 1);
   if(c1 < o1)
   {
      score++;
      detail += "✅ Свеча🔴 ";
   }
   else
   {
      detail += "❌ Свеча🟢 ";
   }

   // 5. Цена < EMA21 (M15, либо H1 если включён InpUseH1TrendFilter)
   double ema = InpUseH1TrendFilter ? BufferVal(h_ma_h1, 0, 1) : BufferVal(h_ma, 0, 1);
   if(ema != EMPTY_VALUE && curPrice < ema)
   {
      score++;
      detail += InpUseH1TrendFilter ? "✅ <EMA(H1) " : "✅ <EMA ";
   }
   else
   {
      detail += InpUseH1TrendFilter ? "❌ >EMA(H1) " : "❌ >EMA ";
   }

   // 6. Объём выше среднего
   if(VolumeConfirmed())
   {
      score++;
      detail += "✅ Vol↑ ";
   }
   else
   {
      detail += "❌ Vol↓ ";
   }

   g_long_filters_detail = detail;
   return score;
}

//+------------------------------------------------------------------+
//| Проверка открытых позиций по типу                                |
//+------------------------------------------------------------------+
bool HasOpenShort()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol &&
            posInfo.Magic() == g_magic &&
            posInfo.PositionType() == POSITION_TYPE_SELL)
            return true;
      }
   }
   return false;
}

bool HasOpenLong()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol &&
            posInfo.Magic() == g_magic &&
            posInfo.PositionType() == POSITION_TYPE_BUY)
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
//| закрытие / трейлинг. Цель — сократить СРЕДНИЙ убыток, не         |
//| трогая исходные TP/SL, которые вы уже проверили на практике.     |
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
      if(posInfo.Symbol() != _Symbol || posInfo.Magic() != g_magic) continue;

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
               curSL = newSL; // FIX v4.4 #B: обновляем локальное состояние сразу,
                              // иначе трейлинг ниже в этом же тике сравнивает
                              // с устаревшим (добезубыточным) SL
               Print("🔒 Безубыток: тикет ", ticket, " SL→", DoubleToString(newSL, digits));
            }
         }
         else
            g_posMgmt[mIdx].beDone = true;
      }

      // --- Частичное закрытие ---
      if(InpUsePartialClose && !g_posMgmt[mIdx].partialDone)
      {
         // FIX v4.5: раньше проверяли "tpDist<=0" чтобы поймать "TP не задан",
         // но если curTP==0 (нет тейка), MathAbs(0-openPrice)/point даёт
         // ОГРОМНОЕ число (не <=0!), и проверка не срабатывала — target
         // получался практически недостижимым. Явно проверяем curTP==0.
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
               g_posMgmt[mIdx].partialDone = true; // объём слишком мал для частичного закрытия
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
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   g_magic = InpMagicNumber; // FIX v4.7: должно быть установлено ДО первого
                             // использования (GVName, trade.SetExpertMagicNumber)

   if(g_magic <= 0)
   {
      Print("❌ ERROR: InpMagicNumber должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_fillType = DetectFillType();
   trade.SetExpertMagicNumber(g_magic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(g_fillType);

   int minStop = GetMinStopPoints();

   // Валидация
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

   // Валидация часов 0-23, минут 0-59
   if(InpShortAnalysisHour < 0 || InpShortAnalysisHour > 23 ||
      InpShortEntryHour < 0    || InpShortEntryHour > 23 ||
      InpLongAnalysisHour < 0  || InpLongAnalysisHour > 23 ||
      InpLongEntryHour < 0     || InpLongEntryHour > 23)
   {
      Print("❌ ERROR: часы должны быть 0-23");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpShortAnalysisMinute < 0 || InpShortAnalysisMinute > 59 ||
      InpShortAnalysisEndMin < 0 || InpShortAnalysisEndMin > 59 ||
      InpShortEntryMinute < 0    || InpShortEntryMinute > 59 ||
      InpLongAnalysisMinute < 0  || InpLongAnalysisMinute > 59 ||
      InpLongAnalysisEndMin < 0  || InpLongAnalysisEndMin > 59 ||
      InpLongEntryMinute < 0     || InpLongEntryMinute > 59)
   {
      Print("❌ ERROR: минуты должны быть 0-59");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpShortEntryWindow <= 0 || InpShortEntryWindow > 60 ||
      InpLongEntryWindow  <= 0 || InpLongEntryWindow > 60)
   {
      Print("❌ ERROR: EntryWindow должен быть 1-60");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpShortAnalysisEndMin <= InpShortAnalysisMinute ||
      InpLongAnalysisEndMin <= InpLongAnalysisMinute)
   {
      Print("❌ ERROR: AnalysisEndMin должен быть > AnalysisMinute");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Времена сравниваются в "минутах от полуночи" (hour*60+minute), а не в
   // псевдо-десятичном ЧЧММ (hour*100+minute) — FIX v4.4 #A: hour*100+minute
   // ломается арифметикой сложения (entryTo=entryFrom+Window) при переходе
   // через границу часа (минута+окно > 59), потому что "часы:минуты" в
   // таком виде не арифметика, а просто склеенные цифры. minute-of-day
   // не имеет этой проблемы.
   int shortAnalEndKey = InpShortAnalysisHour * 60 + InpShortAnalysisEndMin;
   int shortEntryKey   = InpShortEntryHour * 60 + InpShortEntryMinute;
   if(shortEntryKey <= shortAnalEndKey)
   {
      Print("❌ ERROR: вход SHORT должен быть строго после конца анализа SHORT");
      return INIT_PARAMETERS_INCORRECT;
   }
   int longAnalEndKey = InpLongAnalysisHour * 60 + InpLongAnalysisEndMin;
   int longEntryKey    = InpLongEntryHour * 60 + InpLongEntryMinute;
   if(longEntryKey <= longAnalEndKey)
   {
      Print("❌ ERROR: вход LONG должен быть строго после конца анализа LONG");
      return INIT_PARAMETERS_INCORRECT;
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

   // FIX v4.5: без этой проверки при неудачном сочетании входов безубыток
   // мог бы попытаться поставить SL ВЫШЕ текущей цены (для BUY) или НИЖЕ
   // (для SELL) — т.е. по факту не безубыток, а мгновенный стоп/невалидный
   // ордер на модификацию.
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

   // FIX v4.3: требуем hedging-счёт, т.к. стратегия открывает SHORT и LONG
   // одновременно — на netting-счёте вторая позиция схлопнет первую.
   ENUM_ACCOUNT_MARGIN_MODE marginMode =
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(InpRequireHedging && marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("❌ ERROR: счёт не в режиме hedging (", EnumToString(marginMode),
            "). Одновременные SHORT+LONG будут схлопываться. ",
            "Отключите InpRequireHedging только если понимаете последствия.");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Индикаторы
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

   g_short_done_today = false;
   g_long_done_today  = false;
   g_short_analysis_active = false;
   g_long_analysis_active  = false;
   g_short_anal_start_price = 0.0;
   g_long_anal_start_price = 0.0;
   g_short_approved = false;
   g_long_approved = false;
   g_short_score = 0;
   g_long_score = 0;
   g_last_day = 0;
   g_consecutive_losses = 0;
   g_trading_paused = false;

   // FIX v4.6: восстанавливаем состояние стоп-машины после перезапуска —
   // без этого пауза и счётчик убытков подряд молча слетали при любом
   // перезапуске EA/терминала, отключая защиту капитала именно тогда,
   // когда она нужнее всего (сразу после серии убытков).
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
   Print("XAUUSD Time EA v4.8 READABLE PANEL запущен");
   Print("📉 SHORT: анализ ", InpShortAnalysisHour, ":",
         StringFormat("%02d", InpShortAnalysisMinute), "-",
         InpShortAnalysisHour, ":",
         StringFormat("%02d", InpShortAnalysisEndMin),
         " → вход ", InpShortEntryHour, ":",
         StringFormat("%02d", InpShortEntryMinute));
   Print("📈 LONG:  анализ ", InpLongAnalysisHour, ":",
         StringFormat("%02d", InpLongAnalysisMinute), "-",
         InpLongAnalysisHour, ":",
         StringFormat("%02d", InpLongAnalysisEndMin),
         " → вход ", InpLongEntryHour, ":",
         StringFormat("%02d", InpLongEntryMinute));
   Print("Мин счёт фильтров: ", InpMinScore, "/6");
   Print("TP=", InpTakeProfit, "pts SL=", InpStopLoss,
         "pts R:R=1:", DoubleToString(1.0/rr, 2),
         " | нужен винрейт ≥", DoubleToString(breakEvenWinRate, 1),
         "% чтобы не уходить в минус БЕЗ учёта безубытка/трейлинга");
   Print("Безубыток: ", (InpUseBreakEven ? "ON" : "OFF"),
         " | Частичное закрытие: ", (InpUsePartialClose ? "ON" : "OFF"),
         " | Трейлинг: ", (InpUseTrailingStop ? "ON" : "OFF"));
   Print("Стоп-машина после ", InpMaxConsecutiveLosses, " убытков подряд");
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

   // FIX v4.6: осознанное снятие EA с графика (не перезапуск/рекомпиляция)
   // очищает персистентное состояние стоп-машины — новое подключение EA
   // не должно унаследовать паузу от прошлого запуска.
   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE)
   {
      GlobalVariableDel(GVName("ConsecLosses"));
      GlobalVariableDel(GVName("Paused"));
   }

   Print("════════════════════════════════════════════");
   Print("EA v4.8 остановлен");
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
//| OnTick — главная логика                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   ManageOpenPositions();

   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   // Новый день — сброс
   datetime todayStart = StringToTime(
      StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
   if(todayStart != g_last_day)
   {
      g_short_done_today = false;
      g_long_done_today  = false;
      g_short_analysis_active = false;
      g_long_analysis_active  = false;
      g_short_anal_start_price = 0.0;
      g_long_anal_start_price  = 0.0;
      g_short_approved = false;
      g_long_approved  = false;
      g_short_score = 0;
      g_long_score = 0;
      g_short_filters_detail = "";
      g_long_filters_detail = "";
      g_last_day = todayStart;
      Print("🌅 Новый день: ", TimeToString(todayStart, TIME_DATE));

      // FIX v4.3: стоп-машина после серии убытков снимается в понедельник —
      // не даёт одной плохой неделе повлиять на следующую.
      if(dt.day_of_week == 1 && g_trading_paused)
      {
         g_trading_paused = false;
         g_consecutive_losses = 0;
         PersistCircuitBreaker();
         Print("🔓 Новая торговая неделя — торговля возобновлена");
      }
   }

   // FIX v4.4 #A: минуты от полуночи вместо ЧЧММ — см. комментарий в OnInit.
   int curHM = dt.hour * 60 + dt.min;
   int shortAnalStart = InpShortAnalysisHour * 60 + InpShortAnalysisMinute;
   int shortAnalEnd   = InpShortAnalysisHour * 60 + InpShortAnalysisEndMin;
   int shortEntryFrom = InpShortEntryHour * 60 + InpShortEntryMinute;
   int shortEntryTo   = shortEntryFrom + InpShortEntryWindow;

   int longAnalStart  = InpLongAnalysisHour * 60 + InpLongAnalysisMinute;
   int longAnalEnd    = InpLongAnalysisHour * 60 + InpLongAnalysisEndMin;
   int longEntryFrom  = InpLongEntryHour * 60 + InpLongEntryMinute;
   int longEntryTo    = longEntryFrom + InpLongEntryWindow;

   // ============== ОКНО АНАЛИЗА SHORT (03:00-03:50) ==============
   if(curHM >= shortAnalStart && curHM <= shortAnalEnd &&
      !g_short_done_today && !g_short_approved)
   {
      // Стартуем анализ — фиксируем стартовую цену
      if(!g_short_analysis_active)
      {
         g_short_analysis_active = true;
         g_short_anal_start_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         Print("🔍 Старт анализа SHORT в ",
               TimeToString(serverTime, TIME_MINUTES),
               " | стартовая цена=",
               DoubleToString(g_short_anal_start_price, _Digits));
      }

      // Постоянно обновляем счёт фильтров
      g_short_score = CountShortFilters(g_short_anal_start_price);

      // Финальное решение принимается ПРИ ПЕРВОМ тике в момент
      // или после shortAnalEnd (curHM >= shortAnalEnd, а не ==).
      if(curHM >= shortAnalEnd)
      {
         if(g_short_score >= InpMinScore)
         {
            g_short_approved = true;
            Print("✅ SHORT ПОДТВЕРЖДЁН: счёт ", g_short_score,
                  "/6 | ", g_short_filters_detail);
         }
         else
         {
            g_short_done_today = true;  // пропуск дня
            g_short_skipped++;
            Print("❌ SHORT НЕ ПОДТВЕРЖДЁН: счёт ", g_short_score,
                  "/6 < мин ", InpMinScore, " | ",
                  g_short_filters_detail, " — пропуск дня");
         }
      }
   }

   // ============== ОКНО ВХОДА SHORT (04:00-04:05) ==============
   if(curHM >= shortEntryFrom && curHM < shortEntryTo &&
      g_short_approved && !g_short_done_today)
   {
      if(g_trading_paused)
      {
         Print("⛔ Вход SHORT пропущен — торговля приостановлена (стоп-машина)");
         g_short_done_today = true;
         return;
      }

      // Защита от двойного открытия после перезапуска
      if(HasOpenShort())
      {
         Print("⚠️ SHORT уже открыт — пропуск нового входа");
         g_short_done_today = true;
         return;
      }

      if(!SpreadOK()) return;
      if(!CalendarClear()) return;

      if(OpenPosition(-1))
      {
         g_short_done_today = true;
         g_total_trades++;
         g_short_count++;
         Print("✅✅ SHORT ОТКРЫТ в ",
               TimeToString(serverTime, TIME_MINUTES),
               " | счёт был ", g_short_score, "/6");
      }
   }

   // ============== ОКНО АНАЛИЗА LONG (15:00-15:50) ==============
   if(curHM >= longAnalStart && curHM <= longAnalEnd &&
      !g_long_done_today && !g_long_approved)
   {
      if(!g_long_analysis_active)
      {
         g_long_analysis_active = true;
         g_long_anal_start_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         Print("🔍 Старт анализа LONG в ",
               TimeToString(serverTime, TIME_MINUTES),
               " | стартовая цена=",
               DoubleToString(g_long_anal_start_price, _Digits));
      }

      g_long_score = CountLongFilters(g_long_anal_start_price);

      if(curHM >= longAnalEnd)
      {
         if(g_long_score >= InpMinScore)
         {
            g_long_approved = true;
            Print("✅ LONG ПОДТВЕРЖДЁН: счёт ", g_long_score,
                  "/6 | ", g_long_filters_detail);
         }
         else
         {
            g_long_done_today = true;
            g_long_skipped++;
            Print("❌ LONG НЕ ПОДТВЕРЖДЁН: счёт ", g_long_score,
                  "/6 < мин ", InpMinScore, " | ",
                  g_long_filters_detail, " — пропуск дня");
         }
      }
   }

   // ============== ОКНО ВХОДА LONG (16:00-16:05) ==============
   if(curHM >= longEntryFrom && curHM < longEntryTo &&
      g_long_approved && !g_long_done_today)
   {
      if(g_trading_paused)
      {
         Print("⛔ Вход LONG пропущен — торговля приостановлена (стоп-машина)");
         g_long_done_today = true;
         return;
      }

      // Защита от двойного открытия после перезапуска
      if(HasOpenLong())
      {
         Print("⚠️ LONG уже открыт — пропуск нового входа");
         g_long_done_today = true;
         return;
      }

      if(!SpreadOK()) return;
      if(!CalendarClear()) return;

      if(OpenPosition(1))
      {
         g_long_done_today = true;
         g_total_trades++;
         g_long_count++;
         Print("✅✅ LONG ОТКРЫТ в ",
               TimeToString(serverTime, TIME_MINUTES),
               " | счёт был ", g_long_score, "/6");
      }
   }
}

//+------------------------------------------------------------------+
//| Открытие позиции                                                 |
//+------------------------------------------------------------------+
bool OpenPosition(int direction)
{
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   int minStop = GetMinStopPoints();

   int slPts = InpStopLoss;
   int tpPts = InpTakeProfit;

   // Опционально: SL/TP от ATR вместо фиксированных пунктов
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

   Print(direction > 0 ? "📈 BUY (16:00 LONG)" : "📉 SELL (04:00 SHORT)",
         " | Цена=", DoubleToString(entry, digits),
         " SL=", DoubleToString(sl, digits),
         " TP=", DoubleToString(tp, digits),
         " Лот=", DoubleToString(lot, 2));

   bool ok;
   if(direction == 1)
      ok = trade.Buy(lot, _Symbol, entry, sl, tp, "v4.8 LONG");
   else
      ok = trade.Sell(lot, _Symbol, entry, sl, tp, "v4.8 SHORT");

   if(!ok)
   {
      Print("❌ Ошибка: ", trade.ResultRetcode(),
            " — ", trade.ResultRetcodeDescription());
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| OnTradeTransaction — учёт win/loss с разделением SHORT/LONG      |
//| FIX v4.3 #5: PnL накапливается по position_id, статистика        |
//| (win/loss, серия убытков) считается только когда позиция          |
//| ЗАКРЫТА ПОЛНОСТЬЮ — иначе частичное закрытие в плюс и итоговый    |
//| выход по SL считались бы как ДВЕ независимые сделки.              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != g_magic) return;
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
      PersistCircuitBreaker(); // FIX v4.6: серия убытков прервана — сохраняем сразу
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
      PersistCircuitBreaker(); // FIX v4.6: сохраняем счётчик/паузу немедленно —
                               // переживёт перезапуск EA/терминала
   }
}

//+------------------------------------------------------------------+
//| ПАНЕЛЬ — фон + текст                                              |
//+------------------------------------------------------------------+

// Рисует тёмный прямоугольник-фон под панелью
void DrawPanelBackground(int totalLines)
{
   string bgName = PANEL_PREFIX + "_BG";
   int width  = 380;  // ширина фона
   int height = totalLines * (InpPanelFontSize + 6) + 20;

   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpPanelX - 8);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpPanelY - 8);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'15,15,25'); // тёмно-синий
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDarkSlateGray);
      ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, true);  // фон позади текста
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
      ObjectSetInteger(0, fullName, OBJPROP_BACK, false);  // текст поверх фона
      ObjectSetInteger(0, fullName, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, InpPanelY + line * lineHeight);
   ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, InpPanelFontSize);
   ObjectSetString(0, fullName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
}

// FIX v4.3 #4: строки панели теперь собираются в массив, и фон считается
// по РЕАЛЬНОМУ числу строк — раньше totalLines было захардкожено в 16,
// а при всех включённых условных полях фактически рисовалось до ~20
// строк, и текст вылезал за пределы тёмного фона.
void DrawPanel()
{
   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   int curHM = dt.hour * 60 + dt.min; // FIX v4.4 #A: минуты от полуночи

   // Состояние SHORT
   string shortStatus;
   color shortColor;
   int shortAnalStart = InpShortAnalysisHour * 60 + InpShortAnalysisMinute;
   int shortAnalEnd   = InpShortAnalysisHour * 60 + InpShortAnalysisEndMin;
   int shortEntry     = InpShortEntryHour * 60 + InpShortEntryMinute;

   if(g_short_done_today && g_short_approved)
   { shortStatus = "✓ ОТКРЫТ"; shortColor = InpColorGood; }
   else if(g_short_done_today)
   { shortStatus = "✗ пропуск"; shortColor = InpColorBad; }
   else if(curHM >= shortAnalStart && curHM <= shortAnalEnd)
   { shortStatus = StringFormat("🔍 АНАЛИЗ %d/6", g_short_score); shortColor = InpColorWaiting; }
   else if(g_short_approved && curHM < shortEntry)
   { shortStatus = StringFormat("✅ ОДОБРЕН %d/6", g_short_score); shortColor = InpColorGood; }
   else if(curHM < shortAnalStart)
   { shortStatus = StringFormat("⏳ ждём %02d:%02d", InpShortAnalysisHour, InpShortAnalysisMinute); shortColor = InpColorNeutral; }
   else { shortStatus = "❌ упущено"; shortColor = InpColorNeutral; }

   // Состояние LONG
   string longStatus;
   color longColor;
   int longAnalStart = InpLongAnalysisHour * 60 + InpLongAnalysisMinute;
   int longAnalEnd   = InpLongAnalysisHour * 60 + InpLongAnalysisEndMin;
   int longEntry     = InpLongEntryHour * 60 + InpLongEntryMinute;

   if(g_long_done_today && g_long_approved)
   { longStatus = "✓ ОТКРЫТ"; longColor = InpColorGood; }
   else if(g_long_done_today)
   { longStatus = "✗ пропуск"; longColor = InpColorBad; }
   else if(curHM >= longAnalStart && curHM <= longAnalEnd)
   { longStatus = StringFormat("🔍 АНАЛИЗ %d/6", g_long_score); longColor = InpColorWaiting; }
   else if(g_long_approved && curHM < longEntry)
   { longStatus = StringFormat("✅ ОДОБРЕН %d/6", g_long_score); longColor = InpColorGood; }
   else if(curHM < longAnalStart)
   { longStatus = StringFormat("⏳ ждём %02d:%02d", InpLongAnalysisHour, InpLongAnalysisMinute); longColor = InpColorNeutral; }
   else { longStatus = "❌ упущено"; longColor = InpColorNeutral; }

   double winRate = 0.0;
   if(g_total_trades > 0)
      winRate = 100.0 * g_win_trades / g_total_trades;
   double spread = GetSpread();

   string texts[24];
   color  colors[24];
   int n = 0;

   texts[n] = "═══ XAUUSD Reversal v4.8 ═══"; colors[n] = InpColorTitle; n++;
   texts[n] = StringFormat("Время: %02d:%02d  |  Magic: %d", dt.hour, dt.min, g_magic);
   colors[n] = InpColorText; n++;
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = StringFormat("─── SHORT (%02d:%02d→%02d:%02d) ───",
      InpShortAnalysisHour, InpShortAnalysisMinute, InpShortEntryHour, InpShortEntryMinute);
   colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Статус: %s", shortStatus); colors[n] = shortColor; n++;
   if(g_short_anal_start_price > 0.0)
   { texts[n] = StringFormat("Старт. цена: %.2f", g_short_anal_start_price); colors[n] = InpColorText; n++; }
   if(g_short_filters_detail != "")
   { texts[n] = g_short_filters_detail; colors[n] = InpColorText; n++; }
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = StringFormat("─── LONG (%02d:%02d→%02d:%02d) ───",
      InpLongAnalysisHour, InpLongAnalysisMinute, InpLongEntryHour, InpLongEntryMinute);
   colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Статус: %s", longStatus); colors[n] = longColor; n++;
   if(g_long_anal_start_price > 0.0)
   { texts[n] = StringFormat("Старт. цена: %.2f", g_long_anal_start_price); colors[n] = InpColorText; n++; }
   if(g_long_filters_detail != "")
   { texts[n] = g_long_filters_detail; colors[n] = InpColorText; n++; }
   texts[n] = ""; colors[n] = InpColorText; n++;

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
