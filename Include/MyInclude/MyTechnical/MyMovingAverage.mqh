#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#import "Trade.ex5"
    bool IsDeceptionTrade(ulong position_ticket, double allowed_percent);
    bool SettlementTrade(MqlTradeRequest &settlement_request, MqlTradeResult &settlement_response, ulong position_ticket);
#import

#define MA_DECEPTION_ALLOWED_PERCENTAGE 0.05  //移動平均トレードの騙し判定許容パーセンテージ

class MyMovingAverage {
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
        double MyMovingAverage::EntrySignalNormal(double &short_ma_list[], double &long_ma_list[]);
        int MyMovingAverage::CheckAfterMaTrade(ulong position_ticket);
        int MyMovingAverage::SettlementTradeByMaSignal(ENUM_POSITION_TYPE signal_position_type, long magic_number);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MyMovingAverage::MyMovingAverage()
  {
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
 * 引数1: 長期移動平均リスト
 * 引数2: 短期移動平均リスト
 * return double シグナル検知
 * ToDo 将来的に重み付けしたい
**/ 
double MyMovingAverage::EntrySignalNormal(double &short_ma_list[], double &long_ma_list[]) {
    int ret = 0;

    //買いシグナル ゴールデンクロス
    if (long_ma_list[2] >= short_ma_list[2] && long_ma_list[1] < short_ma_list[1]) {
        ret = 1.0;
        PrintFormat("買いシグナル発火、long_ma2=%f <= short_ma2=%f、long_ma1=%f > short_ma1=%f", long_ma_list[2], short_ma_list[2], long_ma_list[1], short_ma_list[1]);
    }
    //売りシグナル デッドクロス
    if (long_ma_list[2] <= short_ma_list[2] && long_ma_list[1] > short_ma_list[1]) {
        ret = -1.0;
        PrintFormat("売りシグナル発火、long_ma2=%f >= short_ma2=%f、long_ma1=%f < short_ma1=%f", long_ma_list[2], short_ma_list[2], long_ma_list[1], short_ma_list[1]);
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
    PrintFormat("移動平均トレード騙し判定、ポジションチケット=%d", position_ticket);
    MqlTradeRequest settlement_request={};
    MqlTradeResult settlement_result={};

    if (!SettlementTrade(settlement_request, settlement_result, position_ticket)) {
        return 0;
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

        // ポジションタイプが買い、売りでない
        if (position_type != POSITION_TYPE_BUY && position_type != POSITION_TYPE_SELL) {
            continue;
        }

        //シグナルは判定とポジションタイプが同じ
        if (signal_position_type == position_type) {
            continue;
        } 

        MqlTradeRequest settlement_request={};
        MqlTradeResult settlement_result={};

        if (!SettlementTrade(settlement_request, settlement_result, position_ticket)) {
            continue;
        }

    }
    return 1;
}
