/**
 *  移動平均線ストレッチロジック
 * 終値がn機関移動平均線を大きく下回ったら買う、上回ったら売る
**/ 

#include <Object.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>
#include <MyInclude\MyTechnical\MyMovingAverage\MyMovingAverage.mqh>

#import "MyLibraries/Trade.ex5"
    double GetSettlementProfit(ulong deal_ticket);
#import
#import "MyLibraries/Indicator.ex5"
    double GetLatestClosePrice(string symbol, ENUM_TIMEFRAMES timeframe);
#import
#import "MyLibraries/Datetime.ex5"
    datetime PlusMinutesForDatetime(datetime target_datetime, uint exchange_minutes);
#import
#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintDebug(const string log_str);
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
#import

long MA_STRETCH_MAGIC_NUMBER = 10002;

int ORDER_FLAG_BUY = 1;
int ORDER_FLAG_SELL = -1;
int NO_ORDER_FLAG = 0;

struct LatestPositionForMaStretchStruct
{
    ulong ticket;
    double price;
    double volume;
    int order_flag;
    datetime trade_datetime;
};

struct PositionHistoryForMaStretchStruct
{
    ulong ticket;
    double profit;
};


class MaStretch
{
    protected:
        ENUM_TIMEFRAMES timeframe;
        int ma_period;
        int ma_period_for_close;
        ENUM_MA_METHOD ma_method;
        double ma_deviation_rate;
        double init_volume;
        long magic_number;
        CMyTrade myTrade;
        CMyMovingAverage myMovingAverage;
        CMyMovingAverage myMovingAverageForClose;
        LatestPositionForMaStretchStruct latest_position_struct;
        PositionHistoryForMaStretchStruct position_histories[];

    public:
        MaStretch(
            CMyTrade &myTradeInput,
            CMyMovingAverage &myMovingAverageInput,
            CMyMovingAverage &myMovingAverageForCloseInput,
            ENUM_TIMEFRAMES timeframe_input,
            int ma_period_input,
            int ma_period_for_close_input,
            ENUM_MA_METHOD ma_method_input,
            double ma_deviation_rate_input,
            double init_volume_input
        );
        ~MaStretch();

        void MaStretch::InitLatestPositionStruct();
        int MaStretch::Execute();
        int MaStretch::CheckClose();
        int MaStretch::CheckOrder();
        int MaStretch::TradeOrder(int order_flag);
        int MaStretch::PositionClose();
        int MaStretch::OrderRetcode(bool is_open);

    private:
        ENUM_TIMEFRAMES MaStretch::GetTimeframe() {return timeframe;}
        int MaStretch::GetMaPeriod() {return ma_period;}
        ENUM_MA_METHOD MaStretch::GetMaMethod() {return ma_method;}
        double MaStretch::GetMaDeviationRate() {return ma_deviation_rate;}
        double MaStretch::GetInitVolume() {return init_volume;}
        bool MaStretch::HasPosition() {
            return latest_position_struct.order_flag != NO_ORDER_FLAG;
        }
        int MaStretch::GetPositionOrderFlag() {return latest_position_struct.order_flag;}

        int MaStretch::GetPositionHistorySize() {return ArraySize(position_histories);}
        void MaStretch::InsertPositionHistory(PositionHistoryForMaStretchStruct &position_history) {
            int size = GetPositionHistorySize();
            ArrayResize(position_histories, size+1);
            position_histories[size] = position_history;
        }
};

MaStretch::MaStretch(
    CMyTrade &myTradeInput,
    CMyMovingAverage &myMovingAverageInput,
    CMyMovingAverage &myMovingAverageForCloseInput,
    ENUM_TIMEFRAMES timeframe_input,
    int ma_period_input,
    int ma_period_for_close_input,
    ENUM_MA_METHOD ma_method_input,
    double ma_deviation_rate_input,
    double init_volume_input
)
{
    myTrade = myTradeInput;
    myMovingAverage = myMovingAverageInput;
    myMovingAverageForClose = myMovingAverageForCloseInput;
    timeframe = timeframe_input;
    ma_period = ma_period_input;
    ma_period_for_close = ma_period_for_close_input;
    ma_method = ma_method_input;
    ma_deviation_rate = ma_deviation_rate_input;
    magic_number = MA_STRETCH_MAGIC_NUMBER;
    init_volume = init_volume_input;

    MaStretch::InitLatestPositionStruct();
    ArrayFree(position_histories);

    myTrade.SetAsyncMode(false);
    myTrade.SetExpertMagicNumber(magic_number);
    myTrade.SetTypeFilling(ORDER_FILLING_IOC);

    if (!myMovingAverage.Init(Symbol(), timeframe_input, ma_period, 0, ma_method, PRICE_CLOSE)) {
        PrintError("Cannot Init MyMovingAverage Class");
        ForceStopEa();
        return;
    }

    if (!myMovingAverageForClose.Init(Symbol(), timeframe_input, ma_period_for_close, 0, ma_method, PRICE_CLOSE)) {
        PrintError("Cannot Init MyMovingAverageForClose Class");
        ForceStopEa();
        return;
    }
}

MaStretch::~MaStretch()
{

}

