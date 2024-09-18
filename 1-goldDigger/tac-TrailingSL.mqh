//+------------------------------------------------------------------+
//|                                               tac-TrailingSL.mqh |
//|                                             Copyright 2024, TAC. |
//|                                              https://www.tac.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, TAC."
#property link      "https://www.tac.com"

#include <Expert\ExpertBase.mqh>
//+------------------------------------------------------------------+
//| Class CExpertTrailing.                                           |
//| Purpose: Base class traling stops.                               |
//| Derives from class CExpertBase.                                  |
//+------------------------------------------------------------------+
class CExpertTrailing : public CExpertBase
  {
public:
                     CExpertTrailing(void);
                    ~CExpertTrailing(void);
   //---
   virtual bool      CheckTrailingStopLong(CPositionInfo *position,double &sl,double &tp)  { return(false); }
   virtual bool      CheckTrailingStopShort(CPositionInfo *position,double &sl,double &tp) { return(false); }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExpertTrailing::CExpertTrailing(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CExpertTrailing::~CExpertTrailing(void)
  {
  }
//+------------------------------------------------------------------+

