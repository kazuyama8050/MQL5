#include <Arrays\ArrayInt.mqh>

int IS_BUYING = 1;
int IS_SELLING = -1;
int IS_NOTRADE = 0;

/** ポジション情報を保持する構造体
 * この構造体の配列を扱うことになる
 * 
**/
struct PositionStruct
{
    ulong ticket;  // ポジションチケット
    int trade_flag; // 売買フラグ 買い:1 売り:-1、未設定:0
    double price;  // ポジション価格
    double volume;  // ポジションロット数
    datetime trade_datetime;  // トレード日時
    bool is_valid;  // 保有ポジションかどうか
};

/** 全ポジション情報を保持する構造体
 * 全決済によりポジション数がなくなったらリセットする
 * 
**/
struct PositionsStruct
{
    PositionStruct positions[];  // 一つのポジション情報の配列
    double martingale_pips;  // 書き負け判定基準PIPS
    int buying_num;  // 買った回数（決済済み含む）
    int selling_num;  // 売った回数（決済済み含む）
    int position_num;  // 保有ポジション数（未決済のみ）
    int clear_lot_num;  // ポジション整理回数
    double profit;  // この構造体が生きてる間の損益（分析用）
    double all_settlement_base_price;  // 全決済基準価格（トレンド判定なしで全決済ロジックに該当した時に本来全決済されるレート）
};

struct MonteCarloStruct
{
    ulong position_ticket;
    double position_price;
    CArrayInt matrix_array;
    CArrayDouble profit_list;
};

struct MonteCarloHistoryStruct
{
    ulong latest_position_ticket;
    double profit;
};

struct PositionHistoryStruct
{
    ulong position_ticket;
    double profit;
};

struct TradeAnalysisStruct
{
    MonteCarloHistoryStruct monte_carlo_histories[];
    PositionHistoryStruct position_histories[];
};

class ExpertMonteCarlo
{
    public:
        static MonteCarloStruct ExpertMonteCarlo::monte_carlo_struct;
        static TradeAnalysisStruct ExpertMonteCarlo::trade_analysis_struct;

    public:
        static int ExpertMonteCarlo::MainLoop();
        static int ExpertMonteCarlo::TradeOrder(int next_trade_flag);
        static int ExpertMonteCarlo::OrderRetcode(bool is_open);
        static int ExpertMonteCarlo::SettlementPosition();


        static ulong ExpertMonteCarlo::GetPositionTicket() { return ExpertMonteCarlo::monte_carlo_struct.position_ticket; }
        static double ExpertMonteCarlo::GetPositionPrice() { return ExpertMonteCarlo::monte_carlo_struct.position_price; }

        static void ExpertMonteCarlo::ReplacePositionTicket(ulong ticket) {
            ExpertMonteCarlo::monte_carlo_struct.position_ticket = ticket;
        }
        static void ExpertMonteCarlo::ReplacePositionPrice(double price) {
            ExpertMonteCarlo::monte_carlo_struct.position_price = price;
        }

        static int ExpertMonteCarlo::GetMonteCarloSize() {
            return ExpertMonteCarlo::monte_carlo_struct.matrix_array.Total();
        }

        static int ExpertMonteCarlo::CalcAdditionalVal() {
            int size = ExpertMonteCarlo::GetMonteCarloSize();
            return ExpertMonteCarlo::monte_carlo_struct.matrix_array.At(0) + ExpertMonteCarlo::monte_carlo_struct.matrix_array.At(size-1);
        }

        static void ExpertMonteCarlo::InitMonteCarlo() {
            ExpertMonteCarlo::monte_carlo_struct.matrix_array.Shutdown();
            ExpertMonteCarlo::monte_carlo_struct.matrix_array.Add(0);
            ExpertMonteCarlo::monte_carlo_struct.matrix_array.Add(1);
        }

        static void ExpertMonteCarlo::DecomposeMonteCarlo() {
            int size = ExpertMonteCarlo::GetMonteCarloSize();
            if (size != 1) { return; }
            int number = ExpertMonteCarlo::monte_carlo_struct.matrix_array.At(0);
            ExpertMonteCarlo::monte_carlo_struct.matrix_array.Shutdown();
            if (number % 2 == 0) {
                ExpertMonteCarlo::monte_carlo_struct.matrix_array.Add((int)number/2);
                ExpertMonteCarlo::monte_carlo_struct.matrix_array.Add((int)number/2);
            } else {
                ExpertMonteCarlo::monte_carlo_struct.matrix_array.Add((int)(number/2));
                ExpertMonteCarlo::monte_carlo_struct.matrix_array.Add((int)(number/2)+1);
            }
        }

