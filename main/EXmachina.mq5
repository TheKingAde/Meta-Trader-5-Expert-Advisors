//+------------------------------------------------------------------+
//|                                                   EXmachina.mq5 |
//|                                      Copyright 2024, KingAde, TAC|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, KingAde, TAC."
#property link      "https://twitter.com/Kingade_1"
#property description "Main with 0.5 sl with 1hr signal limit"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

#define SIGNAL_BUY    1 // Buy signal
#define SIGNAL_NOT    0 // No trading signal
#define SIGNAL_SELL  -1 // Sell signal

input int inpzigzagDepth = 12; // zig zag depth
input int inpzigzagDeviation = 7; // zig zag deviation
input int inpzigzagBackstep = 5; // zig zag backstep
input int inpSMA_Period = 14; // Period for SMA

int ExtBuySignalCount = 0;   // Buy signal count
int ExtSellSignalCount = 0;  // Sell signal count
int drawDownPercent = 30;    // Default drawdown percentage
int percentageRisk = 3;   // Percentage risk per trade
double ExtDrawDownAmount = 0;

//+------------------------------------------------------------------+
//| Expert Trader class                                              |
//+------------------------------------------------------------------+
class CSymbolTrader
  {
private:
   CTrade            EXTrade;              // Object to handle trade operations
   string            symbol;               // Symbol to trade
   MqlTick           ExtLast_tick;         // Chart data
   MqlRates          ExtChartData[];       // Chart data for zigzag indicator
   int               ExtSignalCreated;     // Signal status
   int               ExtCopiedData;        // Data copied
   int               ExtCountLevels;       // Variable to count levels
   int               ExtZigzagHandle;      // Handle for Zigzag indicator
   int               ExtSma_handle4H;      // Handle for SMA
   double            ExtCurrFibLevels[7];  // Current Fibonacci levels
   double            ExtLevelPrices[5];    // Level prices
   double            ExtSma4H[];           // Store candlestick data
   double            ExtZigzagData[];      // Zigzag data array
   double            ExtLastRetracement;   // Last retracement level
   double            ExtCurrentH4SMA;      // Current SMA value
   double            ExtIniaccountBalance;
   datetime          ExtLastSignalTime;    // Last signal time
   datetime          ExtLevelTimes[5];     // Level times array
   ENUM_TIMEFRAMES   period;               // Timeframe for analysis
   long              currencyTicks;       // Currency ticks


public:
   // Constructor
                     CSymbolTrader(string pair, long ticks)
     {
      symbol = pair;
      currencyTicks = ticks;
      ExtSignalCreated = SIGNAL_NOT;
      ExtCopiedData = 0;
      ExtCountLevels = 0;
      ExtLastRetracement = 0;
      ExtCurrentH4SMA = 0;
      ExtLastSignalTime = 0;
      ExtIniaccountBalance = 0;
      period = _Period; // Set timeframe
     }

   // Setter for initial account balance
   void              SetInitialAccountBalance(double balance)
     {
      ExtIniaccountBalance = balance;
     }


   // Method to identify support and resistance levels using ZigZag
   void              IdentifyLevels()
     {
      datetime fromTime = TimeCurrent() - 1 * 4 * 60 * 60;
      datetime toTime = TimeCurrent();

      ArrayFree(ExtChartData); // Free chart data array
      // Retrieve data for the specific symbol
      ExtCopiedData = CopyRates(symbol, period, fromTime, toTime, ExtChartData);
      if(ExtCopiedData <= 0)
        {
         // Print("[ Failed to retrieve data for symbol: ", symbol, " ]");
         return;
        }
      ArraySetAsSeries(ExtChartData, true);

      // Create ZigZag indicator handle for the specific symbol
      ExtZigzagHandle = iCustom(symbol, 0, "Examples/ZigZag", inpzigzagDepth, inpzigzagDeviation, inpzigzagBackstep);
      if(ExtZigzagHandle == INVALID_HANDLE)
        {
         //Print("[ Failed to apply ZigZag on symbol: ", symbol, " ]");
         return;
        }

      ArrayFree(ExtZigzagData); // Free zig zag data array
      // Retrieve ZigZag data for the specific symbol
      int copiedZigzagData = CopyBuffer(ExtZigzagHandle, 0, 0, ExtCopiedData, ExtZigzagData);
      if(copiedZigzagData <= 0)
        {
         //Print("[ Failed to copy ZigZag buffer for symbol: ", symbol, " ]");
         return;
        }
      ArraySetAsSeries(ExtZigzagData, true);

      // Find most recent levels
      ExtCountLevels = 0;
      for(int i = 0; i < ExtCopiedData && ExtCountLevels <= 4; i++)
        {
         if(ExtZigzagData[i] > 0)
           {
            ExtLevelPrices[ExtCountLevels] = ExtZigzagData[i];
            ExtLevelTimes[ExtCountLevels] = ExtChartData[i].time;
            ExtCountLevels++;
           }
        }
     }

   // Method to calculate Fibonacci retracement levels
   void              CalculateFibonacciRetracement(double price1, double price2)
     {
      if(price1 < price2)
        {
         // Uptrend: Calculate levels from price1 (low) to price2 (high)
         ExtCurrFibLevels[0] = price1;                                  // 100%
         ExtCurrFibLevels[1] = price1 + 0.236 * (price2 - price1);       // 76.4%
         ExtCurrFibLevels[2] = price1 + 0.382 * (price2 - price1);       // 61.8%
         ExtCurrFibLevels[3] = price1 + 0.5 * (price2 - price1);         // 50%
         ExtCurrFibLevels[4] = price1 + 0.618 * (price2 - price1);       // 38.2%
         ExtCurrFibLevels[5] = price1 + 0.764 * (price2 - price1);       // 23.6%
         ExtCurrFibLevels[6] = price2;                                   // 0%
        }
      else
         if(price1 > price2)
           {
            // Downtrend: Calculate levels from price1 (high) to price2 (low)
            ExtCurrFibLevels[0] = price1;                                  // 100%
            ExtCurrFibLevels[1] = price1 - 0.236 * (price1 - price2);       // 76.4%
            ExtCurrFibLevels[2] = price1 - 0.382 * (price1 - price2);       // 61.8%
            ExtCurrFibLevels[3] = price1 - 0.5 * (price1 - price2);         // 50%
            ExtCurrFibLevels[4] = price1 - 0.618 * (price1 - price2);       // 38.2%
            ExtCurrFibLevels[5] = price1 - 0.764 * (price1 - price2);       // 23.6%
            ExtCurrFibLevels[6] = price2;                                   // 0%
           }
     }
   // Method to process tick data
   void              processTick()
     {
      // Check if it's the right trading session
      if(!IsTradingSession(24))
         return;
      // Check if 1hr have passed since the last signal
      //if((TimeCurrent() - ExtLastSignalTime) > 3600)
      //  {
      //   ExtSignalCreated = SIGNAL_NOT;
      //   ExtLastRetracement = 0;
      //   ExtLastSignalTime = 0;
      //  }
      // Get the current tick data
      if(!SymbolInfoTick(symbol, ExtLast_tick))
        {
         Print("[ ", symbol,"  Error in SymbolInfoTick. Error code = ", GetLastError(), " ]");
         return;
        }
      // Simple moving averages
      ExtSma_handle4H = iMA(symbol,
                            PERIOD_H4,
                            inpSMA_Period,
                            0,
                            MODE_SMA,
                            PRICE_CLOSE);
      if(CopyBuffer(ExtSma_handle4H,
                    0,
                    0,
                    1,
                    ExtSma4H) <= 0)
        {
         Print("[ ", symbol,"  Error getting H4 SMA data. Error code = ", GetLastError(), " ]");
         return;
        }
      ExtCurrentH4SMA = ExtSma4H[0];
      // Check if no signal has been created
      if(ExtSignalCreated == 0)
        {
         // Identify patterns and set ExtSignalCreated flag accordingly
         if((ExtLevelPrices[1] > ExtLevelPrices[2]
             && ExtLevelPrices[1] >= ExtLevelPrices[3]
             && ExtLevelPrices[1] > ExtLevelPrices[4]
             && ExtLevelPrices[3] > ExtLevelPrices[4]
             && ExtLevelPrices[3] > ExtLevelPrices[2]
             && ExtLevelPrices[4] >= ExtLevelPrices[2]))
           {
            if(ExtLast_tick.ask <= ExtLevelPrices[2]
               && ExtLast_tick.ask < ExtCurrentH4SMA)
              {
               ExtSignalCreated = SIGNAL_SELL; // Sell signal created
               ExtLastSignalTime = TimeCurrent();
               datetime expiryTime = ExtLastSignalTime + 3600;
               Print("[ ", symbol," Sell signal created, expiry time: ", expiryTime, " ]");
               ExtLastRetracement = ExtLevelPrices[1];
               ExtSellSignalCount++;
              }
           }
         else
            if((ExtLevelPrices[2] > ExtLevelPrices[1]
                && ExtLevelPrices[2] >= ExtLevelPrices[4]
                && ExtLevelPrices[2] > ExtLevelPrices[3]
                && ExtLevelPrices[3] >= ExtLevelPrices[1]
                && ExtLevelPrices[4] > ExtLevelPrices[3]
                && ExtLevelPrices[4] > ExtLevelPrices[1]))
              {
               if(ExtLast_tick.bid >= ExtLevelPrices[2]
                  && ExtLast_tick.bid > ExtCurrentH4SMA)
                 {
                  ExtSignalCreated = SIGNAL_BUY; // Buy signal created
                  ExtLastSignalTime = TimeCurrent();
                  datetime expiryTime = ExtLastSignalTime + 3600;
                  Print("[ ", symbol," Buy signal created, expiry time: ", expiryTime, " ]");
                  ExtLastRetracement = ExtLevelPrices[1];
                  ExtBuySignalCount++;
                 }
              }
        }
      if(ExtSignalCreated == SIGNAL_BUY)
        {
         if(ExtLast_tick.bid < ExtLastRetracement)
           {
            Print("[ ", symbol,"  Structure Broken ]");
            ExtSignalCreated = SIGNAL_NOT;
            ExtLastRetracement = 0;
            return;
           }
         if(ExtLevelPrices[1] > ExtLevelPrices[2]) // Retracement
           {
            MonitorPriceAndOpenPosition(ExtLast_tick.bid,
                                        true);
           }
        }
      else
         if(ExtSignalCreated == SIGNAL_SELL)
           {
            if(ExtLast_tick.ask > ExtLastRetracement)
              {
               Print("[ ", symbol," Structure Broken ]");
               ExtSignalCreated = SIGNAL_NOT;
               ExtLastRetracement = 0;
               return;
              }
            if(ExtLevelPrices[2] > ExtLevelPrices[1]) // Retracement
              {
               MonitorPriceAndOpenPosition(ExtLast_tick.ask,
                                           false);
              }
           }
     }
   //  Method to monitor price and open a position
   void              MonitorPriceAndOpenPosition(double lastTickPrice,
         bool isBullish)
     {
      if(isBullish)
        {
         if(findMatchIdx(ExtLastRetracement,
                         ExtLevelPrices) == -1)
           {
            Print("[ ", symbol," Missed Entry ]");
            ExtSignalCreated = SIGNAL_NOT;
            ExtLastRetracement = 0;
            return;
           }
         if(ExtLastRetracement == ExtLevelPrices[4]) // Second retracement after signal
           {
            if(lastTickPrice <= ExtCurrFibLevels[2]) // 61.8 Retracement level
              {
               double stopLoss = calculateExit(ExtLevelPrices[2],
                                               ExtLevelPrices[1],
                                               lastTickPrice,
                                               0.50,
                                               true);
               double takeProfit = calculateExit(ExtLevelPrices[3],
                                                 ExtLevelPrices[4],
                                                 lastTickPrice,
                                                 0.80,
                                                 false);
               double slPoints = MathAbs(lastTickPrice - stopLoss);
               double tpPoints = MathAbs(lastTickPrice - takeProfit);
               double tp = lastTickPrice + (slPoints * 3);
               double RR = tpPoints/slPoints;
               int orderStatus = 0;
               if(RR >= 3)
                 {
                  double lotsizeMul = AccountInfoDouble(ACCOUNT_BALANCE) / 100;
                  double iniLotSize = lotsizeMul * 0.01;
                  double lotsize = 0;

                  if(iniLotSize <= 0.01)
                    {
                     lotsize = 0.01;

                     if(handlePortfolio(percentageRisk,
                                        slPoints,
                                        lotsize) == false)
                       {
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                        return;
                       }
                    }
                  else
                     if(iniLotSize > 0.01)
                       {
                        lotsize = (float)(int)(iniLotSize / 2 * 100) / 100.0;

                        if(handlePortfolio(percentageRisk,
                                           slPoints,
                                           iniLotSize) == false)
                          {
                           ExtSignalCreated = SIGNAL_NOT;
                           ExtLastRetracement = 0;
                           return;
                          }
                       }

                  orderStatus = openBuyOrder(tp,
                                             stopLoss,
                                             lotsize);
                  if(orderStatus == 1)
                    {
                     // double tp = lastTickPrice - tpPoints;
                     // double sl = lastTickPrice + slPoints;
                     if(iniLotSize > 0.01)
                        orderStatus = openBuyOrder(takeProfit,
                                                   stopLoss,
                                                   lotsize);
                     ExtSignalCreated = SIGNAL_NOT;
                     ExtLastRetracement = 0;
                    }
                  else
                     if(orderStatus != 1)
                       {
                        Print("[ ", symbol," Failed to open order resetting ]");
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                       }
                 }
               else
                 {
                  Print("[ ", symbol," Signal doesn't meet R:R requirement ]");
                  ExtSignalCreated = SIGNAL_NOT;
                  ExtLastRetracement = 0;
                 }
              }
           }
        }
      else
         if(!isBullish)
           {
            if(findMatchIdx(ExtLastRetracement,
                            ExtLevelPrices) == -1)
              {
               Print("[ ", symbol," Missed Entry ]");
               ExtSignalCreated = SIGNAL_NOT;
               ExtLastRetracement = 0;
               return;
              }
            if(ExtLastRetracement == ExtLevelPrices[4]) // Second retracement after signal
              {
               if(lastTickPrice >= ExtCurrFibLevels[2]) // 61.8 Retracement level
                 {
                  double stopLoss = calculateExit(ExtLevelPrices[2],
                                                  ExtLevelPrices[1],
                                                  lastTickPrice,
                                                  0.50,
                                                  false);
                  double takeProfit = calculateExit(ExtLevelPrices[3],
                                                    ExtLevelPrices[4],
                                                    lastTickPrice,
                                                    0.80,
                                                    true);
                  double slPoints = MathAbs(lastTickPrice - stopLoss);
                  double tpPoints = MathAbs(lastTickPrice - takeProfit);
                  double tp = lastTickPrice - (slPoints * 3);
                  double RR = tpPoints/slPoints;
                  int orderStatus = 0;
                  if(RR >= 3)
                    {
                     double lotsizeMul = AccountInfoDouble(ACCOUNT_BALANCE) / 100;
                     double iniLotSize = lotsizeMul * 0.01;
                     double lotsize = 0;

                     if(iniLotSize <= 0.01)
                       {
                        lotsize = 0.01;

                        if(handlePortfolio(percentageRisk,
                                           slPoints,
                                           lotsize) == false)
                          {
                           ExtSignalCreated = SIGNAL_NOT;
                           ExtLastRetracement = 0;
                           return;
                          }
                       }
                     else
                        if(iniLotSize > 0.01)
                          {
                           lotsize = (float)(int)(iniLotSize / 2 * 100) / 100.0;

                           if(handlePortfolio(percentageRisk,
                                              slPoints,
                                              iniLotSize) == false)
                             {
                              ExtSignalCreated = SIGNAL_NOT;
                              ExtLastRetracement = 0;
                              return;
                             }
                          }

                     orderStatus = openSellOrder(tp,
                                                 stopLoss,
                                                 lotsize);
                     if(orderStatus == 1)
                       {
                        //double tp = lastTickPrice + tpPoints;
                        //double sl = lastTickPrice - slPoints;
                        if(iniLotSize > 0.01)
                           orderStatus = openSellOrder(takeProfit,
                                                       stopLoss,
                                                       lotsize);
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                       }
                     else
                       {
                        Print("[ ", symbol," Failed to open order resetting ]");
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                       }
                    }
                 }
               else
                 {
                  Print("[ ", symbol," Signal doesn't meet R:R requirement ]");
                  ExtSignalCreated = SIGNAL_NOT;
                  ExtLastRetracement = 0;
                 }
              }
           }
     }
   //  Method to calculate Stop Loss and Take Profit
   double            calculateExit(double price2,
                                   double price1,
                                   double entryPrice,
                                   double slPercent,
                                   bool isBullish)
     {
      double length = MathAbs(price2 - price1);
      double slPoints = length * slPercent;
      double sl = 0;

      if(isBullish)
         sl = entryPrice - slPoints;
      else
         if(!isBullish)
            sl = entryPrice + slPoints;
      return sl;
     }
   //  Method to find the index of a value in an array
   int               findMatchIdx(double value,
                                  double &array[])
     {
      for(int i = 0; i < ArraySize(array); i++)
        {
         if(value == array[i])
           {
            return i;
           }
        }
      return -1;
     }
   //  Method to handle portfolio/risk
   bool              handlePortfolio(double riskPercent, double stopLossPoints, double lotsize)
     {
      double maxRisk = (riskPercent / 100.0) * ExtIniaccountBalance;
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double requiredMargin = 0;
      double pipValue = tickValue * currencyTicks;
      double riskAmount = (pipValue / tickSize) * stopLossPoints * (lotsize);
      Print("[ ", symbol,"Risk Amount: ", riskAmount, " ]");
      if(riskAmount > maxRisk)
        {
         Print("[ ", symbol,"  Trade risk is too high. Risk amount: ", riskAmount, " exceeds max allowable risk per trade: ", maxRisk, " ]");
         return false;
        }
      if(OrderCalcMargin(ORDER_TYPE_BUY,
                         symbol,
                         (lotsize),
                         SymbolInfoDouble(symbol, SYMBOL_BID),
                         requiredMargin))
        {
         if(requiredMargin > freeMargin)
           {
            Print("[ ", symbol,"  Not enough margin to open the position. Required margin: ", requiredMargin, " Free margin: ", freeMargin, " ]");
            return false;
           }
        }
      else
        {
         Print("[ ", symbol,"  ERROR CALCULATING MARGIN ]");
         return false;
        }
      return true;
     }
   // Method to check the current trading session
   bool              IsTradingSession(int sessionMask)
     {
      // Get the current time
      datetime currentTime = TimeCurrent();
      MqlDateTime timeStruct;
      TimeToStruct(currentTime, timeStruct);

      int hour = timeStruct.hour;
      int minute = timeStruct.min;

      // Restrict trading between 1 hour before midnight and 2 hours after
      if(hour < 2)
        {
         return false;
        }

      // Define session time ranges
      bool isAsianSession  = (hour >= 0 && hour < 9);
      bool isLondonSession = (hour >= 8 && hour < 17);
      bool isNYSession     = (hour >= 13 && hour < 22);
      bool isLateNySession = (hour >= 21 && hour < 23);
      bool isSydneySession = (hour >= 22 || hour < 7);

      // Check the session combinations based on sessionMask
      switch(sessionMask)
        {
         case 1:  // Only Asian Session
            return isAsianSession;
         case 2:  // Only London Session
            return isLondonSession;
         case 3:  // Asian + London Sessions
            return isAsianSession || isLondonSession;
         case 4:  // Only NY Session
            return isNYSession;
         case 5:  // Asian + NY Sessions
            return isAsianSession || isNYSession;
         case 6:  // London + NY Sessions
            return isLondonSession || isNYSession;
         case 7:  // Asian + London + NY Sessions
            return isAsianSession || isLondonSession || isNYSession;
         case 8:  // Only Late NY Session
            return isLateNySession;
         case 9:  // Asian + Late NY Sessions
            return isAsianSession || isLateNySession;
         case 10: // London + Late NY Sessions
            return isLondonSession || isLateNySession;
         case 11: // Asian + London + Late NY Sessions
            return isAsianSession || isLondonSession || isLateNySession;
         case 12: // NY + Late NY Sessions
            return isNYSession || isLateNySession;
         case 13: // Asian + NY + Late NY Sessions
            return isAsianSession || isNYSession || isLateNySession;
         case 14: // London + NY + Late NY Sessions
            return isLondonSession || isNYSession || isLateNySession;
         case 15: // Asian + London + NY + Late NY Sessions
            return isAsianSession || isLondonSession || isNYSession || isLateNySession;
         case 16: // Only Sydney Session
            return isSydneySession;
         case 17: // Asian + Sydney Sessions
            return isAsianSession || isSydneySession;
         case 18: // London + Sydney Sessions
            return isLondonSession || isSydneySession;
         case 19: // NY + Sydney Sessions
            return isNYSession || isSydneySession;
         case 20: // Late NY + Sydney Sessions
            return isLateNySession || isSydneySession;
         case 21: // Asian + London + Sydney Sessions
            return isAsianSession || isLondonSession || isSydneySession;
         case 22: // Asian + NY + Sydney Sessions
            return isAsianSession || isNYSession || isSydneySession;
         case 23: // London + NY + Sydney Sessions
            return isLondonSession || isNYSession || isSydneySession;
         case 24: // All sessions including Sydney
            return isAsianSession || isLondonSession || isNYSession || isLateNySession || isSydneySession;
         default:  // Invalid sessionMask
            return false;
        }
     }
   // Method to open buy order
   int               openBuyOrder(double takeProfit, double stopLoss, double lotSize)
     {
      // Open the buy trade
      ulong buyTicket = EXTrade.Buy(lotSize,
                                    symbol,
                                    0,
                                    stopLoss,
                                    takeProfit,
                                    "Buy Order");
      if(buyTicket < 0)
        {
         Print("[ ", symbol,"  FAILED TO OPEN BUY ORDER. ERROR CODE: ", EXTrade.ResultRetcode(), " ]");
         return 0;
        }
      return 1;
     }
   // Method to open sell order
   int               openSellOrder(double takeProfit, double stopLoss, double lotSize)
     {
      // Open the sell trade
      ulong sellTicket = EXTrade.Sell(lotSize,
                                      symbol,
                                      0,
                                      stopLoss,
                                      takeProfit,
                                      "Sell Order");
      if(sellTicket < 0)
        {
         Print("[ ", symbol,"  FAILED TO OPEN SELL ORDER. ERROR CODE: ", EXTrade.ResultRetcode(), " ]");
         return 0;
        }
      return 1;
     }


   // Getter for ExtLevelPrices
   double            GetLevelPrice(int index)
     {
      if(index >= 0 && index < 5)
         return ExtLevelPrices[index];
      return 0.0;  // Return a default value if index is out of range
     }
  };

