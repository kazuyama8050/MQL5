/**
 * ブレークアウトロジック
**/

#include <Object.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>

#import "MyLibraries/Trade.ex5"
    double GetSettlementProfit(ulong deal_ticket);
#import
#import "MyLibraries/Indicator.ex5"
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    double GetLatestClosePrice(string symbol, ENUM_TIMEFRAMES timeframe);
#import
#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintDebug(const string log_str);
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
#import

#import "MyLibraries/Datetime.ex5"
    datetime PlusMinutesForDatetime(datetime target_datetime, uint exchange_minutes);
#import
#import "MyLibraries/Math.ex5"
    double MathMeanForDouble(const CArrayDouble &array);
    double MathMaxForDouble(const CArrayDouble &array, const int start, int count);
    double MathMinForDouble(const CArrayDouble &array, const int start, int count);
#import

int BREAKOUT_HIGH = 1;
int BREAKOUT_LOW = -1;
int NO_BREAKOUT = 0;

long BREAKOUT_MAGIC_NUMBER = 10001;

struct LatestPositionForBreakoutStruct
{
    ulong ticket;
    double price;
    double volume;
    datetime trade_datetime;
};

struct PositionHistoryForBreakoutStruct
{
    ulong ticket;
    double profit;
};

class BreakoutTrade
{
    protected:
        ENUM_TIMEFRAMES timeframe;
        int short_shift;
        int middle_shift;
        int long_shift;
        uint position_having_minutes;
        CMyTrade myTrade;

        long magic_number;
        LatestPositionForBreakoutStruct latest_position_struct;
        PositionHistoryForBreakoutStruct position_histories[];

    public:
        BreakoutTrade(CMyTrade &myTradeInput, ENUM_TIMEFRAMES timeframe_input, int short_shift_input, int middle_shift_input, int long_shift_input, uint position_having_minutes_input);
        ~BreakoutTrade(void);

        void BreakoutTrade::InitLatestPositionStruct();
        int BreakoutTrade::Execute();
        int BreakoutTrade::CheckClose();
        int BreakoutTrade::CheckBreakout();
        int BreakoutTrade::TradeOrder(int breakout_flag);
        int BreakoutTrade::PositionClose();
        int BreakoutTrade::OrderRetcode(bool is_open);

    private:
        ENUM_TIMEFRAMES BreakoutTrade::GetTimeframe() {return timeframe;}
        int BreakoutTrade::GetShortShift() {return short_shift;}
        int BreakoutTrade::GetMiddleShift() {return middle_shift;}
        int BreakoutTrade::GetLongShift() {return long_shift;}
        uint BreakoutTrade::GetPositionHavingMinutes() {return position_having_minutes;}
        bool BreakoutTrade::HasPosition() {
            return latest_position_struct.ticket != 0;
        }

        int BreakoutTrade::GetPositionHistorySize() {return ArraySize(position_histories);}
        void BreakoutTrade::InsertPositionHistory(PositionHistoryForBreakoutStruct &position_history) {
            int size = GetPositionHistorySize();
            ArrayResize(position_histories, size+1);
            position_histories[size] = position_history;
        }
};

BreakoutTrade::BreakoutTrade(CMyTrade &myTradeInput, ENUM_TIMEFRAMES timeframe_input, int short_shift_input, int middle_shift_input, int long_shift_input, uint position_having_minutes_input)
{
    myTrade = myTradeInput;
    timeframe = timeframe_input;
    short_shift = short_shift_input;
    middle_shift = middle_shift_input;
    long_shift = long_shift_input;
    position_having_minutes = position_having_minutes_input;
    magic_number = BREAKOUT_MAGIC_NUMBER;

    InitLatestPositionStruct();
    ArrayFree(position_histories);

    myTrade.SetAsyncMode(false);
    myTrade.SetExpertMagicNumber(magic_number);
    myTrade.SetTypeFilling(ORDER_FILLING_IOC);
}

BreakoutTrade::~BreakoutTrade(void)
{}

