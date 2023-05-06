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

#import "Math.ex5"
    double MathMeanForDouble(const CArrayDouble &array);
#import
#import "Indicator.ex5"
    int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetPriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
#import

input int shift=0;
#define MAGIC_NUMBER_TEST = 123456;

CFile cFile;

/** tickごとの価格差平均値算出
 * 引数1: 時間軸
 * 引数2: 検証データ数
**/
void PrintPriceDiffMean(ENUM_TIMEFRAMES timeframe, int data_num) {
    CArrayDouble price_list;
    for (int i = 0; i <= data_num; i++) {
        price_list.Insert(iClose(Symbol(), timeframe, i), i);
    }
    
    double price_mean = MathMeanForDouble(price_list);

    double price_diff_mean = 0.0;

    for (int i = 0; i < price_list.Total() - 1; i++) {
        double price1 = price_list.At(i);
        double price2 = price_list.At(i + 1);
        double price_diff = MathAbs(price1 - price2);
        price_diff_mean += price_diff;
    }
    PrintFormat("tickごとの価格差平均値=%f", price_diff_mean / (price_list.Total() - 1));
}

void PrintVolumeList() {
    CArrayLong volume_list;
    GetVolumeList(volume_list, Symbol(), PERIOD_M15, 10);

    for (int i=0;i<volume_list.Total();i++) {
        PrintFormat("volume[%d]=%f", i, volume_list.At(i));
    }
    
}

void PrintPriceList() {
    CArrayDouble price_list;
    GetPriceList(price_list, Symbol(), PERIOD_M15, 10);

    for (int i=0;i<price_list.Total();i++) {
        PrintFormat("price[%d]=%f", i, price_list.At(i));
    }
    
}

void OnInit() {
    // tickごとの価格差平均値算出
    // PrintPriceDiffMean(PERIOD_M15, 5000);
    // PrintPriceDiffMean(PERIOD_M15, 5000);
    PrintVolumeList();
    PrintPriceList();

    string filename="Conf\\price_diff_mean.tsv";
    int fileHandle = FileOpen(filename, FILE_READ|FILE_WRITE, '\t', 932);
    Print(FileIsExist(filename));

    if (fileHandle == INVALID_HANDLE) {
        Print("Error File Open");
    }
    PrintFormat("size=%d", FileSize(fileHandle));

    string BuySignal;

    while(!FileIsEnding(fileHandle)) {
        BuySignal=FileReadString(fileHandle);
        // Print(BuySignal);
    }

    // FileWrite(fileHandle, IntegerToString(PERIOD_M15) + "\t0.065");
    
    FileClose(fileHandle);

    CArrayDouble price_list;
    GetPriceList(price_list, Symbol(), PERIOD_M15, 100000);
    CArrayLong volume_list;
    GetVolumeList(volume_list, Symbol(), PERIOD_M15, 100000);

    double volume_mean;

    for (int i=0;i<volume_list.Total();i++) {
        volume_mean += volume_list.At(i);
    }

    PrintFormat("volume_mean=%f", volume_mean / volume_list.Total());

}

void OnTick() {
    Print("Tick Start");

    CArrayDouble price_list;
    GetPriceList(price_list, Symbol(), PERIOD_M15, 10);
    CArrayLong volume_list;
    GetVolumeList(volume_list, Symbol(), PERIOD_M15, 10000);

    double volume_mean;

    for (int i=0;i<volume_list.Total();i++) {
        volume_mean += volume_list.At(i);
    }

    PrintFormat("volume_mean=%f", volume_mean / volume_list.Total());
}