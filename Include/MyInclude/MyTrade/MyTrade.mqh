#include <Object.mqh>
#include <Trade\Trade.mqh>
#include <MyInclude\MyFile\MyFileHandler.mqh>
#import "MyLibraries/File.ex5"
    int CreateReadableFileHandler(string filepath, string separate_string, int code_type = DEFAULT_FILE_CODE_TYPE);
#import

#define PRICE_DIFF_MEAN_OF_15_MINUTES 0.065  //15分足の価格差平均値


class MyTrade {
    public:

    public:
        MyTrade();
        ~MyTrade();

};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MyTrade::MyTrade()
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MyTrade::~MyTrade()
  {
  }
