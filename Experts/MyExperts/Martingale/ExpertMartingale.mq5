#include <Object.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>
#include <MyInclude\MyCommon\MyDatetime.mqh>
#include "include/ExpertMartingale.mqh"

#import "MyLibraries/Trade.ex5"
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    double GetTotalSettlementProfit();
    double GetAllPositionProfit();
    double GetSettlementProfit(ulong deal_ticket);
    int GetTotalSettlementProfitList(CArrayDouble &profit_list);
    bool SettlementTrade(MqlTradeRequest &settlement_request, MqlTradeResult &settlement_response, ulong position_ticket, string comment);
    bool SettlementTradeByVolume(MqlTradeRequest &settlement_request, MqlTradeResult &settlement_response, ulong position_ticket, double volume, string comment);
#import
#import "MyLibraries/Indicator.ex5"
    int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
#import
#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintDebug(const string log_str);
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
    int SearchAndMailFromLog(datetime target_date, string expert_name, string sig, string title);
    int DeleteOlderLogFile(datetime target_date);
#import

#import "MyLibraries/Datetime.ex5"
    datetime MinusDayForDatetime(datetime target_datetime, uint exchange_day);
    int GetDayOfWeekFromDatetime(datetime target_datetime);
#import

input group "ロジック閾値"
input double MARTIGALE_PIPS = 0.2;
input int MARTINGALE_MAX_COUNT = 4;
input double INITIAL_VOLUME = 0.01;
input int LONG_TRADE_PROFIT_POINT = 100000;

input group "初期化ハンドル"
input bool IS_INIT_OF_ENTRY_STRUCT = false;
input bool IS_INIT_OF_TRADE_ANALYST_STRUCT = false;

input group "外部シグナル"
input bool IS_FORCE_STOPPED = false;

string EXPERT_NAME = "ExpertMartingale";

static EntryStruct ExpertMartingale::entry_struct;
static TradeAnalysisStruct ExpertMartingale::trade_analysis_struct;

CMyTrade myTrade;


int ExpertMartingale::TradeOrder(int next_trade_flag) {
    int trade_cnt = ExpertMartingale::entry_struct.buying_num + ExpertMartingale::entry_struct.selling_num;
    const double volume = ExpertMartingale::CalcVolumeByTradeCount(trade_cnt + 1);
    string trade_comment = "売り";
    if (next_trade_flag == IS_BUYING) {
        trade_comment = "買い";
    }
    ENUM_ORDER_TYPE order_type;
    double price;
    if (next_trade_flag == IS_BUYING) {  // 買い注文
        order_type = ORDER_TYPE_BUY;
        price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    } else if (next_trade_flag == IS_SELLING) {  // 売り注文
        order_type = ORDER_TYPE_SELL;
        price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    }
    const string comment = StringFormat("[%d回目]%s : %f * %f", ExpertMartingale::trade_analysis_struct.martingale_trade_cnt+1, trade_comment, volume, price);

    if (!myTrade.PositionOpen(Symbol(), order_type, volume, price, 0, 0, comment)) {
        return 0;
    }
    return 1;
}

int ExpertMartingale::OrderRetcode(bool is_open, bool all_settlement_flag = false) {
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

    ExpertMartingale::PlusOrderErrorCount();
    if (all_settlement_flag == true) {
        return 0;
    }
    ExpertMartingale::SettlementAllPosition();
    PrintError("注文エラーのため全決済して異常終了");
    return 0;
}

