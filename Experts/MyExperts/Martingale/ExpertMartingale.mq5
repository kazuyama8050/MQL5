#include <Object.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <Trade\Trade.mqh>
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


int ExpertMartingale::TradeOrder(bool is_next_buying) {
    int trade_cnt = ExpertMartingale::entry_struct.buying_num + ExpertMartingale::entry_struct.selling_num;
    const double volume = ExpertMartingale::CalcVolumeByTradeCount(trade_cnt + 1);
    string trade_comment = "売り";
    if (is_next_buying) {
        trade_comment = "買い";
    }
    ENUM_ORDER_TYPE order_type;
    double price;
    if (is_next_buying == true) {  // 買い注文
        order_type = ORDER_TYPE_BUY;
        price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    } else if (is_next_buying == false) {  // 売り注文
        order_type = ORDER_TYPE_SELL;
        price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    }
    const string comment = StringFormat("[%d回目]%s : %f * %f", ExpertMartingale::trade_analysis_struct.martingale_trade_cnt+1, trade_comment, volume, price);

    if (!myTrade.PositionOpen(Symbol(), order_type, volume, price, 0, 0, comment)) {
        return 0;
    }
    return 1;
}

int ExpertMartingale::OrderRetcode() {
    uint retcode = myTrade.ResultRetcode();
    if (retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL) {
        return 1;
    }
    if (retcode == TRADE_RETCODE_MARKET_CLOSED) {
        Print("[WARN] 市場閉鎖による取引失敗");
        Sleep(3600*60);  // 1時間スリープ
        return 2;
    }

    ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
    ExpertMartingale::SettlementAllPosition();
    Print("[ERROR] 注文エラーのため全決済して異常終了");
    return 0;
}

