#property copyright "YourName"
#property version   "1.00"
#property description "Configurable MA/RSI + ATR SL/TP EA"
#property strict

#include <Trade/Trade.mqh>

CTrade Trade;

//==================== Inputs ====================//
input string    InpSymbol              = "";           // Symbol (empty=current)
input ENUM_TIMEFRAMES InpTF            = PERIOD_CURRENT; // Timeframe

// Entry logic selection
enum EntryMode { Entry_MA_Cross=0, Entry_RSI_Breakout=1 };
input EntryMode InpEntryMode           = Entry_MA_Cross; // Entry mode

// MA settings
input ENUM_MA_METHOD InpMaMethod       = MODE_EMA;     // MA method
input int       InpFastMAPeriod        = 20;           // Fast MA period
input int       InpSlowMAPeriod        = 50;           // Slow MA period

// RSI settings
input int       InpRSIPeriod           = 14;           // RSI period
input int       InpRSIOverbought       = 70;           // RSI overbought
input int       InpRSIOversold         = 30;           // RSI oversold

// Risk and SL/TP
enum SLTPMode { SLTP_Fixed=0, SLTP_ATR=1 };
input SLTPMode  InpSLTPMode            = SLTP_ATR;     // SL/TP calculation mode
input double    InpRiskPerTradePct     = 1.0;          // Risk per trade (%)
input double    InpFixedSLPoints       = 100.0;        // Fixed SL (points)
input double    InpFixedTPPoints       = 200.0;        // Fixed TP (points)

// ATR
input int       InpATRPeriod           = 14;           // ATR period
input double    InpATR_SL_Mult         = 2.0;          // ATR multiple for SL
input double    InpATR_TP_Mult         = 4.0;          // ATR multiple for TP

// Trailing / BE
input bool      InpEnableTrailing      = true;         // Enable trailing stop
input double    InpTrailStartPoints    = 200.0;        // Start trailing after profit (points)
input double    InpTrailStepPoints     = 50.0;         // Trail step (points)
input bool      InpEnableBreakEven     = true;         // Move SL to BE
input double    InpBreakEvenTriggerPts = 150.0;        // BE trigger (points)
input double    InpBreakEvenOffsetPts  = 10.0;         // BE offset (points)

// Filters
input int       InpMaxSpreadPoints     = 30;           // Max spread (points)
input bool      InpOneTradePerBar      = true;         // Only one trade per bar
input bool      InpLimitTradingHours   = false;        // Limit trading hours
input int       InpSessionStartHour    = 8;            // Start hour (server)
input int       InpSessionEndHour      = 22;           // End hour (server)

//==================== Handles ====================//
int fastMaHandle = -1;
int slowMaHandle = -1;
int rsiHandle    = -1;
int atrHandle    = -1;

//==================== State ====================//
datetime lastBarTime = 0;

//==================== Helpers ====================//
string ActiveSymbol()
{
   return (InpSymbol==NULL || InpSymbol=="") ? _Symbol : InpSymbol;
}

ENUM_TIMEFRAMES ActiveTF()
{
   return InpTF==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpTF;
}

bool TradingWindowOk()
{
   if(!InpLimitTradingHours) return true;
   datetime now = TimeCurrent();
   int hour = TimeHour(now);
   if(InpSessionStartHour <= InpSessionEndHour)
      return (hour >= InpSessionStartHour && hour < InpSessionEndHour);
   // Overnight window (e.g., 22 -> 6)
   return (hour >= InpSessionStartHour || hour < InpSessionEndHour);
}

bool SpreadOk(const string sym)
{
   MqlTick tick;
   if(!SymbolInfoTick(sym, tick)) return false;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double spreadPts = (tick.ask - tick.bid) / pt;
   return spreadPts <= InpMaxSpreadPoints;
}

bool OneTradeThisBarAllowed()
{
   if(!InpOneTradePerBar) return true;
   datetime ct = iTime(ActiveSymbol(), ActiveTF(), 0);
   if(ct != lastBarTime)
   {
      lastBarTime = ct;
      return true;
   }
   return false;
}

