//+------------------------------------------------------------------+
//|              XAUUSD_TimeStrategy_EA v5.2 CONTINUOUS SCAN         |
//|                                                                  |
//|  CHANGELOG v5.2 — защита от "затухания" движения (боковик после  |
//|  профита). По прямому запросу: "если цена выросла, но дальше не  |
//|  растёт и колеблется — закрыть в прибыль, не закрывать в минус.  |
//|  Только если сразу упала резко и не растёт — тогда это убыток"   |
//|  (это нормально, обычный стоп-лосс, не трогаем).                 |
//|                                                                  |
//|  Раньше (v5.0/после фикса): если позиция вышла в плюс, а потом    |
//|  рынок встал (боковик) без новых пиков прибыли, позиция просто    |
//|  ЖДАЛА либо TP, либо SL — если цена потом развернётся и дойдёт    |
//|  до нашего (уже подтянутого трейлингом/безубытком) SL, прибыль    |
//|  могла быть частично или полностью отдана назад. Явного механизма |
//|  "движение выдохлось — забираем то, что есть" не было.            |
//|                                                                  |
//|  ДОБАВЛЕНО: StallExit — если позиция СЕЙЧАС в прибыли (не в       |
//|  минусе — это важно, лоси не трогаем, они закрываются как раньше  |
//|  по SL) И за последние InpStallBars баров M15 НЕ обновлялся пик   |
//|  прибыли по этой позиции (с допуском на шум, InpStallNoiseEpsilon-|
//|  Pct) — позиция закрывается по рынку ПРЯМО СЕЙЧАС, фиксируя       |
//|  текущую прибыль, вместо того чтобы ждать и рисковать отдать её   |
//|  обратно. Если же позиция в минусе — этот механизм НЕ вмешивается,|
//|  убыток идёт своим чередом до SL/безубытка, как и раньше (это и   |
//|  есть "если сразу упала резко — значит убыток, это нормально").   |
//|                                                                  |
//|  ПРОВЕРЕНО Python-бэктестом (2 варианта): с доп. фильтром "рынок  |
//|  сейчас в боковике" (RegimeOK, тот же что на входе) срабатывало   |
//|  лишь 3 раза из 762 сделок — его ADX/диапазон считаются за 8      |
//|  баров и всё ещё "помнят" недавний трендовый заход, поэтому редко |
//|  успевают показать боковик всего за 1-2 бара затухания. Без этого |
//|  фильтра — 22 раза из 762, доп. прибыль ~$148 за год на лоте 0.1. |
//|  Фильтр по рынку убран, оставлена только сама стагнация (нет      |
//|  нового пика с учётом допуска на шум).                            |
//|                                                                  |
//|  CHANGELOG v5.0 — смена архитектуры: НЕ 2-4 фиксированных окна   |
//|  анализа в сутки (как в v4.7-v4.9), а НЕПРЕРЫВНОЕ сканирование   |
//|  всего торгового дня. По прямому запросу пользователя.           |
//|                                                                  |
//|  ⚠️ ВАЖНАЯ ОГОВОРКА ПО ЧЕСТНОСТИ: v4.9 (фиксированные окна        |
//|  11-12-13-14ч) была проверена на реальной истории (бэктест +     |
//|  реальный прогон в MT5 Strategy Tester: 153 сделки, винрейт      |
//|  92.2%, +$180 за полгода). Это была НАСТОЯЩАЯ, измеренная         |
//|  статистическая закономерность. v5.0 — НОВАЯ гипотеза с другой    |
//|  логикой входа (подтверждение сигнала за N баров вместо анализа   |
//|  в фиксированное время, плавающий TP по ATR вместо фиксированного,|
//|  фильтр "тренд/боковик"). Она ПОКА НЕ проверена так же строго —   |
//|  только Python-бэктестом на тех же исторических M15-данных        |
//|  (см. отчёт после кода). Обязательно прогоните v5.0 в реальном    |
//|  MT5 Strategy Tester на демо, прежде чем доверять ей живые деньги.|
//|                                                                  |
//|  ЧТО ИЗМЕНИЛОСЬ ОТНОСИТЕЛЬНО v4.9:                                |
//|  • Убраны 4 фиксированных окна анализ→вход (TradeWindow[4]).      |
//|    Вместо них — 2 "направления" (SHORT/LONG), каждое сканируется  |
//|    на КАЖДОМ новом баре M15 весь день.                            |
//|  • Сигнал должен продержаться InpConfirmBars баров M15 подряд     |
//|    (по умолчанию 4 бара ≈ 1 час) прежде чем откроется сделка —    |
//|    это и есть "мониторить час-два, потом сверить фильтры" из      |
//|    вашего запроса.                                                |
//|  • Добавлен фильтр РЕЖИМА РЫНКА (RegimeOK): ADX + диапазон цены   |
//|    за последние N баров. Если рынок "боковик" (узкий диапазон,    |
//|    слабый ADX) — сигналы не копятся, вход не разрешается.         |
//|  • TP/SL теперь плавающие, считаются от ATR и ограничены          |
//|    коридором InpMinTPPts..InpMaxTPPts (по умолчанию 50-1000 пт —  |
//|    ваше "50 до 500-1000 пунктов").                                |
//|  • Быстрая защита прибыли — реализация вашего "не давать упасть   |
//|    ниже +50, если цена резко разворачивается" (см. ниже фикс от   |
//|    реального теста: пороги теперь % от TP, а не фикс. пункты).    |
//|  • Лимит сделок в день (InpMaxTradesPerDay) и кулдаун между        |
//|    сделками (InpCooldownMinutes) — чтобы не открывать сделки      |
//|    слишком часто на одном и том же движении.                      |
//|  • Панель показывает live-статус сканирования: режим рынка,       |
//|    счёт фильтров и прогресс подтверждения по SHORT и по LONG      |
//|    отдельно — это и есть "таблица что код сканирует/проверяет".    |
//|                                                                  |
//|  Магic: теперь только 2 под-magic (SHORT=база+0, LONG=база+1) —   |
//|  окон-подокон больше нет, поэтому WindowMagic(w) заменён на        |
//|  DirectionMagic(direction).                                       |
//|                                                                  |
//|  НАЙДЕНО И ИСПРАВЛЕНО НА ЭТАПЕ ПРОВЕРКИ (Python-бэктест, 2 прогона|
//|  как и просили): ATR для расчёта TP/SL изначально брался с M15 —  |
//|  то же ATR, что и таймфрейм входа. При текущей цене золота ATR    |
//|  M15 сам по себе близок к размаху ОДНОГО бара, поэтому TP/SL      |
//|  почти всегда закрывались за 0-1 бар (~15-60 мин) — это шум, а не  |
//|  "движение за 1-2 часа" из вашего запроса. Исправлено: ATR теперь  |
//|  считается на H1 (iATR(...,PERIOD_H1,...)) — это отражает размах  |
//|  целого часа и даёт TP/SL более осмысленный масштаб. Даже после   |
//|  фикса сделки часто всё ещё закрываются быстро — это отдельно      |
//|  разобрано в отчёте после кода, это НЕ баг, а следствие текущей    |
//|  высокой абсолютной волатильности золота относительно коридора    |
//|  50-1000 пунктов.                                                  |
//|                                                                  |
//|  Всё остальное из v4.3-v4.9 сохранено без изменений: фильтр       |
//|  объёма (с фиксом реверса массива), риск % от баланса, частичное  |
//|  закрытие, трейлинг, проверка hedging-счёта, персистентная        |
//|  стоп-машина после серии убытков.                                 |
//|                                                                  |
//|  НАЙДЕНО НА РЕАЛЬНОМ ТЕСТЕ В MT5 (лог 2026.06.01-07.16, старт     |
//|  $1000, лот 0.1): 32 сделки, 25 побед/7 убытков (винрейт 78.1%),  |
//|  но итог -$782.55 (баланс $1000→$217). Причина: безубыток (+50пт) |
//|  и трейлинг (+60пт старт) были откалиброваны под МАЛЕНЬКИЙ TP, а  |
//|  не под реальный плавающий TP по ATR (часто ~900-1000 пт). Итог:  |
//|  все 25 побед закрывались в среднем на $24.96 (макс $69.40), ни   |
//|  разу не дойдя до полного TP (~$100-120), а все 7 убытков доходили|
//|  почти ровно до полного SL (~$200.93). Реальное соотношение       |
//|  прибыль/убыток получилось ~1:8 вместо задуманного 1:2 — при      |
//|  винрейте 78.1% нужно было ≥89%, чтобы не уйти в минус.           |
//|  ИСПРАВЛЕНО: безубыток/частичное закрытие/трейлинг теперь считают |
//|  пороги как % от РЕАЛЬНОЙ дистанции TP этой сделки (не фикс.      |
//|  пункты) — защита масштабируется вместе с плавающей целью, а не   |
//|  режет прибыль в зародыше при большом TP.                         |
//+------------------------------------------------------------------+
#property copyright   "Custom EA v5.2 CONTINUOUS SCAN — новая гипотеза, требует проверки в тестере"
#property version     "5.20"
#property strict
#property description "XAUUSD Time EA v5.2 — непрерывное сканирование, защита от затухания движения"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;

