/**
 * 
 * 検証用
 * 
**/

#include <Object.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Trade\Trade.mqh>
#include <Files\File.mqh>

void OnInit() {
    string filepath = "Logs/Martingale/test.log";
    if (FileIsExist(filepath)) {
        Print("ファイルが存在する");
    } else {
        Print("ファイルが存在しない");
        int filehandle = FileOpen(filepath, FILE_WRITE|FILE_TXT);
        if (filehandle == INVALID_HANDLE) {
            Print("ファイルが開けない");
        }
        FileWrite(filehandle, "testtest  testtes\ntesttest");
        FileClose(filehandle);
    }

    int filehandle = FileOpen(filepath, FILE_WRITE|FILE_TXT);
    if (filehandle == INVALID_HANDLE) {
        Print("ファイルが開けない");
    }
    FileWrite(filehandle, "testtest  testtes\ntesttest");
    FileClose(filehandle);

    long fillPolicy=SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);

    Print(fillPolicy);

}

void OnTick() {

    Sleep(10000 * 6 * 15);
}