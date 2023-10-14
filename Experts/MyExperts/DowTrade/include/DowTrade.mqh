int NO_TREND = 0;
int RISING_TREND = 1;
int DOWN_TREND = 2;
int BOX_TREND = 3;
#define MAGIC_NUMBER 123457

struct TrendStruct
{
    int flag;  // トレンドフラグ 0：なし、1: 上昇トレンド、2：下降トレンド、3：ボックス相場
    datetime checked_datetime;  // 直近のトレンド検知した日時
};

class DowTrade {
    public:
        static bool DowTrade::IsLongBoxTrend();
        static int DowTrade::MainLoop();
        static int DowTrade::PredictTrendVectorAfterBoxTrend(CArrayDouble &price_list);
        static int DowTrade::CreateTradeRequestByTrendVector(MqlTradeRequest &request, int trend_vector);
    private:
        

    public:
        
        static TrendStruct DowTrade::trend_struct;

        static int DowTrade::too_short_ima_handle;
        static int DowTrade::short_ima_handle;
        static int DowTrade::middle_ima_handle;
        static int DowTrade::long_ima_handle;
};