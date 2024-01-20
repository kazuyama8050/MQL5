#include <Object.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>
#include <MyInclude\MyTrade\MySymbolInfo.mqh>
#include <MyInclude\MyCommon\MyDatetime.mqh>
#include <MyInclude\MyAccount\MyAccountInfo.mqh>
#include <MyInclude\MyFile\MyLogHandler.mqh>
#include <MyInclude\MyTechnical\MyMovingAverage\MyMovingAverage.mqh>
#include "include/ExpertMartingale.mqh"

#import "MyLibraries/Trade.ex5"
    int GetPositionNumByTargetEa(string symbol, long magic_number);
    double GetAllPositionProfitByTargetEa(string symbol, long magic_number);
    double GetSettlementProfit(ulong deal_ticket);
    double GetTotalSettlementProfitByTargetEa(string symbol, long magic_number);
#import
#import "MyLibraries/Indicator.ex5"
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    double GetLatestClosePrice(string symbol, ENUM_TIMEFRAMES timeframe);
#import
#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintDebug(const string log_str);
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
#import

#import "MyLibraries/Datetime.ex5"
    datetime MinusDayForDatetime(datetime target_datetime, uint exchange_day);
    datetime MinusMinutesForDatetime(datetime target_datetime, uint exchange_minutes);
    int GetDayOfWeekFromDatetime(datetime target_datetime);
    int GetDateFromDatetime(datetime target_datetime) ;
#import

#import "MyLibraries/Math.ex5"
    double RoundToDecimal(double n, const int decimal_digits);
#import

input group "マーチンゲールロジック閾値"
input double MARTINGALE_PIPS = 0.2;  // 勝ち負け判定基準PIPS
input double RESTRICTED_TRADE_VOLUME = 0.1;  // 制限付きトレードのロット数閾値（次トレードがこのロット数を超える場合は制限付き判定）
input int ALL_SETTLEMENT_PIPS_DIFF = 4;  // 全決済判定PIPS差分の利益率増大閾値
input double INITIAL_VOLUME = 0.01;  // 初回トレードロット数
input double CLEAR_BASE_VOLUME = 10.0;  // このロット数はなるべく超えないようにポジション調整しながらロット数を減らす

input group "ロジック採用フラグ"
input bool IS_ACTIVE_CLEAR_LOT = false;  // ポジション調整実行フラグ
input bool IS_ACTIVE_RESTART = true;  // ポジション調整&リスタート実行フラグ

input group "初回トレード判定ロジック"
input int MA_PERIOD = 25;  // 移動平均期間
input ENUM_MA_METHOD MA_METHOD = MODE_SMA;  // 移動平均モード
input int MA_COMPARISON_RANGE = 3;  // 移動平均比較時間幅

input group "トレンド継続判定ロジック"
input int MA_PERIOD_FOR_TREND = 5;  // 移動平均期間
input ENUM_MA_METHOD MA_METHOD_FOR_TREND = MODE_SMA;  // 移動平均モード
input int MA_COMPARISON_RANGE_TREND = 5;  // 移動平均比較時間幅

input group "証拠金"
input int MARGIN_SAFE_LEVEL_RATIO = 2;  // マージンコールの何倍の証拠金維持率でアラートを出すか

input group "初期化ハンドル"
input bool IS_INIT_OF_POSITIONS_STRUCT = false;  // ポジション構造体初期化実施有無
input bool IS_INIT_OF_TRADE_ANALYST_STRUCT = false;  // トレード履歴構造体初期化実施有無
input bool IS_INIT_TRADE_ANALYSIS_STRUCY_ON_FIRST_DAY = false;  // トレード履歴構造体を月初に初期化するか

input group "外部シグナル"
input bool IS_FORCE_STOPPED = false;  // 次の全決済後にプロセスを終了させるフラグ

string EXPERT_NAME = "ExpertMartingale";

static TradeAnalysisStruct ExpertMartingale::trade_analysis_struct;
static PositionsStruct ExpertMartingale::positions_struct;
static long ExpertMartingale::magic_number;
// トレード回数がこの数を超えてくるとポジションロット数を減らすためのポジション調整をする
int CLEAR_BASE_TRADE_CNT = (int)MathCeil(MathLog(CLEAR_BASE_VOLUME / INITIAL_VOLUME) / MathLog(2.0));

static int main_loop_cnt = 0;
static uint main_loop_total_sec = 0;

CMyTrade myTrade;
CMySymbolInfo mySymbolInfo;
CMyAccountInfo myAccountInfo;
MyLogHandler myLogHandler(
    "ExpertMartingale",
    myAccountInfo.TradeModeDescription(),
    myAccountInfo.Name()
);



int ExpertMartingale::TradeOrder(int next_trade_flag) {
    double volume = ExpertMartingale::GetNextTradeVolume();
    string trade_comment = "売り";
    if (next_trade_flag == IS_BUYING) {
        trade_comment = "買い";
    }
    ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
    double price = 0.0;
    if (next_trade_flag == IS_BUYING) {  // 買い注文
        order_type = ORDER_TYPE_BUY;
        price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    } else if (next_trade_flag == IS_SELLING) {  // 売り注文
        order_type = ORDER_TYPE_SELL;
        price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    }
    const string comment = StringFormat("[%d回目]%s : %.2f * %.5f", ExpertMartingale::GetTradeNum()+1, trade_comment, volume, price);

    if (!myTrade.PositionOpen(Symbol(), order_type, volume, price, 0, 0, comment)) {
        return 0;
    }
    return 1;
}

