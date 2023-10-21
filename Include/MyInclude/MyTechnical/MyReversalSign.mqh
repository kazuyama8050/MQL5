#include <Object.mqh>
#include <Math\Stat\Math.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>

#import "MyLibraries/Indicator.ex5"
    int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetOpenPriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetHighPriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetLowPriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
#import

#import "MyLibraries/Math.ex5"
    double MathMeanForLong(const CArrayLong &array);
#import

#define DEFAULT_REVERSAL_SIGN_VOLUME_MEAN_WEIGHT 1.2

class MyReversalSign {
    public:
        MyReversalSign();
        ~MyReversalSign();
        double CheckReversalSignByCurrentMarket(string symbol, ENUM_TIMEFRAMES timeframe, int term);
        bool CheckReversalSignForOddPriceList(CArrayDouble &price_list, int term, int term_center_num, int trend);
        bool CheckReversalSignForEvenPriceList(CArrayDouble &price_list, int term, int term_center_num, int trend);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MyReversalSign::MyReversalSign()
{
}
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MyReversalSign::~MyReversalSign()
{
}

/** 直近マーケットによるトレンド反転サイン確認
 * 
 * 
 * 
**/
double MyReversalSign::CheckReversalSignByCurrentMarket(string symbol, ENUM_TIMEFRAMES timeframe, int term) {
    CArrayDouble open_price_list;
    CArrayDouble close_price_list;
    CArrayDouble high_price_list;
    CArrayDouble low_price_list;

    CArrayLong volume_list;

    double is_sign = 0.0;

    GetOpenPriceList(open_price_list, symbol, timeframe, term);
    GetClosePriceList(close_price_list, symbol, timeframe, term);
    GetHighPriceList(high_price_list, symbol, timeframe, term);
    GetLowPriceList(low_price_list, symbol, timeframe, term);

    GetVolumeList(volume_list, symbol, timeframe, term * 5);
    double volume_mean = MathMeanForLong(volume_list);

    int term_center_num;
    

    // 偶数の場合
    if (term % 2 == 0) {
        term_center_num = (int)MathCeil(term / 2) - 1; //配列の要素番号を指す
        // 終値が山形
        if (CheckReversalSignForEvenPriceList(close_price_list, term, term_center_num, 1)) {
            // ボリュームが平均*1.2以上
            if (volume_mean * DEFAULT_REVERSAL_SIGN_VOLUME_MEAN_WEIGHT <= volume_list[term_center_num] && volume_mean * DEFAULT_REVERSAL_SIGN_VOLUME_MEAN_WEIGHT <= volume_list[term_center_num + 1]) {
                // // 山の頂点の一つ目の終値が始値より高い、（高値と終値の差）が（低値と始値の差）より大きい
                // if ((close_price_list[term_center_num] > open_price_list[term_center_num]) && 
                // ((high_price_list[term_center_num] - close_price_list[term_center_num]) > (open_price_list[term_center_num] - low_price_list[term_center_num]))) {
                //     // 山の頂点の2つ目の終値が始値より低い、（高値と始値の差）が（低値と終値の差）より大きい
                //     if ((close_price_list[term_center_num + 1] < open_price_list[term_center_num + 1]) && 
                //     ((high_price_list[term_center_num + 1] - open_price_list[term_center_num + 1]) > (close_price_list[term_center_num + 1] - low_price_list[term_center_num + 1]))) {
                //         is_sign = 1.0;
                //     }
                // }
                if (close_price_list[term_center_num] > open_price_list[term_center_num]) {
                    if (close_price_list[term_center_num + 1] < open_price_list[term_center_num + 1]) {
                        is_sign = 1.0;
                    }
                }
            }
        }
        // 終値が谷型
        else if (CheckReversalSignForEvenPriceList(close_price_list, term, term_center_num, -1)) {
            // ボリュームが平均*1.2以上
            if (volume_mean * DEFAULT_REVERSAL_SIGN_VOLUME_MEAN_WEIGHT <= volume_list[term_center_num] && volume_mean * DEFAULT_REVERSAL_SIGN_VOLUME_MEAN_WEIGHT <= volume_list[term_center_num + 1]) {
                // // 谷の頂点の一つ目の終値が始値より低い、（高値と始値の差）が（低値と終値の差）より小さい
                // if ((close_price_list[term_center_num] < open_price_list[term_center_num]) && 
                // ((high_price_list[term_center_num] - open_price_list[term_center_num]) < (close_price_list[term_center_num] - low_price_list[term_center_num]))) {
                //     // 谷の頂点の2つ目の終値が始値より高い、（高値と終値の差）が（低値と始値の差）より小さい
                //     if ((close_price_list[term_center_num + 1] > open_price_list[term_center_num + 1]) && 
                //     ((high_price_list[term_center_num + 1] - close_price_list[term_center_num + 1]) < (open_price_list[term_center_num + 1] - low_price_list[term_center_num + 1]))) {
                //         is_sign = -1.0;
                //     }
                // }
                if (close_price_list[term_center_num] < open_price_list[term_center_num]) {
                    if (close_price_list[term_center_num + 1] > open_price_list[term_center_num + 1]) {
                        is_sign = -1.0;
                    }
                }
            }
        }

    // 奇数の場合
    } else {
        term_center_num = (int)MathCeil(term / 2); //配列の要素番号を指す
        // （高値と低値の差）が（始値と終値の差の2倍）より大きい
        if ((high_price_list[term_center_num] - low_price_list[term_center_num]) > ((MathAbs(close_price_list[term_center_num] - open_price_list[term_center_num])) * 2)) {
            // ボリュームが平均*1.2以上
            if (volume_mean * DEFAULT_REVERSAL_SIGN_VOLUME_MEAN_WEIGHT <= volume_list[term_center_num]) {
                // 終値が山形
                if (CheckReversalSignForOddPriceList(close_price_list, term, term_center_num, 1)) {
                    is_sign = 1.0;
                }
                // 終値が谷型
                else if (CheckReversalSignForOddPriceList(close_price_list, term, term_center_num, -1)) {
                    is_sign = -1.0;
                }
            }
        }

    }

    return is_sign;
}

/**奇数個の価格リストから反転サインが出ているか判定
 * 引数1 : 価格リスト
 * 引数2 : 価格リスト期間
 * 引数3 : 価格リスト期間の真ん中の要素番号（０始まりで配列の要素番号）
 * 引数4 : トレンド（上昇:1, 下降:-1）
 * return bool （反転サインの場合true）
**/
bool MyReversalSign::CheckReversalSignForOddPriceList(CArrayDouble &price_list, int term, int term_center_num, int trend) {
    for (int i = term - 1;i > 0;i--) {
        if (i > term_center_num + 1) {
            if (trend > 0 && price_list[i] >= price_list[i - 1]) {
                return false;
            }
            if (trend < 0 && price_list[i] <= price_list[i - 1]) {
                return false;
            }
        } else if (i < term_center_num) {
            if (trend > 0 && price_list[i] <= price_list[i - 1]) {
                return false;
            }
            if (trend < 0 && price_list[i] >= price_list[i - 1]) {
                return false;
            }
        }
    }
    
    return true;
}

/**偶数個の価格リストから反転サインが出ているか判定
 * 引数1 : 価格リスト
 * 引数2 : 価格リスト期間
 * 引数3 : 価格リスト期間の真ん中の要素番号（０始まりで配列の要素番号）（偶数は真ん中の要素が2つあるがその１つ目の要素番号）
 * 引数4 : トレンド（上昇:1, 下降:-1）
 * return bool （反転サインの場合true）
**/
bool MyReversalSign::CheckReversalSignForEvenPriceList(CArrayDouble &price_list, int term, int term_center_num, int trend) {
    for (int i = term - 1;i > 0;i--) {
        if (i > term_center_num + 1) {
            if (trend > 0 && price_list[i] >= price_list[i - 1]) {
                return false;
            }
            if (trend < 0 && price_list[i] <= price_list[i - 1]) {
                return false;
            }
        } else if (i <= term_center_num) {
            if (trend > 0 && price_list[i] <= price_list[i - 1]) {
                return false;
            }
            if (trend < 0 && price_list[i] >= price_list[i - 1]) {
                return false;
            }
        }

        if (i > term_center_num + 1) {
            if (trend > 0 && price_list[i] < price_list[i - 1]) {
            }
            if (trend < 0 && price_list[i] > price_list[i - 1]) {
            }
        } else if (i <= term_center_num) {
            if (trend > 0 && price_list[i] > price_list[i - 1]) {
            }
            if (trend < 0 && price_list[i] < price_list[i - 1]) {
            }
        }
        
    }

    return true;
}