// Global variables for managing multiple symbols
CSymbolTrader *traders[]; // Array to hold symbol traders
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit()
  {
   Print("[ INITIALIZING EXmachina ]");
   double ExtIniaccountBalance = AccountInfoDouble(ACCOUNT_BALANCE); // Get initial account balance
   ExtDrawDownAmount = (drawDownPercent / 100.0) * ExtIniaccountBalance; // Calculate drawdown once globally

   string symbolsToTrade = "XAUUSD,GBPUSD,USDJPY,AUDUSD,EURCAD"; // Comma-separated list of symbols
   string tick = "10,1,1,1,1"; // Corresponding tick sizes for each symbol
// Parse symbols from the input string
   string symbolsArray[];
   StringSplit(symbolsToTrade, ',', symbolsArray); // Split input string by comma
   string tickArray[];
   StringSplit(tick, ',', tickArray); // Split input string by comma

// Initialize traders for each symbol
   ArrayResize(traders, ArraySize(symbolsArray)); // Resize the traders array
   for(int i = 0; i < ArraySize(symbolsArray); i++)
     {
      traders[i] = new CSymbolTrader(symbolsArray[i], StringToInteger(tickArray[i]));
      traders[i].SetInitialAccountBalance(ExtIniaccountBalance);

      // Identify levels and calculate Fibonacci for each symbol
      traders[i].IdentifyLevels();
      traders[i].CalculateFibonacciRetracement(
         traders[i].GetLevelPrice(2),
         traders[i].GetLevelPrice(1)
      ); // Use getter to provide actual prices
     }

   EventSetTimer(15); // Set timer to call OnTimer every 15 seconds
  }

