//+------------------------------------------------------------------+
//|                                                    Indicator.mq5 |
//|                                  Copyright 2023, Kazuki Yamasaki |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2023, Kazuki Yamasaki"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
//+------------------------------------------------------------------+
//| インジケーター系ライブラリ                                           |
//+------------------------------------------------------------------+


/**  直近のボリュームリスト格納する
 * 引数1: 格納先配列ポインタ  現在の1個前ボリュームから順に格納
 * 引数2: シンボル
 * 引数3: チャート時間軸
 * 引数4: 取得数
 * return int 成功可否
**/
int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift) export {
    if (volume_list.Total() > 0) {return 0;}
    for (int i = 0; i < shift; i++) {
        volume_list.Insert(iVolume(symbol, timeframe, i), i);
    }
    return 1;
}

/**  直近の始値リスト格納する
 * 引数1: 格納先配列ポインタ  現在価格から順に格納
 * 引数2: シンボル
 * 引数3: チャート時間軸
 * 引数4: 取得数
 * return int 成功可否
**/
int GetOpenPriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift) export {
    if (price_list.Total() > 0) {return 0;}
    
    for (int i = 0; i < shift; i++) {
        price_list.Insert(iOpen(symbol, timeframe, i), i);
    }
    return 1;
}

/**  直近の終値リスト格納する
 * 引数1: 格納先配列ポインタ  現在価格から順に格納
 * 引数2: シンボル
 * 引数3: チャート時間軸
 * 引数4: 取得数
 * return int 成功可否
**/
int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift) export {
    if (price_list.Total() > 0) {return 0;}
    
    for (int i = 0; i < shift; i++) {
        price_list.Insert(iClose(symbol, timeframe, i), i);
    }
    return 1;
}

/**  直近の高値リスト格納する
 * 引数1: 格納先配列ポインタ  現在価格から順に格納
 * 引数2: シンボル
 * 引数3: チャート時間軸
 * 引数4: 取得数
 * return int 成功可否
**/
int GetHighPriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift) export {
    if (price_list.Total() > 0) {return 0;}
    
    for (int i = 0; i < shift; i++) {
        price_list.Insert(iHigh(symbol, timeframe, i), i);
    }
    return 1;
}

/**  直近の低値リスト格納する
 * 引数1: 格納先配列ポインタ  現在価格から順に格納
 * 引数2: シンボル
 * 引数3: チャート時間軸
 * 引数4: 取得数
 * return int 成功可否
**/
int GetLowPriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift) export {
    if (price_list.Total() > 0) {return 0;}
    
    for (int i = 0; i < shift; i++) {
        price_list.Insert(iLow(symbol, timeframe, i), i);
    }
    return 1;
}