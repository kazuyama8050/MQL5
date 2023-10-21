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
#include <Tools/DateTime.mqh>

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

/** datetime型をYYYYmmddに変換する
 * args1: 変換前datetime
 * return: string YYYYmmdd
**/
string ConvertFormattedDate(datetime target_datetime) export {
    return TimeToString(target_datetime, TIME_DATE | TIME_MINUTES);
}

/** datetime型を文字列に変換する
 * args1 変換前datetime
 * return string YYYY-mm-dd HH:mm:ss
**/
string ConvertDatetimeToString(datetime target_datetime) export {
    MqlDateTime datetime_struct;
    TimeToStruct(target_datetime, datetime_struct);
    string formattedDate = StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
    datetime_struct.year, datetime_struct.mon, datetime_struct.day, 
    datetime_struct.hour, datetime_struct.min, datetime_struct.sec);
    return formattedDate;
}