//--- Входные параметры
input group "=== ИДЕНТИФИКАЦИЯ ==="
input int     InpMagicNumber      = 202520;  // База magic. Реально используется InpMagicNumber+0 (SHORT)
                                              // и InpMagicNumber+1 (LONG). Если планируете НЕСКОЛЬКО
                                              // ИНСТАНСОВ EA — разносите базы минимум на 10.

input group "=== ТОРГОВЫЕ ПАРАМЕТРЫ ==="
input bool    InpUseFixedLot      = true;    // true=фикс.лот InpLotSize, false=риск % от баланса
input double  InpLotSize          = 0.01;
input double  InpRiskPct          = 1.0;     // % риска от баланса (если InpUseFixedLot=false)
input int     InpTakeProfit       = 300;     // TP в пунктах, используется только если InpUseATRStops=false
input int     InpStopLoss         = 1200;    // SL в пунктах, используется только если InpUseATRStops=false

input group "=== ПЛАВАЮЩИЙ SL/TP ПО ATR ==="
input bool    InpUseATRStops      = true;    // true = TP/SL считаются от ATR (переменный размер движения)
input int     InpATRPeriod        = 14;
input double  InpATRSLMult        = 1.8;     // SL = ATR * множитель
input double  InpATRTPMult        = 1.2;     // TP = ATR * множитель
input int     InpMinTPPts         = 50;      // нижняя граница TP (ваше "минимум 50 пунктов")
input int     InpMaxTPPts         = 1000;    // верхняя граница TP (ваше "до 500-1000 пунктов")
input int     InpMinSLPts         = 250;
input int     InpMaxSLPts         = 2000;