void BreakoutTrade::InitLatestPositionStruct()
{
    latest_position_struct.ticket = 0;
    latest_position_struct.price = 0.0;
    latest_position_struct.volume = 0.0;
    latest_position_struct.trade_datetime = TimeLocal();
}

int BreakoutTrade::Execute()
{
    if (HasPosition() == true) {
        if (CheckClose() == 1) {
            if (PositionClose() == 0) {
                return 0;
            }
        }
    } else {
        int breakout_flag = CheckBreakout();
        if (breakout_flag != NO_BREAKOUT) {
            if (TradeOrder(breakout_flag) ==0) {
                return 0;
            }
        }
    }
    return 1;
}

int BreakoutTrade::CheckClose()
{
    datetime latest_datetime = latest_position_struct.trade_datetime;
    if (PlusMinutesForDatetime(latest_datetime, position_having_minutes) <= TimeLocal()) {
        return 1;
    }
    return 0;
}

/**
 * 最新値と最新値以外の最大値・最小値と比較してブレークアウトしているか判断
 **/
int BreakoutTrade::CheckBreakout()
{
    CArrayDouble short_price_list;
    GetClosePriceList(short_price_list, Symbol(), BreakoutTrade::GetTimeframe(), short_shift);
    
    if (MathMaxForDouble(short_price_list, 1, 0) < short_price_list[0]) {
        return BREAKOUT_HIGH;
    }
    if (MathMinForDouble(short_price_list, 1, 0) > short_price_list[0]) {
        return BREAKOUT_LOW;
    }

    CArrayDouble middle_price_list;
    GetClosePriceList(middle_price_list, Symbol(), BreakoutTrade::GetTimeframe(), middle_shift);

    if (MathMaxForDouble(middle_price_list, 1, 0) < middle_price_list[0]) {
        return BREAKOUT_HIGH;
    }
    if (MathMinForDouble(middle_price_list, 1, 0) > middle_price_list[0]) {
        return BREAKOUT_LOW;
    }

    CArrayDouble long_price_list;
    GetClosePriceList(long_price_list, Symbol(), BreakoutTrade::GetTimeframe(), long_shift);

    if (MathMaxForDouble(long_price_list, 1, 0) < long_price_list[0]) {
        return BREAKOUT_HIGH;
    }
    if (MathMinForDouble(long_price_list, 1, 0) > long_price_list[0]) {
        return BREAKOUT_LOW;
    }

    return NO_BREAKOUT;
}

int BreakoutTrade::TradeOrder(int breakout_flag)
{
    double volume = 0.01;
    string trade_comment = "売り";
    if (breakout_flag == BREAKOUT_HIGH) {
        trade_comment = "買い";
    }
    ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
    double price = 0.0;
    if (breakout_flag == BREAKOUT_HIGH) {  // 買い注文
        order_type = ORDER_TYPE_BUY;
        price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    } else if (breakout_flag == BREAKOUT_LOW) {  // 売り注文
        order_type = ORDER_TYPE_SELL;
        price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    }
    const string comment = StringFormat("[%s]%s : %.2f * %.5f", "ブレークアウト", trade_comment, volume, price);

    myTrade.PositionOpen(Symbol(), order_type, volume, price, 0, 0, comment);
    int order_retcode = OrderRetcode(true);
    if (order_retcode == 1) {
        latest_position_struct.ticket = myTrade.ResultOrder();
        latest_position_struct.price = myTrade.ResultPrice();
        latest_position_struct.volume = myTrade.ResultVolume();
        latest_position_struct.trade_datetime = TimeLocal();
        return 1;
    }
    if (order_retcode == 2) {
        return 1;
    }
    return 0;
}


int BreakoutTrade::PositionClose()
{
    ulong ticket = latest_position_struct.ticket;
    string comment = StringFormat("[ブレークアウト] 決済. チケット: %d", ticket);
    myTrade.PositionClose(ticket, ULONG_MAX, comment);
    int order_retcode = OrderRetcode(false);
    if (order_retcode == 1) {
        // 履歴記録
        double profit = GetSettlementProfit(myTrade.ResultDeal());
        PositionHistoryForBreakoutStruct position_history_struct;
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


int BreakoutTrade::OrderRetcode(bool is_open)
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