int ExpertMartingale::MainLoop() {
    // ロジックバグ
    if (MathAbs(ExpertMartingale::GetBuyingNum() - ExpertMartingale::GetSellingNum()) > 1) {
        PrintError(StringFormat("ロジックバグ : ロング、ショートで交互にトレードされていない可能性あり, buying_num: %d, selling_num: %d", ExpertMartingale::GetBuyingNum(), ExpertMartingale::GetSellingNum()));
        return 0;
    }
    CArrayDouble price_15_list;
    GetClosePriceList(price_15_list, Symbol(), PERIOD_M15, 10);

    int next_trade_flag = ExpertMartingale::GetNextTradeFlag();
    if (next_trade_flag != IS_BUYING && next_trade_flag != IS_SELLING) {
        PrintError(StringFormat("ロジックバグ : 次回トレードフラグが買い・売り以外, next_trade_flag: %d", next_trade_flag));
        return 0;
    }

    int trade_cnt = ExpertMartingale::GetTradeNum();
    if (trade_cnt > 0 && ExpertMartingale::HasInitTradeFlag() == false) {
        PrintError(StringFormat("ロジックバグ : ポジション保有済みだが初期トレードフラグが未定義, trade_cnt: %d, init_trade_flag: %d", trade_cnt, ExpertMartingale::GetInitTradeFlag()));
    }

    // 保有ポジションがなく、強制停止シグナルがある場合は終了
    if (trade_cnt == 0 && IS_FORCE_STOPPED) {
        ExpertMartingale::SettlementAllPosition();
        PrintNotice("強制終了シグナルを受け取り、ポジションなしのため全決済");
        ExpertMartingale::PrintTradeAnalysis();
        PrintNotice(StringFormat("Force Stopped Flag Thrown, so Finished ExpertMartingale, symbol: %s", Symbol()));
        ForceStopEa();
        return 1;
    }

    // トレード実績がない場合はとりあえず買いトレード
    if (trade_cnt == 0) {
        // 注文
        ExpertMartingale::TradeOrder(next_trade_flag);
        int order_retcode = ExpertMartingale::OrderRetcode(true);
        if (order_retcode == 0) {
            return 0;
        }
        if (order_retcode == 2) return 1;  // 市場閉鎖によりスキップ

        ExpertMartingale::SetInitTradeFlag(next_trade_flag);  // 初回トレードフラグ設定
        if (next_trade_flag == IS_BUYING) {
            ExpertMartingale::PlusBuyingNum();
        } else {
            ExpertMartingale::PlusSellingNum();
        }
        
        ExpertMartingale::SetBasePoint(0);  //初回トレード価格を基準とする
        ExpertMartingale::SetInitPrice(myTrade.ResultPrice());  // 初回トレード価格
        ExpertMartingale::PlusMartingaleTradeCount();
        ExpertMartingale::SetLatestPositionTradeDatetime(TimeLocal());
        return 1;
    }

    int seg_point = ExpertMartingale::CalcSegPoint(price_15_list[0]);  // 現在のセグポイント
    bool is_revenue = ExpertMartingale::CalcRevenue(seg_point) >= INITIAL_VOLUME;

    // セグポイントでの計算上、トータルで利益が出ていれば全決済
    if (is_revenue) {
        if (ExpertMartingale::SettlementAllPosition() == 0) {
            PrintError("全決済異常エラーのため異常終了");
            return 0;
        }
        if (PositionsTotal() > 0) {
            PrintWarn(StringFormat("全決済後にポジションが残っている, total=%d", PositionsTotal()));
        }
        ExpertMartingale::InitEntryStruct();
        return 1;
    }

    int next_seg_point = ExpertMartingale::CalcNextTradeSegPoint();  // 次のトレードのセグポイント
    if ((next_trade_flag == IS_BUYING && next_seg_point <= 0) ||
        (next_trade_flag == IS_SELLING && next_seg_point >= 0))
    {
        PrintError("セグポイント計算にバグの可能性があるため終了");
        return 0;
    }

    // 連続トレードが指定回数+1を超える && 最新ポジショントレード日時が1日以前 && 利益が初期ボリューム*LONG_TRADE_PROFIT_POINTの場合、全決済
    if (trade_cnt >= MARTINGALE_MAX_COUNT + 1 && 
        ExpertMartingale::GetLatestPositionTradeDatetime() < TimeLocal() - ONE_DATE_DATETIME && 
        GetAllPositionProfit() > INITIAL_VOLUME * LONG_TRADE_PROFIT_POINT
    ) {
        PrintNotice("ロット数多、1日以上経過、利益が出ているため全決済");
        if (ExpertMartingale::SettlementAllPosition() == 0) {
            PrintError("全決済異常エラーのため異常終了");
            return 0;
        }
        if (PositionsTotal() > 0) {
            PrintError(StringFormat("全決済後にポジションが残っている, total=%d", PositionsTotal()));
            return 0;
        }
        ExpertMartingale::InitEntryStruct();
        return 1;
    }

    // 次が買いトレードの場合は、現在のセグメントが次トレードのセグメント以上
    // 次が売りトレードの場合は、現在のセグメントが次トレードのセグメント以下
    // 上記いずれかを満たす場合、注文
    if ((next_trade_flag == IS_BUYING && seg_point >= next_seg_point) || 
        (next_trade_flag == IS_SELLING && seg_point <= next_seg_point))
    {
        // 連続トレードが指定回数を超えるとロット数を調整する
        if (trade_cnt >= MARTINGALE_MAX_COUNT) {
            if (!ExpertMartingale::ClearLot()) {
                ExpertMartingale::SettlementAllPosition();
                PrintError("ポジション調整失敗のため全決済して異常終了");
                return 0;
            }
        }

        // 注文
        ExpertMartingale::TradeOrder(next_trade_flag);
        int order_retcode = ExpertMartingale::OrderRetcode(true);
        if (order_retcode == 0) {
            return 0;
        }

        if (order_retcode == 2) return 1;  // 市場閉鎖によりスキップ

        if (next_trade_flag == IS_BUYING) {
            ExpertMartingale::PlusBuyingNum();
        } else {
            ExpertMartingale::PlusSellingNum();
        }
        
        ExpertMartingale::SetBasePoint(next_seg_point);  // これは必要か？
        ExpertMartingale::PlusMartingaleTradeCount();
        ExpertMartingale::SetLatestPositionTradeDatetime(TimeLocal());
        return 1;
    }

    return 1;
}

