//+------------------------------------------------------------------+
//| AutoFibo_AM.mq5                                                  |
//| Static Fibo based on ZigZag                                      |
//|                                                                  |
//| Original research / concept base reference:                      |
//| Dr. Marek Tomasz Korzeniewski, Ph.D., Eng.                       |
//| Assistant Professor, Bialystok University of Technology (Poland).| 
//| Electrical Engineering specialist in Power Electronics & DSP/FPGA|
//| with ~40 scientific publications.                                |
//|                                                                  |
//| MT5 Static Only Version Modified by: Achyar Munandar (Indonesia) |
//| This version removes Dynamic Fibo, optimizes static swing anchor |
//| and enhances level price mapping accuracy.                       |
//+------------------------------------------------------------------+
#property copyright     "Modified by Achyar Munandar | Original concept: Dr. Marek T. Korzeniewski"
#property link          "https://www.mql5.com/en/users/aymarxp"
#property version       "1.06"
#property description   "AutoFibo (STATIC ONLY) based on ZigZag concept by Dr. Marek T. Korzeniewski"

//+------------------------------------------------------------------+
//|  Indicator drawing parameters                                    |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers   3
#property indicator_plots     1
#property indicator_type1     DRAW_COLOR_ZIGZAG
#property indicator_label1    "AutoFibo"
#property indicator_color1    Red,Blue
#property indicator_style1    STYLE_DASH
#property indicator_width1    1

//+------------------------------------------------------------------+
//|  Inputs                                                          |
//+------------------------------------------------------------------+
input int   ExtDepth                   = 12;
input int   ExtDeviation               = 6;
input int   ExtBackstep                = 4;

input color           StaticFibo_color  = Black;      // warna dasar level Fibo (awal)
input ENUM_LINE_STYLE StaticFibo_style  = STYLE_DOT;  // style garis level
input int             StaticFibo_width  = 1;          // tebal garis level
input bool            StaticFibo_AsRay  = true;       // memanjang ke kanan
input int             StaticFibo_AnchorWidth = 1;     // width anchor origin/target
// Warna kustom ala TradingView (pakai bit-shift RGB)
// NOTE: Saat ini skrip mewarnai level: di atas harga -> BUY (TV_BUY_Color), di bawah harga -> SELL (TV_SELL_Color)
input color TV_SELL_Color  = ((41 << 16) | (98 << 8) | 255);   // biru (sesuai preferensi kamu)
input color TV_BUY_Color   = ((255 << 16) | (150 << 8) | 68);  // oranye-kemerahan (sesuai preferensi kamu)

// Toleransi posisi vs harga saat ini (dalam poin) untuk hindari flip karena noise/spread
input double PosTolerancePoints = 2.0;

//+----------------------------------------------+
double   LowestBuffer[];
double   HighestBuffer[];
double   ColorBuffer[];

int      LASTlowpos,LASThighpos;
double   LASTlow0,LASTlow1,LASThigh0,LASThigh1;
int      StartBars;

//+------------------------------------------------------------------+
//|  CreateFibo: buat objek & styling level (tanpa label harga)      |
//+------------------------------------------------------------------+
void CreateFibo(long chart_id,string name,int nwin,
                datetime time1,double price1,datetime time2,double price2,
                color Color,int style,int width,int ray,string text)
{
   ObjectCreate(chart_id,name,OBJ_FIBO,nwin,time1,price1,time2,price2);
   ObjectSetInteger(chart_id,name,OBJPROP_COLOR,Color);
   ObjectSetInteger(chart_id,name,OBJPROP_STYLE,style);
   ObjectSetInteger(chart_id,name,OBJPROP_WIDTH,width);

   if(ray>0)  ObjectSetInteger(chart_id,name,OBJPROP_RAY_RIGHT,true);
   if(ray<0)  ObjectSetInteger(chart_id,name,OBJPROP_RAY_LEFT,true);
   if(ray==0){ObjectSetInteger(chart_id,name,OBJPROP_RAY_RIGHT,false);
              ObjectSetInteger(chart_id,name,OBJPROP_RAY_LEFT,false);}
   ObjectSetInteger(chart_id,name,OBJPROP_BACK,false);

   // preset level A: rasio (MT5 menerima 0..1)
   ObjectSetInteger(chart_id,name,OBJPROP_LEVELS,7);
   double preset[7]={1.0,0.786,0.618,0.5,0.382,0.236,0.0};
   for(int i=0;i<7;i++)
   {
      ObjectSetDouble (chart_id,name,OBJPROP_LEVELVALUE,i,preset[i]);  // nilai level (rasio)
      //ObjectSetInteger(chart_id,name,OBJPROP_LEVELCOLOR,i,Color); // biar tiap tick tidak mereset warna ke gold lagi.
      ObjectSetInteger(chart_id,name,OBJPROP_LEVELSTYLE,i,style);
      ObjectSetInteger(chart_id,name,OBJPROP_LEVELWIDTH,i,width);
      // Label diisi kemudian (OnCalculate) agar harga otomatis via %$
   }
}

