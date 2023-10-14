#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\List.mqh>
#include <MyInclude\MyCommon\MyDatetime.mqh>
#include "include/ExpertMartingale.mqh"

#import "Trade.ex5"
    bool TradeOrder(MqlTradeRequest &trade_request, MqlTradeResult &order_response);
    double GetTotalSettlementProfit();
    double GetSettlementProfit(ulong deal_ticket);
    int GetTotalSettlementProfitList(CArrayDouble &profit_list);
    bool SettlementTrade(MqlTradeRequest &settlement_request, MqlTradeResult &settlement_response, ulong position_ticket, string comment);
    bool SettlementTradeByVolume(MqlTradeRequest &settlement_request, MqlTradeResult &settlement_response, ulong position_ticket, double volume, string comment);
#import
#import "Indicator.ex5"
    int GetVolumeList(CArrayLong &volume_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
    int GetClosePriceList(CArrayDouble &price_list, string symbol, ENUM_TIMEFRAMES timeframe, int shift);
#import
#import "Common.ex5"
    void ForceStopEa();
#import

double MARTIGALE_PIPS = 0.2;
int MARTINGALE_MAX_COUNT = 4;
double INITIAL_VOLUME = 0.01;

static EntryStruct ExpertMartingale::entry_struct;
static TradeAnalysisStruct ExpertMartingale::trade_analysis_struct;

int ExpertMartingale::CreateTradeRequest(MqlTradeRequest &request, bool is_next_buying) {
    double volume_deviation = 0.5;
    int trade_cnt = ExpertMartingale::entry_struct.buying_num + ExpertMartingale::entry_struct.selling_num;

    //--- リクエストのパラメータ
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.deviation = volume_deviation;
    request.magic = MAGIC_NUMBER;
    request.volume = ExpertMartingale::CalcVolumeByTradeCount(trade_cnt + 1);

    string trade_comment = "売り";
    if (is_next_buying) {
        trade_comment = "買い";
    }
    
    if (is_next_buying == true) {  // 買い注文
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
    } else if (is_next_buying == false) {  // 売り注文
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
    }
    request.comment = StringFormat("[%d回目]%s : %f * %f", ExpertMartingale::trade_analysis_struct.martingale_trade_cnt+1, trade_comment, request.volume, request.price);

    // PrintFormat("volume=%f, type=%d, price=%f",request.volume, request.type, request.price);
    return 1;
}

int ExpertMartingale::MainLoop() {
    // ロジックバグ
    if (MathAbs(ExpertMartingale::entry_struct.buying_num - ExpertMartingale::entry_struct.selling_num) > 1) {
        Print("ロジックバグ");
        return 0;
    }
    CArrayDouble price_15_list;
    GetClosePriceList(price_15_list, Symbol(), PERIOD_M15, 10);

    bool is_next_buying = ExpertMartingale::entry_struct.buying_num == ExpertMartingale::entry_struct.selling_num;
    int trade_cnt = ExpertMartingale::entry_struct.buying_num + ExpertMartingale::entry_struct.selling_num;

    // トレード実績がない場合はとりあえず買いトレード
    if (trade_cnt == 0) {
        // 注文
        MqlTradeRequest trade_request={};
        MqlTradeResult trade_result={};
        if (!ExpertMartingale::CreateTradeRequest(trade_request, is_next_buying)) {
            return 0;
        } 
        if (!TradeOrder(trade_request, trade_result)) {
            ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
            ExpertMartingale::SettlementAllPosition();
            Print("注文エラーのため全決済して異常終了");
            return 0;
        }
        ExpertMartingale::entry_struct.buying_num += 1;
        ExpertMartingale::entry_struct.base_point = 0;  //初回トレード価格を基準とする
        ExpertMartingale::entry_struct.init_price = trade_result.price;  // 初回トレード価格
        ExpertMartingale::trade_analysis_struct.martingale_trade_cnt += 1;
        return 1;
    }

    int seg_point = ExpertMartingale::CalcSegPoint(price_15_list[0]);  // 現在のセグポイント
    bool is_revenue = ExpertMartingale::CalcRevenue(seg_point) > 0;
    

    // トータルで利益が出ていれば全決済
    if (is_revenue) {
        Print("全決済");
        if (ExpertMartingale::SettlementAllPosition() == 0) {
            Print("全決済異常エラーのため異常終了");
            return 0;
        }
        if (PositionsTotal() > 0) {
            PrintFormat("全決済後にポジションが残っている, total=%d", PositionsTotal());
            return 0;
        }
        ExpertMartingale::InitEntryStruct();
        return 1;
    }

    int next_seg_point = ExpertMartingale::CalcNextTradeSegPoint();  // 次のトレードのセグポイント
    if ((is_next_buying == true && next_seg_point <= 0) ||
        (is_next_buying == false && next_seg_point >= 0))
    {
        Print("セグポイント計算にバグの可能性があるため終了");
        return 0;
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
                Print("ポジション調整失敗のため全決済して異常終了");
                return 0;
            }
        }


        // 注文
        MqlTradeRequest trade_request={};
        MqlTradeResult trade_result={};
        if (!ExpertMartingale::CreateTradeRequest(trade_request, is_next_buying)) {
            return 0;
        } 
        if (!TradeOrder(trade_request, trade_result)) {
            ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
            ExpertMartingale::SettlementAllPosition();
            Print("注文エラーのため全決済して異常終了");
            return 0;
        }
        if (is_next_buying == true) {
            ExpertMartingale::entry_struct.buying_num += 1;
        } else {
            ExpertMartingale::entry_struct.selling_num += 1;
        }
        
        ExpertMartingale::entry_struct.base_point = next_seg_point;
        ExpertMartingale::trade_analysis_struct.martingale_trade_cnt += 1;
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
            string comment = StringFormat("[ポジション調整]利益分、チケット=%d", position_ticket);
            MqlTradeRequest settlement_request={};
            MqlTradeResult settlement_result={};
            if (!SettlementTrade(settlement_request, settlement_result, position_ticket, comment)) {
                ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
                PrintFormat("[ERROR] ポジション調整失敗（利益）, チケット=%d", position_ticket);
                return 0;
            }

            double deal_profit = GetSettlementProfit(settlement_result.deal);
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

        // トータル利益より損失額が小さい場合は全てのロットを決済
        if (position_profit <= total_benefit) {
            MqlTradeRequest settlement_request={};
            MqlTradeResult settlement_result={};
            string comment = StringFormat("[ポジション調整]損失分、チケット=%d / all", position_ticket);

            if (!SettlementTrade(settlement_request, settlement_result, position_ticket, comment)) {
                ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
                PrintFormat("[ERROR] ポジション調整失敗（損失）, チケット=%d / all");
                return 0;
            }
            double deal_profit = GetSettlementProfit(settlement_result.deal);
            total_benefit += deal_profit;
            ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.Add(deal_profit);
            continue;
        }

        int divide_volume_cnt = (int)(position_volume / INITIAL_VOLUME);  // 最小ロット数で分割できる数
        double divide_position_profit = position_profit / divide_volume_cnt;  // 最小ロット分の損失
        double settlement_volume = (int)(total_benefit / divide_position_profit) * INITIAL_VOLUME;  // ポジション整理対象ロット数
        if (settlement_volume > position_volume) {
            settlement_volume = position_volume;
        }

        MqlTradeRequest settlement_request={};
        MqlTradeResult settlement_result={};
        string comment = StringFormat("[ポジション調整]損失分、チケット=%d / %d", position_ticket, settlement_volume);

        if (!SettlementTradeByVolume(settlement_request, settlement_result, position_ticket, settlement_volume, comment)) {
            ExpertMartingale::trade_analysis_struct.order_error_cnt += 1;
            PrintFormat("[ERROR] ポジション調整失敗（損失）, チケット=%d / %d", position_ticket, settlement_volume);
            return 0;
        }
        double deal_profit = GetSettlementProfit(settlement_result.deal);
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

        MqlTradeRequest settlement_request={};
        MqlTradeResult settlement_result={};

        double position_profit = PositionGetDouble(POSITION_PROFIT);
        string comment = StringFormat("[全決済] チケット=%d, %f", position_ticket, position_profit);

        if (!SettlementTrade(settlement_request, settlement_result, position_ticket, comment)) {
            ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt += 1;
            continue;
        }

        ret_cnt += 1;
        total_revenue += GetSettlementProfit(settlement_result.deal);
        
    }
    if (total_revenue <= 0) {
        Print(StringFormat("[WARN]損失発生、損益=%f", total_revenue));
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

void ExpertMartingale::InitEntryStruct() {
    ExpertMartingale::entry_struct.buying_num = 0;
    ExpertMartingale::entry_struct.selling_num = 0;
    ExpertMartingale::entry_struct.base_point = INIT_BASE_POINT;
    ExpertMartingale::entry_struct.init_price = 0.0;
    ExpertMartingale::entry_struct.clear_lot_num = 0;
}

void ExpertMartingale::InitTradeAnalysisStruct() {
    ExpertMartingale::trade_analysis_struct.order_error_cnt = 0;
    ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt = 0;
    ExpertMartingale::trade_analysis_struct.martingale_trade_cnt = 0;
}

void OnInit() {
    Print("Start");
    EventSetTimer(ONE_DATE_DATETIME); //1日間隔でタイマーイベントを呼び出す
    ExpertMartingale::InitEntryStruct();
    ExpertMartingale::InitTradeAnalysisStruct();
}

void OnTick() {
    if (!ExpertMartingale::MainLoop()) {
        ExpertMartingale::PrintTradeAnalysis();
        ForceStopEa();
        return;
    }
    Sleep(3600*1); // 1分スリープ
}

void OnTimer() {
    ExpertMartingale::PrintTradeAnalysis();
}

void ExpertMartingale::PrintTradeAnalysis() {
    Print(StringFormat("トレードリクエストの失敗回数=%d", ExpertMartingale::trade_analysis_struct.order_error_cnt));
    Print(StringFormat("全決済リクエストの失敗回数=%d", ExpertMartingale::trade_analysis_struct.all_settlement_order_error_cnt));

    int all_settlement_cnt = ExpertMartingale::trade_analysis_struct.all_settlement_profit_list.Total();
    PrintFormat("両建てマーチンゲール手法による取引回数: %d, 決済回数: %d", ExpertMartingale::trade_analysis_struct.martingale_trade_cnt, all_settlement_cnt);

    int all_settlement_benefit_cnt = 0;
    double all_settlement_total_benefit = 0.0;
    int all_settlement_loss_cnt = 0;
    double all_settlement_total_loss = 0.0;
    double all_settlement_total_profit = 0.0;
    for (int i = 0;i < all_settlement_cnt;i++) {
        double all_settlement_profit = ExpertMartingale::trade_analysis_struct.all_settlement_profit_list.At(i);
        if (all_settlement_profit >= 0) {
            all_settlement_benefit_cnt += 1;
            all_settlement_total_benefit += all_settlement_profit;
        } else {
            all_settlement_loss_cnt += 1;
            all_settlement_total_loss += all_settlement_profit;
        }
        all_settlement_total_profit += all_settlement_profit;
    }
    PrintFormat("[全決済履歴] total=%f, 利益: %d, avg=%f, 損失: %d, avg=%f", 
                all_settlement_total_profit, 
                all_settlement_benefit_cnt, all_settlement_total_benefit / all_settlement_benefit_cnt, 
                all_settlement_loss_cnt, all_settlement_total_loss / all_settlement_loss_cnt
    );

    int clear_lot_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_profit_list.Total();
    int clear_lot_benefit_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_benefit_list.Total();
    int clear_lot_losscut_cnt = ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.Total();
    PrintFormat("[ポジション調整履歴] ポジション調整数: %d 利益調整数: %d, 損失調整数: %d", clear_lot_cnt, clear_lot_benefit_cnt, clear_lot_losscut_cnt);

    double total_profit = GetTotalSettlementProfit();
    PrintFormat("現在までの累積損益：%f円", total_profit);

    int clear_lot_final_benefit_cnt = 0;
    int clear_lot_final_losscut_cnt = 0;
    double clear_lot_final_total_benefit = 0.0;
    double clear_lot_final_total_losscut = 0.0;
    for (int i = 0;i < clear_lot_cnt;i++) {
        double clear_lot_final_profit = ExpertMartingale::trade_analysis_struct.clear_lot_profit_list.At(i);
        if (clear_lot_final_profit >= 0) {
            clear_lot_final_benefit_cnt += 1;
            clear_lot_final_total_benefit += clear_lot_final_profit;
        } else {
            clear_lot_final_losscut_cnt += 1;
            clear_lot_final_total_losscut += clear_lot_final_profit;
        }
    }
    PrintFormat("[ポジション調整履歴] 利益: %d, avg=%f, 損失: %d, avg=%f", 
                clear_lot_final_benefit_cnt, clear_lot_final_total_benefit / clear_lot_final_benefit_cnt, 
                clear_lot_final_losscut_cnt, clear_lot_final_total_losscut / clear_lot_final_losscut_cnt
    );


    int clear_lot_benefit_but_loss_cnt = 0;
    for (int i = 0;i < clear_lot_benefit_cnt;i++) {
        if (ExpertMartingale::trade_analysis_struct.clear_lot_benefit_list.At(i) < 0) {
            clear_lot_benefit_but_loss_cnt += 1;
        }
    }

    // 損失ポジションでポジション調整したが実際は利益だった回数
    int clear_lot_losscut_but_benefit_cnt = 0;
    for (int i = 0;i < clear_lot_losscut_cnt;i++) {
        if (ExpertMartingale::trade_analysis_struct.clear_lot_losscut_list.At(i) > 0) {
            clear_lot_losscut_but_benefit_cnt += 1;
        }
    }

    PrintFormat("[ポジション調整 バグ可能性] 利益ポジションでポジション調整したが実際は損失だった回数: %d", clear_lot_benefit_but_loss_cnt);
    PrintFormat("[ポジション調整 バグ可能性] 損失ポジションでポジション調整したが実際は利益だった回数: %d", clear_lot_losscut_but_benefit_cnt);
}

void OnDeinit() {

}