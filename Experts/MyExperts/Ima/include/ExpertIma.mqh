class ExpertIma {
    public:
        bool ExpertIma::MainLoop();
        int ExpertIma::MaTrade();
        bool ExpertIma::CreateTradeRequest(MqlTradeRequest &request, double order);
    public:
        static int ExpertIma::slow_ima_handle; // 短期移動平均線
        static int ExpertIma::fast_ima_handle; //長期移動平均線
        static int ExpertIma::trade_error_cnt; //注文エラー回数
        static int ExpertIma::loss_cut_total_num; //トータル強制決済回数
        static datetime ExpertIma::ma_trade_last_datetime; //移動平均を用いたラストトレード日時
    protected:
       
    private:
        // static int m_ima_handle;
        // static string short_name;

    private:
        
};