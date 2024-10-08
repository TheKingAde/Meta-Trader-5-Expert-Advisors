//+------------------------------------------------------------------+
//|                                         tac-utilityFunctions.mqh |
//|                                             Copyright 2024, TAC. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, KingAde, TAC."

//+------------------------------------------------------------------+
//| Function to check the current trading session                    |
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
   bool isLondonSession = (hour > 8 || (hour == 8 && minute >= 0)) && (hour < 17 || (hour == 17 && minute == 0));

// New York session: 1:00 PM - 10:00 PM
   bool isNYSession = (hour > 13 || (hour == 13 && minute >= 0)) && (hour < 22 || (hour == 22 && minute == 0));

   bool isLateNySession = (hour > 21 || (hour == 21 && minute >= 0)) && (hour < 23 || (hour == 23 && minute == 40));

// Trading is allowed only during the Asian session
   if(type == 1)
     {
      if(isNYSession || isAsianSession || isLateNySession || isLondonSession)
        {
         return true;
        }
     }
   else
      if(type == 2)
        {
         if(isLondonSession || isNYSession)
           {
            return true;
           }
        }

   return false; // Outside the Asian session
  }

//+------------------------------------------------------------------+
//|  Function checks if any position is opened                       |
//+------------------------------------------------------------------+
bool hasOpenOrder(string symbol)
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(PositionGetSymbol(i) == symbol)
        {
         return true; // Found an open position for the current symbol
        }
     }
   return false; // No open positions for the current symbol
  }

//+------------------------------------------------------------------+
//| Function to open buy order                                       |
//+------------------------------------------------------------------+
int openBuyOrder(double takeProfit, double stopLoss, double lotSize)
  {
// Open the buy trade
   ulong buyTicket = trade.Buy(lotSize, Symbol(), 0, stopLoss, takeProfit, "Buy Signal");
   if(buyTicket > 0)
     {
      buyTradeCount++;
      breakEvenPoints = MathAbs(last_tick.ask - takeProfit) * 0.50;
     }
   else
     {
      Print("Failed to open buy trade. Error code: ", trade.ResultRetcode());
      return 0;
     }

   return 1;
  }

//+------------------------------------------------------------------+
//| Function to open sell order                                      |
//+------------------------------------------------------------------+
int openSellOrder(double takeProfit, double stopLoss, double lotSize)
  {
// Open the sell trade
   ulong sellTicket = trade.Sell(lotSize, Symbol(), 0, stopLoss, takeProfit, "Sell Signal");
   if(sellTicket > 0)
     {
      sellTradeCount++;
      breakEvenPoints = MathAbs(last_tick.ask - takeProfit) * 0.50;
     }
   else
     {
      Print("Failed to open sell trade. Error code: ", trade.ResultRetcode());
      return 0;
     }

   return 1;
  }

