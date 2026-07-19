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
//|                                                                  |
//|  ОБНОВЛЕНО (после нескольких реальных прогонов подряд без единой  |
//|  сделки): панель теперь показывает ЖИВОЙ ЧЕК-ЛИСТ — какое именно  |
//|  из условий (диапазон найден / ширина ОК / у зоны / MA / сессия)  |
//|  сейчас не выполнено, вместо того чтобы гадать по скриншотам.      |
//|  Также ослаблены пороги, которые по накопленным данным оказались   |
//|  главным узким местом: InpZoneProximityPts 400→700,               |
//|  InpMaxRangeWidthPts 3000→5000, InpSessionWindowMinutes 600→900.  |
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
//+------------------------------------------------------------------+
//| ДОБАВЛЕНО (по запросу): безубыток, частичное закрытие и трейлинг- |
//| стоп, перенесённые из XAUUSD_TimeStrategy_EA_v4.9 (тот же код,    |
//| что вы прислали как "работает у меня на реале без единого минуса  |
//| за месяц"). ВАЖНО ЧЕСТНО: в v4.9 этих механизмов НЕТ "гарантии    |
//| без минуса" — это обычное управление уже прибыльной позицией      |
//| (перенос SL в безубыток при +InpBreakEvenTriggerPts, частичная    |
//| фиксация прибыли, подтягивание SL за ценой). Пока профит не       |
//| достиг порога безубытка, SL стоит на исходном месте — если цена    |
//| сразу пойдёт против сделки, позиция закроется по обычному SL в     |
//| минус, точно как в v4.9 (в тесте этой же сессии — 12 убыточных из  |
//| 153 сделок). Эффект этих механизмов — уменьшить СРЕДНИЙ размер     |
//| убытка и защитить часть прибыли на сделках, которые успели уйти в  |
//| плюс, а не убрать убытки полностью.                                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v5.5 — ПЕРЕРАБОТКА СЕССИИ/ЗОН ПО ЗАПРОСУ:                          |
//| 1) Окно ВХОДА сужено с 900 мин (диагностический костыль v5.4) до   |
//|    InpSessionWindowMinutes=60 (40-90 по вашему описанию) — сделки  |
//|    ловим у открытия NY-сессии, пока виден свежий тренд, а не весь  |
//|    день напролёт.                                                 |
//| 2) Добавлен InpTradingEndHour/Minute=22:00 — уже открытая позиция  |
//|    управляется как обычно (БУ/частичное закрытие/трейлинг/         |
//|    стагнация), но принудительно закрывается к этому часу           |
//|    независимо от InpMaxHoldMinutes — "торги до 22:00 по Кишинёву". |
//| 3) Добавлен ШАГ 2b — подтверждение зон на M15 (между H4-диапазоном |
//|    и M5-точкой входа): требуем близость к M15-зоне с накопленными  |
//|    InpM15MinTouches (2-3) касаниями — ваши "два-три подтверждения, |
//|    что цена доходит до вершины и разворачивается".                 |
//| 4) Добавлена боковик-пауза (InpSidewaysPauseMinutes=45, 30-60 по   |
//|    запросу): если на новом H4-баре не нашлось диапазона или        |
//|    структура свингов не даёт направления — сканирование новых      |
//|    входов приостанавливается на это время вместо непрерывной       |
//|    проверки каждую M5-свечу.                                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v5.51 — ПО ИТОГАМ FUNNEL-ПРОГОНА (Python-зеркало логики на M15-    |
//| данных за ГОД): исходная v5.5 не дала НИ ОДНОЙ сделки за год — не   |
//| из-за одной ошибки, а из-за нескольких фильтров, почти              |
//| взаимоисключающих в связке. Исправлены КОРНИ:                       |
//| 1) Лимит ширины H4-диапазона (резал 92%) → по умолчанию ВЫКЛ (0):   |
//|    TP/SL и так зажаты потолками, близость к краю обязательна.       |
//| 2) MA-фильтр требовал "цена выше MA+50пт И MA растёт" — у поддержки |
//|    цена по определению у/ниже своей MA, а MA разворачивается позже  |
//|    цены. Буфер 50→20, наклон MA теперь опционален (по умолч. ВЫКЛ). |
//| 3) M15-подтверждение искало зону СТРОГО ниже/выше цены — исключало  |
//|    ровно ту зону, от которой отбиваемся. Теперь ищется ближайшая    |
//|    зона нужного типа в пределах InpM15ZoneProximityPts, включая     |
//|    случай "цена внутри зоны".                                       |
//| 4) Подтверждённый зонный H4-коридор в тренде часто не существует    |
//|    (на хаях выше цены зон нет) — добавлена запасная рамка max/min   |
//|    последних InpHLRangeBars H4-баров ("видно максимум и минимум").  |
//| 5) Боковик-пауза срабатывала при нейтральном bias на H4-баре 16:00  |
//|    и съедала 45 из 60 минут окна входа — теперь пауза только когда  |
//|    рамки нет вообще.                                                |
//| 6) Запасной триггер входа: закрытие M5-свечи за max/min последних   |
//|    InpSimpleBreakoutBars M5-баров, когда формальной M5-зоны рядом    |
//|    нет ("пробили уровень, свеча закрылась выше — подтверждение").    |
//| Итог зеркального прогона за год: 0 сделок → 4 (3 в плюс, +498 пт);  |
//| реальный M5 в тестере даст больше (зеркало на M15 в 3 раза грубее). |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v5.52 — ЗАМОК ПРИБЫЛИ + более редкие/точные входы (по запросу      |
//| "минимум сделок в день, очень точные, закрывались минимум в плюс   |
//| 50; если цена долго стоит в плюсе — закрыть, чтобы не развернуло    |
//| в стоп"):                                                          |
//| • Добавлен ЗАМОК ПРИБЫЛИ (InpUseProfitLock) — проверяется КАЖДЫЙ    |
//|   ТИК: как только плавающая прибыль достигла +70, ставится         |
//|   плавающий пол max(+50, пик−25); откат до пола → закрытие В ПЛЮСЕ  |
//|   немедленно, не дожидаясь разворота в стоп. Пол не опускается ниже |
//|   +50 (ваш минимум).                                               |
//| • StallExit ускорен: терпение к мелкой прибыли 30→12 мин — мелкий   |
//|   плюс банкуется быстрее, пока не развернулся.                     |
//| • Входы остаются РЕДКИМИ и точными (узкое окно NY-сессии + bias +   |
//|   MA + M15-подтверждение 2-3 касаний + пробой M5 + перевес свечей). |
//| Прогон логики за год (M15-зеркало, грубее реального M5): без        |
//|   ошибок, редкие сделки с защищённым плюсом. Реальную частоту и     |
//|   исполнение замка проверяйте в MT5 Strategy Tester на M5.          |
//+------------------------------------------------------------------+
#property copyright   "vMoneixau v5.52 — новая стратегия, требует проверки в тестере"
#property version     "5.52"
#property strict
#property description "vMoneixau v5.52 — редкие точные входы + замок прибыли (мин. +50, защита от разворота) + БУ/частичное/трейлинг/стагнация"

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
input double  InpZoneProximityPts   = 700;  // насколько близко цена должна быть к H4-зоне (было 150→400)
// НАЙДЕНО (funnel-прогон за ГОД данных): лимит 5000 пт отсекал 92% всех
// кандидатов — золото трендит, и коридор между ближней H4-поддержкой и
// H4-сопротивлением почти всегда шире 5000. При этом реальную проверку
// качества уровня теперь делает слой M15 (2-3 касания), а TP всё равно зажат
// потолком InpMaxTPPts — широкий H4-коридор сам по себе не вредит. Поэтому
// лимит поднят до 12000: H4 задаёт только макро-рамку "где максимум и
// минимум" (как вы и описали), а не требование узкого боковика.
// ОБНОВЛЕНО ещё раз (funnel-прогон с рамкой max/min): даже лимит 12000
// отсекал ~73% оставшихся баров — 3-дневный ход золота обычно шире. Смысла в
// лимите больше нет: TP зажат потолком InpMaxTPPts, SL — InpMaxSLPts, а вход
// требует близости к краю рамки (InpZoneProximityPts). 0 = проверка выключена.
input double  InpMaxRangeWidthPts   = 0;    // макс. ширина H4-диапазона, 0 = не проверять (было 5000→12000)
input int     InpSwingConfirmCount  = 2;    // сколько последних свинг-хаев/лоу проверяем на направление
// НАЙДЕНО (funnel-прогон за год): "подтверждённая зона сопротивления СВЕРХУ и
// поддержки СНИЗУ" существовали одновременно лишь на ~10% баров окна сессии —
// на хаях года выше цены физически нет подтверждённой зоны (цена там ещё не
// была), и вход блокировался неделями. По вашему же описанию "по тайму 4 часа
// видно где максимум и минимум": если зонного коридора нет, рамкой диапазона
// становятся max/min последних InpHLRangeBars H4-баров (~3 дня). Приоритет у
// настоящих зон с касаниями; max/min — запасной вариант, чтобы рамка была
// всегда. Фильтры bias/MA/M15 при этом работают как обычно.
input bool    InpUseHLFallbackRange = true;
input int     InpHLRangeBars        = 18;   // H4-баров для запасной рамки max/min (18 = ~3 дня)

