#include <Arrays\ArrayDouble.mqh>


int INIT_BASE_POINT = 0;
int IS_BUYING = 1;
int IS_SELLING = -1;
int IS_NOTRADE = 0;

/** ポジション情報を保持する構造体
 * この構造体の配列を扱うことになる
 * 
**/
struct PositionStruct
{
    ulong ticket;  // ポジションチケット
    int trade_flag; // 売買フラグ 買い:1 売り:-1、未設定:0
    int seg_point;  // 初回トレード価格を基準としたPIPS差分
    double price;  // ポジション価格
    double volume;  // ポジションロット数
    datetime trade_datetime;  // トレード日時
    bool is_valid;  // 保有ポジションかどうか
};

/** 全ポジション情報を保持する構造体
 * 全決済によりポジション数がなくなったらリセットする
 * 
**/
struct PositionsStruct
{
    PositionStruct positions[];  // 一つのポジション情報の配列
    double initial_volume;  // 初期トレードロット数
    double initial_profit;  // 初期トレード時の既存損益（これがある場合はポジション調整 & リスタート済み）
    double martingale_pips;  // 書き負け判定基準PIPS
    int buying_num;  // 買った回数（決済済み含む）
    int selling_num;  // 売った回数（決済済み含む）
    int position_num;  // 保有ポジション数（未決済のみ）
    int clear_lot_num;  // ポジション整理回数
    double profit;  // この構造体が生きてる間の損益（分析用）
    double all_settlement_base_price;  // 全決済基準価格（トレンド判定なしで全決済ロジックに該当した時に本来全決済されるレート）
};

struct PositionHistoryStruct
{
    ulong first_ticket;
    double profit;
};

struct TradeAnalysisStruct
{
    int order_error_cnt;  // トレードリクエストエラー回数
    int all_settlement_order_error_cnt;  // 全決済リクエストエラー回数
    int martingale_trade_cnt;  // 両建てマーチンゲール手法によるトレード回数
    int first_trade_benefit_cnt;  // 初回トレードで勝った回数
    double trade_max_volume;  // 最大ロット数履歴
    double trade_min_margin_rate;  //最小証拠金維持率履歴
    PositionHistoryStruct position_histories[];  // ポジション履歴
    CArrayDouble all_settlement_profit_list;  // 全決済時トータル損益履歴配列
    CArrayDouble clear_lot_profit_list;  // ポジション調整時トータル損益履歴配列（調整後との調整金額）
    CArrayDouble clear_lot_benefit_list;  // ポジション調整時トータル損益履歴配列（利益分）
    CArrayDouble clear_lot_losscut_list;  // ポジション調整時トータル損益履歴配列（損失分）
    CArrayDouble trend_logic_after_all_settlement_judgement_price_diff_list;  // 全決済判定後のトレンド判定ロジックにおいて、全決済判定時とトレンド判定ロジックとの決済価格差を格納する配列
};

class ExpertMartingale {
    public:
        static TradeAnalysisStruct ExpertMartingale::trade_analysis_struct;
        static PositionsStruct ExpertMartingale::positions_struct;
        static long ExpertMartingale::magic_number;


    public:
        static long ExpertMartingale::GetMagicNumber() { return ExpertMartingale::magic_number; }
        static void ExpertMartingale::SetMagicNumber(long magic) { ExpertMartingale::magic_number = magic; }
        static ulong ExpertMartingale::GetPositionTicketByKey(int key) { return ExpertMartingale::positions_struct.positions[key].ticket; }
        static int ExpertMartingale::GetPositionTradeFlagByKey(int key) { return ExpertMartingale::positions_struct.positions[key].trade_flag; }
        static int ExpertMartingale::GetPositionSegPointByKey(int key) { return ExpertMartingale::positions_struct.positions[key].seg_point; }
        static double ExpertMartingale::GetPositionPriceByKey(int key) { return ExpertMartingale::positions_struct.positions[key].price; }
        static double ExpertMartingale::GetPositionVolumeByKey(int key) { return ExpertMartingale::positions_struct.positions[key].volume; }
        static datetime ExpertMartingale::GetPositionTradeDatetimeByKey(int key) { return ExpertMartingale::positions_struct.positions[key].trade_datetime; }
        static bool ExpertMartingale::GetPositionIsValidByKey(int key) { return ExpertMartingale::positions_struct.positions[key].is_valid; }

