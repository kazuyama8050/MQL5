/**
 *  RSIロジック
 * RSIが基準値以上で売り、基準値以下で買い
 * 特定pips分動いたら決済
**/ 

#include <Object.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>
#include <MyInclude\MyTechnical\MyRsi\MyRsi.mqh>

#import "MyLibraries/Trade.ex5"
    double GetSettlementProfit(ulong deal_ticket);
#import
#import "MyLibraries/Indicator.ex5"
    double GetLatestClosePrice(string symbol, ENUM_TIMEFRAMES timeframe);
#import
#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintDebug(const string log_str);
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
#import

long RSI_FOR_MONTE_CARLO_MAGIC_NUMBER = 10004;

struct LatestPositionForRsiMonteCarloStruct
{
    ulong ticket;
    double price;
    double volume;
    int order_flag;
    datetime trade_datetime;
};

struct PositionHistoryForRsiMonteCarloStruct
{
    ulong ticket;
    double profit;
};

class RsiForMonteCarlo
{
    public:
        static const int ORDER_FLAG_BUY;
        static const int ORDER_FLAG_SELL;
        static const int NO_ORDER_FLAG;

    protected:
        ENUM_TIMEFRAMES timeframe;
        int ma_period;
        double rsi_under_base;
        double rsi_top_base;
        double init_volume;
        double close_price_diff;
        long magic_number;
        CMyTrade myTrade;
        CMyRsi myRsi;

        LatestPositionForRsiMonteCarloStruct latest_position_struct;
        PositionHistoryForRsiMonteCarloStruct position_histories[];

    public:
        RsiForMonteCarlo(
            CMyTrade &myTradeInput,
            CMyRsi &myRsi,
            ENUM_TIMEFRAMES timeframe_input,
            int ma_period_input,
            double rsi_top_base_input,
            double rsi_under_base_input,
            double init_volume_input,
            double close_price_diff_input
        );
        ~RsiForMonteCarlo();

        void RsiForMonteCarlo::InitLatestPositionStruct();
        int RsiForMonteCarlo::Execute();
        int RsiForMonteCarlo::CheckClose();
        int RsiForMonteCarlo::CheckOrder();
        int RsiForMonteCarlo::TradeOrder(int order_flag);
        int RsiForMonteCarlo::PositionClose();
        int RsiForMonteCarlo::OrderRetcode(bool is_open);

    private:
        ENUM_TIMEFRAMES RsiForMonteCarlo::GetTimeframe() {return timeframe;}
        int RsiForMonteCarlo::GetMaPeriod() {return ma_period;}
        double RsiForMonteCarlo::GetRsiTopBase() {return rsi_top_base;}
        double RsiForMonteCarlo::GetRsiUnderBase() {return rsi_under_base;}
        double RsiForMonteCarlo::GetInitVolume() {return init_volume;}
        double RsiForMonteCarlo::GetClosePriceDiff() {return close_price_diff;}
        bool RsiForMonteCarlo::HasPosition() {
            return latest_position_struct.order_flag != NO_ORDER_FLAG;
        }
        int RsiForMonteCarlo::GetPositionOrderFlag() {return latest_position_struct.order_flag;}
        double RsiForMonteCarlo::GetPositionPrice() {return latest_position_struct.price;}

        int RsiForMonteCarlo::GetPositionHistorySize() {return ArraySize(position_histories);}
        void RsiForMonteCarlo::InsertPositionHistory(PositionHistoryForRsiMonteCarloStruct &position_history) {
            int size = GetPositionHistorySize();
            ArrayResize(position_histories, size+1);
            position_histories[size] = position_history;
        }
};

// 定数初期化
const int RsiForMonteCarlo::ORDER_FLAG_BUY = 1;
const int RsiForMonteCarlo::ORDER_FLAG_SELL = -1;
const int RsiForMonteCarlo::NO_ORDER_FLAG = 0;

RsiForMonteCarlo::RsiForMonteCarlo(
    CMyTrade &myTradeInput,
    CMyRsi &myRsiInput,
    ENUM_TIMEFRAMES timeframe_input,
    int ma_period_input,
    double rsi_top_base_input,
    double rsi_under_base_input,
    double init_volume_input,
    double close_price_diff_input
)
{
    myTrade = myTradeInput;
    myRsi = myRsiInput;
    timeframe = timeframe_input;
    ma_period = ma_period_input;
    rsi_top_base = rsi_top_base_input;
    rsi_under_base = rsi_under_base_input;
    magic_number = RSI_FOR_MONTE_CARLO_MAGIC_NUMBER;
    init_volume = init_volume_input;
    close_price_diff = close_price_diff_input;

    RsiForMonteCarlo::InitLatestPositionStruct();
    ArrayFree(position_histories);

    myTrade.SetAsyncMode(false);
    myTrade.SetExpertMagicNumber(magic_number);
    myTrade.SetTypeFilling(ORDER_FILLING_IOC);

    if (!myRsi.Init(Symbol(), timeframe_input, ma_period, PRICE_CLOSE)) {
        PrintError("Cannot Init MyRsi Class");
        ForceStopEa();
        return;
    }
}

RsiForMonteCarlo::~RsiForMonteCarlo()
{
}

void RsiForMonteCarlo::InitLatestPositionStruct()
{
    latest_position_struct.ticket = 0;
    latest_position_struct.price = 0.0;
    latest_position_struct.volume = 0.0;
    latest_position_struct.order_flag = NO_ORDER_FLAG;
    latest_position_struct.trade_datetime = TimeLocal();
}

int RsiForMonteCarlo::Execute()
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


int RsiForMonteCarlo::CheckClose()
{
    double latest_price = GetLatestClosePrice(Symbol(), RsiForMonteCarlo::GetTimeframe());
    double position_price = RsiForMonteCarlo::GetPositionPrice();
    int position_order_flag = GetPositionOrderFlag();

    if (position_order_flag == NO_ORDER_FLAG) {
        return 0;
    }
    if (MathAbs(position_price - latest_price) >= RsiForMonteCarlo::GetClosePriceDiff()) {
        return 1;
    }
    return 0;
}

int RsiForMonteCarlo::CheckOrder()
{
    if (!myRsi.SetRsiByPosition(0, 0, 1)) {
        PrintWarn("Cannot Set Rsi");
        return NO_ORDER_FLAG;
    }
    double rsi_data = myRsi.GetRsiData(0);
    if (rsi_data <= RsiForMonteCarlo::GetRsiUnderBase()) {
        return ORDER_FLAG_SELL;
    }
    if (rsi_data >= RsiForMonteCarlo::GetRsiTopBase()) {
        return ORDER_FLAG_BUY;
    }
    return NO_ORDER_FLAG;
}


int RsiForMonteCarlo::TradeOrder(int order_flag)
{
    double volume = RsiForMonteCarlo::GetInitVolume();
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
    const string comment = StringFormat("[%s]%s : %.2f * %.5f", "RSI", trade_comment, volume, price);

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

int RsiForMonteCarlo::PositionClose()
{
    ulong ticket = latest_position_struct.ticket;
    string comment = StringFormat("[RSI] 決済. チケット: %d", ticket);
    myTrade.PositionClose(ticket, ULONG_MAX, comment);
    int order_retcode = OrderRetcode(false);
    if (order_retcode == 1) {
        // 履歴記録
        double profit = GetSettlementProfit(myTrade.ResultDeal());
        PositionHistoryForRsiMonteCarloStruct position_history_struct;
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


int RsiForMonteCarlo::OrderRetcode(bool is_open)
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