input group "=== ШАГ 2: СЕССИЯ И ИНДИКАТОР 'ИМПУЛЬС' ==="
// ИЗМЕНЕНО (по запросу): раньше InpSessionWindowMinutes=900 (15 часов) — это
// было расширено ИСКУССТВЕННО в v5.4, чтобы просто получить хоть какие-то
// сделки для диагностики. Теперь по вашему описанию — вход должен ловиться
// именно в начале Нью-Йоркской сессии, когда рынок уже "сформировался" и
// виден тренд, а не в течение всего дня: узкое окно ВХОДА 40-90 минут после
// открытия сессии. Отдельно — InpTradingEndHour/Minute: сколько бы ни шла
// сделка, она принудительно закрывается к 22:00 по Кишинёву (уже открытая
// позиция при этом продолжает управляться безубытком/трейлингом/стагнацией
// как обычно — просто не позже этого времени). Если время сервера вашего
// брокера НЕ совпадает с временем Кишинёва (EEST/EET) — сдвиньте оба времени
// (старт сессии и конец торгового дня) на ту же разницу.
input int     InpSessionStartHour   = 16;   // начало окна входа (время сервера — настройте под NY-открытие у вашего брокера)
input int     InpSessionStartMinute = 30;
input int     InpSessionWindowMinutes = 60;  // окно ВХОДА в минутах после старта сессии (было 900 — диагностика; теперь 40-90 по запросу)
input int     InpTradingEndHour     = 22;   // жёсткое закрытие любой открытой сделки к этому часу (по Кишинёву, если сервер = Кишинёв)
input int     InpTradingEndMinute   = 0;
input bool    InpSkipFirstCandle    = true; // не входить на первой M5-свече после открытия окна
input int     InpMAPeriod           = 50;   // период индикатора "Импульс" (обычная MA)
input ENUM_MA_METHOD InpMAMethod    = MODE_SMA;
// НАЙДЕНО (реальный прогон): "рынок падает, шорт, немного поднялось — сразу
// пишет лонг, потом снова падает — снова шорт". Причина: MA-фильтр сравнивал
// цену с MA БЕЗ буфера и без проверки наклона самой MA — любой мелкий отскок
// на пару пунктов через линию MA тут же переключал показанное направление,
// хотя реального разворота тренда не было. Добавлены буфер (цена должна
// отойти от MA на ощутимое расстояние, не просто пересечь линию) и проверка
// наклона MA (сама средняя должна расти/падать, а не быть плоской).
// НАЙДЕНО (funnel-прогон за год): требование "цена выше MA+50пт И MA растёт"
// ЛОГИЧЕСКИ ПРОТИВОРЕЧИТ фейду поддержки. Мы покупаем У ПОДДЕРЖКИ (низ
// диапазона) — а там цена почти по определению ЕЩЁ НИЖЕ или только-только
// у своей MA(50), и сама MA ещё падает (она разворачивается с запозданием).
// Оба условия одновременно выполняются только при редчайшем резком V-развороте
// — фильтр пропускал 9 баров из 22 за ГОД, а вместе с остальными — ноль
// сделок. Исправление: буфер снижен до 20пт, а наклон MA сделан опциональным
// (по умолчанию ВЫКЛ) — при пробое M5-зоны после отскока от поддержки цена
// как раз успевает вернуться над MA, и это и есть ваш "импульс"; требовать
// ещё и разворота самой полусотенной средней — значит опаздывать всегда.
input double  InpMABufferPts        = 20;   // мин. расстояние цены от MA (было 50 — душило входы у зон)
input bool    InpMARequireSlope     = false; // требовать ещё и наклон MA (было жёстко ON — опаздывает у зон)
input int     InpMASlopeBars        = 5;    // на скольки барах назад сравниваем MA для наклона (если ON)