input group "=== УПРАВЛЕНИЕ ОТКРЫТОЙ ПОЗИЦИЕЙ (защита прибыли, % от TP сделки) ==="
// НАЙДЕНО НА РЕАЛЬНОМ ТЕСТЕ (лог 2026.06.01-07.16): фиксированные пороги
// +50/+60 пт были откалиброваны под МАЛЕНЬКИЙ TP, а не под реальный
// плавающий TP по ATR (часто ~900-1000 пт). Итог: 25/25 побед закрывались
// в среднем на $24.96 (макс $69.40), ни разу не дойдя до полного TP
// (~$100-120), а все 7 убытков доходили почти ровно до полного SL
// (~$200.93). Реальное соотношение прибыль/убыток получилось ~1:8 вместо
// задуманного 1:2 — при винрейте 78.1% это дало -$782.55 на $1000.
// Исправлено: пороги теперь % от РЕАЛЬНОЙ дистанции TP этой сделки
// (curTP-openPrice), а не фиксированные пункты — масштабируются вместе
// с плавающей целью.
input bool    InpUseBreakEven          = true;
input double  InpBreakEvenAtTPPct      = 25.0;  // профит (% от TP сделки) для переноса SL в БУ
input double  InpBreakEvenLockAtTPPct  = 8.0;   // сколько % от TP фиксируем в безубытке
input bool    InpUsePartialClose       = true;
input double  InpPartialClosePct       = 50.0;  // % объёма закрыть частично
input double  InpPartialCloseAtTPPct   = 60.0;  // на скольки % от TP делать частичное закрытие
input bool    InpUseTrailingStop       = true;
input double  InpTrailingStartAtTPPct  = 70.0;  // профит (% от TP) для начала трейлинга
input double  InpTrailingStepAtTPPct   = 15.0;  // дистанция трейлинга (% от TP) от текущей цены

input group "=== ЗАЩИТА ОТ ЗАТУХАНИЯ ДВИЖЕНИЯ (v5.2) ==="
// "Если цена выросла, но дальше не растёт и колеблется — закрыть в
// прибыль, не отдавать её обратно". Работает ТОЛЬКО пока позиция сейчас
// в прибыли — на позиции в минусе не влияет (убыток идёт своим чередом
// до SL/безубытка, это ожидаемо и НЕ считается проблемой).
// Проверено Python-бэктестом: с фильтром "рынок сейчас боковик" (тот же
// RegimeOK, что и на входе) срабатывало лишь 3 раза из 762 сделок — его
// ADX/диапазон считаются за 8 баров и ещё "помнят" недавний трендовый
// заход, поэтому редко успевают показать боковик за 1-2 бара затухания.
// Без этого фильтра — 22 раза из 762, доп. прибыль ~$148 за год. Фильтр
// по рынку убран, оставлена только сама стагнация (нет нового пика).
input bool    InpUseStallExit       = true;
input int     InpStallBars          = 2;    // баров M15 без нового пика прибыли, чтобы считать "затухло" (~30мин)
input double  InpStallMinAtTPPct    = 15.0; // мин. прибыль (% от TP), чтобы вообще отслеживать стагнацию
input double  InpStallNoiseEpsilonPct = 5.0; // % от TP — допуск на шум, чтобы мелкое дрожание цены не сбрасывало счётчик "без нового пика"

input group "=== ЗАЩИТА КАПИТАЛА ==="
input int     InpMaxConsecutiveLosses = 3;   // 0 = отключено; пауза до понедельника
input bool    InpRequireHedging       = true; // требовать hedging-счёт (иначе INIT_FAILED)

input group "=== НЕПРЕРЫВНОЕ СКАНИРОВАНИЕ ==="
input int     InpConfirmBars       = 4;     // сигнал должен держаться N баров M15 подряд (~1ч) перед входом
input int     InpMoveLookbackBars  = 8;     // окно для расчёта % движения цены (~2ч), баров M15
input int     InpMaxTradesPerDay   = 3;     // максимум сделок в сутки (на весь EA, оба направления вместе)
input int     InpCooldownMinutes   = 60;    // пауза между сделками после открытия любой из них

input group "=== ФИЛЬТР РЕЖИМА РЫНКА (тренд/боковик) ==="
input int     InpRegimeLookbackBars = 8;    // окно для расчёта диапазона цены, баров M15
input double  InpMinRegimeRangePts  = 150;  // мин. диапазон (high-low) за окно, иначе считаем "боковик"

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

//--- Глобальные переменные
datetime g_last_day      = 0;
datetime g_last_bar_time = 0;
datetime g_last_trade_time = 0;
int      g_magic         = 0; // реальное значение берётся из InpMagicNumber в OnInit
int      g_trades_today  = 0;

