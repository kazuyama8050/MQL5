#include <Object.mqh>
#include <Files\File.mqh>
#include <Files\FileTxt.mqh>

#import "MyLibraries/Datetime.ex5"
    string ConvertFormattedDate(datetime target_datetime);
    string ConvertDatetimeToDateString(datetime target_datetime);
#import
#import "MyLibraries/Common.ex5"
    string PeriodToStr(ENUM_TIMEFRAMES period);
#import

#define LOG_LINE_TAB_NUM 5

class MyLogHandler
{
    protected:
        string expertName;
        string accountTradeMode;
        string accountClientName;
        ushort comma; // コンマ区切り文字
        ushort tab;  // タブ区切り文字
        ushort dot;  // ドット区切り文字
    public:
        MyLogHandler(string expert_name, string account_trade_mode, string account_client_name);
        ~MyLogHandler();
        int MyLogHandler::SearchAndMailFromLog(datetime target_date, string sig, string title);
        int MyLogHandler::DeleteOlderLogFile(datetime target_date);
        
};

MyLogHandler::MyLogHandler(
    string expert_name,
    string account_trade_mode,
    string account_client_name
)
{
    expertName = expert_name;
    accountTradeMode = account_trade_mode;
    accountClientName = account_client_name;
    comma = StringGetCharacter(",", 0);
    tab = StringGetCharacter("\t", 0);
    dot = StringGetCharacter(".", 0);
}
MyLogHandler::~MyLogHandler()
{}

/** 指定日のログファイルを読み込み、問題を検知したらメール送信
 * arg1: 指定日
 * arg2: 検知対象文字列（複数ある場合は「,」区切り） 例：ERROR,WARN
 * arg3: メールタイトル
**/
int MyLogHandler::SearchAndMailFromLog(datetime target_date, string sig, string title)
{
    string target_date_str = ConvertFormattedDate(target_date);
    string logpath = StringFormat("Logs/%s.log", target_date_str);

    if (!FileIsExist(logpath)) {
        PrintWarn(StringFormat("指定日のログファイルが存在しない, filepath: %s", logpath));
        return 0;
    }

    string split_sig[];
    int sig_num = StringSplit(sig, comma, split_sig);
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
    while(!FileIsEnding(filehandle)) {
        string line = FileReadString(filehandle);
        string line_seg[];
        int line_seg_num = StringSplit(line, tab, line_seg);
        if (line_seg_num != LOG_LINE_TAB_NUM) {
            continue;
        }

        string trade_info = line_seg[3];
        if (StringFind(trade_info, expertName) == -1) continue;
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
    FileClose(filehandle);
    if (mail_body == "") return 1;

    string mail_title = StringFormat("%s_%s", title, target_date_str);
    string mail_header = StringFormat("ClientName: %s\nTradeMode: %s\nExpertName: %s\nSymbol: %s:%s", accountClientName, accountTradeMode, expertName, Symbol(), PeriodToStr(Period()));
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
int MyLogHandler::DeleteOlderLogFile(datetime target_date)
{
    string target_date_str = ConvertFormattedDate(target_date);
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