        static void ExpertMonteCarlo::OperateByBenefit() {
            int size = ExpertMonteCarlo::GetMonteCarloSize();
            ExpertMonteCarlo::monte_carlo_struct.matrix_array.Delete(size-1);
            ExpertMonteCarlo::monte_carlo_struct.matrix_array.Delete(0);
        }

        static void ExpertMonteCarlo::OperateByLoss() {
            ExpertMonteCarlo::monte_carlo_struct.matrix_array.Add(ExpertMonteCarlo::CalcAdditionalVal());
        }

        static void ExpertMonteCarlo::AddProfitList(double profit) {
            ExpertMonteCarlo::monte_carlo_struct.profit_list.Add(profit);
        }
        static int ExpertMonteCarlo::GetProfitListSize() { return ExpertMonteCarlo::monte_carlo_struct.profit_list.Total(); }
        static void ExpertMonteCarlo::InitProfitList() { ExpertMonteCarlo::monte_carlo_struct.profit_list.Shutdown(); }

        static void ExpertMonteCarlo::ProgitListToMonteCarloHistory() {
            double total_profit = 0;
            for (int i = 0; i < ExpertMonteCarlo::GetProfitListSize(); i++) {
                total_profit += ExpertMonteCarlo::monte_carlo_struct.profit_list.At(i);
            }
            
            MonteCarloHistoryStruct monteCarloHistoryStruct;
            monteCarloHistoryStruct.latest_position_ticket = ExpertMonteCarlo::trade_analysis_struct.position_histories[ArraySize(ExpertMonteCarlo::trade_analysis_struct.position_histories)-1].position_ticket;
            monteCarloHistoryStruct.profit = total_profit;
            int size = ArraySize(ExpertMonteCarlo::trade_analysis_struct.monte_carlo_histories);
            ArrayResize(ExpertMonteCarlo::trade_analysis_struct.monte_carlo_histories, size+1);
            ExpertMonteCarlo::trade_analysis_struct.monte_carlo_histories[size] = monteCarloHistoryStruct;
        }

        static void ExpertMonteCarlo::AddPositionProfitHistory(ulong position_ticket, double profit) {
            PositionHistoryStruct positionHistoryStruct;
            positionHistoryStruct.position_ticket = position_ticket;
            positionHistoryStruct.profit = profit;
            int size = ArraySize(ExpertMonteCarlo::trade_analysis_struct.position_histories);
            ArrayResize(ExpertMonteCarlo::trade_analysis_struct.position_histories, size+1);
            ExpertMonteCarlo::trade_analysis_struct.position_histories[size] = positionHistoryStruct;
        }

        
        static void ExpertMonteCarlo::PrintTradeAnalyst() {
            double total_benefit = 0;
            int total_benefit_count = 0;
            double total_loss = 0;
            int total_loss_count = 0;
            for (int i = 0; i < ArraySize(ExpertMonteCarlo::trade_analysis_struct.monte_carlo_histories); i++) {
                double profit = ExpertMonteCarlo::trade_analysis_struct.monte_carlo_histories[i].profit;
                if (profit < 0) {
                    PrintFormat("[損失発生] 最後のポジションチケット: %d, 損失額: %f", 
                        ExpertMonteCarlo::trade_analysis_struct.monte_carlo_histories[i].latest_position_ticket,
                        profit
                    );

                    total_loss += profit;
                    total_loss_count += 1;
                } else {
                    total_benefit += profit;
                    total_benefit_count += 1;
                }
            }
            if (total_benefit_count > 0) {
                PrintFormat("利益回数: %d, 累積利益額: %f, 平均利益額: %f", total_benefit_count, total_benefit, total_benefit/total_benefit_count);
            }

            if (total_loss_count > 0) {
                PrintFormat("損失回数: %d, 累積損失額: %f, 平均損失額: %f", total_loss_count, total_loss, total_loss/total_loss_count);
            }


            int position_benefit_count = 0;
            int position_loss_count = 0;
            for (int i = 0; i < ArraySize(ExpertMonteCarlo::trade_analysis_struct.position_histories); i++) {
                ulong position_ticket = ExpertMonteCarlo::trade_analysis_struct.position_histories[i].position_ticket;
                double profit = ExpertMonteCarlo::trade_analysis_struct.position_histories[i].profit;
                if (profit >= 0) {
                    position_benefit_count += 1;
                } else {
                    position_loss_count += 1;
                }
                if (profit < -10000) {
                    PrintFormat("大損失: ticket: %d, loss: %f", position_ticket, profit);
                }
            }
            PrintFormat("ポジション利益回数: %d, ポジション損失回数: %d", position_benefit_count,position_loss_count);

        }
}