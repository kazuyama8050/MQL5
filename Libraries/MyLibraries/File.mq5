//+------------------------------------------------------------------+
//|                                                   File.mq5 |
//|                                  Copyright 2023, Kazuki Yamasaki |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2023, Kazuki Yamasaki"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <MyInclude\MyFile\MyFileHandler.mqh>
//+------------------------------------------------------------------+
//| My function                                                      |
//+------------------------------------------------------------------+

/** KeyValueファイルから特定Keyの値を取得する（カラム数が2前提）
 * 引数1: ファイルハンドラ
 * 引数2: キー(string)
 * return string Keyに対する値
**/
string GetValueOfFileKey(int file_handle, string key) export {
    int is_key = 0;
    int for_cnt = 1;
    string value_str;
    while(!FileIsEnding(file_handle)) {
        // 偶数はvalue、keyが一致したら返却
        if (for_cnt % 2 == 0) {
            if (is_key) {
                value_str = FileReadString(file_handle);
                
                return value_str;
            }
        } else if (FileReadString(file_handle) == key) {
            is_key = 1;
        }
        
        for_cnt++;
        
    }
    //取得できない場合
    return value_str;
}