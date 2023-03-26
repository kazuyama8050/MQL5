#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include <MyInclude\MyAccount\MyAccountInfo.mqh>
#include "include/ExpertIma.mqh"
#import "Trade.ex5"
    int PrintTradeResponseMessage(MqlTradeResult &order_response);
#import

#define MAGIC_NUMBER_TEST = 123456;

static int ExpertIma::slow_ima_handle;
static int ExpertIma::fast_ima_handle;
static int ExpertIma::trade_error_cnt = 0;
static double slow_ma[];
static double fast_ma[];
int ma_cnt = 0;

MyAccountInfo myAccountInfo;
ExpertIma expertIma;


bool ExpertIma::TestPrint(string prt) {
    PrintFormat("%s", prt);
    return true;
}

int ExpertIma::ImaIndicator(
                            string symbol,
                            ENUM_TIMEFRAMES period, 
                            int ma_period, 
                            int ma_shift, 
                            ENUM_MA_METHOD ma_method, 
                            ENUM_APPLIED_PRICE applied_price
                            )
{
    int m_ima_handle=iMA(symbol,period,ma_period,ma_shift,ma_method,applied_price);
    if (m_ima_handle == INVALID_HANDLE) {
        PrintFormat("Failed To Create IMA Handle, symbol=%s, error code=%d", symbol, GetLastError());
        return false;
    }
    string short_name=StringFormat("iMA(%s/%s, %d, %d, %s, %s)",
                            symbol,EnumToString(period),
                            ma_period, ma_shift,EnumToString(ma_method),
                            EnumToString(applied_price));

    IndicatorSetString(INDICATOR_SHORTNAME,short_name);
    Print(short_name);

    return m_ima_handle;
}

bool ExpertIma::CreateTradeRequest(MqlTradeRequest &request, int order) {
    //--- リクエストのパラメータ
    request.action = TRADE_ACTION_DEAL; //　取引操作タイプ
    request.symbol = Symbol(); // シンボル
    request.volume = 0.01; // 0.1ロットのボリューム（取引数量）
    request.deviation = 5; // 価格からの許容偏差
    // request.magic = 1111; // 注文のMagicNumber（同一MT内でのEA識別）
    
    // あとはシグナルに重みをつけて取引数量を操作するとかはやりたい
    if (order > 0) {  // 買い注文
        request.type = ORDER_TYPE_BUY; // 注文タイプ（参考：https://www.mql5.com/ja/docs/constants/tradingconstants/orderproperties）
        request.price = SymbolInfoDouble(Symbol(),SYMBOL_ASK); // 発注価格（参考：https://www.mql5.com/ja/docs/constants/environment_state/marketinfoconstants#enum_symbol_info_double）
    } else if (order < 0) {  // 売り注文
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    } else {
        return false;
    }
    return true;
}

bool ExpertIma::TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response) {
    //--- リクエストの送信
    if(!OrderSend(trade_request,order_response)) {
        PrintFormat("OrderSend error %d",GetLastError());
    }

    if (!PrintTradeResponseMessage(order_response)) {
        return false;
    }
    
    return true;
}

int ExpertIma::EntrySignal(double &slow_ma_list[], double &fast_ma_list[]) {
    int ret = 0;

    //買いシグナル ゴールデンクロス
    if (fast_ma_list[2] <= slow_ma_list[2] && fast_ma_list[1] > slow_ma_list[1]) {
        ret = 1;
        PrintFormat("買いシグナル発火、fast_ma2=%f <= slow_ma2=%f、fast_ma1=%f > slow_ma1=%f", fast_ma_list[2], slow_ma_list[2], fast_ma_list[1], slow_ma_list[1]);
    }
    //売りシグナル デッドクロス
    if (fast_ma_list[2] >= slow_ma_list[2] && fast_ma_list[1] < slow_ma_list[1]) {
        ret = -1;
        PrintFormat("売りシグナル発火、fast_ma2=%f >= slow_ma2=%f、fast_ma1=%f < slow_ma1=%f", fast_ma_list[2], slow_ma_list[2], fast_ma_list[1], slow_ma_list[1]);
    }

    return ret;
}

bool ExpertIma::MainLoop() {
    bool can_trade = true;
    CopyBuffer(slow_ima_handle, 0, 0, 3, slow_ma);
    CopyBuffer(fast_ima_handle, 0, 0, 3, fast_ma);

    // 仕掛けシグナル
    int ma_signal_ret = expertIma.EntrySignal(slow_ma, fast_ma);

    // 注文
    if (ma_signal_ret != 0) {
        //初期化
        MqlTradeRequest trade_request={};
        MqlTradeResult trade_result={};

        if (!expertIma.CreateTradeRequest(trade_request, ma_signal_ret)) {
            Print("注文リクエストの生成に失敗しました。");
            can_trade = false;
        }

        // 証拠金残高の確認
        if (!myAccountInfo.CheckForTrade(trade_request)) {
            can_trade = false;
        }

        if (can_trade) {
            if (!expertIma.TradeOrder(trade_request, trade_result)) {
                Print("注文リクエストに失敗しました。");
                ExpertIma::trade_error_cnt += 1;
            }
        }
    }

    Sleep(10000); // 10秒スリープ
    return true;
}

void OnInit() {
    bool test = expertIma.TestPrint("Start");
    PrintTradeResponseMessage(result);

    ExpertIma::slow_ima_handle = expertIma.ImaIndicator(_Symbol, PERIOD_M5, 25, 0, MODE_SMA, PRICE_CLOSE);
    ExpertIma::fast_ima_handle = expertIma.ImaIndicator(_Symbol, PERIOD_M5, 75, 0, MODE_SMA, PRICE_CLOSE);
    ArraySetAsSeries(slow_ma, true);
    ArraySetAsSeries(fast_ma, true);
}

void OnTick() {
    if (!expertIma.MainLoop()) {
        Alert("予期せぬエラーが発生しました。");
        ExpertRemove();
        return;
    }
}