input group "=== ШАГ 2b: ПОДТВЕРЖДЕНИЕ ЗОН НА M15 (по запросу — 'на 15 минут видно зоны ещё лучше') ==="
// Добавлен средний слой между H4 (общий диапазон) и M5 (точка входа): те же
// зоны поддержки/сопротивления, но на M15, где, по вашим словам, касания
// видно отчётливее. Перед входом требуем, чтобы цена была ещё и рядом с
// M15-зоной ТОЙ ЖЕ стороны (поддержка/сопротивление), причём у этой M15-зоны
// накопилось хотя бы InpM15MinTouches касаний — это и есть ваши "два или три
// подтверждения, что цена в этом месте доходит до вершины и разворачивается".
input int     InpM15PivotLegBars    = 2;
input int     InpM15LookbackBars    = 150;  // M15-баров назад (~37 часов)
input double  InpM15ZoneClusterPts  = 150;
input int     InpM15MinTouches      = 2;    // 2 или 3 подтверждения касания зоны, как вы и просили
input double  InpM15ZoneProximityPts = 300; // насколько близко цена должна быть к M15-зоне для подтверждения

input group "=== ШАГ 3-4: ЗОНЫ НА M5 + ПРОБОЙ С ПОДТВЕРЖДЁННЫМ ЗАКРЫТИЕМ ==="
input int     InpLtfPivotLegBars    = 2;
input int     InpLtfLookbackBars    = 150;  // M5-баров назад (~12.5 часов)
input double  InpLtfZoneClusterPts  = 80;
input int     InpLtfMinTouches      = 2;
// НАЙДЕНО (funnel-прогон): формальный пробой M5-зоны (мин. 2 касания, кластер)
// требует, чтобы рядом с текущей ценой УЖЕ сформировалась подтверждённая
// M5-зона И чтобы её пробитие случилось ровно в момент, когда совпали все
// остальные условия (узкое окно сессии!). На практике это отсекало вообще
// всё. Добавлен запасной триггер в духе вашего же описания ("пробили
// уровень на M5, свеча закрылась выше — подтверждение"): подтверждённое
// ЗАКРЫТИЕ M5-свечи выше максимума (для лонга) / ниже минимума (для шорта)
// последних InpSimpleBreakoutBars M5-баров — микропробой локальной структуры.
// Основной зонный пробой остаётся приоритетным; запасной работает, когда
// формальной зоны рядом просто нет.
input bool    InpUseSimpleBreakout  = true;
input int     InpSimpleBreakoutBars = 6;    // закрытие за экстремум последних N M5-баров (30 мин)

input group "=== БОКОВИК: ПАУЗА ПЕРЕД ПОВТОРНЫМ СКАНОМ (по запросу) ==="
// "Если боковик — пауза 30-60 минут, ждём коррекции." Как только на новом
// H4-баре выясняется, что диапазон не найден ИЛИ структура свингов не даёт
// направления (боковик, а не тренд), сканирование новых входов
// приостанавливается на InpSidewaysPauseMinutes — вместо того чтобы дёргать
// проверку входа на каждой M5-свече без толку. Уже открытые позиции пауза не
// затрагивает — ими управление (безубыток/трейлинг/стагнация) идёт как обычно.
input int     InpSidewaysPauseMinutes = 45; // 30-60 по вашему запросу

input group "=== СОГЛАСИЕ НЕДАВНЕГО ИМПУЛЬСА (v5.4, по запросу) ==="
// "Определять направление рынка и открывать позицию ПО направлению рынка".
// v5.4 изначально отменяла вход, только если ВСЕ последние свечи были
// против сделки — этого оказалось мало: если из 5 свечей 4 зелёных и 1
// красная, вход в шорт всё равно проходил (ваш пример "куча зелёных и одна
// красная, а входит в шорт"). Теперь считаем ПЕРЕВЕС бычьих/медвежьих
// свечей за последние InpMomentumLookback баров и требуем, чтобы БОЛЬШИНСТВО
// было ЗА направление сделки — не просто "не все против".
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

input group "=== БЕЗУБЫТОК / ЧАСТИЧНОЕ ЗАКРЫТИЕ / ТРЕЙЛИНГ (перенесено из v4.9 по запросу) ==="
// Перенесено из XAUUSD_TimeStrategy_EA_v4.9 — ТЕ ЖЕ механизмы, что уже
// проверены на реальном счёте. Это НЕ "гарантия без минуса" (см. пояснение
// в чате) — это управление уже прибыльной позицией: снижает средний убыток
// и защищает часть плавающей прибыли, но если цена сразу пойдёт против
// сделки, не дойдя до порога безубытка, позиция всё равно закроется по
// своему обычному SL в минус — как и в v4.9.
input bool    InpUseBreakEven        = true;
input int     InpBreakEvenTriggerPts = 60;   // профит в пунктах для переноса SL в безубыток
input int     InpBreakEvenLockPts    = 15;   // сколько пунктов профита фиксируем при переносе
input bool    InpUsePartialClose     = true;
input double  InpPartialClosePct     = 50.0; // % объёма закрыть частично
input double  InpPartialCloseAtTPPct = 60.0; // на скольки % от дистанции до TP делать частичное закрытие
input bool    InpUseTrailingStop     = true;
input int     InpTrailingStartPts    = 120;  // профит для начала трейлинга (после безубытка)
input int     InpTrailingStepPts     = 70;   // дистанция трейлинга от текущей цены

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
input int     InpStallMaxMinutes    = 12;   // требуемая стагнация при прибыли ~InpMinTPPts (было 30 — банкуем +50 быстрее)
input double  InpStallEpsilonPts    = 20;   // допуск на шум для "новый пик"

