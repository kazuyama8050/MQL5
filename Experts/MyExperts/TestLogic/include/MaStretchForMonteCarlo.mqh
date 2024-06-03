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

long MA_STRETCH_FOR_MONTE_CARLO_MAGIC_NUMBER = 10003;

struct LatestPositionForMaStretchMonteCarloStruct
{
    ulong ticket;
    double price;
    double volume;
    int order_flag;
    datetime trade_datetime;
};

struct PositionHistoryForMaStretchMonteCarloStruct
{
    ulong ticket;
    double profit;
};


class MaStretchForMonteCarlo
{
    public:
        static const int ORDER_FLAG_BUY;
        static const int ORDER_FLAG_SELL;
        static const int NO_ORDER_FLAG;

    protected:
        ENUM_TIMEFRAMES timeframe;
        int ma_period;
        ENUM_MA_METHOD ma_method;
        double ma_deviation_rate;
        double init_volume;
        double close_price_diff;
        long magic_number;
        CMyTrade myTrade;
        CMyMovingAverage myMovingAverage;
        LatestPositionForMaStretchMonteCarloStruct latest_position_struct;
        PositionHistoryForMaStretchMonteCarloStruct position_histories[];

    public:
        MaStretchForMonteCarlo(
            CMyTrade &myTradeInput,
            CMyMovingAverage &myMovingAverageInput,
            ENUM_TIMEFRAMES timeframe_input,
            int ma_period_input,
            ENUM_MA_METHOD ma_method_input,
            double ma_deviation_rate_input,
            double init_volume_input,
            double close_price_diff_input
        );
        ~MaStretchForMonteCarlo();

        void MaStretchForMonteCarlo::InitLatestPositionStruct();
        int MaStretchForMonteCarlo::Execute();
        int MaStretchForMonteCarlo::CheckClose();
        int MaStretchForMonteCarlo::CheckOrder();
        int MaStretchForMonteCarlo::TradeOrder(int order_flag);
        int MaStretchForMonteCarlo::PositionClose();
        int MaStretchForMonteCarlo::OrderRetcode(bool is_open);

    private:
        ENUM_TIMEFRAMES MaStretchForMonteCarlo::GetTimeframe() {return timeframe;}
        int MaStretchForMonteCarlo::GetMaPeriod() {return ma_period;}
        ENUM_MA_METHOD MaStretchForMonteCarlo::GetMaMethod() {return ma_method;}
        double MaStretchForMonteCarlo::GetMaDeviationRate() {return ma_deviation_rate;}
        double MaStretchForMonteCarlo::GetInitVolume() {return init_volume;}
        double MaStretchForMonteCarlo::GetClosePriceDiff() {return close_price_diff;}
        bool MaStretchForMonteCarlo::HasPosition() {
            return latest_position_struct.order_flag != NO_ORDER_FLAG;
        }
        int MaStretchForMonteCarlo::GetPositionOrderFlag() {return latest_position_struct.order_flag;}
        double MaStretchForMonteCarlo::GetPositionPrice() {return latest_position_struct.price;}

        int MaStretchForMonteCarlo::GetPositionHistorySize() {return ArraySize(position_histories);}
        void MaStretchForMonteCarlo::InsertPositionHistory(PositionHistoryForMaStretchMonteCarloStruct &position_history) {
            int size = GetPositionHistorySize();
            ArrayResize(position_histories, size+1);
            position_histories[size] = position_history;
        }
};

// 定数初期化
const int MaStretchForMonteCarlo::ORDER_FLAG_BUY = 1;
const int MaStretchForMonteCarlo::ORDER_FLAG_SELL = -1;
const int MaStretchForMonteCarlo::NO_ORDER_FLAG = 0;



MaStretchForMonteCarlo::MaStretchForMonteCarlo(
    CMyTrade &myTradeInput,
    CMyMovingAverage &myMovingAverageInput,
    ENUM_TIMEFRAMES timeframe_input,
    int ma_period_input,
    ENUM_MA_METHOD ma_method_input,
    double ma_deviation_rate_input,
    double init_volume_input,
    double close_price_diff_input
)
{
    myTrade = myTradeInput;
    myMovingAverage = myMovingAverageInput;
    timeframe = timeframe_input;
    ma_period = ma_period_input;
    ma_method = ma_method_input;
    ma_deviation_rate = ma_deviation_rate_input;
    magic_number = MA_STRETCH_FOR_MONTE_CARLO_MAGIC_NUMBER;
    init_volume = init_volume_input;
    close_price_diff = close_price_diff_input;

    MaStretchForMonteCarlo::InitLatestPositionStruct();
    ArrayFree(position_histories);

    myTrade.SetAsyncMode(false);
    myTrade.SetExpertMagicNumber(magic_number);
    myTrade.SetTypeFilling(ORDER_FILLING_IOC);

    if (!myMovingAverage.Init(Symbol(), timeframe_input, ma_period, 0, ma_method, PRICE_CLOSE)) {
        PrintError("Cannot Init MyMovingAverage Class");
        ForceStopEa();
        return;
    }
}

MaStretchForMonteCarlo::~MaStretchForMonteCarlo()
{

}

void MaStretchForMonteCarlo::InitLatestPositionStruct()
{
    latest_position_struct.ticket = 0;
    latest_position_struct.price = 0.0;
    latest_position_struct.volume = 0.0;
    latest_position_struct.order_flag = NO_ORDER_FLAG;
    latest_position_struct.trade_datetime = TimeLocal();
}

int MaStretchForMonteCarlo::Execute()
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

int MaStretchForMonteCarlo::CheckClose()
{
    double latest_price = GetLatestClosePrice(Symbol(), MaStretchForMonteCarlo::GetTimeframe());
    double position_price = MaStretchForMonteCarlo::GetPositionPrice();
    int position_order_flag = GetPositionOrderFlag();

    if (position_order_flag == NO_ORDER_FLAG) {
        return 0;
    }
    if (MathAbs(position_price - latest_price) >= MaStretchForMonteCarlo::GetClosePriceDiff()) {
        return 1;
    }
    return 0;
}

int MaStretchForMonteCarlo::CheckOrder()
{
    double latest_price = GetLatestClosePrice(Symbol(), MaStretchForMonteCarlo::GetTimeframe());
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


int MaStretchForMonteCarlo::TradeOrder(int order_flag)
{
    double volume = MaStretchForMonteCarlo::GetInitVolume();
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

int MaStretchForMonteCarlo::PositionClose()
{
    ulong ticket = latest_position_struct.ticket;
    string comment = StringFormat("[移動平均線ストレッチ] 決済. チケット: %d", ticket);
    myTrade.PositionClose(ticket, ULONG_MAX, comment);
    int order_retcode = OrderRetcode(false);
    if (order_retcode == 1) {
        // 履歴記録
        double profit = GetSettlementProfit(myTrade.ResultDeal());
        PositionHistoryForMaStretchMonteCarloStruct position_history_struct;
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


int MaStretchForMonteCarlo::OrderRetcode(bool is_open)
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