//+------------------------------------------------------------------+
//|  SetFibo: pindah anchor dan refresh style                        |
//+------------------------------------------------------------------+
void SetFibo(long chart_id,string name,int nwin,
             datetime time1,double price1,datetime time2,double price2,
             color Color,int style,int width,int ray,string text)
{
   if(ObjectFind(chart_id,name)==-1)
      CreateFibo(chart_id,name,nwin,time1,price1,time2,price2,Color,style,width,ray,text);
   else
   {
      ObjectMove(chart_id,name,0,time1,price1); // anchor 0 (origin)
      ObjectMove(chart_id,name,1,time2,price2); // anchor 1 (target)

      int levels=(int)ObjectGetInteger(chart_id,name,OBJPROP_LEVELS);
      for(int i=0;i<levels;i++)
      {
         ObjectSetInteger(chart_id,name,OBJPROP_LEVELCOLOR,i,Color);
         ObjectSetInteger(chart_id,name,OBJPROP_LEVELSTYLE,i,style);
         ObjectSetInteger(chart_id,name,OBJPROP_LEVELWIDTH,i,width);
      }
   }
}

//+------------------------------------------------------------------+
//| ZigZag helpers                                                   |
//+------------------------------------------------------------------+
int FindFirstExtremum(int StartPos,int Rates_total,double &UpArray[],double &DnArray[],int &Sign,double &Extremum)
{
   if(StartPos>=Rates_total)StartPos=Rates_total-1;
   for(int bar=StartPos; bar<Rates_total; bar++)
   {
      if(UpArray[bar]!=0.0 && UpArray[bar]!=EMPTY_VALUE){ Sign=+1; Extremum=UpArray[bar]; return(bar); }
      if(DnArray[bar]!=0.0 && DnArray[bar]!=EMPTY_VALUE){ Sign=-1; Extremum=DnArray[bar]; return(bar); }
   }
   return(-1);
}
int FindSecondExtremum(int Direct,int StartPos,int Rates_total,double &UpArray[],double &DnArray[],int &Sign,double &Extremum)
{
   if(StartPos>=Rates_total)StartPos=Rates_total-1;
   if(Direct==-1)
      for(int bar=StartPos; bar<Rates_total; bar++)
         if(UpArray[bar]!=0.0 && UpArray[bar]!=EMPTY_VALUE){ Sign=+1; Extremum=UpArray[bar]; return(bar); }
   if(Direct==+1)
      for(int bar=StartPos; bar<Rates_total; bar++)
         if(DnArray[bar]!=0.0 && DnArray[bar]!=EMPTY_VALUE){ Sign=-1; Extremum=DnArray[bar]; return(bar); }
   return(-1);
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
void OnInit()
{
   StartBars=ExtDepth+ExtBackstep;

   SetIndexBuffer(0,LowestBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,HighestBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorBuffer,INDICATOR_COLOR_INDEX);

   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);

   PlotIndexSetString(0,PLOT_LABEL,"ZigZag Lowest");
   PlotIndexSetString(1,PLOT_LABEL,"ZigZag Highest");

   ArraySetAsSeries(LowestBuffer,true);
   ArraySetAsSeries(HighestBuffer,true);
   ArraySetAsSeries(ColorBuffer,true);

   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,StartBars);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,StartBars);

   PlotIndexSetInteger(0,PLOT_LINE_WIDTH,3);

   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

   ObjectDelete(0,"StaticFibo"); // reset tiap compile

   string shortname;
   StringConcatenate(shortname,"ZigZag (ExtDepth=",ExtDepth," ExtDeviation=",ExtDeviation," ExtBackstep=",ExtBackstep,")");
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0,"StaticFibo");
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total<StartBars) return(0);

   int limit,climit,bar,back,lasthighpos,lastlowpos;
   double curlow,curhigh,lasthigh0=0.0,lastlow0=0.0,lasthigh1,lastlow1,val,res;
   bool Max,Min;

   int bar1,bar2,bar3,sign;
   double price1,price2,price3;

   if(prev_calculated>rates_total || prev_calculated<=0)
   {
      limit=rates_total-StartBars;
      climit=limit;
      lastlow1=-1; lasthigh1=-1; lastlowpos=-1; lasthighpos=-1;
   }
   else
   {
      limit=rates_total-prev_calculated;
      climit=limit+StartBars;
      lastlow0=LASTlow0; lasthigh0=LASThigh0;
      lastlow1=LASTlow1; lasthigh1=LASThigh1;
      lastlowpos=LASTlowpos+limit; lasthighpos=LASThighpos+limit;
   }

   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(time,true);

   // loop 1
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
   {
      if(rates_total!=prev_calculated && bar==0){ LASTlow0=lastlow0; LASThigh0=lasthigh0; }

      // low
      val=low[ArrayMinimum(low,bar,ExtDepth)];
      if(val==lastlow0) val=0.0;
      else
      {
         lastlow0=val;
         if((low[bar]-val)>(ExtDeviation*_Point))val=0.0;
         else
            for(back=1; back<=ExtBackstep; back++)
            {
               res=LowestBuffer[bar+back];
               if((res!=0) && (res>val)) LowestBuffer[bar+back]=0.0;
            }
      }
      LowestBuffer[bar]=val;

      // high
      val=high[ArrayMaximum(high,bar,ExtDepth)];
      if(val==lasthigh0) val=0.0;
      else
      {
         lasthigh0=val;
         if((val-high[bar])>(ExtDeviation*_Point))val=0.0;
         else
            for(back=1; back<=ExtBackstep; back++)
            {
               res=HighestBuffer[bar+back];
               if((res!=0) && (res<val)) HighestBuffer[bar+back]=0.0;
            }
      }
      HighestBuffer[bar]=val;
   }

   // loop 2
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
   {
      if(rates_total!=prev_calculated && bar==0)
      {
         LASTlow1=lastlow1; LASThigh1=lasthigh1;
         LASTlowpos=lastlowpos; LASThighpos=lasthighpos;
      }

      curlow=LowestBuffer[bar];
      curhigh=HighestBuffer[bar];

      if((curlow==0) && (curhigh==0))continue;

      if(curhigh!=0)
      {
         if(lasthigh1>0){ if(lasthigh1<curhigh) HighestBuffer[lasthighpos]=0; else HighestBuffer[bar]=0; }
         if(lasthigh1<curhigh || lasthigh1<0){ lasthigh1=curhigh; lasthighpos=bar; }
         lastlow1=-1;
      }

      if(curlow!=0)
      {
         if(lastlow1>0){ if(lastlow1>curlow) LowestBuffer[lastlowpos]=0; else LowestBuffer[bar]=0; }
         if((curlow<lastlow1) || (lastlow1<0)){ lastlow1=curlow; lastlowpos=bar; }
         lasthigh1=-1;
      }
   }

   // loop 3 coloring
   for(bar=climit; bar>=0 && !IsStopped(); bar--)
   {
      Max=HighestBuffer[bar]; Min=LowestBuffer[bar];
      if(!Max && !Min) ColorBuffer[bar]=ColorBuffer[bar+1];
      if(Max && Min)   { if(ColorBuffer[bar+1]==0) ColorBuffer[bar]=1; else ColorBuffer[bar]=0; }
      if( Max && !Min) ColorBuffer[bar]=1;
      if(!Max &&  Min) ColorBuffer[bar]=0;
   }

   //== FIBO STATIC ==
   bar1=FindFirstExtremum(0,rates_total,HighestBuffer,LowestBuffer,sign,price1);
   bar2=FindSecondExtremum(sign,bar1,rates_total,HighestBuffer,LowestBuffer,sign,price2);
   bar3=FindSecondExtremum(sign,bar2,rates_total,HighestBuffer,LowestBuffer,sign,price3);

   // anchor FIX standard: origin older swing (bar3) -> target newer swing (bar2)
   SetFibo(0,"StaticFibo",0,time[bar3],price3,time[bar2],price2,
           StaticFibo_color,StaticFibo_style,StaticFibo_width,StaticFibo_AsRay,"StaticFibo");

   // --- Safety guards ---
   if(ObjectFind(0,"StaticFibo")==-1) return(rates_total);

   int levels = (int)ObjectGetInteger(0,"StaticFibo",OBJPROP_LEVELS);
   if(levels<=0) return(rates_total);
   if(levels>20) levels=20; // batas aman

   // ref harga & anchor dari objek (match garis)
   const double curPx  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double origin = ObjectGetDouble(0,"StaticFibo",OBJPROP_PRICE,0); // 0.0
   const double target = ObjectGetDouble(0,"StaticFibo",OBJPROP_PRICE,1); // 1.0

   const double eps = _Point * PosTolerancePoints;

   for(int i=0;i<levels;i++)
   {
      const double lvl = ObjectGetDouble(0,"StaticFibo",OBJPROP_LEVELVALUE,i);

      string ratioTxt =
         (MathAbs(lvl-1.0)<1e-9 || MathAbs(lvl-0.5)<1e-9 || MathAbs(lvl-0.0)<1e-9)
         ? DoubleToString(lvl,1) : DoubleToString(lvl,3);

      // inverted agar match harga %$
      const double levelPrice = target - (target - origin) * lvl;

      // gunakan eps untuk stabilitas keputusan
      const bool isBuyStop = (levelPrice > curPx + eps);

      // warna level per rekomendasi (consistent dengan isBuyStop)
      color lvColor = isBuyStop ? TV_BUY_Color : TV_SELL_Color;
      ObjectSetInteger(0,"StaticFibo",OBJPROP_LEVELCOLOR,i, lvColor);

      // label: ratio + harga MT5 (%$) + rekomendasi singkat
      ObjectSetString(0,"StaticFibo",OBJPROP_LEVELTEXT,i, ratioTxt+"  (%$)  "+(isBuyStop ? "BSTOP" : "SSTOP")+"   ");
   }
   
   // === Tebalkan level anchor (1.0 & 0.0) ===
   // reset semua level ke width default
   for(int i=0;i<levels;i++)
      ObjectSetInteger(0,"StaticFibo",OBJPROP_LEVELWIDTH,i, StaticFibo_width);
   
   // cari index utk level 1.0 dan 0.0 lalu tebalkan
   int idxOne=-1, idxZero=-1;
   for(int i=0;i<levels;i++)
   {
      double v = ObjectGetDouble(0,"StaticFibo",OBJPROP_LEVELVALUE,i);
      if(MathAbs(v-1.0)<1e-9) idxOne = i;
      if(MathAbs(v-0.0)<1e-9) idxZero = i;
   }
   if(idxOne!=-1) ObjectSetInteger(0,"StaticFibo",OBJPROP_LEVELWIDTH,idxOne, StaticFibo_AnchorWidth);
   if(idxZero!=-1) ObjectSetInteger(0,"StaticFibo",OBJPROP_LEVELWIDTH,idxZero, StaticFibo_AnchorWidth);

   return(rates_total);
}
//+------------------------------------------------------------------+
