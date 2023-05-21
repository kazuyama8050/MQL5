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

#include <MyInclude\MyTechnical\MyReversalSign.mqh>
#include <MyInclude\MyTechnical\MyMovingAverage.mqh>

#import "Math.ex5"
    double MathMeanForDouble(const CArrayDouble &array);
    double MathNormalizeDouble(const double target, const double &array[]);
#import
#import "Indicator.ex5"
    int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
#import
#import "Trade.ex5"
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    double GetTotalSettlementProfit();
#import

input int shift=0;
#define MAGIC_NUMBER_TEST = 123456;

static maTradeHistory MyMovingAverage::ma_trade_history_list[];
static int MyMovingAverage::ma_trade_loss_cnt = 0;

CFile cFile;
MyReversalSign myReversalSign;
MyMovingAverage myMovingAverage;


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
    GetClosePriceList(price_list, Symbol(), PERIOD_M15, 10);

    for (int i=0;i<price_list.Total();i++) {
        PrintFormat("price[%d]=%f", i, price_list.At(i));
    }
    
}

void OnInit() {
    // tickごとの価格差平均値算出
    // PrintPriceDiffMean(PERIOD_M15, 5000);
    // PrintPriceDiffMean(PERIOD_M15, 5000);
    // PrintVolumeList();
    // PrintPriceList();

    // string filename="Conf\\price_diff_mean.tsv";
    // int fileHandle = FileOpen(filename, FILE_READ|FILE_WRITE, '\t', 932);
    // Print(FileIsExist(filename));

    // if (fileHandle == INVALID_HANDLE) {
    //     Print("Error File Open");
    // }
    // PrintFormat("size=%d", FileSize(fileHandle));

    // string BuySignal;

    // while(!FileIsEnding(fileHandle)) {
    //     BuySignal=FileReadString(fileHandle);
    //     // Print(BuySignal);
    // }

    // FileWrite(fileHandle, IntegerToString(PERIOD_M15) + "\t0.065");
    
    // FileClose(fileHandle);

    // int short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 25, 0, MODE_SMA, PRICE_CLOSE);
    // double short_ma[];
    // ArraySetAsSeries(short_ma, true);
    // CopyBuffer(short_ima_handle, 0, 0, 10, short_ma);

    // for (int i = 9;i >= 0;i--) {
    //     double val = MathNormalizeDouble(short_ma[i], short_ma);
    //     PrintFormat("val=%f, normalize_val=%f", short_ma[i], val);
    // }

    int too_short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 5, 0, MODE_SMA, PRICE_CLOSE);
    int short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 25, 0, MODE_SMA, PRICE_CLOSE);
    int middle_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 75, 0, MODE_SMA, PRICE_CLOSE);
    double too_short_ma[];
    double short_ma[];
    double middle_ma[];
    ArraySetAsSeries(too_short_ma, true);
    ArraySetAsSeries(short_ma, true);
    ArraySetAsSeries(middle_ma, true);
    CopyBuffer(too_short_ima_handle, 0, 0, 20, too_short_ma);
    CopyBuffer(short_ima_handle, 0, 0, 20, short_ma);
    CopyBuffer(middle_ima_handle, 0, 0, 20, middle_ma);
    myMovingAverage.IsBoxTrend(short_ma, 10, 0.03);


}

void OnTick() {
    double reversal_sign = myReversalSign.CheckReversalSignByCurrentMarket(Symbol(),PERIOD_M15 , 7);

    int too_short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 5, 0, MODE_SMA, PRICE_CLOSE);
    int short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 25, 0, MODE_SMA, PRICE_CLOSE);
    int middle_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 75, 0, MODE_SMA, PRICE_CLOSE);
    double too_short_ma[];
    double short_ma[];
    double middle_ma[];
    ArraySetAsSeries(too_short_ma, true);
    ArraySetAsSeries(short_ma, true);
    ArraySetAsSeries(middle_ma, true);
    CopyBuffer(too_short_ima_handle, 0, 0, 20, too_short_ma);
    CopyBuffer(short_ima_handle, 0, 0, 20, short_ma);
    CopyBuffer(middle_ima_handle, 0, 0, 20, middle_ma);

    if (myMovingAverage.IsBoxTrend(short_ma, 10, 0.03) || myMovingAverage.IsBoxTrend(middle_ma, 10, 0.004)) {
        MqlTradeRequest trade_request={};
        MqlTradeResult trade_result={};

        trade_request.action = TRADE_ACTION_DEAL; //　取引操作タイプ
        trade_request.symbol = Symbol(); // シンボル
        trade_request.deviation = 5; // 価格からの許容偏差
        trade_request.volume = 0.01;
        trade_request.type = ORDER_TYPE_SELL;
        trade_request.price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
        TradeOrder(trade_request, trade_result);
        Print("OKOKOK");
    }


    

    Sleep(10000 * 6 * 15);
}