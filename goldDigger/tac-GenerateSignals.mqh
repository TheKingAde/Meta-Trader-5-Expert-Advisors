//+------------------------------------------------------------------+
//|                                              tac-GenerateSignals.mqh |
//|                                             Copyright 2024, TAC. |
//|                                              https://www.tac.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, TAC."
#property link      "https://www.tac.com"

//+------------------------------------------------------------------+
//| Function to check the current trading session                                                                  |
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
//| Function to check for elliot waves                        |
//+------------------------------------------------------------------+
bool CheckElliotWave()
  {
// Check if levelPrices[2] is between prevFibLevels[1] and prevFibLevels[4]
   bool isWithinFibLevels = (levelPrices[2] >= MathMin(prevFibLevels[5], prevFibLevels[1]) &&
                             levelPrices[2] <= MathMax(prevFibLevels[5], prevFibLevels[1]));

// Check if the distance between levelPrices[1] and levelPrices[2] is greater than the distance between levelPrices[3] and levelPrices[4]
   bool isDistanceGreater = MathAbs(levelPrices[1] - levelPrices[2]) >= MathAbs(levelPrices[3] - levelPrices[4]);

// Return true if both conditions are met
   return true;
  }


//+------------------------------------------------------------------+
//| Function to check if the market is ranging                        |
//+------------------------------------------------------------------+
int isWithinRange(int type)
  {
//   double resDifference = MathAbs(levelPrices[1] - levelPrices[3]);
//   double supDifference = MathAbs(levelPrices[2] - levelPrices[4]);
//
//   if(resDifference <= 0.30 && supDifference <= 0.30)
//     {
//      return 1;  // Market ist ranging within 0.60 range
//     }
//   return 0;  // Market is not ranging
//

   double topRange;
   double bottomRange;

   if(type == 1)
     {
      bottomRange = levelPrices[4] - 1.50;
      topRange = levelPrices[3] + 1.50;

      if(levelPrices[2] <= levelPrices[4] && levelPrices[2] >= bottomRange && levelPrices[1] >= levelPrices[3] && levelPrices[1] <= topRange)
        {
         return 1;
        }
      else
         return 0;
     }
   else
      if(type == -1)
        {
         topRange = levelPrices[4] + 1.50;
         bottomRange = levelPrices[3] - 1.50;

         if(levelPrices[2] >= levelPrices[4] && levelPrices[2] <= topRange && levelPrices[1] <= levelPrices[3] && levelPrices[1] >= bottomRange)
           {
            return 1;
           }
         else
            return 0;
        }

   return 0;  // Market is not ranging

  }


//+------------------------------------------------------------------+
//|  Function checks if any position has been opened                                                                |
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
//| Function to check for Buy signal                                 |
//+------------------------------------------------------------------+
int openBuyOrder(double takeProfit, double stopLoss, double lotSize)
  {
  buySignalCount++; // Increment the buy signal count
  
// Open the buy trade
   ulong buyTicket = trade.Buy(lotSize, Symbol(), 0, stopLoss, takeProfit, "Buy Signal");
   if(buyTicket > 0)
     {
      buyTradeCount++;
      breakEvenPoints = MathAbs(last_tick.ask - takeProfit) / 2;
     }
   else
     {
      Print("Failed to open buy trade. Error code: ", trade.ResultRetcode());
      return 0;
     }
     
     return 1;
  }



//+------------------------------------------------------------------+
//| Function to check for Sell signal                                |
//+------------------------------------------------------------------+
int openSellOrder(double takeProfit, double stopLoss, double lotSize)
  {
  sellSignalCount++; // Increment the sell signal count
  
// Open the sell trade
   ulong sellTicket = trade.Sell(lotSize, Symbol(), 0, stopLoss, takeProfit, "Sell Signal");
   if(sellTicket > 0)
     {
      sellTradeCount++;
      breakEvenPoints = MathAbs(last_tick.ask - takeProfit) / 2;
     }
   else
     {
      Print("Failed to open sell trade. Error code: ", trade.ResultRetcode());
      return 0;
     }
     
     return 1;
  }

//+------------------------------------------------------------------+
//| Function to break even                                 |
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
                     double newStopLoss = entryPrice + 0.10;
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
                        double newStopLoss = entryPrice - 0.10;
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
//| Function to break even                                 |
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
            else
               if(position.PositionType() == POSITION_TYPE_SELL)
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
//+------------------------------------------------------------------+
