//+---------------------------------+
//| AutoVirtualSLTP.mq5             |
//| Copyright 2025, Achyar Munandar |
//+---------------------------------+
#property copyright "Copyright 2025"
#property version "1.6"
#property strict

#include <Trade\Trade.mqh> CTrade trade;

enum ENUM_CHARTSYMBOL {
    CurrentChartSymbol = 0,                                          // Current Chart Only
    AllOpenOrder = 1                                                 // All Opened Orders/Pending Orders
};

enum ENUM_SLTP_MODE {
    Server = 0,                                                      // Place SL n TP
    Client = 1                                                       // Hidden SL n TP
};

enum ENUM_ORDER_TYPE_MODE {
    ManagePositions = 0,                                             // Only manage open positions
    ManagePendingOrders = 1,                                         // Only manage pending orders
    ManageBoth = 2                                                   // Manage positions and pending orders
};

input int TakeProfit = 1000;                                         // Take Profit
input int StopLoss = 30000;                                          // Stop Loss
input ENUM_SLTP_MODE SLnTPMode = Client;                             // SL & TP Mode
input int Slippage = 500;                                            // Slippage
input ENUM_CHARTSYMBOL ChartSymbolSelection = AllOpenOrder;          //
input ENUM_ORDER_TYPE_MODE OrderTypeToManage = ManageBoth;           // Manage:
input bool inpEnableAlert = false;                                   // Enable Alert

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class Autoclose {
private:
    //--
    bool CheckMoneyForTrade(string sym, double lots, ENUM_ORDER_TYPE type);
    bool CheckVolumeValue(string sym, double volume);
    //--

public:
    //--
    ENUM_SLTP_MODE autoMode;
    ENUM_CHARTSYMBOL chartMode;
    ENUM_ORDER_TYPE_MODE orderTypeMode;
    int slip;
    int TPa;
    int SLa;
    bool SetInstantSLTPPositions();
    bool SetInstantSLTPPendingOrders();
    int CalculateInstantOrders();
    //--
};

Autoclose auto;
//+------------------------------------------------------------------+
//| Fungsi untuk mengatur SL/TP pada POSISI YANG SUDAH TERBUKA       |
//+------------------------------------------------------------------+
bool Autoclose::SetInstantSLTPPositions() {
    double SL = 0, TP = 0;
    double ask = 0, bid = 0, point = 0;
    int digits = 0, minstoplevel = 0;

    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetTicket(i)) {
            if (chartMode == CurrentChartSymbol && PositionGetString(POSITION_SYMBOL) != Symbol()) continue;

            ask = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_ASK);
            bid = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_BID);
            point = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_POINT);
            digits = (int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL), SYMBOL_DIGITS);
            minstoplevel = (int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL), SYMBOL_TRADE_STOPS_LEVEL);

            double minStopLevel = minstoplevel * point;

            double ClosePrice = 0;
            int Poin = 0;
            color CloseColor = clrNONE;

            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                CloseColor = clrBlue;
                ClosePrice = bid;
                Poin = (int)((ClosePrice - PositionGetDouble(POSITION_PRICE_OPEN)) / point);
            } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                CloseColor = clrRed;
                ClosePrice = ask;
                Poin = (int)((PositionGetDouble(POSITION_PRICE_OPEN) - ClosePrice) / point);
            }

            // Set Server SL and TP
            if (autoMode == Server) {
                if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                    SL = (SLa > 0) ? NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - (SLa * point), digits) : 0;
                    TP = (TPa > 0) ? NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + (TPa * point), digits) : 0;

                    if ((SLa > 0 && MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - SL) >= minStopLevel) ||
                        (TPa > 0 && MathAbs(TP - PositionGetDouble(POSITION_PRICE_OPEN)) >= minStopLevel)) {
                        trade.PositionModify(PositionGetInteger(POSITION_TICKET), SL, TP);
                    }
                } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                    SL = (SLa > 0) ? NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + (SLa * point), digits) : 0;
                    TP = (TPa > 0) ? NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - (TPa * point), digits) : 0;

                    if ((SLa > 0 && MathAbs(SL - PositionGetDouble(POSITION_PRICE_OPEN)) >= minStopLevel) ||
                        (TPa > 0 && MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - TP) >= minStopLevel)) {
                        trade.PositionModify(PositionGetInteger(POSITION_TICKET), SL, TP);
                    }
                }
            } else if (autoMode == Client) {
                if ((TPa > 0 && Poin >= TPa) || (SLa > 0 && Poin <= (-SLa))) {
                    if (trade.PositionClose(PositionGetInteger(POSITION_TICKET), slip)) {
                        if (inpEnableAlert) {
                            if (PositionGetDouble(POSITION_PROFIT) > 0) Alert("Closed by Virtual TP #", PositionGetInteger(POSITION_TICKET), " Profit=", PositionGetDouble(POSITION_PROFIT), " Points=", Poin);
                            if (PositionGetDouble(POSITION_PROFIT) < 0) Alert("Closed by Virtual SL #", PositionGetInteger(POSITION_TICKET), " Loss=", PositionGetDouble(POSITION_PROFIT), " Points=", Poin);
                        }
                    }
                }
            }
        }
    }
    return (false);
}

