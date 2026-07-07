//+------------------------------------------------------------------+
//|              XAU_SessionVolatilityAnalyzer.mq5                    |
//|                                                                  |
//|  Разовый скрипт (не EA — ничего не торгует, просто анализирует  |
//|  уже имеющуюся в терминале историю цены). Отвечает на вопрос:    |
//|  "в какие часы суток золото реально сильнее всего двигается?"   |
//|                                                                  |
//|  Вместо того чтобы неделю наблюдать вручную, скрипт считает     |
//|  статистику по каждому часу суток (00-23, время сервера) за     |
//|  последние InpLookbackDays дней истории: средний диапазон       |
//|  (high-low), среднее направленное движение (close-open), сколько|
//|  раз час был "вверх" / "вниз", и то же самое по дням недели.    |
//|                                                                  |
//|  Результат: таблица в журнале "Эксперты" + CSV-файл в           |
//|  MQL5\Files\ (или Tester\Files при тесте), который можно открыть|
//|  в Excel/Google Sheets и построить график.                       |
//|                                                                  |
//|  КАК ЗАПУСТИТЬ:                                                   |
//|  1. Скомпилировать в MetaEditor.                                  |
//|  2. Перетащить на график НУЖНОГО символа (например XAUUSD) —     |
//|     скрипт анализирует именно символ того графика, на который   |
//|     его бросили (или укажите InpSymbol вручную).                 |
//|  3. В диалоге входных параметров при желании поменять             |
//|     InpLookbackDays (по умолчанию 90 дней).                      |
//|  4. Результат появится в журнале "Эксперты"/"Терминал" сразу     |
//|     после запуска — скрипт не остаётся висеть, разово отработал |
//|     и завершился.                                                 |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input string          InpSymbol       = "";        // "" = символ текущего графика
input int             InpLookbackDays = 90;        // сколько дней истории анализировать
input ENUM_TIMEFRAMES InpBucketTF     = PERIOD_H1;  // таймфрейм для разбивки по часам (H1 рекомендуется)
input bool            InpWriteCSV     = true;
input string          InpCSVName      = "XAU_SessionStats.csv";

struct HourStats
{
   int    count;
   double sumRange;
   double sumMove;
   double sumAbsMove;
   int    upCount;
   int    downCount;
};

struct DowStats
{
   int    count;
   double sumRange;
   double sumMove;
   int    upCount;
   int    downCount;
};

