//+------------------------------------------------------------------+
//|                        vMoneixau_EA v5.4                          |
//|                                                                  |
//|  CHANGELOG v5.4 — по факту из реального прогона: "были 4 свечи    |
//|  подряд красные, а код открыл лонг — и, конечно, будет стоп, если |
//|  рынок падает". Разбор: шаги 1-4 (H4-зона/структура свингов →     |
//|  сессия/MA → M5-зоны → пробой M5-зоны с закрытием) НИ ОДИН из них  |
//|  не проверяет НЕПОСРЕДСТВЕННУЮ свечную динамику прямо перед        |
//|  входом. Пробой M5-зоны технически мог сработать (цена закрылась  |
//|  выше уровня сопротивления на M5), даже если последние несколько   |
//|  M5-свечей ДО этого явно падали — код фиксировал факт пробоя, но   |
//|  не проверял, действительно ли непосредственный импульс уже        |
//|  развернулся в нашу сторону, а не идёт против.                     |
//|                                                                  |
//|  ДОБАВЛЕНО: RecentCandlesAgree() — прямо перед входом (шаг 4)      |
//|  проверяем последние InpMomentumLookback закрытых M5-свечей         |
//|  (по умолчанию 4 — как в вашем примере). Если ВСЕ они против        |
//|  направления сделки (все красные перед лонгом, все зелёные перед   |
//|  шортом) — вход отменяется, даже если пробой зоны формально         |
//|  произошёл. Это и есть "определять направление рынка и открывать   |
//|  позицию ПО направлению рынка", а не против недавнего импульса,    |
//|  который ещё не развернулся.                                       |
//+------------------------------------------------------------------+
//|  Новая, отдельная стратегия (не связана с XAUUSD_TimeStrategy_EA  |
//|  v4.x/v5.x) — реализация методики, которую вы описали текстом, в  |
//|  четыре шага:                                                     |
//|                                                                  |
//|  ШАГ 1 (самый важный): на H4 находим зоны поддержки/сопротивления |
//|  — уровни, где цена НЕСКОЛЬКО РАЗ касалась и отскакивала. Зона     |
//|  берётся "от тела свечи до тени" (для сопротивления: от макс.     |
//|  тела касавшихся свечей до макс. хая; для поддержки — от мин.     |
//|  тела до мин. лоу). Торгуем ТОЛЬКО внутри коридора между ближним  |
//|  сопротивлением сверху и ближней поддержкой снизу. ГЛАВНОЕ         |
//|  ПРАВИЛО: у сопротивления НИКОГДА не покупаем — только продаём;    |
//|  у поддержки НИКОГДА не продаём — только покупаем (фейд краёв      |
//|  диапазона, не пробой). Дополнительное подтверждение — структура   |
//|  свингов: 2 восходящих свинг-хая + 2 восходящих свинг-лоу (HH+HL)  |
//|  подтверждают лонг у поддержки; 2 нисходящих (LH+LL) подтверждают  |
//|  шорт у сопротивления.                                             |
//|                                                                  |
//|  ШАГ 2: торгуем только в окне сессии (по умолчанию открытие        |
//|  Нью-Йоркской сессии по времени сервера — настройте            |
//|  InpSessionStartHour/Minute под ваш брокер) и НЕ входим на первой  |
//|  M5-свече после открытия окна (пропускаем возможную манипуляцию). |
//|  Индикатор-фильтр "Импульс" — обычная скользящая средняя (период   |
//|  50 по умолчанию, как в вашем описании): цена выше неё — только    |
//|  лонг, ниже — только шорт.                                        |
//|                                                                  |
//|  ШАГ 3: та же логика зон поддержки/сопротивления, но на младшем    |
//|  таймфрейме (M5 — ровно как вы описали), внутри H4-коридора.       |
//|                                                                  |
//|  ШАГ 4: вход — когда M5-свеча ЗАКРЫВАЕТСЯ за пределами M5-зоны в   |
//|  сторону, разрешённую шагами 1-2 (т.е. подтверждённый пробой       |
//|  локальной M5-зоны в направлении общего фейд-сетапа). Это и есть   |
//|  ваш пример "пробили сопротивление на M5, свеча закрылась выше —   |
//|  подтверждение для лонга".                                        |
//|                                                                  |
//|  ⚠️ ЧЕСТНО О ПРЕВРАЩЕНИИ ДИСКРЕЦИОННОЙ МЕТОДИКИ В КОД: ваше         |
//|  описание — визуальное, "на глаз" (сколько касаний считать зоной,  |
//|  насколько близко цена должна быть к зоне и т.д.). Я формализовал  |
//|  это конкретными параметрами (InpH4ZoneClusterPts,                |
//|  InpH4MinTouches, InpZoneProximityPts и т.д.) — они ПРИБЛИЖЕНИЕ    |
//|  вашего визуального суждения, не точная копия. Настройте их под    |
//|  то, что видите на графике глазами — это нормально и ожидаемо.     |
//|  Это НОВАЯ, НИКОГДА РАНЕЕ НЕ ТЕСТИРОВАННАЯ стратегия — у неё нет    |
//|  истории реальных прогонов, в отличие от XAUUSD_TimeStrategy_EA.   |
//|  Проверил идею Python-бэктестом (см. отчёт после кода) на M15-     |
//|  данных (H4 — ресемпл из M15; "M5" в бэктесте приближён M15-барами,|
//|  т.к. у меня нет отдельного файла M5-истории — сам EA в реальном   |
//|  MT5 использует НАСТОЯЩИЙ M5). Прогоните сами в Strategy Tester,   |
//|  прежде чем доверять живые деньги.                                |
//+------------------------------------------------------------------+
#property copyright   "vMoneixau v5.4 — новая стратегия, требует проверки в тестере"
#property version     "5.40"
#property strict
#property description "vMoneixau v5.4 — H4 зоны + структура свингов + сессия/MA + M5 пробой + согласие импульса"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade        trade;
CPositionInfo posInfo;

//--- Входные параметры
input group "=== ИДЕНТИФИКАЦИЯ ==="
input int     InpMagicNumber        = 202600;

