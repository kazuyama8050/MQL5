#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include <Trade\AccountInfo.mqh>

CAccountInfo cAccountInfo;

class MyAccountInfo {
    public:
        MyAccountInfo();
        ~MyAccountInfo();
        static bool CheckForTrade(MqlTradeRequest &trade_request);
        static double GetAccountBalance();
        static double GetAccountCredit();
        static double GetAccounProfit();
        static double GetAccounEquity();
        static double GetAccounMargin();
        static double GetAccounMarginFree();
        static double GetAccounMarginLevel();
        static double GetAccounMarginSoCall();
        static double GetAccounMarginSoSo();
        static double GetAccounMarginInitial();
        static double GetAccounMarginMaintenance();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MyAccountInfo::MyAccountInfo()
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MyAccountInfo::~MyAccountInfo()
  {
  }

//売買可能か判定する
static bool MyAccountInfo::CheckForTrade(MqlTradeRequest &trade_request) {
    // 取引を実行するための必要な証拠金
    double margin = cAccountInfo.MarginCheck(trade_request.symbol, trade_request.type, trade_request.volume, trade_request.price);
    if (margin > MyAccountInfo::GetAccountBalance()) {
        PrintFormat("Cannot Trade For LossMoney, 証拠金残高:%f、注文に必要な残高:%f", MyAccountInfo::GetAccountBalance(), margin);
        return false;
    }

    return true;
}
//証拠金残高
static double MyAccountInfo::GetAccountBalance() {
    return AccountInfoDouble(ACCOUNT_BALANCE);
}
//信用額
static double MyAccountInfo::GetAccountCredit() {
    return AccountInfoDouble(ACCOUNT_CREDIT);
}
//純資産（証拠金残高 - 損益）
static double MyAccountInfo::GetAccounProfit() {
    return AccountInfoDouble(ACCOUNT_PROFIT);
}
//損益
static double MyAccountInfo::GetAccounEquity() {
    return AccountInfoDouble(ACCOUNT_EQUITY);
}
//必要証拠金
static double MyAccountInfo::GetAccounMargin() {
    return AccountInfoDouble(ACCOUNT_MARGIN);
}
//有効証拠金
static double MyAccountInfo::GetAccounMarginFree() {
    return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}
//証拠金維持率
static double MyAccountInfo::GetAccounMarginLevel() {
    return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
}
//マージンコール値
static double MyAccountInfo::GetAccounMarginSoCall() {
    return AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
}
//強制ロスカット値
static double MyAccountInfo::GetAccounMarginSoSo() {
    return AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
}
//当初証拠金（全ての未決注文の証拠金をカバーするために口座内でリザーブされた額）
static double MyAccountInfo::GetAccounMarginInitial() {
    return AccountInfoDouble(ACCOUNT_MARGIN_INITIAL);
}
//維持証拠金（全ての未決済ポジションの最小額をカバーするために口座内でリザーブされた最低資本金）
static double MyAccountInfo::GetAccounMarginMaintenance() {
    return AccountInfoDouble(ACCOUNT_MARGIN_MAINTENANCE);
}
