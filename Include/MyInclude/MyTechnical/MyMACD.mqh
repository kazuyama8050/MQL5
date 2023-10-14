
struct MACDListStruct
{
    double macd_list[];
    double macd_signal_list[];
};

class MyMACD {
    public:
        int macd_handle;
    
    public:
        MyMACD(const ENUM_TIMEFRAMES period, const int fast_ema_period, const int slow_ema_period, const int signal_period);
        ~MyMACD();
        int MyMACD::SetMACDList(MACDListStruct &macd_list_struct, const int cnt);
        static double MyMACD::CheckNormalCrossSignal(const MACDListStruct &macd_list_struct);
};

MyMACD::MyMACD(const ENUM_TIMEFRAMES period, const int fast_ema_period, const int slow_ema_period, const int signal_period) {
    macd_handle = iMACD(_Symbol, period, fast_ema_period, slow_ema_period, signal_period, PRICE_CLOSE);
}

MyMACD::~MyMACD() {

}

int MyMACD::SetMACDList(MACDListStruct &macd_list_struct, const int cnt) {
    ArraySetAsSeries(macd_list_struct.macd_list, true);
    ArraySetAsSeries(macd_list_struct.macd_signal_list, true);
    CopyBuffer(this.macd_handle, 0, 0, cnt, macd_list_struct.macd_list);
    if (ArraySize(macd_list_struct.macd_list) != cnt) {
        return 0;
    }
    CopyBuffer(this.macd_handle, 1, 0, cnt, macd_list_struct.macd_signal_list);
    if (ArraySize(macd_list_struct.macd_signal_list) != cnt) {
        return 0;
    }
    return 1;
}

/** 一般的なゴールデンクロス・デッドクロス検知
 * 
 **/
static double MyMACD::CheckNormalCrossSignal(const MACDListStruct &macd_list_struct) {
    double signal = 0.0;
    double macd_list[];
    ArraySetAsSeries(macd_list, true);
    ArrayCopy(macd_list, macd_list_struct.macd_list);

    double macd_signal_list[];
    ArraySetAsSeries(macd_signal_list, true);
    ArrayCopy(macd_signal_list, macd_list_struct.macd_signal_list);

    if (ArraySize(macd_list) < 2 || ArraySize(macd_signal_list) < 2) {
        return signal;
    }

    // ゴールデンクロス
    if (macd_list[2] < macd_signal_list[2] && macd_list[0] > macd_signal_list[0]) {
        signal = 1.0;
        Print("MACD ゴールデンクロス検知");
    }

    // デッドクロス
    if (macd_list[2] > macd_signal_list[2] && macd_list[0] < macd_signal_list[0]) {
        signal = -1.0;
        Print("MACD デッドクロス検知");
    }

    return signal;
}