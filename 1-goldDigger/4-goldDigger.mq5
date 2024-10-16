//+------------------------------------------------------------------+
//|                                                   goldDigger.mq5 |
//|                                      Copyright 2024, KingAde, TAC|
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, KingAde, TAC."
#property link      "https://twitter.com/Kingade_1"
#property description "Main with 0.5 sl without 1hr signal limit"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>

#define SIGNAL_BUY    1             // Buy signal
#define SIGNAL_NOT    0             // no trading signal
#define SIGNAL_SELL  -1             // Sell signal

// Global variables
MqlTick ExtLast_tick; // Chart data
MqlRates ExtChartData[]; // Chart data for zig zag indicator
int ExtSignalCreated = SIGNAL_NOT;
int ExtCopiedData = 0;
int ExtCountLevels = 0; //Variable to count levles
int ExtZigzagHandle;
int ExtBuySignalCount = 0; // Count buy and sell signals
int ExtSellSignalCount = 0;
int ExtBuyTradeCount = 0; // Count buy and sell trades
int ExtSellTradeCount = 0;
int ExtSma_handle4H = 0; // Simple moving average handle
double ExtCurrFibLevels[7]; // Store the current Fibonacci levels
double ExtLevelPrices[5]; // Store level prices
double ExtSma4H[]; // Store candle stick data
double ExtZigzagData[];
double ExtLastRetracement = 0;
double ExtCurrentH4SMA = 0; // Store current sma value
double ExtIniaccountBalance = 0;
double ExtDrawDownAmount = 0;
datetime ExtLastSignalTime = 0; // Track if a signal has been generated and time of creation
datetime ExtLevelTimes[5]; // Store level times
ENUM_TIMEFRAMES period = _Period;
// Input parameters
input double inpLotsize = 0.02; // Lotsize variable
input int inpSMA_Period = 14; // Period for SMA
input int inpDrawDownPercent = 30;
input int inpPercentageRisk = 3;

CTrade EXTrade; // library for handling trades

//+------------------------------------------------------------------+
//| Expert Oninit function                                           |
//+------------------------------------------------------------------+
void OnInit()
  {
   Print("[=============================]");
   Print("  Initializing goldDigger.ex5");
   Print("[=============================]");
   IdentifyLevels();  // identify support and resistance levels
   ExtIniaccountBalance = AccountInfoDouble(ACCOUNT_BALANCE); // Get initial account balance
   ExtDrawDownAmount = (inpDrawDownPercent / 100.0) * ExtIniaccountBalance;
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
   IdentifyLevels();
   CalculateFibonacciRetracement(ExtLevelPrices[2],
                                 ExtLevelPrices[1],
                                 ExtCurrFibLevels);
  }
//+------------------------------------------------------------------+
//| Expert OnDeinit function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(reason == -7)
     {
      Print("[==============================================================]");
      Print("  Deinitializing because balance has exceeded draw down amount");
      Print("[=============================================================]");
     }
   int totalSTE = ExtBuyTradeCount + ExtSellTradeCount;
   int totalSG = ExtBuySignalCount + ExtSellSignalCount;
// Counters for winning and losing trades
   int winningTradesCount = 0;
   int winningTrades = 0;
   int losingTrades = 0;
   ulong ticket = 0;
   double profit = 0;
// Print the total number of buy and sell signals generated
   Print("[==============================================]");
   Print("                Total Signals Generated: ", totalSG);
   Print("            Total Buy Signals Generated: ", ExtBuySignalCount);
   Print("           Total Sell Signals Generated: ", ExtSellSignalCount);
// Print the total number of successfully opened buy and sell trades
   Print("       Total Successful Trade Execution: ", totalSTE);
   Print("   Total Buy Successful Trade Execution: ", ExtBuyTradeCount);
   Print("  Total Sell Successful Trade Execution: ", ExtSellTradeCount);
   Print("[==============================================]");
// Select the history of deals within the range from the start of the strategy to the current time
   if(!HistorySelect(0, TimeCurrent()))
     {
      Print("[=====================================]");
      Print("  Error in HistorySelect: ", GetLastError());
      Print("[=====================================]");
      return;
     }
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
   Print("[============================]");
   Print("  Total Winning Trades: ", winningTrades);
   Print("   Total Losing Trades: ", losingTrades);
   Print("[============================]");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
// Check if it's the right trading session
   if(!IsTradingSession(1))
      return;
// Get the current tick data
   if(!SymbolInfoTick(Symbol(), ExtLast_tick))
     {
      Print("[===============================================]");
      Print("  Error in SymbolInfoTick. Error code = ", GetLastError());
      Print("[===============================================]");
      return;
     }