void OnStart()
{
   string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0) point = 0.01;

   datetime endTime   = TimeCurrent();
   datetime startTime = endTime - (long)InpLookbackDays * 24 * 60 * 60;

   MqlRates rates[];
   ArraySetAsSeries(rates, false); // явно: index 0 = самый старый бар из выборки,
                                   // index[total-1] = самый свежий — не полагаемся
                                   // на поведение MQL5 по умолчанию для динамических массивов.
   int total = CopyRates(symbol, InpBucketTF, startTime, endTime, rates);
   if(total <= 0)
   {
      Print("❌ Не удалось получить историю для ", symbol,
            " — проверьте, что символ верный и история загружена (Центр загрузки истории).");
      return;
   }

   HourStats hourStats[24];
   DowStats  dowStats[7];
   // ArrayInitialize() работает только с числовыми массивами, не со структурами —
   // обнуляем поля вручную.
   for(int i = 0; i < 24; i++)
   {
      hourStats[i].count = 0; hourStats[i].sumRange = 0; hourStats[i].sumMove = 0;
      hourStats[i].sumAbsMove = 0; hourStats[i].upCount = 0; hourStats[i].downCount = 0;
   }
   for(int i = 0; i < 7; i++)
   {
      dowStats[i].count = 0; dowStats[i].sumRange = 0; dowStats[i].sumMove = 0;
      dowStats[i].upCount = 0; dowStats[i].downCount = 0;
   }

   datetime actualFirst = rates[0].time;
   datetime actualLast  = rates[total - 1].time;

   for(int i = 0; i < total; i++)
   {
      MqlDateTime dt;
      TimeToStruct(rates[i].time, dt);

      double rng  = rates[i].high - rates[i].low;
      double move = rates[i].close - rates[i].open;

      int h = dt.hour;
      hourStats[h].count++;
      hourStats[h].sumRange   += rng;
      hourStats[h].sumMove    += move;
      hourStats[h].sumAbsMove += MathAbs(move);
      if(move > 0) hourStats[h].upCount++;
      else if(move < 0) hourStats[h].downCount++;

      int d = dt.day_of_week; // 0=Вс, 1=Пн ... 6=Сб
      dowStats[d].count++;
      dowStats[d].sumRange += rng;
      dowStats[d].sumMove  += move;
      if(move > 0) dowStats[d].upCount++;
      else if(move < 0) dowStats[d].downCount++;
   }

   // --- Таблица по часам, отсортированная по среднему диапазону (убывание) ---
   int order[24];
   for(int i = 0; i < 24; i++) order[i] = i;
   for(int i = 0; i < 24; i++)
   {
      for(int j = i + 1; j < 24; j++)
      {
         double avgI = (hourStats[order[i]].count > 0) ? hourStats[order[i]].sumRange / hourStats[order[i]].count : 0.0;
         double avgJ = (hourStats[order[j]].count > 0) ? hourStats[order[j]].sumRange / hourStats[order[j]].count : 0.0;
         if(avgJ > avgI)
         {
            int tmp = order[i]; order[i] = order[j]; order[j] = tmp;
         }
      }
   }

   Print("════════════════════════════════════════════════════════════");
   Print("XAU Session Volatility Analyzer | ", symbol, " | ТФ=", EnumToString(InpBucketTF));
   Print("Запрошено дней: ", InpLookbackDays, " | Реально доступно: ",
         TimeToString(actualFirst, TIME_DATE), " — ", TimeToString(actualLast, TIME_DATE),
         " (", total, " баров)");
   Print("Время — СЕРВЕРНОЕ (как в TimeCurrent() у советника), не забудьте про GMT-смещение брокера.");
   Print("────────────────────────────────────────────────────────────");
   Print("ЧАСЫ ПО УБЫВАНИЮ СРЕДНЕГО ДИАПАЗОНА (самые живые часы — вверху):");
   Print("Час  | Баров | Ср.диапазон | Ср.диапазон(pts) | Ср.движение | Вверх% | Вниз%");
   for(int i = 0; i < 24; i++)
   {
      int h = order[i];
      int cnt = hourStats[h].count;
      if(cnt == 0) continue;
      double avgRange = hourStats[h].sumRange / cnt;
      double avgMove  = hourStats[h].sumMove  / cnt;
      double upPct    = 100.0 * hourStats[h].upCount   / cnt;
      double downPct  = 100.0 * hourStats[h].downCount / cnt;
      PrintFormat("%02d:00 | %5d | %11.2f | %17.0f | %+11.2f | %5.1f%% | %5.1f%%",
                  h, cnt, avgRange, avgRange / point, avgMove, upPct, downPct);
   }

   Print("────────────────────────────────────────────────────────────");
   Print("ПО ДНЯМ НЕДЕЛИ:");
   Print("День | Баров | Ср.диапазон | Ср.движение | Вверх% | Вниз%");
   string dowNames[7] = {"Вс","Пн","Вт","Ср","Чт","Пт","Сб"};
   for(int d = 0; d < 7; d++)
   {
      int cnt = dowStats[d].count;
      if(cnt == 0) continue;
      double avgRange = dowStats[d].sumRange / cnt;
      double avgMove  = dowStats[d].sumMove  / cnt;
      double upPct    = 100.0 * dowStats[d].upCount   / cnt;
      double downPct  = 100.0 * dowStats[d].downCount / cnt;
      PrintFormat("%s   | %5d | %11.2f | %+11.2f | %5.1f%% | %5.1f%%",
                  dowNames[d], cnt, avgRange, avgMove, upPct, downPct);
   }
   Print("════════════════════════════════════════════════════════════");

   if(InpWriteCSV)
   {
      int fh = FileOpen(InpCSVName, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(fh == INVALID_HANDLE)
      {
         Print("⚠️ Не удалось открыть файл для записи CSV: ", InpCSVName,
               " (код ошибки ", GetLastError(), ")");
      }
      else
      {
         FileWrite(fh, "hour", "bar_count", "avg_range", "avg_range_points",
                   "avg_move", "avg_abs_move", "up_pct", "down_pct");
         for(int h = 0; h < 24; h++)
         {
            int cnt = hourStats[h].count;
            if(cnt == 0) continue;
            double avgRange = hourStats[h].sumRange / cnt;
            double avgMove  = hourStats[h].sumMove  / cnt;
            double avgAbs   = hourStats[h].sumAbsMove / cnt;
            double upPct    = 100.0 * hourStats[h].upCount   / cnt;
            double downPct  = 100.0 * hourStats[h].downCount / cnt;
            FileWrite(fh, h, cnt, avgRange, avgRange / point, avgMove, avgAbs, upPct, downPct);
         }
         FileClose(fh);
         Print("💾 CSV сохранён: MQL5/Files/", InpCSVName,
               " (в файловой системе терминала — Файл → Открыть каталог данных → MQL5 → Files)");
      }
   }
}
//+------------------------------------------------------------------+