//+------------------------------------------------------------------+
//| Function to break even                                           |
//+------------------------------------------------------------------+
void checkForBreakEven()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol == _Symbol)
        {
         ulong ticket = PositionGetTicket(i);
         CPositionInfo position;

         if(position.SelectByTicket(ticket))
           {
            double entryPrice = position.PriceOpen();
            double currentPrice = position.PriceCurrent();
            double stopLoss = position.StopLoss();
            double takeProfit = position.TakeProfit();

            if(position.PositionType() == POSITION_TYPE_BUY)
              {
               if(stopLoss < entryPrice)  // before break-even
                 {
                  if(currentPrice - entryPrice >= breakEvenPoints)
                    {
                     double newStopLoss = entryPrice;
                     if(newStopLoss > stopLoss)
                       {
                        int modifyResult = trade.PositionModify(ticket, newStopLoss, takeProfit);
                        if(modifyResult != 0)
                          {
                           Print("Error modifying position: ", modifyResult);
                          }
                       }
                    }
                 }
              }
            else
               if(position.PositionType() == POSITION_TYPE_SELL)
                 {
                  if(stopLoss > entryPrice)  // before break-even
                    {
                     if(entryPrice - currentPrice >= breakEvenPoints)
                       {
                        double newStopLoss = entryPrice;
                        if(newStopLoss < stopLoss)
                          {
                           int modifyResult = trade.PositionModify(ticket, newStopLoss, takeProfit);
                           if(modifyResult != 0)
                             {
                              Print("Error modifying position: ", modifyResult);
                             }
                          }
                       }
                    }
                 }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Function to break even                                           |
//+------------------------------------------------------------------+
void checkForTrailingSL(double level1, double level2)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol == _Symbol)
        {
         ulong ticket = PositionGetTicket(i);
         CPositionInfo position;

         if(position.SelectByTicket(ticket))
           {
            double entryPrice = position.PriceOpen();
            double currentPrice = position.PriceCurrent();
            double stopLoss = position.StopLoss();
            double takeProfit = position.TakeProfit();

            if(position.PositionType() == POSITION_TYPE_BUY)
              {
               if(entryPrice <= stopLoss)
                 {
                  if(level2 > level1)
                    {
                     double newStopLoss = level1;
                     if(newStopLoss > stopLoss)
                       {
                        int modifyResult = trade.PositionModify(ticket, newStopLoss, takeProfit);
                        if(modifyResult != 0)
                          {
                           Print("Error modifying position: ", modifyResult);
                          }
                       }
                    }
                 }
              }
            else
               if(position.PositionType() == POSITION_TYPE_SELL)
                 {
                  if(entryPrice >= stopLoss)
                    {
                     if(level1 > level2)
                       {
                        double newStopLoss = level1;
                        if(newStopLoss < stopLoss)
                          {
                           int modifyResult = trade.PositionModify(ticket, newStopLoss, takeProfit);
                           if(modifyResult != 0)
                             {
                              Print("Error modifying position: ", modifyResult);
                             }
                          }
                       }
                    }
                 }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|  Function to find peak candle stick price                        |
//+------------------------------------------------------------------+
double findPeak(bool isBullish)
  {
   double lowestPrice = 0;
   double highestPrice = 0;
   double highPrice = 0;
   double lowPrice = 0;
// Calculate the number of candlesticks between levels
   int lowerIndex = iBarShift(Symbol(), period, levelTimes[1], true);
   int upperIndex = iBarShift(Symbol(), period, TimeCurrent(), true);

   if(lowerIndex == -1 || upperIndex == -1 || upperIndex > lowerIndex)
     {
      Print("Invalid indices. Ensure levelTimes are correctly defined.");
      return 0;
     }

   for(int i = upperIndex; i <= lowerIndex; i++)
     {
      highPrice = iHigh(Symbol(), PERIOD_CURRENT, i);
      lowPrice = iLow(Symbol(), PERIOD_CURRENT, i);

      if(isBullish)
        {
         if(lowestPrice == 0)
            lowestPrice = lowPrice;

         if(lowPrice < lowestPrice)
            lowestPrice = lowPrice;
        }
      else
         if(!isBullish)
           {
            if(highestPrice == 0)
               highestPrice = highPrice;

            if(highPrice > highestPrice)
               highestPrice = highPrice;
           }
     }

   if(isBullish)
      return lowestPrice;
   else
      if(!isBullish)
         return highestPrice;
      else
         return 0;
  }

//+------------------------------------------------------------------+
//|  Function to calculate Stop Loss                                 |
//+------------------------------------------------------------------+
double calculateSL(double price, bool isBullish)
  {
   double length = MathAbs(levelPrices[2] - levelPrices[1]);
   double slPercent = 0.25;
   double slPoints = length * slPercent;
   double sl = 0;

   if(isBullish)
      sl = price - slPoints;
   else
      if(!isBullish)
         sl = price + slPoints;

   return sl;
  }
//+------------------------------------------------------------------+
