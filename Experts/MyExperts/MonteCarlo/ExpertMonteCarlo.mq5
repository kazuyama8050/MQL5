#include <Object.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>
#include <MyInclude\MyTrade\MySymbolInfo.mqh>
#include <MyInclude\MyCommon\MyDatetime.mqh>
#include <MyInclude\MyAccount\MyAccountInfo.mqh>
#include <MyInclude\MyFile\MyLogHandler.mqh>
#include "include/ExpertMonteCarlo.mqh";

#import "MyLibraries/Trade.ex5"
    int GetPositionNumByTargetEa(string symbol, long magic_number);
#import

#import "MyLibraries/Indicator.ex5"
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    double GetLatestClosePrice(string symbol, ENUM_TIMEFRAMES timeframe);
#import

#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintDebug(const string log_str);
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
#import

string EXPERT_NAME = "ExpertMonteCarlo";

input double BASE_LOT = 0.01;  // 基準ロット数
input double BASE_PIPS = 0.2;  // 勝敗基準PIPS
long MAGIC_NUMBER = 100000;

CMyTrade myTrade;
CMySymbolInfo mySymbolInfo;
CMyAccountInfo myAccountInfo;
MyLogHandler myLogHandler(
    EXPERT_NAME,
    myAccountInfo.TradeModeDescription(),
    myAccountInfo.Name()
);

int tradeFlag = IS_BUYING;

static MonteCarloStruct ExpertMonteCarlo::monte_carlo_struct;
static TradeAnalysisStruct ExpertMonteCarlo::trade_analysis_struct;
static bool is_failed_settlement_by_closed = false;


int ExpertMonteCarlo::TradeOrder(int next_trade_flag) {
    double volume = ExpertMonteCarlo::CalcAdditionalVal() * BASE_LOT;
    string trade_comment = "売り";
    if (next_trade_flag == IS_BUYING) {
        trade_comment = "買い";
    }
    ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
    double price = 0.0;
    if (next_trade_flag == IS_BUYING) {  // 買い注文
        order_type = ORDER_TYPE_BUY;
        price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    } else if (next_trade_flag == IS_SELLING) {  // 売り注文
        order_type = ORDER_TYPE_SELL;
        price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    }
    const string comment = StringFormat("[%d回目] %s : %.2f * %.5f", ArraySize(ExpertMonteCarlo::trade_analysis_struct.monte_carlo_histories), trade_comment, volume, price);

    if (!myTrade.PositionOpen(Symbol(), order_type, volume, price, 0, 0, comment)) {
        return 0;
    }
    return 1;
}

int ExpertMonteCarlo::OrderRetcode(bool is_open) {
    uint retcode = myTrade.ResultRetcode();
    if (retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL) {
        string is_open_str = (is_open) ? "Open" : "Close";
        PrintNotice(StringFormat("ポジション %s comment: request=%s, result=%s", is_open_str, myTrade.RequestComment(), myTrade.ResultComment()));
        return 1;
    }
    if (retcode == TRADE_RETCODE_MARKET_CLOSED) {
        PrintWarn("市場閉鎖による取引失敗");
        Sleep(3600*60);  // 1時間スリープ
        return 2;
    }

    PrintError("注文エラーのため異常終了");
    return 0;
}

int ExpertMonteCarlo::SettlementPosition() {
    if (ExpertMonteCarlo::GetPositionTicket() == 0) {
        PrintError("ポジションチケットが異常です");
        return 0;
    }

    string comment = StringFormat("決済: ポジション: %d", ExpertMonteCarlo::GetPositionTicket());
    myTrade.PositionClose(ExpertMonteCarlo::GetPositionTicket(), ULONG_MAX, comment);

    int order_retcode = ExpertMonteCarlo::OrderRetcode(false);
    if (order_retcode == 0) {
        PrintError(StringFormat("決済失敗のためやり直し, error_position: %d", ExpertMonteCarlo::GetPositionTicket()));
        return 0;
    }
    if (order_retcode == 2) {
        PrintWarn(StringFormat("市場閉鎖による決済失敗のため時間を置いてやり直し, error_position: %d", ExpertMonteCarlo::GetPositionTicket()));
        // Sleep(3600*60);  // 1時間スリープ
        is_failed_settlement_by_closed = true;
        return 1;
    }

    

    double position_profit = PositionGetDouble(POSITION_PROFIT);
    if (is_failed_settlement_by_closed == false) {
        ExpertMonteCarlo::AddPositionProfitHistory(ExpertMonteCarlo::GetPositionTicket(), position_profit);
        ExpertMonteCarlo::AddProfitList(position_profit);
    } else {
        is_failed_settlement_by_closed = false;
    }
    
    

    ExpertMonteCarlo::ReplacePositionTicket(0);
    ExpertMonteCarlo::ReplacePositionPrice(0);
    
    if (position_profit >= 0) {
        ExpertMonteCarlo::OperateByBenefit();
    } else {
        ExpertMonteCarlo::OperateByLoss();
    }

    return 1;
}


