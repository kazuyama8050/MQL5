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

double MathDivide(const int molec, const int denom) export {
    if (molec == 0 || denom == 0) {
        return 0.0;
    }
    return molec / denom;
}

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

double MathMeanForLong(const long &array[]) export {
    int size = ArraySize(array);
    if(size < 1) {return(0.0);}

    double mean = 0;
    for(int i = 0; i < size; i++) {
        mean += (double)array[i];
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

double MathMeanForDouble(const double &array[]) export {
    int size = ArraySize(array);
    if(size < 1) {return(0.0);}

    double mean = 0;
    for(int i = 0; i < size; i++) {
        mean += array[i];
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

double RoundToDecimal(double n, const int decimal_digits) export {
    double multiplier = MathPow(10, decimal_digits);
    return MathRound(n * multiplier) / multiplier;
}

//正規化
double MathNormalizeDouble(const double target, const double &array[]) export {
    int array_cnt = ArraySize(array) - 1;
    // 最大値、最小値の要素番号
    int index_max = ArrayMaximum(array);
    int index_min = ArrayMinimum(array);

    //最大値、最小値
    double max_val = array[array_cnt - index_max];
    double min_val = array[array_cnt - index_min];

    return (target - min_val) / (max_val - min_val);
}

//標準偏差
double MathStandardDeviation(const double &array[]) export {
    double array_mean = MathMeanForDouble(array);
    int array_size = ArraySize(array);

    double val = 0;
    for (int i = 0;i < array_size;i++) {
        val += (array[i] - array_mean) * (array[i] - array_mean);
    }

    if (val <= 0) {
        return 0.0;
    }

    return MathSqrt(val / array_size);
}

//標準化
double MathStandardizationDouble(const double target, const double &array[]) export {
    double array_mean = MathMeanForDouble(array);
    double standard_deviation = MathStandardDeviation(array);  //標準偏差
    if (standard_deviation <= 0) {
        return 0.0;
    }

    return (target - array_mean) / standard_deviation;
}

//標準化リスト
int MathStandardizationDouble(double &ret_array[], const double &array[]) export {
    int array_size = ArraySize(array);
    ArrayResize(ret_array, array_size);

    for (int i = 0;i < array_size;i++) {
        double standard_deviation = MathStandardizationDouble(array[i], array);
        ret_array[i] = standard_deviation;
    }
    return 1;
}