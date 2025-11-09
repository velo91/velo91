//+------------------------------------------------------------------+
//| AutoFibo_AM.mq5                                                  |
//| Static Fibonacci based on ZigZag                                 |
//|                                                                  |
//| Original research / concept reference:                           |
//| Dr. Marek Tomasz Korzeniewski, Ph.D., Eng.                       |
//| Assistant Professor, Bialystok University of Technology (Poland) |
//| Specialist in Power Electronics & DSP/FPGA, author of ~40 papers |
//|                                                                  |
//| Modified by: Achyar Munandar (Indonesia)                         |
//| This version removes Dynamic Fibo, optimizes static swing anchor |
//| and enhances level price mapping accuracy.                       |
//| Simplified ZigZag rendering: only last 3 swings displayed.       |
//| No flicker, minimal CPU usage, and cleaner visuals.              |
//+------------------------------------------------------------------+
#property copyright     "Modified by Achyar Munandar | Original concept: Dr. Marek T. Korzeniewski"
#property link          "https://www.mql5.com/en/users/aymarxp"
#property version       "1.06"
#property description   "AutoFibo (STATIC ONLY) based on ZigZag concept by Dr. Marek T. Korzeniewski"

//+------------------------------------------------------------------+
//|  Indicator drawing parameters
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers   3
#property indicator_plots     1
#property indicator_type1     DRAW_COLOR_ZIGZAG
#property indicator_label1    "AutoFibo"
#property indicator_color1    ((41 << 16) | (98 << 8) | 255), ((255 << 16) | (150 << 8) | 68)
#property indicator_style1    STYLE_DASH
#property indicator_width1    1

//+------------------------------------------------------------------+
//|  Inputs
//+------------------------------------------------------------------+
input int   ExtDepth                   = 12;
input int   ExtDeviation               = 6;
input int   ExtBackstep                = 4;

input color           StaticFibo_color  = Black;      // warna dasar level Fibo (awal)
input ENUM_LINE_STYLE StaticFibo_style  = STYLE_DOT;  // style garis level
input bool            StaticFibo_AsRay  = true;       // memanjang ke kanan
// Warna kustom ala TradingView (pakai bit-shift RGB)
// NOTE: Saat ini skrip mewarnai level: di atas harga -> BUY (TV_BUY_Color), di bawah harga -> SELL (TV_SELL_Color)
input color           TV_SELL_Color  = ((41 << 16) | (98 << 8) | 255);   // biru (sesuai preferensi kamu)
input color           TV_BUY_Color   = ((255 << 16) | (150 << 8) | 68);  // oranye-kemerahan (sesuai preferensi kamu)
input int             LocalTimeOffset = 7;            // tambahan offset jam waktu lokal
input double          PosTolerancePoints = 20.0;      // toleransi posisi vs harga saat ini (dalam poin) untuk hindari flip karena noise/spread

//--- ZigZag buffers & start offset
double   LowestBuffer[];    // swing low points
double   HighestBuffer[];   // swing high points
double   ColorBuffer[];     // zigzag color index (up/down)
int      StartBars;         // minimal bars before calculation

//+------------------------------------------------------------------+
//|  CreateFibo: buat objek Fibonacci baru & styling level (tanpa label harga)
//+------------------------------------------------------------------+
void CreateFibo(long chart_id,string name,int nwin,datetime time1,double price1,datetime time2,double price2,color Color,int style,int width,int ray,string text)
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
      ObjectSetDouble (chart_id,name,OBJPROP_LEVELVALUE,i,preset[i]); // nilai level (rasio)
      //ObjectSetInteger(chart_id,name,OBJPROP_LEVELCOLOR,i,Color); // komen saja biar tiap tick tidak mereset warna ke awal lagi
      ObjectSetInteger(chart_id,name,OBJPROP_LEVELSTYLE,i,style);
      ObjectSetInteger(chart_id,name,OBJPROP_LEVELWIDTH,i,width);
      // Label nanti akan diisi kemudian di OnCalculate() agar harga otomatis via %$
   }
}

//+------------------------------------------------------------------+
//|  SetFibo: Jika objek StaticFibo sudah ada, cukup pindah anchor dan refresh style
//+------------------------------------------------------------------+
void SetFibo(long chart_id,string name,int nwin,datetime time1,double price1,datetime time2,double price2,color Color,int style,int width,int ray,string text)
{
   if(ObjectFind(chart_id,name)==-1)
      CreateFibo(chart_id,name,nwin,time1,price1,time2,price2,Color,style,width,ray,text); // Jika belum ada -> panggil CreateFibo()
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
//| ZigZag helpers: yang akan menghasilkan bar1, bar2, bar3 nanti
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
//| OnInit: Inisialisasi buffer, label, dan hapus objek lama.
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

   ObjectDelete(0,"StaticFibo"); // reset fibo lama tiap compile agar tidak double di chart

   string shortname;
   StringConcatenate(shortname,"ZigZag (ExtDepth=",ExtDepth," ExtDeviation=",ExtDeviation," ExtBackstep=",ExtBackstep,")");
   IndicatorSetString(INDICATOR_SHORTNAME,shortname);
}

