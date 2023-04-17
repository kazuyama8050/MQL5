//+------------------------------------------------------------------+
//|                                                         Math.mq5 |
//|                                  Copyright 2023, Kazuki Yamasaki |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2023, Kazuki Yamasaki"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Arrays\ArrayLong.mqh>
#include <Arrays\ArrayDouble.mqh>
//+------------------------------------------------------------------+
//| My function                                                      |
//+------------------------------------------------------------------+

double MathMeanForLong(const CArrayLong &array) export {
    int size = array.Total();
    if(size < 1) {return(0.0);}
        
    double mean = 0;
    for(int i = 0; i < size; i++) {
        mean += (double)array.At(i);
    }
    mean = (double)mean / size;
    return mean;
}

double MathMeanForDouble(const CArrayDouble &array) export {
    int size = array.Total();
    if(size < 1) {return(0.0);}
        
    double mean = 0;
    for(int i = 0; i < size; i++) {
        mean += array.At(i);
    }
    mean = (double)mean / size;
    return mean;
}

//配列の各要素ごとの差分の平均値算出
double MathDiffMeanForDouble(const CArrayDouble &array) export {
    double diff_mean = 0.0;
    int size = array.Total();
    if(size < 1) {return(0.0);}

    for (int i = 0; i < array.Total() - 1; i++) {
        double diff1 = array.At(i);
        double diff2 = array.At(i + 1);
        double diff_ret = MathAbs(diff1 - diff2);
        diff_mean += diff_ret;
    }
    diff_mean = diff_mean / size;
    return diff_mean;
}