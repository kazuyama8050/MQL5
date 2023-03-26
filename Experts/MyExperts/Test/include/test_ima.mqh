class TestIma {
    public:
        static int MainLoop();
        static bool TestPrint(void);
        static int ImaIndicator(
                        string symbol,
                        ENUM_TIMEFRAMES period, 
                        int ma_period, 
                        int ma_shift, 
                        ENUM_MA_METHOD ma_method, 
                        ENUM_APPLIED_PRICE applied_price
        );

    public:
        static int m_ima_handle;
    protected:
       
    private:
        // static int m_ima_handle;
        // static string short_name;

    private:
        
};