int ExpertMartingale::OrderRetcode(bool is_open, bool all_settlement_flag = false) {
    uint retcode = myTrade.ResultRetcode();
    if (retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL) {
        string is_open_str = (is_open) ? "Open" : "Close";
        PrintNotice(StringFormat("ポジション %s comment: request=%s, result=%s", is_open_str, myTrade.RequestComment(), myTrade.ResultComment()));
        return 1;
    }
    if (retcode == TRADE_RETCODE_MARKET_CLOSED) {
        PrintWarn("市場閉鎖による取引失敗");
        Sleep(3600*60);  // 1時間スリープ
        return 2;
    }

    ExpertMartingale::PlusOrderErrorCount();
    if (all_settlement_flag == true) {
        return 0;
    }
    ExpertMartingale::SettlementAllPosition();
    PrintError("注文エラーのため全決済して異常終了");
    return 0;
}

int ExpertMartingale::MainLoop() {
    // ロジックバグ
    if (MathAbs(ExpertMartingale::GetBuyingNum() - ExpertMartingale::GetSellingNum()) > 1) {
        PrintError(StringFormat("ロジックバグ : ロング、ショートで交互にトレードされていない可能性あり, buying_num: %d, selling_num: %d", ExpertMartingale::GetBuyingNum(), ExpertMartingale::GetSellingNum()));
        return 0;
    }

    if (ExpertMartingale::GetTradeNum() != ExpertMartingale::GetPositionSize()) {
        PrintError(StringFormat("ロジックバグ : トレード記録が不正, recorded_trade_cnt: %d, real_trade_cnt: %d", ExpertMartingale::GetTradeNum(), ExpertMartingale::GetPositionSize()));
        return 0;
    }

    if (ExpertMartingale::GetPositionNum() > 0 && ExpertMartingale::GetInitTradeFlag() == IS_NOTRADE) {
        PrintError(StringFormat("ロジックバグ : 初回トレード記録が不正, position_num: %d", ExpertMartingale::GetPositionNum()));
        return 0;
    }

    double now_price = GetLatestClosePrice(Symbol(), PERIOD_M15);

    int next_trade_flag = ExpertMartingale::GetNextTradeFlag();
    int last_trade_flag = ExpertMartingale::SwitchTradeFlag(next_trade_flag);
    if (next_trade_flag != IS_BUYING && next_trade_flag != IS_SELLING) {
        PrintError(StringFormat("ロジックバグ : 次回トレードフラグが買い・売り以外, next_trade_flag: %d", next_trade_flag));
        return 0;
    }

    int position_cnt = ExpertMartingale::GetPositionNum();
    int trade_cnt = ExpertMartingale::GetTradeNum();
    if (position_cnt > 0 && ExpertMartingale::HasInitTradeFlag() == false) {
        PrintError(StringFormat("ロジックバグ : ポジション保有済みだが初期トレードフラグが未定義, position_cnt: %d, init_trade_flag: %d", position_cnt, ExpertMartingale::GetInitTradeFlag()));
    }


    // 保有ポジションがなく、強制停止シグナルがある場合は終了
    if (position_cnt == 0 && IS_FORCE_STOPPED) {
        ExpertMartingale::SettlementAllPosition();
        PrintNotice("強制終了シグナルを受け取り、ポジションなしのため全決済");
        ExpertMartingale::PrintTradeAnalysis();
        PrintNotice(StringFormat("Force Stopped Flag Thrown, so Finished ExpertMartingale, symbol: %s", Symbol()));
        ForceStopEa();
        return 1;
    }

    // トレード実績がない場合は初回トレード
    if (position_cnt == 0) {
        // 注文
        ExpertMartingale::TradeOrder(next_trade_flag);
        int order_retcode = ExpertMartingale::OrderRetcode(true);
        if (order_retcode == 0) {
            return 0;
        }
        if (order_retcode == 2) return 1;  // 市場閉鎖によりスキップ

        if (next_trade_flag == IS_BUYING) {
            ExpertMartingale::PlusBuyingNum();
        } else {
            ExpertMartingale::PlusSellingNum();
        }
        ExpertMartingale::PlusPositionNum();

        PositionStruct position_struct;
        ExpertMartingale::SetPositionStruct(
            position_struct,
            myTrade.ResultOrder(),
            next_trade_flag,
            myTrade.ResultPrice(),
            myTrade.ResultVolume(),
            TimeLocal()
        );
        ExpertMartingale::AddPosition(position_struct);
        ExpertMartingale::PlusMartingaleTradeCount();
        return 1;
    }

    // pips単位で利益が出ていれば全決済
    if (ExpertMartingale::IsRevenueBySegCalc(now_price, ExpertMartingale::GetAllSettlementPipsDiff())) {
        if (ExpertMartingale::IsShortTrendContinue(last_trade_flag)) {  // トレンド継続中ならば決済しない
            if (ExpertMartingale::GetAllSettlementBasePrice() == 0.0) {
                ExpertMartingale::SetAllSettlementBasePrice(now_price);
            }
            return 1;
        }

        double all_settlement_base_price = ExpertMartingale::GetAllSettlementBasePrice();
        if (all_settlement_base_price == 0.0) {
            ExpertMartingale::AddAllSettlementTrendLogicPriceDiff(0.0);
        } else {
            if (last_trade_flag == IS_BUYING) {
                ExpertMartingale::AddAllSettlementTrendLogicPriceDiff(now_price - all_settlement_base_price);
            } else {
                ExpertMartingale::AddAllSettlementTrendLogicPriceDiff(all_settlement_base_price - now_price);
            }
        }

        PrintNotice("PIPS単位で利益が出ているため全決済");
        if (ExpertMartingale::SettlementAllPosition() == 0) {
            PrintError("全決済異常エラーのため異常終了");
            return 0;
        }
        if (GetPositionNumByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber()) > 0) {
            PrintWarn(StringFormat("全決済後にポジションが残っている, total=%d", GetPositionNumByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber())));
        }
        ExpertMartingale::InitPositionsStruct();
        ExpertMartingale::SetInitialVolume(INITIAL_VOLUME);
        ExpertMartingale::SetMartingalePips(MARTINGALE_PIPS);
        return 1;
    }

    double next_seg_price = ExpertMartingale::CalcNextTradeSegPrice();  // 次のトレードの基準価格
    double next_trade_volume = ExpertMartingale::GetNextTradeVolume();  // 次のトレードロット数
    if ((next_trade_flag == IS_BUYING && next_seg_price <= ExpertMartingale::GetInitPrice()) ||
        (next_trade_flag == IS_SELLING && next_seg_price >= ExpertMartingale::GetInitPrice()))
    {
        PrintError(StringFormat("セグポイント計算にバグの可能性があるため終了. next_trade_flag: %d, next_seg_price: %.5f", next_trade_flag, next_seg_price));
        return 0;
    }

    // (リスタート済み && 利益が0を超える) || ((次回トレードロット数が指定ロット数を超える & 最新ポジショントレード日時が1日以前) & 利益が(初期ロット * 1ロット当たり取引数量 * 基準PIPS))の場合、全決済
    if ((ExpertMartingale::HasInitialProfit() && GetAllPositionProfitByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber()) > 0) ||
        (next_trade_volume >= RESTRICTED_TRADE_VOLUME && ExpertMartingale::GetLatestPositionTradeDatetime() < TimeLocal() - ONE_DATE_DATETIME) && 
        GetAllPositionProfitByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber()) > ExpertMartingale::GetInitialVolume() * mySymbolInfo.ContractSize() * ExpertMartingale::GetMartingalePips()
    ) {
        PrintNotice("ロット数多、1日以上経過、利益が出ているため全決済");
        if (ExpertMartingale::SettlementAllPosition() == 0) {
            PrintError("全決済異常エラーのため異常終了");
            return 0;
        }
        if (GetPositionNumByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber()) > 0) {
            PrintError(StringFormat("全決済後にポジションが残っている, total=%d", GetPositionNumByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber())));
            return 0;
        }
        ExpertMartingale::InitPositionsStruct();
        ExpertMartingale::SetInitialVolume(INITIAL_VOLUME);
        ExpertMartingale::SetMartingalePips(MARTINGALE_PIPS);
        return 1;
    }


    /** ポジション調整後リスタート
     * リスタートロジック実行フラグ：実行
     * 次回トレードロット数が指定ロット数を超える
     * リスタート済みの場合は、前回リスタート後にとったポジションのトレードフラグ と 最新トレードフラグ（今からリスタート後にとろうとしているポジションのトレードフラグ）が一致しない
     * 最新トレードが初期PIPS以上の利益幅がある & ポジション調整可能な場合
    **/
    if (IS_ACTIVE_RESTART && next_trade_volume >= CLEAR_BASE_VOLUME) {
        bool can_clear_lot_and_restart = false;
        if (last_trade_flag == IS_BUYING) {
            if (now_price >= ExpertMartingale::GetLatestPositionPrice() + MARTINGALE_PIPS) {
                can_clear_lot_and_restart = true;
            }
        }
        if (last_trade_flag == IS_SELLING) {
            if (now_price <= ExpertMartingale::GetLatestPositionPrice() - MARTINGALE_PIPS) {
                can_clear_lot_and_restart = true;
            }
        }
        if (ExpertMartingale::HasInitialProfit() && ExpertMartingale::SwitchTradeFlag(ExpertMartingale::GetInitTradeFlag()) == last_trade_flag) {
            can_clear_lot_and_restart = false;
        }
        
        if (can_clear_lot_and_restart && ExpertMartingale::IsCanClearLotRestart()) {
            if (!ExpertMartingale::ClearLot(2)) {
                ExpertMartingale::SettlementAllPosition();
                PrintError("ポジション調整後リスタート失敗のため全決済して異常終了");
                return 0;
            }

            
            if (ExpertMartingale::GetPositionNum() != 1) {
                PrintWarn(StringFormat("ロジックバグの可能性あり. 「ポジション調整&リスタート」の場合、ポジション調整終了直後はポジション数は一つのはず. position_num: %d", ExpertMartingale::GetPositionNum()));
                return 0;
            } else if (ExpertMartingale::GetPositionNum() == 0) {
                ExpertMartingale::InitPositionsStruct();
                return 1;
            }

            /** リスタートするため、既存有効ポジションからポジションコピー
             * ポジション調整後の有効なポジション数が1以上の場合、最大ロット数のポジションのみ参照する
             * リスタートのため、セグポイントは0スタート
            **/
            int valid_position_key_of_max_volume = ExpertMartingale::GetKeyOfMaxPositionVolume();
            if (valid_position_key_of_max_volume == -1) { return 1; }
            int valid_position_trade_flag = ExpertMartingale::GetPositionTradeFlagByKey(valid_position_key_of_max_volume);
            if (last_trade_flag == valid_position_trade_flag) {
                PrintWarn("ロジックバグの可能性あり、「ポジション調整&リスタート」の場合、有効なポジションは最新トレードフラグと同じではないはず");
            }

            PositionStruct new_position_struct;
            new_position_struct.ticket = ExpertMartingale::GetPositionTicketByKey(valid_position_key_of_max_volume);
            new_position_struct.trade_flag = valid_position_trade_flag;
            new_position_struct.price = ExpertMartingale::GetPositionPriceByKey(valid_position_key_of_max_volume);
            new_position_struct.volume = ExpertMartingale::GetPositionVolumeByKey(valid_position_key_of_max_volume);
            new_position_struct.trade_datetime = ExpertMartingale::GetPositionTradeDatetimeByKey(valid_position_key_of_max_volume);
            new_position_struct.seg_point = 0;
            new_position_struct.is_valid = 1;

            ExpertMartingale::InitPositionsStruct();
            ExpertMartingale::AddPosition(new_position_struct);

            ExpertMartingale::PlusPositionNum();
            if (valid_position_trade_flag == IS_BUYING) {
                ExpertMartingale::PlusBuyingNum();
            } else {
                ExpertMartingale::PlusSellingNum();
            }
            
            ExpertMartingale::SetInitialVolume(ExpertMartingale::GetMaxPositionVolume());  // 初期ロット数を動的セット
            ExpertMartingale::SetInitialProfit(GetAllPositionProfitByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber()));  // リスタート時の損失をセット

            /**
             *  ここまでで有効なポジションを一つ残してリスタート準備完了
            **/

            ExpertMartingale::TradeOrder(last_trade_flag);
            int order_retcode = ExpertMartingale::OrderRetcode(true);
            if (order_retcode == 0) {
                return 0;
            }
            if (order_retcode == 2) return 1;  // 市場閉鎖によりスキップ

            if (last_trade_flag == IS_BUYING) {
                ExpertMartingale::PlusBuyingNum();
            } else {
                ExpertMartingale::PlusSellingNum();
            }
            ExpertMartingale::PlusPositionNum();

            PositionStruct position_struct;
            ExpertMartingale::SetPositionStruct(
                position_struct,
                myTrade.ResultOrder(),
                last_trade_flag,
                myTrade.ResultPrice(),
                myTrade.ResultVolume(),
                TimeLocal()
            );
            
            double price_diff = MathAbs(ExpertMartingale::GetPositionPriceByKey(0) - myTrade.ResultPrice());
            double seg_point_diff = MARTINGALE_PIPS;
            while (true) {
                if (price_diff < MARTINGALE_PIPS) {
                    if (price_diff >= MARTINGALE_PIPS / 2) {
                        seg_point_diff += MARTINGALE_PIPS / 2;
                    }
                    break;
                }
                seg_point_diff += MARTINGALE_PIPS;
                price_diff -= MARTINGALE_PIPS;
            }

            ExpertMartingale::SetMartingalePips(seg_point_diff);  // 既存有効ポジションとこのトレードの売買価格から基準PIPSを算出する
            ExpertMartingale::AddPosition(position_struct);

            ExpertMartingale::PlusMartingaleTradeCount();
        }
    }

    // 次が買いトレードの場合は、現在のレートが次トレードのレート以上
    // 次が売りトレードの場合は、現在のレートが次トレードのレート以下
    // 上記いずれかを満たす場合、注文
    if ((next_trade_flag == IS_BUYING && now_price >= next_seg_price) || 
        (next_trade_flag == IS_SELLING && now_price <= next_seg_price))
    {
        // 次回トレードロット数が指定ロット数を超えるとロット数を調整する
        if (IS_ACTIVE_CLEAR_LOT && next_trade_volume >= RESTRICTED_TRADE_VOLUME) {
            if (!ExpertMartingale::ClearLot(1)) {
                ExpertMartingale::SettlementAllPosition();
                PrintError("ポジション調整失敗のため全決済して異常終了");
                return 0;
            }
        }

        // 注文
        ExpertMartingale::TradeOrder(next_trade_flag);
        int order_retcode = ExpertMartingale::OrderRetcode(true);
        if (order_retcode == 0) {
            return 0;
        }

        if (order_retcode == 2) return 1;  // 市場閉鎖によりスキップ

        if (next_trade_flag == IS_BUYING) {
            ExpertMartingale::PlusBuyingNum();
        } else {
            ExpertMartingale::PlusSellingNum();
        }
        ExpertMartingale::PlusPositionNum();

        PositionStruct position_struct;
        ExpertMartingale::SetPositionStruct(
            position_struct,
            myTrade.ResultOrder(),
            next_trade_flag,
            myTrade.ResultPrice(),
            myTrade.ResultVolume(),
            TimeLocal()
        );
        ExpertMartingale::AddPosition(position_struct);
        ExpertMartingale::PlusMartingaleTradeCount();
        return 1;
    }

    return 1;
}