        static double ExpertMartingale::GetInitialVolume() { return ExpertMartingale::positions_struct.initial_volume; }
        static double ExpertMartingale::GetInitialProfit() { return ExpertMartingale::positions_struct.initial_profit; }
        static bool ExpertMartingale::HasInitialProfit() { return ExpertMartingale::positions_struct.initial_profit != 0.0; }
        static double ExpertMartingale::GetMartingalePips() { return ExpertMartingale::positions_struct.martingale_pips; }
        static int ExpertMartingale::GetBuyingNum() { return ExpertMartingale::positions_struct.buying_num; }
        static int ExpertMartingale::GetSellingNum() { return ExpertMartingale::positions_struct.selling_num; }
        static int ExpertMartingale::GetPositionNum() { return ExpertMartingale::positions_struct.position_num; }
        static double ExpertMartingale::GetPositionProfit() { return ExpertMartingale::positions_struct.profit; }
        static int ExpertMartingale::GetTradeNum() { return ExpertMartingale::positions_struct.buying_num + ExpertMartingale::positions_struct.selling_num; }
        static int ExpertMartingale::GetPositionSize() { return ArraySize(ExpertMartingale::positions_struct.positions); }
        static int ExpertMartingale::GetInitTradeFlag() {
            if (ExpertMartingale::GetPositionSize() == 0) return IS_NOTRADE;
            return ExpertMartingale::GetPositionTradeFlagByKey(0);
        }

        static double ExpertMartingale::GetInitPrice() {
            if (ExpertMartingale::GetPositionSize() == 0) return 0.0;
            return ExpertMartingale::GetPositionPriceByKey(0);
        }

        static int ExpertMartingale::GetClearLotNum() { return ExpertMartingale::positions_struct.clear_lot_num; }
        static double ExpertMartingale::GetAllSettlementBasePrice() { return ExpertMartingale::positions_struct.all_settlement_base_price; }
        static double ExpertMartingale::GetLatestPositionPrice() {
            int size = ExpertMartingale::GetPositionSize();
            if (size == 0) return 0.0;
            return ExpertMartingale::GetPositionPriceByKey(size - 1);
        }

        static double ExpertMartingale::GetMaxPositionVolume() {
            int size = ExpertMartingale::GetPositionSize();
            if (size == 0) return 0.0;
            double max_volume = 0.0;
            for (int i = 0; i < size; i++) {
                if (ExpertMartingale::GetPositionIsValidByKey(i)) {
                    double volume = ExpertMartingale::GetPositionVolumeByKey(i);
                    if (max_volume < volume) {
                        max_volume = volume;
                    }
                }
            }
            return max_volume;
        }

        static int ExpertMartingale::GetKeyOfMaxPositionVolume() {
            int size = ExpertMartingale::GetPositionSize();
            if (size == 0) return -1;
            int key = -1;
            double max_volume = 0.0;
            for (int i = 0; i < size; i++) {
                if (ExpertMartingale::GetPositionIsValidByKey(i)) {
                    double volume = ExpertMartingale::GetPositionVolumeByKey(i);
                    if (max_volume < volume) {
                        max_volume = volume;
                        key = i;
                    }
                }
            }
            return key;
        }

        static datetime ExpertMartingale::GetLatestPositionTradeDatetime() {
            int size = ExpertMartingale::GetPositionSize();
            if (size == 0) return TimeLocal();
            return ExpertMartingale::GetPositionTradeDatetimeByKey(size - 1);
        }



