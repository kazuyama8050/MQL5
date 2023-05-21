#define DEFAULT_TRADE_ACTION_DEAL 3  //デフォルト注文時価格の最大偏差（スリッページ）
#define TREND_CHECK_TERM 15  // トレンド継続確認期間
#define MAGIC_NUMBER 123456
#define COMMON_PERIOD PERIOD_M15 //期間（15分足）

#define TOO_SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_RAPID_CHANGE 0.25
#define SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_BOX_TREND 0.03
#define MIDDLE_MA_STANDARD_DEVIATION_VALUE_FOR_BOX_TREND 0.04
#define SHORT_MA_STANDARD_DEVIATION_VALUE_FOR_RAPID_CHANGE 0.04

#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayDouble.mqh>



class ExpertIma {
    public:
        bool ExpertIma::MainLoop();
        int ExpertIma::MaTrade();
        bool ExpertIma::CreateTradeRequest(MqlTradeRequest &request, double signal);
        int ExpertIma::CheckAfterMaTrade(ulong position_ticket);
        int ExpertIma::PrintTimerReport();
    public:
        static int ExpertIma::too_short_ima_handle; // 超短期移動平均線
        static int ExpertIma::short_ima_handle; // 短期移動平均線
        static int ExpertIma::middle_ima_handle; //中期移動平均線
        static int ExpertIma::long_ima_handle; //長期移動平均線
        static int ExpertIma::trade_error_cnt; //注文エラー回数
        static int ExpertIma::loss_cut_total_num; //トータル強制決済回数
        static datetime ExpertIma::ma_trade_last_datetime; //移動平均を用いたラストトレード日時
        static ulong ExpertIma::ma_trade_last_position_ticket; //移動平均を用いた最新取引のポジションチケット番号
        static int ExpertIma::ma_trade_num;  //移動平均トレードによる注文回数
        static int ExpertIma::ma_settlement_num;  //移動平均トレードによる騙し判定回数
    protected:
       
    private:
        // static int m_ima_handle;
        // static string short_name;

    private:
        static int ExpertIma::PrintCurrentPriceAndMaDiffResult();
        
};