bool ExpertMartingale::IsCanClearLotRestart() {
    if (ExpertMartingale::GetPositionNum() < 2) return false;
    double total_benefit = 0.0;

    for (int i = 0;i < ExpertMartingale::GetPositionSize(); i++) {
        if (ExpertMartingale::GetPositionIsValidByKey(i) == false) continue;
        ulong  position_ticket = ExpertMartingale::GetPositionTicketByKey(i);
        if (!PositionSelectByTicket(position_ticket)) {
            PrintWarn(StringFormat("ポジション情報取得失敗, チケット=%d", position_ticket));
            continue;
        }

        double position_profit = PositionGetDouble(POSITION_PROFIT);

        if (position_ticket == 0) continue;

        if (position_profit >= 0) {
            total_benefit += position_profit;
        }
    }

    for (int i = 0;i < ExpertMartingale::GetPositionSize(); i++) {
        if (ExpertMartingale::GetPositionIsValidByKey(i) == false) continue;
        ulong  position_ticket = ExpertMartingale::GetPositionTicketByKey(i);
        if (!PositionSelectByTicket(position_ticket)) {
            PrintWarn(StringFormat("ポジション情報取得失敗, チケット=%d", position_ticket));
            continue;
        }

        double position_volume = PositionGetDouble(POSITION_VOLUME);
        double position_profit = PositionGetDouble(POSITION_PROFIT);

        if (position_ticket == 0 || position_profit >= 0.0) continue;

        int divide_volume_cnt = (int)(position_volume / INITIAL_VOLUME);  // 最小ロット数で分割できる数
        double divide_position_profit = position_profit / divide_volume_cnt;  // 最小ロット分の損失
        if (total_benefit >= MathAbs(divide_position_profit)) { return true; }
    }
    return false;
}

