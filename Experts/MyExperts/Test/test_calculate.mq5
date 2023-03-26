void OnInit()
{
    return;
}

void OnTick()  
{

  // Print("口座番号 =  ",AccountInfoInteger(ACCOUNT_LOGIN));
  // Print("本番/デモ =  ",AccountInfoInteger(ACCOUNT_TRADE_MODE));
  // /Print("レバレッジ =  ",AccountInfoInteger(ACCOUNT_LEVERAGE));
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

  
 
  return;
}