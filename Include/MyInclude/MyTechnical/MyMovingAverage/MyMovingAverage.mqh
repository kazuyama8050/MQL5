//+------------------------------------------------------------------+
//|                                                  MyTrade.mqh |
//|                             Copyright 2000-2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Class CMyMovingAverage.                                                  |
//| Appointment: Class simple trade operations.                          |
//+------------------------------------------------------------------+

#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
#import

/** 移動平均の平滑化の種類（ENUM_MA_METHOD）
 * MODE_SMA: 単純平均
 * MODE_EMA: 指数移動平均
 * MODE_SMMA: 平滑平均
 * MODE_LWMA: 線形加重移動平均
**/

/** ボリューム計算（ENUM_APPLIED_VOLUME）
 * VOLUME_TICK: ティックボリューム
 * VOLUME_REAL: 取引高
**/

class CMyMovingAverage
{
    protected:
        int imaHandle;
        int imaDataNum;
        double imaDatas[];  // 移動平均線の価格リスト（0に近いほど直近データ）
        
    public:
        CMyMovingAverage(void);
        ~CMyMovingAverage(void);

        void CMyMovingAverage::SetImaDataNum(int ima_data_num) { imaDataNum = ima_data_num; }
        int CMyMovingAverage::GetImaDataNum() { return imaDataNum; }
        double CMyMovingAverage::GetImaData(int p) { return imaDatas[p]; }

        int CMyMovingAverage::Init(string symbol, ENUM_TIMEFRAMES period, int ma_period, int ma_shift, ENUM_MA_METHOD ma_method, ENUM_APPLIED_PRICE applied_price);
        void CMyMovingAverage::ClearImaDatas();
        bool CMyMovingAverage::IsValidImaHandle() { return imaHandle != INVALID_HANDLE; }

        int CMyMovingAverage::SetMaByPosition(int buffer_num, int start_pos, int count);
        int CMyMovingAverage::SetMaByStartTime(int buffer_num, datetime start_time, int count);
        int CMyMovingAverage::SetMaByStartEndTime(int buffer_num, datetime start_time, datetime stop_time);

    
};

//+-----------------------------------x-------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CMyMovingAverage::CMyMovingAverage(void)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMyMovingAverage::~CMyMovingAverage(void)
{
    imaHandle = NULL;
    CMyMovingAverage::ClearImaDatas();
}

int CMyMovingAverage::Init(
    string symbol, ENUM_TIMEFRAMES period,
    int ma_period, int ma_shift,
    ENUM_MA_METHOD ma_method, ENUM_APPLIED_PRICE applied_price
)
{
    imaHandle = iMA(symbol, period, ma_period, ma_shift, ma_method, applied_price);
    if (!CMyMovingAverage::IsValidImaHandle()) {
        PrintError("Failed To Create IMA Handle");
        return 0;
    }
    return 1;
}

void CMyMovingAverage::ClearImaDatas()
{
    ArrayFree(imaDatas);
    ArraySetAsSeries(imaDatas, true);
    CMyMovingAverage::SetImaDataNum(0);
}

/** 開始時点と取得数を指定
 * @var buffer_num 指標バッファ番号、基本的に0で良いはず
 * @var start_pos 開始時点、直近を取得したい場合は0を指定
 * @var count 取得数、開始時点を要素0として、取得数分要素に追加する
 **/
int CMyMovingAverage::SetMaByPosition(int buffer_num, int start_pos, int count)
{
    if (!CMyMovingAverage::IsValidImaHandle()) { return 0; }
    CMyMovingAverage::ClearImaDatas();
    int set_count = CopyBuffer(imaHandle, buffer_num, start_pos, count, imaDatas);
    if (set_count == count) {
        CMyMovingAverage::SetImaDataNum(set_count);
        return 1;
    }
    CMyMovingAverage::SetImaDataNum(0);
    return 0;
}

/** 開始日時と取得数を指定
 * @var buffer_num 指標バッファ番号、基本的に0で良いはず
 * @var start_time 開始日時、取得したい最新データの日時
 * @var count 取得数、最新データを要素0として、取得数分要素に追加する
**/
int CMyMovingAverage::SetMaByStartTime(int buffer_num, datetime start_time, int count)
{
    if (!CMyMovingAverage::IsValidImaHandle()) { return 0; }
    CMyMovingAverage::ClearImaDatas();

    int set_count = CopyBuffer(imaHandle, buffer_num, start_time, count, imaDatas);
    if (set_count == count) {
        CMyMovingAverage::SetImaDataNum(set_count);
        return 1;
    }
    CMyMovingAverage::SetImaDataNum(0);
    return 0;
}

/** 開始日時と終了日時を指定
 * @var buffer_num 指標バッファ番号、基本的に0で良いはず
 * @var start_time 開始日時、取得したい最古のデータの日時
 * @var stop_time 終了日時、取得したい最新のデータの日時
**/
int CMyMovingAverage::SetMaByStartEndTime(int buffer_num, datetime start_time, datetime stop_time)
{
    if (!CMyMovingAverage::IsValidImaHandle()) { return 0; }
    CMyMovingAverage::ClearImaDatas();

    int set_count = CopyBuffer(imaHandle, buffer_num, start_time, stop_time, imaDatas);
    if (set_count > 0) {
        CMyMovingAverage::SetImaDataNum(set_count);
        return 1;
    }
    CMyMovingAverage::SetImaDataNum(0);
    return 0;
}