//+------------------------------------------------------------------+
//| OnDeinit: Hapus objek StaticFibo saat indikator dihapus dari chart
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0,"StaticFibo");
}

//+------------------------------------------------------------------+
//| OnCalculate: Bagian utama yang menjalankan ZigZag dan menggambar Fibonacci
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{


   if(rates_total<StartBars) return(0);

   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(time,true);

   //--- gunakan ZigZag internal MT5 (mirip logika bawaan)
   for(int i=0;i<rates_total;i++){ LowestBuffer[i]=0; HighestBuffer[i]=0; }

   for(int i=ExtDepth; i<rates_total-ExtDepth; i++)
   {
      double min=low[ArrayMinimum(low,i,ExtDepth)];
      double max=high[ArrayMaximum(high,i,ExtDepth)];
      if(low[i]==min) LowestBuffer[i]=min;
      if(high[i]==max) HighestBuffer[i]=max;
   }

   //=== ZIGZAG RINGAN (hanya 3 swing terakhir)
   ArrayInitialize(ColorBuffer,0.0);

   int sign;
   double price1,price2,price3;
   int bar1=FindFirstExtremum(0,rates_total,HighestBuffer,LowestBuffer,sign,price1);
   int bar2=FindSecondExtremum(sign,bar1,rates_total,HighestBuffer,LowestBuffer,sign,price2);
   int bar3=FindSecondExtremum(sign,bar2,rates_total,HighestBuffer,LowestBuffer,sign,price3);

   // kosongkan buffer agar tidak menampilkan zigzag panjang
   ArrayInitialize(LowestBuffer,0.0);
   ArrayInitialize(HighestBuffer,0.0);

   if(bar3>=0 && bar2>=0 && bar1>=0)
   {
      // Tentukan arah terakhir (bar2 → bar1)
      int colorUp   = 1;  // index warna ke-2 = biru
      int colorDown = 0;  // index warna ke-1 = merah
      int colorUse  = (price1 > price2) ? colorUp : colorDown;
   
      // Isi warna sesuai arah
      ColorBuffer[bar3] = colorUse;
      ColorBuffer[bar2] = colorUse;
      ColorBuffer[bar1] = colorUse;
   
      // Tentukan swing high/low sesuai arah
      if(sign > 0)
      {
         HighestBuffer[bar3] = price3;
         LowestBuffer[bar2]  = price2;
         HighestBuffer[bar1] = price1;
      }
      else
      {
         LowestBuffer[bar3]  = price3;
         HighestBuffer[bar2] = price2;
         LowestBuffer[bar1]  = price1;
      }
   }

   //== FIBO STATIC ==
   // Setelah ZigZag siap, bar1–3 dicari
   // bar1 = swing ekstrem terbaru (bisa high atau low)    : berfungsi untuk mengetahui swing paling baru (arah tren saat ini)
   // bar2 = swing ekstrem sebelumnya                      : perannya sebagai titik akhir (target) Fibo
   // bar3 = swing terlama (untuk tarik fibo statis)       : perannya sebagai titik awal (origin) Fibo
   bar1=FindFirstExtremum(0,rates_total,HighestBuffer,LowestBuffer,sign,price1); // price1 = harga di bar1 (swing ekstrem terbaru)
   bar2=FindSecondExtremum(sign,bar1,rates_total,HighestBuffer,LowestBuffer,sign,price2); // price2 = harga di bar2 (swing ekstrem sebelumnya)
   bar3=FindSecondExtremum(sign,bar2,rates_total,HighestBuffer,LowestBuffer,sign,price3); // price3 = harga di bar3 (swing terlama)

   // Kemudian Fibo digambar
   // Tarikan garis Fibo dimulai dari bar3 ke bar2
   // Jadi anchor Fibo = dari swing bar3 (origin terlama) ke swing bar2 (target terbaru)
   // Jika bar3 adalah High ---> bar2 adalah Low ---> origin > target ---> tren naik ---> "ONLY BUY"
   // Jika bar3 adalah Low ---> bar2 adalah High ---> origin < target ---> tren turun ---> "ONLY SELL"
   SetFibo(0,"StaticFibo",0,time[bar3],price3,time[bar2],price2,StaticFibo_color,StaticFibo_style,1,StaticFibo_AsRay,"StaticFibo");

   // Safety guards
   // untuk mencegah crash, error, atau perilaku aneh kalau objek Fibo belum ada, rusak, atau level-nya invalid
   // intinya, jangan lanjut memproses level, harga, atau warna kalau garis Fibo (objek bernama "StaticFibo") belum terbentuk
   if(ObjectFind(0,"StaticFibo")==-1) return(rates_total);

   int levels = (int)ObjectGetInteger(0,"StaticFibo",OBJPROP_LEVELS); // mengambil jumlah level Fibonacci yang aktif di objek itu, biasanya ada 7 karena di CreateFibo() tadi presetnya ada 7 level
   if(levels<=0) return(rates_total); // Jika <= 0 --> kemungkinan ada error di Fibo (misal belum lengkap atau gagal dibuat), jadi langsung return
   if(levels>20) levels=20; // Jika lebih dari 20 --> dibatasi jadi 20 agar loop nanti tidak jalan terlalu banyak (batas aman untuk perlindungan performa & memory)

   // ref harga & anchor dari objek (match garis)
   const double curPx  = SymbolInfoDouble(_Symbol, SYMBOL_BID); // ambil ulang koordinat (harga & waktu) dari Fibo yang sudah digambar di chart, agar logika warna dan teks sinkron
   const double origin = ObjectGetDouble(0,"StaticFibo",OBJPROP_PRICE,0); // ambil harga level 0.0 = origin (titik awal, bar3)
   const double target = ObjectGetDouble(0,"StaticFibo",OBJPROP_PRICE,1); // ambil harga level 1.0 = target (titik akhir, bar2)
   datetime tOrigin = (datetime)ObjectGetInteger(0,"StaticFibo",OBJPROP_TIME,0); // ambil waktu kapan swing bar3 terjadi
   datetime tTarget = (datetime)ObjectGetInteger(0,"StaticFibo",OBJPROP_TIME,1); // ambil waktu kapan swing bar2 terjadi
   datetime swingStartTime   = time[bar3]; // waktu swing dimulai (anchor origin)
   datetime swingEndTime     = time[bar2]; // waktu swing selesai (anchor target)
   datetime latestSwingTime  = time[bar1]; // waktu swing terbaru (UTC server)
   double   latestSwingPrice = price1; // ambil harga swing terbaru di bar1
   datetime latestSwingTimeIndo = latestSwingTime + (LocalTimeOffset * 3600); // waktu lokal WIB (ditambah berapa jam offset)
   
   const double eps = _Point * PosTolerancePoints;

   for(int i=0;i<levels;i++)
   {
      const double lvl = ObjectGetDouble(0,"StaticFibo",OBJPROP_LEVELVALUE,i);

      string ratioTxt = (MathAbs(lvl-1.0)<1e-9 || MathAbs(lvl-0.5)<1e-9 || MathAbs(lvl-0.0)<1e-9) ? DoubleToString(lvl,1) : DoubleToString(lvl,3);

      // Pemberian warna dan label pada setiap level Fibonacci
      // pakai perhitungan terbalik agar cocok dengan harga %$
      const double levelPrice = target - (target - origin) * lvl;
      // pakai eps untuk stabilitas keputusan
      const bool isBuyStop = (levelPrice > curPx + eps);
      // warna level per rekomendasi berdasarkan kondisi isBuyStop
      color lvColor = isBuyStop ? TV_BUY_Color : TV_SELL_Color;
      ObjectSetInteger(0,"StaticFibo",OBJPROP_LEVELCOLOR,i, lvColor);
      // label: ratio + harga MT5 (%$) + rekomendasi singkat
      ObjectSetString(0,"StaticFibo",OBJPROP_LEVELTEXT,i, ratioTxt+"  (%$)  "+(isBuyStop ? "BSTOP" : "SSTOP")+"   ");
   }
   
   // Teks di anchor last swing
   string tag = "AnchorLastText";
   double offset = (origin > target) ? (-_Point * 3000) : (+_Point * 3000); // sesuaikan selera
   if(ObjectFind(0,tag)==-1)
   {
      ObjectCreate(0,tag,OBJ_TEXT,0,tTarget,target + offset);
   }
   else
   {
      ObjectMove(0,tag,0,tTarget,target + offset);
   }
   // Menampilkan arah dominan dan waktu swing terakhir
   MqlDateTime tUTC, tWIB;
   TimeToStruct(latestSwingTime, tUTC);
   TimeToStruct(latestSwingTimeIndo, tWIB);
   // Format manual: 08 NOV 10:45
   string textTimeUTC = StringFormat("%02d %s %02d:%02d UTC",tUTC.day,StringSubstr("JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC", (tUTC.mon-1)*3, 3),tUTC.hour, tUTC.min);
   string textTimeWIB = StringFormat("%02d %s %02d:%02d WIB",tWIB.day,StringSubstr("JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC", (tWIB.mon-1)*3, 3),tWIB.hour, tWIB.min);
   if(origin > target)
   {
      // Jika origin > target (tarikan dari atas ke bawah) -> arah naik (BUY)
      string textMsg = "ONLY BUY TO " + textTimeUTC + " / " + textTimeWIB;
      ObjectSetString(0, tag, OBJPROP_TEXT, textMsg);
   }
   else
   {
      // Jika sebaliknya -> arah turun (SELL)
      string textMsg = "ONLY SELL TO " + textTimeUTC + " / " + textTimeWIB;
      ObjectSetString(0, tag, OBJPROP_TEXT, textMsg);
   }
   // Style
   ObjectSetInteger(0,tag,OBJPROP_COLOR,White);
   ObjectSetInteger(0,tag,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,tag,OBJPROP_BACK,true);

   // Menandakan indikator sudah selesai menghitung semua bar
   return(rates_total);
}
//+------------------------------------------------------------------+
