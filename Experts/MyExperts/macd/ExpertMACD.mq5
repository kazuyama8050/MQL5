#include "include/ExpertMACD.mqh"
#include <MyInclude\MyTechnical\MyMACD.mqh>
#include <MyInclude\MyAccount\MyAccountInfo.mqh>
#include <MyInclude\MyCommon\MyDatetime.mqh>
#import "Common.ex5"
    void ForceStopEa();
#import
#import "Trade.ex5"
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    double GetTotalSettlementProfit();
#import

input group "MACDハンドラ"
input int long_ema_period_for_15minutes_period = 12;
input int short_ema_period_for_15minutes_period = 26;
input int signal_ema_period_for_15minutes_period = 9;

input group "取引リクエスト"
input double default_volume = 0.01;

static MACDHandlerStruct ExpertMACD::macd_handler_struct;
static MACDListStruct ExpertMACD::macd_list_struct_of_15_min;
static MACDLastTradeStruct ExpertMACD::macdLastTrade;

void OnInit() {
    Print("Start!!");
    ExpertMACD::Init();
    
}

static int ExpertMACD::Init() {
    ExpertMACD::macd_handler_struct.macd_handler_15_min = new MyMACD(
        PERIOD_M15,
        long_ema_period_for_15minutes_period,
        short_ema_period_for_15minutes_period,
        signal_ema_period_for_15minutes_period
    );

    // if (macd_handler_15_min == INVALID_HANDLE) {
    //     Print("Invalid MACD Handler per 15 min");
    //     return 0;
    // }
    return 1;
}

void OnTick() {
    if (!ExpertMACD::MainLoop()) {
        ForceStopEa();
        return;
    }
    
}


static int ExpertMACD::MainLoop() {
    if (!ExpertMACD::InitOnMainLoop()) {
        return 0;
    }

    double signal = MyMACD::CheckNormalCrossSignal(ExpertMACD::macd_list_struct_of_15_min);

    if (ExpertMACD::macdLastTrade.last_datetime == NULL || 
        ExpertMACD::macdLastTrade.last_datetime <= TimeLocal() - ONE_HOUR_DATETIME) {
            ExpertMACD::MainTrade(signal);
    }
    
    

    Sleep(10000*6);
    return 1;
}



static int ExpertMACD::InitOnMainLoop() {
    if (ExpertMACD::macd_handler_struct.macd_handler_15_min.SetMACDList(
        ExpertMACD::macd_list_struct_of_15_min,
        DEFAULT_MACD_LIST_BUFFER
    ) != 1) {
        return 0;
    }

    return 1;
}

static bool ExpertMACD::MainTrade(const double signal) {
    MqlTradeRequest trade_request={};
    MqlTradeResult trade_result={};
    if (ExpertMACD::CreateTradeRequest(trade_request, signal)) {
        if (MyAccountInfo::CheckForTrade(trade_request)) {
            if (TradeOrder(trade_request, trade_result)) {
                ExpertMACD::macdLastTrade.last_datetime = TimeLocal();
            }
        }
    }
    return true;
}

static bool ExpertMACD::CreateTradeRequest(MqlTradeRequest &request, double signal) {
    if (signal == 0) {return false;}
    double volume_deveation = 1.0;

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.deviation = DEFAULT_TRADE_ACTION_DEAL;
    request.magic = MAGIC_NUMBER;
    request.comment = "MACDによるシグナル検知";
    request.volume = default_volume * MathAbs(signal);

    if (signal > 0) {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    } else if (signal < 0) {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
    }
    return true;
}

