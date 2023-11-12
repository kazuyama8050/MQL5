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
    return target_datetime + (exchange_day * ONE_DATE_DATETIME);
}

/** x日前のdatetime型を返す
 * 引数1: 変換前datetime
 * 引数2: x日前
 * return datetime
**/
datetime MinusDayForDatetime(datetime target_datetime, uint exchange_day) export {
    return target_datetime - (exchange_day * ONE_DATE_DATETIME);
}

/** x分後のdatetime型を返す
 * 引数1: 変換前datetime
 * 引数2: x分後
 * return datetime
**/
datetime PlusMinutesForDatetime(datetime target_datetime, uint exchange_minutes) export {
    return target_datetime + (exchange_minutes * ONE_MINUTE_DATETIME);
}

/** x分前のdatetime型を返す
 * 引数1: 変換前datetime
 * 引数2: x分前
 * return datetime
**/
datetime MinusMinutesForDatetime(datetime target_datetime, uint exchange_minutes) export {
    return target_datetime - (exchange_minutes * ONE_MINUTE_DATETIME);
}

/** datetime型をCDateTimeに変換する 
 * args1: 変換前datetime
 * args2: CDateTimeへのポインタ
**/
int DatetimeToCDatetime(datetime target_datetime, CDateTime &cDatetime) export {
    MqlDateTime mql_current_datetime;
    TimeToStruct(target_datetime, mql_current_datetime);

    cDatetime.Sec(mql_current_datetime.sec);
    cDatetime.Min(mql_current_datetime.min);
    cDatetime.Hour(mql_current_datetime.hour);
    cDatetime.Day(mql_current_datetime.day);
    cDatetime.Mon(mql_current_datetime.mon);
    cDatetime.Year(mql_current_datetime.year);
    ZeroMemory(mql_current_datetime);

    return 1;
}

/** datetime型をYYYYmmddに変換する
 * args1: 変換前datetime
 * return: string YYYYmmdd
**/
string ConvertFormattedDate(datetime target_datetime) export {
    MqlDateTime datetime_struct;
    TimeToStruct(target_datetime, datetime_struct);
    string formattedDate = StringFormat("%04d%02d%02d",
    datetime_struct.year, datetime_struct.mon, datetime_struct.day);
    return formattedDate;
}

/** datetime型を文字列に変換する
 * args1 変換前datetime
 * return string YYYY-mm-dd
**/
string ConvertDatetimeToDateString(datetime target_datetime) export {
    MqlDateTime datetime_struct;
    TimeToStruct(target_datetime, datetime_struct);
    string formattedDate = StringFormat("%04d-%02d-%02d",
    datetime_struct.year, datetime_struct.mon, datetime_struct.day);
    return formattedDate;
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

/** datetime型から曜日を取得する
 * args1 変換前datetime
 * return int（日曜日から0スタート）
**/
int GetDayOfWeekFromDatetime(datetime target_datetime) export {
    MqlDateTime datetime_struct;
    TimeToStruct(target_datetime, datetime_struct);
    return datetime_struct.day_of_week;
}