//+------------------------------------------------------------------+
//|                                                   goldDigger.mq5 |
//|                                     Copyright 2021, KingAde, TAC.|
//|                                             https://www.tac.com  |
//+------------------------------------------------------------------+
#property copyright "2024, TAC"
#property link      "https://www.tac.com"
#property version   "1.00"
#property strict

#include "tacEA-ID-lvl.mqh"
#include "tac-GenerateSignals.mqh"
#include "tacEA-BB.mqh"
#include <Trade\Trade.mqh>

// Global variables to count buy and sell signals
int buySignalCount = 0;
int sellSignalCount = 0;

// Global variable to count buy and sell trades
int buyTradeCount = 0;
int sellTradeCount = 0;

double breakEvenPoints = 0;// Array to store Bollinger Bands levels

// Variable to track the type of the last trade opened
int lastTrade = 0; // 0 indicates no trades yet, 1 for trades
// Variables to track the time of the last signal and trade opened
datetime lastTradeTime = 0;

// Variable to track if a signal has been generated
int signalCreated = 0;
datetime lastSignalTime = 0;

// Array to store simple moving average levels
double sma[];
double sma4[];
// Simple moving average handle
int sma_handle4 = 0;
int sma_handle = 0;
// Variable to store current sma value
double currentSMA = 0;
double currentH4SMA = 0;

double lowerLevel = 0;
double upperLevel = 0;

int idSequence = 0;

// Input parameters
input int SMA_Period = 14; // Period for SMA
ENUM_TIMEFRAMES period = _Period;

// library for handling trades
CTrade trade;

// Get chart data
MqlTick last_tick;

// Define the struct to hold candlestick data
struct Candlestick
  {
   double            open;
   double            high;
   double            low;
   double            close;
   datetime          time;
  };


// Define the structure for a candlestick sequence
struct CandlestickSequence
  {
   double            size;             // Total size of the bullish sequence
   datetime          startTime;      // Start time of the sequence
   datetime          endTime;        // End time of the sequence
   double            endHighPrice;     // Close price of the last candle in the sequence
   double            endLowPrice;
  };

CandlestickSequence bullishSequences[];
CandlestickSequence bearishSequences[];

//+------------------------------------------------------------------+
//| Expert Oninit function                                            |
//+------------------------------------------------------------------+
void OnInit()
  {
   Print("Starting...");
   IdentifyLevels();
   CalculateFibonacciRetracement(levelPrices[2], levelPrices[1], currFibLevels);
   DrawCurrFibonacciRetracement(levelPrices[2], levelPrices[1], currFibLevels);
   EventSetTimer(15); // Set timer to call OnTimer every 15 seconds
  }

//+------------------------------------------------------------------+
//| Expert OnTimer function                                           |
//+------------------------------------------------------------------+
void OnTimer()
  {
   IdentifyLevels();
   CalculateFibonacciRetracement(levelPrices[2], levelPrices[1], currFibLevels);
   DrawCurrFibonacciRetracement(levelPrices[2], levelPrices[1], currFibLevels);
  }

//+------------------------------------------------------------------+
//| Expert OnDeinit function                                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   int buyFTE = buySignalCount - buyTradeCount;
   int sellFTE = sellSignalCount - sellTradeCount;
   int totalFTE = buyFTE + sellFTE;
   int totalSTE = buyTradeCount + sellTradeCount;
   int totalSG = buySignalCount + sellSignalCount;

// Print the total number of buy and sell signals generated
   Print("Total signals generated: ", totalSG);
   Print("Total Buy signals generated: ", buySignalCount);
   Print("Total Sell signals generated: ", sellSignalCount);
// Print the total number of successfully opened buy and sell trades
   Print("Total Successful Trade Execution: ", totalSTE);
   Print("Total Buy Successful Trade Execution: ", buyTradeCount);
   Print("Total Sell Successful Trade Execution: ", sellTradeCount);
