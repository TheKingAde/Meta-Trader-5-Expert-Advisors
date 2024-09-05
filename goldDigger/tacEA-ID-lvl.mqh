//+------------------------------------------------------------------+
//|                                                       tacEA-ID-lvl.mqh |
//|                                  Copyright 2024, TAC. |
//|                                             https://www.tac.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, TAC."
#property link      "https://www.tac.com"

#include <ChartObjects/ChartObjectsTxtControls.mqh>

// Calculate Fibonacci levels
double currFibLevels[7]; // Declare array to store the current Fibonacci levels
double prevFibLevels[7]; // Declare array to store the previous Fibonacci levels

// Global variables to store level data
double levelPrices[5];
datetime levelTimes[5];

//Variable to count levles
int countLevels = 0;

// Get chart data for zig zag indicator
MqlRates chartData[];
double zigzagData[];
int copiedData = 0;
int zigzagHandle;


//+------------------------------------------------------------------+
//| Function to remove previous levels                                 |
//+------------------------------------------------------------------+
void removePreviousLevels()
  {
   long chart_ID = ChartID();

   for(int j = ObjectsTotal(chart_ID) - 1; j >= 0; j--)
     {
      string name = ObjectName(chart_ID, j);
      if(StringFind(name, "Level") == 0)
        {
         ObjectDelete(chart_ID, name);
        }
     }
  }

//+------------------------------------------------------------------+
//| Function to plot lines on the chart                                  |
//+------------------------------------------------------------------+
void PlotLines()
  {
   removePreviousLevels();
   long chart_ID = ChartID();

   for(int k = 3; k < countLevels; k++)
     {
      string lineName = "Level_" + IntegerToString(k);
      ObjectCreate(chart_ID, lineName, OBJ_HLINE, 0, levelTimes[k], levelPrices[k]);
      ObjectSetInteger(chart_ID, lineName, OBJPROP_COLOR, clrYellow);
     }
  }

//+------------------------------------------------------------------+
//| Main function to identify levels                                   |
//+------------------------------------------------------------------+
void IdentifyLevels()
  {
   datetime fromTime = TimeLocal() - 2 * 24 * 60 * 60; // Subtract 2 days in seconds from the current time
   datetime toTime = TimeLocal(); // Current local time

// Retrieve data
   copiedData = CopyRates(NULL, PERIOD_M1, fromTime, toTime, chartData);
   if(copiedData <= 0)
     {
      Print("Failed to retrieve data");
      return;
     }
   ArraySetAsSeries(chartData, true);

// Create ZigZag indicator handle
   int zigzagDepth = 12;
   int zigzagDeviation = 7;
   int zigzagBackstep = 5;
   zigzagHandle = iCustom(NULL, 0, "Examples/ZigZag", zigzagDepth, zigzagDeviation, zigzagBackstep);
   if(zigzagHandle == INVALID_HANDLE)
     {
      Print("Failed to apply ZigZag");
      return;
     }

// Retrieve ZigZag data
   int copiedZigzagData = CopyBuffer(zigzagHandle, 0, 0, copiedData, zigzagData);
   if(copiedZigzagData <= 0)
     {
      Print("Failed to copy ZigZag buffer");
      return;
     }
   ArraySetAsSeries(zigzagData, true);

// Find most recent peaks
   countLevels = 0;
   for(int i = 0; i < copiedData && countLevels <= 4; i++)
     {
      if(zigzagData[i] > 0)
        {
         levelPrices[countLevels] = zigzagData[i];
         levelTimes[countLevels] = chartData[i].time;
         countLevels++;
        }
     }

// Plot initial levels
   PlotLines();
  }

//+------------------------------------------------------------------+
//| Function to calculate Fibonacci retracement levels               |
//+------------------------------------------------------------------+
void CalculateFibonacciRetracement(double price1, double price2, double &levels[])
  {
   if(price1 < price2)
     {
      // Uptrend: Calculate levels from price1 (low) to price2 (high)
      levels[0] = price1;                                  // 0%
      levels[1] = price1 + 0.236 * (price2 - price1);       // 23.6%
      levels[2] = price1 + 0.382 * (price2 - price1);       // 38.2%
      levels[3] = price1 + 0.5 * (price2 - price1);         // 50%
      levels[4] = price1 + 0.618 * (price2 - price1);       // 61.8%
      levels[5] = price1 + 0.764 * (price2 - price1);       // 76.4%
      levels[6] = price2;                                   // 100%
     }
   else
      if(price1 > price2)
        {
         // Downtrend: Calculate levels from price1 (high) to price2 (low)
         levels[0] = price1;                                  // 0%
         levels[1] = price1 - 0.236 * (price1 - price2);       // 23.6%
         levels[2] = price1 - 0.382 * (price1 - price2);       // 38.2%
         levels[3] = price1 - 0.5 * (price1 - price2);         // 50%
         levels[4] = price1 - 0.618 * (price1 - price2);       // 61.8%
         levels[5] = price1 - 0.764 * (price1 - price2);       // 76.4%
         levels[6] = price2;                                   // 100%
        }
  }