/**　ポジション整理
 * 
**/
int ExpertMartingale::ClearLot() {
    // 利益分のポジション調整
    int total_position = PositionsTotal();
    double total_benefit = 0.0;
    for (int i = 0; i < total_position; i++) {
        ulong  position_ticket = PositionGetTicket(i);
        PositionSelectByTicket(position_ticket);
        double position_volume = PositionGetDouble(POSITION_VOLUME);
        double position_profit = PositionGetDouble(POSITION_PROFIT);

        if (position_ticket == 0 || position_volume == 0.0) continue;

        if (position_profit >= 0) {  // 利益を出しているポジションは決済確定
            string comment = StringFormat("[ポジション調整] 利益分、チケット=%d", position_ticket);
            myTrade.PositionClose(position_ticket, ULONG_MAX, comment);
            int order_retcode = ExpertMartingale::OrderRetcode(false);
            if (order_retcode == 0) {
                ExpertMartingale::PlusOrderErrorCount();
                PrintWarn(StringFormat("ポジション調整失敗（利益）, チケット=%d", position_ticket));
                return 0;
            }

            if (order_retcode == 2) continue;  // 市場閉鎖によりスキップ

            double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
            total_benefit += deal_profit;
            ExpertMartingale::AddClearLotBenefitList(deal_profit);
            
        }
    }

    // 損失分のポジション調整
    total_position = PositionsTotal();
    for (int i = 0; i < total_position; i++) {
        ulong  position_ticket = PositionGetTicket(i);
        PositionSelectByTicket(position_ticket);
        double position_volume = PositionGetDouble(POSITION_VOLUME);
        double position_profit = PositionGetDouble(POSITION_PROFIT);

        if (position_ticket == 0 || position_volume == 0.0) continue;

        // 利益が発生しているポジションは基本ないはず
        // あったとしても無視で良い
        if (position_profit >= 0) {
            continue;
        }

        // トータル利益額より損失額が小さい場合は全てのロットを決済
        if (MathAbs(position_profit) <= total_benefit) {
            string comment = StringFormat("[ポジション調整] 損失分、チケット=%d", position_ticket);
            myTrade.PositionClose(position_ticket, ULONG_MAX, comment);
            int order_retcode = ExpertMartingale::OrderRetcode(false);
            if (order_retcode == 0) {
                ExpertMartingale::PlusOrderErrorCount();
                PrintError(StringFormat("ポジション調整失敗（損失）, チケット=%d / all", position_ticket));
                return 0;
            }

            if (order_retcode == 2) continue;

            double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
            total_benefit += deal_profit;
            ExpertMartingale::AddClearLotLosscutList(deal_profit);
            continue;
        }

        // トータル利益より損失額が大きい場合は最小限の利益が出る範囲で既存損失ポジションを部分決済
        int divide_volume_cnt = (int)(position_volume / INITIAL_VOLUME);  // 最小ロット数で分割できる数
        double divide_position_profit = position_profit / divide_volume_cnt;  // 最小ロット分の損失
        double settlement_volume = (int)(total_benefit / MathAbs(divide_position_profit)) * INITIAL_VOLUME;  // ポジション整理対象ロット数
        if (settlement_volume > position_volume) {
            settlement_volume = position_volume;
        }

        if (settlement_volume < INITIAL_VOLUME) continue;

        string comment = StringFormat("[ポジション調整]損失分、チケット=%d, %f/%f", position_ticket, settlement_volume, position_volume);
        myTrade.PositionClose(position_ticket, ULONG_MAX, settlement_volume, comment);
        int order_retcode = ExpertMartingale::OrderRetcode(false);
        if (order_retcode == 0) {
            ExpertMartingale::PlusOrderErrorCount();
            PrintError(StringFormat("ポジション調整失敗（損失）, チケット=%d, %f/%f", position_ticket, settlement_volume, position_volume));
            return 0;
        }

        if (order_retcode == 2) continue;

        double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
        total_benefit += deal_profit;
        ExpertMartingale::AddClearLotLosscutList(deal_profit);
                
    }

    ExpertMartingale::AddClearLotProfitList(total_benefit);


    return 1;
}