int ExpertMartingale::MainLoop() {
    // ロジックバグ
    if (MathAbs(ExpertMartingale::entry_struct.buying_num - ExpertMartingale::entry_struct.selling_num) > 1) {
        Print("[ERROR] ロジックバグ");
        return 0;
    }
    CArrayDouble price_15_list;
    GetClosePriceList(price_15_list, Symbol(), PERIOD_M15, 10);

    bool is_next_buying = ExpertMartingale::entry_struct.buying_num == ExpertMartingale::entry_struct.selling_num;
    int trade_cnt = ExpertMartingale::entry_struct.buying_num + ExpertMartingale::entry_struct.selling_num;

    // トレード実績がなく、強制停止シグナルがある場合は終了
    if (trade_cnt == 0 && IS_FORCE_STOPPED) {
        ExpertMartingale::SettlementAllPosition();
        Print("[NOTICE] 強制終了シグナルを受け取ったため全決済");
        ExpertMartingale::PrintTradeAnalysis();
        PrintFormat("[NOTICE] Force Stopped Flag Thrown, so Finished ExpertMartingale, symbol: %s", Symbol());
        ForceStopEa();
        return 1;
    }

    // トレード実績がない場合はとりあえず買いトレード
    if (trade_cnt == 0) {
        // 注文
        ExpertMartingale::TradeOrder(is_next_buying);
        int order_retcode = ExpertMartingale::OrderRetcode();
        if (order_retcode == 0) {
            return 0;
        }

        if (order_retcode == 2) return 1;  // 市場閉鎖によりスキップ

        ExpertMartingale::entry_struct.buying_num += 1;
        ExpertMartingale::entry_struct.base_point = 0;  //初回トレード価格を基準とする
        ExpertMartingale::entry_struct.init_price = myTrade.ResultPrice();  // 初回トレード価格
        ExpertMartingale::trade_analysis_struct.martingale_trade_cnt += 1;
        ExpertMartingale::entry_struct.latest_position_trade_datetime = TimeLocal();
        return 1;
    }

    int seg_point = ExpertMartingale::CalcSegPoint(price_15_list[0]);  // 現在のセグポイント
    bool is_revenue = ExpertMartingale::CalcRevenue(seg_point) > 0;
    

    // トータルで利益が出ていれば全決済
    if (is_revenue) {
        if (ExpertMartingale::SettlementAllPosition() == 0) {
            Print("[ERROR] 全決済異常エラーのため異常終了");
            return 0;
        }
        if (PositionsTotal() > 0) {
            PrintFormat("[WARN] 全決済後にポジションが残っている, total=%d", PositionsTotal());
        }
        ExpertMartingale::InitEntryStruct();
        return 1;
    }

    int next_seg_point = ExpertMartingale::CalcNextTradeSegPoint();  // 次のトレードのセグポイント
    if ((is_next_buying == true && next_seg_point <= 0) ||
        (is_next_buying == false && next_seg_point >= 0))
    {
        Print("[ERROR] セグポイント計算にバグの可能性があるため終了");
        return 0;
    }


    // 連続トレードが指定回数+1を超える && 最新ポジショントレード日時が1日以前 && 利益が初期ボリューム*LONG_TRADE_PROFIT_POINTの場合、全決済
    if (trade_cnt >= MARTINGALE_MAX_COUNT + 1 && 
        ExpertMartingale::entry_struct.latest_position_trade_datetime < TimeLocal() - ONE_DATE_DATETIME && 
        GetAllPositionProfit() > INITIAL_VOLUME * LONG_TRADE_PROFIT_POINT
    ) {
        Print("[NOTICE] ロット数多、1日以上経過、利益が出ているため全決済");
        if (ExpertMartingale::SettlementAllPosition() == 0) {
            Print("[ERROR] 全決済異常エラーのため異常終了");
            return 0;
        }
        if (PositionsTotal() > 0) {
            PrintFormat("[ERROR] 全決済後にポジションが残っている, total=%d", PositionsTotal());
            return 0;
        }
        ExpertMartingale::InitEntryStruct();
        return 1;
    }

    // 次が買いトレードの場合は、現在のセグメントが次トレードのセグメント以上
    // 次が売りトレードの場合は、現在のセグメントが次トレードのセグメント以下
    // 上記いずれかを満たす場合、注文
    if ((is_next_buying == true && seg_point >= next_seg_point) || 
        (is_next_buying == false && seg_point <= next_seg_point))
    {
        // 連続トレードが指定回数を超えるとロット数を調整する
        if (trade_cnt >= MARTINGALE_MAX_COUNT) {
            if (!ExpertMartingale::ClearLot()) {
                ExpertMartingale::SettlementAllPosition();
                Print("[ERROR] ポジション調整失敗のため全決済して異常終了");
                return 0;
            }
        }


        // 注文
        ExpertMartingale::TradeOrder(is_next_buying);
        int order_retcode = ExpertMartingale::OrderRetcode();
        if (order_retcode == 0) {
            return 0;
        }

        if (order_retcode == 2) return 1;  // 市場閉鎖によりスキップ

        if (is_next_buying == true) {
            ExpertMartingale::entry_struct.buying_num += 1;
        } else {
            ExpertMartingale::entry_struct.selling_num += 1;
        }
        
        ExpertMartingale::entry_struct.base_point = next_seg_point;
        ExpertMartingale::trade_analysis_struct.martingale_trade_cnt += 1;
        ExpertMartingale::entry_struct.latest_position_trade_datetime = TimeLocal();
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
            int order_retcode = ExpertMartingale::OrderRetcode();
            if (order_retcode == 0) {
                ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
                PrintFormat("[WARN] ポジション調整失敗（利益）, チケット=%d", position_ticket);
                return 0;
            }

            if (order_retcode == 2) continue;  // 市場閉鎖によりスキップ

            double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
            total_benefit += deal_profit;
            ExpertMartingale::trade_analysis_struct.clear_lot_benefit_list.Add(deal_profit);
            
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
            int order_retcode = ExpertMartingale::OrderRetcode();
            if (order_retcode == 0) {
                ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
                PrintFormat("[ERROR] ポジション調整失敗（損失）, チケット=%d / all", position_ticket);
                return 0;
            }

            if (order_retcode == 2) continue;

            double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
            total_benefit += deal_profit;
            ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.Add(deal_profit);
            continue;
        }

        int divide_volume_cnt = (int)(position_volume / INITIAL_VOLUME);  // 最小ロット数で分割できる数
        double divide_position_profit = position_profit / divide_volume_cnt;  // 最小ロット分の損失
        double settlement_volume = (int)(total_benefit / MathAbs(divide_position_profit)) * INITIAL_VOLUME;  // ポジション整理対象ロット数
        if (settlement_volume > position_volume) {
            settlement_volume = position_volume;
        }

        if (settlement_volume < INITIAL_VOLUME) continue;

        string comment = StringFormat("[ポジション調整]損失分、チケット=%d / %f", position_ticket, settlement_volume);
        myTrade.PositionClose(position_ticket, ULONG_MAX, settlement_volume, comment);
        int order_retcode = ExpertMartingale::OrderRetcode();
        if (order_retcode == 0) {
            ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
            PrintFormat("[ERROR] ポジション調整失敗（損失）, チケット=%d / %f", position_ticket, settlement_volume);
            return 0;
        }

        if (order_retcode == 2) continue;

        double deal_profit = GetSettlementProfit(myTrade.ResultDeal());
        total_benefit += deal_profit;
        ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.Add(deal_profit);
                
    }

    ExpertMartingale::trade_analysis_struct.clear_lot_profit_list.Add(total_benefit);


    return 1;
}