bool GetMA(const string sym, ENUM_TIMEFRAMES tf, int handle, double &value)
{
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) return false;
   value = buf[0];
   return (value != 0.0 && value != EMPTY_VALUE);
}

bool GetRSI(const string sym, ENUM_TIMEFRAMES tf, int handle, double &value)
{
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) return false;
   value = buf[0];
   return (value != 0.0 && value != EMPTY_VALUE);
}

bool GetATR(const string sym, ENUM_TIMEFRAMES tf, int handle, double &value)
{
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) return false;
   value = buf[0];
   return (value != 0.0 && value != EMPTY_VALUE);
}

// Calculate lot size based on risk % and SL distance (points)
double CalculateRiskLot(const string sym, double slPoints)
{
   if(slPoints <= 0.0) return 0.0;
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double slPriceDist = slPoints * pt;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPerTradePct / 100.0;

   // Approximate lots: riskMoney = (slPriceDist / tickSize) * tickValue * lots
   double lots = riskMoney / ((slPriceDist / tickSize) * tickValue);

   // Constrain to symbol min/max step
   double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   // Normalize to step
   lots = MathMax(minLot, MathMin(maxLot, MathFloor(lots/step)*step));
   return lots;
}

void ComputeSLTP(const string sym, ENUM_POSITION_TYPE dir, double &slPrice, double &tpPrice)
{
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);

   double slPts=InpFixedSLPoints, tpPts=InpFixedTPPoints;
   if(InpSLTPMode == SLTP_ATR)
   {
      double atr=0.0;
      if(GetATR(sym, ActiveTF(), atrHandle, atr))
      {
         slPts = InpATR_SL_Mult * (atr/pt);
         tpPts = InpATR_TP_Mult * (atr/pt);
      }
   }

   if(dir==POSITION_TYPE_BUY)
   {
      slPrice = bid - slPts*pt;
      tpPrice = bid + tpPts*pt;
   }
   else
   {
      slPrice = ask + slPts*pt;
      tpPrice = ask - tpPts*pt;
   }
}

bool EntrySignals(bool &buySignal, bool &sellSignal)
{
   buySignal=false; sellSignal=false;
   string sym=ActiveSymbol();
   ENUM_TIMEFRAMES tf=ActiveTF();

   if(InpEntryMode==Entry_MA_Cross)
   {
      double fast=0, slow=0;
      if(!GetMA(sym, tf, fastMaHandle, fast) || !GetMA(sym, tf, slowMaHandle, slow))
         return false;
      // Cross using last two values
      double fastPrevArr[2], slowPrevArr[2];
      if(CopyBuffer(fastMaHandle, 0, 0, 2, fastPrevArr) < 2) return false;
      if(CopyBuffer(slowMaHandle, 0, 0, 2, slowPrevArr) < 2) return false;

      bool crossUp = (fastPrevArr[1] < slowPrevArr[1]) && (fastPrevArr[0] > slowPrevArr[0]);
      bool crossDn = (fastPrevArr[1] > slowPrevArr[1]) && (fastPrevArr[0] < slowPrevArr[0]);
      buySignal = crossUp;
      sellSignal = crossDn;
      return true;
   }
   else // RSI breakout
   {
      double rsi=0.0;
      if(!GetRSI(sym, tf, rsiHandle, rsi)) return false;
      // Use simple breakout thresholds
      buySignal = (rsi > InpRSIOverbought);
      sellSignal = (rsi < InpRSIOversold);
      return true;
   }
}

