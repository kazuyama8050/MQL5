#include <Object.mqh>

#define DEFAULT_FILE_CODE_TYPE 932
#define PRICE_DIFF_MEAN_FILEPATH "Conf\\price_diff_mean.tsv"
#define PRICE_DIFF_MEAN_COLUMN_NUM 2
#define TSV_SEPARATE_STRING "\t"
#define CSV_SEPARATE_STRING ","

struct FileHandlerSetting
{
    string filepath;
    int file_flag;
    short separate_string;
    uint code_type;
};

class MyFileHandler {
    public:
        FileHandlerSetting file_handler_setting;
    public:
        MyFileHandler(string filepath, int file_flag, short separate_string, int code_type = DEFAULT_FILE_CODE_TYPE);
        ~MyFileHandler();
        string MyFileHandler::GetFilepath();
        bool MyFileHandler::IsExistFilrpath();
        int MyFileHandler::CreateFileHandler();
        int MyFileHandler::GetFileType();
        short MyFileHandler::GetSeparateString();
        uint MyFileHandler::GetCodeType();
        
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MyFileHandler::MyFileHandler(string filepath, int file_flag, short separate_string, int code_type = DEFAULT_FILE_CODE_TYPE)
{
    file_handler_setting.filepath = filepath;
    file_handler_setting.file_flag = file_flag;
    file_handler_setting.separate_string = separate_string;
    file_handler_setting.code_type = code_type;

}
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MyFileHandler::~MyFileHandler()
{
}

string MyFileHandler::GetFilepath() {
    return file_handler_setting.filepath;
}

bool MyFileHandler::IsExistFilrpath() {
    if (FileIsExist(file_handler_setting.filepath)) {
        return false;
    }
    return true;
}

int MyFileHandler::CreateFileHandler() {
    // PrintFormat("separate=%s",file_handler_setting.separate_string);
    // string filename="Conf\\price_diff_mean.tsv";
    // int file_handle = FileOpen(filename, FILE_READ|FILE_WRITE, '\t', 932);
    int file_handle = FileOpen(file_handler_setting.filepath, file_handler_setting.file_flag, "\t", file_handler_setting.code_type);
    if (file_handle == INVALID_HANDLE) {
        PrintFormat("ファイルハンドラの作成に失敗  ファイルパス=%s, ファイル利用種類=%d 区切り文字=%s, 文字コード=%d",
        file_handler_setting.filepath, file_handler_setting.file_flag, file_handler_setting.separate_string, file_handler_setting.code_type);
        return 0;
    }

    return file_handle;
}

int MyFileHandler::GetFileType() {
    return file_handler_setting.file_flag;
}

short MyFileHandler::GetSeparateString() {
    return file_handler_setting.separate_string;
}

uint MyFileHandler::GetCodeType() {
    return file_handler_setting.code_type;
}