// Индикаторы
int      h_ma         = INVALID_HANDLE;  // EMA на M15
int      h_ma_h1      = INVALID_HANDLE;  // EMA на H1 (для InpUseH1TrendFilter)
int      h_adx        = INVALID_HANDLE;
int      h_rsi        = INVALID_HANDLE;
int      h_atr        = INVALID_HANDLE;

// Живое состояние сканирования (для панели и для решения о входе)
bool     g_regime_ok        = false;
string   g_regime_detail    = "";
int      g_short_score      = 0;
string   g_short_detail     = "";
int      g_short_confirm    = 0;
int      g_long_score       = 0;
string   g_long_detail      = "";
int      g_long_confirm     = 0;

// Статистика
int      g_total_trades  = 0;
int      g_win_trades    = 0;
int      g_loss_trades   = 0;
double   g_total_profit  = 0.0;
int      g_short_count   = 0;
int      g_long_count    = 0;
int      g_short_wins    = 0;
int      g_long_wins     = 0;

// Защита капитала — общая на весь EA
int      g_consecutive_losses = 0;
bool     g_trading_paused     = false;

ENUM_ORDER_TYPE_FILLING g_fillType = ORDER_FILLING_IOC;

string PANEL_PREFIX = "TimeRev_";

//--- Учёт PnL/управления по каждой позиции (нужно для частичных закрытий)
struct PosPnlEntry  { ulong posId; double pnl; };
struct PosMgmtState
{
   ulong  posId;
   bool   beDone;
   bool   partialDone;
   double peakProfitPts;   // максимальная плавающая прибыль (пт), которую видела эта позиция
   int    barsSincePeak;   // сколько баров M15 подряд пик не обновлялся (для StallExit)
};
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

// Найдено на аудите: без этого суточный лимит InpMaxTradesPerDay сбрасывался
// в 0 при любом перезапуске EA (смена параметра, перезапуск терминала) в
// середине дня — можно было превысить лимит сделок за календарный день.
// Персистентно, как и стоп-машина.
void PersistDailyState()
{
   GlobalVariableSet(GVName("TradesToday"), (double)g_trades_today);
   GlobalVariableSet(GVName("LastDay"), (double)g_last_day);
}