//+------------------------------------------------------------------+
//| Fungsi untuk mengatur SL/TP pada PENDING ORDER                   |
//+------------------------------------------------------------------+
bool Autoclose::SetInstantSLTPPendingOrders() {
    double SL = 0, TP = 0;
    double point = 0;
    int digits = 0, minstoplevel = 0;
    ENUM_ORDER_TYPE order_type;
    double order_price;

    // Variabel untuk menyimpan parameter order yang sudah ada
    ENUM_ORDER_TYPE_TIME current_type_time;
    datetime           current_expiration;
    double             current_stoplimit_price; // Hanya relevan untuk StopLimit, akan 0 untuk lainnya

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong order_ticket = OrderGetTicket(i);
        if (order_ticket == 0) continue; 

        if (OrderSelect(order_ticket)) { 
            if (chartMode == CurrentChartSymbol && OrderGetString(ORDER_SYMBOL) != Symbol()) continue;

            order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            order_price = OrderGetDouble(ORDER_PRICE_OPEN);

            // Lewati order yang bukan pending order
            if (order_type != ORDER_TYPE_BUY_LIMIT &&
                order_type != ORDER_TYPE_BUY_STOP &&
                order_type != ORDER_TYPE_SELL_LIMIT &&
                order_type != ORDER_TYPE_SELL_STOP &&
                order_type != ORDER_TYPE_BUY_STOP_LIMIT && // Tambahkan jika Anda juga mengelola StopLimit
                order_type != ORDER_TYPE_SELL_STOP_LIMIT) { // Tambahkan jika Anda juga mengelola StopLimit
                continue;
            }

            // Dapatkan parameter order yang sudah ada
            current_type_time = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
            current_expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
            current_stoplimit_price = OrderGetDouble(ORDER_PRICE_STOPLIMIT); // Akan 0.0 jika bukan StopLimit

            point = SymbolInfoDouble(OrderGetString(ORDER_SYMBOL), SYMBOL_POINT);
            digits = (int)SymbolInfoInteger(OrderGetString(ORDER_SYMBOL), SYMBOL_DIGITS);
            minstoplevel = (int)SymbolInfoInteger(OrderGetString(ORDER_SYMBOL), SYMBOL_TRADE_STOPS_LEVEL);

            double minStopLevel = minstoplevel * point;

            if (autoMode == Server) {
                if (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_STOP_LIMIT) {
                    SL = (SLa > 0) ? NormalizeDouble(order_price - (SLa * point), digits) : 0;
                    TP = (TPa > 0) ? NormalizeDouble(order_price + (TPa * point), digits) : 0;

                    if ((SLa > 0 && MathAbs(order_price - SL) >= minStopLevel) ||
                        (TPa > 0 && MathAbs(TP - order_price) >= minStopLevel)) {
                        
                        if (OrderGetDouble(ORDER_SL) != SL || OrderGetDouble(ORDER_TP) != TP) {
                           // Panggil OrderModify dengan semua parameter
                           trade.OrderModify(order_ticket, order_price, SL, TP, current_type_time, current_expiration, current_stoplimit_price);
                        }
                    }
                } else if (order_type == ORDER_TYPE_SELL_LIMIT || order_type == ORDER_TYPE_SELL_STOP || order_type == ORDER_TYPE_SELL_STOP_LIMIT) {
                    SL = (SLa > 0) ? NormalizeDouble(order_price + (SLa * point), digits) : 0;
                    TP = (TPa > 0) ? NormalizeDouble(order_price - (TPa * point), digits) : 0;

                    if ((SLa > 0 && MathAbs(SL - order_price) >= minStopLevel) ||
                        (TPa > 0 && MathAbs(order_price - TP) >= minStopLevel)) {

                        if (OrderGetDouble(ORDER_SL) != SL || OrderGetDouble(ORDER_TP) != TP) {
                            // Panggil OrderModify dengan semua parameter
                            trade.OrderModify(order_ticket, order_price, SL, TP, current_type_time, current_expiration, current_stoplimit_price);
                        }
                    }
                }
            }
        }
    }
    return (false);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Autoclose::CalculateInstantOrders() {
    int buys = 0, sells = 0;
    // Ini hanya menghitung POSISI, bukan pending order
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetTicket(i))
            if (chartMode == CurrentChartSymbol && PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
        {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) buys++;
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) sells++;
        }
    }
    // Jika Anda ingin ini mencakup pending order, logikanya perlu lebih kompleks
    // Untuk saat ini, biarkan seperti ini karena OnTick akan memanggil kedua fungsi secara terpisah
    if (buys > 0)
        return (buys);
    else
        return (-sells);
}

