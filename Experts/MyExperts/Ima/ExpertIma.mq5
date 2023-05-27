#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include <Tools\DateTime.mqh>
#include <Math\Stat\Math.mqh>
#include <MyInclude\MyAccount\MyAccountInfo.mqh>
#include <MyInclude\MyTrade\MyLossCutTrade.mqh>
#include <MyInclude\MyTechnical\MyMovingAverage.mqh>
#include <MyInclude\MyTechnical\MyReversalSign.mqh>
#include <MyInclude\MyFundamental\MyCalendarEvent.mqh>
#include <MyInclude\MyCommon\MyDatetime.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\List.mqh>
#include "include/ExpertIma.mqh"
#import "Trade.ex5"
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    double GetTotalSettlementProfit();
#import
#import "Indicator.ex5"
    int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
#import
#import "Math.ex5"
    double MathMeanForLong(const CArrayLong &array);
    double MathMeanForDouble(const CArrayDouble &array);
    double MathDivide(const int molec, const int denom);
#import
#import "Common.ex5"
    void ForceStopEa();
#import
#import "CalendarEvent.ex5"
    int GetCalendarValueByCountries(MqlCalendarValue &mql_calendar_value_list[], const string &target_country_list[], datetime fromDatetime, datetime toDatetime);
    int GetCalendarEventByEventId(MqlCalendarEvent &mql_calendar_event, ulong event_id);
#import
#import "Datetime.ex5"
    datetime PlusDayForDatetime(datetime target_datetime, uint exchange_day);
    datetime PlusMinutesForDatetime(datetime target_datetime, uint exchange_minutes);
#import

input group "ロジック実行許可有無"
input bool is_use_box_trend_checker_input = true;
input bool is_use_rapid_trend_change_checker_input = true;

input group "ロジック閾値"
input double force_loss_cut_line_input = 0.05;
input double ma_deception_loss_cut_line_input = 0.03;

#define DEFAULT_FORCE_LOSS_CUT_LINE force_loss_cut_line_input
#define MA_DECEPTION_ALLOWED_PERCENTAGE ma_deception_loss_cut_line_input  //移動平均トレードの騙し判定許容パーセンテージ


input group "各種デフォルト値"
sinput double default_order_price_input = 0.01;

#define DEFAULT_VOLUME default_order_price_input  //デフォルト注文ボリューム


input group "移動平均トレンド判定"
input double too_short_ma_standard_deviation_value_for_rapid_change = 0.2;
input double short_ma_standard_deviation_value_for_box_trend = 0.04;
input double middle_ma_standard_deviation_value_for_box_trend = 0.05;
input double short_ma_standard_deviation_value_for_rapid_change = 0.045;

input group "経済指標イベント"
input ENUM_CALENDAR_EVENT_IMPORTANCE default_non_trade_calendar_event_importance_level = CALENDAR_IMPORTANCE_HIGH;
input int default_non_trade_minutes_by_calendar_event = 30; 

#define TOO_SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_RAPID_CHANGE too_short_ma_standard_deviation_value_for_rapid_change
#define SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_BOX_TREND short_ma_standard_deviation_value_for_box_trend
#define MIDDLE_MA_STANDARD_DEVIATION_VALUE_FOR_BOX_TREND middle_ma_standard_deviation_value_for_box_trend
#define SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_RAPID_CHANGE short_ma_standard_deviation_value_for_rapid_change

static int ExpertIma::too_short_ima_handle;
static int ExpertIma::short_ima_handle;
static int ExpertIma::middle_ima_handle;
static int ExpertIma::long_ima_handle;
static int MyMovingAverage::ma_trade_loss_cnt = 0;
static double too_short_ma[];  //超短期移動平均を格納する配列
static double short_ma[];  //短期移動平均を格納する配列
static double middle_ma[];  //中期移動平均を格納する配列
static double long_ma[];  //長期移動平均を格納する配列

static MaLastTradeStruct ExpertIma::ma_last_trade_struct;
static MaTradeAggregatorStruct ExpertIma::ma_trade_aggregator_struct;
static TradeAggregatorStruct ExpertIma::trade_aggregator_struct;

static maTradeHistory MyMovingAverage::ma_trade_history_list[];

string target_country_list[2] = {"US", "JP"};

