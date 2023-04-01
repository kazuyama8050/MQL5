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
    int response_code = order_response.retcode;
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