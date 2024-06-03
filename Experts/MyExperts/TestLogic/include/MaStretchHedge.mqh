/**
 *  ヘッジあり移動平均線ストレッチロジック（ヘッジあり）
 * 終値がn機関移動平均線を大きく下回ったら買う、上回ったら売る
 * + 同時に反対ポジションを少量持っておきヘッジする
 * 
 * ※ ヘッジあり移動平均線ストレッチは時間足を長くすると勝ち数は少ないが低損失・高利益が実現できる
 *   ヘッジすると、低損失と低利益の差分 < 高利益と低利益の差分となるので期待利益が高くなるはず
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

long MA_STRETCH_HEDGE_MAGIC_NUMBER = 10005;

string MA_STRETCH_HEDGE_JP = "ヘッジあり移動平均線ストレッチ";

struct PositionForMaStretchHedgeStruct
{
    ulong ticket;
    double price;
    double volume;
    int order_flag;
    bool is_hedge;
    datetime trade_datetime;
};

struct PositionHistoryForMaStretchHedgeStruct
{
    ulong ticket;
    double profit;
};


class MaStretchHedge
{
    private:
        static const int ORDER_FLAG_BUY;
        static const int ORDER_FLAG_SELL;
        static const int NO_ORDER_FLAG;

    protected:
        ENUM_TIMEFRAMES timeframe;
        int ma_period;
        int ma_period_for_close;
        ENUM_MA_METHOD ma_method;
        double ma_deviation_rate;
        double init_volume;
        double init_hedge_volume;
        long magic_number;
        CMyTrade myTrade;
        CMyMovingAverage myMovingAverage;
        CMyMovingAverage myMovingAverageForClose;
        PositionForMaStretchHedgeStruct position_structs[];
        PositionHistoryForMaStretchHedgeStruct position_histories[];

    public:
        MaStretchHedge(
            CMyTrade &myTradeInput,
            CMyMovingAverage &myMovingAverageInput,
            CMyMovingAverage &myMovingAverageForCloseInput,
            ENUM_TIMEFRAMES timeframe_input,
            int ma_period_input,
            int ma_period_for_close_input,
            ENUM_MA_METHOD ma_method_input,
            double ma_deviation_rate_input,
            double init_volume_input,
            double init_hedge_volume_input
        );
        ~MaStretchHedge();

        void MaStretchHedge::InitLatestPositionStruct();
        int MaStretchHedge::Execute();
        int MaStretchHedge::CheckClose();
        int MaStretchHedge::CheckOrder();
        int MaStretchHedge::TradeOrder(int order_flag, double volume, string logic_comment, bool is_hedge);
        int MaStretchHedge::PositionClose();
        int MaStretchHedge::OrderRetcode(bool is_open);

    private:
        ENUM_TIMEFRAMES MaStretchHedge::GetTimeframe() {return timeframe;}
        int MaStretchHedge::GetMaPeriod() {return ma_period;}
        ENUM_MA_METHOD MaStretchHedge::GetMaMethod() {return ma_method;}
        double MaStretchHedge::GetMaDeviationRate() {return ma_deviation_rate;}
        double MaStretchHedge::GetInitVolume() {return init_volume;}
        double MaStretchHedge::GetInitHedgeVolume() {return init_hedge_volume;}
        bool MaStretchHedge::HasPosition() {return MaStretchHedge::GetPositionStructSize() > 0;}

        int MaStretchHedge::GetPositionHistorySize() {return ArraySize(position_histories);}
        int MaStretchHedge::GetPositionStructSize() {return ArraySize(position_structs);}
        void MaStretchHedge::InsertPositionHistory(PositionHistoryForMaStretchHedgeStruct &position_history) {
            int size = GetPositionHistorySize();
            ArrayResize(position_histories, size+1);
            position_histories[size] = position_history;
        }
        void MaStretchHedge::InsertPositionStruct(PositionForMaStretchHedgeStruct &position_struct) {
            int size = GetPositionStructSize();
            ArrayResize(position_structs, size+1);
            position_structs[size] = position_struct;
        }
        int MaStretchHedge::ReverseOrderFlag(int order_flag) {
            if (order_flag == ORDER_FLAG_BUY) {
                return ORDER_FLAG_SELL;
            } else if (order_flag == ORDER_FLAG_SELL) {
                return ORDER_FLAG_BUY;
            }
            return NO_ORDER_FLAG;
        }
};

// 定数初期化
const int MaStretchHedge::ORDER_FLAG_BUY = 1;
const int MaStretchHedge::ORDER_FLAG_SELL = -1;
const int MaStretchHedge::NO_ORDER_FLAG = 0;

MaStretchHedge::MaStretchHedge(
    CMyTrade &myTradeInput,
    CMyMovingAverage &myMovingAverageInput,
    CMyMovingAverage &myMovingAverageForCloseInput,
    ENUM_TIMEFRAMES timeframe_input,
    int ma_period_input,
    int ma_period_for_close_input,
    ENUM_MA_METHOD ma_method_input,
    double ma_deviation_rate_input,
    double init_volume_input,
    double init_hedge_volume_input
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
    magic_number = MA_STRETCH_HEDGE_MAGIC_NUMBER;
    init_volume = init_volume_input;
    init_hedge_volume = init_hedge_volume_input;

    MaStretchHedge::InitLatestPositionStruct();
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

MaStretchHedge::~MaStretchHedge()
{

}

void MaStretchHedge::InitLatestPositionStruct()
{
    ArrayFree(position_histories);
    ArrayResize(position_structs, 0);
}

int MaStretchHedge::Execute()
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
            if (TradeOrder(order_flag, MaStretchHedge::GetInitVolume(), MA_STRETCH_HEDGE_JP, false) == 0) {
                return 0;
            }
            if (TradeOrder(MaStretchHedge::ReverseOrderFlag(order_flag), MaStretchHedge::GetInitHedgeVolume(), MA_STRETCH_HEDGE_JP+"（ヘッジ）", true) == 0) {
                return 0;
            }
        }
    }
    return 1;
}

int MaStretchHedge::CheckClose()
{
    double latest_price = GetLatestClosePrice(Symbol(), MaStretchHedge::GetTimeframe());
    if (!myMovingAverage.SetMaByPosition(0, 0, 1)) {
        PrintWarn("Cannot Set MovingAverage");
        return NO_ORDER_FLAG;
    }
    double latest_ma_data = myMovingAverage.GetImaData(0);
    int position_order_flag = position_structs[0].order_flag;

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

int MaStretchHedge::CheckOrder()
{
    double latest_price = GetLatestClosePrice(Symbol(), MaStretchHedge::GetTimeframe());
    if (!myMovingAverage.SetMaByPosition(0, 0, 1)) {
        PrintWarn("Cannot Set MovingAverage");
        return NO_ORDER_FLAG;
    }
    double latest_ma_data = myMovingAverage.GetImaData(0);
    double ma_diff_rate = (latest_price - latest_ma_data) / latest_ma_data * 100;
    if (ma_diff_rate >= ma_deviation_rate) {
        return ORDER_FLAG_BUY;
    }
    if (ma_diff_rate <= (ma_deviation_rate * -1 )) {
        return ORDER_FLAG_SELL;
    }
    return NO_ORDER_FLAG;
}


int MaStretchHedge::TradeOrder(int order_flag, double volume, string logic_comment, bool is_hedge)
{
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
    const string comment = StringFormat("[%s]%s : %.2f * %.5f", logic_comment, trade_comment, volume, price);

    myTrade.PositionOpen(Symbol(), order_type, volume, price, 0, 0, comment);
    int order_retcode = OrderRetcode(true);
    if (order_retcode == 1) {
        PositionForMaStretchHedgeStruct position_struct;
        position_struct.ticket = myTrade.ResultOrder();
        position_struct.price = myTrade.ResultPrice();
        position_struct.volume = myTrade.ResultVolume();
        position_struct.order_flag = order_flag;
        position_struct.is_hedge = is_hedge;
        position_struct.trade_datetime = TimeLocal();

        MaStretchHedge::InsertPositionStruct(position_struct);
        return 1;
    }
    if (order_retcode == 2) {
        return 1;
    }
    return 0;
}

int MaStretchHedge::PositionClose()
{
    int position_size = MaStretchHedge::GetPositionStructSize();
    for (int i=0; i < position_size; i++) {
        ulong ticket = position_structs[i].ticket;
        bool is_hedge = position_structs[i].is_hedge;
        string logic_comment = MA_STRETCH_HEDGE_JP;
        if (is_hedge == true) {
            logic_comment = logic_comment + "（ヘッジ）";
        }
        string comment = StringFormat("[%s] 決済. チケット: %d", logic_comment, ticket);
        myTrade.PositionClose(ticket, ULONG_MAX, comment);
        int order_retcode = OrderRetcode(false);
        if (order_retcode == 1) {
            // 履歴記録
            double profit = GetSettlementProfit(myTrade.ResultDeal());
            PositionHistoryForMaStretchHedgeStruct position_history_struct;
            position_history_struct.ticket = ticket;
            position_history_struct.profit = profit;
            InsertPositionHistory(position_history_struct);            
        }
        else if (order_retcode == 2) {
            return 1;
        }
        else {
            return 0;
        }
    }

    // ポジション構造体初期化
    InitLatestPositionStruct();
    return 1;
}


int MaStretchHedge::OrderRetcode(bool is_open)
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