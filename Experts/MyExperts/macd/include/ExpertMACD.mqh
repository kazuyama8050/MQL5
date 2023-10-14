#include <MyInclude\MyTechnical\MyMACD.mqh>

#define DEFAULT_MACD_LIST_BUFFER 20
#define DEFAULT_TRADE_ACTION_DEAL 3  //デフォルト注文時価格の最大偏差（スリッページ）
#define MAGIC_NUMBER 111111

struct MACDHandlerStruct
{
    MyMACD* macd_handler_15_min;
};

struct MACDLastTradeStruct
{
    datetime last_datetime;
};


class ExpertMACD {
    public:
        static int ExpertMACD::Init();
        static int ExpertMACD::InitOnMainLoop();
        static int ExpertMACD::MainLoop();
        static bool ExpertMACD::MainTrade(const double signal);
        static bool ExpertMACD::CreateTradeRequest(MqlTradeRequest &request, double signal);
    public:
        static MACDListStruct ExpertMACD::macd_list_struct_of_15_min;
        static MACDHandlerStruct ExpertMACD::macd_handler_struct;
        static MACDLastTradeStruct ExpertMACD::macdLastTrade;
        
};