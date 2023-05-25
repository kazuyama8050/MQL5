//+------------------------------------------------------------------+
//|                                                       CalendarEvent.mq5 |
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


/** 指定期間から対象国の経済指標イベント値を取得する
 * 引数1: MqlCalendarValue構造体の配列
 * 引数2: 国を格納した配列
 * 引数3: 開始期間日時
 * 引数4: 終了期間日時
 * return int 取得数
**/
int GetCalendarValueByCountries(MqlCalendarValue &mql_calendar_value_list[], const string &target_country_list[], datetime fromDatetime, datetime toDatetime) export {
    int target_country_cnt = ArraySize(target_country_list);
    if (target_country_cnt < 1) {
        return 0;
    }
    
    for (int i = 0;i < target_country_cnt;i++) {
        MqlCalendarValue mql_calendar_values[];
        if (CalendarValueHistory(mql_calendar_values, fromDatetime, toDatetime, target_country_list[i])) {
            int calendar_event_cnt = ArraySize(mql_calendar_value_list);
            int calendar_value_cnt = ArraySize(mql_calendar_values);
            ArrayResize(mql_calendar_value_list, calendar_event_cnt + calendar_value_cnt);
            for (int y = 0;y < calendar_value_cnt;y++) {
                mql_calendar_value_list[calendar_event_cnt + y] = mql_calendar_values[y];
            }
        } else {
            return 0;
        }
    }
    return ArraySize(mql_calendar_value_list);
}

/** イベントIDから経済指標イベント説明を取得する
 * 引数1: MqlCalendarEvent構造体
 * 引数2: イベントID
 * return int 取得数
**/
int GetCalendarEventByEventId(MqlCalendarEvent &mql_calendar_event, ulong event_id) export {
    if (!CalendarEventById(event_id, mql_calendar_event)) {
        return 0;
    }

    return 1;
}

/** イベントID配列から経済指標イベント説明を取得する
 * 引数1: MqlCalendarEvent構造体の配列
 * 引数2: イベントID配列
 * return int 取得数
**/
int GetCalendarEventByEventIds(MqlCalendarEvent &mql_calendar_event_list[], const ulong &event_id_list[]) export {
    int event_id_cnt = ArraySize(event_id_list);
    if (event_id_cnt < 1) {
        return 0;
    }
    
    for (int i = 0;i < event_id_cnt;i++) {
        MqlCalendarEvent mql_calendar_event;
        if (!GetCalendarEventByEventId(mql_calendar_event, event_id_list[i])) {
            return 0;
        }

        int mql_calendar_event_cnt = ArraySize(mql_calendar_event_list);
        ArrayResize(mql_calendar_event_list, mql_calendar_event_cnt + 1);
        mql_calendar_event_list[mql_calendar_event_cnt] = mql_calendar_event;
    }

    return ArraySize(mql_calendar_event_list);
}