        static void ExpertMartingale::SetInitialVolume(double initial_volume) { ExpertMartingale::positions_struct.initial_volume = initial_volume; }
        static void ExpertMartingale::SetMartingalePips(double martingale_pips) { ExpertMartingale::positions_struct.martingale_pips = martingale_pips; }
        static void ExpertMartingale::SetInitialProfit(double initial_profit) { ExpertMartingale::positions_struct.initial_profit = initial_profit; }
        static void ExpertMartingale::PlusBuyingNum() { ExpertMartingale::positions_struct.buying_num += 1; }
        static void ExpertMartingale::PlusSellingNum() { ExpertMartingale::positions_struct.selling_num += 1; }
        static void ExpertMartingale::PlusPositionNum() { ExpertMartingale::positions_struct.position_num += 1; }
        static void ExpertMartingale::MinusPositionNum() { ExpertMartingale::positions_struct.position_num -= 1; }
        static void ExpertMartingale::AddPositionProfit(double profit) { ExpertMartingale::positions_struct.profit += profit; }
        static void ExpertMartingale::SetClearLotNum(int clear_lot_num) { ExpertMartingale::positions_struct.clear_lot_num = clear_lot_num; }
        static void ExpertMartingale::SetAllSettlementBasePrice(double all_settlement_base_price) { ExpertMartingale::positions_struct.all_settlement_base_price = all_settlement_base_price; }
        static void ExpertMartingale::SetPositionPriceByKey(int key, double price) { ExpertMartingale::positions_struct.positions[key].price = price; }
        static void ExpertMartingale::SetPositionVolumeByKey(int key, double volume) { ExpertMartingale::positions_struct.positions[key].volume = volume; }

        // 売買成立後、ポジション情報追加時に呼び出される
        static int ExpertMartingale::CalcTradingSegPoint(int trade_flag) {
            int seg_point = 0;
            if (ExpertMartingale::GetPositionSize() == 0) {
                return seg_point;  // 初回トレードは0で基準値
            }

            // すでに売買数がカウントアップされてある前提
            if (trade_flag == IS_BUYING) {
                seg_point = ExpertMartingale::GetBuyingNum();
                if (ExpertMartingale::GetInitTradeFlag() == trade_flag) {
                    seg_point -= 1;
                }
            } else if (trade_flag == IS_SELLING) {
                seg_point = ExpertMartingale::GetSellingNum() * -1;
                if (ExpertMartingale::GetInitTradeFlag() == trade_flag) {
                    seg_point += 1;
                }
            }
            
            return seg_point;
        }

        static void ExpertMartingale::AddPosition(PositionStruct &position) {
            int size = ExpertMartingale::GetPositionSize();
            ArrayResize(ExpertMartingale::positions_struct.positions, size+1);
            ExpertMartingale::positions_struct.positions[size] = position;
        }

        static void ExpertMartingale::ExchangePosition(PositionStruct &position, int key) {
            ExpertMartingale::positions_struct.positions[key] = position;
        }

        static bool ExpertMartingale::HasInitTradeFlag() {
            if (ExpertMartingale::GetPositionSize() == 0) return false;
            return ExpertMartingale::GetPositionTradeFlagByKey(0) != IS_NOTRADE;
        }

        static int ExpertMartingale::SwitchTradeFlag(int trade_flag) {
            if (trade_flag == IS_BUYING) return IS_SELLING;
            if (trade_flag == IS_SELLING) return IS_BUYING;
            return IS_NOTRADE;
        }

        static int ExpertMartingale::SetPositionStruct(PositionStruct &position_struct, ulong ticket, int trade_flag, double price, double volume, datetime trade_datetime) {
            position_struct.ticket = ticket;
            position_struct.trade_flag = trade_flag;
            position_struct.seg_point = ExpertMartingale::CalcTradingSegPoint(trade_flag);
            position_struct.price = price;
            position_struct.volume = volume;
            position_struct.trade_datetime = trade_datetime;
            position_struct.is_valid = 1;
            return 1;
        }

        static void ExpertMartingale::ConvertInvalidPosition(int key) {
            ExpertMartingale::positions_struct.positions[key].is_valid = 0;
        }

        static int ExpertMartingale::SearchPositionsElementByTicket(ulong position_ticket, bool is_valid) {
            for (int i = 0; i < ExpertMartingale::GetPositionSize(); i++) {
                if (is_valid == true && ExpertMartingale::GetPositionTradeFlagByKey(i) == false) continue;
                if (ExpertMartingale::GetPositionTicketByKey(i) == position_ticket) {
                    return i;
                }
            }
            return -1;
        }