void MaStretch::InitLatestPositionStruct()
{
    latest_position_struct.ticket = 0;
    latest_position_struct.price = 0.0;
    latest_position_struct.volume = 0.0;
    latest_position_struct.order_flag = NO_ORDER_FLAG;
    latest_position_struct.trade_datetime = TimeLocal();
}

int MaStretch::Execute()
{
    if (HasPosition() == true) {
        if (CheckClose() == 1) {
            if (PositionClose() == 0) {
                return 0;
            }
        }
    } else {
        int order_flag = CheckOrder();
        if (order_flag != NO_ORDER_FLAG) {
            if (TradeOrder(order_flag) == 0) {
                return 0;
            }
        }
    }
    return 1;
}

int MaStretch::CheckClose()
{
    double latest_price = GetLatestClosePrice(Symbol(), MaStretch::GetTimeframe());
    if (!myMovingAverage.SetMaByPosition(0, 0, 1)) {
        PrintWarn("Cannot Set MovingAverage");
        return NO_ORDER_FLAG;
    }
    double latest_ma_data = myMovingAverage.GetImaData(0);
    int position_order_flag = GetPositionOrderFlag();

    // 買い注文の場合は直近価格 >= 移動平均で決済
    // 売り注文の場合は直近価格 <= 移動平均で決済
    if (position_order_flag == NO_ORDER_FLAG) {
        return 0;
    }
    if (position_order_flag == ORDER_FLAG_SELL && latest_price >= latest_ma_data) {
        return 1;
    }
    if (position_order_flag == ORDER_FLAG_BUY && latest_price <= latest_ma_data) {
        return 1;
    }
    return 0;
}

int MaStretch::CheckOrder()
{
    double latest_price = GetLatestClosePrice(Symbol(), MaStretch::GetTimeframe());
    if (!myMovingAverage.SetMaByPosition(0, 0, 1)) {
        PrintWarn("Cannot Set MovingAverage");
        return NO_ORDER_FLAG;
    }
    double latest_ma_data = myMovingAverage.GetImaData(0);
    double ma_diff_rate = (latest_price - latest_ma_data) / latest_ma_data * 100;
    PrintNotice(StringFormat("latest_price: %f, latest_ma_data: %f, ma_diff_rate: %f", latest_price, latest_ma_data, ma_diff_rate));
    if (ma_diff_rate >= ma_deviation_rate) {
        return ORDER_FLAG_BUY;
    }
    if (ma_diff_rate <= (ma_deviation_rate * -1 )) {
        return ORDER_FLAG_SELL;
    }
    return NO_ORDER_FLAG;
}


int MaStretch::TradeOrder(int order_flag)
{
    double volume = MaStretch::GetInitVolume();
    string trade_comment = "売り";
    if (order_flag == ORDER_FLAG_BUY) {
        trade_comment = "買い";
    }
    ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
    double price = 0.0;
    if (order_flag == ORDER_FLAG_BUY) {  // 買い注文
        order_type = ORDER_TYPE_BUY;
        price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    } else if (order_flag == ORDER_FLAG_SELL) {  // 売り注文
        order_type = ORDER_TYPE_SELL;
        price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    }
    const string comment = StringFormat("[%s]%s : %.2f * %.5f", "移動平均線ストレッチ", trade_comment, volume, price);

    myTrade.PositionOpen(Symbol(), order_type, volume, price, 0, 0, comment);
    int order_retcode = OrderRetcode(true);
    if (order_retcode == 1) {
        latest_position_struct.ticket = myTrade.ResultOrder();
        latest_position_struct.price = myTrade.ResultPrice();
        latest_position_struct.volume = myTrade.ResultVolume();
        latest_position_struct.order_flag = order_flag;
        latest_position_struct.trade_datetime = TimeLocal();
        return 1;
    }
    if (order_retcode == 2) {
        return 1;
    }
    return 0;
}

int MaStretch::PositionClose()
{
    ulong ticket = latest_position_struct.ticket;
    string comment = StringFormat("[移動平均線ストレッチ] 決済. チケット: %d", ticket);
    myTrade.PositionClose(ticket, ULONG_MAX, comment);
    int order_retcode = OrderRetcode(false);
    if (order_retcode == 1) {
        // 履歴記録
        double profit = GetSettlementProfit(myTrade.ResultDeal());
        PositionHistoryForMaStretchStruct position_history_struct;
        position_history_struct.ticket = ticket;
        position_history_struct.profit = profit;
        InsertPositionHistory(position_history_struct);

        // ポジション構造体初期化
        InitLatestPositionStruct();
        return 1;
    }
    if (order_retcode == 2) {
        return 1;
    }
    return 0;
}


int MaStretch::OrderRetcode(bool is_open)
{
    uint retcode = myTrade.ResultRetcode();
    if (retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL) {
        string is_open_str = (is_open) ? "Open" : "Close";
        PrintNotice(StringFormat("ポジション %s comment: request=%s, result=%s", is_open_str, myTrade.RequestComment(), myTrade.ResultComment()));
        return 1;
    }
    if (retcode == TRADE_RETCODE_MARKET_CLOSED) {
        Sleep(3600*60);  // 1時間スリープ
        return 2;
    }

    return 0;
}