MyAccountInfo myAccountInfo;
MyLossCutTrade myLossCutTrade;
MyMovingAverage myMovingAverage;
MyReversalSign myReversalSign;
ExpertIma expertIma;


/** 経済指標イベントから非推奨取引日かどうかチェック
 * 引数1: MyCalendarEventクラスの配列
 * 引数2: イベントの重要レベル（ENUM_CALENDAR_EVENT_IMPORTANCE（https://www.mql5.com/ja/docs/constants/structures/mqlcalendar#enum_calendar_event_importance））
 * 引数3: 対象日時（現在から対象日時）
 * return bool
**/
bool ExpertIma::CheckNonTradeDatetime(MyCalendarEvent &calendar_event_list[], ENUM_CALENDAR_EVENT_IMPORTANCE event_importance, datetime target_datetime) {
    if (ArraySize(calendar_event_list) < 1) {
        return false;
    }

    for (int i = 0;i< ArraySize(calendar_event_list);i++) {        
        if (calendar_event_list[i].GetEventImportance() < event_importance || !calendar_event_list[i].CanGetEventDatetime()) {
            continue;
        }

        if (calendar_event_list[i].GetEventDatetime() <= target_datetime) {
            return true;
        }

    }
    return false;
}

/** 経済指標カレンダーを取得
 * 引数1: MyCalendarEventクラスの配列
 * return int 取得数
**/
int ExpertIma::GetMyCalendarEvent(MyCalendarEvent &calendar_event_list[]) {
    ArrayFree(calendar_event_list);
    datetime current_datetime = TimeTradeServer();  //現在の日付（サーバ時間）
    datetime next_datetime = PlusDayForDatetime(current_datetime, 1);  // 現在から一日後

    MqlCalendarValue mql_calendar_value_list[];
    if (GetCalendarValueByCountries(mql_calendar_value_list, target_country_list, current_datetime, next_datetime)) {
        for (int i = 0;i < ArraySize(mql_calendar_value_list);i++) {
            MqlCalendarEvent mql_calendar_event;
            if (!GetCalendarEventByEventId(mql_calendar_event, mql_calendar_value_list[i].event_id)) {
                continue;
            }

            int my_calendar_event_cnt = ArraySize(calendar_event_list);
            ArrayResize(calendar_event_list, my_calendar_event_cnt + 1);
            MyCalendarEvent myCalendarEvent(mql_calendar_event, mql_calendar_value_list[i]);
            calendar_event_list[i] = myCalendarEvent;
        }
        
    }

    return ArraySize(calendar_event_list);
}

int ExpertIma::PrintTimerReport() {
    PrintFormat("移動平均トレードによる売買回数: %d回、損切り回数：%d", ExpertIma::ma_trade_aggregator_struct.trade_num, MyMovingAverage::ma_trade_loss_cnt);
    PrintFormat("移動平均トレードによる騙し判定：%d回、%f％",
                ExpertIma::ma_trade_aggregator_struct.settlement_num_by_deception, 
                (MathDivide(ExpertIma::ma_trade_aggregator_struct.settlement_num_by_deception, ExpertIma::ma_trade_aggregator_struct.trade_num) * 100));
    PrintFormat("移動平均トレードのトレンド変化による決済回数:%d回、%f％", ExpertIma::ma_trade_aggregator_struct.settlement_num_by_trend_checker, 
                (MathDivide(ExpertIma::ma_trade_aggregator_struct.settlement_num_by_trend_checker, ExpertIma::ma_trade_aggregator_struct.trade_num) * 100));
    PrintFormat("移動平均トレードのシグナル検知による決済回数:%d回、%f％", ExpertIma::ma_trade_aggregator_struct.settlement_num_by_ma_signal, 
                (MathDivide(ExpertIma::ma_trade_aggregator_struct.settlement_num_by_ma_signal, ExpertIma::ma_trade_aggregator_struct.trade_num) * 100));
    PrintFormat("強制決済回数: %d", ExpertIma::trade_aggregator_struct.loss_cut_total_num);
    PrintFormat("注文取引失敗回数: %d", ExpertIma::trade_aggregator_struct.trade_error_cnt);
    double total_profit = GetTotalSettlementProfit();
    PrintFormat("現在までの累積損益：%f円", total_profit);

    ExpertIma::PrintCurrentPriceAndMaDiffResult();
    
    return 1;
}

