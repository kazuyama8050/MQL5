class ExpertIma {
    public:
        bool ExpertIma::TestPrint(string prt);
        bool ExpertIma::MainLoop();
        int ExpertIma::ImaIndicator(
                        string symbol,
                        ENUM_TIMEFRAMES period, 
                        int ma_period, 
                        int ma_shift, 
                        ENUM_MA_METHOD ma_method, 
                        ENUM_APPLIED_PRICE applied_price
        );
        bool ExpertIma::CreateTradeRequest(MqlTradeRequest &request, int order);
        int ExpertIma::EntrySignal(double &slow_ma[], double &fast_ma[]);
    public:
        static int ExpertIma::slow_ima_handle; // 短期移動平均線
        static int ExpertIma::fast_ima_handle; //長期移動平均線
        static int ExpertIma::trade_error_cnt; //注文エラー回数
        static int ExpertIma::loss_cut_total_num; //トータル強制決済回数
    protected:
       
    private:
        // static int m_ima_handle;
        // static string short_name;

    private:
        
};