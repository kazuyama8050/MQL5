#include <Arrays\ArrayDouble.mqh>


#define MAGIC_NUMBER 123458
int INIT_BASE_POINT = 0;

struct EntryStruct
{
    int buying_num;  // 買った回数
    int selling_num;  // 売った回数
    int base_point;  // 前回トレードしたポイントが初回売買pipsからいくつ離れているか
    double init_price;  // 初回トレードの売買価格
    int clear_lot_num;  // ポジション整理回数
    datetime latest_position_trade_datetime;  // 最新ポジションの取引日時
};

struct TradeAnalysisStruct
{
    int order_error_cnt;  // トレードリクエストエラー回数
    int all_settlement_order_error_cnt;  // 全決済リクエストエラー回数
    int martingale_trade_cnt;  // 両建てマーチンゲール手法によるトレード回数
    double trade_max_volume;
    CArrayDouble all_settlement_profit_list;  // 全決済時トータル損益履歴配列
    CArrayDouble clear_lot_profit_list;  // ポジション調整時トータル損益履歴配列（調整後との調整金額）
    CArrayDouble clear_lot_benefit_list;  // ポジション調整時トータル損益履歴配列（利益分）
    CArrayDouble clear_lot_losscut_list;  // ポジション調整時トータル損益履歴配列（損失分）
};

class ExpertMartingale {
    public:
        static void ExpertMartingale::InitEntryStruct();
        static void ExpertMartingale::InitTradeAnalysisStruct();
        static void ExpertMartingale::PrintTradeAnalysis();
        static int ExpertMartingale::MainLoop();
        static int ExpertMartingale::TradeOrder(bool isNextBuying);
        static int ExpertMartingale::OrderRetcode(bool is_open);
        static int ExpertMartingale::CalcSegPoint(double latest_price);
        static double ExpertMartingale::CalcRevenue(int seg_point);
        static double ExpertMartingale::CalcRevenueByProfitOrLoss(int seg_point, bool is_benefit_flag);
        static double ExpertMartingale::CalcVolumeByTradeCount(int trade_num);
        static int ExpertMartingale::CalcNextTradeSegPoint();
        static int ExpertMartingale::SettlementAllPosition();
        static int ExpertMartingale::ClearLot();

    public:
        static EntryStruct ExpertMartingale::entry_struct;
        static TradeAnalysisStruct ExpertMartingale::trade_analysis_struct;
};

void ExpertMartingale::InitEntryStruct() {
    ExpertMartingale::entry_struct.buying_num = 0;
    ExpertMartingale::entry_struct.selling_num = 0;
    ExpertMartingale::entry_struct.base_point = INIT_BASE_POINT;
    ExpertMartingale::entry_struct.init_price = 0.0;
    ExpertMartingale::entry_struct.clear_lot_num = 0;
    ExpertMartingale::entry_struct.latest_position_trade_datetime = TimeLocal();
}

void ExpertMartingale::InitTradeAnalysisStruct() {
    ExpertMartingale::trade_analysis_struct.order_error_cnt = 0;
    ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt = 0;
    ExpertMartingale::trade_analysis_struct.martingale_trade_cnt = 0;
    ExpertMartingale::trade_analysis_struct.trade_max_volume = 0.0;
}

void ExpertMartingale::PrintTradeAnalysis() {
    Print(StringFormat("[SUMMARY] トレードリクエストの失敗回数=%d", ExpertMartingale::trade_analysis_struct.order_error_cnt));
    Print(StringFormat("[SUMMARY] 全決済リクエストの失敗回数=%d", ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt));

    int all_settlement_cnt = ExpertMartingale::trade_analysis_struct.all_settlement_profit_list.Total();
    PrintFormat("[SUMMARY] 両建てマーチンゲール手法による取引回数: %d, 決済回数: %d, 最大トレードロット数: %f", ExpertMartingale::trade_analysis_struct.martingale_trade_cnt, all_settlement_cnt, ExpertMartingale::trade_analysis_struct.trade_max_volume);

    int all_settlement_benefit_cnt = 0;
    double all_settlement_total_benefit = 0.0;
    int all_settlement_loss_cnt = 0;
    double all_settlement_total_loss = 0.0;
    double all_settlement_total_profit = 0.0;
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
    }
    PrintFormat("[SUMMARY] [全決済履歴] total=%f, 利益: %d, avg=%f, 損失: %d, avg=%f", 
                all_settlement_total_profit, 
                all_settlement_benefit_cnt, all_settlement_total_benefit / all_settlement_benefit_cnt, 
                all_settlement_loss_cnt, all_settlement_total_loss / all_settlement_loss_cnt
    );

    int clear_lot_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_profit_list.Total();
    int clear_lot_benefit_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_benefit_list.Total();
    int clear_lot_losscut_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.Total();
    PrintFormat("[SUMMARY] [ポジション調整履歴] ポジション調整数: %d 利益調整数: %d, 損失調整数: %d", clear_lot_cnt, clear_lot_benefit_cnt, clear_lot_losscut_cnt);

    double total_profit = GetTotalSettlementProfit();
    PrintFormat("[SUMMARY] 現在までの累積損益：%f円", total_profit);

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
    PrintFormat("[SUMMARY] [ポジション調整履歴] 利益: %d, avg=%f, 損失: %d, avg=%f", 
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