// Simple moving averages
   ExtSma_handle4H = iMA(Symbol(),
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
      Print("  Error getting H4 SMA data. Error code = ", GetLastError());
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
            Print("  Sell signal created, expiry time: ", expiryTime);
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
               Print("  Buy signal created, expiry time: ", expiryTime);
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
         Print("  Structure Broken");
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
            Print("  Structure Broken");
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
void MonitorPriceAndOpenPosition(double lastTickPrice,
                                 bool isBullish)
  {
   if(isBullish)
     {
      if(findMatchIdx(ExtLastRetracement,
                      ExtLevelPrices) == -1)
        {
         Print("[==============]");
         Print("  Missed Entry");
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
            double tp = lastTickPrice + (slPoints * 3);
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
                  orderStatus = openBuyOrder(tp,
                                             stopLoss,
                                             inpLotsize);
                  ExtSignalCreated = SIGNAL_NOT;
                  ExtLastRetracement = 0;
                 }
               else
                 {
                  Sleep(3000);
                  Print("[==========]");
                  Print("  Retrying");
                  Print("[==========]");
                  orderStatus = openBuyOrder(takeProfit,
                                             stopLoss,
                                             inpLotsize);
                  if(orderStatus == 1)
                    {
                     orderStatus = openBuyOrder(tp,
                                                stopLoss,
                                                inpLotsize);
                     ExtSignalCreated = SIGNAL_NOT;
                     ExtLastRetracement = 0;
                    }
                  else
                    {
                     Sleep(3000);
                     Print("[==========]");
                     Print("  Retrying");
                     Print("[==========]");
                     orderStatus = openBuyOrder(takeProfit,
                                                stopLoss,
                                                inpLotsize);
                     if(orderStatus == 1)
                       {
                        orderStatus = openBuyOrder(tp,
                                                   stopLoss,
                                                   inpLotsize);
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                       }
                     else
                       {
                        Print("[===========]");
                        Print("  Resetting");
                        Print("[===========]");
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                       }
                    }
                 }
              }
            else
              {
               Print("[=====================================]");
               Print("  Signal doesn't meet R:R requirement");
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
            Print("  Missed Entry");
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
                     orderStatus = openSellOrder(tp,
                                                 stopLoss,
                                                 inpLotsize);
                     ExtSignalCreated = SIGNAL_NOT;
                     ExtLastRetracement = 0;
                    }
                  else
                    {
                     Sleep(5000);
                     Print("[==========]");
                     Print("  Retrying");
                     Print("[==========]");
                     orderStatus = openSellOrder(takeProfit,
                                                 stopLoss,
                                                 inpLotsize);
                     if(orderStatus == 1)
                       {
                        orderStatus = openSellOrder(tp,
                                                    stopLoss,
                                                    inpLotsize);
                        ExtSignalCreated = SIGNAL_NOT;
                        ExtLastRetracement = 0;
                       }
                     else
                       {
                        Sleep(5000);
                        Print("[==========]");
                        Print("  Retrying");
                        Print("[==========]");
                        orderStatus = openSellOrder(takeProfit,
                                                    stopLoss,
                                                    inpLotsize);
                        if(orderStatus == 1)
                          {
                           orderStatus = openSellOrder(tp,
                                                       stopLoss,
                                                       inpLotsize);
                           ExtSignalCreated = SIGNAL_NOT;
                           ExtLastRetracement = 0;
                          }
                        else
                          {
                           Print("[===========]");
                           Print("  Resetting");
                           Print("[===========]");
                           ExtSignalCreated = SIGNAL_NOT;
                           ExtLastRetracement = 0;
                          }
                       }
                    }
                 }
               else
                 {
                  Print("[=====================================]");
                  Print("  Signal doesn't meet R:R requirement");
                  Print("[=====================================]");
                  ExtSignalCreated = SIGNAL_NOT;
                  ExtLastRetracement = 0;
                 }
              }
           }
        }
  }