input group "=== ШАГ 1: ЗОНЫ H4 + СТРУКТУРА СВИНГОВ ==="
// НАЙДЕНО (диагностика после жалобы "почему код не открывает сделки"): золото
// весь этот год было в сильном тренде, а не в боковике. "Ближайшая зона сверху/
// снизу" в такие периоды часто оказывается СТАРЫМ уровнем за много месяцев —
// медианная ширина между такими зонами получилась ~7564 пт, а медианное
// расстояние цены до ближайшей зоны — ~1622 пт (при старом InpZoneProximityPts
// =150 это почти никогда не срабатывало). Добавлен InpMaxRangeWidthPts —
// диапазон засчитывается, только если он ДЕЙСТВИТЕЛЬНО узкий (реальный боковик,
// а не два случайных далёких уровня). Также расширены InpZoneProximityPts и
// InpSessionWindowMinutes — раньше они сильно резали и без того редкие сигналы.
input int     InpH4PivotLegBars     = 3;    // баров слева/справа для фрактального свинга на H4
input int     InpH4LookbackBars     = 150;  // сколько H4-баров назад искать зоны (~25 дней)
input double  InpH4ZoneClusterPts   = 300;  // касания в пределах этого расстояния — одна зона
input int     InpH4MinTouches       = 2;    // мин. касаний, чтобы зона считалась подтверждённой
input double  InpZoneProximityPts   = 400;  // насколько близко цена должна быть к H4-зоне (было 150)
input double  InpMaxRangeWidthPts   = 3000; // макс. ширина H4-диапазона — иначе это не реальный боковик
input int     InpSwingConfirmCount  = 2;    // сколько последних свинг-хаев/лоу проверяем на направление

input group "=== ШАГ 2: СЕССИЯ И ИНДИКАТОР 'ИМПУЛЬС' ==="
input int     InpSessionStartHour   = 16;   // начало торгового окна (время сервера — настройте под NY-открытие у вашего брокера)
input int     InpSessionStartMinute = 30;
input int     InpSessionWindowMinutes = 600; // сколько минут после старта окна ищем сделки (было 240)
input bool    InpSkipFirstCandle    = true; // не входить на первой M5-свече после открытия окна
input int     InpMAPeriod           = 50;   // период индикатора "Импульс" (обычная MA)
input ENUM_MA_METHOD InpMAMethod    = MODE_SMA;

input group "=== ШАГ 3-4: ЗОНЫ НА M5 + ПРОБОЙ С ПОДТВЕРЖДЁННЫМ ЗАКРЫТИЕМ ==="
input int     InpLtfPivotLegBars    = 2;
input int     InpLtfLookbackBars    = 150;  // M5-баров назад (~12.5 часов)
input double  InpLtfZoneClusterPts  = 80;
input int     InpLtfMinTouches      = 2;

input group "=== СОГЛАСИЕ НЕДАВНЕГО ИМПУЛЬСА (v5.4, по запросу) ==="
// "Определять направление рынка и открывать позицию ПО направлению рынка".
// Пробой M5-зоны формально мог сработать, даже если последние несколько
// M5-свечей ДО этого явно шли против сделки (например, 4 красные свечи
// подряд перед входом в лонг). Эта проверка отменяет вход, если ВСЕ
// последние InpMomentumLookback свечи против направления сделки.
input bool    InpRequireMomentumAgree = true;
input int     InpMomentumLookback     = 4;  // сколько последних M5-свечей проверяем (ваш пример — 4)

input group "=== СДЕЛКА (TP/SL — по запросу) ==="
input bool    InpUseFixedLot        = true;
input double  InpLotSize            = 0.1;
input double  InpRiskPct            = 1.0;   // % риска от баланса (если InpUseFixedLot=false)
input double  InpSLBufferPts        = 50;    // буфер за пределы H4-зоны для стоп-лосса
input int     InpMaxSLPts           = 2500;  // максимум для SL (ваше "стоп до 2500 пунктов")
input double  InpTPAtOppositeZonePct = 80.0; // % пути до противоположной H4-зоны — там базовый TP (потолок)
input int     InpMinTPPts           = 50;    // минимум для TP (ваше "минимум тейк 50 пунктов")
input int     InpMaxTPPts           = 1000;  // максимум для TP (ваше "до 1000 пунктов максимум тейк")
input int     InpMaxHoldMinutes     = 90;    // макс. время удержания сделки (ваше "40 мин - 1.5 часа")

input group "=== ДИНАМИЧЕСКАЯ ФИКСАЦИЯ ПРИБЫЛИ ПРИ СТАГНАЦИИ (по запросу) ==="
// "Тейк должен брать так: если поднялся в плюс минимум до 50 и прыгает от 50 до
// 800 — закрыть в прибыль, если цена долго стоит от 5 до 30 минут, взять
// лучший тейк по ситуации." Реализовано так: чем БОЛЬШЕ прибыль внутри этого
// коридора (ближе к InpStallUpperRefPts), тем МЕНЬШЕ терпения нужно, чтобы
// зафиксировать её (InpStallMinMinutes) — крупную прибыль рискованно ждать
// долго. Чем МЕНЬШЕ прибыль (ближе к InpMinTPPts), тем больше терпения
// (InpStallMaxMinutes) — даём мелкой прибыли шанс дорасти. "Простояла" —
// значит пик прибыли не обновлялся (с допуском на шум InpStallEpsilonPts).
input bool    InpUseStallExit       = true;
input double  InpStallUpperRefPts   = 800;  // верхняя граница "прыгает от 50 до 800"
input int     InpStallMinMinutes    = 5;    // требуемая стагнация при прибыли ~InpStallUpperRefPts
input int     InpStallMaxMinutes    = 30;   // требуемая стагнация при прибыли ~InpMinTPPts
input double  InpStallEpsilonPts    = 20;   // допуск на шум для "новый пик"

input group "=== ЗАЩИТА КАПИТАЛА ==="
input int     InpMaxConsecutiveLosses = 3;
input bool    InpRequireHedging       = true;

input group "=== ЗАЩИТНЫЕ ФИЛЬТРЫ ==="
input int     InpMaxSpread          = 80;
input bool    InpUseCalendar        = true;
input int     InpNewsBlockMins      = 30;

input group "=== ОТОБРАЖЕНИЕ ==="
input bool    InpShowInfo           = true;
input int     InpPanelX             = 15;
input int     InpPanelY             = 30;
input int     InpPanelFontSize      = 11;
input string  InpPanelFontName      = "Consolas";
input color   InpColorTitle         = clrAqua;
input color   InpColorHeader        = clrGold;
input color   InpColorText          = clrWhite;
input color   InpColorGood          = clrLime;
input color   InpColorBad           = clrTomato;
input color   InpColorNeutral       = clrLightGray;
input bool    InpDarkBackground     = true;

//--- Структуры зон и свингов
struct SwingPoint
{
   datetime time;
   double   price;    // экстремум (хай для свинг-хая, лоу для свинг-лоу)
   double   bodyEdge; // ближайший край тела свечи (max(open,close) для хая, min(open,close) для лоу)
   bool     isHigh;
};