int ExpertMartingale::ClearLot(int logic_flag) {
    if (ExpertMartingale::GetPositionNum() < 2) return 1;
    double total_benefit = 0.0;

    string comment_prefix = "ポジション調整";
    if (logic_flag == 1) { comment_prefix = "ポジション調整"; }
    if (logic_flag == 2) { comment_prefix = "リスタート"; }

    for (int i = 0;i < ExpertMartingale::GetPositionSize(); i++) {
        if (ExpertMartingale::GetPositionIsValidByKey(i) == false) continue;
        ulong  position_ticket = ExpertMartingale::GetPositionTicketByKey(i);
        if (!PositionSelectByTicket(position_ticket)) {
            PrintWarn(StringFormat("ポジション情報取得失敗, チケット=%d", position_ticket));
            continue;
        }
        double position_volume = PositionGetDouble(POSITION_VOLUME);
        double position_profit = PositionGetDouble(POSITION_PROFIT);

        if (position_ticket == 0 || position_volume == 0.0) continue;

        if (position_profit >= 0) {  // 利益を出しているポジションは決済確定
            string comment = StringFormat("[%s] 利益分、チケット=%d", comment_prefix, position_ticket);
            myTrade.PositionClose(position_ticket, ULONG_MAX, comment);
            int order_retcode = ExpertMartingale::OrderRetcode(false);
            if (order_retcode == 0) {
                ExpertMartingale::PlusOrderErrorCount();
                PrintWarn(StringFormat("%s失敗（利益）, チケット=%d", comment_prefix, position_ticket));
                return 0;
            }

            if (order_retcode == 2) continue;  // 市場閉鎖によりスキップ

            ExpertMartingale::MinusPositionNum();
            ExpertMartingale::ConvertInvalidPosition(i);

            double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
            total_benefit += deal_profit;
            ExpertMartingale::AddClearLotBenefitList(deal_profit);
            
        }
    }

    // 損失分のポジション調整
    for (int i = 0;i < ExpertMartingale::GetPositionSize(); i++) {
        if (ExpertMartingale::GetPositionIsValidByKey(i) == false) continue;
        ulong  position_ticket = ExpertMartingale::GetPositionTicketByKey(i);
        if (!PositionSelectByTicket(position_ticket)) {
            PrintWarn(StringFormat("ポジション情報取得失敗, チケット=%d", position_ticket));
            continue;
        }
        double position_volume = PositionGetDouble(POSITION_VOLUME);
        double position_profit = PositionGetDouble(POSITION_PROFIT);

        if (position_ticket == 0 || position_volume == 0.0) continue;

        // 利益が発生しているポジションは基本ないはず
        // あったとしても無視で良い
        if (position_profit >= 0) {
            continue;
        }

        // トータル利益額より損失額が小さい場合は全てのロットを決済
        if (MathAbs(position_profit) <= total_benefit) {
            string comment = StringFormat("[%s] 損失分、チケット=%d", comment_prefix, position_ticket);
            myTrade.PositionClose(position_ticket, ULONG_MAX, comment);
            int order_retcode = ExpertMartingale::OrderRetcode(false);
            if (order_retcode == 0) {
                ExpertMartingale::PlusOrderErrorCount();
                PrintError(StringFormat("失敗（損失）, チケット=%d / all", comment_prefix, position_ticket));
                return 0;
            }

            if (order_retcode == 2) continue;

            ExpertMartingale::MinusPositionNum();
            ExpertMartingale::ConvertInvalidPosition(i);

            double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
            total_benefit += deal_profit;
            ExpertMartingale::AddClearLotLosscutList(deal_profit);
            continue;
        }

        // トータル利益より損失額が大きい場合は最小限の利益が出る範囲で既存損失ポジションを部分決済
        int divide_volume_cnt = (int)(position_volume / INITIAL_VOLUME);  // 最小ロット数で分割できる数
        double divide_position_profit = position_profit / divide_volume_cnt;  // 最小ロット分の損失
        double settlement_volume = (int)(total_benefit / MathAbs(divide_position_profit)) * INITIAL_VOLUME;  // ポジション整理対象ロット数
        if (settlement_volume > position_volume) {
            settlement_volume = position_volume;
        }

        if (settlement_volume < INITIAL_VOLUME) continue;
        double remaining_volume = position_volume - settlement_volume;

        string comment = StringFormat("[%s]損失分、チケット=%d, %.2f/%.2f", comment_prefix, position_ticket, remaining_volume, position_volume);
        myTrade.PositionClose(position_ticket, ULONG_MAX, settlement_volume, comment);
        int order_retcode = ExpertMartingale::OrderRetcode(false);
        if (order_retcode == 0) {
            ExpertMartingale::PlusOrderErrorCount();
            PrintError(StringFormat("%s失敗（損失）, チケット=%d, %.2f/%.2f", comment_prefix, position_ticket, remaining_volume, position_volume));
            return 0;
        }

        if (order_retcode == 2) continue;

        
        ExpertMartingale::SetPositionVolumeByKey(i, remaining_volume);


        double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
        total_benefit += deal_profit;
        ExpertMartingale::AddClearLotLosscutList(deal_profit);
                
    }

    ExpertMartingale::AddClearLotProfitList(total_benefit);
    ExpertMartingale::AddPositionProfit(total_benefit);


    return 1;
}


