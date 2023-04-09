//+------------------------------------------------------------------+
//|                                                         Trade.mq5 |
//|                                  Copyright 2023, Kazuki Yamasaki |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2023, Kazuki Yamasaki"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| 注文関連ライブラリ                                                  |
//+------------------------------------------------------------------+

/** 注文時のメッセージ出力
 * 引数1: MqlTradeResult構造体（注文のレスポンス）
 * return int 
**/
int PrintTradeResponseMessage(MqlTradeResult &order_response) export {
    uint response_code = order_response.retcode;
    string response_message;
    int is_success;

    switch (response_code) {
        case TRADE_RETCODE_DONE:
            break;
        case TRADE_RETCODE_REQUOTE:
            response_message = "リクオート（取引価格の再提示）されました。";
            break;
        case TRADE_RETCODE_PLACED:
            response_message = "注文が出されました。";
            break;
        case TRADE_RETCODE_PRICE_CHANGED:
            response_message = "価格が変更されました。";
            break;
        case TRADE_RETCODE_DONE_PARTIAL:
            response_message = "一部のリクエストのみ完了しました。";
            break;
        case TRADE_RETCODE_MARKET_CLOSED:
            response_message = "市場が閉鎖中です。";
            break;
        case TRADE_RETCODE_NO_MONEY:
            response_message = "資金不足です。";
            break;
        default:
            response_message = "予期せぬエラーが発生しました。";
    }

    if (response_code == TRADE_RETCODE_DONE) {
        is_success = 1;
        PrintFormat("売買成立しました。 symbol = %s volume = %f price = %f", Symbol(), order_response.volume, order_response.price);
    } else {
        is_success = 0;
        PrintFormat("売買不成立です。 > %s", response_message);
    }

    return is_success;
}

/** 注文 normal
 * 引数1: MqlTradeRequest構造体
 * 引数2: MqlTradeResult構造体
 * return bool (取引成功有無)
**/
bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response) export {
    //--- リクエストの送信
    if(!OrderSend(trade_request,order_response)) {
        PrintFormat("OrderSend error %d",GetLastError());
    }

    if (!PrintTradeResponseMessage(order_response)) {
        return false;
    }
    
    return true;
}

/** 決済
 * 引数1: MqlTradeRequest構造体
 * 引数2: MqlTradeResult構造体
 * 引数3: ポジションチケット
 * 引数4: コメント（決済に至った原因など）
 * return bool
 **/
bool SettlementTrade(MqlTradeRequest &settlement_request, MqlTradeResult &settlement_response, ulong position_ticket, string comment) export {
    PositionSelectByTicket(position_ticket);
    double position_volume = PositionGetDouble(POSITION_VOLUME);
    string position_symbol = PositionGetString(POSITION_SYMBOL);
    double position_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double position_price_current = PositionGetDouble(POSITION_PRICE_CURRENT);
    double position_profit = PositionGetDouble(POSITION_PROFIT);
    ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    settlement_request.action = TRADE_ACTION_DEAL;
    settlement_request.position = position_ticket;
    settlement_request.symbol = position_symbol;
    settlement_request.volume = position_volume;
    settlement_request.deviation = 5;
    settlement_request.comment = comment;

    if (position_type == POSITION_TYPE_BUY) {
        settlement_request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
        settlement_request.type = ORDER_TYPE_SELL;
    } else if (position_type == POSITION_TYPE_SELL) {
        settlement_request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
        settlement_request.type = ORDER_TYPE_BUY;
    } else {
        return false;
    }

    if (!TradeOrder(settlement_request, settlement_response)) {
        return false;
    }
    return true;
}

/** 損切りポイント判定関数 損切りの場合true
 * 引数1：ポジションシンボル
 * 引数2：ポジション価格
 * 引数3：%表示を小数点で渡す（例：5%なら0.05）
 * 引数4：ポジションタイプ
 * 買いポジションならx%以上の下落、売りポジションならx%以上の上昇で損切り判定
 * return bool (損切り判定ならtrue)
**/
bool IsLossCutPosition(string position_symbol, double position_price, double rule_percent, ENUM_POSITION_TYPE position_type) export {
    double dead_price;
    double symbol_price = SymbolInfoDouble(position_symbol, TICK_FLAG_LAST);  // シンボルの現在価格

    if (position_type == POSITION_TYPE_BUY) {
        dead_price = position_price * (1 - rule_percent);
        if (dead_price >= symbol_price) {
            return true;
        }
    } else {
        dead_price = position_price * (1 + rule_percent);
        if (dead_price <= symbol_price) {
            return true;
        }
    }
    return false;
}

/** 騙し判定関数 騙し判定の場合true 
 * 引数1: ポジションチケット番号
 * 引数2: 騙し判定許容パーセンテージ
 * return bool
**/
bool IsDeceptionTrade(ulong position_ticket, double allowed_percent) export {
    if (!PositionSelectByTicket(position_ticket)) {
        return false;
    }

    double position_price = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double current_symbol_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    
    //ポジション価格が現在価格と比べて許容オーバー
    if (position_type == POSITION_TYPE_BUY) {
        if (position_price * (1 - allowed_percent) > current_symbol_price) {
            return true;
        }
    } else if (position_type == POSITION_TYPE_SELL) {
        if (position_price * (1 + allowed_percent) < current_symbol_price) {
            return true;
        }
    }
    return false;
}