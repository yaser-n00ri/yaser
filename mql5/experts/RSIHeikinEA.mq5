#property copyright "YourName"
#property version   "1.00"
#property description "RSI entries with Heikin Ashi filter, ATR/fixed SLTP, trailing, BE"
#property strict

#include <Trade/Trade.mqh>

CTrade Trade;

//==================== Inputs ====================//
input string    InpSymbol              = "";             // Symbol (empty=current)
input ENUM_TIMEFRAMES InpTF            = PERIOD_CURRENT; // Timeframe

// RSI
input int       InpRSIPeriod           = 14;             // RSI period
input int       InpRSIOverbought       = 70;             // RSI overbought
input int       InpRSIOversold         = 30;             // RSI oversold

// Heikin-Ashi trend filter
input int       InpHAConfirmBars       = 1;              // Required consecutive HA bars (1-3)

// Risk and SL/TP
enum SLTPMode { SLTP_Fixed=0, SLTP_ATR=1 };
input SLTPMode  InpSLTPMode            = SLTP_ATR;       // SL/TP calculation mode
input double    InpRiskPerTradePct     = 1.0;            // Risk per trade (%)
input double    InpFixedSLPoints       = 100.0;          // Fixed SL (points)
input double    InpFixedTPPoints       = 200.0;          // Fixed TP (points)

// ATR
input int       InpATRPeriod           = 14;             // ATR period
input double    InpATR_SL_Mult         = 2.0;            // ATR multiple for SL
input double    InpATR_TP_Mult         = 4.0;            // ATR multiple for TP

// Trailing / Breakeven
input bool      InpEnableTrailing      = true;           // Enable trailing stop
input double    InpTrailStartPoints    = 200.0;          // Start trailing after profit (points)
input double    InpTrailStepPoints     = 50.0;           // Trail step (points)
input bool      InpEnableBreakEven     = true;           // Move SL to BE
input double    InpBreakEvenTriggerPts = 150.0;          // BE trigger (points)
input double    InpBreakEvenOffsetPts  = 10.0;           // BE offset (points)

// Filters
input int       InpMaxSpreadPoints     = 30;             // Max spread (points)
input bool      InpOneTradePerBar      = true;           // Only one trade per bar
input bool      InpLimitTradingHours   = false;          // Limit trading hours
input int       InpSessionStartHour    = 8;              // Start hour (server)
input int       InpSessionEndHour      = 22;             // End hour (server)

//==================== Handles ====================//
int rsiHandle = -1;
int atrHandle = -1;

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
   return (hour >= InpSessionStartHour || hour < InpSessionEndHour);
}