/** ポジション全決済
 * 稼働EAでのポジションは全て決済したいため、実際のポジション情報を取得するようにする
 * return int 決済数
**/
int ExpertMartingale::SettlementAllPosition() {
    int ret_cnt = 0;
    double total_revenue = 0.0;
    while (true)  {
        int total_position = PositionsTotal();
        for (int i = 0; i < total_position; i++) {
            // PositionGetTicket(i)だとポジションチケットを取得できないことがある
            if (!PositionSelect(Symbol())) continue;// 対象シンボルのポジションをチケット番号が最も古いものを取得する
            if (ExpertMartingale::GetMagicNumber() != PositionGetInteger(POSITION_MAGIC)) continue;
            ulong position_ticket = PositionGetInteger(POSITION_TICKET);
            if (position_ticket == 0) continue;
            string comment = StringFormat("全決済: ポジション: %d", position_ticket);
            if (!myTrade.PositionClose(position_ticket, ULONG_MAX, comment)) {
                continue;
            }

            int order_retcode = ExpertMartingale::OrderRetcode(false, true);
            if (order_retcode == 0) {
                ExpertMartingale::PlusAllSettlementOrderErrorCount();
                PrintError(StringFormat("全決済失敗のためやり直し, error_position: %d", position_ticket));
                break;  // 決済失敗のためやり直し
            }
            if (order_retcode == 2) {
                PrintWarn(StringFormat("市場閉鎖による全決済失敗のため時間を置いてやり直し, error_position: %d", position_ticket));
                break;  // 市場閉鎖によりやり直し
            }

            double position_profit = PositionGetDouble(POSITION_PROFIT);
            double position_volume = PositionGetDouble(POSITION_VOLUME);
            
            ret_cnt += 1;
            total_revenue += GetSettlementProfit(myTrade.ResultDeal());

            if (position_volume > ExpertMartingale::GetTradeMaxVolume()) {
                ExpertMartingale::SetTradeMaxVolume(position_volume);
            }
        }

        if (GetPositionNumByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber()) == 0) {
            break;
        }
        PrintWarn("全決済完了しなかったため再度実行");
        Sleep(3600*10);
    }
    
    if (total_revenue < 0) {
        PrintWarn(StringFormat("損失発生、損益=%.5f", total_revenue));
    }

    if (ret_cnt == 1) {
        ExpertMartingale::PlusFirstTradeBenefitCount();
    }
    ExpertMartingale::AddAllSettlementProfitList(total_revenue);
    ExpertMartingale::AddPositionProfit(total_revenue);
    PositionHistoryStruct position_history;
    position_history.first_ticket = ExpertMartingale::GetPositionTicketByKey(0);
    position_history.profit = ExpertMartingale::GetPositionProfit();
    ExpertMartingale::AddPositionHistory(position_history);

    return ret_cnt;
}