int ExpertIma::PrintCurrentPriceAndMaDiffResult() {
    //これより下では短期移動平均と売買価格の差の調査
    CArrayDouble current_price_and_ma_diff_list_by_loss;
    CArrayDouble current_price_and_ma_diff_list_by_benefit;
    CArrayDouble current_price_and_ma_diff_list_for_search;
    double current_price_and_ma_diff_max = 0;
    for (int i=0;i<101;i++) {
        current_price_and_ma_diff_list_for_search.Insert(0.0, i);
    }
    
    for (int i = 0;i < ArraySize(MyMovingAverage::ma_trade_history_list); i++) {
        if (MyMovingAverage::ma_trade_history_list[i].deal_ticket) {
            maTradeHistory ma_trade_history = MyMovingAverage::ma_trade_history_list[i];

            PrintFormat("ポジションチケット: %d, 短期移動平均と売買価格の差: %f, 決済チケット: %d, 損益: %f, 判定: %s", 
                        ma_trade_history.position_ticket, ma_trade_history.current_price_and_ma_diff, ma_trade_history.deal_ticket,
                        ma_trade_history.profit, (ma_trade_history.is_benefit) ? "利益" : "損失");
            if (ma_trade_history.profit > 100 || ma_trade_history.profit < 100) {
                if (ma_trade_history.is_benefit) {
                    current_price_and_ma_diff_list_by_benefit.Insert(ma_trade_history.current_price_and_ma_diff, current_price_and_ma_diff_list_by_benefit.Total());
                } else {
                    current_price_and_ma_diff_list_by_loss.Insert(ma_trade_history.current_price_and_ma_diff, current_price_and_ma_diff_list_by_loss.Total());
                }
            }

            if (current_price_and_ma_diff_max > ma_trade_history.profit) {
                current_price_and_ma_diff_max = ma_trade_history.profit;
            }

            for (int y = 0;y < 100;y++) {
                if (y < ma_trade_history.current_price_and_ma_diff * 100 && y + 1 > ma_trade_history.current_price_and_ma_diff * 100) {
                    current_price_and_ma_diff_list_for_search.Update(i,ma_trade_history.profit + current_price_and_ma_diff_list_for_search.At(y));
                    // PrintFormat("current_price_and_ma_diff_list_for_search[%d]: %f", y, current_price_and_ma_diff_list_for_search.At(y));
                }
            }
            if (100 < ma_trade_history.current_price_and_ma_diff * 100) {
                current_price_and_ma_diff_list_for_search.Update(100,ma_trade_history.profit + current_price_and_ma_diff_list_for_search.At(10));
                // PrintFormat("current_price_and_ma_diff_list_for_search[%d]: %f", 100, current_price_and_ma_diff_list_for_search.At(100));
            }
        }
    }

    for (int i=0;i<101;i++) {
        PrintFormat("%d帯: %f", i, current_price_and_ma_diff_list_for_search.At(i));
    }

    PrintFormat("利益確定時の短期移動平均と売買価格の差の平均: %f, 損失確定時の短期移動平均と売買価格の差の平均: %f", MathMeanForDouble(current_price_and_ma_diff_list_by_benefit), MathMeanForDouble(current_price_and_ma_diff_list_by_loss));
    PrintFormat("最大損失価格：%f", current_price_and_ma_diff_max);

    return 1;
}

