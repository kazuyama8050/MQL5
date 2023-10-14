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
};

struct TradeAnalysisStruct
{
    int order_error_cnt;  // トレードリクエストエラー回数
    int all_settlement_order_error_cnt;  // 全決済リクエストエラー回数
    int martingale_trade_cnt;  // 両建てマーチンゲール手法によるトレード回数
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
        static int ExpertMartingale::CreateTradeRequest(MqlTradeRequest &request, bool isNextBuying);
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