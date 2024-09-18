//+------------------------------------------------------------------+
//|                                                   goldDigger.mq5 |
//|                                      Copyright 2021, KingAde, TAC|
//+------------------------------------------------------------------+
#property copyright "2024, TAC"
#property link      "#"
#property version   "1.00"
#property strict

#include "tacEA-ID-lvl.mqh"
#include "tac-utilityFunctions.mqh"
#include <Trade\Trade.mqh>

// Global variables to count buy and sell signals
int buySignalCount = 0;
int sellSignalCount = 0;

// Global variable to count buy and sell trades
int buyTradeCount = 0;
int sellTradeCount = 0;

// Variable to store break-even price
double breakEvenPoints = 0;

// Variable to track if a signal has been generated and time of creation
int signalCreated = 0;
datetime lastSignalTime = 0;

// Array to store candle stick data
double sma4H[];
double sma1M[];

// Simple moving average handle
int sma_handle4H = 0;
int sma_handle1M = 0;

// Variable to store current sma value
double currentH4SMA = 0;
double current1MSMA = 0;

// Global lotsize variable
input double lotsize = 0.01;

// Input parameters
input int SMA_Period = 14; // Period for SMA
ENUM_TIMEFRAMES period = _Period;

// library for handling trades
CTrade trade;

// Get chart data
MqlTick last_tick;

//+------------------------------------------------------------------+
//| Expert Oninit function                                           |
//+------------------------------------------------------------------+
void OnInit()
  {
   Print("initializing goldDigger.ex5...");
   IdentifyLevels();  // identify support and resistance levels
   EventSetTimer(15); // Set timer to call OnTimer every 15 seconds
  }

//+------------------------------------------------------------------+
//| Expert OnTimer function                                          |
//+------------------------------------------------------------------+
void OnTimer()
  {
   IdentifyLevels();
   CalculateFibonacciRetracement(levelPrices[2], levelPrices[1], currFibLevels);
  }

//+------------------------------------------------------------------+
//| Expert OnDeinit function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();

   int totalSTE = buyTradeCount + sellTradeCount;
   int totalSG = buySignalCount + sellSignalCount;
// Counters for winning and losing trades
   int winningTrades = 0;
   int losingTrades = 0;
   ulong ticket = 0;
   double profit = 0;

// Print the total number of buy and sell signals generated
   Print("Total signals generated: ", totalSG);
   Print("Total Buy signals generated: ", buySignalCount);
   Print("Total Sell signals generated: ", sellSignalCount);
// Print the total number of successfully opened buy and sell trades
   Print("Total Successful Trade Execution: ", totalSTE);
   Print("Total Buy Successful Trade Execution: ", buyTradeCount);
   Print("Total Sell Successful Trade Execution: ", sellTradeCount);


// Select the history of deals within the range from the start of the strategy to the current time
   if(!HistorySelect(0, TimeCurrent()))
     {
      Print("Error in HistorySelect: ", GetLastError());
      return;
     }

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
   checkForBreakEven();
   
// Check if it's the right trading session
   if(!IsTradingSession(1))
      return;
// Check if 1hr have passed since the last signal
   if(TimeCurrent() - lastSignalTime > 3600)
     {
      signalCreated = 0;
     }
// Get the current tick data
   if(!SymbolInfoTick(Symbol(), last_tick))
     {
      Print("Error in SymbolInfoTick. Error code = ", GetLastError());
      return;
     }

// Simple moving averages
   sma_handle1M = iMA(Symbol(), PERIOD_M1, SMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   if(CopyBuffer(sma_handle1M, 0, 0, 1, sma1M) <= 0)
     {
      Print("Erroe getting 1Min SMA data. Error code = ", GetLastError());
     }
   sma_handle4H = iMA(Symbol(), PERIOD_H4, SMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   if(CopyBuffer(sma_handle4H, 0, 0, 1, sma4H) <= 0)
     {
      Print("Error getting H4 SMA data. Error code = ", GetLastError());
      return;
     }
   currentH4SMA = sma4H[0];
   current1MSMA = sma1M[0];

   if(signalCreated == 0) // Check if no signal has been created
     {
      // Identify patterns and set signalCreated flag accordingly
      if((levelPrices[1] > levelPrices[2]
          && levelPrices[1] >= levelPrices[3]
          && levelPrices[1] > levelPrices[4]
          && levelPrices[3] > levelPrices[4]
          && levelPrices[3] > levelPrices[2]
          && levelPrices[4] >= levelPrices[2]))
        {
         if(last_tick.ask <= levelPrices[2] && last_tick.ask < currentH4SMA)
           {
            signalCreated = -1; // Sell signal created
            sellSignalCount++;
            lastSignalTime = TimeCurrent();
           }
        }
      else
         if((levelPrices[2] > levelPrices[1]
             && levelPrices[2] >= levelPrices[4]
             && levelPrices[2] > levelPrices[3]
             && levelPrices[3] >= levelPrices[1]
             && levelPrices[4] > levelPrices[3]
             && levelPrices[4] > levelPrices[1]))
           {
            if(last_tick.bid >= levelPrices[2] && last_tick.bid > currentH4SMA)
              {
               signalCreated = 1; // Buy signal created
               buySignalCount++;
               lastSignalTime = TimeCurrent();
              }
           }
     }

   if(signalCreated == 1)
     {
      if(levelPrices[1] > levelPrices[2]) // First retracement after signal has been generated
         MonitorPriceAndOpenPosition(last_tick.bid, true);
     }
   else
      if(signalCreated == -1)
        {
         if(levelPrices[2] > levelPrices[1]) // First retracement after signal has been generated
            MonitorPriceAndOpenPosition(last_tick.ask, false);
        }
  }

//+------------------------------------------------------------------+
// Function to monitor price and open a position                     |
//+------------------------------------------------------------------+
void MonitorPriceAndOpenPosition(double lastTickPrice, bool isBullish)
  {
   if(isBullish)
     {
      if(lastTickPrice <= currFibLevels[2]) // Wait for price to get to the 61.8 retracement level
        {
         double stopLoss = calculateSL(lastTickPrice, true);
         double slPoints = MathAbs(lastTickPrice - stopLoss);
         double tpPoints = slPoints * 4;
         double takeProfit = lastTickPrice + tpPoints;
         
         int orderStatus = 0;
         orderStatus = openBuyOrder(takeProfit, stopLoss, lotsize);
         if(orderStatus == 1)
           {
            signalCreated = 0;
           }
         else
           {
            Print("Failed to open Buy order, resetting signal");
            signalCreated = 0;
           }
        }
     }
   else
      if(!isBullish)
        {
         if(lastTickPrice >= currFibLevels[2]) // Wait for price to get to the 61.8 retracement level
           {
            double stopLoss = calculateSL(lastTickPrice, false);
            double slPoints = MathAbs(lastTickPrice - stopLoss);
            double tpPoints = slPoints * 4;
            double takeProfit = lastTickPrice - tpPoints;
            int orderStatus = 0;

            orderStatus = openSellOrder(takeProfit, stopLoss, lotsize);
            if(orderStatus == 1)
              {
               signalCreated = 0;
              }
            else
              {
               Print("Failed to open Sell order, resetting signal");
               signalCreated = 0;
              }
           }
        }
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
