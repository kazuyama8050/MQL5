
#include "include/MaStretch.mqh"
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

input group "移動平均線ストレッチ 共通"
input ENUM_TIMEFRAMES ma_stretch_timeframe = PERIOD_M15;  // 時間軸
input ENUM_MA_METHOD ma_stretch_ma_method = MODE_SMA;  // 移動平均モード

input group "移動平均線ストレッチ パターン1"
input bool isuse_ma_stretch_logic_1 = true;  // 移動平均線ストレッチロジック使用有無
input int ma_stretch_ma_period_1 = 225;  // 移動平均期間
input int ma_stretch_ma_period_for_close_1 = 225;  // 決済判定用移動平均期間
input double ma_stretch_ma_deviation_rate_1 = 0.01;  // 移動平均と終値の価格差基準値
input double ma_stretch_init_volume_1 = 0.02;  // 初期ロット数

input group "移動平均線ストレッチ パターン2"
input bool isuse_ma_stretch_logic_2 = true;  // 移動平均線ストレッチロジック使用有無
input int ma_stretch_ma_period_2 = 175;  // 移動平均期間
input int ma_stretch_ma_period_for_close_2 = 175;  // 決済判定用移動平均期間
input double ma_stretch_ma_deviation_rate_2 = 0.03;  // 移動平均と終値の価格差基準値
input double ma_stretch_init_volume_2 = 0.02;  // 初期ロット数

input group "移動平均線ストレッチ パターン3"
input bool isuse_ma_stretch_logic_3 = true;  // 移動平均線ストレッチロジック使用有無
input int ma_stretch_ma_period_3 = 175;  // 移動平均期間
input int ma_stretch_ma_period_for_close_3 = 175;  // 決済判定用移動平均期間
input double ma_stretch_ma_deviation_rate_3 = 0.04;  // 移動平均と終値の価格差基準値
input double ma_stretch_init_volume_3 = 0.02;  // 初期ロット数

input group "移動平均線ストレッチ パターン4"
input bool isuse_ma_stretch_logic_4 = true;  // 移動平均線ストレッチロジック使用有無
input int ma_stretch_ma_period_4 = 225;  // 移動平均期間
input int ma_stretch_ma_period_for_close_4 = 225;  // 決済判定用移動平均期間
input double ma_stretch_ma_deviation_rate_4 = 0.02;  // 移動平均と終値の価格差基準値
input double ma_stretch_init_volume_4= 0.02;  // 初期ロット数

input group "移動平均線ストレッチ パターン5"
input bool isuse_ma_stretch_logic_5 = true;  // 移動平均線ストレッチロジック使用有無
input int ma_stretch_ma_period_5= 175;  // 移動平均期間
input int ma_stretch_ma_period_for_close_5 = 175;  // 決済判定用移動平均期間
input double ma_stretch_ma_deviation_rate_5 = 0.01;  // 移動平均と終値の価格差基準値
input double ma_stretch_init_volume_5 = 0.02;  // 初期ロット数


CMyTrade myTrade();
CMyMovingAverage myMovingAverage();
CMyMovingAverage myMovingAverageForClose();

MaStretch maStretch1(
    myTrade,
    myMovingAverage,
    myMovingAverageForClose,
    ma_stretch_timeframe,
    ma_stretch_ma_period_1, ma_stretch_ma_period_for_close_1, ma_stretch_ma_method,
    ma_stretch_ma_deviation_rate_1,
    ma_stretch_init_volume_1
);

MaStretch maStretch2(
    myTrade,
    myMovingAverage,
    myMovingAverageForClose,
    ma_stretch_timeframe,
    ma_stretch_ma_period_2, ma_stretch_ma_period_for_close_2, ma_stretch_ma_method,
    ma_stretch_ma_deviation_rate_2,
    ma_stretch_init_volume_2
);

MaStretch maStretch3(
    myTrade,
    myMovingAverage,
    myMovingAverageForClose,
    ma_stretch_timeframe,
    ma_stretch_ma_period_3, ma_stretch_ma_period_for_close_3, ma_stretch_ma_method,
    ma_stretch_ma_deviation_rate_3,
    ma_stretch_init_volume_3
);

MaStretch maStretch4(
    myTrade,
    myMovingAverage,
    myMovingAverageForClose,
    ma_stretch_timeframe,
    ma_stretch_ma_period_4, ma_stretch_ma_period_for_close_4, ma_stretch_ma_method,
    ma_stretch_ma_deviation_rate_4,
    ma_stretch_init_volume_4
);

MaStretch maStretch5(
    myTrade,
    myMovingAverage,
    myMovingAverageForClose,
    ma_stretch_timeframe,
    ma_stretch_ma_period_5, ma_stretch_ma_period_for_close_5, ma_stretch_ma_method,
    ma_stretch_ma_deviation_rate_5,
    ma_stretch_init_volume_5
);

CMySymbolInfo mySymbolInfo;

int MainLoop()
{
    if (isuse_ma_stretch_logic_1 == true) {
        if (!maStretch1.Execute()) {
            return 0;
        }
    }
    if (isuse_ma_stretch_logic_2 == true) {
        if (!maStretch2.Execute()) {
            return 0;
        }
    }
    if (isuse_ma_stretch_logic_3 == true) {
        if (!maStretch3.Execute()) {
            return 0;
        }
    }
    if (isuse_ma_stretch_logic_4 == true) {
        if (!maStretch4.Execute()) {
            return 0;
        }
    }
    if (isuse_ma_stretch_logic_5 == true) {
        if (!maStretch5.Execute()) {
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