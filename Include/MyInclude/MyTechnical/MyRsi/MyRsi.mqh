#import "MyLibraries/Common.ex5"
    void ForceStopEa();
    void PrintNotice(const string log_str);
    void PrintWarn(const string log_str);
    void PrintError(const string log_str);
#import



class CMyRsi
{
    protected:
        int rsiHandle;
        int rsiDataNum;
        double rsiDatas[];
    public:
        CMyRsi();
        ~CMyRsi(void);

        int CMyRsi::Init(
            string symbol, ENUM_TIMEFRAMES period,
            int ma_period, ENUM_APPLIED_PRICE  applied_price
        );

        bool CMyRsi::IsValidRsiHandle() { return rsiHandle != INVALID_HANDLE; }
        int CMyRsi::GetRsiDataNum() { return rsiDataNum; }
        void CMyRsi::SetRsiDataNum(int dataNum) { rsiDataNum = dataNum; }
        double CMyRsi::GetRsiData(int p) { return rsiDatas[p]; }

        void CMyRsi::ClearRsiDatas();
        int CMyRsi::SetRsiByPosition(int buffer_num, int start_pos, int count);
        int CMyRsi::SetRsiByStartTime(int buffer_num, datetime start_time, int count);
        int CMyRsi::SetRsiByStartEndTime(int buffer_num, datetime start_time, datetime stop_time);
};

/**
 * symbol: 銘柄名
 * period, 時間軸
 * ma_period: RSI計算の平均期間
 * applied_price: 価格種類（終値など）
**/
void CMyRsi::CMyRsi()
{
    rsiDataNum = 0;
}

void CMyRsi::~CMyRsi()
{
}

int CMyRsi::Init(
    string symbol, ENUM_TIMEFRAMES period,
    int ma_period, ENUM_APPLIED_PRICE applied_price
)
{
    rsiHandle = iRSI(
        symbol, period, ma_period, applied_price
    );
    if (!CMyRsi::IsValidRsiHandle()) {
        PrintError("Failed To Create iRSI Handle");
        return 0;
    }
    return 1;
    
}

void CMyRsi::ClearRsiDatas()
{
    ArrayFree(rsiDatas);
    ArraySetAsSeries(rsiDatas, true);
    CMyRsi::SetRsiDataNum(0);
}


/** 開始時点と取得数を指定
 * @var buffer_num 指標バッファ番号、基本的に0で良いはず
 * @var start_pos 開始時点、直近を取得したい場合は0を指定
 * @var count 取得数、開始時点を要素0として、取得数分要素に追加する
 **/
int CMyRsi::SetRsiByPosition(int buffer_num, int start_pos, int count)
{
    if (!CMyRsi::IsValidRsiHandle()) { return 0; }
    CMyRsi::ClearRsiDatas();
    int set_count = CopyBuffer(rsiHandle, buffer_num, start_pos, count, rsiDatas);
    if (set_count == count) {
        CMyRsi::SetRsiDataNum(set_count);
        return 1;
    }
    CMyRsi::SetRsiDataNum(0);
    return 0;
}

/** 開始日時と取得数を指定
 * @var buffer_num 指標バッファ番号、基本的に0で良いはず
 * @var start_time 開始日時、取得したい最新データの日時
 * @var count 取得数、最新データを要素0として、取得数分要素に追加する
**/
int CMyRsi::SetRsiByStartTime(int buffer_num, datetime start_time, int count)
{
    if (!CMyRsi::IsValidRsiHandle()) { return 0; }
    CMyRsi::ClearRsiDatas();

    int set_count = CopyBuffer(rsiHandle, buffer_num, start_time, count, rsiDatas);
    if (set_count == count) {
        CMyRsi::SetRsiDataNum(set_count);
        return 1;
    }
    CMyRsi::SetRsiDataNum(0);
    return 0;
}

/** 開始日時と終了日時を指定
 * @var buffer_num 指標バッファ番号、基本的に0で良いはず
 * @var start_time 開始日時、取得したい最古のデータの日時
 * @var stop_time 終了日時、取得したい最新のデータの日時
**/
int CMyRsi::SetRsiByStartEndTime(int buffer_num, datetime start_time, datetime stop_time)
{
    if (!CMyRsi::IsValidRsiHandle()) { return 0; }
    CMyRsi::ClearRsiDatas();

    int set_count = CopyBuffer(rsiHandle, buffer_num, start_time, stop_time, rsiDatas);
    if (set_count > 0) {
        CMyRsi::SetRsiDataNum(set_count);
        return 1;
    }
    CMyRsi::SetRsiDataNum(0);
    return 0;
}