/** ポジション全決済
 * return int 決済数
**/
int ExpertMartingale::SettlementAllPosition() {
    int total_position = PositionsTotal();
    int ret_cnt = 0;
    double total_revenue = 0.0;

    for (int i = 0; i < total_position; i++) {
        // PositionGetTicket(i)だとポジションチケットを取得できないことがある
        if (!PositionSelect(Symbol())) continue;// 対象シンボルのポジションをチケット番号が最も古いものを取得する
        ulong position_ticket = PositionGetInteger(POSITION_TICKET);
        if (position_ticket == 0) continue;
        if (!myTrade.PositionClose(position_ticket, ULONG_MAX, "全決済")) {
            ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt += 1;
            continue;
        }

        double position_profit = PositionGetDouble(POSITION_PROFIT);
        double position_volume = PositionGetDouble(POSITION_VOLUME);
        
        ret_cnt += 1;
        total_revenue += GetSettlementProfit(myTrade.ResultDeal());

        if (position_volume > ExpertMartingale::trade_analysis_struct.trade_max_volume) {
            ExpertMartingale::trade_analysis_struct.trade_max_volume = position_volume;
        }
        
    }
    if (total_revenue <= 0) {
        Print(StringFormat("[WARN] 損失発生、損益=%f", total_revenue));
    }
    ExpertMartingale::trade_analysis_struct.all_settlement_profit_list.Add(total_revenue);

    return ret_cnt;
}

double ExpertMartingale::CalcVolumeByTradeCount(int trade_num) {
    if (trade_num < 1) return 0.0;
    return INITIAL_VOLUME * MathPow(2, trade_num-1);
}

