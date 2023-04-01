#include <Object.mqh>
#include <Trade\Trade.mqh>

input int shift=0;
#define MAGIC_NUMBER_TEST = 123456;

int BuyBySymbol(ENUM_TRADE_REQUEST_ACTIONS action, string symbol, double volume, ENUM_ORDER_TYPE orderType, double price, ulong deviation) {
  /**
   * 買い注文
  **/
  //初期化
  MqlTradeRequest request={};
  MqlTradeResult  result={};
  //--- リクエストのパラメータ
  request.action = action;                     //　取引操作タイプ
  request.symbol = symbol;                             // シンボル
  request.volume = volume;                                   // 0.1ロットのボリューム（取引数量）
  request.type = orderType;                       // 注文タイプ（参考：https://www.mql5.com/ja/docs/constants/tradingconstants/orderproperties）
  request.price = price; // 発注価格（参考：https://www.mql5.com/ja/docs/constants/environment_state/marketinfoconstants#enum_symbol_info_double）
  request.deviation = deviation;                                     // 価格からの許容偏差
  // request.magic = MAGIC_NUMBER_TEST; // 注文のMagicNumber（同一MT内でのEA識別）
  //--- リクエストの送信
  if(!OrderSend(request,result))
    PrintFormat("OrderSend error %d",GetLastError());     // リクエストの送信が失敗した場合、エラーコードを出力する
  //--- 操作に関する情報
  PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);

  if (result.retcode != 200) {
    PrintFormat("Failed Buy symbol = %s", Symbol());
    return 0;
  }
  PrintFormat("Success Buy symbol = %s volume = %d price = %d", Symbol(), result.volume, result.price);
  return 1;
}

// void ClearOrderStructure() {
  // ZeroMemory(request);
  // ZeroMemory(result);
  // ZeroMemory(m_check_result);
// }