/** ポジション全決済
 * return int 決済数
**/
int ExpertIma::SettlementTradeForAllPosition() {
    int total_position = PositionsTotal();
    int ret_cnt = 0;

    for (int i = 0; i < total_position; i++) {
        ulong  position_ticket = PositionGetTicket(i);

        MqlTradeRequest settlement_request={};
        MqlTradeResult settlement_result={};

        string comment = StringFormat("[決済]重要イベント間近、チケット=%d", position_ticket);

        if (!SettlementTrade(settlement_request, settlement_result, position_ticket, comment)) {
            continue;
        }

        ret_cnt += 1;

        double position_deal_profit = GetSettlementProfit(settlement_result.deal);
        if (position_deal_profit < 0.0) {
            MyMovingAverage::ma_trade_loss_cnt += 1;
        }
        myMovingAverage.SetMaTradeHistoryForSettlement(position_ticket, settlement_result.deal, position_deal_profit);
    }

    return ret_cnt;
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
        volume_deveation = volume_deveation + (volume_list.At(0) / volume_mean);
    }
    //デフォルトボリュームに直近ボリューム数を考慮した重み付与
    // request.volume = MathRound(DEFAULT_VOLUME * volume_deveation, 2); //小数点2以下で丸める
    request.volume = DEFAULT_VOLUME * MathAbs(signal);

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
    bool can_ma_trend_checker = true;
    CopyBuffer(too_short_ima_handle, 0, 0, 20, too_short_ma);
    CopyBuffer(short_ima_handle, 0, 0, 20, short_ma);
    CopyBuffer(middle_ima_handle, 0, 0, 20, middle_ma);
    CopyBuffer(long_ima_handle, 0, 0, 20, long_ma);

    // 直近の価格リストを取得（チャート時間軸 × 10）
    CArrayDouble price_list;
    GetClosePriceList(price_list, Symbol(), COMMON_PERIOD, 10);

    if (is_use_box_trend_checker_input) {
        /**
         * ボックス相場の場合は何もしない
         * → トレンドの見極めが難しいから
        **/
        if (myMovingAverage.IsBoxTrend(short_ma, 10, SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_BOX_TREND) && myMovingAverage.IsBoxTrend(middle_ma, 20, MIDDLE_MA_STANDARD_DEVIATION_VALUE_FOR_BOX_TREND)) {
            can_ma_trend_checker = false;
        }
    }

    if (is_use_rapid_trend_change_checker_input) {
        /**
         * 急激な相場変動の場合は何もしない
        **/
        if (myMovingAverage.IsRapidChange(too_short_ma, 2, TOO_SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_RAPID_CHANGE) || myMovingAverage.IsRapidChange(short_ma, 2, SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_RAPID_CHANGE)) {
            can_ma_trend_checker = false;
        }
    }

    double ma_signal_ret = 0.0;
    // 仕掛けシグナル
    if (can_ma_trend_checker) {
        ma_signal_ret = myMovingAverage.EntrySignalNormal(too_short_ma, short_ma, middle_ma, long_ma, price_list);
    }

    // 仕掛けシグナル判定出ない時
    if (ma_signal_ret == 0) {
        // トレンドを読み取って決済判定
        if (myMovingAverage.SettlementTradeByMaTrendSignal(short_ma, 5, MAGIC_NUMBER)) {
            ExpertIma::ma_trade_aggregator_struct.settlement_num_by_trend_checker += 1;
        }

        /** 
         * 長期間トレンドが継続している & 反転サインがある場合はトレンドにのっているポジションを決済する
        **/
        double short_ma_trend = myMovingAverage.CheckKeepTrendByMa(short_ma, TREND_CHECK_TERM, 1);
        double reversal_sign = myReversalSign.CheckReversalSignByCurrentMarket(Symbol(), COMMON_PERIOD, 7);

        // 長期上昇トレンド継続中 && 反転サイン
        if (short_ma_trend > 0 && reversal_sign > 0) {
            string settlement_comment = "[決済]上昇トレンド&反転サイン";
            if (myMovingAverage.SettlementTradeByMaSignal(POSITION_TYPE_BUY, MAGIC_NUMBER, settlement_comment)) {
                ExpertIma::ma_trade_aggregator_struct.settlement_num_by_trend_checker += 1;
            }
        }

        // 長期下降トレンド継続中 && 反転サイン
        if (short_ma_trend < 0 && reversal_sign < 0) {
            string settlement_comment = "[決済]下降トレンド&反転サイン";
            if (myMovingAverage.SettlementTradeByMaSignal(POSITION_TYPE_SELL, MAGIC_NUMBER, settlement_comment)) {
                ExpertIma::ma_trade_aggregator_struct.settlement_num_by_trend_checker += 1;
            }
        }
    }

    // 仕掛けシグナル発火
    if (ma_signal_ret != 0) {

        //ポジション決済
        ENUM_POSITION_TYPE signal_position_type;
        if (ma_signal_ret > 0) {
            signal_position_type = POSITION_TYPE_BUY;
        } else {
            signal_position_type = POSITION_TYPE_SELL;
        }
        string settlement_comment = "[決済]移動平均シグナル";
        if (myMovingAverage.SettlementTradeByMaSignal(signal_position_type, MAGIC_NUMBER, settlement_comment)) {
            ExpertIma::ma_trade_aggregator_struct.settlement_num_by_ma_signal += 1;
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
                ExpertIma::trade_aggregator_struct.trade_error_cnt += 1;
            } else {
                myMovingAverage.SetMaTradeHistoryForTrade(trade_result, price_list, short_ma);

                ExpertIma::ma_trade_aggregator_struct.trade_num += 1;
                ExpertIma::ma_last_trade_struct.last_datetime = TimeLocal();
                ExpertIma::ma_last_trade_struct.last_position_ticket = PositionGetTicket(PositionsTotal() - 1);
            }
        }
    }
    return 1;
}

