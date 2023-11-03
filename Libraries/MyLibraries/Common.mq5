//+------------------------------------------------------------------+
//|                                                       Common.mq5 |
//|                                  Copyright 2023, Kazuki Yamasaki |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2023, Kazuki Yamasaki"
#property link      "https://www.mql5.com"
#property version   "1.00"

#import "MyLibraries/Datetime.ex5"
    string ConvertDatetimeToString(datetime target_datetime);
#import
//+------------------------------------------------------------------+
//| My function                                                      |
//+------------------------------------------------------------------+

/** 強制終了
 * 
**/
void ForceStopEa() export {
    Alert("[ERROR] 予期せぬエラーが発生しました。");
    ExpertRemove();
}

/**
 * ログ出力
**/
void PrintNotice(const string log_str) export {
    PrintFormat("[NOTICE] %s", log_str);
}

void PrintWarn(const string log_str) export {
    PrintFormat("[WARN] %s", log_str);
    // SendMail("")
}

void PrintError(const string log_str) export {
    PrintFormat("[ERROR] %s", log_str);
    // メール送信
    SendMail("FX 自動売買 エラー検出", GetCommonLogData(log_str));
}

string GetCommonLogData(const string log_str) export {
    return StringFormat(
        "%s\t%s:%s\t%s",
        ConvertDatetimeToString(TimeLocal()),
        Symbol(),
        PeriodToStr(Period()),
        log_str
    );
}

string PeriodToStr(ENUM_TIMEFRAMES period) export {
   switch(period) {
        case PERIOD_MN1 : return "MN1";
        case PERIOD_W1 :  return "W1";
        case PERIOD_D1 :  return "D1";
        case PERIOD_H1 :  return "H1";
        case PERIOD_H2 :  return "H2";
        case PERIOD_H3 :  return "H3";
        case PERIOD_H4 :  return "H4";
        case PERIOD_H6 :  return "H6";
        case PERIOD_H8 :  return "H8";
        case PERIOD_H12 : return "H12";
        case PERIOD_M1 :  return "M1";
        case PERIOD_M2 :  return "M2";
        case PERIOD_M3 :  return "M3";
        case PERIOD_M4 :  return "M4";
        case PERIOD_M5 :  return "M5";
        case PERIOD_M6 :  return "M6";
        case PERIOD_M10 : return "M10";
        case PERIOD_M12 : return "M12";
        case PERIOD_M15 : return "M15";
        case PERIOD_M20 : return "M20";
        case PERIOD_M30 : return "M30";
        default : return "Undefined";
    }
   return "Undefined";
  }