static int ExpertMonteCarlo::MainLoop()
{
    if (ExpertMonteCarlo::GetMonteCarloSize() == 0) {
        ExpertMonteCarlo::ProgitListToMonteCarloHistory();
        ExpertMonteCarlo::InitProfitList();
        ExpertMonteCarlo::InitMonteCarlo();
    }

    if (ExpertMonteCarlo::GetMonteCarloSize() == 1) {
        ExpertMonteCarlo::DecomposeMonteCarlo();
    }
    
    // if (GetPositionNumByTargetEa(Symbol(), MAGIC_NUMBER) == 0) {  // ポジション取得
    if (ExpertMonteCarlo::GetPositionTicket() == 0) {  // ポジションを持っていない場合
        int next_trade_flag = IS_BUYING;
        // if (MathRand() % 2 == 0) {
        if (tradeFlag == IS_BUYING) {
            next_trade_flag = IS_SELLING;
        }
        ExpertMonteCarlo::TradeOrder(next_trade_flag);
        tradeFlag = next_trade_flag;
        int order_retcode = ExpertMonteCarlo::OrderRetcode(true);
        if (order_retcode == 0) {
            return 0;
        }
        if (order_retcode == 2) { return 1; }  // 市場閉鎖によりスキップ
        ExpertMonteCarlo::ReplacePositionTicket(myTrade.ResultOrder());
        ExpertMonteCarlo::ReplacePositionPrice(myTrade.ResultPrice());
    }

    double now_price = GetLatestClosePrice(Symbol(), PERIOD_M15);
    if (MathAbs(now_price - ExpertMonteCarlo::GetPositionPrice()) >= BASE_PIPS) {  // ポジション決済
        int ret = ExpertMonteCarlo::SettlementPosition();
        if (ret == 0) { return 0; }
    }

    return 1;
    
}

void OnInit() {
    EventSetTimer(ONE_DATE_DATETIME); //1日間隔でタイマーイベントを呼び出す
    PrintNotice(StringFormat("Start ExpertMonteCarlo, symbol: %s", Symbol()));
    ExpertMonteCarlo::InitMonteCarlo();
    ExpertMonteCarlo::InitProfitList();
    MathSrand(GetTickCount());
}

void OnTick() {
    int main_loop_cnt = 0;
    uint main_loop_total_sec = 0;
    uint start = GetTickCount();
    if (!ExpertMonteCarlo::MainLoop()) {
        PrintError(StringFormat("Exception Thrown, so Finished symbol: %s", Symbol()));
        ForceStopEa();
        return;
    }

    if (main_loop_cnt % 100 == 0) {
        // if (myAccountInfo.MarginLevel() < GetTradeMinMarginRate() && myAccountInfo.MarginLevel() > 0) {
        //     SetTradeMinMarginRate(myAccountInfo.MarginLevel());
        // }

        if (main_loop_cnt > 0 && (main_loop_total_sec / main_loop_cnt) > 100) {
            PrintWarn(StringFormat("Total MainLoop Count = %d, Avg MiliSecond = %d", main_loop_cnt, main_loop_total_sec));
        }
    }

    main_loop_cnt += 1;
    main_loop_total_sec += GetTickCount() - start;
    Sleep(3600*1); // 1分スリープ
}

void OnTimer() {
    ExpertMonteCarlo::PrintTradeAnalyst();
}

void OnDeinit() {
}