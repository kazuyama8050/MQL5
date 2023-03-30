#include <Object.mqh>
#include <Trade\Trade.mqh>
#import "Trade.ex5"
    int PrintTradeResponseMessage(MqlTradeResult &order_response);
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    bool IsLossCutPosition(string position_symbol, double position_price, double rule_percent, ENUM_POSITION_TYPE position_type);
#import

class MyLossCutTrade {
    public:
        MyLossCutTrade();
        ~MyLossCutTrade();
        int MyLossCutTrade::ClosePositionByLossCutRule(double loss_cut_line);
    private:
        bool MyLossCutTrade::CreateLossCutTradeRequest(string position_symbol, int position_type, ulong position_ticket, double position_volume);
        
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MyLossCutTrade::MyLossCutTrade()
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MyLossCutTrade::~MyLossCutTrade()
  {
  }

/** 損切りラインに達すると強制決済
 * 引数1: 損切りライン（5%なら0.05）
 * return 強制決済数
**/
int MyLossCutTrade::ClosePositionByLossCutRule(double loss_cut_line) {
    int total_position = PositionsTotal();  //保有ポジション数
    int loss_cut_num = 0;

    for (int i = 0; i <= total_position; i++) {
        ulong  position_ticket = PositionGetTicket(i);       // ポジションチケット
        double position_volume = PositionGetDouble(POSITION_VOLUME); // ポジションボリューム
        string position_symbol = PositionGetString(POSITION_SYMBOL);  //ポジションシンボル
        double position_price = PositionGetDouble(POSITION_PRICE_OPEN); // ポジション価格
        ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);   // ポジションタイプ

        // 損切りの場合そのポジションを決済する
        if (IsLossCutPosition(position_symbol, position_price, loss_cut_line, position_type)) {
            Print("損切り判定されました。");
            if (CreateLossCutTradeRequest(position_symbol, position_type, position_ticket, position_volume)) {
                loss_cut_num += 1;
                PrintFormat("%f％以上の損失を出したため強制損切りしました。 symbol=%s, position_type=%d, position_ticket=%d, position_volume=%f", 
                            loss_cut_line * 100, position_symbol, position_type, position_ticket, position_volume);
            }
        }

    }
    return loss_cut_num;
}

bool MyLossCutTrade::CreateLossCutTradeRequest(string position_symbol, int position_type, ulong position_ticket, double position_volume) {
    MqlTradeRequest close_request={};
    MqlTradeResult close_result={};

    close_request.action = TRADE_ACTION_DEAL;
    close_request.position = position_ticket;
    close_request.symbol = position_symbol;
    close_request.volume = position_volume;
    close_request.deviation = 5;

    if (position_type == POSITION_TYPE_BUY) {
        close_request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
        close_request.type = ORDER_TYPE_SELL;
    } else {
        close_request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
        close_request.type = ORDER_TYPE_BUY;
    }

    if (!TradeOrder(close_request, close_result)) {
        return false;
    }
    return true;
}