//+------------------------------------------------------------------+
bool Autoclose::CheckMoneyForTrade(string sym, double lots, ENUM_ORDER_TYPE type) {
    //--- Getting the opening price
    MqlTick mqltick;
    SymbolInfoTick(sym, mqltick);
    double price = mqltick.ask;
    if (type == ORDER_TYPE_SELL) price = mqltick.bid;
    //--- values of the required and free margin
    double margin, free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    //--- call of the checking function
    if (!OrderCalcMargin(type, sym, lots, price, margin)) {
        //--- something went wrong, report and return false
        return (false);
    }
    //--- if there are insufficient funds to perform the operation
    if (margin > free_margin) {
        //--- report the error and return false
        return (false);
    }
    //--- checking successful
    return (true);
}

//+------------------------------------------------------------------+
bool Autoclose::CheckVolumeValue(string sym, double volume) {
    double min_volume = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
    if (volume < min_volume) return (false);

    double max_volume = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
    if (volume > max_volume) return (false);

    double volume_step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

    int ratio = (int)MathRound(volume / volume_step);
    if (MathAbs(ratio * volume_step - volume) > 0.0000001) return (false);

    return (true);
}

//+------------------------------------------------------------------+
int OnInit() {
    auto.TPa = TakeProfit;
    auto.SLa = StopLoss;
    auto.slip = Slippage;
    auto.chartMode = ChartSymbolSelection;
    auto.autoMode = SLnTPMode;
    auto.orderTypeMode = OrderTypeToManage;

    trade.SetDeviationInPoints(auto.slip);

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
    // --- Memanggil fungsi berdasarkan pilihan pengguna ---
    if (auto.orderTypeMode == ManagePositions || auto.orderTypeMode == ManageBoth) {
        if (PositionsTotal() > 0) { // Hanya panggil jika ada posisi terbuka
            auto.SetInstantSLTPPositions();
        }
    }

    if (auto.orderTypeMode == ManagePendingOrders || auto.orderTypeMode == ManageBoth) {
        if (OrdersTotal() > 0) { // Hanya panggil jika ada pending order
            auto.SetInstantSLTPPendingOrders();
        }
    }

    return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    return;
}
//+------------------------------------------------------------------+