input group "=== ЗАМОК ПРИБЫЛИ (по запросу: закрыть в плюс, не дать развернуться в стоп) ==="
// "Закрывались минимум в плюс 50 пунктов; если цена долго стоит в плюсе — нужно
// закрывать, чтобы не было разворота и не выкинуло по стопам." В отличие от
// StallExit (закрывает по ВРЕМЕНИ простоя) этот замок закрывает по ОТКАТУ от
// пика прибыли — он проверяется НА КАЖДОМ ТИКЕ, поэтому реагирует на разворот
// сразу, а не через минуты. Как только плавающая прибыль хоть раз достигла
// InpProfitLockActivatePts, ставится "плавающий пол": max(InpProfitLockFloorPts,
// пик − InpProfitLockGiveBackPts). Если прибыль откатывается до этого пола —
// закрываемся В ПЛЮСЕ немедленно, не дожидаясь, пока разворот съест профит и
// уведёт в стоп. Пол НИКОГДА не опускается ниже InpProfitLockFloorPts (ваше
// "минимум +50"). ВАЖНО: замок работает только ПОСЛЕ того как прибыль
// достигла порога активации — если цена сразу пошла против входа и профита не
// было вовсе, замок не поможет (это защищает прибыль, а не отменяет убыток).
input bool    InpUseProfitLock         = true;
input double  InpProfitLockActivatePts = 70;  // с какого пика прибыли включается замок
input double  InpProfitLockGiveBackPts = 25;  // сколько пунктов от пика позволяем отдать до закрытия
input double  InpProfitLockFloorPts    = 50;  // плавающий пол не опускается ниже (минимум +50 пт)

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
SwingPoint g_m15Swings[];
SRZone     g_m15Zones[];
SwingPoint g_ltfSwings[];
SRZone     g_ltfZones[];

datetime g_last_h4_bar   = 0;
datetime g_last_m15_bar  = 0;
datetime g_last_ltf_bar  = 0;
datetime g_last_day      = 0;
datetime g_scanPauseUntil = 0; // "боковик" — сканирование новых входов приостановлено до этого момента

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

// Живой статус для панели — единый источник правды: считается один раз в
// OnTick и используется И для решения о входе (CheckEntry), И для панели
// (DrawPanel), чтобы не гадать, что именно блокирует вход — панель теперь
// показывает результат КАЖДОГО шага живьём.
bool     g_haveRange    = false;
bool     g_rangeIsFallback = false; // рамка из max/min H4, а не из подтверждённых зон
bool     g_rangeWidthOk = false;
SRZone   g_curRes, g_curSup;
int      g_swingBias   = 0;
bool     g_maLong = false, g_maShort = false;
bool     g_inSession = false;
bool     g_nearSupport = false, g_nearResistance = false;
bool     g_m15ConfirmSupport = false, g_m15ConfirmResistance = false;
bool     g_sidewaysPaused = false;
string   g_lastSignalDetail = "";

struct PosPnlEntry  { ulong posId; double pnl; };
PosPnlEntry g_posPnl[];

