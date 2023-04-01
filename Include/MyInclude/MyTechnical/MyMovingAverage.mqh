#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>

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
        double MyMovingAverage::EntrySignalNormal(double &slow_ma_list[], double &fast_ma_list[]);
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
double MyMovingAverage::EntrySignalNormal(double &slow_ma_list[], double &fast_ma_list[]) {
    int ret = 0;

    //買いシグナル ゴールデンクロス
    if (fast_ma_list[2] <= slow_ma_list[2] && fast_ma_list[1] > slow_ma_list[1]) {
        ret = 1.0;
        PrintFormat("買いシグナル発火、fast_ma2=%f <= slow_ma2=%f、fast_ma1=%f > slow_ma1=%f", fast_ma_list[2], slow_ma_list[2], fast_ma_list[1], slow_ma_list[1]);
    }
    //売りシグナル デッドクロス
    if (fast_ma_list[2] >= slow_ma_list[2] && fast_ma_list[1] < slow_ma_list[1]) {
        ret = -1.0;
        PrintFormat("売りシグナル発火、fast_ma2=%f >= slow_ma2=%f、fast_ma1=%f < slow_ma1=%f", fast_ma_list[2], slow_ma_list[2], fast_ma_list[1], slow_ma_list[1]);
    }

    return ret;
}