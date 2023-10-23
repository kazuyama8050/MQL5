//+------------------------------------------------------------------+
//|                                                  MyTrade.mqh |
//|                             Copyright 2000-2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//| Class CMyTrade.                                                  |
//| Appointment: Class simple trade operations.                      |
//|              Derives from class CTrade.                          |
//+------------------------------------------------------------------+
class CMyTrade : public CTrade
  {
protected:

public:
                     CMyTrade(void);
                    ~CMyTrade(void);
                    bool CMyTrade::PositionClose(const ulong ticket,const ulong deviation, const string comment);
					bool CMyTrade::PositionClose(const ulong ticket,const ulong deviation, double volume, const string comment);


  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CMyTrade::CMyTrade(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMyTrade::~CMyTrade(void)
  {
  }
//+------------------------------------------------------------------+
//| Setting working symbol for easy trade operations.                |
//+------------------------------------------------------------------+

/** チケットのポジションをクローズ
 * 
**/
bool CMyTrade::PositionClose(const ulong ticket,const ulong deviation, const string comment)
{
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- check position existence
   if(!PositionSelectByTicket(ticket))
      return(false);
   string symbol=PositionGetString(POSITION_SYMBOL);
//--- clean
   ClearStructures();
//--- check filling
   if(!FillingCheck(symbol))
      return(false);
//--- check
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
     {
      //--- prepare request for close BUY position
      m_request.type =ORDER_TYPE_SELL;
      m_request.price=SymbolInfoDouble(symbol,SYMBOL_BID);
     }
   else
     {
      //--- prepare request for close SELL position
      m_request.type =ORDER_TYPE_BUY;
      m_request.price=SymbolInfoDouble(symbol,SYMBOL_ASK);
     }
//--- setting request
   m_request.action   =TRADE_ACTION_DEAL;
   m_request.position =ticket;
   m_request.symbol   =symbol;
   m_request.volume   =PositionGetDouble(POSITION_VOLUME);
   m_request.magic    =m_magic;
   m_request.comment = comment;
   m_request.deviation=(deviation==ULONG_MAX) ? m_deviation : deviation;
//--- close position
   return(OrderSend(m_request,m_result));
}

/** チケットのポジションを指定ロット数のみクローズ
 * 
**/
bool CMyTrade::PositionClose(const ulong ticket,const ulong deviation, double volume, const string comment)
{
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- check position existence
   if(!PositionSelectByTicket(ticket))
      return(false);
   string symbol=PositionGetString(POSITION_SYMBOL);
//--- clean
   ClearStructures();
//--- check filling
   if(!FillingCheck(symbol))
		return(false);
//--- check
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
	{
      //--- prepare request for close BUY position
      m_request.type =ORDER_TYPE_SELL;
      m_request.price=SymbolInfoDouble(symbol,SYMBOL_BID);
	}
   else
	{
      //--- prepare request for close SELL position
      m_request.type =ORDER_TYPE_BUY;
      m_request.price=SymbolInfoDouble(symbol,SYMBOL_ASK);
	}

	if (PositionGetDouble(POSITION_VOLUME) < volume) {
		volume = PositionGetDouble(POSITION_VOLUME);
	}

//--- setting request
   m_request.action   =TRADE_ACTION_DEAL;
   m_request.position =ticket;
   m_request.symbol   =symbol;
   m_request.volume   =volume;
   m_request.magic    =m_magic;
   m_request.comment = comment;
   m_request.deviation=(deviation==ULONG_MAX) ? m_deviation : deviation;
//--- close position
   return(OrderSend(m_request,m_result));
}