double ExpertMartingale::CalcRevenue(int seg_point) {
    int trade_cnt = ExpertMartingale::entry_struct.buying_num + ExpertMartingale::entry_struct.selling_num;

    int base_seg_point = 0;  // トレード時点の基準ポイント
    double revenue = 0;
    bool is_benefit = false;
    double volume = 1;
    for (int i = 0;i < trade_cnt;i++) {
        if (i == 0) {  // 初回トレード
            base_seg_point = INIT_BASE_POINT;
            is_benefit = base_seg_point <= seg_point;  // 差が0の場合はpriceの計算が0になるので考慮しない
        }else if (i % 2 == 0) { // 偶数が買い
            base_seg_point = INIT_BASE_POINT + i;
            is_benefit = base_seg_point <= seg_point;  // 差が0の場合はpriceの計算が0になるので考慮しない
        } else {
            base_seg_point = INIT_BASE_POINT - i;
            is_benefit = base_seg_point >= seg_point;  // 差が0の場合はpriceの計算が0になるので考慮しない
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

/** 引数で与えられた利益 or 損失のポジションのみの概算損益を算出する
 * 引数1: 現在の基準からの価格帯
 * 引数2: 利益かどうか
**/
double ExpertMartingale::CalcRevenueByProfitOrLoss(int seg_point, bool is_benefit_flag) {
    int trade_cnt = ExpertMartingale::entry_struct.buying_num + ExpertMartingale::entry_struct.selling_num;

    int base_seg_point = 0;  // トレード時点の基準ポイント
    double revenue = 0;
    bool is_benefit = false;
    double volume = 1;
    for (int i = 0;i < trade_cnt;i++) {
        if (i == 0) {  // 初回トレード
            base_seg_point = INIT_BASE_POINT;
            is_benefit = base_seg_point < seg_point;
        }else if (i % 2 == 0) { // 偶数が買い
            base_seg_point = INIT_BASE_POINT + i;
            is_benefit = base_seg_point < seg_point;
        } else {
            base_seg_point = INIT_BASE_POINT - i;
            is_benefit = base_seg_point > seg_point;
        }

        // 現在のポイントとトレード時点の基準ポイントの差 * volume
        double total_volume = ExpertMartingale::CalcVolumeByTradeCount(i+1);
        double price = MathAbs(seg_point - base_seg_point) * total_volume;
        
        if (is_benefit == is_benefit_flag) {
            revenue += price;
        }

        if (is_benefit_flag == false) {  // 損失の場合はマイナスに変換
            revenue = revenue * -1;
        }
    }
    return revenue;
}

int ExpertMartingale::CalcNextTradeSegPoint() {
    bool is_next_buying = ExpertMartingale::entry_struct.buying_num == ExpertMartingale::entry_struct.selling_num;
    int next_seg_point = 0;
    if (is_next_buying == true) {
        next_seg_point = ExpertMartingale::entry_struct.buying_num;
    } else {
        next_seg_point = 0 - (ExpertMartingale::entry_struct.selling_num + 1);
    }
    return next_seg_point;
}

int ExpertMartingale::CalcSegPoint(double latest_price) {
    double seg_price = latest_price - ExpertMartingale::entry_struct.init_price;
    return (int)(seg_price / MARTIGALE_PIPS);
}


void OnInit() {
    PrintFormat("Start ExpertMartingale, symbol: %s", Symbol());

    EventSetTimer(ONE_DATE_DATETIME); //1日間隔でタイマーイベントを呼び出す
    if (IS_INIT_OF_ENTRY_STRUCT) {
        ExpertMartingale::InitEntryStruct();
        Print("[NOTICE] Entry構造体を初期化しました");
    } else {
        Print("[NOTICE] Entry初期化を初期化しませんでした");
    }

    if (IS_INIT_OF_TRADE_ANALYST_STRUCT) {
        ExpertMartingale::InitTradeAnalysisStruct();
        Print("[NOTICE] TradeAnalyst構造体を初期化しました");
    } else {
        Print("[NOTICE] TradeAnalyst初期化を初期化しませんでした");
    }
    
    

    myTrade.SetAsyncMode(false);
    myTrade.SetExpertMagicNumber(MAGIC_NUMBER);
    myTrade.SetTypeFilling(ORDER_FILLING_IOC);
}

void OnTick() {
    if (!ExpertMartingale::MainLoop()) {
        ExpertMartingale::PrintTradeAnalysis();
        PrintFormat("[ERROR] Exception Thrown, so Finished ExpertMartingale, symbol: %s", Symbol());
        ForceStopEa();
        return;
    }
    Sleep(3600*1); // 1分スリープ
}

void OnTimer() {
    ExpertMartingale::PrintTradeAnalysis();
}

void OnDeinit() {

}