void ManageTrailingAndBE()
{
   if(!InpEnableTrailing && !InpEnableBreakEven) return;

   string sym=ActiveSymbol();
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);

      if(InpEnableBreakEven)
      {
         if(type==POSITION_TYPE_BUY)
         {
            double profitPts = (bid - priceOpen)/pt;
            double bePrice = priceOpen + InpBreakEvenOffsetPts*pt;
            if(profitPts >= InpBreakEvenTriggerPts && (sl==0.0 || sl < bePrice))
            {
               Trade.PositionModify(ticket, bePrice, PositionGetDouble(POSITION_TP));
            }
         }
         else if(type==POSITION_TYPE_SELL)
         {
            double profitPts = (priceOpen - ask)/pt;
            double bePrice = priceOpen - InpBreakEvenOffsetPts*pt;
            if(profitPts >= InpBreakEvenTriggerPts && (sl==0.0 || sl > bePrice))
            {
               Trade.PositionModify(ticket, bePrice, PositionGetDouble(POSITION_TP));
            }
         }
      }

      if(InpEnableTrailing)
      {
         if(type==POSITION_TYPE_BUY)
         {
            double profitPts = (bid - priceOpen)/pt;
            if(profitPts >= InpTrailStartPoints)
            {
               double newSL = bid - InpTrailStepPoints*pt;
               if(sl==0.0 || newSL > sl)
                  Trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
         }
         else if(type==POSITION_TYPE_SELL)
         {
            double profitPts = (priceOpen - ask)/pt;
            if(profitPts >= InpTrailStartPoints)
            {
               double newSL = ask + InpTrailStepPoints*pt;
               if(sl==0.0 || newSL < sl)
                  Trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}

bool OpenPosition(ENUM_POSITION_TYPE dir)
{
   string sym=ActiveSymbol();
   if(!SpreadOk(sym) || !TradingWindowOk()) return false;

   double slPrice=0.0, tpPrice=0.0;
   ComputeSLTP(sym, dir, slPrice, tpPrice);

   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double slPts = MathAbs((dir==POSITION_TYPE_BUY ? SymbolInfoDouble(sym, SYMBOL_BID) - slPrice : slPrice - SymbolInfoDouble(sym, SYMBOL_ASK)))/pt;
   double lots = CalculateRiskLot(sym, slPts);
   if(lots <= 0.0) return false;

   MqlTick tick; SymbolInfoTick(sym, tick);
   bool result=false;
   if(dir==POSITION_TYPE_BUY)
      result = Trade.Buy(lots, sym, tick.ask, slPrice, tpPrice, "EA_NewStrategy BUY");
   else
      result = Trade.Sell(lots, sym, tick.bid, slPrice, tpPrice, "EA_NewStrategy SELL");
   return result;
}

//==================== EA Events ====================//
int OnInit()
{
   string sym = ActiveSymbol();
   ENUM_TIMEFRAMES tf = ActiveTF();

   fastMaHandle = iMA(sym, tf, InpFastMAPeriod, 0, InpMaMethod, PRICE_CLOSE);
   slowMaHandle = iMA(sym, tf, InpSlowMAPeriod, 0, InpMaMethod, PRICE_CLOSE);
   rsiHandle    = iRSI(sym, tf, InpRSIPeriod, PRICE_CLOSE);
   atrHandle    = iATR(sym, tf, InpATRPeriod);

   if(fastMaHandle==INVALID_HANDLE || slowMaHandle==INVALID_HANDLE || rsiHandle==INVALID_HANDLE || atrHandle==INVALID_HANDLE)
   {
      Print("Indicator handle creation failed");
      return INIT_FAILED;
   }

   lastBarTime = iTime(sym, tf, 0);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(fastMaHandle!=-1) IndicatorRelease(fastMaHandle);
   if(slowMaHandle!=-1) IndicatorRelease(slowMaHandle);
   if(rsiHandle!=-1) IndicatorRelease(rsiHandle);
   if(atrHandle!=-1) IndicatorRelease(atrHandle);
}

void OnTick()
{
   ManageTrailingAndBE();

   // Entry conditions
   bool buy=false, sell=false;
   if(!EntrySignals(buy, sell)) return;

   // One-trade-per-bar filter
   if(!OneTradeThisBarAllowed()) return;

   // Avoid multiple positions: simple filter to allow only one position per symbol and direction
   string sym=ActiveSymbol();
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL)==sym) return;
   }

   if(buy)  OpenPosition(POSITION_TYPE_BUY);
   if(sell) OpenPosition(POSITION_TYPE_SELL);
}