/**
 * 初回トレード判定ロジック
 * return int 買い: 1 売り: -1 それ以外: 0
**/
int ExpertMartingale::CalcFirstTradeTrend() {
    CMyMovingAverage myMovingAverage();
    if (!myMovingAverage.Init(Symbol(), PERIOD_M15, MA_PERIOD, 0, MA_METHOD, PRICE_CLOSE)) {
        PrintWarn("Failed Init IMA Handle");
        return IS_BUYING;
    }
    if (!myMovingAverage.SetMaByPosition(0, 0, MA_COMPARISON_RANGE)) {
        PrintWarn("Failed Get IMA Datas");
        return IS_BUYING;
    }

    double latest_ma_data = myMovingAverage.GetImaData(0);
    double oldest_ma_data = myMovingAverage.GetImaData(MA_COMPARISON_RANGE-1);
    if (latest_ma_data >= oldest_ma_data) {
        return IS_BUYING;
    }
    return IS_SELLING;
}

bool ExpertMartingale::IsShortTrendContinue(int latest_trade_flag) {
    CMyMovingAverage myMovingAverage();
    if (!myMovingAverage.Init(Symbol(), PERIOD_M15, MA_PERIOD_FOR_TREND, 0, MA_METHOD_FOR_TREND, PRICE_CLOSE)) {
        PrintWarn("Failed Init IMA Handle");
        return false;
    }
    if (!myMovingAverage.SetMaByPosition(0, 0, MA_COMPARISON_RANGE)) {
        PrintWarn("Failed Get IMA Datas");
        return false;
    }
    double latest_ma_data = myMovingAverage.GetImaData(0);
    double oldest_ma_data = myMovingAverage.GetImaData(MA_COMPARISON_RANGE-1);

    if (latest_trade_flag == IS_BUYING) {
        return (latest_ma_data > oldest_ma_data);
    } else if (latest_trade_flag == IS_SELLING) {
        return (latest_ma_data < oldest_ma_data);
    }
    return false;
}

double ExpertMartingale::CalcNextTradeSegPrice() {
    int next_trade_flag = ExpertMartingale::GetNextTradeFlag();
    int init_trade_flag = ExpertMartingale::GetInitTradeFlag();
    double init_price = ExpertMartingale::GetInitPrice();
    double next_seg_price = 0.0;

    // 初回トレードによって基準価格の初期値が変わる
    if (next_trade_flag == IS_BUYING) {
        next_seg_price = init_price + (ExpertMartingale::GetBuyingNum() * ExpertMartingale::GetMartingalePips());
        if (init_trade_flag == IS_SELLING) {
            next_seg_price += ExpertMartingale::GetMartingalePips();
        }
    } else {
        next_seg_price = init_price - (ExpertMartingale::GetSellingNum() * ExpertMartingale::GetMartingalePips());
        if (init_trade_flag == IS_BUYING) {
            next_seg_price -= ExpertMartingale::GetMartingalePips();
        }
    }
    return next_seg_price;
}