void OnInit()  
{

  // Print("口座番号 =  ",AccountInfoInteger(ACCOUNT_LOGIN));
  // Print("本番/デモ =  ",AccountInfoInteger(ACCOUNT_TRADE_MODE));
  // Print("レバレッジ =  ",AccountInfoInteger(ACCOUNT_LEVERAGE));
  // Print("未決注文の最大許容数 =  ",AccountInfoInteger(ACCOUNT_LIMIT_ORDERS));
  // Print("最小証拠金 =  ",AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE));
  // Print("口座で許可された取引 =  ",AccountInfoInteger(ACCOUNT_TRADE_ALLOWED));
  // Print("EAで許可された取引 =  ",AccountInfoInteger(ACCOUNT_TRADE_EXPERT));
  // Print("証拠金計算モード =  ",AccountInfoInteger(ACCOUNT_MARGIN_MODE));
  // Print("小数点以下の桁数 =  ",AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS));
  // Print("FIFO方式で決済(true/false) =  ",AccountInfoInteger(ACCOUNT_FIFO_CLOSE));
  //   //FIFO = First In First Out 古い注文から先に決済する

  // シンボル名を指定
  string symbol = "EURUSD";

  // シンボルの情報を取得
  double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
  double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
  double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

  // 結果を出力
  Print("シンボル: ", symbol);
  Print("Bid: ", bid);
  Print("Ask: ", ask);
  Print("Point: ", point);

  datetime time  = iTime(Symbol(),Period(),shift);
  double   open  = iOpen(Symbol(),Period(),shift);
  double   high  = iHigh(Symbol(),Period(),shift);
  double   low   = iLow(Symbol(),Period(),shift);
  double   close = iClose(NULL,PERIOD_CURRENT,shift);
  long     volume= iVolume(Symbol(),0,shift);
  int     bars  = iBars(NULL,0);

  Print("OPEN: ", open);
 
  Comment(Symbol(),",",EnumToString(Period()),"\n",
          "Time: " ,TimeToString(time,TIME_DATE|TIME_SECONDS),"\n",
          "Open: " ,DoubleToString(open,Digits()),"\n",
          "High: " ,DoubleToString(high,Digits()),"\n",
          "Low: "   ,DoubleToString(low,Digits()),"\n",
          "Close: " ,DoubleToString(close,Digits()),"\n",
          "Volume: ",IntegerToString(volume),"\n",
          "Bars: " ,IntegerToString(bars),"\n"
          );

  // 成り行き注文 執行方式 instant執行方式
  /**  以下を指定して注文が執行される
   * 取引種別
   * 取引銘柄
   * ロット数
   * ストップロス（損切り値）
   * テイクプロフィット（利確値）
   * スリッページ（現在値と発注前のレートとの乖離がどれくらいまでなら取引を許容するか）
  **/
  ENUM_SYMBOL_TRADE_EXECUTION exeMode = SymbolInfoInteger(NULL,SYMBOL_TRADE_EXEMODE);
  string executionType=EnumToString(exeMode);
  Print(executionType);

  // 買い注文
  BuyBySymbol(TRADE_ACTION_DEAL, Symbol(), 0.01, ORDER_TYPE_BUY, SymbolInfoDouble(Symbol(),SYMBOL_ASK), 5);
  BuyBySymbol(TRADE_ACTION_DEAL, Symbol(), 0.02, ORDER_TYPE_BUY, SymbolInfoDouble(Symbol(),SYMBOL_ASK), 5);
  BuyBySymbol(TRADE_ACTION_DEAL, Symbol(), 0.01, ORDER_TYPE_SELL, SymbolInfoDouble(Symbol(),SYMBOL_BID), 5);
  // 構造体リセット
  // ClearStructures();

  /**
   * ポジション決済
  **/
  MqlTradeRequest request={};
  MqlTradeResult  result={};
  int total=PositionsTotal(); //　保有ポジション数
  PrintFormat("total=%d", total);
//--- 全ての保有ポジションの取捨
  // for (int i = 0 i >= total - 1; i++) {
    // //--- 注文のパラメータ
    // ulong  position_ticket=PositionGetTicket(i);       // ポジションチケット
    // // 小数点以下の桁数
    // ulong  magic=PositionGetInteger(POSITION_MAGIC);  // ポジションのMagicNumber
    // double volume=PositionGetDouble(POSITION_VOLUME); // ポジションボリューム
    // ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);   // ポジションタイプ
    // PrintFormat("magic=%d", position_ticket);
    // PrintFormat("magic=%d", magic);
    // PrintFormat("magic=%f", volume);
    // Print(type);

  // }

  for (int i = total - 1; i >= 0; i--) {
    //--- 注文のパラメータ
    ulong  position_ticket=PositionGetTicket(i);       // ポジションチケット
    // 小数点以下の桁数
    ulong  magic=PositionGetInteger(POSITION_MAGIC);  // ポジションのMagicNumber
    double volume=PositionGetDouble(POSITION_VOLUME); // ポジションボリューム
    double position_price=PositionGetDouble(POSITION_PRICE_OPEN); // ポジションの価格
    string position_symbol=PositionGetString(POSITION_SYMBOL);
    ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);   // ポジションタイプ
    PrintFormat("position_ticket=%d", position_ticket);
    PrintFormat("magic=%f", volume);
    PrintFormat("price=%f", position_price);
    Print(type);

    request.action = TRADE_ACTION_DEAL;
    request.position = position_ticket;
    request.symbol = position_symbol;
    request.volume = volume;
    // request.type = POSITION_TYPE_BUY;
    // request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
    request.deviation = 5;

    if(type==POSITION_TYPE_BUY)
    {
      request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
      request.type =ORDER_TYPE_SELL;
    }
    else
    {
      request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
      request.type =ORDER_TYPE_BUY;
    }

    if(!OrderSend(request,result)) {
        PrintFormat("OrderSend error %d",GetLastError());
    }

    int total2=PositionsTotal(); //　保有ポジション数
    PrintFormat("total=%d", total2);
  }

  // int macdHandle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
  // if(macdHandle==INVALID_HANDLE) {
  //   Print("Failed Get MACD Handle");
  // }

  // //配列を時系列にセット
  // double priceArray[];
  // ArraySetAsSeries(priceArray,true);
  
  // //MACDのメインライン値を取得し、配列に格納
  // CopyBuffer(macdHandle,0,0,3,priceArray);
   
  // //現在足のMACD値を変数に格納
  // // 配列要素0が現在足で過去のデータほど要素が増える
  // double macdValue=priceArray[0];
  // PrintFormat("MACD value %d", macdValue);

  datetime test_date = TimeLocal();
  Print("test_date");
  Print(test_date);
  Print(test_date -3600);
  Print(test_date > test_date - 3600);

  return;
}
// double priceArray[];
// void OnTick() {
//   int macdHandle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
//   if(macdHandle==INVALID_HANDLE) {
//     Print("Failed Get MACD Handle");
//   }

//   //配列を時系列にセット
  
//   ArraySetAsSeries(priceArray,true);
  
//   //MACDのメインライン値を取得し、配列に格納
//   CopyBuffer(macdHandle,0,0,3,priceArray);
//   PrintFormat("Array Size %d", ArraySize(priceArray));
   
//   //現在足のMACD値を変数に格納
//   // 配列要素0が現在足で過去のデータほど要素が増える
//   double macdValue=priceArray[0];
//   PrintFormat("MACD value %f, %f, %f", macdValue, priceArray[1], priceArray[2]);
// }
