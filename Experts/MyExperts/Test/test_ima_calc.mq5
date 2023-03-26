//+------------------------------------------------------------------+
//|                                                     test_ima.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Object.mqh>
#include <Trade\Trade.mqh>
// #include <Indicator\Indicator.mqh>
#include "include/test_ima.mqh"

input int shift=0;
#define MAGIC_NUMBER_TEST = 123456;

int TestIma::m_ima_handle;
double movingAverage[];

// TestIma testIma;

static int TestIma::MainLoop() {
    while(true) {
        if (BarsCalculated(m_ima_handle) < 0) {
            Print("Cannot Get Ima Data");
            Sleep(10000); // 10秒スリープ
            continue;
        }
        double ma[2];
        CopyBuffer(m_ima_handle, 0, 0, 2, ma);

        PrintFormat("ma[0] = %f, ma[1] = %f", ma[0], ma[1]);
        Sleep(10000); // 10秒スリープ
    }
    return 1;
}

static bool TestIma::TestPrint(void) {
    Print("AAA");
    return true;
}


/**
 * 移動平均を取得
 * 第一引数：銘柄
 * 第二引数：チャート時間軸
 * 第三引数：平均期間
 * 第四引数：水平シフト
 * 第五引数：平滑化の種類（移動平均、指数移動平均とか）
 * 第六引数：価格の種類かハンドル（終値か始値かとか）
 * 
**/
static int TestIma::ImaIndicator(
                            string symbol,
                            ENUM_TIMEFRAMES period, 
                            int ma_period, 
                            int ma_shift, 
                            ENUM_MA_METHOD ma_method, 
                            ENUM_APPLIED_PRICE applied_price
                            ) 
{
    m_ima_handle=iMA(symbol,period,ma_period,ma_shift,ma_method,applied_price);
    if (m_ima_handle == INVALID_HANDLE) {
        PrintFormat("Failed To Create IMA Handle, symbol=%s, error code=%d", symbol, GetLastError());
        return false;
    }
    string short_name=StringFormat("iMA(%s/%s, %d, %d, %s, %s)",
                            symbol,EnumToString(period),
                            ma_period, ma_shift,EnumToString(ma_method),
                            EnumToString(applied_price));

    IndicatorSetString(INDICATOR_SHORTNAME,short_name);
    Print(short_name);

    return m_ima_handle;
}

void OnInit() {
    // Print("Start EA test_ima");
    // 初期化処理など
    return;
}

void OnStart() {
    // ハンドラーの初期化
    int m_ima_handle = TestIma::ImaIndicator(_Symbol, PERIOD_M5, 25, 0, MODE_SMA, PRICE_CLOSE);
    //配列を時系列にセット
    ArraySetAsSeries(movingAverage,true); 
    
    //現在足からさかのぼって10本分の移動平均価格情報を配列に格納
    CopyBuffer(m_ima_handle,0,0,10,movingAverage);
    //--- 失敗した事実とエラーコードを出力する
    if (m_ima_handle == INVALID_HANDLE) {
        PrintFormat("Failed to create handle of the iMA indicator for the symbol %s/%s, error code %d",
                    _Symbol,
                    EnumToString(PERIOD_M5),
                    GetLastError());
    }

    int main_loop_ret = TestIma::MainLoop();
}

// /**
//  * 
// **/
// void OnTimer() {

// }

// /**
//  * 相場更新タイミングで呼び出される
//  * 処理中に呼び出しシグナルがあっても無視する
// **/
// void OnTick() {

// }

// /**
//  *  取引完了直後に呼び出される
// **/
// void OnTrade() {

// }

// /**
//  * 
// **/
// void OnDeinit() {

// }