//+------------------------------------------------------------------+
//| Expert OnTimer function                                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(checkDrawDown() == true)
     {
      OnDeinit(-7);
     }

// Identify levels and calculate Fibonacci for each symbol
   for(int i = 0; i < ArraySize(traders); i++)
     {
      traders[i].IdentifyLevels();
      traders[i].CalculateFibonacciRetracement(
         traders[i].GetLevelPrice(2),
         traders[i].GetLevelPrice(1)
      ); // Use getter to provide actual prices
     }
  }

//+------------------------------------------------------------------+
//| Expert OnDeinit function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i = 0; i < ArraySize(traders); i++)
     {
      delete traders[i];
     }
   if(reason == -7)
     {
      Print("[ MINIMUM DRAWDOWN AMOUNT EXCEEDED, DEINITIALIZING... ]");
     }

   int totalSG = ExtBuySignalCount + ExtSellSignalCount;

   Print("[ Total Signals Generated: ", totalSG, " ]");
   Print("[ Total Buy Signals Generated: ", ExtBuySignalCount, " ]");
   Print("[ Total Sell Signals Generated: ", ExtSellSignalCount, " ]");
// Select the history of deals within the range from the start of the strategy to the current time
   if(!HistorySelect(0, TimeCurrent()))
     {
      Print("[ Error in HistorySelect: ", GetLastError(), " ]");
      return;
     }
// Counters for winning and losing trades
   int winningTradesCount = 0;
   int winningTrades = 0;
   int losingTrades = 0;
   ulong ticket = 0;
   double profit = 0;
// Iterate through the trade history
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if(profit > 0)
        {
         winningTradesCount++;
        }
      else
         if(profit < 0)
           {
            losingTrades++;
           }
     }
   winningTrades = winningTradesCount - 1;
// Print the results for winning and losing trades
   Print("[ Total Winning Trades: ", winningTrades, " ]");
   Print("[ Total Losing Trades: ", losingTrades,  " ]");
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
// Call the OnTick method for each symbol trader
   for(int i = 0; i < ArraySize(traders); i++)
     {
      traders[i].processTick();
     }
  }
//+------------------------------------------------------------------+
//| Expert Function to check if price is lower than drawdown amount  |
//+------------------------------------------------------------------+
bool checkDrawDown()
  {
   double currAccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(currAccountBalance < ExtDrawDownAmount)
      return true;
   return false;
  }
//+------------------------------------------------------------------+
