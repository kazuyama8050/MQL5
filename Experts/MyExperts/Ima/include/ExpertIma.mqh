#define DEFAULT_TRADE_ACTION_DEAL 3  //デフォルト注文時価格の最大偏差（スリッページ）
#define TREND_CHECK_TERM 15  // トレンド継続確認期間
#define MAGIC_NUMBER 123456
#define COMMON_PERIOD PERIOD_M15 //期間（15分足）

#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayDouble.mqh>

#include <MyInclude\MyFundamental\MyCalendarEvent.mqh>

// 最新の移動平均取引情報構造体
struct MaLastTradeStruct
{
    datetime last_datetime;  //移動平均を用いたラストトレード日時
    ulong last_position_ticket;  //移動平均を用いた最新取引のポジションチケット番号
};

//移動平均取引集計情報構造体
struct MaTradeAggregatorStruct
{
    int trade_num;  //移動平均トレードによる注文回数
    int settlement_num_by_deception;  //移動平均トレードの騙し判定決済回数
    int settlement_num_by_trend_checker;  //移動平均トレードのトレンド変化による決済回数
    int settlement_num_by_ma_signal;  // 移動平均トレードのシグナル検知による決済回数
};

// 全取引集計情報構造体
struct TradeAggregatorStruct
{
    int loss_cut_total_num; //トータル強制決済回数
    int trade_error_cnt; //注文エラー回数
};

class ExpertIma {
    public:
        bool ExpertIma::MainLoop();
        int ExpertIma::MaTrade();
        bool ExpertIma::CreateTradeRequest(MqlTradeRequest &request, double signal);
        int ExpertIma::CheckAfterMaTrade(ulong position_ticket);
        int ExpertIma::PrintTimerReport();
        int ExpertIma::GetMyCalendarEvent(MyCalendarEvent &my_calendar_event_list[]);
        bool ExpertIma::CheckNonTradeDatetime(MyCalendarEvent &calendar_event_list[], ENUM_CALENDAR_EVENT_IMPORTANCE event_importance, datetime target_datetime);
        int ExpertIma::SettlementTradeForAllPosition();
    public:
        static int ExpertIma::too_short_ima_handle; // 超短期移動平均線
        static int ExpertIma::short_ima_handle; // 短期移動平均線
        static int ExpertIma::middle_ima_handle; //中期移動平均線
        static int ExpertIma::long_ima_handle; //長期移動平均線
        static MaLastTradeStruct ExpertIma::ma_last_trade_struct;  // 移動平均による最新取引情報構造体
        static MaTradeAggregatorStruct ExpertIma::ma_trade_aggregator_struct;  //移動平均による取引集計情報構造体
        static TradeAggregatorStruct ExpertIma::trade_aggregator_struct;  // 取引集計情報構造体
        MyCalendarEvent ExpertIma::my_calendar_event_list[];  // イベントカレンダークラスリスト
    private:
        // static int m_ima_handle;
        // static string short_name;

    private:
        static int ExpertIma::PrintCurrentPriceAndMaDiffResult();
        
};