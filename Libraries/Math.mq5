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
// int MyCalculator(int value,int value2) export
//   {
//    return(value+value2);
//   }
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