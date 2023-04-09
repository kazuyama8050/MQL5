/**
 * 
 * 検証用
 * 
**/

#include <Object.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Trade\Trade.mqh>

#import "Math.ex5"
    double MathMeanForDouble(const CArrayDouble &array);
#import

input int shift=0;
#define MAGIC_NUMBER_TEST = 123456;

/** tickごとの価格差平均値算出
 * 引数1: 時間軸
 * 引数2: 検証データ数
**/
void PrintPriceDiffMean(ENUM_TIMEFRAMES timeframe, int data_num) {
    CArrayDouble price_list;
    for (int i = 0; i <= data_num; i++) {
        price_list.Insert(iClose(Symbol(), timeframe, i), i);
    }
    
    double price_mean = MathMeanForDouble(price_list);

    double price_diff_mean = 0.0;

    for (int i = 0; i < price_list.Total() - 1; i++) {
        double price1 = price_list.At(i);
        double price2 = price_list.At(i + 1);
        double price_diff = MathAbs(price1 - price2);
        price_diff_mean += price_diff;
    }
    PrintFormat("tickごとの価格差平均値=%f", price_diff_mean / (price_list.Total() - 1));
}

void OnInit() {
    // tickごとの価格差平均値算出
    PrintPriceDiffMean(PERIOD_M15, 5000);
    // PrintPriceDiffMean(PERIOD_M15, 5000);
}