/** ポジション全決済
 * return int 決済数
**/
int ExpertMartingale::SettlementAllPosition() {
    int ret_cnt = 0;
    double total_revenue = 0.0;
    while (true)  {
        int total_position = PositionsTotal();
        for (int i = 0; i < total_position; i++) {
            // PositionGetTicket(i)だとポジションチケットを取得できないことがある
            if (!PositionSelect(Symbol())) continue;// 対象シンボルのポジションをチケット番号が最も古いものを取得する
            ulong position_ticket = PositionGetInteger(POSITION_TICKET);
            if (position_ticket == 0) continue;
            if (!myTrade.PositionClose(position_ticket, ULONG_MAX, "全決済")) {
                
                continue;
            }

            int order_retcode = ExpertMartingale::OrderRetcode(false, true);
            if (order_retcode == 0) {
                ExpertMartingale::PlusAllSettlementOrderErrorCount();
                PrintError(StringFormat("全決済失敗のためやり直し, error_position: %d", position_ticket));
                break;  // 決済失敗のためやり直し
            }
            if (order_retcode == 2) {
                PrintWarn(StringFormat("市場閉鎖による全決済失敗のため時間を置いてやり直し, error_position: %d", position_ticket));
                break;  // 市場閉鎖によりやり直し
            }

            double position_profit = PositionGetDouble(POSITION_PROFIT);
            double position_volume = PositionGetDouble(POSITION_VOLUME);
            
            ret_cnt += 1;
            total_revenue += GetSettlementProfit(myTrade.ResultDeal());

            if (position_volume > ExpertMartingale::GetTradeMaxVolume()) {
                ExpertMartingale::SetTradeMaxVolume(position_volume);
            }
        }

        if (PositionsTotal() == 0) {
            break;
        }
        PrintWarn("全決済完了しなかったため再度実行");
        Sleep(3600*10);
    }
    
    if (total_revenue < 0) {
        PrintWarn(StringFormat("損失発生、損益=%f", total_revenue));
    }
    ExpertMartingale::AddAllSettlementProfitList(total_revenue);

    return ret_cnt;
}


/**
 * 初回トレード判定ロジック
 * return int 買い: 1 売り: -1 それ以外: 0
**/
int ExpertMartingale::CalcFirstTradeTrend() {
    return 1;
}

double ExpertMartingale::CalcVolumeByTradeCount(int trade_num) {
    if (trade_num < 1) return 0.0;
    return INITIAL_VOLUME * MathPow(2, trade_num-1);
}

double ExpertMartingale::CalcRevenue(int seg_point) {
    int trade_cnt = ExpertMartingale::GetTradeNum();
    int init_trade_flag = ExpertMartingale::GetInitTradeFlag();
    int base_seg_point = 0;  // トレード時点の基準ポイント
    double revenue = 0;
    bool is_benefit = false;

    if (init_trade_flag == 0) {
        return revenue;
    }
    
    // 初回トレードフラグによって、基準ポイントの基準が変わる
    // is_benefit: 差が0の場合はpriceの計算が0になるので考慮しない
    for (int i = 0;i < trade_cnt;i++) {
        if (init_trade_flag == IS_BUYING) {
            if (i == 0) {  // 初回トレード
                base_seg_point = INIT_BASE_POINT;
                is_benefit = base_seg_point <= seg_point;
            }else if (i % 2 == 0) { // 偶数が買い
                base_seg_point = INIT_BASE_POINT + i - 1;
                is_benefit = base_seg_point <= seg_point;
            } else {
                base_seg_point = INIT_BASE_POINT - i;
                is_benefit = base_seg_point >= seg_point;
            }

        } else if (init_trade_flag == IS_SELLING) {
            if (i == 0) {  // 初回トレード
                base_seg_point = INIT_BASE_POINT;
                is_benefit = base_seg_point >= seg_point;
            }else if (i % 2 == 0) { // 偶数が売り
                base_seg_point = INIT_BASE_POINT - i + 1;
                is_benefit = base_seg_point >= seg_point;
            } else {
                base_seg_point = INIT_BASE_POINT + i;
                is_benefit = base_seg_point <= seg_point;
            }
        }

        // 現在のポイントとトレード時点の基準ポイントの差 * volume
        double total_volume = ExpertMartingale::CalcVolumeByTradeCount(i+1);
        double price = MathAbs(seg_point - base_seg_point) * total_volume;
        
        if (is_benefit) {
            revenue += price;
        } else {
            revenue -= price;
        }
    }
    return revenue;
}

