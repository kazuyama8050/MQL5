#include <Object.mqh>
#include <Files\File.mqh>

#import "MyLibraries/Datetime.ex5"
    string ConvertFormattedDate(datetime target_datetime);
    string ConvertDatetimeToString(datetime target_datetime);
#import

class MyLogHandler {
    public:
        string logDir;
        string expertName;
        string filePath;
        int logFileHandler;
    public:
        MyLogHandler::MyLogHandler(string log_dir, string expert_name);
        int MyLogHandler::SetLogFileHandler();
        int MyLogHandler::WriteLog(string log_string);

    private:
        int MyLogHandler::GetLogFileHandler();
        string MyLogHandler::CreateLogFilePath();
        int MyLogHandler::IsExistsLogFileOrCreate();
        
};

MyLogHandler::MyLogHandler(string log_dir, string expert_name) {
    logDir = log_dir;
    expertName = expert_name;
    filePath = MyLogHandler::CreateLogFilePath();
    logFileHandler = MyLogHandler::GetLogFileHandler();
}

// ログファイルを変更するときはこのメソッドを呼ぶ
int MyLogHandler::SetLogFileHandler() {
    filePath = MyLogHandler::CreateLogFilePath();
    logFileHandler = MyLogHandler::GetLogFileHandler();
    if (logFileHandler == INVALID_HANDLE) {
        return 0;
    }
    return 1;
}

int MyLogHandler::GetLogFileHandler() {
    if (!MyLogHandler::IsExistsLogFileOrCreate()) {
        return INVALID_HANDLE;
    }
    int filehandle = FileOpen(filePath, FILE_WRITE|FILE_TXT);
    if (filehandle == INVALID_HANDLE) {
        return INVALID_HANDLE;
    }
    return filehandle;
}

string MyLogHandler::CreateLogFilePath() {
    string formattedDate = ConvertFormattedDate(TimeCurrent());
    return logDir + "/" + expertName + "_" + formattedDate + ".log";
}


int MyLogHandler::IsExistsLogFileOrCreate() {
    if (FileIsExist(filePath)) {
        return 1;
    } else {
        int filehandle = FileOpen(filePath, FILE_WRITE|FILE_TXT);
        if (filehandle == INVALID_HANDLE) {
            return 0;
        }
        FileWrite(filehandle, "");
        FileClose(filehandle);
    }
    return 1;
}

int MyLogHandler::WriteLog(string log_string) {
    string log = StringFormat("%s\t%s\t%s\n", ConvertDatetimeToString(TimeCurrent()), expertName, log_string);
    FileWriteString(logFileHandler, log);
    return 1;
}