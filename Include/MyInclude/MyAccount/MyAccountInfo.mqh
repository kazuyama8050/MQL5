#include <Object.mqh>
#include <Trade\AccountInfo.mqh>

class CMyAccountInfo : public CAccountInfo
{
    public:
        string TradeModeDescription(void) const;
        string StopoutModeDescription(void) const;
        string MarginModeDescription(void) const;
};

string CMyAccountInfo::TradeModeDescription(void) const
{
    switch(TradeMode()) {
        case ACCOUNT_TRADE_MODE_DEMO : return "デモ口座";
        case ACCOUNT_TRADE_MODE_CONTEST : return "コンテスト口座";
        case ACCOUNT_TRADE_MODE_REAL : return "リアル口座";
        default : return "不明な口座取引モード";
    }
    return "不明な口座取引モード";
}

string CMyAccountInfo::StopoutModeDescription(void) const
{
    switch(StopoutMode()) {
        case ACCOUNT_STOPOUT_MODE_PERCENT : return "百分率モード";
        case ACCOUNT_STOPOUT_MODE_MONEY : return "通過モード";
        default : return "不明なモード";
    }
    return "不明なモード";
}

string CMyAccountInfo::MarginModeDescription(void) const
{
    switch(MarginMode()) {
        case ACCOUNT_MARGIN_MODE_RETAIL_NETTING : return "ネッティングモード";
        case ACCOUNT_MARGIN_MODE_EXCHANGE : return "商品設定割引モード";
        case ACCOUNT_MARGIN_MODE_RETAIL_HEDGING : return "ヘッジングモード";
        default : return "不明な証拠金計算モード";
    }
    return "不明な証拠金計算モード";
}