    public:
        static void ExpertMartingale::InitPositionsStruct();
        static void ExpertMartingale::InitTradeAnalysisStruct();
        static void ExpertMartingale::PrintTradeAnalysis();
        static int ExpertMartingale::MainLoop();
        static int ExpertMartingale::TradeOrder(int next_trade_flag);
        static int ExpertMartingale::OrderRetcode(bool is_open, bool all_settlement_flag = false);
        static double ExpertMartingale::CalcRevenuePrice(double latest_price);
        static bool ExpertMartingale::IsRevenueBySegCalc(double latest_price, int pips_diff);
        static int ExpertMartingale::GetAllSettlementPipsDiff();

        static double ExpertMartingale::CalcNextTradeSegPrice();
        static int ExpertMartingale::SettlementAllPosition();
        static bool ExpertMartingale::IsCanClearLotRestart();
        static int ExpertMartingale::ClearLot(int logic_flag);
        static int ExpertMartingale::CalcFirstTradeTrend();
        static bool ExpertMartingale::IsShortTrendContinue(int latest_trade_flag);
        static int ExpertMartingale::CalcSegPoint(double price);
        static int ExpertMartingale::GetNextTradeFlag();
        static int ExpertMartingale::GetLatestTradeFlag();
        static double ExpertMartingale::GetNextTradeVolume();
        static int ExpertMartingale::IsLogicNormally();

        static double ExpertMartingale::GetTradeMaxVolume() { return ExpertMartingale::trade_analysis_struct.trade_max_volume; }
        static double ExpertMartingale::GetTradeMinMarginRate() { return ExpertMartingale::trade_analysis_struct.trade_min_margin_rate; }
        static int ExpertMartingale::GetFirstTradeBenefitCount() { return ExpertMartingale::trade_analysis_struct.first_trade_benefit_cnt; }
        static int ExpertMartingale::GetPositionHistorySize() { return ArraySize(ExpertMartingale::trade_analysis_struct.position_histories); }

        static void ExpertMartingale::PlusOrderErrorCount() { ExpertMartingale::trade_analysis_struct.order_error_cnt += 1; }
        static void ExpertMartingale::PlusAllSettlementOrderErrorCount() { ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt += 1; }
        static void ExpertMartingale::PlusMartingaleTradeCount() { ExpertMartingale::trade_analysis_struct.martingale_trade_cnt += 1; }
        static void ExpertMartingale::PlusFirstTradeBenefitCount() { ExpertMartingale::trade_analysis_struct.first_trade_benefit_cnt += 1; }
        static void ExpertMartingale::SetTradeMaxVolume(double trade_max_volume) { ExpertMartingale::trade_analysis_struct.trade_max_volume = trade_max_volume; }
        static void ExpertMartingale::SetTradeMinMarginRate(double trade_min_margin_rate) { ExpertMartingale::trade_analysis_struct.trade_min_margin_rate = trade_min_margin_rate; }
        static void ExpertMartingale::AddAllSettlementProfitList(double all_settlement_profit) { ExpertMartingale::trade_analysis_struct.all_settlement_profit_list.Add(all_settlement_profit); }
        static void ExpertMartingale::AddClearLotProfitList(double clear_lot_profit) { ExpertMartingale::trade_analysis_struct.clear_lot_profit_list.Add(clear_lot_profit); }
        static void ExpertMartingale::AddClearLotBenefitList(double clear_lot_benefit) { ExpertMartingale::trade_analysis_struct.clear_lot_benefit_list.Add(clear_lot_benefit); }
        static void ExpertMartingale::AddClearLotLosscutList(double clear_lot_losscut) { ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.Add(clear_lot_losscut); }
        static void ExpertMartingale::AddAllSettlementTrendLogicPriceDiff(double profit_diff) { ExpertMartingale::trade_analysis_struct.trend_logic_after_all_settlement_judgement_price_diff_list.Add(profit_diff); }
        static void ExpertMartingale::AddPositionHistory(PositionHistoryStruct &position_history) {
            int size = ExpertMartingale::GetPositionHistorySize();
            ArrayResize(ExpertMartingale::trade_analysis_struct.position_histories, size+1);
            ExpertMartingale::trade_analysis_struct.position_histories[size] = position_history;
        }

    
};

