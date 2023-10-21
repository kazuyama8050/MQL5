//+------------------------------------------------------------------+
//|                                                       Common.mq5 |
//|                                  Copyright 2023, Kazuki Yamasaki |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2023, Kazuki Yamasaki"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| My function                                                      |
//+------------------------------------------------------------------+

/** 強制終了
 * 
**/
void ForceStopEa() export {
    Alert("予期せぬエラーが発生しました。");
    ExpertRemove();
}