// Под-magic для направления: SHORT = база+0, LONG = база+1.
// Заменяет WindowMagic(w) из v4.9 — окон-подокон больше нет.
int DirectionMagic(int direction)
{
   return (direction == -1) ? (g_magic + 0) : (g_magic + 1);
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
//| ФИЛЬТР РЕЖИМА РЫНКА: тренд/активность vs боковик.                 |
//| ADX должен быть выше порога И диапазон (high-low) за N баров      |
//| должен быть достаточно широким — иначе рынок "стоит на месте",    |
//| сигналы копиться не должны (ваше "часы боковика").                |
//+------------------------------------------------------------------+
bool RegimeOK(string &detail)
{
   double adx = BufferVal(h_adx, 0, 1);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   int highIdx = iHighest(_Symbol, PERIOD_M15, MODE_HIGH, InpRegimeLookbackBars, 1);
   int lowIdx  = iLowest(_Symbol, PERIOD_M15, MODE_LOW, InpRegimeLookbackBars, 1);
   double hi = (highIdx >= 0) ? iHigh(_Symbol, PERIOD_M15, highIdx) : 0.0;
   double lo = (lowIdx  >= 0) ? iLow(_Symbol, PERIOD_M15, lowIdx)  : 0.0;
   double rangePts = (hi > 0.0 && lo > 0.0 && point > 0.0) ? (hi - lo) / point : 0.0;

   bool adxOk   = (adx != EMPTY_VALUE) && (adx > InpMinADX);
   bool rangeOk = (rangePts >= InpMinRegimeRangePts);

   detail = StringFormat("ADX %.1f%s | Диапазон %.0fпт%s",
                          (adx != EMPTY_VALUE ? adx : 0.0), adxOk ? "✅" : "❌",
                          rangePts, rangeOk ? "✅" : "❌");

   return (adxOk && rangeOk);
}

//+------------------------------------------------------------------+
//| ПОДСЧЁТ ФИЛЬТРОВ — единая функция для SHORT (direction=-1,        |
//| фейд роста цены) и LONG (direction=+1, фейд падения цены).        |
//| startPrice теперь берётся из скользящего окна InpMoveLookbackBars |
//| назад (а не из "старта окна анализа", которого больше нет).       |
//+------------------------------------------------------------------+
int CountFilters(int direction, double startPrice, string &outDetail)
{
   int score = 0;
   string detail = "";

   double curPrice = SymbolInfoDouble(_Symbol, direction == -1 ? SYMBOL_BID : SYMBOL_ASK);

   // 1. Движение цены (вверх для SHORT-фейда, вниз для LONG-фейда) за скользящее окно
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
//| Проверка "уже открыта позиция в этом направлении" (по под-magic   |
//| направления). Заменяет HasOpenPositionForWindow(w) из v4.9.       |
//+------------------------------------------------------------------+
bool HasOpenPositionForDirection(int direction)
{
   int wantMagic = DirectionMagic(direction);
   ENUM_POSITION_TYPE wantType = (direction == 1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

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
   g_posMgmt[n].posId         = posId;
   g_posMgmt[n].beDone        = false;
   g_posMgmt[n].partialDone   = false;
   g_posMgmt[n].peakProfitPts = 0.0;
   g_posMgmt[n].barsSincePeak = 0;
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
//| закрытие / трейлинг. Отбираем позиции ЛЮБОГО из наших 2 под-magic |
//| (magic в диапазоне g_magic..g_magic+1).                          |
//+------------------------------------------------------------------+
void ManageOpenPositions(bool isNewBar)
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int    minStop = GetMinStopPoints();

   // Обратный порядок (не 0→N): StallExit ниже может закрыть позицию целиком
   // через trade.PositionClose(), что уменьшает PositionsTotal() и сдвигает
   // индексы. При прямом переборе это могло бы пропустить или обработать
   // дважды соседнюю позицию — при обратном переборе такого сдвига для ещё
   // не посещённых (более ранних) индексов не происходит.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      long posMagic = posInfo.Magic();
      if(posMagic < g_magic || posMagic > g_magic + 1) continue;

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

      // tpDist = реальная дистанция TP ЭТОЙ сделки (в пунктах), а не общий
      // фиксированный вход. Все три порога защиты (безубыток/частичное
      // закрытие/трейлинг) масштабируются от неё — при плавающем TP по ATR
      // цель может быть и 60 пт, и 950 пт, порог должен следовать за ней.
      double tpDist = (curTP != 0.0) ? MathAbs(curTP - openPrice) / point : InpTakeProfit;

      // --- Безубыток ---
      if(InpUseBreakEven && !g_posMgmt[mIdx].beDone &&
         profitPts >= tpDist * (InpBreakEvenAtTPPct / 100.0))
      {
         int lockPts = MathMax((int)MathRound(tpDist * (InpBreakEvenLockAtTPPct / 100.0)), minStop);
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
         profitPts >= tpDist * (InpTrailingStartAtTPPct / 100.0))
      {
         int stepPts = MathMax((int)MathRound(tpDist * (InpTrailingStepAtTPPct / 100.0)), minStop);
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

      // --- Защита от затухания движения (StallExit) ---
      // Обновляем пик прибыли и счётчик "баров без нового пика" РАЗ ЗА БАР
      // (не на каждом тике) — это по сути бар-уровневое понятие, как и
      // подтверждение сигнала на входе. Закрытие по стагнации проверяем
      // только пока позиция СЕЙЧАС в прибыли — если сейчас минус, эта
      // логика не вмешивается, убыток идёт своим чередом до SL/безубытка.
      if(InpUseStallExit && isNewBar)
      {
         // Допуск на шум (epsilon): без него требование "строго новый пик"
         // почти никогда не накапливает подряд идущие "без пика" бары на
         // реально боковом рынке — случайное дрожание цены то и дело чуть
         // обновляет пик, обнуляя счётчик. С допуском мелкий шум не считается
         // прогрессом, и стагнация реально засчитывается.
         double epsPts = tpDist * (InpStallNoiseEpsilonPct / 100.0);
         if(profitPts > g_posMgmt[mIdx].peakProfitPts + epsPts)
         {
            g_posMgmt[mIdx].peakProfitPts = profitPts;
            g_posMgmt[mIdx].barsSincePeak = 0;
         }
         else
         {
            g_posMgmt[mIdx].barsSincePeak++;
         }

         double stallMinPts = tpDist * (InpStallMinAtTPPct / 100.0);
         if(profitPts > 0.0 && profitPts >= stallMinPts &&
            g_posMgmt[mIdx].barsSincePeak >= InpStallBars)
         {
            if(trade.PositionClose(ticket))
            {
               Print("📊 Стагнация (без нового пика ", InpStallBars,
                     " бар.): тикет ", ticket, " закрыт в прибыли, было +",
                     DoubleToString(profitPts, 0), "пт (пик +",
                     DoubleToString(g_posMgmt[mIdx].peakProfitPts, 0), "пт)");
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

   if(!InpUseATRStops && (InpStopLoss <= 0 || InpTakeProfit <= 0))
   {
      Print("❌ ERROR: SL/TP должны быть > 0 (или включите InpUseATRStops)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseATRStops)
   {
      if(InpMinTPPts <= 0 || InpMaxTPPts <= InpMinTPPts ||
         InpMinSLPts <= 0 || InpMaxSLPts <= InpMinSLPts)
      {
         Print("❌ ERROR: InpMin/MaxTPPts и InpMin/MaxSLPts заданы некорректно (Max должен быть > Min)");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(InpATRSLMult <= 0.0 || InpATRTPMult <= 0.0)
      {
         Print("❌ ERROR: InpATRSLMult/InpATRTPMult должны быть > 0");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(InpMinScore < 1 || InpMinScore > 6)
   {
      Print("❌ ERROR: InpMinScore должен быть 1-6");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpConfirmBars <= 0)
   {
      Print("❌ ERROR: InpConfirmBars должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMoveLookbackBars <= 0 || InpRegimeLookbackBars <= 0)
   {
      Print("❌ ERROR: InpMoveLookbackBars и InpRegimeLookbackBars должны быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxTradesPerDay <= 0)
   {
      Print("❌ ERROR: InpMaxTradesPerDay должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpCooldownMinutes < 0)
   {
      Print("❌ ERROR: InpCooldownMinutes не может быть отрицательным");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpMaxConsecutiveLosses < 0)
   {
      Print("❌ ERROR: InpMaxConsecutiveLosses не может быть отрицательным");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseStallExit && (InpStallBars <= 0 || InpStallMinAtTPPct <= 0.0 || InpStallNoiseEpsilonPct < 0.0))
   {
      Print("❌ ERROR: InpStallBars и InpStallMinAtTPPct должны быть > 0, InpStallNoiseEpsilonPct ≥ 0");
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
      if(InpBreakEvenAtTPPct <= 0.0 || InpBreakEvenLockAtTPPct <= 0.0)
      {
         Print("❌ ERROR: InpBreakEvenAtTPPct и InpBreakEvenLockAtTPPct должны быть > 0");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(InpBreakEvenLockAtTPPct >= InpBreakEvenAtTPPct)
      {
         Print("❌ ERROR: InpBreakEvenLockAtTPPct должен быть МЕНЬШЕ InpBreakEvenAtTPPct ",
               "(иначе SL попытается встать за пределы текущей цены)");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(InpUseTrailingStop)
   {
      if(InpTrailingStartAtTPPct <= 0.0 || InpTrailingStepAtTPPct <= 0.0)
      {
         Print("❌ ERROR: InpTrailingStartAtTPPct и InpTrailingStepAtTPPct должны быть > 0");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(InpUseBreakEven && InpTrailingStartAtTPPct < InpBreakEvenAtTPPct)
      {
         Print("❌ ERROR: InpTrailingStartAtTPPct должен быть ≥ InpBreakEvenAtTPPct ",
               "(трейлинг стартует после безубытка)");
         return INIT_PARAMETERS_INCORRECT;
      }
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
   h_atr   = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
   // H1, а не M15: ATR с того же таймфрейма, что и вход, почти равен размаху
   // ОДНОГО M15-бара — цель TP тогда достигается за 0-1 бар (проверено бэктестом:
   // 91% сделок закрывались за 0-1 бар M15, т.е. это шум, а не "движение за 1-2 часа").
   // H1 ATR отражает размах целого часа, что и даёт TP/SL нужный масштаб.

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
   g_last_bar_time = 0;
   g_last_trade_time = 0;
   g_trades_today = 0;
   g_short_confirm = 0;
   g_long_confirm = 0;
   g_consecutive_losses = 0;
   g_trading_paused = false;

   if(GlobalVariableCheck(GVName("Paused")))
      g_trading_paused = (GlobalVariableGet(GVName("Paused")) != 0.0);
   if(GlobalVariableCheck(GVName("ConsecLosses")))
      g_consecutive_losses = (int)GlobalVariableGet(GVName("ConsecLosses"));

   // Восстанавливаем суточный лимит сделок, только если сохранённый "последний
   // день" — СЕГОДНЯ (иначе это старое значение от прошлого дня, законно 0).
   if(GlobalVariableCheck(GVName("LastDay")) && GlobalVariableCheck(GVName("TradesToday")))
   {
      datetime savedDay = (datetime)GlobalVariableGet(GVName("LastDay"));
      MqlDateTime nowDt;
      TimeToStruct(TimeCurrent(), nowDt);
      datetime todayNow = StringToTime(
         StringFormat("%04d.%02d.%02d 00:00", nowDt.year, nowDt.mon, nowDt.day));
      if(savedDay == todayNow)
      {
         g_last_day = savedDay;
         g_trades_today = (int)GlobalVariableGet(GVName("TradesToday"));
         if(g_trades_today > 0)
            Print("🔁 Восстановлено число сделок за сегодня после перезапуска: ", g_trades_today,
                  "/", InpMaxTradesPerDay);
      }
   }
   if(g_trading_paused)
      Print("🔁 Восстановлено состояние стоп-машины после перезапуска: ПАУЗА (",
            g_consecutive_losses, " убытков подряд)");

   ArrayResize(g_posPnl, 0);
   ArrayResize(g_posMgmt, 0);

   EventSetTimer(1);

   Print("════════════════════════════════════════════");
   Print("XAUUSD Time EA v5.0 CONTINUOUS SCAN запущен | magic-база=", g_magic,
         " (SHORT=", DirectionMagic(-1), " LONG=", DirectionMagic(1), ")");
   Print("Непрерывное сканирование M15: подтверждение сигнала ", InpConfirmBars,
         " баров (~", InpConfirmBars * 15, " мин)");
   Print("Мин счёт фильтров: ", InpMinScore, "/6 | Режим рынка: ADX>", InpMinADX,
         " И диапазон≥", InpMinRegimeRangePts, "пт за ", InpRegimeLookbackBars, " баров");
   if(InpUseATRStops)
      Print("TP/SL: плавающие по ATR (SL x", InpATRSLMult, " TP x", InpATRTPMult,
            "), ограничены TP[", InpMinTPPts, "-", InpMaxTPPts, "] SL[",
            InpMinSLPts, "-", InpMaxSLPts, "] пт");
   else
      Print("TP/SL: фиксированные ", InpTakeProfit, "/", InpStopLoss, " пт");
   Print("Безубыток от ", InpBreakEvenAtTPPct, "% TP (фикс ", InpBreakEvenLockAtTPPct,
         "% TP) | Частичное закрытие: ", (InpUsePartialClose ? "ON" : "OFF"),
         " | Трейлинг от ", InpTrailingStartAtTPPct, "% TP: ", (InpUseTrailingStop ? "ON" : "OFF"));
   if(InpUseStallExit)
      Print("StallExit: если в прибыли ≥", InpStallMinAtTPPct, "% TP и ", InpStallBars,
            " бар. без нового пика + боковик — закрыть в прибыль");
   Print("Лимит сделок/день: ", InpMaxTradesPerDay, " | Кулдаун между сделками: ",
         InpCooldownMinutes, " мин");
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
      GlobalVariableDel(GVName("TradesToday"));
      GlobalVariableDel(GVName("LastDay"));
   }

   Print("════════════════════════════════════════════");
   Print("EA v5.0 остановлен");
   Print("Сделок: ", g_total_trades,
         " (S:", g_short_count, " L:", g_long_count, ")");
   Print("Win: ", g_win_trades, " | Loss: ", g_loss_trades);
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
//| OnTick — непрерывное сканирование. На каждом новом баре M15       |
//| пересчитываем режим рынка и счёт фильтров по обоим направлениям,   |
//| копим "подтверждение" (confirm bars). Когда подтверждение          |
//| накопилось — пробуем открыть сделку (с учётом лимита/кулдауна/     |
//| паузы/спреда/новостей).                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // isNewBar считается ДО ManageOpenPositions(), т.к. StallExit внутри
   // неё обновляет "пик прибыли/баров без пика" раз за бар, а не на
   // каждом тике. g_last_bar_time ещё не обновлён на этом месте (это
   // происходит ниже), поэтому значение здесь корректно.
   datetime curBarTime = iTime(_Symbol, PERIOD_M15, 0);
   bool isNewBar = (curBarTime != g_last_bar_time);

   ManageOpenPositions(isNewBar);

   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   datetime todayStart = StringToTime(
      StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
   if(todayStart != g_last_day)
   {
      g_trades_today = 0;
      g_short_confirm = 0;
      g_long_confirm = 0;
      g_last_day = todayStart;
      PersistDailyState();
      Print("🌅 Новый день: ", TimeToString(todayStart, TIME_DATE));

      if(dt.day_of_week == 1 && g_trading_paused)
      {
         g_trading_paused = false;
         g_consecutive_losses = 0;
         PersistCircuitBreaker();
         Print("🔓 Новая торговая неделя — торговля возобновлена");
      }
   }

   // ВАЖНО: попытка входа делается ТОЛЬКО раз за бар (внутри isNewBar), а не на
   // каждом тике. Раньше (до аудита) проверка входа шла в OnTick() отдельно от
   // isNewBar — если OpenPosition() не срабатывал (реквот, "торговый контекст
   // занят", временная нехватка маржи), EA пытался открыть сделку ПОВТОРНО на
   // КАЖДОМ следующем тике того же бара (а тиков может быть десятки в секунду),
   // без какой-либо паузы между попытками — риск завалить сервер брокера
   // повторными запросами и захламить журнал одинаковыми ошибками. Теперь одна
   // попытка на бар, следующая — только на следующем новом баре.
   if(isNewBar)
   {
      g_last_bar_time = curBarTime;

      g_regime_ok = RegimeOK(g_regime_detail);

      double lookbackPrice = iClose(_Symbol, PERIOD_M15, InpMoveLookbackBars);

      g_short_score = CountFilters(-1, lookbackPrice, g_short_detail);
      g_long_score  = CountFilters(1,  lookbackPrice, g_long_detail);

      if(g_regime_ok && g_short_score >= InpMinScore)
         g_short_confirm = MathMin(g_short_confirm + 1, InpConfirmBars);
      else
         g_short_confirm = 0;

      if(g_regime_ok && g_long_score >= InpMinScore)
         g_long_confirm = MathMin(g_long_confirm + 1, InpConfirmBars);
      else
         g_long_confirm = 0;

      // ---------- Проверка возможности входа (общие условия) ----------
      bool canTradeNow = true;
      if(g_trading_paused) canTradeNow = false;
      if(g_trades_today >= InpMaxTradesPerDay) canTradeNow = false;
      if(InpCooldownMinutes > 0 && g_last_trade_time != 0 &&
         (serverTime - g_last_trade_time) < (long)InpCooldownMinutes * 60) canTradeNow = false;

      if(canTradeNow)
      {
         // ---------- SHORT ----------
         if(g_short_confirm >= InpConfirmBars && !HasOpenPositionForDirection(-1))
         {
            if(SpreadOK() && CalendarClear())
            {
               if(OpenPosition(-1, DirectionMagic(-1)))
               {
                  g_short_confirm = 0;
                  g_trades_today++;
                  PersistDailyState();
                  g_last_trade_time = serverTime;
                  g_total_trades++;
                  g_short_count++;
               }
            }
         }

         // ---------- LONG ----------
         if(g_long_confirm >= InpConfirmBars && !HasOpenPositionForDirection(1))
         {
            if(SpreadOK() && CalendarClear())
            {
               if(OpenPosition(1, DirectionMagic(1)))
               {
                  g_long_confirm = 0;
                  g_trades_today++;
                  PersistDailyState();
                  g_last_trade_time = serverTime;
                  g_total_trades++;
                  g_long_count++;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Открытие позиции под magic конкретного направления. TP/SL         |
//| плавающие по ATR (если InpUseATRStops), ограничены коридором      |
//| InpMin/MaxTPPts и InpMin/MaxSLPts.                                 |
//+------------------------------------------------------------------+
bool OpenPosition(int direction, int magicForTrade)
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
         slPts = (int)MathMax(InpMinSLPts, MathMin(InpMaxSLPts, slPts));
         tpPts = (int)MathMax(InpMinTPPts, MathMin(InpMaxTPPts, tpPts));
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

   string label = (direction == -1) ? "SHORT" : "LONG";
   Print(direction > 0 ? "📈 BUY (" : "📉 SELL (", label, ")",
         " | Цена=", DoubleToString(entry, digits),
         " SL=", DoubleToString(sl, digits), " (", slPts, "пт)",
         " TP=", DoubleToString(tp, digits), " (", tpPts, "пт)",
         " Лот=", DoubleToString(lot, 2),
         " Magic=", magicForTrade);

   bool ok;
   if(direction == 1)
      ok = trade.Buy(lot, _Symbol, entry, sl, tp, "v5.0 " + label);
   else
      ok = trade.Sell(lot, _Symbol, entry, sl, tp, "v5.0 " + label);

   if(!ok)
   {
      Print("❌ Ошибка: ", trade.ResultRetcode(),
            " — ", trade.ResultRetcodeDescription());
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| OnTradeTransaction — учёт win/loss. Магic-фильтр — диапазон       |
//| g_magic..g_magic+1 (SHORT и LONG под-magic).                      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;

   long dealMagic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(dealMagic < g_magic || dealMagic > g_magic + 1) return;

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
//| ПАНЕЛЬ — фон + текст. Показывает live-статус сканирования:        |
//| режим рынка, счёт фильтров SHORT/LONG и прогресс подтверждения.   |
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

void DrawPanel()
{
   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   double winRate = 0.0;
   if(g_total_trades > 0)
      winRate = 100.0 * g_win_trades / g_total_trades;
   double spread = GetSpread();

   string texts[40];
   color  colors[40];
   int n = 0;

   texts[n] = "═══ XAUUSD Scan v5.0 ═══"; colors[n] = InpColorTitle; n++;
   texts[n] = StringFormat("Время: %02d:%02d  |  Magic-база: %d", dt.hour, dt.min, g_magic);
   colors[n] = InpColorText; n++;
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = "─── РЕЖИМ РЫНКА ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("%s %s", g_regime_ok ? "✅ Тренд/активность" : "⛔ Боковик", g_regime_detail);
   colors[n] = g_regime_ok ? InpColorGood : InpColorBad; n++;
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = "─── SHORT (фейд роста) ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Счёт: %d/6 | Подтверждение: %d/%d",
                            g_short_score, g_short_confirm, InpConfirmBars);
   colors[n] = (g_short_confirm >= InpConfirmBars) ? InpColorGood : InpColorWaiting; n++;
   texts[n] = g_short_detail; colors[n] = InpColorText; n++;
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = "─── LONG (фейд падения) ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Счёт: %d/6 | Подтверждение: %d/%d",
                            g_long_score, g_long_confirm, InpConfirmBars);
   colors[n] = (g_long_confirm >= InpConfirmBars) ? InpColorGood : InpColorWaiting; n++;
   texts[n] = g_long_detail; colors[n] = InpColorText; n++;
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = "─── СТАТУС ВХОДА ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Сделок сегодня: %d/%d", g_trades_today, InpMaxTradesPerDay);
   colors[n] = InpColorNeutral; n++;
   if(InpCooldownMinutes > 0 && g_last_trade_time != 0)
   {
      long remainSec = (long)InpCooldownMinutes * 60 - (serverTime - g_last_trade_time);
      if(remainSec > 0)
      {
         texts[n] = StringFormat("Кулдаун: ещё %d мин", (int)(remainSec / 60) + 1);
         colors[n] = InpColorWaiting; n++;
      }
   }
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = "─── СТАТИСТИКА ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Сделок: %d (S:%d L:%d)", g_total_trades, g_short_count, g_long_count);
   colors[n] = InpColorText; n++;
   texts[n] = StringFormat("Win: %d | Loss: %d (%.0f%%)", g_win_trades, g_loss_trades, winRate);
   colors[n] = InpColorText; n++;
   texts[n] = StringFormat("PnL: $%.2f", g_total_profit);
   colors[n] = (g_total_profit >= 0 ? InpColorGood : InpColorBad); n++;
   texts[n] = StringFormat("Серия убытков: %d/%d", g_consecutive_losses,
                            InpMaxConsecutiveLosses);
   colors[n] = (g_trading_paused ? InpColorBad : InpColorNeutral); n++;
   if(g_trading_paused)
   { texts[n] = "⛔ ТОРГОВЛЯ ПРИОСТАНОВЛЕНА до понедельника"; colors[n] = InpColorBad; n++; }
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = StringFormat("Spread: %.0fpts", spread);
   colors[n] = InpColorNeutral; n++;

   if(InpDarkBackground) DrawPanelBackground(n);
   for(int i = 0; i < n; i++)
      DrawPanelLine(i, texts[i], colors[i]);

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
