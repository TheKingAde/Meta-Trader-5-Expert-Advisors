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

#define SIGNAL_BUY    1             // Buy signal
#define SIGNAL_NOT    0             // No trading signal
#define SIGNAL_SELL  -1             // Sell signal

double ExtDrawDownAmount = 0;      // Drawdown amount based on percentage
input int      inpDrawDownPercent = 30;         // Default drawdown percentage
input int inppercentageRisk = 3; // Percentage risk per trade
input string symbolsToTrade = "XAUUSD,GBPUSD"; // Comma-separated list of symbols
input string tick = "10,1"; // Corresponding tick sizes for each symbol
input double inplotSize = 0.02; // Lot size

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
   int               ExtBuySignalCount;    // Buy signal count
   int               ExtSellSignalCount;   // Sell signal count
   int               ExtBuyTradeCount;     // Buy trade count
   int               ExtSellTradeCount;    // Sell trade count
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
   ENUM_TIMEFRAMES   period;              // Timeframe for analysis

   // Input parameters
   double            inpLotsize;             // Lotsize
   int               inpSMA_Period;          // Period for SMA
   long               inpcurrencyTicks;       // Currency ticks
   int               inpPercentageRisk;      // Risk percentage

public:
   // Constructor that accepts the symbol as a parameter
                     CSymbolTrader(string pair, long ticks, double lotsize, int percentageRisk)
     {
      symbol = pair;
      inpcurrencyTicks = ticks;                // Store the symbol to trade
      ExtSignalCreated = SIGNAL_NOT;
      ExtCopiedData = 0;
      ExtCountLevels = 0;
      ExtBuySignalCount = 0;
      ExtSellSignalCount = 0;
      ExtBuyTradeCount = 0;
      ExtSellTradeCount = 0;
      ExtLastRetracement = 0;
      ExtCurrentH4SMA = 0;
      ExtIniaccountBalance = 0;
      ExtDrawDownAmount = 0;
      ExtLastSignalTime = 0;
      period = _Period; // Set default timeframe

      inpLotsize = lotsize;               // Default lot size
      inpSMA_Period = 14;              // Default SMA period
      inpPercentageRisk = percentageRisk;           // Default risk percentage         // Default currency ticks
     }

   // Setter for initial account balance
   void              SetInitialAccountBalance(double balance)
     {
      ExtIniaccountBalance = balance; // Assuming ExtIniaccountBalance is a class member
     }


   // Method to identify support and resistance levels using ZigZag
   void              IdentifyLevels()
     {
      // Subtract 2 days in seconds from the current time
      datetime fromTime = TimeLocal() - 2 * 24 * 60 * 60;
      datetime toTime = TimeLocal(); // Current local time

      // Retrieve data for the specific symbol
      ExtCopiedData = CopyRates(symbol, PERIOD_M1, fromTime, toTime, ExtChartData);
      if(ExtCopiedData <= 0)
        {
         // Print("Failed to retrieve data for symbol: ", symbol);
         return;
        }
      ArraySetAsSeries(ExtChartData, true);

      // Create ZigZag indicator handle for the specific symbol
      int zigzagDepth = 12;
      int zigzagDeviation = 7;
      int zigzagBackstep = 5;
      ExtZigzagHandle = iCustom(symbol, 0, "Examples/ZigZag", zigzagDepth, zigzagDeviation, zigzagBackstep);

      if(ExtZigzagHandle == INVALID_HANDLE)
        {
         //Print("Failed to apply ZigZag on symbol: ", symbol);
         return;
        }

      // Retrieve ZigZag data for the specific symbol
      int copiedZigzagData = CopyBuffer(ExtZigzagHandle, 0, 0, ExtCopiedData, ExtZigzagData);
      if(copiedZigzagData <= 0)
        {
         //Print("Failed to copy ZigZag buffer for symbol: ", symbol);
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
   //+------------------------------------------------------------------+
   //| Expert tick function                                             |
   //+------------------------------------------------------------------+
   void              processTick()
     {
      // Check if it's the right trading session
      if(!IsTradingSession(1))
         return;
      // Check if 1hr have passed since the last signal
      if((TimeCurrent() - ExtLastSignalTime) > 3600)
        {
         ExtSignalCreated = SIGNAL_NOT;
         ExtLastRetracement = 0;
         ExtLastSignalTime = 0;
        }
      // Get the current tick data
      if(!SymbolInfoTick(symbol, ExtLast_tick))
        {
         Print("[===============================================]");
         Print(symbol,"  Error in SymbolInfoTick. Error code = ", GetLastError());
         Print("[===============================================]");
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
         Print("[==================================================]");
         Print(symbol,"  Error getting H4 SMA data. Error code = ", GetLastError());
         Print("[==================================================]");
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
               datetime expiryTime = TimeCurrent() + 3600;
               Print("[=======================================================]");
               Print(symbol,"  Sell signal created, expiry time: ", expiryTime);
               Print("                  Last retracement: ", ExtLevelPrices[1]);
               Print("[=======================================================]");
               ExtLastRetracement = ExtLevelPrices[1];
               ExtSellSignalCount++;
               ExtLastSignalTime = TimeCurrent();
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
                  datetime expiryTime = TimeCurrent() + 3600;
                  Print("[======================================================]");
                  Print(symbol,"  Buy signal created, expiry time: ", expiryTime);
                  Print("                 Last retracement: ", ExtLevelPrices[1]);
                  Print("[======================================================]");
                  ExtLastRetracement = ExtLevelPrices[1];
                  ExtBuySignalCount++;
                  ExtLastSignalTime = TimeCurrent();
                 }
              }
        }
      if(ExtSignalCreated == SIGNAL_BUY)
        {
         if(ExtLast_tick.bid < ExtLastRetracement)
           {
            Print("[==================]");
            Print(symbol,"  Structure Broken");
            Print("[==================]");
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
               Print("[==================]");
               Print(symbol,"  Structure Broken");
               Print("[==================]");
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
   //+------------------------------------------------------------------+
   //  Expert Function to monitor price and open a position             |
   //+------------------------------------------------------------------+
   void              MonitorPriceAndOpenPosition(double lastTickPrice,
         bool isBullish)
     {
      if(isBullish)
        {
         if(findMatchIdx(ExtLastRetracement,
                         ExtLevelPrices) == -1)
           {
            Print("[==============]");
            Print(symbol,"  Missed Entry");
            Print("[==============]");
            ExtSignalCreated = SIGNAL_NOT;
            ExtLastRetracement = 0;
            return;
           }
         if(ExtLastRetracement == ExtLevelPrices[4]) // // Second retracement after signal
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
               //double tp = lastTickPrice + (slPoints * 3);
               double RR = tpPoints/slPoints;
               int orderStatus = 0;
               if(RR >= 3)
                 {
                  if(handlePortfolio(inpPercentageRisk,
                                     slPoints) == false)
                    {
                     ExtSignalCreated = SIGNAL_NOT;
                     ExtLastRetracement = 0;
                     return;
                    }
                  orderStatus = openBuyOrder(takeProfit,
                                             stopLoss,
                                             inpLotsize);
                  if(orderStatus == 1)
                    {
                     double tp = lastTickPrice - tpPoints;
                     double sl = lastTickPrice + slPoints;

                     orderStatus = openSellOrder(tp,
                                                sl,
                                                inpLotsize);
                     ExtSignalCreated = SIGNAL_NOT;
                     ExtLastRetracement = 0;
                    }
                  else
                    {
                     Print("[=================================]");
                     Print(symbol,"  Failed to open order resetting");
                     Print("[=================================]");
                     ExtSignalCreated = SIGNAL_NOT;
                     ExtLastRetracement = 0;
                    }
                 }
               else
                 {
                  Print("[=====================================]");
                  Print(symbol,"  Signal doesn't meet R:R requirement");
                  Print("[=====================================]");
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
               Print("[==============]");
               Print(symbol,"  Missed Entry");
               Print("[==============]");
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
                     if(handlePortfolio(inpPercentageRisk,
                                        slPoints) == false)
                       {
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                        return;
                       }
                     orderStatus = openSellOrder(takeProfit,
                                                 stopLoss,
                                                 inpLotsize);
                     if(orderStatus == 1)
                       {
                        double tp = lastTickPrice + tpPoints;
                        double sl = lastTickPrice - slPoints;
                        
                        orderStatus = openBuyOrder(tp,
                                                    sl,
                                                    inpLotsize);
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                       }
                     else
                       {
                        Print("[=================================]");
                        Print(symbol,"  Failed to open order resetting");
                        Print("[=================================]");
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                       }
                    }
                 }
               else
                 {
                  Print("[=====================================]");
                  Print(symbol,"  Signal doesn't meet R:R requirement");
                  Print("[=====================================]");
                  ExtSignalCreated = SIGNAL_NOT;
                  ExtLastRetracement = 0;
                 }
              }
           }
     }
   //+------------------------------------------------------------------+
   //|   Expert Function to calculate Stop Loss and Take Profit         |
   //+------------------------------------------------------------------+
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
   //+------------------------------------------------------------------+
   //|  Expert Function to find the index of a value in an array        |
   //+------------------------------------------------------------------+
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

   //+------------------------------------------------------------------+
   //|  Expert Function  to handle portfolio/risk                       |
   //+------------------------------------------------------------------+
   bool              handlePortfolio(double riskPercent, double stopLossPoints)
     {
      double maxRisk = (riskPercent / 100.0) * ExtIniaccountBalance;
      Print(riskPercent);
      Print(ExtIniaccountBalance);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double requiredMargin = 0;
      // 1 pip = 10 ticks
      Print(inpcurrencyTicks);
      double pipValue = tickValue * inpcurrencyTicks;
      // Calculate the risk amount in currency
      double riskAmount = (pipValue / tickSize) * stopLossPoints * (inpLotsize * 2);
      Print("[=======================]");
      Print(symbol,"Risk Amount: ", riskAmount);
      Print("[=======================]");
      if(riskAmount > maxRisk)
        {
         Print("[======================================================================================]");
         Print(symbol,"  Trade risk is too high. Risk amount: ", riskAmount, " exceeds max allowable risk per trade: ", maxRisk);
         Print("[======================================================================================]");
         return false;
        }
      if(OrderCalcMargin(ORDER_TYPE_BUY,
                         symbol,
                         (inpLotsize * 2),
                         SymbolInfoDouble(symbol, SYMBOL_BID),
                         requiredMargin))
        {
         if(requiredMargin > freeMargin)
           {
            Print("[===============================================================================]");
            Print(symbol,"  Not enough margin to open the position. Required margin: ", requiredMargin, " Free margin: ", freeMargin);
            Print("[===============================================================================]");
            return false;
           }
        }
      else
        {
         Print("[===========================]");
         Print(symbol,"  Error calculating margin.");
         Print("[===========================]");
         return false;
        }
      return true;
     }
   //+------------------------------------------------------------------+
   //| Expert Function to check the current trading session             |
   //+------------------------------------------------------------------+
   bool              IsTradingSession(int type)
     {
      datetime currentTime = TimeCurrent();
      MqlDateTime timeStruct;
      TimeToStruct(currentTime, timeStruct);
      int hour = timeStruct.hour;
      int minute = timeStruct.min;
      // Asian session: 00:00 AM - 09:00 AM
      bool isAsianSession = (hour >= 2 && hour < 9); // 2 hr after asian session begins
      // London session: 8:00 AM - 5:00 PM
      bool isLondonSession = (hour > 8 || (hour == 8 && minute >= 0))
                             && (hour < 17 || (hour == 17 && minute == 0));
      // New York session: 1:00 PM - 10:00 PM
      bool isNYSession = (hour > 13 || (hour == 13 && minute >= 0))
                         && (hour < 22 || (hour == 22 && minute == 0));
      bool isLateNySession = (hour > 21 || (hour == 21 && minute >= 0))
                             && (hour < 23 || (hour == 23 && minute == 40));
      // Trading is allowed only during specified session(s)
      if(type == 1)
        {
         if(isNYSession
            || isAsianSession
            || isLateNySession
            || isLondonSession)
           {
            return true;
           }
        }
      else
         if(type == 2)
           {
            if(isLondonSession
               || isNYSession)
              {
               return true;
              }
           }
      return false;
     }
   //+------------------------------------------------------------------+
   //| Expert Function to open buy order                                |
   //+------------------------------------------------------------------+
   int               openBuyOrder(double takeProfit, double stopLoss, double lotSize)
     {
      // Open the buy trade
      ulong buyTicket = EXTrade.Buy(lotSize,
                                    symbol,
                                    0,
                                    stopLoss,
                                    takeProfit,
                                    "Buy Order");
      if(buyTicket > 0)
        {
         ExtBuyTradeCount++;
        }
      else
        {
         Print("[========================================]");
         Print(symbol,"  Failed to open Sell order. Error code: ", EXTrade.ResultRetcode());
         Print("[========================================]");
         return 0;
        }
      return 1;
     }
   //+------------------------------------------------------------------+
   //| Expert Function to open sell order                               |
   //+------------------------------------------------------------------+
   int               openSellOrder(double takeProfit, double stopLoss, double lotSize)
     {
      // Open the sell trade
      ulong sellTicket = EXTrade.Sell(lotSize,
                                      symbol,
                                      0,
                                      stopLoss,
                                      takeProfit,
                                      "Sell Order");
      if(sellTicket > 0)
        {
         ExtSellTradeCount++;
        }
      else
        {
         Print("[========================================]");
         Print(symbol,"  Failed to open Sell order. Error code: ", EXTrade.ResultRetcode());
         Print("[========================================]");
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

   // Additional methods for trade management, etc.
  };
// Global variables for managing multiple symbols
CSymbolTrader *traders[]; // Array to hold symbol traders

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit()
  {
   Print("[=============================]");
   Print("  Initializing EXmachina");
   Print("[=============================]");

// Calculate initial account balance and drawdown once globally
   double ExtIniaccountBalance = AccountInfoDouble(ACCOUNT_BALANCE); // Get initial account balance
   Print(ExtIniaccountBalance);
   ExtDrawDownAmount = (inpDrawDownPercent / 100.0) * ExtIniaccountBalance;

// Parse symbols from the input string
   string symbolsArray[];
   StringSplit(symbolsToTrade, ',', symbolsArray); // Split input string by comma
   string tickArray[];
   StringSplit(tick, ',', tickArray); // Split input string by comma

// Initialize traders for each symbol
   ArrayResize(traders, ArraySize(symbolsArray)); // Resize the traders array
   for(int i = 0; i < ArraySize(symbolsArray); i++)
     {
      traders[i] = new CSymbolTrader(symbolsArray[i], StringToInteger(tickArray[i]), inplotSize, inppercentageRisk);
      traders[i].SetInitialAccountBalance(ExtIniaccountBalance);

      // Identify levels and calculate Fibonacci for each symbol
      traders[i].IdentifyLevels();
      traders[i].CalculateFibonacciRetracement(
         traders[i].GetLevelPrice(2),
         traders[i].GetLevelPrice(1)
      ); // Use getter to provide actual prices
     }

// Further initialization if needed...
   EventSetTimer(15); // Set timer to call OnTimer every 15 seconds
  }

//+------------------------------------------------------------------+
//| Expert OnTimer function                                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(checkDrawDown() == true)
     {
      Print("[===============================================]");
      Print("  Min draw down amount exceeded, deinitializing");
      Print("[===============================================]");
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
      Print("[==============================================================]");
      Print("  Deinitializing because balance has exceeded draw down amount");
      Print("[=============================================================]");
     }
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
