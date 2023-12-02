//+------------------------------------------------------------------+
//|                                                  MySymbolInfo.mqh |
//|                             Copyright 2000-2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\SymbolInfo.mqh>
//+------------------------------------------------------------------+
//| Class CMySymbolInfo.                                                  |
//| Appointment: Class simple trade operations.                      |
//|              Derives from class CSymbolInfo.                          |
//+------------------------------------------------------------------+
class CMySymbolInfo : public CSymbolInfo
{
    public:
        bool IsValidMinVolume(double volume) const;
        bool IsValidMaxVolume(double volume) const;

};

bool CMySymbolInfo::IsValidMinVolume(double volume) const
{
    return volume >= LotsMin();
}

bool CMySymbolInfo::IsValidMaxVolume(double volume) const
{
    return volume <= LotsMax();
}
