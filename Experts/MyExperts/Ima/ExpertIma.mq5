#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include <Math\Stat\Math.mqh>
#include <MyInclude\MyAccount\MyAccountInfo.mqh>
#include <MyInclude\MyTrade\MyLossCutTrade.mqh>
#include <MyInclude\MyTechnical\MyMovingAverage.mqh>
#include <MyInclude\MyCommon\MyDatetime.mqh>
#include <Arrays\ArrayLong.mqh>
#include "include/ExpertIma.mqh"
#import "Trade.ex5"
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    double GetTotalSettlementProfit();
#import
#import "Indicator.ex5"
    int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetPriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
#import
#import "Math.ex5"
    double MathMeanForLong(const CArrayLong &array);
#import
#import "Common.ex5"
    void ForceStopEa();
#import

const double loss_cut_line = 0.05;  //損切りライン

static int ExpertIma::short_ima_handle;
static int ExpertIma::long_ima_handle;
static int ExpertIma::trade_error_cnt = 0;
static int ExpertIma::loss_cut_total_num = 0;
static datetime ExpertIma::ma_trade_last_datetime;
static ulong ExpertIma::ma_trade_last_position_ticket;
static int ExpertIma::ma_trade_num = 0;
static int ExpertIma::ma_settlement_num = 0;
static int MyMovingAverage::ma_trade_loss_cnt = 0;
static double short_ma[];  //短期移動平均を格納する配列
static double long_ma[];  //長期移動平均を格納する配列
int ma_cnt = 0;

MyAccountInfo myAccountInfo;
MyLossCutTrade myLossCutTrade;
MyMovingAverage myMovingAverage;
ExpertIma expertIma;

int ExpertIma::PrintTimerReport() {
    PrintFormat("移動平均トレードによる売買回数: %d回、損切り回数：%d", ExpertIma::ma_trade_num, MyMovingAverage::ma_trade_loss_cnt);
    PrintFormat("移動平均トレードによる騙し判定：、%d回、%f％", ExpertIma::ma_settlement_num, (ExpertIma::ma_settlement_num / ExpertIma::ma_trade_num * 100));
    PrintFormat("強制決済回数: %d", ExpertIma::loss_cut_total_num);
    PrintFormat("注文取引失敗回数: %d", ExpertIma::trade_error_cnt);
    double total_profit = GetTotalSettlementProfit();
    PrintFormat("現在までの累積損益：%f円", total_profit);
    return 1;
}

bool ExpertIma::CreateTradeRequest(MqlTradeRequest &request, double signal) {
    if (signal == 0) {return false;}
    double volume_deveation = 1.0;

    //--- リクエストのパラメータ
    request.action = TRADE_ACTION_DEAL; //　取引操作タイプ
    request.symbol = Symbol(); // シンボル
    request.deviation = DEFAULT_TRADE_ACTION_DEAL; // 価格からの許容偏差
    request.magic = MAGIC_NUMBER; // 注文のMagicNumber（同一MT内でのEA識別）
    request.comment = "移動平均によるシグナル検知";
    
    // 直近のボリュームリストを取得（チャート時間軸 × 10）
    CArrayLong volume_list;
    GetVolumeList(volume_list, Symbol(), COMMON_PERIOD, 10);
    if (volume_list.Total() > 0) {
        double volume_mean = MathMeanForLong(volume_list);
        volume_deveation = 1 + (volume_list.At(0) / volume_mean);
    }
    //デフォルトボリュームに直近ボリューム数を考慮した重み付与
    request.volume = MathRound(DEFAULT_VOLUME * volume_deveation, 2); //小数点2以下で丸める

    if (signal > 0) {  // 買い注文
        request.type = ORDER_TYPE_BUY; // 注文タイプ（参考：https://www.mql5.com/ja/docs/constants/tradingconstants/orderproperties）
        request.price = SymbolInfoDouble(Symbol(),SYMBOL_ASK); // 発注価格（参考：https://www.mql5.com/ja/docs/constants/environment_state/marketinfoconstants#enum_symbol_info_double）
    } else if (signal < 0) {  // 売り注文
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    }
    return true;
}

int ExpertIma::MaTrade() {
    bool can_trade = true;
    CopyBuffer(short_ima_handle, 0, 0, 10, short_ma);
    CopyBuffer(long_ima_handle, 0, 0, 10, long_ma);

    // 直近の価格リストを取得（チャート時間軸 × 10）
    CArrayDouble price_list;
    GetPriceList(price_list, Symbol(), COMMON_PERIOD, 10);

    // 仕掛けシグナル
    double ma_signal_ret = myMovingAverage.EntrySignalNormal(short_ma, long_ma, price_list);

    // 仕掛けシグナル判定出ない時はトレンドを読み取って決済判定
    if (ma_signal_ret == 0) {
        if (myMovingAverage.SettlementTradeByMaTrendSignal(short_ma, 2, MAGIC_NUMBER)) {
            // ExpertIma::ma_settlement_num += 1;
        }
    }

    // 注文
    if (ma_signal_ret != 0) {

        //ポジション決済
        ENUM_POSITION_TYPE signal_position_type;
        if (ma_signal_ret > 0) {
            signal_position_type = POSITION_TYPE_BUY;
        } else {
            signal_position_type = POSITION_TYPE_SELL;
        }
        if (myMovingAverage.SettlementTradeByMaSignal(signal_position_type, MAGIC_NUMBER)) {
            // ExpertIma::ma_settlement_num += 1;
        }

        //注文
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

            ExpertIma::ma_trade_num += 1;
            ExpertIma::ma_trade_last_datetime = TimeLocal();
            ExpertIma::ma_trade_last_position_ticket = PositionGetTicket(PositionsTotal() - 1);
        }
    }
    return 1;
}

bool ExpertIma::MainLoop() {
     datetime check_ma_datetime = TimeLocal();
    // 移動平均トレード

    // 前回移動平均トレードから30分未満の場合、騙し判定出なかったか監視する
    if (ExpertIma::ma_trade_last_datetime != NULL && ExpertIma::ma_trade_last_datetime <= check_ma_datetime - HALF_HOUR_DATETIME) {
        if (myMovingAverage.CheckAfterMaTrade(ExpertIma::ma_trade_last_position_ticket)) {
            ExpertIma::ma_settlement_num += 1;
        }
    }
    // 前回移動平均トレードから1時間以上経過していること
    if (ExpertIma::ma_trade_last_datetime == NULL || ExpertIma::ma_trade_last_datetime <= check_ma_datetime - ONE_HOUR_DATETIME) {
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

    ExpertIma::short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, COMMON_PERIOD, 25, 0, MODE_SMA, PRICE_CLOSE);
    ExpertIma::long_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, COMMON_PERIOD, 75, 0, MODE_SMA, PRICE_CLOSE);
    ArraySetAsSeries(short_ma, true);
    ArraySetAsSeries(long_ma, true);
}

void OnTick() {
    if (!expertIma.MainLoop()) {
        ForceStopEa();
        return;
    }
}

void OnTimer() {
    expertIma.PrintTimerReport();
}

void OnDeinit() {
    expertIma.PrintTimerReport();
    Print("End!!");
    EventKillTimer();
}
