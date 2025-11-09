//+------------------------------------------------------------------+
//| AutoFiboTouchEA.mq5                                              |
//| Final Version v1.40 (Fibo-Touch Logic, Clean Branding)           |
//| by Achyar Munandar                                               |
//+------------------------------------------------------------------+
#property version   "1.40"
#property strict
#include <Trade/Trade.mqh>

//--- Inputs
input double BalanceStep        = 2000.0;   // step saldo per kenaikan lot
input double StepLot            = 0.01;     // lot per step
input int    SL_Points          = 30000;    // Stop Loss (points)
input int    TP_Points          = 1000;     // Take Profit (points)
input double PosTolerancePoints = 200.0;    // toleransi sentuh level (points)
input int    MagicNumber        = 20251109; // magic number unik
input bool   ShowPanel          = true;     // tampilkan panel status

//--- internal
CTrade trade;
datetime lastTradeCandleTime = 0;

struct LevelTouch { double price; datetime candle; };
LevelTouch touchedLevels[];

//+------------------------------------------------------------------+
//| Utility Functions                                                 |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double minlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   if(lots < minlot) lots = minlot;
   if(lots > maxlot) lots = maxlot;
   double n = MathFloor(lots / step + 0.0000001);
   double res = n * step;
   int digits = (int)MathMax(0.0, MathLog10(1.0/step));
   return NormalizeDouble(res, digits);
}

double ComputeLotByBalance()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   int stepCount = (int)MathFloor(bal / BalanceStep);
   double lot = StepLot * (stepCount + 1);
   return NormalizeLot(lot);
}

datetime CurrentCandleOpen()
{
   MqlRates r[1];
   if(CopyRates(_Symbol, Period(), 0, 1, r) > 0)
      return r[0].time;
   return TimeCurrent();
}

bool AlreadyTouchedThisCandle(double levelPrice, datetime candleTime, double eps)
{
   for(int i=0; i<ArraySize(touchedLevels); i++)
   {
      if(MathAbs(touchedLevels[i].price - levelPrice) <= eps &&
         touchedLevels[i].candle == candleTime)
         return true;
   }
   return false;
}

void MarkTouched(double levelPrice, datetime candleTime)
{
   LevelTouch lt;
   lt.price = levelPrice;
   lt.candle = candleTime;
   int sz = ArraySize(touchedLevels);
   ArrayResize(touchedLevels, sz + 1);
   touchedLevels[sz] = lt;
}

void ShowStatusPanel(bool isBuyTrend, int activeLevels, double curPx, datetime lastEntry)
{
   if(!ShowPanel) return;
   string objName = "AutoFiboTouch_Panel";
   string txt;
   txt = "AutoFiboTouch EA v1.40\n";
   txt += "Trend: " + (isBuyTrend ? "BUY" : "SELL") + "\n";
   txt += "Active Levels " + (isBuyTrend ? "Below" : "Above") + " Price: " + IntegerToString(activeLevels) + "\n";
   txt += "Price: " + DoubleToString(curPx, _Digits) + "\n";
   txt += "Last Signal: " + (lastEntry > 0 ? TimeToString(lastEntry, TIME_DATE|TIME_MINUTES) : "-");

   if(ObjectFind(0, objName) == -1)
   {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 15);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   }

   ObjectSetString(0, objName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, isBuyTrend ? clrLime : clrTomato);
}

//+------------------------------------------------------------------+
int OnInit()
{
   // Attach indikator AutoFibo_AM agar visual backtest jelas
   long chart_id = ChartID();
   int subwin = 0;
   int indi_handle = iCustom(_Symbol, _Period, "AutoFibo_AM.ex5",
                             12, 6, 4,
                             clrBlack, STYLE_DOT, true, 1,
                             ((41 << 16) | (98 << 8) | 255),
                             ((255 << 16) | (150 << 8) | 68),
                             PosTolerancePoints);
   if(indi_handle != INVALID_HANDLE)
      ChartIndicatorAdd(chart_id, subwin, indi_handle);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(ObjectFind(0, "StaticFibo") == -1) return;

   datetime thisCandle = CurrentCandleOpen();
   if(lastTradeCandleTime == thisCandle) return;

   double origin = ObjectGetDouble(0, "StaticFibo", OBJPROP_PRICE, 0);
   double target = ObjectGetDouble(0, "StaticFibo", OBJPROP_PRICE, 1);
   int levels = (int)ObjectGetInteger(0, "StaticFibo", OBJPROP_LEVELS);
   if(levels <= 0) return;

   bool isBuyTrend  = (origin > target); // origin>target => arah naik
   bool isSellTrend = (origin < target); // origin<target => arah turun
   double curPx = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double eps = _Point * PosTolerancePoints;

   // hitung level aktif untuk panel
   int activeLevels = 0;
   for(int i=0; i<levels; i++)
   {
      double lvl_ratio  = ObjectGetDouble(0, "StaticFibo", OBJPROP_LEVELVALUE, i);
      double levelPrice = target - (target - origin) * lvl_ratio;
      if(isBuyTrend && levelPrice < curPx - eps) activeLevels++;
      if(isSellTrend && levelPrice > curPx + eps) activeLevels++;
   }

   ShowStatusPanel(isBuyTrend, activeLevels, curPx, lastTradeCandleTime);

   if(ArraySize(touchedLevels) > 100) ArrayResize(touchedLevels, 0);

   // Loop tiap level — logika utama FiboTouch
   for(int i=0; i<levels; i++)
   {
      double lvl_ratio  = ObjectGetDouble(0, "StaticFibo", OBJPROP_LEVELVALUE, i);
      double levelPrice = target - (target - origin) * lvl_ratio;

      if(AlreadyTouchedThisCandle(levelPrice, thisCandle, eps)) continue;

      bool trigger = false;
      // Logika FiboTouch (retracement logic)
      // BUY trend → harga turun menyentuh level bawah
      // SELL trend → harga naik menyentuh level atas
      if(isBuyTrend && curPx <= levelPrice + eps) trigger = true;
      if(isSellTrend && curPx >= levelPrice - eps) trigger = true;

      if(!trigger) continue;

      MarkTouched(levelPrice, thisCandle);

      double lots = ComputeLotByBalance();
      double slPrice = 0.0, tpPrice = 0.0;

      if(isBuyTrend)
      {
         slPrice = curPx - SL_Points * _Point;
         tpPrice = curPx + TP_Points * _Point;
         lots = NormalizeLot(lots);
         if(trade.Buy(lots, NULL, 0.0, slPrice, tpPrice, "FiboTouch Signal"))
         {
            lastTradeCandleTime = thisCandle;
            return;
         }
      }
      else if(isSellTrend)
      {
         slPrice = curPx + SL_Points * _Point;
         tpPrice = curPx - TP_Points * _Point;
         lots = NormalizeLot(lots);
         if(trade.Sell(lots, NULL, 0.0, slPrice, tpPrice, "FiboTouch Signal"))
         {
            lastTradeCandleTime = thisCandle;
            return;
         }
      }
   }
}