// Для динамической фиксации прибыли при стагнации (StallExit) + перенесённое
// из v4.9 состояние безубытка/частичного закрытия (одна позиция — одна запись).
struct PosStallState { ulong posId; double peakPts; datetime peakTime; bool beDone; bool partialDone; double lockPeakPts; };
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
   g_posStall[n].beDone = false;
   g_posStall[n].partialDone = false;
   g_posStall[n].lockPeakPts = 0.0;  // отдельный пик для ЗАМКА ПРИБЫЛИ (обновляется каждый тик)
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
   // НАЙДЕНО (полный аудит): при InpSessionStartHour=16:30 и
   // InpSessionWindowMinutes=900 расчётный конец окна = 990+900=1890 минут —
   // а curHM (минуты с начала ТЕКУЩИХ суток) физически не может превысить
   // 1439. Значит curHM >= endHM никогда не срабатывало в течение того же
   // календарного дня, и окно МОЛЧА обрывалось на полуночи — реально
   // получалось только ~450 минут (16:30-24:00) вместо заявленных 900. Это
   // силой резало половину настроенного окна сессии. Исправлено — окно,
   // переходящее через полночь, теперь корректно продолжается в раннее утро
   // следующего календарного дня.
   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   int curHM = dt.hour * 60 + dt.min;
   int startHM = InpSessionStartHour * 60 + InpSessionStartMinute;
   int endHM = startHM + InpSessionWindowMinutes;

   bool inWindow;
   if(endHM <= 1440)
      inWindow = (curHM >= startHM && curHM < endHM);
   else
      inWindow = (curHM >= startHM) || (curHM < endHM - 1440);
   if(!inWindow) return false;

   if(InpSkipFirstCandle)
   {
      datetime todayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
      datetime sessionStart = (datetime)(todayStart + startHM * 60);
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
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int    minStop = GetMinStopPoints();

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

      // "Торги до 22:00 по Кишинёву" — независимо от того, сколько уже длится
      // сделка и что показывает InpMaxHoldMinutes, к этому часу (время сервера)
      // позиция закрывается принудительно.
      {
         MqlDateTime nowDt;
         TimeToStruct(now, nowDt);
         int nowHM = nowDt.hour * 60 + nowDt.min;
         int endHM = InpTradingEndHour * 60 + InpTradingEndMinute;
         if(nowHM >= endHM)
         {
            if(trade.PositionClose(ticket))
               Print("🌙 Закрыто по концу торгового дня (", StringFormat("%02d:%02d", InpTradingEndHour, InpTradingEndMinute), "): тикет ", ticket);
            continue;
         }
      }

      // --- Замок прибыли (каждый тик, приоритетнее БУ/трейлинга) ---
      // Закрывает В ПЛЮСЕ при откате от пика прибыли, чтобы разворот не съел
      // профит и не увёл в стоп. См. пояснение у InpUseProfitLock.
      if(InpUseProfitLock)
      {
         ENUM_POSITION_TYPE ptype = posInfo.PositionType();
         double popen = posInfo.PriceOpen();
         double pbid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double pask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profNow = (ptype == POSITION_TYPE_BUY) ? (pbid - popen) / point : (popen - pask) / point;

         int lIdx = GetOrCreateStall(posId);
         if(profNow > g_posStall[lIdx].lockPeakPts) g_posStall[lIdx].lockPeakPts = profNow;

         if(g_posStall[lIdx].lockPeakPts >= InpProfitLockActivatePts)
         {
            double floorPts = MathMax(InpProfitLockFloorPts, g_posStall[lIdx].lockPeakPts - InpProfitLockGiveBackPts);
            if(profNow <= floorPts)
            {
               if(trade.PositionClose(ticket))
                  Print("🔐 Замок прибыли: тикет ", ticket, " закрыт на +", DoubleToString(profNow, 0),
                        "пт (пик +", DoubleToString(g_posStall[lIdx].lockPeakPts, 0),
                        ", пол +", DoubleToString(floorPts, 0), ")");
               continue;
            }
         }
      }

      // --- Безубыток / частичное закрытие / трейлинг (перенесено из v4.9) ---
      {
         ENUM_POSITION_TYPE type = posInfo.PositionType();
         double openPrice = posInfo.PriceOpen();
         double curSL = posInfo.StopLoss();
         double curTP = posInfo.TakeProfit();
         double volume = posInfo.Volume();
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profitPtsMgmt = (type == POSITION_TYPE_BUY) ? (bid - openPrice) / point : (openPrice - ask) / point;

         int mIdx = GetOrCreateStall(posId);

         if(InpUseBreakEven && !g_posStall[mIdx].beDone && profitPtsMgmt >= InpBreakEvenTriggerPts)
         {
            int lockPts = MathMax(InpBreakEvenLockPts, minStop);
            double newSL = (type == POSITION_TYPE_BUY)
                            ? NormalizeDouble(openPrice + lockPts * point, digits)
                            : NormalizeDouble(openPrice - lockPts * point, digits);
            bool improves = (type == POSITION_TYPE_BUY) ? (curSL < newSL) : (curSL == 0.0 || curSL > newSL);
            if(improves)
            {
               if(trade.PositionModify(ticket, newSL, curTP))
               {
                  g_posStall[mIdx].beDone = true;
                  curSL = newSL;
                  Print("🔒 Безубыток: тикет ", ticket, " SL→", DoubleToString(newSL, digits));
               }
            }
            else
               g_posStall[mIdx].beDone = true;
         }

         if(InpUsePartialClose && !g_posStall[mIdx].partialDone)
         {
            double tpDist = (curTP != 0.0) ? MathAbs(curTP - openPrice) / point : InpMinTPPts;
            double target = tpDist * (InpPartialCloseAtTPPct / 100.0);
            if(profitPtsMgmt >= target)
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
                     g_posStall[mIdx].partialDone = true;
                     Print("💰 Частичное закрытие: тикет ", ticket, " объём ", DoubleToString(closeVol, 2));
                  }
               }
               else
                  g_posStall[mIdx].partialDone = true;
            }
         }

         if(InpUseTrailingStop && g_posStall[mIdx].beDone && profitPtsMgmt >= InpTrailingStartPts)
         {
            int stepPts = MathMax(InpTrailingStepPts, minStop);
            if(type == POSITION_TYPE_BUY)
            {
               double newSL = NormalizeDouble(bid - stepPts * point, digits);
               if(newSL > curSL)
                  trade.PositionModify(ticket, newSL, curTP);
            }
            else
            {
               double newSL = NormalizeDouble(ask + stepPts * point, digits);
               if(curSL == 0.0 || newSL < curSL)
                  trade.PositionModify(ticket, newSL, curTP);
            }
         }
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
   // НАЙДЕНО (реальный прогон): старая версия требовала "ВСЕ свечи против",
   // чтобы отменить вход — этого было мало. Если из 5 последних свечей 4
   // зелёных и 1 красная, старая проверка всё равно пропускала ШОРТ (нашла
   // хотя бы одну не-бычью свечу и сразу решила "согласие есть"). Это и есть
   // ваш пример "куча зелёных свечей и одна красная, а код входит в шорт".
   // Теперь считаем ПЕРЕВЕС: сколько свечей бычьих, сколько медвежьих, и
   // требуем, чтобы БОЛЬШИНСТВО было ЗА направление сделки — не просто
   // "не все против".
   int bullishCount = 0, bearishCount = 0;
   for(int shift = 1; shift <= lookback; shift++)
   {
      double o = iOpen(_Symbol, PERIOD_M5, shift);
      double c = iClose(_Symbol, PERIOD_M5, shift);
      if(c > o) bullishCount++;
      else if(c < o) bearishCount++;
      // дожи (c==o) не считаем ни туда, ни сюда
   }
   if(direction == 1)  return bullishCount > bearishCount;
   if(direction == -1) return bearishCount > bullishCount;
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

   // Запасной триггер (см. пояснение у InpUseSimpleBreakout): подтверждённое
   // закрытие за экстремумом последних N M5-баров, когда формальной зоны с
   // нужным числом касаний рядом не оказалось. Сканируем бары 2..N+1 — сам
   // сигнальный бар (shift=1) в свой же экстремум не входит.
   if(InpUseSimpleBreakout && InpSimpleBreakoutBars > 0)
   {
      if(direction == 1)
      {
         double hh = -DBL_MAX;
         for(int s = 2; s <= InpSimpleBreakoutBars + 1; s++)
            hh = MathMax(hh, iHigh(_Symbol, PERIOD_M5, s));
         if(hh > -DBL_MAX && closePrice > hh)
         {
            g_lastSignalDetail = StringFormat("Микропробой: закрытие %.2f выше max последних %d M5-баров (%.2f)",
                                               closePrice, InpSimpleBreakoutBars, hh);
            return true;
         }
      }
      else
      {
         double ll = DBL_MAX;
         for(int s = 2; s <= InpSimpleBreakoutBars + 1; s++)
            ll = MathMin(ll, iLow(_Symbol, PERIOD_M5, s));
         if(ll < DBL_MAX && closePrice < ll)
         {
            g_lastSignalDetail = StringFormat("Микропробой: закрытие %.2f ниже min последних %d M5-баров (%.2f)",
                                               closePrice, InpSimpleBreakoutBars, ll);
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
   if(g_sidewaysPaused) return; // боковик — ждём коррекцию (см. InpSidewaysPauseMinutes)
   if(!g_inSession) return;
   if(!g_haveRange) return;
   if(!g_rangeWidthOk) return; // не реальный боковик, а два далёких старых уровня

   bool wantLong  = g_nearSupport    && (g_swingBias >= 0) && g_maLong  && g_m15ConfirmSupport;
   bool wantShort = g_nearResistance && (g_swingBias <= 0) && g_maShort && g_m15ConfirmResistance;

   if(!SpreadOK()) return;
   if(!CalendarClear()) return;

   if(wantLong && TryLtfBreakout(1))
   {
      if(!InpRequireMomentumAgree || RecentCandlesAgree(1, InpMomentumLookback))
         OpenTrade(1);
      else
      {
         Print("⚠️ Пробой вверх есть, но среди последних ", InpMomentumLookback,
               " M5-свечей нет перевеса бычьих — вход отменён");
         g_lastSignalDetail += StringFormat(" [ОТМЕНЕНО: нет перевеса зелёных свечей из %d]", InpMomentumLookback);
      }
   }
   else if(wantShort && TryLtfBreakout(-1))
   {
      if(!InpRequireMomentumAgree || RecentCandlesAgree(-1, InpMomentumLookback))
         OpenTrade(-1);
      else
      {
         Print("⚠️ Пробой вниз есть, но среди последних ", InpMomentumLookback,
               " M5-свечей нет перевеса медвежьих — вход отменён");
         g_lastSignalDetail += StringFormat(" [ОТМЕНЕНО: нет перевеса красных свечей из %d]", InpMomentumLookback);
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
   if(InpMABufferPts < 0.0 || InpMASlopeBars <= 0)
   {
      Print("❌ ERROR: InpMABufferPts должен быть ≥ 0, InpMASlopeBars должен быть > 0");
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
   if(InpTradingEndHour < 0 || InpTradingEndHour > 23 || InpTradingEndMinute < 0 || InpTradingEndMinute > 59)
   {
      Print("❌ ERROR: InpTradingEndHour/Minute вне диапазона");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpM15PivotLegBars <= 0 || InpM15LookbackBars <= 0)
   {
      Print("❌ ERROR: InpM15PivotLegBars/InpM15LookbackBars должны быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpM15MinTouches < 1)
   {
      Print("❌ ERROR: InpM15MinTouches должен быть ≥ 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSidewaysPauseMinutes <= 0)
   {
      Print("❌ ERROR: InpSidewaysPauseMinutes должен быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseHLFallbackRange && InpHLRangeBars <= 0)
   {
      Print("❌ ERROR: InpHLRangeBars должен быть > 0 при включённой запасной рамке");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseSimpleBreakout && InpSimpleBreakoutBars <= 0)
   {
      Print("❌ ERROR: InpSimpleBreakoutBars должен быть > 0 при включённом микропробое");
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
   if(InpMaxRangeWidthPts < 0)
   {
      Print("❌ ERROR: InpMaxRangeWidthPts не может быть отрицательным (0 = проверка выключена)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseStallExit && (InpStallUpperRefPts <= InpMinTPPts || InpStallMinMinutes <= 0 || InpStallMaxMinutes <= 0))
   {
      Print("❌ ERROR: InpStallUpperRefPts должен быть > InpMinTPPts, InpStallMin/MaxMinutes должны быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseProfitLock)
   {
      if(InpProfitLockFloorPts <= 0.0 || InpProfitLockGiveBackPts <= 0.0)
      {
         Print("❌ ERROR: InpProfitLockFloorPts и InpProfitLockGiveBackPts должны быть > 0");
         return INIT_PARAMETERS_INCORRECT;
      }
      if(InpProfitLockActivatePts < InpProfitLockFloorPts)
      {
         Print("❌ ERROR: InpProfitLockActivatePts должен быть ≥ InpProfitLockFloorPts (нельзя защитить пол выше пика активации)");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(InpUseBreakEven && (InpBreakEvenTriggerPts <= 0 || InpBreakEvenLockPts <= 0))
   {
      Print("❌ ERROR: InpBreakEvenTriggerPts и InpBreakEvenLockPts должны быть > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseBreakEven && InpBreakEvenLockPts >= InpBreakEvenTriggerPts)
   {
      Print("❌ ERROR: InpBreakEvenLockPts должен быть МЕНЬШЕ InpBreakEvenTriggerPts");
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
   if(InpUseTrailingStop && (InpTrailingStartPts <= 0 || InpTrailingStepPts <= 0))
   {
      Print("❌ ERROR: InpTrailingStartPts и InpTrailingStepPts должны быть > 0");
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
   g_last_m15_bar = 0;
   g_last_ltf_bar = 0;
   g_last_day     = 0;
   g_scanPauseUntil = 0;
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
   Print("Шаг 2: окно ВХОДА ", StringFormat("%02d:%02d", InpSessionStartHour, InpSessionStartMinute),
         " + ", InpSessionWindowMinutes, " мин, пропуск первой свечи: ", (InpSkipFirstCandle?"ON":"OFF"),
         ", MA(", InpMAPeriod, ") с буфером ", InpMABufferPts, "пт и наклоном за ", InpMASlopeBars,
         " баров как фильтр направления");
   Print("Шаг 2b: M15 подтверждение (leg=", InpM15PivotLegBars, " lookback=", InpM15LookbackBars,
         " кластер=", InpM15ZoneClusterPts, "пт мин.касаний=", InpM15MinTouches, ")");
   Print("Шаг 3-4: M5 зоны (leg=", InpLtfPivotLegBars, " lookback=", InpLtfLookbackBars,
         " кластер=", InpLtfZoneClusterPts, "пт) — вход по подтверждённому закрытию за зоной");
   Print("SL буфер: ", InpSLBufferPts, "пт | TP на ", InpTPAtOppositeZonePct, "% пути до противоположной зоны");
   Print("Макс. удержание сделки: ", InpMaxHoldMinutes, " мин | конец торгового дня: ",
         StringFormat("%02d:%02d", InpTradingEndHour, InpTradingEndMinute));
   Print("Боковик-пауза: ", InpSidewaysPauseMinutes, " мин");
   Print("Безубыток: ", (InpUseBreakEven ? "ON" : "OFF"),
         " | Частичное закрытие: ", (InpUsePartialClose ? "ON" : "OFF"),
         " | Трейлинг: ", (InpUseTrailingStop ? "ON" : "OFF"));
   if(InpUseProfitLock)
      Print("Замок прибыли: активация +", DoubleToString(InpProfitLockActivatePts, 0),
            "пт, отдаём max ", DoubleToString(InpProfitLockGiveBackPts, 0),
            "пт от пика, пол +", DoubleToString(InpProfitLockFloorPts, 0), "пт");
   if(InpRequireMomentumAgree)
      Print("Согласие импульса: вход отменяется без перевеса свечей (бычьих/медвежьих) ",
            "за направление сделки среди последних ", InpMomentumLookback, " M5-свечей");
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
   bool isNewH4Bar = (curH4Bar != g_last_h4_bar);
   if(isNewH4Bar)
   {
      g_last_h4_bar = curH4Bar;
      DetectSwings(PERIOD_H4, InpH4PivotLegBars, InpH4LookbackBars, g_h4Swings);
      ClusterZones(g_h4Swings, InpH4ZoneClusterPts, InpH4MinTouches, g_h4Zones);
      g_swingBias = GetSwingTrendBias(g_h4Swings, InpSwingConfirmCount);
   }

   // --- Шаг 2b: пересчёт M15 зон раз за M15-бар (подтверждение, см. вход. параметры) ---
   datetime curM15Bar = iTime(_Symbol, PERIOD_M15, 0);
   if(curM15Bar != g_last_m15_bar)
   {
      g_last_m15_bar = curM15Bar;
      DetectSwings(PERIOD_M15, InpM15PivotLegBars, InpM15LookbackBars, g_m15Swings);
      ClusterZones(g_m15Swings, InpM15ZoneClusterPts, InpM15MinTouches, g_m15Zones);
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
   g_rangeIsFallback = false;

   // Запасная рамка "максимум/минимум H4" (см. пояснение у InpUseHLFallbackRange):
   // подтверждённый зонный коридор в тренде часто не существует (нет зоны выше
   // цены на хаях) — тогда рамкой становятся max/min последних InpHLRangeBars
   // завершённых H4-баров. Толщина синтетической зоны = InpH4ZoneClusterPts.
   if(!g_haveRange && InpUseHLFallbackRange && InpHLRangeBars > 0)
   {
      double hh = -DBL_MAX, ll = DBL_MAX;
      for(int b = 1; b <= InpHLRangeBars; b++)
      {
         double bh = iHigh(_Symbol, PERIOD_H4, b);
         double bl = iLow(_Symbol, PERIOD_H4, b);
         if(bh > 0.0) hh = MathMax(hh, bh);
         if(bl > 0.0) ll = MathMin(ll, bl);
      }
      if(hh > -DBL_MAX && ll < DBL_MAX && hh > curPrice && ll < curPrice)
      {
         double zw = InpH4ZoneClusterPts * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         g_curRes.hi = hh; g_curRes.lo = hh - zw; g_curRes.touches = 1;
         g_curRes.isResistance = true;  g_curRes.anchor = hh;
         g_curSup.lo = ll; g_curSup.hi = ll + zw; g_curSup.touches = 1;
         g_curSup.isResistance = false; g_curSup.anchor = ll;
         g_haveRange = true;
         g_rangeIsFallback = true;
      }
   }

   // "Если боковик — пауза 30-60 минут, ждём коррекции" — проверяем ровно
   // когда H4-структура пересчиталась (раз в 4 часа), а не на каждом тике.
   // НАЙДЕНО (funnel-прогон): первая версия ставила паузу ещё и при
   // g_swingBias==0 — но нейтральная структура свингов ВХОД НЕ БЛОКИРУЕТ
   // (CheckEntry разрешает bias>=0 для лонга и bias<=0 для шорта), а H4-бар
   // открывается ровно в 16:00 — пауза до 16:45 съедала 45 из 60 минут
   // вашего окна входа 16:30-17:30 почти каждый день. Теперь пауза только
   // когда диапазона нет ВООБЩЕ (реально нечего сканировать).
   if(isNewH4Bar && !g_haveRange)
   {
      g_scanPauseUntil = (datetime)(TimeCurrent() + (long)InpSidewaysPauseMinutes * 60);
      Print("💤 Нет H4-диапазона — пауза сканирования входов на ", InpSidewaysPauseMinutes, " мин");
   }
   g_sidewaysPaused = (TimeCurrent() < g_scanPauseUntil);

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_haveRange)
   {
      g_rangeWidthOk   = (InpMaxRangeWidthPts <= 0.0) ||
                         ((g_curRes.lo - g_curSup.hi) / point <= InpMaxRangeWidthPts);
      g_nearSupport    = (curPrice >= g_curSup.lo) && ((curPrice - g_curSup.hi) / point <= InpZoneProximityPts);
      g_nearResistance = (curPrice <= g_curRes.hi) && ((g_curRes.lo - curPrice) / point <= InpZoneProximityPts);
   }
   else
   {
      g_rangeWidthOk = false;
      g_nearSupport = false;
      g_nearResistance = false;
   }

   // Шаг 2b: подтверждение на M15 — та же сторона (поддержка/сопротивление),
   // что и на H4, но с независимой кластеризацией на M15 (там, по вашим
   // словам, касания видно ещё чётче). Требуем близость к M15-зоне с
   // накопленными InpM15MinTouches касаниями — это и есть "два-три
   // подтверждения" разворота в этом месте.
   //
   // НАЙДЕНО (funnel-прогон): первая версия искала M15-поддержку СТРОГО НИЖЕ
   // цены (через GetActiveRange) — но у H4-поддержки цена стоит на локальном
   // минимуме, и M15-зона, от которой отбиваемся, лежит ВОКРУГ цены, а не под
   // ней. Проверка исключала ровно ту зону, которую должна была подтверждать
   // (13 кандидатов за год → 3). Теперь ищем ближайшую M15-зону нужного типа,
   // до края которой не дальше InpM15ZoneProximityPts — включая случай, когда
   // цена ВНУТРИ зоны.
   g_m15ConfirmSupport = false;
   g_m15ConfirmResistance = false;
   for(int zi = 0; zi < ArraySize(g_m15Zones); zi++)
   {
      if(g_m15Zones[zi].touches < InpM15MinTouches) continue;
      double distPts;
      if(curPrice < g_m15Zones[zi].lo)      distPts = (g_m15Zones[zi].lo - curPrice) / point;
      else if(curPrice > g_m15Zones[zi].hi) distPts = (curPrice - g_m15Zones[zi].hi) / point;
      else                                   distPts = 0.0; // цена внутри зоны
      if(distPts > InpM15ZoneProximityPts) continue;
      if(g_m15Zones[zi].isResistance) g_m15ConfirmResistance = true;
      else                            g_m15ConfirmSupport = true;
   }

   // Буфер + наклон (см. пояснение у InpMABufferPts выше) — без этого мелкий
   // отскок цены через линию MA на пару пунктов мгновенно переключал
   // показанное направление туда-обратно ("рынок падает — шорт, чуть
   // поднялось — сразу лонг, снова падает — снова шорт").
   double maNow  = BufferVal(h_ma, 0, 1);
   double maPrev = BufferVal(h_ma, 0, 1 + InpMASlopeBars);
   if(maNow != EMPTY_VALUE && maPrev != EMPTY_VALUE)
   {
      double buffer = InpMABufferPts * point;
      bool maRising  = maNow > maPrev;
      bool maFalling = maNow < maPrev;
      // Наклон MA — опционально (см. пояснение у InpMARequireSlope): у зоны
      // поддержки/сопротивления MA(50) разворачивается позже цены, жёсткое
      // требование наклона делало лонг у поддержки практически невозможным.
      g_maLong  = (curPrice > maNow + buffer) && (!InpMARequireSlope || maRising);
      g_maShort = (curPrice < maNow - buffer) && (!InpMARequireSlope || maFalling);
   }
   else
   {
      g_maLong = false;
      g_maShort = false;
   }

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
      string srcTag = g_rangeIsFallback ? " [по max/min H4]" : "";
      texts[n] = StringFormat("Сопротивление: %.2f-%.2f (%d кас.)%s", g_curRes.lo, g_curRes.hi, g_curRes.touches, srcTag);
      colors[n] = InpColorBad; n++;
      texts[n] = StringFormat("Поддержка: %.2f-%.2f (%d кас.)%s", g_curSup.lo, g_curSup.hi, g_curSup.touches, srcTag);
      colors[n] = InpColorGood; n++;
      if(InpMaxRangeWidthPts > 0.0)
      {
         texts[n] = StringFormat("Ширина: %.0fпт %s (лимит %.0f)", widthPts,
                                  g_rangeWidthOk ? "✅" : "❌ слишком широко", InpMaxRangeWidthPts);
         colors[n] = g_rangeWidthOk ? InpColorGood : InpColorBad; n++;
      }
      else
      {
         texts[n] = StringFormat("Ширина: %.0fпт (лимит выключен)", widthPts);
         colors[n] = InpColorNeutral; n++;
      }
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

   // Живой чек-лист: что ИМЕННО сейчас блокирует вход. Раньше приходилось
   // гадать/присылать скриншоты, чтобы понять, на каком из условий застряли —
   // теперь видно на самом графике.
   texts[n] = "─── ПОЧЕМУ НЕ ВХОДИМ (живой чек-лист) ───"; colors[n] = InpColorHeader; n++;
   texts[n] = StringFormat("Диапазон найден: %s", g_haveRange ? "✅" : "❌");
   colors[n] = g_haveRange ? InpColorGood : InpColorBad; n++;
   texts[n] = StringFormat("Ширина диапазона ОК: %s", g_haveRange ? (g_rangeWidthOk ? "✅" : "❌") : "—");
   colors[n] = (g_haveRange && g_rangeWidthOk) ? InpColorGood : InpColorBad; n++;
   texts[n] = StringFormat("Цена у поддержки: %s | у сопротивления: %s",
                            g_nearSupport ? "✅" : "❌", g_nearResistance ? "✅" : "❌");
   colors[n] = (g_nearSupport || g_nearResistance) ? InpColorGood : InpColorBad; n++;
   texts[n] = StringFormat("MA(%d) согласна: %s", InpMAPeriod,
                            (g_maLong || g_maShort) ? (g_maLong ? "✅ (лонг)" : "✅ (шорт)") : "❌");
   colors[n] = (g_maLong || g_maShort) ? InpColorGood : InpColorBad; n++;
   texts[n] = StringFormat("M15 подтверждение: у поддержки %s | у сопротивления %s",
                            g_m15ConfirmSupport ? "✅" : "❌", g_m15ConfirmResistance ? "✅" : "❌");
   colors[n] = (g_m15ConfirmSupport || g_m15ConfirmResistance) ? InpColorGood : InpColorBad; n++;
   texts[n] = StringFormat("Окно входа (сессия) активно: %s", g_inSession ? "✅" : "❌");
   colors[n] = g_inSession ? InpColorGood : InpColorBad; n++;
   texts[n] = StringFormat("Боковик-пауза: %s", g_sidewaysPaused
                            ? StringFormat("⏸ ещё %d мин", (int)MathMax(0, (g_scanPauseUntil - TimeCurrent()) / 60))
                            : "✅ нет паузы");
   colors[n] = g_sidewaysPaused ? InpColorBad : InpColorGood; n++;
   bool readyLong  = g_haveRange && g_rangeWidthOk && g_nearSupport    && (g_swingBias >= 0) && g_maLong  && g_m15ConfirmSupport    && g_inSession && !g_sidewaysPaused;
   bool readyShort = g_haveRange && g_rangeWidthOk && g_nearResistance && (g_swingBias <= 0) && g_maShort && g_m15ConfirmResistance && g_inSession && !g_sidewaysPaused;
   if(readyLong || readyShort)
   {
      texts[n] = StringFormat("Все условия ОК (%s) — ждём пробой M5-зоны", readyLong ? "ЛОНГ" : "ШОРТ");
      colors[n] = InpColorGood; n++;
   }
   else
   {
      texts[n] = "Не все условия совпали — сделка невозможна прямо сейчас"; colors[n] = InpColorNeutral; n++;
   }
   texts[n] = StringFormat("Торговый день до %02d:%02d (сервер)", InpTradingEndHour, InpTradingEndMinute);
   colors[n] = InpColorNeutral; n++;
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