int ExpertMartingale::CalcSegPoint(double price) {
    double seg_price = price - ExpertMartingale::GetInitPrice();
    return (int)(seg_price / ExpertMartingale::GetMartingalePips());
}

/** ロジック上、利益が出る価格を算出（設定PIPS単位）
 * 
**/
double ExpertMartingale::CalcRevenuePrice(double latest_price) {
    int latest_seg_point = ExpertMartingale::CalcSegPoint(latest_price);

    double total_seg_point_profit = 0.0;
    for (int i = 0; i < ExpertMartingale::GetPositionSize(); i++) {
        if (ExpertMartingale::GetPositionIsValidByKey(i) == false) continue;

        int trade_flag = ExpertMartingale::GetPositionTradeFlagByKey(i);
        int position_seg_point = ExpertMartingale::GetPositionSegPointByKey(i);
        double position_volume = ExpertMartingale::GetPositionVolumeByKey(i);
        
        int seg_point_diff = 0;
        if (trade_flag == IS_BUYING) {
            seg_point_diff = latest_seg_point - position_seg_point;
        } else if (trade_flag == IS_SELLING) {
            seg_point_diff = position_seg_point - latest_seg_point;
        }
        total_seg_point_profit += seg_point_diff * position_volume;
    }
    return total_seg_point_profit;
}

bool ExpertMartingale::IsRevenueBySegCalc(double latest_price, int pips_diff) {
    return ExpertMartingale::CalcRevenuePrice(latest_price) >= ExpertMartingale::GetInitialVolume() * pips_diff;  // 利益額 >= 初期ロット数 * α （理論上より+αを持たせた方が少しリスクが上がるが、損を出すことはなくなる）
}

int ExpertMartingale::GetNextTradeFlag() {
    if (ExpertMartingale::GetBuyingNum() == ExpertMartingale::GetSellingNum()) {  // 買い回数と売り回数が一致する場合
        if (ExpertMartingale::HasInitTradeFlag()) {   // 初回トレード情報あり
            return ExpertMartingale::GetInitTradeFlag();
        } else {  // 初回トレード情報なし
            if (ExpertMartingale::GetTradeNum() > 0) {
                PrintWarn(StringFormat("Undefined init_trade_flag, but has positions, buying_num: %d, selling_num: %d", ExpertMartingale::GetBuyingNum(), ExpertMartingale::GetSellingNum()));
            }
            return ExpertMartingale::CalcFirstTradeTrend();
        }
    } else {
        if (ExpertMartingale::GetBuyingNum() > ExpertMartingale::GetSellingNum()) {
            return IS_SELLING;
        } else {
            return IS_BUYING;
        }
    }
    PrintError("Maybe Logic Bug By Calc GetNextTradeFlag");
    return IS_BUYING;
}

int ExpertMartingale::GetAllSettlementPipsDiff() {
    int trade_cnt = ExpertMartingale::GetTradeNum();
    double latest_position_volume = ExpertMartingale::GetMaxPositionVolume();
    if (trade_cnt <= ALL_SETTLEMENT_PIPS_DIFF) { return 1; }
    if ((ExpertMartingale::GetMaxPositionVolume() * 2) > CLEAR_BASE_VOLUME) { return 1; }
    return 2;
}

int ExpertMartingale::GetLatestTradeFlag() {
    if (!ExpertMartingale::HasInitTradeFlag()) {
        return IS_NOTRADE;
    }
    int next_trade_flag = ExpertMartingale::GetNextTradeFlag();
    return ExpertMartingale::SwitchTradeFlag(next_trade_flag);
}

double ExpertMartingale::GetNextTradeVolume() {
    if (ExpertMartingale::GetPositionNum() == 0) {
        return ExpertMartingale::GetInitialVolume();
    }

    double volume = ExpertMartingale::GetInitialVolume() * MathPow(2, ExpertMartingale::GetTradeNum());
    if (volume >= CLEAR_BASE_VOLUME) {
        volume = ExpertMartingale::GetMaxPositionVolume() * 2;
    }
    return volume;
}

void OnInit() {
    PrintNotice(StringFormat("Start ExpertMartingale, symbol: %s", Symbol()));

    EventSetTimer(ONE_DATE_DATETIME); //1日間隔でタイマーイベントを呼び出す

    if (IS_INIT_OF_POSITIONS_STRUCT) {
        ExpertMartingale::InitPositionsStruct();
        ExpertMartingale::SetInitialVolume(INITIAL_VOLUME);
        ExpertMartingale::SetMartingalePips(MARTINGALE_PIPS);
        PrintNotice("Positions構造体を初期化しました");
    } else {
        PrintNotice("Positions初期化を初期化しませんでした");
    }

    if (IS_INIT_OF_TRADE_ANALYST_STRUCT) {
        ExpertMartingale::InitTradeAnalysisStruct();
        PrintNotice("TradeAnalyst構造体を初期化しました");
    } else {
        PrintNotice("TradeAnalyst初期化を初期化しませんでした");
    }

    if (IS_FORCE_STOPPED) {
        PrintNotice("ポジションがなくなり次第強制終了します。");
    }

    if (Symbol() == "USDJPY") {
        ExpertMartingale::SetMagicNumber(100001);
    } else if (Symbol() == "EURUSD") {
        ExpertMartingale::SetMagicNumber(100002);
    } else {
        ExpertMartingale::SetMagicNumber(100000);
    }
    
    myTrade.SetAsyncMode(false);
    myTrade.SetExpertMagicNumber(ExpertMartingale::GetMagicNumber());
    myTrade.SetTypeFilling(ORDER_FILLING_IOC);

    if (!mySymbolInfo.Refresh()) {
        PrintError("Cannot Refresh Cached Data of SymbolInfo");
        ForceStopEa();
        return;
    }

    if (!mySymbolInfo.IsValidMinVolume(INITIAL_VOLUME)) {
        PrintError(StringFormat("Initial Volume is too Low than %.5f", mySymbolInfo.LotsMin()));
        ForceStopEa();
        return;
    }
}