//+------------------------------------------------------------------+
//|   Expert Function to calculate Stop Loss and Take Profit         |
//+------------------------------------------------------------------+
double calculateExit(double price2,
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
int findMatchIdx(double value,
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
//|  Expert Function  to handle portfolio/risk                       |
//+------------------------------------------------------------------+
bool handlePortfolio(double riskPercent, double stopLossPoints)
  {
   string symbol = Symbol();
   double maxRisk = (riskPercent / 100.0) * ExtIniaccountBalance;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double requiredMargin = 0;
// 1 pip = 10 ticks
   double pipValue = tickValue * 10;
// Calculate the risk amount in currency
   double riskAmount = (pipValue / tickSize) * stopLossPoints * (inpLotsize * 2);
   Print("[=======================]");
   Print("Risk Amount: ", riskAmount);
   Print("[=======================]");
   if(riskAmount > maxRisk)
     {
      Print("[======================================================================================]");
      Print("  Trade risk is too high. Risk amount: ", riskAmount, " exceeds max allowable risk per trade: ", maxRisk);
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
         Print("  Not enough margin to open the position. Required margin: ", requiredMargin, " Free margin: ", freeMargin);
         Print("[===============================================================================]");
         return false;
        }
     }
   else
     {
      Print("[===========================]");
      Print("  Error calculating margin.");
      Print("[===========================]");
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//| Expert Function to check the current trading session             |
//+------------------------------------------------------------------+
bool IsTradingSession(int type)
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
int openBuyOrder(double takeProfit, double stopLoss, double lotSize)
  {
// Open the buy trade
   ulong buyTicket = EXTrade.Buy(lotSize,
                                 Symbol(),
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
      Print("  Failed to open Sell order. Error code: ", EXTrade.ResultRetcode());
      Print("[========================================]");
      return 0;
     }
   return 1;
  }
//+------------------------------------------------------------------+
//| Expert Function to open sell order                               |
//+------------------------------------------------------------------+
int openSellOrder(double takeProfit, double stopLoss, double lotSize)
  {
// Open the sell trade
   ulong sellTicket = EXTrade.Sell(lotSize,
                                   Symbol(),
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
      Print("  Failed to open Sell order. Error code: ", EXTrade.ResultRetcode());
      Print("[========================================]");
      return 0;
     }
   return 1;
  }
//+------------------------------------------------------------------+
//| Expert Function to identify levels                               |
//+------------------------------------------------------------------+
void IdentifyLevels()
  {
// Subtract 2 days in sec from the current time
   datetime fromTime = TimeLocal() - 2 * 24 * 60 * 60;
   datetime toTime = TimeLocal(); // Current local time
// Retrieve data
   ExtCopiedData = CopyRates(NULL,
                             PERIOD_M1,
                             fromTime,
                             toTime,
                             ExtChartData);
   if(ExtCopiedData <= 0)
     {
      //Print("Failed to retrieve data");
      return;
     }
   ArraySetAsSeries(ExtChartData, true);
// Create ZigZag indicator handle
   int zigzagDepth = 12;
   int zigzagDeviation = 7;
   int zigzagBackstep = 5;
   ExtZigzagHandle = iCustom(NULL,
                             0,
                             "Examples/ZigZag",
                             zigzagDepth,
                             zigzagDeviation,
                             zigzagBackstep);
   if(ExtZigzagHandle == INVALID_HANDLE)
     {
      Print("[==========================]");
      Print("  Failed to apply ZigZag");
      Print("[==========================]");
      return;
     }
// Retrieve ZigZag data
   int copiedZigzagData = CopyBuffer(ExtZigzagHandle,
                                     0,
                                     0,
                                     ExtCopiedData,
                                     ExtZigzagData);
   if(copiedZigzagData <= 0)
     {
      Print("[===============================]");
      Print("  Failed to copy ZigZag buffer");
      Print("[===============================]");
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
//+------------------------------------------------------------------+
//| Expert Function to calculate Fibonacci retracement levels        |
//+------------------------------------------------------------------+
void CalculateFibonacciRetracement(double price1,
                                   double price2,
                                   double &levels[])
  {
   if(price1 < price2)
     {
      // Uptrend: Calculate levels from price1 (low) to price2 (high)
      levels[0] = price1;                                  // 100%
      levels[1] = price1 + 0.236 * (price2 - price1);       // 76.4%
      levels[2] = price1 + 0.382 * (price2 - price1);       // 61.8%
      levels[3] = price1 + 0.5 * (price2 - price1);         // 50%
      levels[4] = price1 + 0.618 * (price2 - price1);       // 38.2%
      levels[5] = price1 + 0.764 * (price2 - price1);       // 23.6%
      levels[6] = price2;                                   // 0%
     }
   else
      if(price1 > price2)
        {
         // Downtrend: Calculate levels from price1 (high) to price2 (low)
         levels[0] = price1;                                  // 100%
         levels[1] = price1 - 0.236 * (price1 - price2);       // 76.4%
         levels[2] = price1 - 0.382 * (price1 - price2);       // 61.8%
         levels[3] = price1 - 0.5 * (price1 - price2);         // 50%
         levels[4] = price1 - 0.618 * (price1 - price2);       // 38.2%
         levels[5] = price1 - 0.764 * (price1 - price2);       // 23.6%
         levels[6] = price2;                                   // 0%
        }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