bool SpreadOk(const string sym)
{
   MqlTick tick;
   if(!SymbolInfoTick(sym, tick)) return false;
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

//==================== Indicators / Data ====================//
bool GetRSI(int count, double &rsiCurr, double &rsiPrev)
{
   rsiCurr = 0.0; rsiPrev = 0.0;
   double buf[2];
   if(CopyBuffer(rsiHandle, 0, 0, 2, buf) < 2) return false;
   rsiCurr = buf[0];
   rsiPrev = buf[1];
   return (rsiCurr!=EMPTY_VALUE && rsiPrev!=EMPTY_VALUE);
}

bool GetATR(double &atr)
{
   double buf[];
   if(CopyBuffer(atrHandle, 0, 0, 1, buf) <= 0) return false;
   atr = buf[0];
   return (atr!=EMPTY_VALUE && atr>0.0);
}

bool ComputeHeikinFilter(int confirmBars, bool &bullish, bool &bearish)
{
   bullish=false; bearish=false;
   string sym=ActiveSymbol();
   ENUM_TIMEFRAMES tf=ActiveTF();

   int need = MathMax(confirmBars + 10, 50);
   MqlRates rates[];
   int copied = CopyRates(sym, tf, 0, need, rates);
   if(copied <= confirmBars) return false;

   // Compute HA series forward (oldest -> newest)
   double haOpen[], haClose[];
   ArrayResize(haOpen, copied);
   ArrayResize(haClose, copied);

   haClose[0] = (rates[0].open + rates[0].high + rates[0].low + rates[0].close) / 4.0;
   haOpen[0]  = (rates[0].open + rates[0].close) / 2.0;

   for(int i=1;i<copied;i++)
   {
      double o=rates[i].open, h=rates[i].high, l=rates[i].low, c=rates[i].close;
      haClose[i] = (o+h+l+c)/4.0;
      haOpen[i]  = (haOpen[i-1] + haClose[i-1]) / 2.0;
   }

   int last = copied-1;
   bool allBull=true, allBear=true;
   for(int k=0;k<confirmBars;k++)
   {
      int idx = last - k;
      if(haClose[idx] <= haOpen[idx]) allBull=false;
      if(haClose[idx] >= haOpen[idx]) allBear=false;
   }
   bullish = allBull;
   bearish = allBear;
   return true;
}

//==================== Risk & Orders ====================//

double CalculateRiskLot(const string sym, double slPoints)
{
   if(slPoints <= 0.0) return 0.0;
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double slPriceDist = slPoints * pt;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPerTradePct / 100.0;

   double lots = riskMoney / ((slPriceDist / tickSize) * tickValue);

   double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

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
      if(GetATR(atr))
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
      result = Trade.Buy(lots, sym, tick.ask, slPrice, tpPrice, "RSIHeikinEA BUY");
   else
      result = Trade.Sell(lots, sym, tick.bid, slPrice, tpPrice, "RSIHeikinEA SELL");
   return result;
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
               Trade.PositionModify(ticket, bePrice, PositionGetDouble(POSITION_TP));
         }
         else if(type==POSITION_TYPE_SELL)
         {
            double profitPts = (priceOpen - ask)/pt;
            double bePrice = priceOpen - InpBreakEvenOffsetPts*pt;
            if(profitPts >= InpBreakEvenTriggerPts && (sl==0.0 || sl > bePrice))
               Trade.PositionModify(ticket, bePrice, PositionGetDouble(POSITION_TP));
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

//==================== Signals ====================//

bool EntrySignals(bool &buySignal, bool &sellSignal)
{
   buySignal=false; sellSignal=false;

   double rsiCurr=0.0, rsiPrev=0.0;
   if(!GetRSI(2, rsiCurr, rsiPrev)) return false;

   bool haBull=false, haBear=false;
   if(!ComputeHeikinFilter(MathMax(1, InpHAConfirmBars), haBull, haBear)) return false;

   bool rsiBuyCross  = (rsiPrev <= InpRSIOversold) && (rsiCurr > InpRSIOversold);
   bool rsiSellCross = (rsiPrev >= InpRSIOverbought) && (rsiCurr < InpRSIOverbought);

   buySignal  = rsiBuyCross  && haBull;
   sellSignal = rsiSellCross && haBear;
   return true;
}

//==================== EA Events ====================//

int OnInit()
{
   string sym = ActiveSymbol();
   ENUM_TIMEFRAMES tf = ActiveTF();

   rsiHandle = iRSI(sym, tf, InpRSIPeriod, PRICE_CLOSE);
   atrHandle = iATR(sym, tf, InpATRPeriod);

   if(rsiHandle==INVALID_HANDLE || atrHandle==INVALID_HANDLE)
   {
      Print("Indicator handle creation failed");
      return INIT_FAILED;
   }

   lastBarTime = iTime(sym, tf, 0);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(rsiHandle!=-1) IndicatorRelease(rsiHandle);
   if(atrHandle!=-1) IndicatorRelease(atrHandle);
}

void OnTick()
{
   ManageTrailingAndBE();

   bool buy=false, sell=false;
   if(!EntrySignals(buy, sell)) return;

   if(!OneTradeThisBarAllowed()) return;

   string sym=ActiveSymbol();
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL)==sym) return;
   }

   if(buy)  OpenPosition(POSITION_TYPE_BUY);
   if(sell) OpenPosition(POSITION_TYPE_SELL);
}
