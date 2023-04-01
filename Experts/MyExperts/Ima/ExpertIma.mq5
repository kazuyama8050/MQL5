#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include <MyInclude\MyAccount\MyAccountInfo.mqh>
#include <MyInclude\MyTrade\MyLossCutTrade.mqh>
#include <MyInclude\MyTechnical\MyMovingAverage.mqh>
#include "include/ExpertIma.mqh"
#import "Trade.ex5"
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
#import

#define MAGIC_NUMBER 123456
#define ONE_HOUR_DATETIME 3600
#define ONE_DATE_DATETIME 86400
const double loss_cut_line = 0.001;  //損切りライン

static int ExpertIma::slow_ima_handle;
static int ExpertIma::fast_ima_handle;
static int ExpertIma::trade_error_cnt = 0;
static int ExpertIma::loss_cut_total_num = 0;
static datetime ExpertIma::ma_trade_last_datetime;
static double slow_ma[];
static double fast_ma[];
int ma_cnt = 0;

MyAccountInfo myAccountInfo;
MyLossCutTrade myLossCutTrade;
MyMovingAverage myMovingAverage;
ExpertIma expertIma;

bool ExpertIma::CreateTradeRequest(MqlTradeRequest &request, double order) {
    //--- リクエストのパラメータ
    request.action = TRADE_ACTION_DEAL; //　取引操作タイプ
    request.symbol = Symbol(); // シンボル
    request.volume = 0.01; // 0.1ロットのボリューム（取引数量）
    request.deviation = 5; // 価格からの許容偏差
    // request.magic = MAGIC_NUMBER; // 注文のMagicNumber（同一MT内でのEA識別）
    
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

int ExpertIma::MaTrade() {
    bool can_trade = true;
    CopyBuffer(slow_ima_handle, 0, 0, 3, slow_ma);
    CopyBuffer(fast_ima_handle, 0, 0, 3, fast_ma);

    // 仕掛けシグナル
    double ma_signal_ret = myMovingAverage.EntrySignalNormal(slow_ma, fast_ma);

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
            if (!TradeOrder(trade_request, trade_result)) {
                ExpertIma::trade_error_cnt += 1;
            }

            ExpertIma::ma_trade_last_datetime = TimeLocal();
        }
    }
    return 1;
}

bool ExpertIma::MainLoop() {
    // 移動平均トレード
    // 前回移動平均トレードから1時間以上経過していること
    datetime check_ma_datetime = TimeLocal();
    if (ExpertIma::ma_trade_last_datetime <= check_ma_datetime - ONE_HOUR_DATETIME) {
        ExpertIma::MaTrade();
    }

    //損切りライン確認 & 決済実行
    ExpertIma::loss_cut_total_num += myLossCutTrade.ClosePositionByLossCutRule(loss_cut_line);

    Sleep(10000); // 10秒スリープ
    return true;
}

void OnInit() {
    Print("Start!!");
    EventSetTimer(ONE_DATE_DATETIME); //1日間隔でタイマーイベントを呼び出す

    ExpertIma::slow_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, PERIOD_M15, 25, 0, MODE_SMA, PRICE_CLOSE);
    ExpertIma::fast_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, PERIOD_M15, 75, 0, MODE_SMA, PRICE_CLOSE);
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

void OnTimer() {
    datetime watch_datetime = TimeLocal();
    PrintFormat("タイマーイベント起動 %s", TimeToString(watch_datetime));
    PrintFormat("強制決済回数: %d", ExpertIma::loss_cut_total_num);
    PrintFormat("注文取引失敗回数: %d", ExpertIma::trade_error_cnt);
}

void OnDeinit() {
    EventKillTimer();
}