int ExpertMartingale::CalcNextTradeSegPoint() {
    int next_trade_flag = ExpertMartingale::GetNextTradeFlag();
    int init_trade_flag = ExpertMartingale::GetInitTradeFlag();
    int next_seg_point = 0;

    // 初回トレードによって基準価格の初期値が変わる
    if (next_trade_flag == IS_BUYING) {
        next_seg_point = ExpertMartingale::GetBuyingNum();
        if (init_trade_flag == IS_SELLING) {
            next_seg_point += 1;
        }
    } else {
        next_seg_point = 0 - (ExpertMartingale::GetSellingNum());
        if (init_trade_flag == IS_BUYING) {
            next_seg_point -= 1;
        }
    }
    return next_seg_point;
}

int ExpertMartingale::CalcSegPoint(double latest_price) {
    double seg_price = latest_price - ExpertMartingale::GetInitPrice();
    return (int)(seg_price / MARTIGALE_PIPS);
}

int ExpertMartingale::GetNextTradeFlag() {
    if (ExpertMartingale::GetBuyingNum() == ExpertMartingale::GetSellingNum()) {  // 買い回数と売り回数が一致する場合
        if (ExpertMartingale::HasInitTradeFlag()) {   // 初回トレード情報あり
            return ExpertMartingale::GetInitTradeFlag();
        } else {  // 初回トレード情報なし
            if (ExpertMartingale::GetTradeNum() > 0) {
                PrintWarn(StringFormat("Undefined init_trade_flag, but has positions, buying_num: %d, selling_num: %d", ExpertMartingale::entry_struct.buying_num, ExpertMartingale::entry_struct.selling_num));
            }
            return ExpertMartingale::CalcFirstTradeTrend();
        }
    } else {
        if (ExpertMartingale::GetBuyingNum() > ExpertMartingale::GetSellingNum()) {
            return IS_SELLING;
        } else {
            return IS_BUYING;
        }
    }
    PrintError("Maybe Logic Bug By Calc IsNextBuying");
    return IS_BUYING;
}

void OnInit() {
    PrintNotice(StringFormat("Start ExpertMartingale, symbol: %s", Symbol()));

    EventSetTimer(ONE_DATE_DATETIME); //1日間隔でタイマーイベントを呼び出す
    if (IS_INIT_OF_ENTRY_STRUCT) {
        ExpertMartingale::InitEntryStruct();
        PrintNotice("Entry構造体を初期化しました");
    } else {
        PrintNotice("Entry初期化を初期化しませんでした");
    }

    if (IS_INIT_OF_TRADE_ANALYST_STRUCT) {
        ExpertMartingale::InitTradeAnalysisStruct();
        PrintNotice("TradeAnalyst構造体を初期化しました");
    } else {
        PrintNotice("TradeAnalyst初期化を初期化しませんでした");
    }

    if (IS_FORCE_STOPPED) {
        PrintNotice("ポジションがなくなり次第強制終了します。");
    }
    
    myTrade.SetAsyncMode(false);
    myTrade.SetExpertMagicNumber(MAGIC_NUMBER);
    myTrade.SetTypeFilling(ORDER_FILLING_IOC);
}

void OnTick() {
    if (!ExpertMartingale::MainLoop()) {
        ExpertMartingale::PrintTradeAnalysis();
        PrintError(StringFormat("Exception Thrown, so Finished ExpertMartingale, symbol: %s", Symbol()));
        ForceStopEa();
        return;
    }
    Sleep(3600*1); // 1分スリープ
}

void OnTimer() {
    ExpertMartingale::PrintTradeAnalysis();
    if (!SearchAndMailFromLog(MinusDayForDatetime(TimeLocal(), 1), EXPERT_NAME, "ERROR,WARN", "バグ検知_daily")) {
        PrintError("バグ検知_dailyのメール送信失敗");
    }
    if (!SearchAndMailFromLog(MinusDayForDatetime(TimeLocal(), 1), EXPERT_NAME, "SUMMARY", "サマリー_daily")) {
        PrintError("サマリー_dailyのメール送信失敗");
    }
    DeleteOlderLogFile(MinusDayForDatetime(TimeLocal(), 30));
}

void OnDeinit() {

}