struct SRZone
{
   double lo;
   double hi;
   int    touches;
   bool   isResistance;
   double anchor;  // цена ПЕРВОГО свинга, создавшего зону — новые касания
                    // сравниваются с ней, а не с текущим (уже расширенным)
                    // центром, иначе зона может "расползтись" на всю историю
                    // при медленном дрейфе цены (см. ClusterZones).
};

SwingPoint g_h4Swings[];
SRZone     g_h4Zones[];
SwingPoint g_ltfSwings[];
SRZone     g_ltfZones[];

datetime g_last_h4_bar   = 0;
datetime g_last_ltf_bar  = 0;
datetime g_last_day      = 0;

int      g_magicLong  = 0;
int      g_magicShort = 0;

int      h_ma = INVALID_HANDLE;

// Статистика
int      g_total_trades = 0;
int      g_win_trades   = 0;
int      g_loss_trades  = 0;
double   g_total_profit = 0.0;
int      g_consecutive_losses = 0;
bool     g_trading_paused     = false;

ENUM_ORDER_TYPE_FILLING g_fillType = ORDER_FILLING_IOC;
string PANEL_PREFIX = "vMoneixau_";

// Живой статус для панели
bool     g_haveRange   = false;
SRZone   g_curRes, g_curSup;
int      g_swingBias   = 0;
bool     g_maLong = false, g_maShort = false;
bool     g_inSession = false;
string   g_lastSignalDetail = "";

struct PosPnlEntry  { ulong posId; double pnl; };
PosPnlEntry g_posPnl[];

// Для динамической фиксации прибыли при стагнации (StallExit)
struct PosStallState { ulong posId; double peakPts; datetime peakTime; };
PosStallState g_posStall[];

int GetOrCreateStall(ulong posId)
{
   for(int i = 0; i < ArraySize(g_posStall); i++)
      if(g_posStall[i].posId == posId) return i;
   int n = ArraySize(g_posStall);
   ArrayResize(g_posStall, n + 1);
   g_posStall[n].posId = posId;
   g_posStall[n].peakPts = 0.0;
   g_posStall[n].peakTime = TimeCurrent();
   return n;
}

void RemoveStallState(ulong posId)
{
   for(int i = 0; i < ArraySize(g_posStall); i++)
      if(g_posStall[i].posId == posId) { ArrayRemove(g_posStall, i, 1); return; }
}

//+------------------------------------------------------------------+
//| УТИЛИТЫ (общие, как в предыдущих EA)                              |
//+------------------------------------------------------------------+
string GVName(string suffix)
{
   return "vMoneixau_" + _Symbol + "_" + IntegerToString(InpMagicNumber) + "_" + suffix;
}

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
   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
}

bool SpreadOK()
{
   double spread = GetSpread();
   if(spread > InpMaxSpread)
   {
      Print("⚠️ Спред=", DoubleToString(spread, 1), "pts > макс ", InpMaxSpread);
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
      if(ev.importance == CALENDAR_IMPORTANCE_HIGH) { Print("📰 Блок USD: '", ev.name, "'"); return false; }
   }
   for(int i = 0; i < n2; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(v2[i].event_id, ev)) continue;
      if(ev.importance == CALENDAR_IMPORTANCE_HIGH) { Print("📰 Блок XAU: '", ev.name, "'"); return false; }
   }
   return true;
}

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
   if(lot < lotMin) { Print("❌ Лот < lotMin"); return 0.0; }
   if(lot > lotMax) lot = lotMax;

   double margin = 0.0;
   ENUM_ORDER_TYPE oType = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(oType, _Symbol, lot, price, margin))
   {
      double free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(margin > free * 0.9)
      {
         Print("❌ Недостаточно маржи: $", DoubleToString(margin, 2), " > 90% свободной $", DoubleToString(free, 2));
         return 0.0;
      }
   }
   return lot;
}

double CalcLotByRisk(double slPoints)
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

double BufferVal(int handle, int bufIdx, int shift)
{
   if(handle == INVALID_HANDLE) return EMPTY_VALUE;
   double v[1];
   if(CopyBuffer(handle, bufIdx, shift, 1, v) != 1) return EMPTY_VALUE;
   return v[0];
}

void AddPosPnl(ulong posId, double pnl)
{
   for(int i = 0; i < ArraySize(g_posPnl); i++)
      if(g_posPnl[i].posId == posId) { g_posPnl[i].pnl += pnl; return; }
   int n = ArraySize(g_posPnl);
   ArrayResize(g_posPnl, n + 1);
   g_posPnl[n].posId = posId;
   g_posPnl[n].pnl   = pnl;
}

double PopPosPnl(ulong posId)
{
   for(int i = 0; i < ArraySize(g_posPnl); i++)
      if(g_posPnl[i].posId == posId)
      {
         double v = g_posPnl[i].pnl;
         ArrayRemove(g_posPnl, i, 1);
         return v;
      }
   return 0.0;
}

//+------------------------------------------------------------------+
//| ШАГ 1/3: поиск фрактальных свингов на любом таймфрейме             |
//+------------------------------------------------------------------+
void SortSwingsByTime(SwingPoint &arr[])
{
   int n = ArraySize(arr);
   for(int i = 1; i < n; i++)
   {
      SwingPoint key = arr[i];
      int j = i - 1;
      while(j >= 0 && arr[j].time > key.time)
      {
         arr[j+1] = arr[j];
         j--;
      }
      arr[j+1] = key;
   }
}

void DetectSwings(ENUM_TIMEFRAMES tf, int legBars, int lookbackBars, SwingPoint &out[])
{
   ArrayResize(out, 0);
   for(int shift = legBars + 1; shift <= lookbackBars + legBars; shift++)
   {
      double h = iHigh(_Symbol, tf, shift);
      double l = iLow(_Symbol, tf, shift);
      if(h <= 0.0 || l <= 0.0) continue;

      bool isSwingHigh = true;
      bool isSwingLow  = true;
      for(int k = 1; k <= legBars; k++)
      {
         double hL = iHigh(_Symbol, tf, shift - k);
         double hR = iHigh(_Symbol, tf, shift + k);
         double lL = iLow(_Symbol, tf, shift - k);
         double lR = iLow(_Symbol, tf, shift + k);
         if(hL > h || hR > h) isSwingHigh = false;
         if(lL < l || lR < l) isSwingLow  = false;
      }

      if(isSwingHigh)
      {
         int n = ArraySize(out);
         ArrayResize(out, n + 1);
         out[n].time     = iTime(_Symbol, tf, shift);
         out[n].price    = h;
         out[n].bodyEdge = MathMax(iOpen(_Symbol, tf, shift), iClose(_Symbol, tf, shift));
         out[n].isHigh   = true;
      }
      if(isSwingLow)
      {
         int n = ArraySize(out);
         ArrayResize(out, n + 1);
         out[n].time     = iTime(_Symbol, tf, shift);
         out[n].price    = l;
         out[n].bodyEdge = MathMin(iOpen(_Symbol, tf, shift), iClose(_Symbol, tf, shift));
         out[n].isHigh   = false;
      }
   }
   SortSwingsByTime(out);
}

