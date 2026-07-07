//+------------------------------------------------------------------+
//|              XAU_HistoryExporter.mq5                              |
//|                                                                  |
//|  Разовый скрипт (не EA — ничего не торгует). Выгружает "сырую"  |
//|  историю баров (Open/High/Low/Close/Volume) символа в CSV-файл,  |
//|  чтобы её можно было отдать на анализ вне терминала.             |
//|                                                                  |
//|  Нужен, когда в меню "Сервис" нет пункта "Центр истории котировок"|
//|  (бывает в некоторых сборках терминала у брокеров) — этот скрипт |
//|  делает то же самое программно, через стандартные функции MQL5, |
//|  и работает одинаково в любой сборке.                            |
//|                                                                  |
//|  КАК ЗАПУСТИТЬ:                                                   |
//|  1. Скомпилировать в MetaEditor.                                  |
//|  2. Перетащить на график XAUUSD (или указать InpSymbol вручную). |
//|  3. В диалоге параметров при желании увеличить InpLookbackDays    |
//|     (по умолчанию 365 дней) — но реально выгрузится столько,     |
//|     сколько истории есть в терминале (если брокер хранит меньше, |
//|     скрипт сначала попытается её дозапросить).                   |
//|  4. Результат — файл в каталоге данных терминала:                |
//|     Файл → Открыть каталог данных → MQL5 → Files → (имя файла).  |
//|     Этот CSV и нужно прислать для анализа.                        |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input string          InpSymbol       = "";              // "" = символ текущего графика
input int             InpLookbackDays = 365;              // сколько дней истории выгружать
input ENUM_TIMEFRAMES InpTF           = PERIOD_M15;        // таймфрейм баров
input string          InpCSVName      = "XAU_History_M15.csv";

void OnStart()
{
   string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;

   datetime endTime   = TimeCurrent();
   datetime startTime = endTime - (long)InpLookbackDays * 24 * 60 * 60;

   // Просим терминал догрузить историю у брокера, если её ещё нет локально.
   MqlRates warm[];
   CopyRates(symbol, InpTF, startTime, endTime, warm);

   MqlRates rates[];
   ArraySetAsSeries(rates, false); // явно: index 0 = самый старый бар, по возрастанию времени
   int total = CopyRates(symbol, InpTF, startTime, endTime, rates);

   if(total <= 0)
   {
      Print("❌ Не удалось получить историю для ", symbol,
            " на ТФ ", EnumToString(InpTF),
            ". Попробуйте открыть график этого символа/ТФ и прокрутить его в начало (клавиша Home), "
            "чтобы терминал догрузил историю у брокера, затем запустить скрипт снова.");
      return;
   }

   int fh = FileOpen(InpCSVName, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(fh == INVALID_HANDLE)
   {
      Print("❌ Не удалось открыть файл для записи: ", InpCSVName,
            " (код ошибки ", GetLastError(), ")");
      return;
   }

   FileWrite(fh, "datetime", "open", "high", "low", "close", "tick_volume");
   for(int i = 0; i < total; i++)
   {
      FileWrite(fh,
                TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES),
                DoubleToString(rates[i].open,  _Digits),
                DoubleToString(rates[i].high,  _Digits),
                DoubleToString(rates[i].low,   _Digits),
                DoubleToString(rates[i].close, _Digits),
                (long)rates[i].tick_volume);
   }
   FileClose(fh);

   Print("════════════════════════════════════════════════════════════");
   Print("✅ Экспортировано ", total, " баров (", symbol, ", ", EnumToString(InpTF), ")");
   Print("Период: ", TimeToString(rates[0].time, TIME_DATE),
         " — ", TimeToString(rates[total - 1].time, TIME_DATE));
   Print("💾 Файл: MQL5/Files/", InpCSVName);
   Print("Найти физически: Файл → Открыть каталог данных → папка MQL5 → Files → ", InpCSVName);
   Print("════════════════════════════════════════════════════════════");
}
//+------------------------------------------------------------------+
