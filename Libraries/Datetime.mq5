//+------------------------------------------------------------------+
//|                                                     Datetime.mq5 |
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

#include <MyInclude\MyCommon\MyDatetime.mqh>

/** x日後のdatetime型を返す
 * 引数1: 変換前datetime
 * 引数2: x日後
 * return datetime
**/
datetime PlusDayForDatetime(datetime target_datetime, uint exchange_day) export {
    MqlDateTime mql_current_datetime;
    TimeToStruct(target_datetime, mql_current_datetime);
    mql_current_datetime.day += int(exchange_day);  //現在からx日後
    return StructToTime(mql_current_datetime);  //datetime型に変換
}

/** x日前のdatetime型を返す
 * 引数1: 変換前datetime
 * 引数2: x日前
 * return datetime
**/
datetime MinusDayForDatetime(datetime target_datetime, uint exchange_day) export {
    MqlDateTime mql_current_datetime;
    TimeToStruct(target_datetime, mql_current_datetime);
    mql_current_datetime.day -= int(exchange_day);  //現在からx日後
    return StructToTime(mql_current_datetime);  //datetime型に変換
}

/** x分後のdatetime型を返す
 * 引数1: 変換前datetime
 * 引数2: x分後
 * return datetime
**/
datetime PlusMinutesForDatetime(datetime target_datetime, uint exchange_minutes) export {
    MqlDateTime mql_current_datetime;
    TimeToStruct(target_datetime, mql_current_datetime);
    mql_current_datetime.min += int(exchange_minutes);  //現在からx分後
    return StructToTime(mql_current_datetime);  //datetime型に変換
}

/** x分前のdatetime型を返す
 * 引数1: 変換前datetime
 * 引数2: x分前
 * return datetime
**/
datetime MinusMinutesForDatetime(datetime target_datetime, uint exchange_minutes) export {
    MqlDateTime mql_current_datetime;
    TimeToStruct(target_datetime, mql_current_datetime);
    mql_current_datetime.min -= int(exchange_minutes);  //現在からx分前
    return StructToTime(mql_current_datetime);  //datetime型に変換
}