bool ExpertIma::MainLoop() {
    // 経済指標カレンダーチェック
    if (ExpertIma::CheckNonTradeDatetime(expertIma.my_calendar_event_list, default_non_trade_calendar_event_importance_level, PlusMinutesForDatetime(TimeTradeServer(), default_non_trade_minutes_by_calendar_event))) {
        Print("重要イベント間近による非推奨取引日時");

        // ポジション全決済
        ExpertIma::SettlementTradeForAllPosition();

        Sleep(default_non_trade_minutes_by_calendar_event * 60 * 100);
        return true;
    }

     datetime check_ma_datetime = TimeLocal();
    // 移動平均トレード

    // 前回移動平均トレードから30分未満の場合、騙し判定出なかったか監視する
    if (ExpertIma::ma_last_trade_struct.last_datetime != NULL && ExpertIma::ma_last_trade_struct.last_datetime <= check_ma_datetime - HALF_HOUR_DATETIME) {
        if (myMovingAverage.CheckAfterMaTrade(ExpertIma::ma_last_trade_struct.last_position_ticket, MA_DECEPTION_ALLOWED_PERCENTAGE)) {
            ExpertIma::ma_trade_aggregator_struct.settlement_num_by_deception += 1;
        }
    }
    // 前回移動平均トレードから1時間以上経過していること
    if (ExpertIma::ma_last_trade_struct.last_datetime == NULL || ExpertIma::ma_last_trade_struct.last_datetime <= check_ma_datetime - ONE_HOUR_DATETIME) {
        ExpertIma::MaTrade();
    }

    //損切りライン確認 & 決済実行
    ExpertIma::trade_aggregator_struct.loss_cut_total_num += myLossCutTrade.ClosePositionByLossCutRule(DEFAULT_FORCE_LOSS_CUT_LINE);

    Sleep(10000); // 10秒スリープ
    return true;
}

void OnInit() {
    Print("Start!!");
    EventSetTimer(ONE_DATE_DATETIME); //1日間隔でタイマーイベントを呼び出す

    ExpertIma::too_short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 5, 0, MODE_SMA, PRICE_CLOSE);
    ExpertIma::short_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 25, 0, MODE_SMA, PRICE_CLOSE);
    ExpertIma::middle_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 75, 0, MODE_SMA, PRICE_CLOSE);
    ExpertIma::long_ima_handle = myMovingAverage.CreateMaIndicator(_Symbol, 0, 200, 0, MODE_SMA, PRICE_CLOSE);
    ArraySetAsSeries(too_short_ma, true);
    ArraySetAsSeries(short_ma, true);
    ArraySetAsSeries(middle_ma, true);
    ArraySetAsSeries(long_ma, true);

    ArrayFree(expertIma.my_calendar_event_list);
    expertIma.GetMyCalendarEvent(expertIma.my_calendar_event_list);

}

void OnTick() {
    if (!expertIma.MainLoop()) {
        ForceStopEa();
        return;
    }
}

void OnTimer() {
    ArrayFree(expertIma.my_calendar_event_list);
    expertIma.GetMyCalendarEvent(expertIma.my_calendar_event_list);
    expertIma.PrintTimerReport();
}

void OnDeinit() {
    expertIma.PrintTimerReport();
    Print("End!!");
    EventKillTimer();
}