// Print the total number of failed trade execution
   Print("Total Failed Trade Execution: ", totalFTE);
   Print("Total Buy Failed Trade Execution: ", buyFTE);
   Print("Total Sell Failed Trade Execution: ", sellFTE);

// Select the history of deals within the range from the start of the strategy to the current time
   if(!HistorySelect(0, TimeCurrent()))
     {
      Print("Error in HistorySelect: ", GetLastError());
      return;
     }

// Counters for winning and losing trades
   int winningTrades = 0;
   int losingTrades = 0;
// Iterate through the trade history
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if(profit > 0)
        {
         winningTrades++;
        }
      else
         if(profit < 0)
           {
            losingTrades++;
           }
     }

// Print the results for winning and losing trades
   Print("Total Winning Trades: ", winningTrades);
   Print("Total Losing Trades: ", losingTrades);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
// Check if it's the right trading session
   if(!IsTradingSession(1))
     {
      return;
     }

// Get the current tick data
   if(!SymbolInfoTick(Symbol(), last_tick))
     {
      Print("Error in SymbolInfoTick. Error code = ", GetLastError());
      return;
     }

// Simple moving averages
   sma_handle = iMA(Symbol(), period, SMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   if(CopyBuffer(sma_handle, 0, 0, 1, sma) <= 0)
     {
      Print("Error getting 1MIN SMA data. Error code = ", GetLastError());
      return;
     }
   sma_handle4 = iMA(Symbol(), PERIOD_H4, SMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   if(CopyBuffer(sma_handle4, 0, 0, 1, sma4) <= 0)
     {
      Print("Error getting H4 SMA data. Error code = ", GetLastError());
      return;
     }
   currentH4SMA = sma4[0];
   currentSMA = sma[0];

   if(signalCreated == 0)
     {
      // Identify patterns and set signalCreated flag accordingly
      if((levelPrices[1] > levelPrices[2]
          && levelPrices[1] >= levelPrices[3]
          && levelPrices[1] > levelPrices[4]
          && levelPrices[3] > levelPrices[4]
          && levelPrices[3] > levelPrices[2]
          && levelPrices[4] >= levelPrices[2]))
        {
         if(last_tick.ask <= levelPrices[2])
           {
            signalCreated = -1;
           }
        }
      else
         if((levelPrices[2] > levelPrices[1]
             && levelPrices[2] > levelPrices[4]
             && levelPrices[2] > levelPrices[3]
             && levelPrices[3] > levelPrices[1]
             && levelPrices[4] > levelPrices[3]
             && levelPrices[4] > levelPrices[1]))
           {
            if(last_tick.bid >= levelPrices[2])
              {
               signalCreated = 1;
              }
           }
     }

   if(signalCreated == 1) // Execute trades after a buy signal has been generated
     {
      if(levelPrices[1] > levelPrices[2] && idSequence ==  0)
        {
         // Calculate the number of candlesticks between levels
         int lowerIndex = iBarShift(Symbol(), period, levelTimes[2], true);
         int upperIndex = iBarShift(Symbol(), period, levelTimes[1], true);

         if(lowerIndex == -1 || upperIndex == -1 || upperIndex > lowerIndex)
           {
            Print("Invalid indices. Ensure levelTimes are correctly defined.");
            return;
           }

         int numCandles = lowerIndex - upperIndex + 1;

         // Create an array to store the candlesticks
         Candlestick candles[];
         ArrayResize(candles, numCandles);

         // Populate the array with candlestick data
         for(int i = 0; i < numCandles; i++)
           {
            int candleIndex = upperIndex + i;
            candles[i].open = iOpen(Symbol(), period, candleIndex);
            candles[i].high = iHigh(Symbol(), period, candleIndex);
            candles[i].low = iLow(Symbol(), period, candleIndex);
            candles[i].close = iClose(Symbol(), period, candleIndex);
            candles[i].time = iTime(Symbol(), period, candleIndex);
           }

         double currentConsecutiveSize = 0;
         datetime currentStartTime = candles[0].time;
         bool inConsecutive = false;

         for(int i = 0; i < numCandles; i++)
           {
            double candleSize = MathAbs(candles[i].close - candles[i].open);

            // Identify bullish candlesticks
            if(candles[i].close > candles[i].open)
              {
               if(!inConsecutive)
                 {
                  inConsecutive = true;
                  currentStartTime = candles[i].time;
                  currentConsecutiveSize = candleSize;
                 }
               else
                 {
                  currentConsecutiveSize += candleSize;
                 }
              }
            else
              {
               if(inConsecutive)
                 {
                  // Save the completed sequence
                  CandlestickSequence seq;
                  seq.size = currentConsecutiveSize;
                  seq.startTime = currentStartTime;
                  seq.endTime = candles[i - 1].time;
                  seq.endHighPrice = candles[i - 1].high;  // Store the open price of the last candle
                  seq.endLowPrice = candles[i - 1].low;


                  ArrayResize(bullishSequences, ArraySize(bullishSequences) + 1);
                  bullishSequences[ArraySize(bullishSequences) - 1] = seq;

                  // Reset the sequence tracker
                  inConsecutive = false;
                  currentConsecutiveSize = 0;
                 }
              }
           }

         // Check if the last sequence is still active
         if(inConsecutive)
           {
            CandlestickSequence seq;
            seq.size = currentConsecutiveSize;
            seq.startTime = currentStartTime;
            seq.endTime = candles[numCandles - 1].time;
            seq.endHighPrice = candles[numCandles - 1].high;  // Store the open price of the last candle
            seq.endLowPrice = candles[numCandles - 1].low;

            ArrayResize(bullishSequences, ArraySize(bullishSequences) + 1);
            bullishSequences[ArraySize(bullishSequences) - 1] = seq;
           }

         idSequence =  1;
        }
     }
   else
      if(signalCreated == -1) // Execute trades after a sell signal has been generated
        {
         if(levelPrices[2] > levelPrices[1] && idSequence == 0)
           {
            // Calculate the number of candlesticks between levels
            int lowerIndex = iBarShift(Symbol(), period, levelTimes[2], true);
            int upperIndex = iBarShift(Symbol(), period, levelTimes[1], true);

            if(lowerIndex == -1 || upperIndex == -1 || upperIndex > lowerIndex)
              {
               Print("Invalid indices. Ensure levelTimes are correctly defined.");
               return;
              }

            int numCandles = lowerIndex - upperIndex + 1;

            // Create an array to store the candlesticks
            Candlestick candles[];
            ArrayResize(candles, numCandles);

            // Populate the array with candlestick data
            for(int i = 0; i < numCandles; i++)
              {
               int candleIndex = upperIndex + i;
               candles[i].open = iOpen(Symbol(), period, candleIndex);
               candles[i].high = iHigh(Symbol(), period, candleIndex);
               candles[i].low = iLow(Symbol(), period, candleIndex);
               candles[i].close = iClose(Symbol(), period, candleIndex);
               candles[i].time = iTime(Symbol(), period, candleIndex);
              }

            double currentConsecutiveSize = 0;
            datetime currentStartTime = candles[0].time;
            bool inConsecutive = false;

            for(int i = 0; i < numCandles; i++)
              {
               double candleSize = MathAbs(candles[i].close - candles[i].open);

               // Identify bearish candlesticks
               if(candles[i].close < candles[i].open)
                 {
                  if(!inConsecutive)
                    {
                     inConsecutive = true;
                     currentStartTime = candles[i].time;
                     currentConsecutiveSize = candleSize;
                    }
                  else
                    {
                     currentConsecutiveSize += candleSize;
                    }
                 }
               else
                 {
                  if(inConsecutive)
                    {
                     // Save the completed sequence
                     CandlestickSequence seq;
                     seq.size = currentConsecutiveSize;
                     seq.startTime = currentStartTime;
                     seq.endTime = candles[i - 1].time;
                     seq.endHighPrice = candles[i - 1].high;
                     seq.endLowPrice = candles[i - 1].low;  // Store the open price of the last candle

                     ArrayResize(bearishSequences, ArraySize(bearishSequences) + 1);
                     bearishSequences[ArraySize(bearishSequences) - 1] = seq;

                     // Reset the sequence tracker
                     inConsecutive = false;
                     currentConsecutiveSize = 0;
                    }
                 }
              }

            // Check if the last sequence is still active
            if(inConsecutive)
              {
               CandlestickSequence seq;
               seq.size = currentConsecutiveSize;
               seq.startTime = currentStartTime;
               seq.endTime = candles[numCandles - 1].time;
               seq.endHighPrice = candles[numCandles - 1].high;
               seq.endLowPrice = candles[numCandles - 1].low;  // Store the open price of the last candle

               ArrayResize(bearishSequences, ArraySize(bearishSequences) + 1);
               bearishSequences[ArraySize(bearishSequences) - 1] = seq;
              }

            idSequence =  -1;
           }
        }

   if(idSequence == 1)  // For bullish sequences
     {
      // Sort the sequences by size
      SortSequencesBySize(bullishSequences);

      // Array to store the top 3 endHighPrices
      double topBullishEndHighPrices[3];
      // Array to store the 3 entries
      double entries[3];
      GetTop3EndPrices(bullishSequences, topBullishEndHighPrices, true);
      GetEntries(topBullishEndHighPrices, entries, true);
      MonitorPriceAndOpenPosition(last_tick.bid, entries, true);
     }
   else
      if(idSequence == -1)  // For bearish sequences
        {
         // Sort the sequences by size
         SortSequencesBySize(bearishSequences);

         // Array to store the top 3 endLowPrices
         double topBearishEndLowPrices[3];
         // Array to store the 3 entries
         double entries[3];
         GetTop3EndPrices(bearishSequences, topBearishEndLowPrices, false);
         GetEntries(topBearishEndLowPrices, entries, false);
         MonitorPriceAndOpenPosition(last_tick.ask, entries, false);
        }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GetEntries(double &orderBlocks[], double &entries[], bool isBullish)
  {
   int size = ArraySize(currFibLevels);

   for(int i = 0; i < 3; i++)
     {
      for(int j = 0; j < size - 1; j++)
        {
         if(isBullish)
           {
            if(orderBlocks[i] > currFibLevels[i])
               continue;
            else
               if(orderBlocks[i] <= currFibLevels[i])
                 {
                  entries[i] = currFibLevels[i];
                  break;
                 }
           }
         else
            if(!isBullish)
              {
               if(orderBlocks[i] < currFibLevels[i])
                  continue;
               else
                  if(orderBlocks[i] >= currFibLevels[i])
                    {
                     entries[i] = currFibLevels[i];
                     break;
                    }
              }
        }
     }
  }

//+------------------------------------------------------------------+
// Sorting function for sequences based on size
void SortSequencesBySize(CandlestickSequence &sequences[])
  {
   int size = ArraySize(sequences);

   for(int i = 0; i < size - 1; i++)
     {
      for(int j = i + 1; j < size; j++)
        {
         if(sequences[i].size < sequences[j].size)
           {
            // Swap sequences[i] and sequences[j]
            CandlestickSequence temp = sequences[i];
            sequences[i] = sequences[j];
            sequences[j] = temp;
           }
        }
     }
  }

// Function to get the end Price of the top 3 sequences
void GetTop3EndPrices(CandlestickSequence &sequences[], double &endPrices[], bool isBullish, int maxCount = 3)
  {
   int count = MathMin(ArraySize(sequences), maxCount);
   ArrayResize(endPrices, count);

   for(int i = 0; i < count; i++)
     {
      if(isBullish)
         endPrices[i] = sequences[i].endHighPrice;
      else
         if(!isBullish)
            endPrices[i] = sequences[i].endLowPrice;
     }
  }
//+------------------------------------------------------------------+

// Function to monitor price and open a position
void MonitorPriceAndOpenPosition(double lastTickPrice, double &entries[], bool isBullish)
  {
   Print("Monitoring price to open position");
   for(int i = 0; i < ArraySize(entries); i++)
     {
      Print("opening position");
      if(isBullish && lastTickPrice <= entries[i] && lastTickPrice > currentSMA && lastTickPrice > currentH4SMA)
        {
         double takeProfit = lastTickPrice + MathAbs(levelPrices[1] - levelPrices[2]);
         double stopLoss = calculateSL(true) - 1.50;
         if(stopLoss == 0)
           {
            Print("Failed to set SL");
            return;
           }
         double lotSize = 0.01;

         double slPoints = MathAbs(lastTickPrice - stopLoss);
         double tpPoints = MathAbs(lastTickPrice - takeProfit);
         double RR = tpPoints / slPoints;

         int orderStatus = openBuyOrder(takeProfit, stopLoss, lotSize);
         if(orderStatus == 1)
           {
            signalCreated = 0;
            idSequence = 0;
            break;
           }
        }
      else
         if(!isBullish && lastTickPrice >= entries[i] && lastTickPrice < currentSMA && lastTickPrice < currentH4SMA)
           {
            double takeProfit = lastTickPrice - MathAbs(levelPrices[1] - levelPrices[2]);
            double stopLoss = calculateSL(false) + 1.50;
            if(stopLoss == 0)
              {
               Print("Failed to set SL");
               return;
              }
            double lotSize = 0.01;

            double slPoints = MathAbs(lastTickPrice - stopLoss);
            double tpPoints = MathAbs(lastTickPrice - takeProfit);
            double RR = tpPoints / slPoints;

            int orderStatus = openSellOrder(takeProfit, stopLoss, lotSize);
            if(orderStatus == 1)
              {
               signalCreated = 0;
               idSequence = 0;
               break;
              }
           }
     }

   if(isBullish && levelPrices[2] > levelPrices[1])
     {
      signalCreated = 0;
      idSequence = 0;
      Print("Signal invalidated, resetting...");
     }
   else
      if(!isBullish && levelPrices[1] > levelPrices[2])
        {
         signalCreated = 0;
         idSequence = 0;
         Print("Signal invalidated, resetting...");
        }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateSL(bool isBullish)
  {
// Calculate the number of candlesticks between levels
   int lowerIndex = iBarShift(Symbol(), period, levelTimes[1], true);
   int upperIndex = iBarShift(Symbol(), period, TimeCurrent(), true);

   if(lowerIndex == -1 || upperIndex == -1 || upperIndex > lowerIndex)
     {
      Print("Invalid indices. Ensure levelTimes are correctly defined.");
      return 0;
     }

   Print(lowerIndex);
   Print(upperIndex);

   double lowestPrice = 0;
   double highestPrice = 0;
   for(int i = upperIndex; i <= lowerIndex; i++)
     {
      double openPrice = iOpen(Symbol(), PERIOD_CURRENT, i);
      double closePrice = iClose(Symbol(), PERIOD_CURRENT, i);

      Print(openPrice);
      Print(closePrice);

      if(isBullish)
        {
         if(lowestPrice == 0)
            lowestPrice = openPrice;

         if(openPrice < lowestPrice)
            lowestPrice = openPrice;
        }
      else
         if(!isBullish)
           {
            if(highestPrice == 0)
               highestPrice = closePrice;

            if(closePrice > highestPrice)
               highestPrice = closePrice;
           }
     }

   Print(lowestPrice);
   Print(highestPrice);

   if(isBullish)
      return lowestPrice;
   else
      if(!isBullish)
         return highestPrice;
      else
         return 0;
  }
//+------------------------------------------------------------------+
