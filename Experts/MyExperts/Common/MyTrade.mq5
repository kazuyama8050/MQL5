#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include "include/MyTrade.mqh"

static int MyTrade::PrintTradeResponseMessage(MqlTradeResult &order_response) {
    int response_code = order_response.retcode;
    string response_message;

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

    if (response_code != TRADE_RETCODE_DONE) {
        PrintFormat("retcode=%u  deal=%I64u  order=%I64u",response_code,order_response.deal,order_response.order);
    }

    return 1;
}