void ExpertMartingale::InitPositionsStruct() {
    ArrayFree(ExpertMartingale::positions_struct.positions);
    ExpertMartingale::positions_struct.initial_volume = 0.0;
    ExpertMartingale::positions_struct.initial_profit = 0.0;
    ExpertMartingale::positions_struct.martingale_pips = 0.0;
    ExpertMartingale::positions_struct.buying_num = 0;
    ExpertMartingale::positions_struct.selling_num = 0;
    ExpertMartingale::positions_struct.position_num = 0;
    ExpertMartingale::positions_struct.clear_lot_num = 0;
    ExpertMartingale::positions_struct.profit = 0;
    ExpertMartingale::positions_struct.all_settlement_base_price = 0.0;
}

void ExpertMartingale::InitTradeAnalysisStruct() {
    ArrayFree(ExpertMartingale::trade_analysis_struct.position_histories);
    ExpertMartingale::trade_analysis_struct.order_error_cnt = 0;
    ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt = 0;
    ExpertMartingale::trade_analysis_struct.martingale_trade_cnt = 0;
    ExpertMartingale::trade_analysis_struct.trade_max_volume = 0.0;
    ExpertMartingale::trade_analysis_struct.trade_min_margin_rate = DBL_MAX;
}

void ExpertMartingale::PrintTradeAnalysis() {
    Print(StringFormat("[SUMMARY] トレードリクエストの失敗回数=%d", ExpertMartingale::trade_analysis_struct.order_error_cnt));
    Print(StringFormat("[SUMMARY] 全決済リクエストの失敗回数=%d", ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt));

    int all_settlement_cnt = ExpertMartingale::trade_analysis_struct.all_settlement_profit_list.Total();
    PrintFormat(
        "[SUMMARY] 両建てマーチンゲール手法による取引回数: %d, 決済回数: %d, 初回トレード勝ち数: %d 最大トレードロット数: %.2f, 最小証拠金維持率: %.3f",
        ExpertMartingale::trade_analysis_struct.martingale_trade_cnt,
        all_settlement_cnt,
        ExpertMartingale::GetFirstTradeBenefitCount(),
        ExpertMartingale::trade_analysis_struct.trade_max_volume,
        ExpertMartingale::trade_analysis_struct.trade_min_margin_rate
    );

    int all_settlement_benefit_cnt = 0;
    double all_settlement_total_benefit = 0.0;
    int all_settlement_loss_cnt = 0;
    double all_settlement_total_loss = 0.0;
    double all_settlement_total_profit = 0.0;

    int trend_logic_non_adopted_cnt = 0;
    int trend_logic_price_cnt = 0;
    double trend_logic_benefit_price = 0.0;
    int trend_logic_loss_cnt = 0;
    double trend_logic_loss_price = 0.0;
    for (int i = 0;i < all_settlement_cnt;i++) {
        double all_settlement_profit = ExpertMartingale::trade_analysis_struct.all_settlement_profit_list.At(i);

        if (all_settlement_profit >= 0) {
            all_settlement_benefit_cnt += 1;
            all_settlement_total_benefit += all_settlement_profit;
        } else {
            all_settlement_loss_cnt += 1;
            all_settlement_total_loss += all_settlement_profit;
        }
        all_settlement_total_profit += all_settlement_profit;

        double all_settlement_trend_logic_price_diff = ExpertMartingale::trade_analysis_struct.trend_logic_after_all_settlement_judgement_price_diff_list.At(i);
        if (all_settlement_trend_logic_price_diff > 100000) {
            continue;  // 稀に不正値が入っているので除外する
        }
        if (all_settlement_trend_logic_price_diff > 0.0) {
            trend_logic_price_cnt += 1;
            trend_logic_benefit_price += all_settlement_trend_logic_price_diff;
        } else if (all_settlement_trend_logic_price_diff < 0.0) {
            trend_logic_loss_cnt += 1;
            trend_logic_loss_price += all_settlement_trend_logic_price_diff;
        } else {
            trend_logic_non_adopted_cnt += 1;
        }
    }
    PrintFormat("[SUMMARY] [全決済履歴] total=%.3f, 利益: %d, avg=%.3f, 損失: %d, avg=%.3f", 
                all_settlement_total_profit, 
                all_settlement_benefit_cnt, all_settlement_total_benefit / all_settlement_benefit_cnt, 
                all_settlement_loss_cnt, all_settlement_total_loss / all_settlement_loss_cnt
    );

    PrintFormat("[SUMMARY] [トレンド判定による全決済履歴] ロジック使用率:%.2f, 利益価格差: %d回 %.5f avg=%.5f, 損失価格差: %d回 %.5f avg=%.5f",
                (all_settlement_cnt - trend_logic_non_adopted_cnt) / all_settlement_cnt,
                trend_logic_price_cnt, trend_logic_benefit_price, trend_logic_benefit_price / trend_logic_price_cnt,
                trend_logic_loss_cnt, trend_logic_loss_price, trend_logic_loss_price / trend_logic_loss_cnt
    );

    int clear_lot_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_profit_list.Total();
    int clear_lot_benefit_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_benefit_list.Total();
    int clear_lot_losscut_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.Total();
    PrintFormat("[SUMMARY] [ポジション調整履歴] ポジション調整数: %d 利益調整数: %d, 損失調整数: %d", clear_lot_cnt, clear_lot_benefit_cnt, clear_lot_losscut_cnt);

    double total_profit = GetTotalSettlementProfitByTargetEa(Symbol(), ExpertMartingale::GetMagicNumber());
    PrintFormat("[SUMMARY] 現在までの累積損益：%f円", total_profit);

    for (int i = 0; i < ExpertMartingale::GetPositionHistorySize(); i++) {
        ulong first_trade_ticket = ExpertMartingale::trade_analysis_struct.position_histories[i].first_ticket;
        double profit = ExpertMartingale::trade_analysis_struct.position_histories[i].profit;
        if (profit < 0) {
            PrintFormat("[SUMMARY] profit_per_martingale: %.3f, first_trade_ticket: %d", profit, first_trade_ticket);
        }
    }

    int clear_lot_final_benefit_cnt = 0;
    int clear_lot_final_losscut_cnt = 0;
    double clear_lot_final_total_benefit = 0.0;
    double clear_lot_final_total_losscut = 0.0;
    for (int i = 0;i < clear_lot_cnt;i++) {
        double clear_lot_final_profit = ExpertMartingale::trade_analysis_struct.clear_lot_profit_list.At(i);
        if (clear_lot_final_profit >= 0) {
            clear_lot_final_benefit_cnt += 1;
            clear_lot_final_total_benefit += clear_lot_final_profit;
        } else {
            clear_lot_final_losscut_cnt += 1;
            clear_lot_final_total_losscut += clear_lot_final_profit;
        }
    }
    PrintFormat("[SUMMARY] [ポジション調整履歴] 利益: %d, avg=%.3f, 損失: %d, avg=%.3f", 
                clear_lot_final_benefit_cnt, clear_lot_final_total_benefit / clear_lot_final_benefit_cnt, 
                clear_lot_final_losscut_cnt, clear_lot_final_total_losscut / clear_lot_final_losscut_cnt
    );


    int clear_lot_benefit_but_loss_cnt = 0;
    for (int i = 0;i < clear_lot_benefit_cnt;i++) {
        if (ExpertMartingale::trade_analysis_struct.clear_lot_benefit_list.At(i) < 0) {
            clear_lot_benefit_but_loss_cnt += 1;
        }
    }

    // 損失ポジションでポジション調整したが実際は利益だった回数
    int clear_lot_losscut_but_benefit_cnt = 0;
    for (int i = 0;i < clear_lot_losscut_cnt;i++) {
        if (ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.At(i) > 0) {
            clear_lot_losscut_but_benefit_cnt += 1;
        }
    }

    PrintFormat("[SUMMARY] [ポジション調整 バグ可能性] 利益ポジションでポジション調整したが実際は損失だった回数: %d", clear_lot_benefit_but_loss_cnt);
    PrintFormat("[SUMMARY] [ポジション調整 バグ可能性] 損失ポジションでポジション調整したが実際は利益だった回数: %d", clear_lot_losscut_but_benefit_cnt);
}