//+------------------------------------------------------------------+
//| Function to draw Fibonacci retracement levels on the chart       |
//+------------------------------------------------------------------+
void DrawCurrFibonacciRetracement(double price1, double price2, double &fibLevels[])
  {
// Remove the previous Fibonacci retracement object if it exists
   ObjectDelete(0, "CurrFiboRetracement");

// Create the Fibonacci retracement object
   if(!ObjectCreate(0, "CurrFiboRetracement", OBJ_FIBO, 0, TimeCurrent(), price1, TimeCurrent(), price2))
     {
      Print("Error creating Fibonacci retracement: ", GetLastError());
      return;
     }

// Set the levels (e.g., 23.6%, 38.2%, 50%, 61.8%, 100%)
   ObjectSetDouble(0, "CurrFiboRetracement", OBJPROP_LEVELVALUE, 0, 0.0);     // 0%
   ObjectSetDouble(0, "CurrFiboRetracement", OBJPROP_LEVELVALUE, 1, 0.236);   // 23.6%
   ObjectSetDouble(0, "CurrFiboRetracement", OBJPROP_LEVELVALUE, 2, 0.382);   // 38.2%
   ObjectSetDouble(0, "CurrFiboRetracement", OBJPROP_LEVELVALUE, 3, 0.5);     // 50%
   ObjectSetDouble(0, "CurrFiboRetracement", OBJPROP_LEVELVALUE, 4, 0.618);   // 61.8%
   ObjectSetDouble(0, "CurrFiboRetracement", OBJPROP_LEVELVALUE, 5, 1.0);     // 100%

// Set the level colors (optional)
   ObjectSetInteger(0, "CurrFiboRetracement", OBJPROP_COLOR, clrRed);

// Set properties for the Fibonacci retracement object
   ObjectSetInteger(0, "CurrFiboRetracement", OBJPROP_WIDTH, 2);       // Set line width
   ObjectSetInteger(0, "CurrFiboRetracement", OBJPROP_STYLE, STYLE_SOLID); // Set line style

//Create and set horizontal lines for each Fibonacci level
//   for(int i = 0; i < 7; i++)  // Updated to loop 7 times for 7 levels
//     {
//      string lineName = "CurrFiboLevel_" + IntegerToString(i);
//      ObjectDelete(0, lineName); // Delete any existing lines with the same name
//
//      if(!ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, fibLevels[i]))
//        {
//         Print("Error creating horizontal line for level ", i, ": ", GetLastError());
//         return;
//        }
//
//      //Set properties for the horizontal lines
//      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrYellow);  // Set line color
//      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);       // Set line width
//     }

// Redraw the chart to show the updated Fibonacci levels
   ChartRedraw();
  }


//+------------------------------------------------------------------+
//| Function to draw Fibonacci retracement levels on the chart       |
//+------------------------------------------------------------------+
void DrawPrevFibonacciRetracement(double price1, double price2, double &fibLevels[])
  {
// Remove the previous Fibonacci retracement object if it exists
   ObjectDelete(0, "PrevFiboRetracement");

// Create the Fibonacci retracement object
   if(!ObjectCreate(0, "FiboRetracement", OBJ_FIBO, 0, TimeCurrent(), price1, TimeCurrent(), price2))
     {
      Print("Error creating Fibonacci retracement: ", GetLastError());
      return;
     }

// Set the levels (e.g., 23.6%, 38.2%, 50%, 61.8%, 100%)
   ObjectSetDouble(0, "PrevFiboRetracement", OBJPROP_LEVELVALUE, 0, 0.0);     // 0%
   ObjectSetDouble(0, "PrevFiboRetracement", OBJPROP_LEVELVALUE, 1, 0.236);   // 23.6%
   ObjectSetDouble(0, "PrevFiboRetracement", OBJPROP_LEVELVALUE, 2, 0.382);   // 38.2%
   ObjectSetDouble(0, "PrevFiboRetracement", OBJPROP_LEVELVALUE, 3, 0.5);     // 50%
   ObjectSetDouble(0, "PrevFiboRetracement", OBJPROP_LEVELVALUE, 4, 0.618);   // 61.8%
   ObjectSetDouble(0, "PrevFiboRetracement", OBJPROP_LEVELVALUE, 5, 1.0);     // 100%

// Set the level colors (optional)
   ObjectSetInteger(0, "PrevFiboRetracement", OBJPROP_COLOR, clrRed);

// Set properties for the Fibonacci retracement object
   ObjectSetInteger(0, "PrevFiboRetracement", OBJPROP_WIDTH, 2);       // Set line width
   ObjectSetInteger(0, "PrevFiboRetracement", OBJPROP_STYLE, STYLE_SOLID); // Set line style

// Create and set horizontal lines for each Fibonacci level
   for(int i = 0; i < 7; i++)  // Updated to loop 7 times for 7 levels
     {
      string lineName = "PrevFiboLevel_" + IntegerToString(i);
      ObjectDelete(0, lineName); // Delete any existing lines with the same name

      if(!ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, fibLevels[i]))
        {
         Print("Error creating horizontal line for level ", i, ": ", GetLastError());
         return;
        }

      // Set properties for the horizontal lines
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrYellow);  // Set line color
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);       // Set line width
     }

// Redraw the chart to show the updated Fibonacci levels
   ChartRedraw();
  }


//+------------------------------------------------------------------+
