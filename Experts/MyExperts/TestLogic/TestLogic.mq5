
#include "include/BreakoutTrade.mqh"
#include "include/MaStretch.mqh"
#include "include/MaStretchHedge.mqh"
#include "include/MaStretchForMonteCarlo.mqh"
#include "include/RsiForMonteCarlo.mqh"
#include <MyInclude\MyCommon\MyDatetime.mqh>
#include <MyInclude\MyTrade\MySymbolInfo.mqh>
#include <MyInclude\MyTrade\MyTrade.mqh>


#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintDebug(const string log_str);
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
#import

input group "ブレークアウト戦略"
input bool isuse_breakout_logic = true;  // ブレークアウトロジック使用有無
input ENUM_TIMEFRAMES breakout_timeframe = PERIOD_M15;  // 時間軸
input int breakout_short_shift = 10;  // 短期比較
input int breakout_middle_shift = 25;  // 中期比較
input int breakout_long_shift = 40;  // 長期比較
input uint breakout_position_having_minutes = 120;  // 手仕舞い時間

input group "移動平均線ストレッチ"
input bool isuse_ma_stretch_logic = true;  // 移動平均線ストレッチロジック使用有無
input ENUM_TIMEFRAMES ma_stretch_timeframe = PERIOD_M15;  // 時間軸
input int ma_stretch_ma_period = 25;  // 移動平均期間
input int ma_stretch_ma_period_for_close = 25;  // 決済判定用移動平均期間
input ENUM_MA_METHOD ma_stretch_ma_method = MODE_SMA;  // 移動平均モード
input double ma_stretch_ma_deviation_rate = 0.05;  // 移動平均と終値の価格差基準値
input double ma_stretch_init_volume = 0.01;  // 初期ロット数


input group "モンテカルロ法用移動平均線ストレッチ"
input bool isuse_ma_stretch_monte_carlo_logic = true;  // 移動平均線ストレッチロジック使用有無
input ENUM_TIMEFRAMES ma_stretch_monte_carlo_timeframe = PERIOD_M15;  // 時間軸
input int ma_stretch_monte_carlo_ma_period = 25;  // 移動平均期間
input ENUM_MA_METHOD ma_stretch_monte_carlo_ma_method = MODE_SMA;  // 移動平均モード
input double ma_stretch_monte_carlo_ma_deviation_rate = 0.05;  // 移動平均と終値の価格差基準値
input double ma_stretch_monte_carlo_init_volume = 0.01;  // 初期ロット数
input double ma_stretch_monte_carlo_close_price_diff = 0.1;


input group "モンテカルロ法用RSI"
input bool isuse_rsi_monte_carlo_logic = true;  // RSIロジック使用有無
input ENUM_TIMEFRAMES rsi_monte_carlo_timeframe = PERIOD_M15;  // 時間軸
input int rsi_monte_carlo_ma_period = 25;  // 移動平均期間
input double rsi_monte_carlo_rsi_top_base = 70;  // RSIの上限基準値
input double rsi_monte_carlo_rsi_under_base = 30;  // RSIの下限基準値
input double rsi_monte_carlo_init_volume = 0.01;  // 初期ロット数
input double rsi_monte_carlo_close_price_diff = 0.1;


input group "ヘッジあり移動平均線ストレッチ"
input bool isuse_ma_stretch_hedge_logic = true;  // ヘッジあり移動平均線ストレッチロジック使用有無
input ENUM_TIMEFRAMES ma_stretch_hedge_timeframe = PERIOD_M15;  // 時間軸
input int ma_stretch_hedge_ma_period = 225;  // 移動平均期間
input int ma_stretch_hedge_ma_period_for_close = 225;  // 決済判定用移動平均期間
input ENUM_MA_METHOD ma_stretch_hedge_ma_method = MODE_SMA;  // 移動平均モード
input double ma_stretch_hedge_ma_deviation_rate = 0.01;  // 移動平均と終値の価格差基準値
input double ma_stretch_hedge_init_volume = 0.02;  // 初期ロット数
input double ma_stretch_hedge_init_hedge_volume = 0.01;  // 初期ヘッジロット数

CMyTrade myTrade();
CMyMovingAverage myMovingAverage();
CMyMovingAverage myMovingAverageForClose();
CMyRsi myRsi();

BreakoutTrade breakoutTrade(
    myTrade,
    breakout_timeframe,
    breakout_short_shift, breakout_middle_shift, breakout_long_shift, 
    breakout_position_having_minutes
);

MaStretch maStretch(
    myTrade,
    myMovingAverage,
    myMovingAverageForClose,
    ma_stretch_timeframe,
    ma_stretch_ma_period, ma_stretch_ma_period_for_close, ma_stretch_ma_method,
    ma_stretch_ma_deviation_rate,
    ma_stretch_init_volume
);

MaStretchForMonteCarlo maStretchForMonteCarlo(
    myTrade,
    myMovingAverage,
    ma_stretch_monte_carlo_timeframe,
    ma_stretch_monte_carlo_ma_period, ma_stretch_monte_carlo_ma_method,
    ma_stretch_monte_carlo_ma_deviation_rate,
    ma_stretch_monte_carlo_init_volume,
    ma_stretch_monte_carlo_close_price_diff
);

RsiForMonteCarlo rsiForMonteCarlo(
    myTrade,
    myRsi,
    rsi_monte_carlo_timeframe,
    rsi_monte_carlo_ma_period,
    rsi_monte_carlo_rsi_top_base,
    rsi_monte_carlo_rsi_under_base,
    rsi_monte_carlo_init_volume,
    rsi_monte_carlo_close_price_diff
);

MaStretchHedge maStretchHedge(
    myTrade,
    myMovingAverage,
    myMovingAverageForClose,
    ma_stretch_hedge_timeframe,
    ma_stretch_hedge_ma_period, ma_stretch_hedge_ma_period_for_close, ma_stretch_hedge_ma_method,
    ma_stretch_hedge_ma_deviation_rate,
    ma_stretch_hedge_init_volume, 
    ma_stretch_hedge_init_hedge_volume
);

CMySymbolInfo mySymbolInfo;

int MainLoop()
{
    if (isuse_breakout_logic == true) {
        if (!breakoutTrade.Execute()) {
            return 0;
        }
    }
    if (isuse_ma_stretch_logic == true) {
        if (!maStretch.Execute()) {
            return 0;
        }
    }
    if (isuse_ma_stretch_monte_carlo_logic == true) {
        if (!maStretchForMonteCarlo.Execute()) {
            return 0;
        }
    }
    if (isuse_rsi_monte_carlo_logic == true) {
        if (!rsiForMonteCarlo.Execute()) {
            return 0;
        }
    }
    if (isuse_ma_stretch_hedge_logic == true) {
        if (!maStretchHedge.Execute()) {
            return 0;
        }
    }
    
    return 1;
}

void OnInit()
{
    EventSetTimer(ONE_DATE_DATETIME); //1日間隔でタイマーイベントを呼び出す

    if (!mySymbolInfo.Refresh()) {
        PrintError("Cannot Refresh Cached Data of SymbolInfo");
        ForceStopEa();
        return;
    }
}

void OnTick()
{
    if (!MainLoop()) {
        PrintError(StringFormat("Exception Thrown, so Finished TestLogic, symbol: %s", Symbol()));
        ForceStopEa();
        return;
    }
}

void OnTimer()
{

}