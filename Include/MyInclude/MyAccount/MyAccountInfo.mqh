#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <Indicators\Indicators.mqh>
#include <Trade\AccountInfo.mqh>

CAccountInfo cAccountInfo;

class MyAccountInfo {
    public:
        MyAccountInfo();
        ~MyAccountInfo();
        bool CheckForTrade(MqlTradeRequest &trade_request);
        double GetAccountBalance();
        double GetAccountCredit();
        double GetAccounProfit();
        double GetAccounEquity();
        double GetAccounMargin();
        double GetAccounMarginFree();
        double GetAccounMarginLevel();
        double GetAccounMarginSoCall();
        double GetAccounMarginSoSo();
        double GetAccounMarginInitial();
        double GetAccounMarginMaintenance();
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
bool MyAccountInfo::CheckForTrade(MqlTradeRequest &trade_request) {
    // 取引を実行するための必要な証拠金
    double margin = cAccountInfo.MarginCheck(trade_request.symbol, trade_request.type, trade_request.volume, trade_request.price);
    if (margin > GetAccountBalance()) {
        PrintFormat("Cannot Trade For LossMoney, 証拠金残高:%f、注文に必要な残高:%f", GetAccountBalance(), margin);
        return false;
    }

    return true;
}
//証拠金残高
double MyAccountInfo::GetAccountBalance() {
    return AccountInfoDouble(ACCOUNT_BALANCE);
}
//信用額
double MyAccountInfo::GetAccountCredit() {
    return AccountInfoDouble(ACCOUNT_CREDIT);
}
//純資産（証拠金残高 - 損益）
double MyAccountInfo::GetAccounProfit() {
    return AccountInfoDouble(ACCOUNT_PROFIT);
}
//損益
double MyAccountInfo::GetAccounEquity() {
    return AccountInfoDouble(ACCOUNT_EQUITY);
}
//必要証拠金
double MyAccountInfo::GetAccounMargin() {
    return AccountInfoDouble(ACCOUNT_MARGIN);
}
//有効証拠金
double MyAccountInfo::GetAccounMarginFree() {
    return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}
//証拠金維持率
double MyAccountInfo::GetAccounMarginLevel() {
    return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
}
//マージンコール値
double MyAccountInfo::GetAccounMarginSoCall() {
    return AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
}
//強制ロスカット値
double MyAccountInfo::GetAccounMarginSoSo() {
    return AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
}
//当初証拠金（全ての未決注文の証拠金をカバーするために口座内でリザーブされた額）
double MyAccountInfo::GetAccounMarginInitial() {
    return AccountInfoDouble(ACCOUNT_MARGIN_INITIAL);
}
//維持証拠金（全ての未決済ポジションの最小額をカバーするために口座内でリザーブされた最低資本金）
double MyAccountInfo::GetAccounMarginMaintenance() {
    return AccountInfoDouble(ACCOUNT_MARGIN_MAINTENANCE);
}
