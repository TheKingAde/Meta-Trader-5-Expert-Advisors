//+------------------------------------------------------------------+
//|                                                      0-tacEA.mq5 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.tac.com  |
//+------------------------------------------------------------------+
#property copyright "2024, TAC"
#property link      "https://www.tac.com"
#property version   "1.00"
#property strict

#include "tacEA-ID-lvl.mqh"
//#include "tacEA-BB.mqh"
#include "tac-GenerateSignals.mqh"
#include <Trade\Trade.mqh>

// Global variables to count buy and sell signals
int buySignalCount = 0;
int sellSignalCount = 0;

// Global variable to count buy and sell trades
int buyTradeCount = 0;
int sellTradeCount = 0;

//Global  variable to prevent opening multiple buy orders
double firstHalfBuy;
double secondHalfBuy;

//Global variable to prevent opening multiple sell orders
double firstHalfSell;
double secondHalfSell;

// Flags to track if a buy or sell signal has been created
bool buySignalCreated = false;
bool sellSignalCreated = false;

CTrade trade;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {
   Print("Identifying levels");
   IdentifyLevels();
   EventSetTimer(70); // Set timer to call OnTimer every 70 seconds
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   IdentifyLevels();
  }

//+------------------------------------------------------------------+
//|                                                                  |
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
   Print("Total Successfull Trade Execution: ", totalSTE);
   Print("Total Buy Successful Trade Execution: ", buyTradeCount);
   Print("Total Sell Successful Trade Execution: ", sellTradeCount);

// Print the total number of failed trade execution
   Print("Total Failed Trade Execution: ", totalFTE);
   Print("Total Buy Failed Trade Execution: ", buyFTE);
   Print("Total Sell Failed Trade Execution: ", sellFTE);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   ENUM_TIMEFRAMES period = _Period;
   float deviation = 2.00;
// Array to store Bollinger Bands levels
//double upper[], middle[], lower[];

// Get chart data
   MqlTick last_tick;
   if(!SymbolInfoTick(Symbol(), last_tick))
     {
      Print("Error in SymbolInfoTick. Error code = ", GetLastError());
      return;
     }

//CalculateBollingerBands(period, deviation, upper, middle, lower);
//PlotBollingerBands(upper[0], middle[0], lower[0]);
   double center = MathAbs(levelPrices[1] - levelPrices[2]);
   double resistance = 0;
   double support = 0;

// Compare the most recent high and low to determine support and resistance
   if(levelPrices[1] > levelPrices[2])
     {
      resistance = levelPrices[1];
      support = levelPrices[2];

      if(last_tick.bid >= resistance && !sellSignalCreated)
        {
         checkForSellSignal(last_tick.bid, center);

        }
      else
         if(last_tick.bid <= support && !buySignalCreated)
           {
            checkForBuySignal(last_tick.bid, center);
           }
     }
   else
      if(levelPrices[2] > levelPrices[1])
        {
         resistance = levelPrices[2];
         support = levelPrices[1];

         if(last_tick.bid >= resistance && !sellSignalCreated)
           {
            checkForSellSignal(last_tick.bid, center);
           }
         else
            if(last_tick.bid <= support && !buySignalCreated)
              {
               checkForBuySignal(last_tick.bid, center);
              }
        }

// Reset buySignalCreated when price crosses the middle band
   if(buySignalCreated && (last_tick.bid > firstHalfBuy || last_tick.bid < secondHalfBuy))
     {
      buySignalCreated = false;
     }

// Reset sellSignalCreated when price crosses the middle band
   if(sellSignalCreated && (last_tick.bid > firstHalfSell || last_tick.bid < secondHalfSell))
     {
      sellSignalCreated = false;
     }

//if(last_tick.bid >= upper[0])
//  {
//   if(levelDifference >= 1.00 && !sellSignalCreated)
//     {
//      checkForSellSignal(last_tick.bid, middle[0]);
//     }
//  }
//else
//   if(last_tick.bid <= lower[0])
//     {
//      if(levelDifference >= 1.00 && !buySignalCreated)
//        {
//         checkForBuySignal(last_tick.bid, middle[0]);
//        }
//     }

   trailingStop();
  }
//+------------------------------------------------------------------+
