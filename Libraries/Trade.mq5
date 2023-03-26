//+------------------------------------------------------------------+
//|                                                         test.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| My function                                                      |
//+------------------------------------------------------------------+

int PrintTradeResponseMessage(MqlTradeResult &order_response) export {
    int response_code = order_response.retcode;
    string response_message;
    int is_success;

    switch (response_code) {
        case TRADE_RETCODE_DONE:
            response_message = "取引は成功しました。";
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

    PrintFormat("%s", response_message);

    if (response_code == TRADE_RETCODE_DONE) {
        is_success = 1;
        PrintFormat("Success Buy symbol = %s volume = %d price = %d", Symbol(), order_response.volume, order_response.price);
    } else {
        is_success = 0;
        PrintFormat("retcode=%u  deal=%I64u  order=%I64u",response_code,order_response.deal,order_response.order);
    }

    return is_success;
}