//+------------------------------------------------------------------+
//| Кластеризация свингов в зоны поддержки/сопротивления              |
//| (касания в пределах clusterPts считаем одной и той же зоной,      |
//| зона = от тела свечи до тени, как вы описали).                   |
//|                                                                  |
//| ВАЖНО: новое касание сравнивается с ANCHOR (цена первого свинга,  |
//| создавшего зону), а НЕ с текущим центром зоны. Раньше сравнение   |
//| шло с центром, который сам сдвигается при каждом расширении зоны |
//| — из-за этого при медленном дрейфе цены (серия свингов, каждый   |
//| чуть дальше предыдущего) зона могла "расползаться" бесконечно,    |
//| склеивая на самом деле РАЗНЫЕ уровни в одну гигантскую зону и     |
//| ломая определение диапазона (и, соответственно, направления      |
//| сделок — зона резистанса могла случайно "дорасти" почти до зоны   |
//| поддержки).                                                       |
//+------------------------------------------------------------------+
void ClusterZones(SwingPoint &swings[], double clusterPts, int minTouches, SRZone &zones[])
{
   ArrayResize(zones, 0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double clusterDist = clusterPts * point;

   for(int i = 0; i < ArraySize(swings); i++)
   {
      bool matched = false;
      for(int z = 0; z < ArraySize(zones); z++)
      {
         if(zones[z].isResistance != swings[i].isHigh) continue;
         if(MathAbs(swings[i].price - zones[z].anchor) <= clusterDist)
         {
            if(swings[i].isHigh)
            {
               zones[z].hi = MathMax(zones[z].hi, swings[i].price);
               zones[z].lo = MathMin(zones[z].lo, swings[i].bodyEdge);
            }
            else
            {
               zones[z].lo = MathMin(zones[z].lo, swings[i].price);
               zones[z].hi = MathMax(zones[z].hi, swings[i].bodyEdge);
            }
            zones[z].touches++;
            matched = true;
            break;
         }
      }
      if(!matched)
      {
         int n = ArraySize(zones);
         ArrayResize(zones, n + 1);
         zones[n].anchor = swings[i].price;
         if(swings[i].isHigh)
         {
            zones[n].hi = swings[i].price;
            zones[n].lo = swings[i].bodyEdge;
            zones[n].isResistance = true;
         }
         else
         {
            zones[n].lo = swings[i].price;
            zones[n].hi = swings[i].bodyEdge;
            zones[n].isResistance = false;
         }
         zones[n].touches = 1;
      }
   }

   int w = 0;
   for(int i = 0; i < ArraySize(zones); i++)
   {
      if(zones[i].touches >= minTouches)
      {
         zones[w] = zones[i];
         w++;
      }
   }
   ArrayResize(zones, w);
}

//+------------------------------------------------------------------+
//| Ближайшие H4-зоны сопротивления/поддержки вокруг текущей цены     |
//+------------------------------------------------------------------+
bool GetActiveRange(SRZone &zones[], double curPrice, SRZone &resOut, SRZone &supOut)
{
   bool haveRes = false, haveSup = false;
   for(int i = 0; i < ArraySize(zones); i++)
   {
      if(zones[i].isResistance && zones[i].lo > curPrice)
      {
         if(!haveRes || zones[i].lo < resOut.lo) { resOut = zones[i]; haveRes = true; }
      }
      if(!zones[i].isResistance && zones[i].hi < curPrice)
      {
         if(!haveSup || zones[i].hi > supOut.hi) { supOut = zones[i]; haveSup = true; }
      }
   }
   return haveRes && haveSup;
}

//+------------------------------------------------------------------+
//| Структура свингов: HH+HL -> +1 (аптренд, только лонг разрешён),   |
//| LH+LL -> -1 (даунтренд, только шорт), иначе 0 (нет подтверждения) |
//|                                                                  |
//| ВАЖНО: раньше свинг-хаи и свинг-лоу собирались НЕЗАВИСИМО, каждый |
//| до накопления confirmCount штук, без ограничения по тому, как     |
//| далеко назад пришлось заглянуть. Если, например, свинг-хаи        |
//| попадались редко, а свинг-лоу часто, могло получиться сравнение    |
//| хаёв недельной давности со свежими вчерашними лоу — структура     |
//| "аптренд/даунтренд" получалась бы из ДВУХ РАЗНЫХ, несвязанных по   |
//| времени участков графика, а не из реальной недавней структуры.    |
//| Теперь окно поиска ограничено (последние ~6×confirmCount свингов  |
//| ЛЮБОГО типа) — если внутри него не набралось confirmCount хаёв И   |
//| confirmCount лоу, считаем "нет подтверждения" вместо того чтобы    |
//| лезть произвольно далеко в историю.                                |
//+------------------------------------------------------------------+
int GetSwingTrendBias(SwingPoint &swings[], int confirmCount)
{
   double highs[]; double lows[];
   ArrayResize(highs, 0); ArrayResize(lows, 0);

   int total = ArraySize(swings);
   int windowLimit = confirmCount * 6;
   int scanned = 0;

   for(int i = total - 1; i >= 0 && scanned < windowLimit; i--, scanned++)
   {
      if(swings[i].isHigh && ArraySize(highs) < confirmCount)
      {
         int n = ArraySize(highs); ArrayResize(highs, n + 1); highs[n] = swings[i].price;
      }
      if(!swings[i].isHigh && ArraySize(lows) < confirmCount)
      {
         int n = ArraySize(lows); ArrayResize(lows, n + 1); lows[n] = swings[i].price;
      }
      if(ArraySize(highs) >= confirmCount && ArraySize(lows) >= confirmCount) break;
   }
   if(ArraySize(highs) < confirmCount || ArraySize(lows) < confirmCount) return 0;

   bool ascHighs = true, descHighs = true;
   for(int i = 0; i < confirmCount - 1; i++)
   {
      if(highs[i] <= highs[i+1]) ascHighs = false;
      if(highs[i] >= highs[i+1]) descHighs = false;
   }
   bool ascLows = true, descLows = true;
   for(int i = 0; i < confirmCount - 1; i++)
   {
      if(lows[i] <= lows[i+1]) ascLows = false;
      if(lows[i] >= lows[i+1]) descLows = false;
   }

   if(ascHighs && ascLows) return 1;
   if(descHighs && descLows) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| ШАГ 2: окно сессии + пропуск первой свечи                         |
//+------------------------------------------------------------------+
bool InSessionWindow()
{
   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   int curHM = dt.hour * 60 + dt.min;
   int startHM = InpSessionStartHour * 60 + InpSessionStartMinute;
   int endHM = startHM + InpSessionWindowMinutes;
   if(curHM < startHM || curHM >= endHM) return false;

   if(InpSkipFirstCandle)
   {
      datetime todayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
      datetime sessionStart = todayStart + startHM * 60;
      datetime curBarTime = iTime(_Symbol, PERIOD_M5, 0);
      if(curBarTime <= sessionStart) return false; // это первая (или ещё не наступившая) свеча окна
   }
   return true;
}

//+------------------------------------------------------------------+
//| Есть ли уже открытая позиция под нашими magic (одна сделка за раз,|
//| как и подразумевает стратегия — один активный сетап на диапазон)  |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol &&
            (posInfo.Magic() == g_magicLong || posInfo.Magic() == g_magicShort))
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Управление открытой позицией: принудительное закрытие по времени  |
//| (InpMaxHoldMinutes) + динамическая фиксация прибыли при стагнации  |
//| (StallExit, по запросу — см. пояснение у входных параметров).      |
//+------------------------------------------------------------------+
void ManageOpenPositions(bool isNewLtfBar)
{
   datetime now = TimeCurrent();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      long posMagic = posInfo.Magic();
      if(posMagic != g_magicLong && posMagic != g_magicShort) continue;

      ulong ticket = posInfo.Ticket();
      ulong posId  = posInfo.Identifier();
      datetime openTime = (datetime)posInfo.Time();

      if(InpMaxHoldMinutes > 0 && (now - openTime) >= (long)InpMaxHoldMinutes * 60)
      {
         if(trade.PositionClose(ticket))
            Print("⏱ Закрыто по времени (макс. ", InpMaxHoldMinutes, " мин): тикет ", ticket);
         continue;
      }

      if(InpUseStallExit && isNewLtfBar)
      {
         ENUM_POSITION_TYPE type = posInfo.PositionType();
         double openPrice = posInfo.PriceOpen();
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profitPts = (type == POSITION_TYPE_BUY) ? (bid - openPrice) / point : (openPrice - ask) / point;

         int sIdx = GetOrCreateStall(posId);
         if(profitPts > g_posStall[sIdx].peakPts + InpStallEpsilonPts)
         {
            g_posStall[sIdx].peakPts = profitPts;
            g_posStall[sIdx].peakTime = now;
         }

         if(profitPts >= InpMinTPPts)
         {
            double frac = (profitPts - InpMinTPPts) / (InpStallUpperRefPts - InpMinTPPts);
            frac = MathMax(0.0, MathMin(1.0, frac));
            double requiredMinutes = InpStallMaxMinutes + frac * (InpStallMinMinutes - InpStallMaxMinutes);
            long stalledSeconds = now - g_posStall[sIdx].peakTime;
            if(stalledSeconds >= (long)(requiredMinutes * 60))
            {
               if(trade.PositionClose(ticket))
                  Print("📊 Стагнация: тикет ", ticket, " закрыт в прибыли +",
                        DoubleToString(profitPts, 0), "пт (простояла ", stalledSeconds/60,
                        " мин ≥ треб. ", DoubleToString(requiredMinutes,1), " мин)");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Согласие недавнего импульса: не входить ПРОТИВ явного недавнего   |
//| движения. Если ВСЕ последние lookback закрытых M5-свечей — против  |
//| направления сделки (все красные перед лонгом / все зелёные перед   |
//| шортом), отменяем вход, даже если формальный пробой зоны сработал. |
//+------------------------------------------------------------------+
bool RecentCandlesAgree(int direction, int lookback)
{
   for(int shift = 1; shift <= lookback; shift++)
   {
      double o = iOpen(_Symbol, PERIOD_M5, shift);
      double c = iClose(_Symbol, PERIOD_M5, shift);
      bool bullish = c > o;
      bool bearish = c < o;
      // Если хотя бы одна свеча ЗА направление сделки (или дожи, не против) — согласие есть
      if(direction == 1 && !bearish) return true;
      if(direction == -1 && !bullish) return true;
   }
   // Все lookback свечей оказались против направления сделки
   return false;
}

//+------------------------------------------------------------------+
//| ШАГ 4: пробой M5-зоны с подтверждённым закрытием свечи            |
//+------------------------------------------------------------------+
bool TryLtfBreakout(int direction)
{
   double closePrice = iClose(_Symbol, PERIOD_M5, 1);
   double prevClose  = iClose(_Symbol, PERIOD_M5, 2);

   if(direction == 1)
   {
      for(int i = 0; i < ArraySize(g_ltfZones); i++)
      {
         if(!g_ltfZones[i].isResistance) continue;
         if(closePrice > g_ltfZones[i].hi && prevClose <= g_ltfZones[i].hi)
         {
            g_lastSignalDetail = StringFormat("Пробой M5-сопротивления %.2f, закрытие %.2f",
                                               g_ltfZones[i].hi, closePrice);
            return true;
         }
      }
   }
   else
   {
      for(int i = 0; i < ArraySize(g_ltfZones); i++)
      {
         if(g_ltfZones[i].isResistance) continue;
         if(closePrice < g_ltfZones[i].lo && prevClose >= g_ltfZones[i].lo)
         {
            g_lastSignalDetail = StringFormat("Пробой M5-поддержки %.2f, закрытие %.2f",
                                               g_ltfZones[i].lo, closePrice);
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Открытие позиции: SL за пределы H4-зоны, от которой отбились, TP  |
//| на % пути до противоположной H4-зоны.                             |
//+------------------------------------------------------------------+
bool OpenTrade(int direction)
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    minStop = GetMinStopPoints();

   // SL/TP берутся от структуры H4-зон, но зажаты в коридор InpMinTPPts/
   // InpMaxTPPts и потолком InpMaxSLPts (по запросу) — зона задаёт НАПРАВЛЕНИЕ
   // и ЛОГИКУ (куда ставить, где реалистичная цель), а коридор — абсолютные
   // границы здравого смысла для лота/риска.
   double entry, sl, tp;
   if(direction == 1)
   {
      entry = ask;
      double slPtsRaw = (entry - (g_curSup.lo - InpSLBufferPts * point)) / point;
      double slPtsC = MathMin(slPtsRaw, (double)InpMaxSLPts);
      sl = NormalizeDouble(entry - slPtsC * point, digits);

      double distToRes = g_curRes.lo - entry;
      if(distToRes <= 0.0) return false;
      double tpPtsRaw = (distToRes * (InpTPAtOppositeZonePct / 100.0)) / point;
      double tpPtsC = MathMax((double)InpMinTPPts, MathMin((double)InpMaxTPPts, tpPtsRaw));
      tp = NormalizeDouble(entry + tpPtsC * point, digits);
   }
   else
   {
      entry = bid;
      double slPtsRaw = ((g_curRes.hi + InpSLBufferPts * point) - entry) / point;
      double slPtsC = MathMin(slPtsRaw, (double)InpMaxSLPts);
      sl = NormalizeDouble(entry + slPtsC * point, digits);

      double distToSup = entry - g_curSup.hi;
      if(distToSup <= 0.0) return false;
      double tpPtsRaw = (distToSup * (InpTPAtOppositeZonePct / 100.0)) / point;
      double tpPtsC = MathMax((double)InpMinTPPts, MathMin((double)InpMaxTPPts, tpPtsRaw));
      tp = NormalizeDouble(entry - tpPtsC * point, digits);
   }

   // Защита от устаревших данных о зонах (H4-зоны пересчитываются раз в 4 часа,
   // а цена могла уйти дальше за это время) — SL/TP обязаны быть на правильной
   // стороне от входа, иначе PositionOpen с абсурдными уровнями будет отклонён
   // брокером (или хуже — примется с неверной логикой).
   bool sidesOk = (direction == 1) ? (sl < entry && tp > entry) : (sl > entry && tp < entry);
   if(!sidesOk)
   {
      Print("⚠️ SL/TP оказались на неверной стороне от входа (устаревшие зоны?) — пропуск");
      return false;
   }

   double slPts = MathAbs(entry - sl) / point;
   double tpPts = MathAbs(tp - entry) / point;
   if(slPts < minStop || tpPts < minStop)
   {
      Print("⚠️ Диапазон слишком узкий для валидных SL/TP (SL=", DoubleToString(slPts,0),
            "пт TP=", DoubleToString(tpPts,0), "пт < мин. ", minStop, "пт) — пропуск");
      return false;
   }

   double lot;
   if(InpUseFixedLot) lot = InpLotSize;
   else                lot = CalcLotByRisk(slPts);
   lot = NormalizeAndValidateLot(lot, direction, entry);
   if(lot <= 0.0) return false;

   int magic = (direction == 1) ? g_magicLong : g_magicShort;
   trade.SetExpertMagicNumber(magic);

   string label = (direction == 1) ? "LONG" : "SHORT";
   Print(direction > 0 ? "📈 BUY (" : "📉 SELL (", label, ") | ", g_lastSignalDetail,
         " | Цена=", DoubleToString(entry, digits),
         " SL=", DoubleToString(sl, digits), " (", DoubleToString(slPts,0), "пт)",
         " TP=", DoubleToString(tp, digits), " (", DoubleToString(tpPts,0), "пт)",
         " Лот=", DoubleToString(lot, 2));

   bool ok;
   if(direction == 1) ok = trade.Buy(lot, _Symbol, entry, sl, tp, "vMoneixau " + label);
   else                ok = trade.Sell(lot, _Symbol, entry, sl, tp, "vMoneixau " + label);

   if(!ok)
   {
      Print("❌ Ошибка: ", trade.ResultRetcode(), " — ", trade.ResultRetcodeDescription());
      return false;
   }
   g_total_trades++;
   return true;
}

//+------------------------------------------------------------------+
//| Проверка условий входа (шаги 1-2-3-4 вместе)                      |
//+------------------------------------------------------------------+
void CheckEntry()
{
   if(g_trading_paused) return;
   if(HasOpenPosition()) return;
   if(!g_inSession) return;
   if(!g_haveRange) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double curPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;

   // Не реальный боковик, а просто два далёких старых уровня — пропускаем
   // (см. пояснение у InpMaxRangeWidthPts выше).
   if((g_curRes.lo - g_curSup.hi) / point > InpMaxRangeWidthPts) return;

   bool nearSupport    = (curPrice >= g_curSup.lo) && ((curPrice - g_curSup.hi) / point <= InpZoneProximityPts);
   bool nearResistance = (curPrice <= g_curRes.hi) && ((g_curRes.lo - curPrice) / point <= InpZoneProximityPts);

   bool wantLong  = nearSupport    && (g_swingBias >= 0) && g_maLong;
   bool wantShort = nearResistance && (g_swingBias <= 0) && g_maShort;

   if(!SpreadOK()) return;
   if(!CalendarClear()) return;

   if(wantLong && TryLtfBreakout(1))
   {
      if(!InpRequireMomentumAgree || RecentCandlesAgree(1, InpMomentumLookback))
         OpenTrade(1);
      else
      {
         Print("⚠️ Пробой вверх есть, но последние ", InpMomentumLookback,
               " M5-свечи все против (красные) — вход отменён");
         g_lastSignalDetail += StringFormat(" [ОТМЕНЕНО: %d красных свечей подряд]", InpMomentumLookback);
      }
   }
   else if(wantShort && TryLtfBreakout(-1))
   {
      if(!InpRequireMomentumAgree || RecentCandlesAgree(-1, InpMomentumLookback))
         OpenTrade(-1);
      else
      {
         Print("⚠️ Пробой вниз есть, но последние ", InpMomentumLookback,
               " M5-свечи все против (зелёные) — вход отменён");
         g_lastSignalDetail += StringFormat(" [ОТМЕНЕНО: %d зелёных свечей подряд]", InpMomentumLookback);
      }
   }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpMagicNumber <= 0)
   {
      Print("❌ ERROR: InpMagicNumber должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   g_magicLong  = InpMagicNumber;
   g_magicShort = InpMagicNumber + 1;

   g_fillType = DetectFillType();
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(g_fillType);

   if(InpH4PivotLegBars <= 0 || InpH4LookbackBars <= 0 || InpLtfPivotLegBars <= 0 || InpLtfLookbackBars <= 0)
   {
      Print("❌ ERROR: параметры Pivot/Lookback должны быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpH4MinTouches < 1 || InpLtfMinTouches < 1)
   {
      Print("❌ ERROR: InpH4MinTouches/InpLtfMinTouches должны быть ≥ 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSwingConfirmCount < 2)
   {
      Print("❌ ERROR: InpSwingConfirmCount должен быть ≥ 2 (нужно минимум 2 свинга для направления)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSessionStartHour < 0 || InpSessionStartHour > 23 || InpSessionStartMinute < 0 || InpSessionStartMinute > 59)
   {
      Print("❌ ERROR: InpSessionStartHour/Minute вне диапазона");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSessionWindowMinutes <= 0)
   {
      Print("❌ ERROR: InpSessionWindowMinutes должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpTPAtOppositeZonePct <= 0.0 || InpTPAtOppositeZonePct > 100.0)
   {
      Print("❌ ERROR: InpTPAtOppositeZonePct должен быть в (0,100]");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMinTPPts <= 0 || InpMaxTPPts <= InpMinTPPts)
   {
      Print("❌ ERROR: InpMinTPPts/InpMaxTPPts заданы некорректно (Max должен быть > Min)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxSLPts <= 0)
   {
      Print("❌ ERROR: InpMaxSLPts должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxRangeWidthPts <= 0)
   {
      Print("❌ ERROR: InpMaxRangeWidthPts должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseStallExit && (InpStallUpperRefPts <= InpMinTPPts || InpStallMinMinutes <= 0 || InpStallMaxMinutes <= 0))
   {
      Print("❌ ERROR: InpStallUpperRefPts должен быть > InpMinTPPts, InpStallMin/MaxMinutes должны быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxConsecutiveLosses < 0)
   {
      Print("❌ ERROR: InpMaxConsecutiveLosses не может быть отрицательным");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRequireMomentumAgree && InpMomentumLookback <= 0)
   {
      Print("❌ ERROR: InpMomentumLookback должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   ENUM_ACCOUNT_MARGIN_MODE marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(InpRequireHedging && marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("❌ ERROR: счёт не в режиме hedging (", EnumToString(marginMode), ")");
      return INIT_PARAMETERS_INCORRECT;
   }

   h_ma = iMA(_Symbol, PERIOD_M5, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);
   if(h_ma == INVALID_HANDLE)
   {
      Print("❌ Ошибка создания индикатора MA ('Импульс')");
      return INIT_FAILED;
   }
   double tmp[];
   CopyBuffer(h_ma, 0, 0, 300, tmp);

   g_last_h4_bar  = 0;
   g_last_ltf_bar = 0;
   g_last_day     = 0;
   g_consecutive_losses = 0;
   g_trading_paused = false;

   if(GlobalVariableCheck(GVName("Paused")))
      g_trading_paused = (GlobalVariableGet(GVName("Paused")) != 0.0);
   if(GlobalVariableCheck(GVName("ConsecLosses")))
      g_consecutive_losses = (int)GlobalVariableGet(GVName("ConsecLosses"));
   if(g_trading_paused)
      Print("🔁 Восстановлено состояние стоп-машины: ПАУЗА (", g_consecutive_losses, " убытков подряд)");

   ArrayResize(g_posPnl, 0);
   ArrayResize(g_posStall, 0);
   EventSetTimer(1);

   Print("════════════════════════════════════════════");
   Print("vMoneixau v5.4 запущен | magic LONG=", g_magicLong, " SHORT=", g_magicShort);
   Print("Шаг 1: H4 зоны (leg=", InpH4PivotLegBars, " lookback=", InpH4LookbackBars,
         " кластер=", InpH4ZoneClusterPts, "пт мин.касаний=", InpH4MinTouches, ")");
   Print("Шаг 2: сессия ", StringFormat("%02d:%02d", InpSessionStartHour, InpSessionStartMinute),
         " + ", InpSessionWindowMinutes, " мин, пропуск первой свечи: ", (InpSkipFirstCandle?"ON":"OFF"),
         ", MA(", InpMAPeriod, ") как фильтр направления");
   Print("Шаг 3-4: M5 зоны (leg=", InpLtfPivotLegBars, " lookback=", InpLtfLookbackBars,
         " кластер=", InpLtfZoneClusterPts, "пт) — вход по подтверждённому закрытию за зоной");
   Print("SL буфер: ", InpSLBufferPts, "пт | TP на ", InpTPAtOppositeZonePct, "% пути до противоположной зоны");
   Print("Макс. удержание сделки: ", InpMaxHoldMinutes, " мин");
   if(InpRequireMomentumAgree)
      Print("Согласие импульса: вход отменяется, если последние ", InpMomentumLookback,
            " M5-свечей все против направления сделки");
   Print("Стоп-машина после ", InpMaxConsecutiveLosses, " убытков подряд");
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

   if(h_ma != INVALID_HANDLE) IndicatorRelease(h_ma);

   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE)
   {
      GlobalVariableDel(GVName("ConsecLosses"));
      GlobalVariableDel(GVName("Paused"));
   }

   Print("════════════════════════════════════════════");
   Print("vMoneixau остановлен");
   Print("Сделок: ", g_total_trades);
   Print("Win: ", g_win_trades, " | Loss: ", g_loss_trades);
   if(g_total_trades > 0)
      Print("Winrate: ", DoubleToString(100.0 * g_win_trades / g_total_trades, 1), "%");
   Print("PnL: $", DoubleToString(g_total_profit, 2));
   Print("════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| OnTimer — обновляем панель                                        |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(InpShowInfo) DrawPanel();
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   // isNewLtfBar считается ДО ManageOpenPositions() — StallExit внутри неё
   // обновляет пик прибыли раз за M5-бар, а не на каждом тике.
   datetime curLtfBar = iTime(_Symbol, PERIOD_M5, 0);
   bool isNewLtfBar = (curLtfBar != g_last_ltf_bar);

   ManageOpenPositions(isNewLtfBar);

   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   datetime todayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
   if(todayStart != g_last_day)
   {
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

   // --- Шаг 1: пересчёт H4 зон и структуры свингов раз за H4-бар ---
   datetime curH4Bar = iTime(_Symbol, PERIOD_H4, 0);
   if(curH4Bar != g_last_h4_bar)
   {
      g_last_h4_bar = curH4Bar;
      DetectSwings(PERIOD_H4, InpH4PivotLegBars, InpH4LookbackBars, g_h4Swings);
      ClusterZones(g_h4Swings, InpH4ZoneClusterPts, InpH4MinTouches, g_h4Zones);
      g_swingBias = GetSwingTrendBias(g_h4Swings, InpSwingConfirmCount);
   }

   // --- Шаг 3: пересчёт M5 зон раз за M5-бар ---
   if(isNewLtfBar)
   {
      g_last_ltf_bar = curLtfBar;
      DetectSwings(PERIOD_M5, InpLtfPivotLegBars, InpLtfLookbackBars, g_ltfSwings);
      ClusterZones(g_ltfSwings, InpLtfZoneClusterPts, InpLtfMinTouches, g_ltfZones);
   }

   double curPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   g_haveRange = GetActiveRange(g_h4Zones, curPrice, g_curRes, g_curSup);

   double ma = BufferVal(h_ma, 0, 1);
   g_maLong  = (ma != EMPTY_VALUE) && (curPrice > ma);
   g_maShort = (ma != EMPTY_VALUE) && (curPrice < ma);

   g_inSession = InSessionWindow();

   // Вход проверяем только на новом M5-баре (сигнал шага 4 — закрытие свечи)
   if(isNewLtfBar)
      CheckEntry();
}

//+------------------------------------------------------------------+
//| OnTradeTransaction — учёт win/loss                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;

   long dealMagic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(dealMagic != g_magicLong && dealMagic != g_magicShort) return;
   if((long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   double pnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
              + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
              + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   g_total_profit += pnl;

   ulong posId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   AddPosPnl(posId, pnl);

   bool stillOpen = PositionSelectByTicket(posId);
   if(stillOpen) return;

   RemoveStallState(posId);
   double finalPnl = PopPosPnl(posId);
   if(finalPnl > 0.0)
   {
      g_win_trades++;
      g_consecutive_losses = 0;
      PersistCircuitBreaker();
      Print("✅ Позиция закрыта +$", DoubleToString(finalPnl, 2), " | PnL: $", DoubleToString(g_total_profit, 2));
   }
   else if(finalPnl < 0.0)
   {
      g_loss_trades++;
      g_consecutive_losses++;
      Print("❌ Позиция закрыта $", DoubleToString(finalPnl, 2), " | PnL: $", DoubleToString(g_total_profit, 2));
      if(InpMaxConsecutiveLosses > 0 && g_consecutive_losses >= InpMaxConsecutiveLosses)
      {
         g_trading_paused = true;
         Print("⛔ СТОП-МАШИНА: ", g_consecutive_losses, " убытков подряд — торговля приостановлена до понедельника");
      }
      PersistCircuitBreaker();
   }
}

//+------------------------------------------------------------------+
//| ПАНЕЛЬ                                                            |
//+------------------------------------------------------------------+
void DrawPanelBackground(int totalLines)
{
   string bgName = PANEL_PREFIX + "_BG";
   int width  = 420;
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
   double winRate = (g_total_trades > 0) ? 100.0 * g_win_trades / g_total_trades : 0.0;

   string texts[40];
   color  colors[40];
   int n = 0;

   texts[n] = "═══ vMoneixau v5.4 ═══"; colors[n] = InpColorTitle; n++;
   texts[n] = StringFormat("Сессия: %s | MA(%d): %s", g_inSession ? "✅ активна" : "⏳ вне окна",
                            InpMAPeriod, g_maLong ? "выше (лонг)" : (g_maShort ? "ниже (шорт)" : "н/д"));
   colors[n] = g_inSession ? InpColorGood : InpColorNeutral; n++;
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = "─── ШАГ 1: H4 ДИАПАЗОН ───"; colors[n] = InpColorHeader; n++;
   if(g_haveRange)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double widthPts = (g_curRes.lo - g_curSup.hi) / point;
      bool widthOk = widthPts <= InpMaxRangeWidthPts;
      texts[n] = StringFormat("Сопротивление: %.2f-%.2f (%d кас.)", g_curRes.lo, g_curRes.hi, g_curRes.touches);
      colors[n] = InpColorBad; n++;
      texts[n] = StringFormat("Поддержка: %.2f-%.2f (%d кас.)", g_curSup.lo, g_curSup.hi, g_curSup.touches);
      colors[n] = InpColorGood; n++;
      texts[n] = StringFormat("Ширина: %.0fпт %s (лимит %.0f)", widthPts,
                               widthOk ? "✅" : "❌ слишком широко", InpMaxRangeWidthPts);
      colors[n] = widthOk ? InpColorGood : InpColorBad; n++;
   }
   else
   {
      texts[n] = "Диапазон не определён (мало зон/касаний)"; colors[n] = InpColorNeutral; n++;
   }
   string biasTxt = (g_swingBias == 1) ? "▲ вверх (HH+HL) — только лонг" :
                    (g_swingBias == -1) ? "▼ вниз (LH+LL) — только шорт" : "○ нет подтверждения";
   texts[n] = "Структура свингов: " + biasTxt;
   colors[n] = (g_swingBias != 0) ? InpColorGood : InpColorNeutral; n++;
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = "─── ШАГ 3-4: M5 ЗОНЫ И СИГНАЛ ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("M5 зон найдено: %d", ArraySize(g_ltfZones)); colors[n] = InpColorText; n++;
   if(g_lastSignalDetail != "")
   { texts[n] = "Последний сигнал: " + g_lastSignalDetail; colors[n] = InpColorGood; n++; }
   texts[n] = ""; colors[n] = InpColorText; n++;

   texts[n] = "─── СТАТИСТИКА ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Сделок: %d | Win: %d Loss: %d (%.0f%%)", g_total_trades, g_win_trades, g_loss_trades, winRate);
   colors[n] = InpColorText; n++;
   texts[n] = StringFormat("PnL: $%.2f", g_total_profit);
   colors[n] = (g_total_profit >= 0 ? InpColorGood : InpColorBad); n++;
   texts[n] = StringFormat("Серия убытков: %d/%d", g_consecutive_losses, InpMaxConsecutiveLosses);
   colors[n] = (g_trading_paused ? InpColorBad : InpColorNeutral); n++;
   if(g_trading_paused)
   { texts[n] = "⛔ ТОРГОВЛЯ ПРИОСТАНОВЛЕНА до понедельника"; colors[n] = InpColorBad; n++; }

   if(InpDarkBackground) DrawPanelBackground(n);
   for(int i = 0; i < n; i++)
      DrawPanelLine(i, texts[i], colors[i]);

   // Найдено по вашему скриншоту: если в ПРЕДЫДУЩЕМ кадре строк было больше
   // (например, показывалась строка "ТОРГОВЛЯ ПРИОСТАНОВЛЕНА", а сейчас её
   // нет), лишние старые объекты с индексами ≥n никогда не удалялись —
   // оставались висеть на графике поверх новых строк (это и есть "Label" и
   // задвоенные "PnL"/"Серия убытков" на вашем скриншоте). Стираем всё, что
   // осталось от предыдущего, более длинного кадра.
   for(int i = n; i < 40; i++)
   {
      string fullName = PANEL_PREFIX + IntegerToString(i);
      if(ObjectFind(0, fullName) >= 0) ObjectDelete(0, fullName);
   }
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
