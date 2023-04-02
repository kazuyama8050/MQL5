class ExpertIma {
    public:
        bool ExpertIma::MainLoop();
        int ExpertIma::MaTrade();
        bool ExpertIma::CreateTradeRequest(MqlTradeRequest &request, double signal);
        int ExpertIma::CheckAfterMaTrade(ulong position_ticket);
        int ExpertIma::PrintTimerReport();
    public:
        static int ExpertIma::short_ima_handle; // 短期移動平均線
        static int ExpertIma::long_ima_handle; //長期移動平均線
        static int ExpertIma::trade_error_cnt; //注文エラー回数
        static int ExpertIma::loss_cut_total_num; //トータル強制決済回数
        static datetime ExpertIma::ma_trade_last_datetime; //移動平均を用いたラストトレード日時
        static ulong ExpertIma::ma_trade_last_position_ticket; //移動平均を用いた最新取引のポジションチケット番号
        static int ExpertIma::ma_trade_num;  //移動平均トレードによる注文回数
        static int ExpertIma::ma_settlement_num;  //移動平均トレードによる騙し判定回数
    protected:
       
    private:
        // static int m_ima_handle;
        // static string short_name;

    private:
        
};