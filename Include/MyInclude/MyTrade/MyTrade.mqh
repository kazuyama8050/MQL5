#include <Object.mqh>
#include <Trade\Trade.mqh>
#import "Trade.ex5"
    int PrintTradeResponseMessage(MqlTradeResult &order_response);
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    bool IsLossCutPosition(string position_symbol, double position_price, double rule_percent ENUM_POSITION_TYPE position_type);
#import

#define PRICE_DIFF_MEAN_OF_15_MINUTES 0.065

class MyTrade {
    public:
};

