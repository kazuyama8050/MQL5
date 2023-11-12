//+------------------------------------------------------------------+
//|                                                       Common.mq5 |
//|                                  Copyright 2023, Kazuki Yamasaki |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2023, Kazuki Yamasaki"
#property link      "https://www.mql5.com"
#property version   "1.00"

#define LOG_LINE_TAB_NUM 5

#import "MyLibraries/Datetime.ex5"
    string ConvertDatetimeToString(datetime target_datetime);
    string ConvertFormattedDate(datetime target_datetime);
    string ConvertDatetimeToDateString(datetime target_datetime);
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

/** 指定日のログファイルを読み込み、問題を検知したらメール送信
 * arg1: 指定日
 * arg2: ExpertName
 * arg3: 検知対象文字列（複数ある場合は「,」区切り） 例：ERROR,WARN
 * arg4: メールタイトル
 * 
**/
int SearchAndMailFromLog(datetime target_date, string expert_name, string sig, string title) export {
    string target_date_str = ConvertFormattedDate(target_date);
    string logpath = StringFormat("Logs/%s.log", target_date_str);

    if (!FileIsExist(logpath)) {
        PrintWarn(StringFormat("指定日のログファイルが存在しない, filepath: %s", logpath));
        return 0;
    }

    ushort u_sep = StringGetCharacter(",", 0);
    string split_sig[];
    int sig_num = StringSplit(sig, u_sep, split_sig);
    if (sig_num == 0) {
        PrintWarn(StringFormat("検知対象文字列不正により、前日のログファイル読み込み失敗, sig: %s", sig));
        return 0;
    }

    int filehandle = FileOpen(logpath, FILE_READ|FILE_TXT);
    if (filehandle == INVALID_HANDLE) {
        PrintWarn(StringFormat("Failed Open Log File, filepath: %s", logpath));
        return 0;
    }
    
    string mail_body = "";
    ushort tab = StringGetCharacter("\t", 0);
    while(!FileIsEnding(filehandle)) {
        string line = FileReadString(filehandle);
        string line_seg[];
        int line_seg_num = StringSplit(line, tab, line_seg);
        if (line_seg_num != LOG_LINE_TAB_NUM) {
            continue;
        }

        string trade_info = line_seg[3];
        if (StringFind(trade_info, expert_name) == -1) continue;
        if (StringFind(trade_info, Symbol()) == -1) continue;
        if (StringFind(trade_info, PeriodToStr(Period())) == -1) continue;

        string print_str = line_seg[4];
        bool is_sig_included = false;
        for (int i=0;i<sig_num;i++) {
            if (StringFind(print_str, split_sig[i]) != -1) {
                is_sig_included = true;
                break;
            }
        }
        if (!is_sig_included) continue;
        
        string datetime_format = StringFormat("%s %s", ConvertDatetimeToDateString(target_date), line_seg[2]);
        string log_str = StringFormat("%s\n%s", datetime_format, print_str);
        mail_body = StringFormat("%s\n\n%s", mail_body, log_str);
    }
    if (mail_body == "") return 1;

    string mail_title = StringFormat("%s_%s", title, target_date_str);
    string mail_header = StringFormat("ExpertName: %s\nSymbol: %s:%s", expert_name, Symbol(), PeriodToStr(Period()));
    mail_body = StringFormat("%s\n\n-------------------------\n%s", mail_header, mail_body);
    if (!SendMail(mail_title, mail_body)) {
        PrintError("メール送信失敗");
        return 0;
    }
    return 1;
}

/** 指定日より古いログファイルを削除する
 * arg1: 指定日
**/
int DeleteOlderLogFile(datetime target_date) export {
    string target_date_str = ConvertFormattedDate(target_date);
    ushort dot = StringGetCharacter(".", 0);
    string filename;
    long search_handle=FileFindFirst("Logs/*.log",filename);
    if (search_handle == INVALID_HANDLE) {
        return 0;
    }

    do
       {
            ResetLastError();
            string filename_seg[];
            int line_seg_num = StringSplit(filename, dot, filename_seg);
            if (line_seg_num != 2) {
                continue;
            }
            string date_yyyymmdd = filename_seg[0];
            if(date_yyyymmdd < target_date_str) {
                string filepath = StringFormat("Logs/%s", filename);
                FileDelete(filepath);
                PrintNotice(StringFormat("%s file deleted!", filepath));
            }
       }
    while(FileFindNext(search_handle,filename));
    FileFindClose(search_handle);

    return 1;
}