#define DEFAULT_VOLUME 0.01  //デフォルト注文ボリューム
#define DEFAULT_TRADE_ACTION_DEAL 5  //デフォルト注文時価格の最大偏差
#define DEFAULT_FORCE_LOSS_CUT_LINE 0.01
#define MAGIC_NUMBER 123456
#define COMMON_PERIOD PERIOD_M15 //期間（15分足）

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