#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>
#include <MyInclude\MyFile\MyFileHandler.mqh>
#include "../../../Experts/MyExperts/Ima/include/ExpertIma.mqh"
#import "Trade.ex5"
    bool IsDeceptionTrade(ulong position_ticket, double allowed_percent);
    bool SettlementTrade(MqlTradeRequest &settlement_request, MqlTradeResult &settlement_response, ulong position_ticket, string comment);
    double GetSettlementProfit(ulong position_ticket);
#import
#import "Math.ex5"
    double MathMeanForDouble(const CArrayDouble &array);
    double MathDiffMeanForDouble(const CArrayDouble &array);
#import
#import "File.ex5"
    string GetValueOfFileKey(int file_handle, string key);
#import
#import "Common.ex5"
    void ForceStopEa();
#import

#define MA_DECEPTION_ALLOWED_PERCENTAGE 0.03  //移動平均トレードの騙し判定許容パーセンテージ

struct maTradeHistory
{
    ulong position_ticket;
    double current_price_and_ma_diff;
    ulong deal_ticket;
    double profit;
    int is_benefit;
};

class MyMovingAverage {
    public:
        double price_diff_mean;
        static maTradeHistory MyMovingAverage::ma_trade_history_list[];  //移動平均トレード履歴構造体
        static int MyMovingAverage::ma_trade_loss_cnt;
    public:
        MyMovingAverage();
        ~MyMovingAverage();
        int MyMovingAverage::CreateMaIndicator(
                            string symbol,
                            ENUM_TIMEFRAMES period, 
                            int ma_period, 
                            int ma_shift, 
                            ENUM_MA_METHOD ma_method, 
                            ENUM_APPLIED_PRICE applied_price
        );
        double MyMovingAverage::EntrySignalNormal(double &short_ma_list[], double &long_ma_list[], CArrayDouble &price_list);
        int MyMovingAverage::CheckAfterMaTrade(ulong position_ticket);
        int MyMovingAverage::SettlementTradeByMaSignal(ENUM_POSITION_TYPE signal_position_type, long magic_number);
        int MyMovingAverage::SettlementTradeByMaTrendSignal(double &short_ma_list[], int compare_term, long magic_number);
        int MyMovingAverage::SetMaTradeHistoryForTrade(MqlTradeResult &trade_result, CArrayDouble &price_list, double &short_ma_list[]);

