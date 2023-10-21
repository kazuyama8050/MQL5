#include <Object.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\List.mqh>
#include <MyInclude\MyTechnical\MyMovingAverage.mqh>
#include <MyInclude\MyCommon\MyDatetime.mqh>
#include "include/DowTrade.mqh"

#import "MyLibraries/Trade.ex5"
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    double GetTotalSettlementProfit();
#import
#import "MyLibraries/Indicator.ex5"
    int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
#import
#import "MyLibraries/Math.ex5"
    double MathMeanForDouble(const CArrayDouble &array);
    double MathDiffMeanForDouble(const CArrayDouble &array);
    int MathStandardizationDouble(double &ret_array[], const double &array[]);
    double MathStandardDeviation(const double &array[]);
#import

#define DEFAULT_VOLUME 0.01

static TrendStruct DowTrade::trend_struct;

static int DowTrade::too_short_ima_handle;
static int DowTrade::short_ima_handle;
static int DowTrade::middle_ima_handle;
static int DowTrade::long_ima_handle;
static double too_short_ma[];  //超短期移動平均を格納する配列
static double short_ma[];  //短期移動平均を格納する配列
static double middle_ma[];  //中期移動平均を格納する配列
static double long_ma[];  //長期移動平均を格納する配列

MyMovingAverage myMovingAverage;

int PrintBoxTrend(const double &ma_list[], int term) {
    double ma_target_list[];
    ArrayInsert(ma_target_list, ma_list, 0, 0, term);
    double ma_standard_deviation = MathStandardDeviation(ma_target_list);
    Print(ma_standard_deviation);
    return 1;
}

bool DowTrade::IsLongBoxTrend() {
    if (DowTrade::trend_struct.flag != NO_TREND && DowTrade::trend_struct.flag != BOX_TREND) {
        return false;
    }
    
    if (myMovingAverage.IsBoxTrend(short_ma, 10, 0.04) && 
        myMovingAverage.IsBoxTrend(middle_ma, 20, 0.04) && 
        myMovingAverage.IsBoxTrend(long_ma, 20, 0.03) && 
        MathAbs(short_ma[0] - middle_ma[0]) < 0.5 && 
        MathAbs(short_ma[0] - long_ma[0]) < 1 && 
        MathAbs(middle_ma[0] - long_ma[0]) < 1
    ) {
        
        // PrintBoxTrend(short_ma, 10);
        // PrintBoxTrend(middle_ma, 20);
        // PrintBoxTrend(long_ma, 20);
        return true;
    }
    return false;
}

int DowTrade::PredictTrendVectorAfterBoxTrend(CArrayDouble &price_list) {
    int flag = 0;
    int check_term = 3;
    for (int i = check_term - 1;i >= 0;i--) {
        if (too_short_ma[i] <= price_list[i]) {
            flag += 1;
        }
    }
    
    if (flag == check_term) {
        return RISING_TREND;
    } else if (flag == 0) {
        return DOWN_TREND;
    }

    return NO_TREND;
}

int DowTrade::CreateTradeRequestByTrendVector(MqlTradeRequest &request, int trend_vector) {
    double volume_deveation = 1.0;

    //--- リクエストのパラメータ
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.deviation = DEFAULT_TRADE_ACTION_DEAL;
    request.magic = MAGIC_NUMBER;
    request.comment = "長期ボックス相場ブレイク";

    request.volume = DEFAULT_VOLUME;

    if (trend_vector == RISING_TREND) {  // 買い注文
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    } else if (trend_vector == DOWN_TREND) {  // 売り注文
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    } else {
        return 0;
    }
    return 1;
}

int DowTrade::MainLoop() {
    CArrayDouble price_15_list;
    GetClosePriceList(price_15_list, Symbol(), PERIOD_M15, 50);

    if (DowTrade::IsLongBoxTrend() == true) {
        Print("ロングボックス相場");
        DowTrade::trend_struct.flag = BOX_TREND;
        DowTrade::trend_struct.checked_datetime = TimeLocal();
    } else {
        // ロングボックストレンド継続中にこのトレンドが変わった時
        if (DowTrade::trend_struct.flag == BOX_TREND) {
            if (DowTrade::trend_struct.checked_datetime <= TimeLocal() - HALF_HOUR_DATETIME) {
                DowTrade::trend_struct.flag = NO_TREND;
            } else {
                int trend_vector = DowTrade::PredictTrendVectorAfterBoxTrend(price_15_list);
                if (trend_vector == RISING_TREND || trend_vector == DOWN_TREND) {

                    // 注文
                    MqlTradeRequest trade_request={};
                    MqlTradeResult trade_result={};
                    DowTrade::CreateTradeRequestByTrendVector(trade_request, trend_vector);
                    TradeOrder(trade_request, trade_result);
                    DowTrade::trend_struct.flag = NO_TREND;
                }
                
            }
        }
    }

    return 1;
}

void OnInit() {
    Print("Start!!");

    DowTrade::too_short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 5, 0, MODE_SMA, PRICE_CLOSE);
    DowTrade::short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 25, 0, MODE_SMA, PRICE_CLOSE);
    DowTrade::middle_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 75, 0, MODE_SMA, PRICE_CLOSE);
    DowTrade::long_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 200, 0, MODE_SMA, PRICE_CLOSE);
    ArraySetAsSeries(too_short_ma, true);
    ArraySetAsSeries(short_ma, true);
    ArraySetAsSeries(middle_ma, true);
    ArraySetAsSeries(long_ma, true);

    DowTrade::trend_struct.flag = NO_TREND;
    DowTrade::trend_struct.checked_datetime = TimeLocal();
}

void OnTick() {
    CopyBuffer(DowTrade::too_short_ima_handle, 0, 0, 20, too_short_ma);
    CopyBuffer(DowTrade::short_ima_handle, 0, 0, 20, short_ma);
    CopyBuffer(DowTrade::middle_ima_handle, 0, 0, 20, middle_ma);
    CopyBuffer(DowTrade::long_ima_handle, 0, 0, 40, long_ma);
    DowTrade::MainLoop();
    Sleep(600000); // 10分スリープ
}

void OnDeinit() {

}