void OnTick() {
    uint start = GetTickCount();
    if (!ExpertMartingale::MainLoop()) {
        ExpertMartingale::PrintTradeAnalysis();
        PrintError(StringFormat("Exception Thrown, so Finished ExpertMartingale, symbol: %s", Symbol()));
        ForceStopEa();
        return;
    }

    if (main_loop_cnt % 100 == 0) {
        if (myAccountInfo.MarginLevel() < ExpertMartingale::GetTradeMinMarginRate() && myAccountInfo.MarginLevel() > 0) {
            ExpertMartingale::SetTradeMinMarginRate(myAccountInfo.MarginLevel());
        }

        if (main_loop_cnt > 0 && (main_loop_total_sec / main_loop_cnt) > 100) {
        PrintWarn(StringFormat("Total MainLoop Count = %d, Avg MiliSecond = %d", main_loop_cnt, main_loop_total_sec));
    }
    }

    main_loop_cnt += 1;
    main_loop_total_sec += GetTickCount() - start;
    Sleep(3600*1); // 1分スリープ
}

void OnTimer() {
    main_loop_cnt = 0;
    main_loop_total_sec = 0;
    
    if (myAccountInfo.IsMarginLevelSafe(MARGIN_SAFE_LEVEL_RATIO) == false) {
        PrintWarn(StringFormat("証拠金維持率に余裕がありません。 証拠金維持率: %.3f", myAccountInfo.MarginLevel()));
    }

    if (!mySymbolInfo.Refresh()) {
        PrintWarn("Cannot Refresh Cached Data of SymbolInfo");
    }

    ExpertMartingale::PrintTradeAnalysis();
    if (!myLogHandler.SearchAndMailFromLog(MinusDayForDatetime(TimeLocal(), 1), "ERROR,WARN", "バグ検知_daily")) {
        PrintError("バグ検知_dailyのメール送信失敗");
    }
    if (!myLogHandler.SearchAndMailFromLog(MinusDayForDatetime(TimeLocal(), 1), "SUMMARY", "サマリー_daily")) {
        PrintError("サマリー_dailyのメール送信失敗");
    }
    myLogHandler.DeleteOlderLogFile(MinusDayForDatetime(TimeLocal(), 30));

    if (ExpertMartingale::IsLogicNormally() == 2) {
        ForceStopEa();
        return;
    }

    if (IS_INIT_TRADE_ANALYSIS_STRUCY_ON_FIRST_DAY && GetDateFromDatetime(TimeLocal()) == 1) {
        ExpertMartingale::InitTradeAnalysisStruct();
    }
}

/** ロジックチェック
 * return int OK: 0, warning: 1, force stopped: 2
**/
int ExpertMartingale::IsLogicNormally() {
    if (GetPositionNumByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber()) != ExpertMartingale::GetPositionNum()) {
        PrintError(StringFormat("ロジックバグ. 保有ポジション数が一致しない, real: %d, getter: %d", GetPositionNumByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber()), ExpertMartingale::GetPositionNum()));
        return 1;
    }

    int real_position_num = 0;
    for (int i = 0; i < ExpertMartingale::GetPositionSize(); i++) {
        if (ExpertMartingale::GetPositionIsValidByKey(i) == false) continue;

        ulong logic_position_ticket = ExpertMartingale::GetPositionTicketByKey(i);
        if (!PositionSelectByTicket(logic_position_ticket)) {
            PrintError(StringFormat("ロジックバグ. 保有ポジションチケットを保有していない. logic_position_ticket: %d", logic_position_ticket));
            return 1;
        }
        real_position_num += 1;

        if (ExpertMartingale::GetMagicNumber() != PositionGetInteger(POSITION_MAGIC)) continue;
        ulong real_position_ticket = PositionGetInteger(POSITION_TICKET);
        if (real_position_ticket == 0) continue;

        double real_position_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double real_position_volume = PositionGetDouble(POSITION_VOLUME);

        int positions_element = ExpertMartingale::SearchPositionsElementByTicket(real_position_ticket, true);
        if (positions_element == -1) {
            PrintError(StringFormat("ロジックバグ. 保有中ポジションを保持できていない, position_ticket: %d", real_position_ticket));
            return 1;
        }

        double logic_position_price = ExpertMartingale::GetPositionPriceByKey(positions_element);
        if (logic_position_price != real_position_price) {
            PrintError(StringFormat(
                "ロジックバグ. 保有中ポジション価格が一致しない, position_ticket: %d, real_price: %.5f, logic_price: %.5f",
                real_position_ticket, real_position_price, logic_position_price
            ));
            return 1;
        }

        double logic_position_volume = ExpertMartingale::GetPositionVolumeByKey(positions_element);
        if (logic_position_volume != real_position_volume) {
            PrintError(StringFormat(
                "ロジックバグ. 保有中ポジションロット数が一致しない, position_ticket: %d, real_volume: %.2f, logic_volume: %.2f",
                real_position_ticket, real_position_volume, logic_position_volume
            ));
            return 1;
        }
    }

    if (real_position_num != ExpertMartingale::GetPositionNum()) {
        PrintError(StringFormat("ロジックバグ. 保有ポジション数が一致しない. real: %d, logic: %d", real_position_num, ExpertMartingale::GetPositionNum()));
        return 1;
    }
    

    return 0;
}

void OnDeinit() {
}