    private:
        int MyMovingAverage::SetMaTradeHistoryForSettlement(ulong position_ticket, ulong deal_ticket, double position_deal_profit);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MyMovingAverage::MyMovingAverage()
{
    MyFileHandler myFileHandler(PRICE_DIFF_MEAN_FILEPATH, FILE_READ|FILE_WRITE, TSV_SEPARATE_STRING);
    int file_handle = myFileHandler.CreateFileHandler();
    if (!file_handle) {
        ForceStopEa();
    }
    string price_diff_mean_str = GetValueOfFileKey(file_handle, IntegerToString(COMMON_PERIOD));
    price_diff_mean = StringToDouble(price_diff_mean_str);
    if (price_diff_mean <= 0) {
        price_diff_mean = PRICE_DIFF_MEAN_OF_15_MINUTES;  //暫定で入れておく
    }

    ArraySetAsSeries(MyMovingAverage::ma_trade_history_list,false);
    ZeroMemory(MyMovingAverage::ma_trade_history_list);
}
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MyMovingAverage::~MyMovingAverage()
{
}

/** ma handler 作成
 * 
**/
int MyMovingAverage::CreateMaIndicator(
                            string symbol,
                            ENUM_TIMEFRAMES period, 
                            int ma_period, 
                            int ma_shift, 
                            ENUM_MA_METHOD ma_method, 
                            ENUM_APPLIED_PRICE applied_price
                            )
{
    int m_ima_handle=iMA(symbol,period,ma_period,ma_shift,ma_method,applied_price);
    if (m_ima_handle == INVALID_HANDLE) {
        PrintFormat("Failed To Create IMA Handle, symbol=%s, error code=%d", symbol, GetLastError());
        return false;
    }

    return m_ima_handle;
}

/** 移動平均のエントリシグナル検知
 * 引数1: 短期移動平均リスト（要素数3以上）
 * 引数2: 長期移動平均リスト（要素数3以上）
 * 引数3: 直近からの価格リスト
 * return double シグナル検知
 * ToDo 将来的に重み付けしたい
**/ 
double MyMovingAverage::EntrySignalNormal(double &short_ma_list[], double &long_ma_list[], CArrayDouble &price_list) {
    int ret = 0;

    int price_list_num = price_list.Total();
    double price_mean = MathMeanForDouble(price_list);
    double current_price = price_list.At(0);
    double price_list_diff_mean = MathDiffMeanForDouble(price_list);
    
    //買いシグナル ゴールデンクロス
    if (long_ma_list[2] >= short_ma_list[2] && long_ma_list[0] < short_ma_list[0]) {
        // 上昇トレンド中 （直近価格が平均より高いとしておく）
        if (price_mean < current_price) {
            ret = 1.0;
            PrintFormat("買いシグナル発火、long_ma2=%f >= short_ma2=%f、long_ma0=%f < short_ma0=%f", long_ma_list[2], short_ma_list[2], long_ma_list[0], short_ma_list[0]);
        }
    }
    //売りシグナル デッドクロス
    if (long_ma_list[2] <= short_ma_list[2] && long_ma_list[0] >= short_ma_list[0]) {
        // 下降トレンド中 （直近価格が平均より低いとしておく）
        if (price_mean > current_price) {
            ret = -1.0;
            PrintFormat("売りシグナル発火、long_ma2=%f >= short_ma2=%f、long_ma0=%f > short_ma0=%f", long_ma_list[2], short_ma_list[2], long_ma_list[0], short_ma_list[0]);
        }
    }

    return ret;
}

/** 移動平均トレードの騙し判定監視
 * 引数1: ポジションチケット
 * return int
**/
int MyMovingAverage::CheckAfterMaTrade(ulong position_ticket) {
    if (!IsDeceptionTrade(position_ticket, MA_DECEPTION_ALLOWED_PERCENTAGE)) {
        return 0;
    }
    MqlTradeRequest settlement_request={};
    MqlTradeResult settlement_result={};

    string comment = StringFormat("移動平均トレードの騙し判定による決済、チケット=%d", position_ticket);

    if (!SettlementTrade(settlement_request, settlement_result, position_ticket, comment)) {
        return 0;
    }

    double position_deal_profit = GetSettlementProfit(settlement_result.deal);
    if (position_deal_profit < 0.0) {
        MyMovingAverage::ma_trade_loss_cnt += 1;
    }
    MyMovingAverage::SetMaTradeHistoryForSettlement(position_ticket, settlement_result.deal, position_deal_profit);
    return 1;
}

/** 移動平均トレンドシグナル検知によるポジション決済
 * 引数1: 短期移動平均リストのポインタ
 * 引数2: 比較対象の移動平均対象期間（tick数指定）
 * 引数3: magic_number 移動平均以外のトレードの決済はしない
**/
int MyMovingAverage::SettlementTradeByMaTrendSignal(double &short_ma_list[], int compare_term, long magic_number) {
    int total_position = PositionsTotal();

    for (int i = 0; i < total_position; i++) {
        ulong  position_ticket = PositionGetTicket(i);
        
        ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        long position_magic = PositionGetInteger(POSITION_MAGIC);

        //magic_numberが異なれば移動平均トレードでない
        if (position_magic != magic_number) {
            continue;
        }

        int is_settlement = 1;
        for (int i = compare_term;i > 0;i--) {
            // 買いポジションの場合、期間中に一回でも上昇トレンドのままなら何もしない
            if (position_type == POSITION_TYPE_BUY) {
                if (short_ma_list[i - 1] > short_ma_list[i]) {
                    is_settlement = 0;
                }
            // 売りポジションの場合、期間中に一回でも下落トレンドのままなら何もしない
            } else if (position_type == POSITION_TYPE_SELL) {
                if (short_ma_list[i - 1] < short_ma_list[i]) {
                    is_settlement = 0;
                }
            }
        }

        if (!is_settlement) {
            continue;
        }

        MqlTradeRequest settlement_request={};
        MqlTradeResult settlement_result={};

        string comment = StringFormat("移動平均トレンドシグナル検知による決済、チケット=%d", position_ticket);

        if (!SettlementTrade(settlement_request, settlement_result, position_ticket, comment)) {
            continue;
        }

        double position_deal_profit = GetSettlementProfit(settlement_result.deal);
        if (position_deal_profit < 0.0) {
            MyMovingAverage::ma_trade_loss_cnt += 1;
        }
        MyMovingAverage::SetMaTradeHistoryForSettlement(position_ticket, settlement_result.deal, position_deal_profit);
    }
    return 1;
}

/** 移動平均シグナル検知によるポジション決済
 * 引数1: シグナルタイプが買いか売りか
 * 引数2: magic_number 移動平均以外のトレードの決済はしない
 * return int
**/
int MyMovingAverage::SettlementTradeByMaSignal(ENUM_POSITION_TYPE signal_position_type, long magic_number) {
    int total_position = PositionsTotal();  //保有ポジション数

    for (int i = 0; i < total_position; i++) {
        ulong  position_ticket = PositionGetTicket(i);
        
        ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        long position_magic = PositionGetInteger(POSITION_MAGIC);

        //magic_numberが異なれば移動平均トレードでない
        if (position_magic != magic_number) {
            continue;
        }

        // シグナル判定が買い、売りでない
        if (signal_position_type != POSITION_TYPE_BUY && signal_position_type != POSITION_TYPE_SELL) {
            continue;
        }

        //シグナルは判定とポジションタイプが同じ
        if (signal_position_type == position_type) {
            continue;
        } 

        MqlTradeRequest settlement_request={};
        MqlTradeResult settlement_result={};

        string comment = StringFormat("移動平均シグナル検知による決済、チケット=%d", position_ticket);

        if (!SettlementTrade(settlement_request, settlement_result, position_ticket, comment)) {
            continue;
        }

        double position_deal_profit = GetSettlementProfit(settlement_result.deal);
        if (position_deal_profit < 0.0) {
            MyMovingAverage::ma_trade_loss_cnt += 1;
        }
        MyMovingAverage::SetMaTradeHistoryForSettlement(position_ticket, settlement_result.deal, position_deal_profit);

    }
    return 1;
}

int MyMovingAverage::SetMaTradeHistoryForTrade(MqlTradeResult &trade_result, CArrayDouble &price_list, double &short_ma_list[]) {
    int ma_trade_history_cnt = ArraySize(MyMovingAverage::ma_trade_history_list);
    ArrayResize(MyMovingAverage::ma_trade_history_list, ma_trade_history_cnt + 1);
    maTradeHistory ma_trade_history = {};
    ma_trade_history.position_ticket = trade_result.order;
    ma_trade_history.current_price_and_ma_diff = MathAbs(price_list[0] - short_ma_list[0]);
    MyMovingAverage::ma_trade_history_list[ma_trade_history_cnt] = ma_trade_history;

    return 1;
}

int MyMovingAverage::SetMaTradeHistoryForSettlement(ulong position_ticket, ulong deal_ticket, double position_deal_profit) {
    int ma_trade_history_cnt = ArraySize(MyMovingAverage::ma_trade_history_list);
    for (int i = 0; i < ma_trade_history_cnt; i++) {
        if (MyMovingAverage::ma_trade_history_list[i].position_ticket == position_ticket) {
            MyMovingAverage::ma_trade_history_list[i].deal_ticket = deal_ticket;
            MyMovingAverage::ma_trade_history_list[i].profit = position_deal_profit;
            MyMovingAverage::ma_trade_history_list[i].is_benefit = (position_deal_profit < 0.0) ? 0 : 1;

            return 1;
        }
    }
    return 0;
}