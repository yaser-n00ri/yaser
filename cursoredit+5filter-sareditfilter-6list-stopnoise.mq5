//+------------------------------------------------------------------+
//| Modular EA Template - RSICrossHeikinV2 Fixed (v3.8026 + Filters) |
//| HIRADJAM - Aug 2025                                              |
//| - Base: v3.8026 (ATR Trailing intact)                            |
//| - Added filters into A/B/C/D/E/F banks:                          |
//|   ADXTrend, PSARTrend, MACDTrend, StochSignal, VolumeAboveMA     |
//| - Added entry gates: LossLockoutBars, PriceImproveATR            |
//| - NEW: LossLockoutTrades (skip N valid entries after SL)         |
//+------------------------------------------------------------------+
#property copyright "HIRADJAM"
#property version   "3.8026-filters-lockout"
#include <Trade/Trade.mqh>
CTrade trade;

// ===== ENUMS =====
enum StrategyEnum { NONE_STRATEGY = 0, RSICrossHeikinV2, RSI2Cross, HeikinComplete, HeikinSAR };
enum FilterEnum { NONE_FILTER = 0, EMA_Trend, RSI_Cross2RSI, EMACross, HeikinFilter, ATRFilter, ADXTrend, PSARTrend, MACDTrend, StochSignal, VolumeAboveMA };
enum StopLossEnum { NONE_STOP = 0, Fixed_Stop, Trailing_Stop, Custom_Trailing, ATR_Trailing };
enum TakeProfitEnum { NONE_TP = 0, Fixed_TP, Trailing_TP, Custom_Trailing_Profit };
enum SLTypeEnum { SL_PIPS = 0, SL_PERCENT };
enum TPTypeEnum { TP_PIPS = 0, TP_PERCENT };
enum LogicMode { LOGIC_AND = 0, LOGIC_OR };
enum NewBarModeEnum { NBM_TF1 = 0, NBM_TF2, NBM_ANY };

// ===== STRATEGY SELECTION =====
input StrategyEnum SelectedStrategy1 = RSICrossHeikinV2;
input StrategyEnum SelectedStrategy2 = NONE_STRATEGY;
input ENUM_TIMEFRAMES Strategy1Timeframe = PERIOD_M1;
input ENUM_TIMEFRAMES Strategy2Timeframe = PERIOD_M1;
input long Magic_S1 = 1001;
input long Magic_S2 = 1002;

// ===== PER-STRATEGY FILTER BANKS (expanded to A/B/C/D/E/F) =====
input FilterEnum S1_FilterA = RSI_Cross2RSI;
input ENUM_TIMEFRAMES S1_FilterA_TF = PERIOD_M15;
input FilterEnum S1_FilterB = HeikinFilter;
input ENUM_TIMEFRAMES S1_FilterB_TF = PERIOD_H1;
input FilterEnum S1_FilterC = EMA_Trend;
input ENUM_TIMEFRAMES S1_FilterC_TF = PERIOD_D1;
input FilterEnum S1_FilterD = ATRFilter;
input ENUM_TIMEFRAMES S1_FilterD_TF = PERIOD_M1;
input FilterEnum S1_FilterE = NONE_FILTER;
input ENUM_TIMEFRAMES S1_FilterE_TF = PERIOD_H1;
input FilterEnum S1_FilterF = NONE_FILTER;
input ENUM_TIMEFRAMES S1_FilterF_TF = PERIOD_H1;
input LogicMode S1_FilterLogic = LOGIC_AND;

input FilterEnum S2_FilterA = NONE_FILTER;
input ENUM_TIMEFRAMES S2_FilterA_TF = PERIOD_H1;
input FilterEnum S2_FilterB = NONE_FILTER;
input ENUM_TIMEFRAMES S2_FilterB_TF = PERIOD_H1;
input FilterEnum S2_FilterC = NONE_FILTER;
input ENUM_TIMEFRAMES S2_FilterC_TF = PERIOD_H1;
input FilterEnum S2_FilterD = NONE_FILTER;
input ENUM_TIMEFRAMES S2_FilterD_TF = PERIOD_H1;
input FilterEnum S2_FilterE = NONE_FILTER;
input ENUM_TIMEFRAMES S2_FilterE_TF = PERIOD_H1;
input FilterEnum S2_FilterF = NONE_FILTER;
input ENUM_TIMEFRAMES S2_FilterF_TF = PERIOD_H1;
input LogicMode S2_FilterLogic = LOGIC_AND;

// ===== STOP/TP MODULES =====
input StopLossEnum SelectedStopLoss1 = ATR_Trailing;
input SLTypeEnum StopLossType1 = SL_PERCENT;
input double StopLossValue1 = 0.3;
input double TrailingStart1 = 0.4;
input double TrailingStep1 = 0.15;
input bool UseInitialSLForTrailing1 = true;

input StopLossEnum SelectedStopLoss2 = NONE_STOP;
input SLTypeEnum StopLossType2 = SL_PIPS;
input double StopLossValue2 = 200;
input double TrailingStart2 = 50;
input double TrailingStep2 = 10;
input bool UseInitialSLForTrailing2 = true;

input TakeProfitEnum SelectedTakeProfit1 = NONE_TP;
input TPTypeEnum TakeProfitType1 = TP_PIPS;
input double TakeProfitValue1 = 400;
input double TrailingTPStart1 = 50;
input double TrailingTPStep1 = 10;

input TakeProfitEnum SelectedTakeProfit2 = NONE_TP;
input TPTypeEnum TakeProfitType2 = TP_PERCENT;
input double TakeProfitValue2 = 3.5;
input double TrailingTPStart2 = 1.2;
input double TrailingTPStep2 = 0.4;

// NEW: For ATR_Trailing
input double ATR_Start_Multiplier = 18; // Multiplier for start and initial SL
input double ATR_Step_Multiplier = 15; // Multiplier for trailing step

// ===== TRADING WINDOW =====
input int TradingStartHour = 10;
input int TradingStartMin = 0;
input int TradingEndHour = 18;
input int TradingEndMin = 0;
input int CloseAllHour = -1; // <0 = disabled
input int CloseAllMinute = 0;
input bool DisableTradingWindow = true;

// ===== COMMON PARAMS =====
input int RSI_Period = 14;
input double RSI_Low_Threshold = 26;
input double RSI_High_Threshold = 72;
input int Heikin_Num_Bull = 3;
input int Heikin_Num_Bear = 3;
input int Heikin_Num_Bull_Exit = 3;
input int Heikin_Num_Bear_Exit = 3;
input int Heikin_Num_Entry = 3; // for HeikinComplete entry
input int Heikin_Num_Exit = 3; // for HeikinComplete exit
input int EMA_Period = 50; // for EMA_Trend
input double LotSize = 0.01;

// RSI2Cross
input int RSI2_Fast_Period = 5;
input int RSI2_Slow_Period = 25;

// RSI_Cross2RSI filter
input int FilterRSI_Fast_Period = 5;
input int FilterRSI_Slow_Period = 14;

// EMACross filter
input int FilterEMA_Fast_Period = 9;
input int FilterEMA_Slow_Period = 21;

// NEW: ATRFilter params
input int ATR_Period = 130;
input double ATR_Threshold = 0.9; // Default for XAUUSD M1 (~5 pips)

// Bar selection for filters
input bool EMACross_UseClosedBar = true; // true=bar1, false=bar0
input bool RSIx2_UseClosedBar = true; // true=bar1, false=bar0

// NEW: HeikinFilter bar selection
input bool HeikinFilter_UseClosedBar = false; // true=shift1 (closed), false=shift0 (current)

// NEW: RSICrossHeikinV2 bar selection
input bool RHV2_EntryUseClosedBar = true;
input bool RHV2_ExitUseClosedBar = true;

// NEW INPUT for updated logic
input int Max_N_Candles_After_Cross = 10;

// Controls
input bool EnableChartLogs = true;
input NewBarModeEnum NewBarMode = NBM_ANY;
input string HeikenIndicatorName = "Heiken_Ashi";

// NEW: Toggle strategy exits
input bool UseStrategyExits = false;

// HeikinSAR strategy params
input double HeikinSAR_Step = 0.02;
input double HeikinSAR_Max  = 0.2;
input bool   HeikinSAR_UseClosedBar_Entry = true;
input bool   HeikinSAR_UseClosedBar_Exit  = true;

// ===== ENTRY GATES (cooldown and price improvement) =====
input int    LossLockoutBars = -1;   // -1 disable; lockout N bars after SL (per-dir, per S1/S2)
input double PriceImproveATR = -1.0; // -1 disable; require k*ATR price improvement vs last entry (per-dir)
input int    LossLockoutTrades = 0;  // 0 disable; skip N valid entries after SL (per-dir, per S1/S2)

// ===== NEW FILTER INPUTS =====
// ADX
input int ADX_Filter_Period = 14;
input double ADX_Filter_Threshold = 25.0;

// MACD
input int MACD_Fast_Filter = 12;
input int MACD_Slow_Filter = 26;
input int MACD_Signal_Filter = 9;

// Stochastic
input int Stoch_K_Filter = 14;
input int Stoch_D_Filter = 3;
input int Stoch_Slowing_Filter = 3;
input double Stoch_LowLevel = 20.0;
input double Stoch_HighLevel = 80.0;

// PSAR
input double PSAR_Step_Filter = 0.02;
input double PSAR_Max_Filter = 0.2;

// Volume MA
input int VolMA_Period = 20;
input double Vol_Multiplier = 1.3;

// ===== HANDLES =====
int rsi_handle1 = INVALID_HANDLE, rsi_handle2 = INVALID_HANDLE;
int ha_handle1 = INVALID_HANDLE, ha_handle2 = INVALID_HANDLE;
int rsi_fast1 = INVALID_HANDLE, rsi_slow1 = INVALID_HANDLE;
int rsi_fast2 = INVALID_HANDLE, rsi_slow2 = INVALID_HANDLE;

// S1-A/B/C/D/E/F
int s1a_ema_trend = INVALID_HANDLE, s1b_ema_trend = INVALID_HANDLE, s1c_ema_trend = INVALID_HANDLE, s1d_ema_trend = INVALID_HANDLE, s1e_ema_trend = INVALID_HANDLE, s1f_ema_trend = INVALID_HANDLE;
int s1a_rsi_fast = INVALID_HANDLE, s1a_rsi_slow = INVALID_HANDLE, s1b_rsi_fast = INVALID_HANDLE, s1b_rsi_slow = INVALID_HANDLE, s1c_rsi_fast = INVALID_HANDLE, s1c_rsi_slow = INVALID_HANDLE, s1d_rsi_fast = INVALID_HANDLE, s1d_rsi_slow = INVALID_HANDLE, s1e_rsi_fast = INVALID_HANDLE, s1e_rsi_slow = INVALID_HANDLE, s1f_rsi_fast = INVALID_HANDLE, s1f_rsi_slow = INVALID_HANDLE;
int s1a_ema_fast = INVALID_HANDLE, s1a_ema_slow = INVALID_HANDLE, s1b_ema_fast = INVALID_HANDLE, s1b_ema_slow = INVALID_HANDLE, s1c_ema_fast = INVALID_HANDLE, s1c_ema_slow = INVALID_HANDLE, s1d_ema_fast = INVALID_HANDLE, s1d_ema_slow = INVALID_HANDLE, s1e_ema_fast = INVALID_HANDLE, s1e_ema_slow = INVALID_HANDLE, s1f_ema_fast = INVALID_HANDLE, s1f_ema_slow = INVALID_HANDLE;
int s1a_ha = INVALID_HANDLE, s1b_ha = INVALID_HANDLE, s1c_ha = INVALID_HANDLE, s1d_ha = INVALID_HANDLE, s1e_ha = INVALID_HANDLE, s1f_ha = INVALID_HANDLE; // for HeikinFilter
int s1a_atr = INVALID_HANDLE, s1b_atr = INVALID_HANDLE, s1c_atr = INVALID_HANDLE, s1d_atr = INVALID_HANDLE, s1e_atr = INVALID_HANDLE, s1f_atr = INVALID_HANDLE; // for ATRFilter
int s1a_adx = INVALID_HANDLE, s1b_adx = INVALID_HANDLE, s1c_adx = INVALID_HANDLE, s1d_adx = INVALID_HANDLE, s1e_adx = INVALID_HANDLE, s1f_adx = INVALID_HANDLE;
int s1a_psar = INVALID_HANDLE, s1b_psar = INVALID_HANDLE, s1c_psar = INVALID_HANDLE, s1d_psar = INVALID_HANDLE, s1e_psar = INVALID_HANDLE, s1f_psar = INVALID_HANDLE;
int s1a_macd = INVALID_HANDLE, s1b_macd = INVALID_HANDLE, s1c_macd = INVALID_HANDLE, s1d_macd = INVALID_HANDLE, s1e_macd = INVALID_HANDLE, s1f_macd = INVALID_HANDLE;
int s1a_stoch = INVALID_HANDLE, s1b_stoch = INVALID_HANDLE, s1c_stoch = INVALID_HANDLE, s1d_stoch = INVALID_HANDLE, s1e_stoch = INVALID_HANDLE, s1f_stoch = INVALID_HANDLE;

// S2-A/B/C/D/E/F
int s2a_ema_trend = INVALID_HANDLE, s2b_ema_trend = INVALID_HANDLE, s2c_ema_trend = INVALID_HANDLE, s2d_ema_trend = INVALID_HANDLE, s2e_ema_trend = INVALID_HANDLE, s2f_ema_trend = INVALID_HANDLE;
int s2a_rsi_fast = INVALID_HANDLE, s2a_rsi_slow = INVALID_HANDLE, s2b_rsi_fast = INVALID_HANDLE, s2b_rsi_slow = INVALID_HANDLE, s2c_rsi_fast = INVALID_HANDLE, s2c_rsi_slow = INVALID_HANDLE, s2d_rsi_fast = INVALID_HANDLE, s2d_rsi_slow = INVALID_HANDLE, s2e_rsi_fast = INVALID_HANDLE, s2e_rsi_slow = INVALID_HANDLE, s2f_rsi_fast = INVALID_HANDLE, s2f_rsi_slow = INVALID_HANDLE;
int s2a_ema_fast = INVALID_HANDLE, s2a_ema_slow = INVALID_HANDLE, s2b_ema_fast = INVALID_HANDLE, s2b_ema_slow = INVALID_HANDLE, s2c_ema_fast = INVALID_HANDLE, s2c_ema_slow = INVALID_HANDLE, s2d_ema_fast = INVALID_HANDLE, s2d_ema_slow = INVALID_HANDLE, s2e_ema_fast = INVALID_HANDLE, s2e_ema_slow = INVALID_HANDLE, s2f_ema_fast = INVALID_HANDLE, s2f_ema_slow = INVALID_HANDLE;
int s2a_ha = INVALID_HANDLE, s2b_ha = INVALID_HANDLE, s2c_ha = INVALID_HANDLE, s2d_ha = INVALID_HANDLE, s2e_ha = INVALID_HANDLE, s2f_ha = INVALID_HANDLE; // for HeikinFilter
int s2a_atr = INVALID_HANDLE, s2b_atr = INVALID_HANDLE, s2c_atr = INVALID_HANDLE, s2d_atr = INVALID_HANDLE, s2e_atr = INVALID_HANDLE, s2f_atr = INVALID_HANDLE; // for ATRFilter
int s2a_adx = INVALID_HANDLE, s2b_adx = INVALID_HANDLE, s2c_adx = INVALID_HANDLE, s2d_adx = INVALID_HANDLE, s2e_adx = INVALID_HANDLE, s2f_adx = INVALID_HANDLE;
int s2a_psar = INVALID_HANDLE, s2b_psar = INVALID_HANDLE, s2c_psar = INVALID_HANDLE, s2d_psar = INVALID_HANDLE, s2e_psar = INVALID_HANDLE, s2f_psar = INVALID_HANDLE;
int s2a_macd = INVALID_HANDLE, s2b_macd = INVALID_HANDLE, s2c_macd = INVALID_HANDLE, s2d_macd = INVALID_HANDLE, s2e_macd = INVALID_HANDLE, s2f_macd = INVALID_HANDLE;
int s2a_stoch = INVALID_HANDLE, s2b_stoch = INVALID_HANDLE, s2c_stoch = INVALID_HANDLE, s2d_stoch = INVALID_HANDLE, s2e_stoch = INVALID_HANDLE, s2f_stoch = INVALID_HANDLE;

// NEW: ATR handles for trailing (per strategy TF)
int atr_handle1 = INVALID_HANDLE, atr_handle2 = INVALID_HANDLE;

// PSAR handles for HeikinSAR strategy (per strategy timeframe)
int psar_strat1 = INVALID_HANDLE, psar_strat2 = INVALID_HANDLE;

// ===== FLAGS (extended for RHV2 state) =====
struct StrategyFlags {
  bool waitForBuyCandle; bool waitForSellCandle; int lastCrossBar;
  bool checkRSIAtConfirmBuy; bool checkRSIAtConfirmSell;
  int crossShift;
  StrategyFlags(const StrategyFlags &other) {
    waitForBuyCandle = other.waitForBuyCandle;
    waitForSellCandle = other.waitForSellCandle;
    lastCrossBar = other.lastCrossBar;
    checkRSIAtConfirmBuy = other.checkRSIAtConfirmBuy;
    checkRSIAtConfirmSell = other.checkRSIAtConfirmSell;
    crossShift = other.crossShift;
  }
  StrategyFlags() : waitForBuyCandle(false), waitForSellCandle(false), lastCrossBar(0),
                    checkRSIAtConfirmBuy(false), checkRSIAtConfirmSell(false), crossShift(0) {}
};
StrategyFlags strat1flags, strat2flags;

// ===== ENTRY GATE STATE =====
int    lockoutBuyUntilBarS1 = -1, lockoutSellUntilBarS1 = -1;
int    lockoutBuyUntilBarS2 = -1, lockoutSellUntilBarS2 = -1;
double lastEntryPriceBuyS1 = 0.0, lastEntryPriceSellS1 = 0.0;
double lastEntryPriceBuyS2 = 0.0, lastEntryPriceSellS2 = 0.0;
int    skipBuyCountS1 = 0, skipSellCountS1 = 0, skipBuyCountS2 = 0, skipSellCountS2 = 0;

// ===== SIGNAL ENUM =====
enum TradeSignal { SIGNAL_NONE = 0, SIGNAL_BUY, SIGNAL_SELL };

// ===== UTILS =====
double PipSize(){ return (_Digits==3||_Digits==5)?10*_Point:_Point; }

void LogChart(string text,double price,color col){
  if(!EnableChartLogs) return;
  string obj="LOG_"+IntegerToString((int)TimeCurrent())+"_"+IntegerToString(MathRand());
  ObjectCreate(0,obj,OBJ_TEXT,0,TimeCurrent(),price);
  ObjectSetInteger(0,obj,OBJPROP_COLOR,col);
  ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,14);
  ObjectSetString(0,obj,OBJPROP_TEXT,text);
}

// ===== INDICATOR HELPERS =====
double GetRSI(int h,int shift=0){
  if(h==INVALID_HANDLE) { Print("Error: Invalid RSI handle"); return -1; }
  double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(h,0,shift,1,b)>0) return b[0];
  Print("Error: CopyBuffer failed for RSI"); return -1;
}

bool IsHeikinBull(int h,int sh=0){
  if(h==INVALID_HANDLE) { Print("Error: Invalid Heikin handle"); return false; }
  double o[],c[]; ArraySetAsSeries(o,true); ArraySetAsSeries(c,true);
  if(CopyBuffer(h,0,sh,1,o)<1) { Print("Error: CopyBuffer failed for Heikin Open"); return false; }
  if(CopyBuffer(h,3,sh,1,c)<1) { Print("Error: CopyBuffer failed for Heikin Close"); return false; }
  return c[0]>o[0];
}

bool IsHeikinBear(int h,int sh=0){
  if(h==INVALID_HANDLE) { Print("Error: Invalid Heikin handle"); return false; }
  double o[],c[]; ArraySetAsSeries(o,true); ArraySetAsSeries(c,true);
  if(CopyBuffer(h,0,sh,1,o)<1) { Print("Error: CopyBuffer failed for Heikin Open"); return false; }
  if(CopyBuffer(h,3,sh,1,c)<1) { Print("Error: CopyBuffer failed for Heikin Close"); return false; }
  return c[0]<o[0];
}

bool FullBodyCandleTF(ENUM_TIMEFRAMES tf,int sh,double minR){
  double o=iOpen(_Symbol,tf,sh), c=iClose(_Symbol,tf,sh), h=iHigh(_Symbol,tf,sh), l=iLow(_Symbol,tf,sh);
  double body=MathAbs(c-o), rng=h-l; if(rng<=0) return false; return (body/rng)>=minR;
}

int SafeN(int n){ return (n<=0)?1:n; }

bool LastNBullHeikin(int h,int n,bool requireFull=false,double minR=0.6, ENUM_TIMEFRAMES tf=PERIOD_CURRENT){
  n=SafeN(n);
  for(int i=1;i<=n;i++){ if(!IsHeikinBull(h,i)) return false; if(requireFull && !FullBodyCandleTF(tf,i,minR)) return false; }
  return true;
}

bool LastNBearHeikin(int h,int n,bool requireFull=false,double minR=0.6, ENUM_TIMEFRAMES tf=PERIOD_CURRENT){
  n=SafeN(n);
  for(int i=1;i<=n;i++){ if(!IsHeikinBear(h,i)) return false; if(requireFull && !FullBodyCandleTF(tf,i,minR)) return false; }
  return true;
}

double GetATR(int h,int shift=0){
  if(h==INVALID_HANDLE) { Print("Error: Invalid ATR handle"); return -1; }
  double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(h,0,shift,1,b)>0) return b[0];
  Print("Error: CopyBuffer failed for ATR"); return -1;
}

// ===== TIME =====
bool InRange(int h,int m,int fh,int fm,int th,int tm){ int now=h*60+m,from=fh*60+fm,to=th*60+tm; return now>=from && now<to; }
bool ForceCloseNow(int h,int m){ if(CloseAllHour<0) return false; int c=CloseAllHour*60+CloseAllMinute, now=h*60+m; return now>=c; }

// ===== SL/TP =====
double CalcStopLoss(StopLossEnum st,SLTypeEnum mode,double entry,bool isBuy,double val, int atr_handle = INVALID_HANDLE){
  if(st==NONE_STOP) return 0;
  if(st==Fixed_Stop || st==Custom_Trailing || (st==Trailing_Stop && UseInitialSLForTrailing1)){
    double pip=PipSize();
    double off;
    if(mode==SL_PIPS) off = val * pip;
    else off=entry*val/100.0;
    return isBuy?(entry-off):(entry+off);
  } else if(st==ATR_Trailing && UseInitialSLForTrailing1){
    double atr = GetATR(atr_handle, 1);
    if(atr < 0) return 0;
    double off = atr * ATR_Start_Multiplier;
    return isBuy?(entry - off):(entry + off);
  }
  return 0;
}

double CalcTakeProfit(TakeProfitEnum tt,TPTypeEnum mode,double entry,bool isBuy,double val){
  if(tt==Fixed_TP || tt==Custom_Trailing_Profit){
    double pip=PipSize();
    double off;
    if(mode==TP_PIPS) off = val * pip;
    else off=entry*val/100.0;
    return isBuy?(entry+off):(entry-off);
  } return 0;
}

// ===== FILTER EVAL (ENTRY ONLY) =====
bool CheckFilter_EMATrend(int h, ENUM_TIMEFRAMES tf, bool isBuy){
  if(h==INVALID_HANDLE) { Print("Error: Invalid EMA handle"); return false; }
  double b[]; ArraySetAsSeries(b,true);
  if(CopyBuffer(h,0,1,1,b)<1) { Print("Error: CopyBuffer failed for EMA"); return false; }
  double emaVal=b[0], close=iClose(_Symbol,tf,1);
  return isBuy ? (close>emaVal) : (close<emaVal);
}

bool CheckFilter_RSIx2(int hf,int hs,int shift,bool isBuy){
  if(hf==INVALID_HANDLE || hs==INVALID_HANDLE) { Print("Error: Invalid RSI handles for filter"); return false; }
  double fast=GetRSI(hf,shift), slow=GetRSI(hs,shift);
  if(fast<0 || slow<0) return false;
  return isBuy ? (fast>slow) : (fast<slow);
}

bool CheckFilter_EMACross(int hf,int hs,int shift,bool isBuy){
  if(hf==INVALID_HANDLE || hs==INVALID_HANDLE) { Print("Error: Invalid EMA handles for cross"); return false; }
  double bf[],bs[]; ArraySetAsSeries(bf,true); ArraySetAsSeries(bs,true);
  if(CopyBuffer(hf,0,shift,1,bf)<1 || CopyBuffer(hs,0,shift,1,bs)<1) { Print("Error: CopyBuffer failed for EMACross"); return false; }
  double fast=bf[0], slow=bs[0];
  return isBuy ? (fast>slow) : (fast<slow);
}

bool CheckFilter_Heikin(int h_ha, bool isBuy, int shift){
  if(h_ha==INVALID_HANDLE) { Print("Error: Invalid Heikin handle for filter"); return false; }
  return isBuy ? IsHeikinBull(h_ha, shift) : IsHeikinBear(h_ha, shift);
}

bool CheckFilter_ATR(int h_atr, double threshold){
  if(h_atr==INVALID_HANDLE) { Print("Error: Invalid ATR handle for filter"); return false; }
  double atr = GetATR(h_atr, 1);
  if(atr < 0) return false;
  return (atr <= threshold);
}

bool CheckFilter_ADXTrend(int h_adx, double threshold, bool isBuy){
  if(h_adx==INVALID_HANDLE){ Print("Error: Invalid ADX handle"); return false; }
  double adx[], pdi[], ndi[];
  ArraySetAsSeries(adx,true); ArraySetAsSeries(pdi,true); ArraySetAsSeries(ndi,true);
  if(CopyBuffer(h_adx,0,1,1,adx)<1 || CopyBuffer(h_adx,1,1,1,pdi)<1 || CopyBuffer(h_adx,2,1,1,ndi)<1){ Print("Error: ADX CopyBuffer"); return false; }
  if(adx[0] < threshold) return false;
  return isBuy ? (pdi[0] > ndi[0]) : (pdi[0] < ndi[0]);
}

bool CheckFilter_PSARTrend(int h_psar, ENUM_TIMEFRAMES tf, bool isBuy){
  if(h_psar==INVALID_HANDLE){ Print("Error: Invalid PSAR handle"); return false; }
  double psar[]; ArraySetAsSeries(psar,true);
  if(CopyBuffer(h_psar,0,1,1,psar)<1){ Print("Error: PSAR CopyBuffer"); return false; }
  double close=iClose(_Symbol,tf,1);
  return isBuy ? (close > psar[0]) : (close < psar[0]);
}

bool CheckFilter_MACDTrend(int h_macd, bool isBuy){
  if(h_macd==INVALID_HANDLE){ Print("Error: Invalid MACD handle"); return false; }
  double main[], sig[]; ArraySetAsSeries(main,true); ArraySetAsSeries(sig,true);
  if(CopyBuffer(h_macd,0,1,1,main)<1 || CopyBuffer(h_macd,1,1,1,sig)<1){ Print("Error: MACD CopyBuffer"); return false; }
  return isBuy ? (main[0] > sig[0] && main[0] > 0.0) : (main[0] < sig[0] && main[0] < 0.0);
}

bool CheckFilter_StochSignal(int h_stoch, bool isBuy){
  if(h_stoch==INVALID_HANDLE){ Print("Error: Invalid Stoch handle"); return false; }
  double k[], d[]; ArraySetAsSeries(k,true); ArraySetAsSeries(d,true);
  if(CopyBuffer(h_stoch,0,1,1,k)<1 || CopyBuffer(h_stoch,1,1,1,d)<1){ Print("Error: Stoch CopyBuffer"); return false; }
  if(isBuy)  return (k[0] > d[0] && k[0] <= Stoch_HighLevel);
  else       return (k[0] < d[0] && k[0] >= Stoch_LowLevel);
}

bool CheckFilter_VolumeAboveMA(ENUM_TIMEFRAMES tf, int period, double mult){
  if(period<=1) return true;
  long v_now = (long)iVolume(_Symbol, tf, 1);
  if(v_now<=0) return false;
  double sum=0.0; int cnt=0;
  for(int i=2;i<2+period;i++){ long v = (long)iVolume(_Symbol, tf, i); if(v<=0) continue; sum += (double)v; cnt++; }
  if(cnt==0) return false;
  double v_ma = sum / (double)cnt;
  return (v_now >= mult * v_ma);
}

bool EvalOneFilter(FilterEnum f, ENUM_TIMEFRAMES tf, bool isBuy,
                   int h_ema_trend, int h_rsi_fast, int h_rsi_slow, int h_ema_fast, int h_ema_slow, int h_ha, int h_atr,
                   int h_adx, int h_psar, int h_macd, int h_stoch)
{
  if(f == NONE_FILTER) return true;
  if(f == EMA_Trend) return CheckFilter_EMATrend(h_ema_trend, tf, isBuy);
  if(f == RSI_Cross2RSI) return CheckFilter_RSIx2(h_rsi_fast, h_rsi_slow, RSIx2_UseClosedBar ? 1 : 0, isBuy);
  if(f == EMACross) return CheckFilter_EMACross(h_ema_fast, h_ema_slow, EMACross_UseClosedBar ? 1 : 0, isBuy);
  if(f == HeikinFilter) return CheckFilter_Heikin(h_ha, isBuy, HeikinFilter_UseClosedBar ? 1 : 0);
  if(f == ATRFilter) return CheckFilter_ATR(h_atr, ATR_Threshold);
  if(f == ADXTrend) return CheckFilter_ADXTrend(h_adx, ADX_Filter_Threshold, isBuy);
  if(f == PSARTrend) return CheckFilter_PSARTrend(h_psar, tf, isBuy);
  if(f == MACDTrend) return CheckFilter_MACDTrend(h_macd, isBuy);
  if(f == StochSignal) return CheckFilter_StochSignal(h_stoch, isBuy);
  if(f == VolumeAboveMA) return CheckFilter_VolumeAboveMA(tf, VolMA_Period, Vol_Multiplier);
  return false;
}

bool EvalFilterBank(FilterEnum fA, ENUM_TIMEFRAMES tfA, FilterEnum fB, ENUM_TIMEFRAMES tfB,
                    FilterEnum fC, ENUM_TIMEFRAMES tfC, FilterEnum fD, ENUM_TIMEFRAMES tfD,
                    LogicMode logic, bool isBuy,
                    int hA_ema_trend, int hA_rsi_fast, int hA_rsi_slow, int hA_ema_fast, int hA_ema_slow, int hA_ha, int hA_atr, int hA_adx, int hA_psar, int hA_macd, int hA_stoch,
                    int hB_ema_trend, int hB_rsi_fast, int hB_rsi_slow, int hB_ema_fast, int hB_ema_slow, int hB_ha, int hB_atr, int hB_adx, int hB_psar, int hB_macd, int hB_stoch,
                    int hC_ema_trend, int hC_rsi_fast, int hC_rsi_slow, int hC_ema_fast, int hC_ema_slow, int hC_ha, int hC_atr, int hC_adx, int hC_psar, int hC_macd, int hC_stoch,
                    int hD_ema_trend, int hD_rsi_fast, int hD_rsi_slow, int hD_ema_fast, int hD_ema_slow, int hD_ha, int hD_atr, int hD_adx, int hD_psar, int hD_macd, int hD_stoch)
{
  bool a = EvalOneFilter(fA, tfA, isBuy, hA_ema_trend, hA_rsi_fast, hA_rsi_slow, hA_ema_fast, hA_ema_slow, hA_ha, hA_atr, hA_adx, hA_psar, hA_macd, hA_stoch);
  bool b = EvalOneFilter(fB, tfB, isBuy, hB_ema_trend, hB_rsi_fast, hB_rsi_slow, hB_ema_fast, hB_ema_slow, hB_ha, hB_atr, hB_adx, hB_psar, hB_macd, hB_stoch);
  bool c = EvalOneFilter(fC, tfC, isBuy, hC_ema_trend, hC_rsi_fast, hC_rsi_slow, hC_ema_fast, hC_ema_slow, hC_ha, hC_atr, hC_adx, hC_psar, hC_macd, hC_stoch);
  bool d = EvalOneFilter(fD, tfD, isBuy, hD_ema_trend, hD_rsi_fast, hD_rsi_slow, hD_ema_fast, hD_ema_slow, hD_ha, hD_atr, hD_adx, hD_psar, hD_macd, hD_stoch);
  return (logic==LOGIC_AND) ? (a && b && c && d) : (a || b || c || d);
}

// ===== ENTRIES =====
bool CrossUp_RSIs(int hFast,int hSlow){ double f1=GetRSI(hFast,1), s1=GetRSI(hSlow,1), f2=GetRSI(hFast,2), s2=GetRSI(hSlow,2); if(f1<0||s1<0||f2<0||s2<0) return false; return (f1>s1 && f2<=s2); }
bool CrossDn_RSIs(int hFast,int hSlow){ double f1=GetRSI(hFast,1), s1=GetRSI(hSlow,1), f2=GetRSI(hFast,2), s2=GetRSI(hSlow,2); if(f1<0||s1<0||f2<0||s2<0) return false; return (f1<s1 && f2>=s2); }

TradeSignal Strategy_RSI2Cross_Entry(int hFast,int hSlow){
  if(CrossUp_RSIs(hFast,hSlow)) return SIGNAL_BUY;
  if(CrossDn_RSIs(hFast,hSlow)) return SIGNAL_SELL;
  return SIGNAL_NONE;
}

TradeSignal Strategy_RH_V2_Entry(StrategyFlags &flags, int rsi_handle, int ha_handle, ENUM_TIMEFRAMES tf, bool allowBuy, bool allowSell){
  int sh1 = (RHV2_EntryUseClosedBar ? 1 : 0);
  int sh2 = sh1 + 1;
  double rsi_cur = GetRSI(rsi_handle, sh1), rsi_prev = GetRSI(rsi_handle, sh2);
  if(rsi_prev < 0 || rsi_cur < 0) return SIGNAL_NONE;
  if(rsi_prev < RSI_Low_Threshold && rsi_cur >= RSI_Low_Threshold && allowBuy && !flags.waitForBuyCandle){
    flags.waitForBuyCandle = true;
    flags.crossShift = sh1; flags.lastCrossBar = Bars(_Symbol, tf);
    LogChart("WaitForBuyCandle set", SymbolInfoDouble(_Symbol, SYMBOL_ASK), clrBlue);
  }
  if(rsi_prev > RSI_High_Threshold && rsi_cur <= RSI_High_Threshold && allowSell && !flags.waitForSellCandle){
    flags.waitForSellCandle = true;
    flags.crossShift = sh1; flags.lastCrossBar = Bars(_Symbol, tf);
    LogChart("WaitForSellCandle set", SymbolInfoDouble(_Symbol, SYMBOL_BID), clrBlue);
  }
  int currentBar = Bars(_Symbol, tf);
  int barsSinceCross = currentBar - flags.lastCrossBar;
  if(flags.waitForBuyCandle && barsSinceCross <= Max_N_Candles_After_Cross && barsSinceCross >= Heikin_Num_Bull){
    if(LastNBullHeikin(ha_handle, Heikin_Num_Bull, false, 0.6, tf)){
      flags.checkRSIAtConfirmBuy = true;
      double lastRSI = GetRSI(rsi_handle, 1);
      if(lastRSI >= RSI_Low_Threshold){ flags.waitForBuyCandle=false; flags.checkRSIAtConfirmBuy=false; return SIGNAL_BUY; }
      else { flags.waitForBuyCandle=false; flags.checkRSIAtConfirmBuy=false; return SIGNAL_NONE; }
    }
  } else if(flags.waitForBuyCandle && barsSinceCross > Max_N_Candles_After_Cross){ flags.waitForBuyCandle=false; }
  if(flags.waitForSellCandle && barsSinceCross <= Max_N_Candles_After_Cross && barsSinceCross >= Heikin_Num_Bear){
    if(LastNBearHeikin(ha_handle, Heikin_Num_Bear, false, 0.6, tf)){
      flags.checkRSIAtConfirmSell = true;
      double lastRSI = GetRSI(rsi_handle, 1);
      if(lastRSI <= RSI_High_Threshold){ flags.waitForSellCandle=false; flags.checkRSIAtConfirmSell=false; return SIGNAL_SELL; }
      else { flags.waitForSellCandle=false; flags.checkRSIAtConfirmSell=false; return SIGNAL_NONE; }
    }
  } else if(flags.waitForSellCandle && barsSinceCross > Max_N_Candles_After_Cross){ flags.waitForSellCandle=false; }
  return SIGNAL_NONE;
}

TradeSignal Strategy_HeikinComplete_Entry(int ha_handle, ENUM_TIMEFRAMES tf){
  if(LastNBullHeikin(ha_handle, Heikin_Num_Entry, false, 0.6, tf)) return SIGNAL_BUY;
  if(LastNBearHeikin(ha_handle, Heikin_Num_Entry, false, 0.6, tf)) return SIGNAL_SELL;
  return SIGNAL_NONE;
}

bool Strategy_RSI2Cross_ShouldExit(bool isBuy,int hFast,int hSlow){ return isBuy ? CrossDn_RSIs(hFast,hSlow) : CrossUp_RSIs(hFast,hSlow); }

bool Exit_RH_V2(bool isBuy, StrategyFlags &flags, int rsi_handle, int ha_handle, ENUM_TIMEFRAMES tf){
  int sh1 = (RHV2_ExitUseClosedBar ? 1 : 0);
  int sh2 = sh1 + 1;
  double rsi_cur = GetRSI(rsi_handle, sh1), rsi_prev = GetRSI(rsi_handle, sh2);
  if(rsi_prev < 0 || rsi_cur < 0) return false;
  if(isBuy && rsi_prev > RSI_High_Threshold && rsi_cur <= RSI_High_Threshold && !flags.waitForSellCandle){ flags.waitForSellCandle = true; flags.crossShift = sh1; flags.lastCrossBar = Bars(_Symbol, tf); }
  if(!isBuy && rsi_prev < RSI_Low_Threshold && rsi_cur >= RSI_Low_Threshold && !flags.waitForBuyCandle){ flags.waitForBuyCandle = true; flags.crossShift = sh1; flags.lastCrossBar = Bars(_Symbol, tf); }
  int currentBar = Bars(_Symbol, tf);
  int barsSinceCross = currentBar - flags.lastCrossBar;
  if(isBuy && flags.waitForSellCandle && barsSinceCross <= Max_N_Candles_After_Cross && barsSinceCross >= Heikin_Num_Bear_Exit){
    if(LastNBearHeikin(ha_handle, Heikin_Num_Bear_Exit, false, 0.6, tf)){
      double lastRSI = GetRSI(rsi_handle, 1);
      if(lastRSI <= RSI_High_Threshold){ flags.waitForSellCandle=false; return true; } else { flags.waitForSellCandle=false; return false; }
    }
  } else if(isBuy && flags.waitForSellCandle && barsSinceCross > Max_N_Candles_After_Cross){ flags.waitForSellCandle=false; }
  if(!isBuy && flags.waitForBuyCandle && barsSinceCross <= Max_N_Candles_After_Cross && barsSinceCross >= Heikin_Num_Bull_Exit){
    if(LastNBullHeikin(ha_handle, Heikin_Num_Bull_Exit, false, 0.6, tf)){
      double lastRSI = GetRSI(rsi_handle, 1);
      if(lastRSI >= RSI_Low_Threshold){ flags.waitForBuyCandle=false; return true; } else { flags.waitForBuyCandle=false; return false; }
    }
  } else if(!isBuy && flags.waitForBuyCandle && barsSinceCross > Max_N_Candles_After_Cross){ flags.waitForBuyCandle=false; }
  return false;
}

bool Strategy_HeikinComplete_ShouldExit(bool isBuy, int ha_handle, ENUM_TIMEFRAMES tf){
  if(isBuy && LastNBearHeikin(ha_handle, Heikin_Num_Exit, false, 0.6, tf)) return true;
  if(!isBuy && LastNBullHeikin(ha_handle, Heikin_Num_Exit, false, 0.6, tf)) return true;
  return false;
}

bool NewBarTF(ENUM_TIMEFRAMES tf){ static datetime last_t[256]; int idx = ((int)tf) & 255; datetime t=iTime(_Symbol,tf,0); if(t==0) return false; if(t!=last_t[idx]){ last_t[idx]=t; return true; } return false; }
bool ShouldProceedNewBar(){ if(NewBarMode==NBM_TF1) return NewBarTF(Strategy1Timeframe); if(NewBarMode==NBM_TF2) return (SelectedStrategy2!=NONE_STRATEGY)? NewBarTF(Strategy2Timeframe) : NewBarTF(Strategy1Timeframe); bool nb1=NewBarTF(Strategy1Timeframe), nb2=(SelectedStrategy2!=NONE_STRATEGY)?NewBarTF(Strategy2Timeframe):false; return (nb1||nb2); }
bool PosFromS1(const string c){ return (StringFind(c," S1")>=0); }

TradeSignal CheckStrategy(StrategyEnum strat,StrategyFlags &flags,
                         int rsi,int ha,bool pfB,bool pfS,
                         ENUM_TIMEFRAMES tf, int hFast, int hSlow)
{
  switch(strat){
    case RSI2Cross:        return Strategy_RSI2Cross_Entry(hFast,hSlow);
    case RSICrossHeikinV2: return Strategy_RH_V2_Entry(flags, rsi, ha, tf, pfB, pfS);
    case HeikinComplete:   return Strategy_HeikinComplete_Entry(ha, tf);
    case HeikinSAR: {
      int sh = (HeikinSAR_UseClosedBar_Entry ? 1 : 0);
      int hps = (tf==Strategy1Timeframe? psar_strat1 : psar_strat2);
      if(hps==INVALID_HANDLE) return SIGNAL_NONE;
      double buf[]; ArraySetAsSeries(buf,true);
      if(CopyBuffer(hps,0,sh,1,buf)<1) return SIGNAL_NONE;
      double psarVal = buf[0];
      double close = iClose(_Symbol, tf, sh);
      bool heikinBull = IsHeikinBull(ha, sh);
      bool heikinBear = IsHeikinBear(ha, sh);
      bool psarBuy = (close > psarVal);
      bool psarSell = (close < psarVal);
      if(pfB && heikinBull && psarBuy) return SIGNAL_BUY;
      if(pfS && heikinBear && psarSell) return SIGNAL_SELL;
      return SIGNAL_NONE;
    }
    default: return SIGNAL_NONE;
  }
}

bool HasTargetFilters_S1(){
  return (S1_FilterA==EMA_Trend || S1_FilterA==EMACross || S1_FilterA==RSI_Cross2RSI ||
          S1_FilterB==EMA_Trend || S1_FilterB==EMACross || S1_FilterB==RSI_Cross2RSI ||
          S1_FilterC==EMA_Trend || S1_FilterC==EMACross || S1_FilterC==RSI_Cross2RSI ||
          S1_FilterD==EMA_Trend || S1_FilterD==EMACross || S1_FilterD==RSI_Cross2RSI ||
          S1_FilterE==EMA_Trend || S1_FilterE==EMACross || S1_FilterE==RSI_Cross2RSI ||
          S1_FilterF==EMA_Trend || S1_FilterF==EMACross || S1_FilterF==RSI_Cross2RSI);
}

bool HasTargetFilters_S2(){
  return (S2_FilterA==EMA_Trend || S2_FilterA==EMACross || S2_FilterA==RSI_Cross2RSI ||
          S2_FilterB==EMA_Trend || S2_FilterB==EMACross || S2_FilterB==RSI_Cross2RSI ||
          S2_FilterC==EMA_Trend || S2_FilterC==EMACross || S2_FilterC==RSI_Cross2RSI ||
          S2_FilterD==EMA_Trend || S2_FilterD==EMACross || S2_FilterD==RSI_Cross2RSI ||
          S2_FilterE==EMA_Trend || S2_FilterE==EMACross || S2_FilterE==RSI_Cross2RSI ||
          S2_FilterF==EMA_Trend || S2_FilterF==EMACross || S2_FilterF==RSI_Cross2RSI);
}

bool PassEntryGates(bool isBuy, bool forS1, ENUM_TIMEFRAMES tf){
  if(LossLockoutTrades>0){
    if(forS1){
      if(isBuy && skipBuyCountS1>0){ skipBuyCountS1--; return false; }
      if(!isBuy && skipSellCountS1>0){ skipSellCountS1--; return false; }
    } else {
      if(isBuy && skipBuyCountS2>0){ skipBuyCountS2--; return false; }
      if(!isBuy && skipSellCountS2>0){ skipSellCountS2--; return false; }
    }
  }
  bool hasTarget = forS1 ? HasTargetFilters_S1() : HasTargetFilters_S2();
  if(hasTarget){
    if(LossLockoutBars>0){
      int curBar = Bars(_Symbol, tf);
      if(forS1){
        if(isBuy && lockoutBuyUntilBarS1>0 && curBar < lockoutBuyUntilBarS1) return false;
        if(!isBuy && lockoutSellUntilBarS1>0 && curBar < lockoutSellUntilBarS1) return false;
      } else {
        if(isBuy && lockoutBuyUntilBarS2>0 && curBar < lockoutBuyUntilBarS2) return false;
        if(!isBuy && lockoutSellUntilBarS2>0 && curBar < lockoutSellUntilBarS2) return false;
      }
    }
    if(PriceImproveATR>0){
      int ah = forS1 ? atr_handle1 : atr_handle2;
      if(ah==INVALID_HANDLE) ah = iATR(_Symbol, tf, ATR_Period);
      double atr = GetATR(ah, 1);
      if(atr>0){
        double minDelta = PriceImproveATR * atr;
        double cur = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(forS1){
          if(isBuy  && lastEntryPriceBuyS1>0  && cur < lastEntryPriceBuyS1  + minDelta) return false;
          if(!isBuy && lastEntryPriceSellS1>0 && cur > lastEntryPriceSellS1 - minDelta) return false;
        } else {
          if(isBuy  && lastEntryPriceBuyS2>0  && cur < lastEntryPriceBuyS2  + minDelta) return false;
          if(!isBuy && lastEntryPriceSellS2>0 && cur > lastEntryPriceSellS2 - minDelta) return false;
        }
      }
    }
  }
  return true;
}

int OnInit(){
  ZeroMemory(strat1flags); ZeroMemory(strat2flags);
  rsi_handle1 = iRSI(_Symbol,Strategy1Timeframe,RSI_Period,PRICE_CLOSE);
  ha_handle1  = iCustom(_Symbol,Strategy1Timeframe,HeikenIndicatorName);
  if(SelectedStrategy2!=NONE_STRATEGY){ rsi_handle2 = iRSI(_Symbol,Strategy2Timeframe,RSI_Period,PRICE_CLOSE); ha_handle2  = iCustom(_Symbol,Strategy2Timeframe,HeikenIndicatorName); }
  if(SelectedStopLoss1==ATR_Trailing || SelectedStopLoss2==ATR_Trailing || PriceImproveATR>0) { atr_handle1 = iATR(_Symbol,Strategy1Timeframe,ATR_Period); if(SelectedStrategy2!=NONE_STRATEGY) atr_handle2 = iATR(_Symbol,Strategy2Timeframe,ATR_Period); if(atr_handle1==INVALID_HANDLE) Print("Error: Failed to load ATR for S1"); if(SelectedStrategy2!=NONE_STRATEGY && atr_handle2==INVALID_HANDLE) Print("Error: Failed to load ATR for S2"); }
  if(SelectedStrategy1==RSI2Cross){ rsi_fast1=iRSI(_Symbol,Strategy1Timeframe,RSI2_Fast_Period,PRICE_CLOSE); rsi_slow1=iRSI(_Symbol,Strategy1Timeframe,RSI2_Slow_Period,PRICE_CLOSE); }
  if(SelectedStrategy2==RSI2Cross){ rsi_fast2=iRSI(_Symbol,Strategy2Timeframe,RSI2_Fast_Period,PRICE_CLOSE); rsi_slow2=iRSI(_Symbol,Strategy2Timeframe,RSI2_Slow_Period,PRICE_CLOSE); }
  
  // S1 filters A-D
  if(S1_FilterA==EMA_Trend) s1a_ema_trend = iMA(_Symbol,S1_FilterA_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S1_FilterA==RSI_Cross2RSI){ s1a_rsi_fast = iRSI(_Symbol,S1_FilterA_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s1a_rsi_slow = iRSI(_Symbol,S1_FilterA_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S1_FilterA==EMACross){ s1a_ema_fast = iMA(_Symbol,S1_FilterA_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s1a_ema_slow = iMA(_Symbol,S1_FilterA_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S1_FilterA==HeikinFilter) s1a_ha = iCustom(_Symbol,S1_FilterA_TF,HeikenIndicatorName);
  if(S1_FilterA==ATRFilter)    s1a_atr = iATR(_Symbol,S1_FilterA_TF,ATR_Period);
  if(S1_FilterA==ADXTrend)     s1a_adx = iADX(_Symbol,S1_FilterA_TF,ADX_Filter_Period);
  if(S1_FilterA==PSARTrend)    s1a_psar = iSAR(_Symbol,S1_FilterA_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S1_FilterA==MACDTrend)    s1a_macd = iMACD(_Symbol,S1_FilterA_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S1_FilterA==StochSignal)  s1a_stoch = iStochastic(_Symbol,S1_FilterA_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  if(S1_FilterB==EMA_Trend) s1b_ema_trend = iMA(_Symbol,S1_FilterB_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S1_FilterB==RSI_Cross2RSI){ s1b_rsi_fast = iRSI(_Symbol,S1_FilterB_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s1b_rsi_slow = iRSI(_Symbol,S1_FilterB_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S1_FilterB==EMACross){ s1b_ema_fast = iMA(_Symbol,S1_FilterB_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s1b_ema_slow = iMA(_Symbol,S1_FilterB_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S1_FilterB==HeikinFilter) s1b_ha = iCustom(_Symbol,S1_FilterB_TF,HeikenIndicatorName);
  if(S1_FilterB==ATRFilter)    s1b_atr = iATR(_Symbol,S1_FilterB_TF,ATR_Period);
  if(S1_FilterB==ADXTrend)     s1b_adx = iADX(_Symbol,S1_FilterB_TF,ADX_Filter_Period);
  if(S1_FilterB==PSARTrend)    s1b_psar = iSAR(_Symbol,S1_FilterB_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S1_FilterB==MACDTrend)    s1b_macd = iMACD(_Symbol,S1_FilterB_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S1_FilterB==StochSignal)  s1b_stoch = iStochastic(_Symbol,S1_FilterB_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  if(S1_FilterC==EMA_Trend) s1c_ema_trend = iMA(_Symbol,S1_FilterC_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S1_FilterC==RSI_Cross2RSI){ s1c_rsi_fast = iRSI(_Symbol,S1_FilterC_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s1c_rsi_slow = iRSI(_Symbol,S1_FilterC_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S1_FilterC==EMACross){ s1c_ema_fast = iMA(_Symbol,S1_FilterC_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s1c_ema_slow = iMA(_Symbol,S1_FilterC_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S1_FilterC==HeikinFilter) s1c_ha = iCustom(_Symbol,S1_FilterC_TF,HeikenIndicatorName);
  if(S1_FilterC==ATRFilter)    s1c_atr = iATR(_Symbol,S1_FilterC_TF,ATR_Period);
  if(S1_FilterC==ADXTrend)     s1c_adx = iADX(_Symbol,S1_FilterC_TF,ADX_Filter_Period);
  if(S1_FilterC==PSARTrend)    s1c_psar = iSAR(_Symbol,S1_FilterC_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S1_FilterC==MACDTrend)    s1c_macd = iMACD(_Symbol,S1_FilterC_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S1_FilterC==StochSignal)  s1c_stoch = iStochastic(_Symbol,S1_FilterC_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  if(S1_FilterD==EMA_Trend) s1d_ema_trend = iMA(_Symbol,S1_FilterD_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S1_FilterD==RSI_Cross2RSI){ s1d_rsi_fast = iRSI(_Symbol,S1_FilterD_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s1d_rsi_slow = iRSI(_Symbol,S1_FilterD_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S1_FilterD==EMACross){ s1d_ema_fast = iMA(_Symbol,S1_FilterD_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s1d_ema_slow = iMA(_Symbol,S1_FilterD_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S1_FilterD==HeikinFilter) s1d_ha = iCustom(_Symbol,S1_FilterD_TF,HeikenIndicatorName);
  if(S1_FilterD==ATRFilter)    s1d_atr = iATR(_Symbol,S1_FilterD_TF,ATR_Period);
  if(S1_FilterD==ADXTrend)     s1d_adx = iADX(_Symbol,S1_FilterD_TF,ADX_Filter_Period);
  if(S1_FilterD==PSARTrend)    s1d_psar = iSAR(_Symbol,S1_FilterD_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S1_FilterD==MACDTrend)    s1d_macd = iMACD(_Symbol,S1_FilterD_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S1_FilterD==StochSignal)  s1d_stoch = iStochastic(_Symbol,S1_FilterD_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  // S1 filters E-F
  if(S1_FilterE==EMA_Trend) s1e_ema_trend = iMA(_Symbol,S1_FilterE_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S1_FilterE==RSI_Cross2RSI){ s1e_rsi_fast = iRSI(_Symbol,S1_FilterE_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s1e_rsi_slow = iRSI(_Symbol,S1_FilterE_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S1_FilterE==EMACross){ s1e_ema_fast = iMA(_Symbol,S1_FilterE_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s1e_ema_slow = iMA(_Symbol,S1_FilterE_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S1_FilterE==HeikinFilter) s1e_ha = iCustom(_Symbol,S1_FilterE_TF,HeikenIndicatorName);
  if(S1_FilterE==ATRFilter)    s1e_atr = iATR(_Symbol,S1_FilterE_TF,ATR_Period);
  if(S1_FilterE==ADXTrend)     s1e_adx = iADX(_Symbol,S1_FilterE_TF,ADX_Filter_Period);
  if(S1_FilterE==PSARTrend)    s1e_psar = iSAR(_Symbol,S1_FilterE_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S1_FilterE==MACDTrend)    s1e_macd = iMACD(_Symbol,S1_FilterE_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S1_FilterE==StochSignal)  s1e_stoch = iStochastic(_Symbol,S1_FilterE_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  if(S1_FilterF==EMA_Trend) s1f_ema_trend = iMA(_Symbol,S1_FilterF_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S1_FilterF==RSI_Cross2RSI){ s1f_rsi_fast = iRSI(_Symbol,S1_FilterF_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s1f_rsi_slow = iRSI(_Symbol,S1_FilterF_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S1_FilterF==EMACross){ s1f_ema_fast = iMA(_Symbol,S1_FilterF_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s1f_ema_slow = iMA(_Symbol,S1_FilterF_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S1_FilterF==HeikinFilter) s1f_ha = iCustom(_Symbol,S1_FilterF_TF,HeikenIndicatorName);
  if(S1_FilterF==ATRFilter)    s1f_atr = iATR(_Symbol,S1_FilterF_TF,ATR_Period);
  if(S1_FilterF==ADXTrend)     s1f_adx = iADX(_Symbol,S1_FilterF_TF,ADX_Filter_Period);
  if(S1_FilterF==PSARTrend)    s1f_psar = iSAR(_Symbol,S1_FilterF_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S1_FilterF==MACDTrend)    s1f_macd = iMACD(_Symbol,S1_FilterF_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S1_FilterF==StochSignal)  s1f_stoch = iStochastic(_Symbol,S1_FilterF_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  // S2 filters A-D
  if(S2_FilterA==EMA_Trend) s2a_ema_trend = iMA(_Symbol,S2_FilterA_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S2_FilterA==RSI_Cross2RSI){ s2a_rsi_fast = iRSI(_Symbol,S2_FilterA_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s2a_rsi_slow = iRSI(_Symbol,S2_FilterA_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S2_FilterA==EMACross){ s2a_ema_fast = iMA(_Symbol,S2_FilterA_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s2a_ema_slow = iMA(_Symbol,S2_FilterA_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S2_FilterA==HeikinFilter) s2a_ha = iCustom(_Symbol,S2_FilterA_TF,HeikenIndicatorName);
  if(S2_FilterA==ATRFilter)    s2a_atr = iATR(_Symbol,S2_FilterA_TF,ATR_Period);
  if(S2_FilterA==ADXTrend)     s2a_adx = iADX(_Symbol,S2_FilterA_TF,ADX_Filter_Period);
  if(S2_FilterA==PSARTrend)    s2a_psar = iSAR(_Symbol,S2_FilterA_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S2_FilterA==MACDTrend)    s2a_macd = iMACD(_Symbol,S2_FilterA_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S2_FilterA==StochSignal)  s2a_stoch = iStochastic(_Symbol,S2_FilterA_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  if(S2_FilterB==EMA_Trend) s2b_ema_trend = iMA(_Symbol,S2_FilterB_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S2_FilterB==RSI_Cross2RSI){ s2b_rsi_fast = iRSI(_Symbol,S2_FilterB_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s2b_rsi_slow = iRSI(_Symbol,S2_FilterB_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S2_FilterB==EMACross){ s2b_ema_fast = iMA(_Symbol,S2_FilterB_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s2b_ema_slow = iMA(_Symbol,S2_FilterB_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S2_FilterB==HeikinFilter) s2b_ha = iCustom(_Symbol,S2_FilterB_TF,HeikenIndicatorName);
  if(S2_FilterB==ATRFilter)    s2b_atr = iATR(_Symbol,S2_FilterB_TF,ATR_Period);
  if(S2_FilterB==ADXTrend)     s2b_adx = iADX(_Symbol,S2_FilterB_TF,ADX_Filter_Period);
  if(S2_FilterB==PSARTrend)    s2b_psar = iSAR(_Symbol,S2_FilterB_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S2_FilterB==MACDTrend)    s2b_macd = iMACD(_Symbol,S2_FilterB_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S2_FilterB==StochSignal)  s2b_stoch = iStochastic(_Symbol,S2_FilterB_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  if(S2_FilterC==EMA_Trend) s2c_ema_trend = iMA(_Symbol,S2_FilterC_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S2_FilterC==RSI_Cross2RSI){ s2c_rsi_fast = iRSI(_Symbol,S2_FilterC_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s2c_rsi_slow = iRSI(_Symbol,S2_FilterC_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S2_FilterC==EMACross){ s2c_ema_fast = iMA(_Symbol,S2_FilterC_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s2c_ema_slow = iMA(_Symbol,S2_FilterC_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S2_FilterC==HeikinFilter) s2c_ha = iCustom(_Symbol,S2_FilterC_TF,HeikenIndicatorName);
  if(S2_FilterC==ATRFilter)    s2c_atr = iATR(_Symbol,S2_FilterC_TF,ATR_Period);
  if(S2_FilterC==ADXTrend)     s2c_adx = iADX(_Symbol,S2_FilterC_TF,ADX_Filter_Period);
  if(S2_FilterC==PSARTrend)    s2c_psar = iSAR(_Symbol,S2_FilterC_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S2_FilterC==MACDTrend)    s2c_macd = iMACD(_Symbol,S2_FilterC_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S2_FilterC==StochSignal)  s2c_stoch = iStochastic(_Symbol,S2_FilterC_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  if(S2_FilterD==EMA_Trend) s2d_ema_trend = iMA(_Symbol,S2_FilterD_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S2_FilterD==RSI_Cross2RSI){ s2d_rsi_fast = iRSI(_Symbol,S2_FilterD_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s2d_rsi_slow = iRSI(_Symbol,S2_FilterD_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S2_FilterD==EMACross){ s2d_ema_fast = iMA(_Symbol,S2_FilterD_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s2d_ema_slow = iMA(_Symbol,S2_FilterD_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S2_FilterD==HeikinFilter) s2d_ha = iCustom(_Symbol,S2_FilterD_TF,HeikenIndicatorName);
  if(S2_FilterD==ATRFilter)    s2d_atr = iATR(_Symbol,S2_FilterD_TF,ATR_Period);
  if(S2_FilterD==ADXTrend)     s2d_adx = iADX(_Symbol,S2_FilterD_TF,ADX_Filter_Period);
  if(S2_FilterD==PSARTrend)    s2d_psar = iSAR(_Symbol,S2_FilterD_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S2_FilterD==MACDTrend)    s2d_macd = iMACD(_Symbol,S2_FilterD_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S2_FilterD==StochSignal)  s2d_stoch = iStochastic(_Symbol,S2_FilterD_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  // S2 filters E-F
  if(S2_FilterE==EMA_Trend) s2e_ema_trend = iMA(_Symbol,S2_FilterE_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S2_FilterE==RSI_Cross2RSI){ s2e_rsi_fast = iRSI(_Symbol,S2_FilterE_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s2e_rsi_slow = iRSI(_Symbol,S2_FilterE_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S2_FilterE==EMACross){ s2e_ema_fast = iMA(_Symbol,S2_FilterE_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s2e_ema_slow = iMA(_Symbol,S2_FilterE_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S2_FilterE==HeikinFilter) s2e_ha = iCustom(_Symbol,S2_FilterE_TF,HeikenIndicatorName);
  if(S2_FilterE==ATRFilter)    s2e_atr = iATR(_Symbol,S2_FilterE_TF,ATR_Period);
  if(S2_FilterE==ADXTrend)     s2e_adx = iADX(_Symbol,S2_FilterE_TF,ADX_Filter_Period);
  if(S2_FilterE==PSARTrend)    s2e_psar = iSAR(_Symbol,S2_FilterE_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S2_FilterE==MACDTrend)    s2e_macd = iMACD(_Symbol,S2_FilterE_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S2_FilterE==StochSignal)  s2e_stoch = iStochastic(_Symbol,S2_FilterE_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  if(S2_FilterF==EMA_Trend) s2f_ema_trend = iMA(_Symbol,S2_FilterF_TF,EMA_Period,0,MODE_EMA,PRICE_CLOSE);
  if(S2_FilterF==RSI_Cross2RSI){ s2f_rsi_fast = iRSI(_Symbol,S2_FilterF_TF,FilterRSI_Fast_Period,PRICE_CLOSE); s2f_rsi_slow = iRSI(_Symbol,S2_FilterF_TF,FilterRSI_Slow_Period,PRICE_CLOSE); }
  if(S2_FilterF==EMACross){ s2f_ema_fast = iMA(_Symbol,S2_FilterF_TF,FilterEMA_Fast_Period,0,MODE_EMA,PRICE_CLOSE); s2f_ema_slow = iMA(_Symbol,S2_FilterF_TF,FilterEMA_Slow_Period,0,MODE_EMA,PRICE_CLOSE); }
  if(S2_FilterF==HeikinFilter) s2f_ha = iCustom(_Symbol,S2_FilterF_TF,HeikenIndicatorName);
  if(S2_FilterF==ATRFilter)    s2f_atr = iATR(_Symbol,S2_FilterF_TF,ATR_Period);
  if(S2_FilterF==ADXTrend)     s2f_adx = iADX(_Symbol,S2_FilterF_TF,ADX_Filter_Period);
  if(S2_FilterF==PSARTrend)    s2f_psar = iSAR(_Symbol,S2_FilterF_TF,PSAR_Step_Filter,PSAR_Max_Filter);
  if(S2_FilterF==MACDTrend)    s2f_macd = iMACD(_Symbol,S2_FilterF_TF,MACD_Fast_Filter,MACD_Slow_Filter,MACD_Signal_Filter,PRICE_CLOSE);
  if(S2_FilterF==StochSignal)  s2f_stoch = iStochastic(_Symbol,S2_FilterF_TF,Stoch_K_Filter,Stoch_D_Filter,Stoch_Slowing_Filter,MODE_SMA,STO_LOWHIGH);

  // HeikinSAR strategy PSAR handles
  if(SelectedStrategy1==HeikinSAR){ psar_strat1 = iSAR(_Symbol, Strategy1Timeframe, HeikinSAR_Step, HeikinSAR_Max); if(psar_strat1==INVALID_HANDLE){ Print("Error: Failed to load PSAR for HeikinSAR S1"); return INIT_FAILED; } if(ha_handle1==INVALID_HANDLE){ Print("Error: Heikin for HeikinSAR S1 not loaded"); return INIT_FAILED; } }
  if(SelectedStrategy2==HeikinSAR){ psar_strat2 = iSAR(_Symbol, Strategy2Timeframe, HeikinSAR_Step, HeikinSAR_Max); if(psar_strat2==INVALID_HANDLE){ Print("Error: Failed to load PSAR for HeikinSAR S2"); return INIT_FAILED; } if(ha_handle2==INVALID_HANDLE){ Print("Error: Heikin for HeikinSAR S2 not loaded"); return INIT_FAILED; } }

  bool NeedsHA1 = (SelectedStrategy1==RSICrossHeikinV2 || SelectedStrategy1==HeikinComplete);
  bool NeedsHA2 = (SelectedStrategy2==RSICrossHeikinV2 || SelectedStrategy2==HeikinComplete);
  bool ok1 = !NeedsHA1 || (ha_handle1!=INVALID_HANDLE);
  bool ok2 = (SelectedStrategy2==NONE_STRATEGY) || (!NeedsHA2 || (ha_handle2!=INVALID_HANDLE));
  if(rsi_handle1==INVALID_HANDLE && (SelectedStrategy1==RSICrossHeikinV2)) Print("Error: Failed to load RSI for S1");
  if(NeedsHA1 && ha_handle1==INVALID_HANDLE) Print("Error: Failed to load Heikin for S1");
  return (ok1 && ok2) ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnDeinit(const int /*reason*/){
  if(rsi_handle1!=INVALID_HANDLE) IndicatorRelease(rsi_handle1);
  if(rsi_handle2!=INVALID_HANDLE) IndicatorRelease(rsi_handle2);
  if(rsi_fast1 !=INVALID_HANDLE) IndicatorRelease(rsi_fast1);
  if(rsi_slow1 !=INVALID_HANDLE) IndicatorRelease(rsi_slow1);
  if(rsi_fast2 !=INVALID_HANDLE) IndicatorRelease(rsi_fast2);
  if(rsi_slow2 !=INVALID_HANDLE) IndicatorRelease(rsi_slow2);
  if(ha_handle1 !=INVALID_HANDLE) IndicatorRelease(ha_handle1);
  if(ha_handle2 !=INVALID_HANDLE) IndicatorRelease(ha_handle2);
  if(atr_handle1 !=INVALID_HANDLE) IndicatorRelease(atr_handle1);
  if(atr_handle2 !=INVALID_HANDLE) IndicatorRelease(atr_handle2);
  if(psar_strat1!=INVALID_HANDLE) IndicatorRelease(psar_strat1);
  if(psar_strat2!=INVALID_HANDLE) IndicatorRelease(psar_strat2);
  
  // release S1 A-F
  if(s1a_ema_trend!=INVALID_HANDLE) IndicatorRelease(s1a_ema_trend);
  if(s1a_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s1a_rsi_fast);
  if(s1a_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s1a_rsi_slow);
  if(s1a_ema_fast !=INVALID_HANDLE) IndicatorRelease(s1a_ema_fast);
  if(s1a_ema_slow !=INVALID_HANDLE) IndicatorRelease(s1a_ema_slow);
  if(s1a_ha !=INVALID_HANDLE) IndicatorRelease(s1a_ha);
  if(s1a_atr !=INVALID_HANDLE) IndicatorRelease(s1a_atr);
  if(s1b_ema_trend!=INVALID_HANDLE) IndicatorRelease(s1b_ema_trend);
  if(s1b_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s1b_rsi_fast);
  if(s1b_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s1b_rsi_slow);
  if(s1b_ema_fast !=INVALID_HANDLE) IndicatorRelease(s1b_ema_fast);
  if(s1b_ema_slow !=INVALID_HANDLE) IndicatorRelease(s1b_ema_slow);
  if(s1b_ha !=INVALID_HANDLE) IndicatorRelease(s1b_ha);
  if(s1b_atr !=INVALID_HANDLE) IndicatorRelease(s1b_atr);
  if(s1c_ema_trend!=INVALID_HANDLE) IndicatorRelease(s1c_ema_trend);
  if(s1c_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s1c_rsi_fast);
  if(s1c_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s1c_rsi_slow);
  if(s1c_ema_fast !=INVALID_HANDLE) IndicatorRelease(s1c_ema_fast);
  if(s1c_ema_slow !=INVALID_HANDLE) IndicatorRelease(s1c_ema_slow);
  if(s1c_ha !=INVALID_HANDLE) IndicatorRelease(s1c_ha);
  if(s1c_atr !=INVALID_HANDLE) IndicatorRelease(s1c_atr);
  if(s1d_ema_trend!=INVALID_HANDLE) IndicatorRelease(s1d_ema_trend);
  if(s1d_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s1d_rsi_fast);
  if(s1d_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s1d_rsi_slow);
  if(s1d_ema_fast !=INVALID_HANDLE) IndicatorRelease(s1d_ema_fast);
  if(s1d_ema_slow !=INVALID_HANDLE) IndicatorRelease(s1d_ema_slow);
  if(s1d_ha !=INVALID_HANDLE) IndicatorRelease(s1d_ha);
  if(s1d_atr !=INVALID_HANDLE) IndicatorRelease(s1d_atr);
  if(s1a_adx!=INVALID_HANDLE) IndicatorRelease(s1a_adx);
  if(s1b_adx!=INVALID_HANDLE) IndicatorRelease(s1b_adx);
  if(s1c_adx!=INVALID_HANDLE) IndicatorRelease(s1c_adx);
  if(s1d_adx!=INVALID_HANDLE) IndicatorRelease(s1d_adx);
  if(s1a_psar!=INVALID_HANDLE) IndicatorRelease(s1a_psar);
  if(s1b_psar!=INVALID_HANDLE) IndicatorRelease(s1b_psar);
  if(s1c_psar!=INVALID_HANDLE) IndicatorRelease(s1c_psar);
  if(s1d_psar!=INVALID_HANDLE) IndicatorRelease(s1d_psar);
  if(s1a_macd!=INVALID_HANDLE) IndicatorRelease(s1a_macd);
  if(s1b_macd!=INVALID_HANDLE) IndicatorRelease(s1b_macd);
  if(s1c_macd!=INVALID_HANDLE) IndicatorRelease(s1c_macd);
  if(s1d_macd!=INVALID_HANDLE) IndicatorRelease(s1d_macd);
  if(s1a_stoch!=INVALID_HANDLE) IndicatorRelease(s1a_stoch);
  if(s1b_stoch!=INVALID_HANDLE) IndicatorRelease(s1b_stoch);
  if(s1c_stoch!=INVALID_HANDLE) IndicatorRelease(s1c_stoch);
  if(s1d_stoch!=INVALID_HANDLE) IndicatorRelease(s1d_stoch);
  
  // release S2 A-F
  if(s2a_ema_trend!=INVALID_HANDLE) IndicatorRelease(s2a_ema_trend);
  if(s2a_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s2a_rsi_fast);
  if(s2a_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s2a_rsi_slow);
  if(s2a_ema_fast !=INVALID_HANDLE) IndicatorRelease(s2a_ema_fast);
  if(s2a_ema_slow !=INVALID_HANDLE) IndicatorRelease(s2a_ema_slow);
  if(s2a_ha !=INVALID_HANDLE) IndicatorRelease(s2a_ha);
  if(s2a_atr !=INVALID_HANDLE) IndicatorRelease(s2a_atr);
  if(s2b_ema_trend!=INVALID_HANDLE) IndicatorRelease(s2b_ema_trend);
  if(s2b_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s2b_rsi_fast);
  if(s2b_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s2b_rsi_slow);
  if(s2b_ema_fast !=INVALID_HANDLE) IndicatorRelease(s2b_ema_fast);
  if(s2b_ema_slow !=INVALID_HANDLE) IndicatorRelease(s2b_ema_slow);
  if(s2b_ha !=INVALID_HANDLE) IndicatorRelease(s2b_ha);
  if(s2b_atr !=INVALID_HANDLE) IndicatorRelease(s2b_atr);
  if(s2c_ema_trend!=INVALID_HANDLE) IndicatorRelease(s2c_ema_trend);
  if(s2c_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s2c_rsi_fast);
  if(s2c_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s2c_rsi_slow);
  if(s2c_ema_fast !=INVALID_HANDLE) IndicatorRelease(s2c_ema_fast);
  if(s2c_ema_slow !=INVALID_HANDLE) IndicatorRelease(s2c_ema_slow);
  if(s2c_ha !=INVALID_HANDLE) IndicatorRelease(s2c_ha);
  if(s2c_atr !=INVALID_HANDLE) IndicatorRelease(s2c_atr);
  if(s2d_ema_trend!=INVALID_HANDLE) IndicatorRelease(s2d_ema_trend);
  if(s2d_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s2d_rsi_fast);
  if(s2d_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s2d_rsi_slow);
  if(s2d_ema_fast !=INVALID_HANDLE) IndicatorRelease(s2d_ema_fast);
  if(s2d_ema_slow !=INVALID_HANDLE) IndicatorRelease(s2d_ema_slow);
  if(s2d_ha !=INVALID_HANDLE) IndicatorRelease(s2d_ha);
  if(s2d_atr !=INVALID_HANDLE) IndicatorRelease(s2d_atr);
  if(s2a_adx!=INVALID_HANDLE) IndicatorRelease(s2a_adx);
  if(s2b_adx!=INVALID_HANDLE) IndicatorRelease(s2b_adx);
  if(s2c_adx!=INVALID_HANDLE) IndicatorRelease(s2c_adx);
  if(s2d_adx!=INVALID_HANDLE) IndicatorRelease(s2d_adx);
  if(s2a_psar!=INVALID_HANDLE) IndicatorRelease(s2a_psar);
  if(s2b_psar!=INVALID_HANDLE) IndicatorRelease(s2b_psar);
  if(s2c_psar!=INVALID_HANDLE) IndicatorRelease(s2c_psar);
  if(s2d_psar!=INVALID_HANDLE) IndicatorRelease(s2d_psar);
  if(s2a_macd!=INVALID_HANDLE) IndicatorRelease(s2a_macd);
  if(s2b_macd!=INVALID_HANDLE) IndicatorRelease(s2b_macd);
  if(s2c_macd!=INVALID_HANDLE) IndicatorRelease(s2c_macd);
  if(s2d_macd!=INVALID_HANDLE) IndicatorRelease(s2d_macd);
  if(s2a_stoch!=INVALID_HANDLE) IndicatorRelease(s2a_stoch);
  if(s2b_stoch!=INVALID_HANDLE) IndicatorRelease(s2b_stoch);
  if(s2c_stoch!=INVALID_HANDLE) IndicatorRelease(s2c_stoch);
  if(s2d_stoch!=INVALID_HANDLE) IndicatorRelease(s2d_stoch);
  
  // release S1 E-F
  if(s1e_ema_trend!=INVALID_HANDLE) IndicatorRelease(s1e_ema_trend);
  if(s1e_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s1e_rsi_fast);
  if(s1e_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s1e_rsi_slow);
  if(s1e_ema_fast !=INVALID_HANDLE) IndicatorRelease(s1e_ema_fast);
  if(s1e_ema_slow !=INVALID_HANDLE) IndicatorRelease(s1e_ema_slow);
  if(s1e_ha !=INVALID_HANDLE) IndicatorRelease(s1e_ha);
  if(s1e_atr !=INVALID_HANDLE) IndicatorRelease(s1e_atr);
  if(s1e_adx!=INVALID_HANDLE) IndicatorRelease(s1e_adx);
  if(s1e_psar!=INVALID_HANDLE) IndicatorRelease(s1e_psar);
  if(s1e_macd!=INVALID_HANDLE) IndicatorRelease(s1e_macd);
  if(s1e_stoch!=INVALID_HANDLE) IndicatorRelease(s1e_stoch);
  
  if(s1f_ema_trend!=INVALID_HANDLE) IndicatorRelease(s1f_ema_trend);
  if(s1f_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s1f_rsi_fast);
  if(s1f_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s1f_rsi_slow);
  if(s1f_ema_fast !=INVALID_HANDLE) IndicatorRelease(s1f_ema_fast);
  if(s1f_ema_slow !=INVALID_HANDLE) IndicatorRelease(s1f_ema_slow);
  if(s1f_ha !=INVALID_HANDLE) IndicatorRelease(s1f_ha);
  if(s1f_atr !=INVALID_HANDLE) IndicatorRelease(s1f_atr);
  if(s1f_adx!=INVALID_HANDLE) IndicatorRelease(s1f_adx);
  if(s1f_psar!=INVALID_HANDLE) IndicatorRelease(s1f_psar);
  if(s1f_macd!=INVALID_HANDLE) IndicatorRelease(s1f_macd);
  if(s1f_stoch!=INVALID_HANDLE) IndicatorRelease(s1f_stoch);
  
  // release S2 E-F
  if(s2e_ema_trend!=INVALID_HANDLE) IndicatorRelease(s2e_ema_trend);
  if(s2e_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s2e_rsi_fast);
  if(s2e_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s2e_rsi_slow);
  if(s2e_ema_fast !=INVALID_HANDLE) IndicatorRelease(s2e_ema_fast);
  if(s2e_ema_slow !=INVALID_HANDLE) IndicatorRelease(s2e_ema_slow);
  if(s2e_ha !=INVALID_HANDLE) IndicatorRelease(s2e_ha);
  if(s2e_atr !=INVALID_HANDLE) IndicatorRelease(s2e_atr);
  if(s2e_adx!=INVALID_HANDLE) IndicatorRelease(s2e_adx);
  if(s2e_psar!=INVALID_HANDLE) IndicatorRelease(s2e_psar);
  if(s2e_macd!=INVALID_HANDLE) IndicatorRelease(s2e_macd);
  if(s2e_stoch!=INVALID_HANDLE) IndicatorRelease(s2e_stoch);
  
  if(s2f_ema_trend!=INVALID_HANDLE) IndicatorRelease(s2f_ema_trend);
  if(s2f_rsi_fast !=INVALID_HANDLE) IndicatorRelease(s2f_rsi_fast);
  if(s2f_rsi_slow !=INVALID_HANDLE) IndicatorRelease(s2f_rsi_slow);
  if(s2f_ema_fast !=INVALID_HANDLE) IndicatorRelease(s2f_ema_fast);
  if(s2f_ema_slow !=INVALID_HANDLE) IndicatorRelease(s2f_ema_slow);
  if(s2f_ha !=INVALID_HANDLE) IndicatorRelease(s2f_ha);
  if(s2f_atr !=INVALID_HANDLE) IndicatorRelease(s2f_atr);
  if(s2f_adx!=INVALID_HANDLE) IndicatorRelease(s2f_adx);
  if(s2f_psar!=INVALID_HANDLE) IndicatorRelease(s2f_psar);
  if(s2f_macd!=INVALID_HANDLE) IndicatorRelease(s2f_macd);
  if(s2f_stoch!=INVALID_HANDLE) IndicatorRelease(s2f_stoch);
}

void OnTick(){
  if(!ShouldProceedNewBar()) return;
  MqlDateTime tm; TimeToStruct(TimeCurrent(),tm); int hour=tm.hour, min=tm.min;
  bool hasPosition=PositionSelect(_Symbol);
  if(hasPosition && ForceCloseNow(hour,min)){
    trade.PositionClose(_Symbol);
    ZeroMemory(strat1flags); ZeroMemory(strat2flags);
    return;
  }
  bool allowEntries = (DisableTradingWindow || InRange(hour,min,TradingStartHour,TradingStartMin,TradingEndHour,TradingEndMin));

  if(allowEntries && !hasPosition){
    // S1
    bool s1_buyOK = EvalFilterBank(S1_FilterA,S1_FilterA_TF,S1_FilterB,S1_FilterB_TF,S1_FilterC,S1_FilterC_TF,S1_FilterD,S1_FilterD_TF,S1_FilterLogic,true,
      s1a_ema_trend,s1a_rsi_fast,s1a_rsi_slow,s1a_ema_fast,s1a_ema_slow,s1a_ha,s1a_atr,s1a_adx,s1a_psar,s1a_macd,s1a_stoch,
      s1b_ema_trend,s1b_rsi_fast,s1b_rsi_slow,s1b_ema_fast,s1b_ema_slow,s1b_ha,s1b_atr,s1b_adx,s1b_psar,s1b_macd,s1b_stoch,
      s1c_ema_trend,s1c_rsi_fast,s1c_rsi_slow,s1c_ema_fast,s1c_ema_slow,s1c_ha,s1c_atr,s1c_adx,s1c_psar,s1c_macd,s1c_stoch,
      s1d_ema_trend,s1d_rsi_fast,s1d_rsi_slow,s1d_ema_fast,s1d_ema_slow,s1d_ha,s1d_atr,s1d_adx,s1d_psar,s1d_macd,s1d_stoch);
    bool s1_sellOK = EvalFilterBank(S1_FilterA,S1_FilterA_TF,S1_FilterB,S1_FilterB_TF,S1_FilterC,S1_FilterC_TF,S1_FilterD,S1_FilterD_TF,S1_FilterLogic,false,
      s1a_ema_trend,s1a_rsi_fast,s1a_rsi_slow,s1a_ema_fast,s1a_ema_slow,s1a_ha,s1a_atr,s1a_adx,s1a_psar,s1a_macd,s1a_stoch,
      s1b_ema_trend,s1b_rsi_fast,s1b_rsi_slow,s1b_ema_fast,s1b_ema_slow,s1b_ha,s1b_atr,s1b_adx,s1b_psar,s1b_macd,s1b_stoch,
      s1c_ema_trend,s1c_rsi_fast,s1c_rsi_slow,s1c_ema_fast,s1c_ema_slow,s1c_ha,s1c_atr,s1c_adx,s1c_psar,s1c_macd,s1c_stoch,
      s1d_ema_trend,s1d_rsi_fast,s1d_rsi_slow,s1d_ema_fast,s1d_ema_slow,s1d_ha,s1d_atr,s1d_adx,s1d_psar,s1d_macd,s1d_stoch);
    
    // S1 filters E & F (buy signals)
    bool s1_buyE  = EvalOneFilter(S1_FilterE, S1_FilterE_TF, true,  s1e_ema_trend, s1e_rsi_fast, s1e_rsi_slow, s1e_ema_fast, s1e_ema_slow, s1e_ha, s1e_atr, s1e_adx, s1e_psar, s1e_macd, s1e_stoch);
    bool s1_buyF  = EvalOneFilter(S1_FilterF, S1_FilterF_TF, true,  s1f_ema_trend, s1f_rsi_fast, s1f_rsi_slow, s1f_ema_fast, s1f_ema_slow, s1f_ha, s1f_atr, s1f_adx, s1f_psar, s1f_macd, s1f_stoch);
    // S1 filters E & F (sell signals)  
    bool s1_sellE = EvalOneFilter(S1_FilterE, S1_FilterE_TF, false, s1e_ema_trend, s1e_rsi_fast, s1e_rsi_slow, s1e_ema_fast, s1e_ema_slow, s1e_ha, s1e_atr, s1e_adx, s1e_psar, s1e_macd, s1e_stoch);
    bool s1_sellF = EvalOneFilter(S1_FilterF, S1_FilterF_TF, false, s1f_ema_trend, s1f_rsi_fast, s1f_rsi_slow, s1f_ema_fast, s1f_ema_slow, s1f_ha, s1f_atr, s1f_adx, s1f_psar, s1f_macd, s1f_stoch);
    
    if(S1_FilterLogic==LOGIC_AND){ s1_buyOK = (s1_buyOK && s1_buyE && s1_buyF); s1_sellOK = (s1_sellOK && s1_sellE && s1_sellF); }
    else { s1_buyOK = (s1_buyOK || s1_buyE || s1_buyF); s1_sellOK = (s1_sellOK || s1_sellE || s1_sellF); }

    TradeSignal sig1=CheckStrategy(SelectedStrategy1,strat1flags, rsi_handle1,ha_handle1,s1_buyOK,s1_sellOK, Strategy1Timeframe,rsi_fast1,rsi_slow1);
    if(sig1!=SIGNAL_NONE){
      bool dirBuy = (sig1==SIGNAL_BUY);
      bool finalOK = dirBuy? s1_buyOK : s1_sellOK;
      if(finalOK){ if(!PassEntryGates(dirBuy, true, Strategy1Timeframe)) finalOK = false; }
      if(finalOK){
        double entry = dirBuy? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
        double sl1 = CalcStopLoss(SelectedStopLoss1, StopLossType1, entry, dirBuy, StopLossValue1, atr_handle1);
        double sl2 = CalcStopLoss(SelectedStopLoss2, StopLossType2, entry, dirBuy, StopLossValue2, atr_handle1);
        double sl=(sl1>0)?sl1:((sl2>0)?sl2:0);
        double tp1=(SelectedTakeProfit1==Fixed_TP)?CalcTakeProfit(SelectedTakeProfit1,TakeProfitType1,entry,dirBuy,TakeProfitValue1):0;
        double tp2=(SelectedTakeProfit2==Fixed_TP)?CalcTakeProfit(SelectedTakeProfit2,TakeProfitType2,entry,dirBuy,TakeProfitValue2):0;
        double tp = (tp1>0)?tp1:((tp2>0)?tp2:0);
        string tag="STRAT="+EnumToString(SelectedStrategy1);
        string reason=(dirBuy?"BUY":"SELL"); reason+="("+tag+") S1";
        trade.SetExpertMagicNumber(Magic_S1);
        if(dirBuy) trade.Buy(LotSize,_Symbol,entry,sl,tp,reason); else trade.Sell(LotSize,_Symbol,entry,sl,tp,reason);
        if(dirBuy) lastEntryPriceBuyS1 = entry; else lastEntryPriceSellS1 = entry;
        ZeroMemory(strat1flags); ZeroMemory(strat2flags);
      }
    }

    // S2
    if(!PositionSelect(_Symbol) && SelectedStrategy2!=NONE_STRATEGY){
      bool s2_buyOK = EvalFilterBank(S2_FilterA,S2_FilterA_TF,S2_FilterB,S2_FilterB_TF,S2_FilterC,S2_FilterC_TF,S2_FilterD,S2_FilterD_TF,S2_FilterLogic,true,
        s2a_ema_trend,s2a_rsi_fast,s2a_rsi_slow,s2a_ema_fast,s2a_ema_slow,s2a_ha,s2a_atr,s2a_adx,s2a_psar,s2a_macd,s2a_stoch,
        s2b_ema_trend,s2b_rsi_fast,s2b_rsi_slow,s2b_ema_fast,s2b_ema_slow,s2b_ha,s2b_atr,s2b_adx,s2b_psar,s2b_macd,s2b_stoch,
        s2c_ema_trend,s2c_rsi_fast,s2c_rsi_slow,s2c_ema_fast,s2c_ema_slow,s2c_ha,s2c_atr,s2c_adx,s2c_psar,s2c_macd,s2c_stoch,
        s2d_ema_trend,s2d_rsi_fast,s2d_rsi_slow,s2d_ema_fast,s2d_ema_slow,s2d_ha,s2d_atr,s2d_adx,s2d_psar,s2d_macd,s2d_stoch);
      bool s2_sellOK = EvalFilterBank(S2_FilterA,S2_FilterA_TF,S2_FilterB,S2_FilterB_TF,S2_FilterC,S2_FilterC_TF,S2_FilterD,S2_FilterD_TF,S2_FilterLogic,false,
        s2a_ema_trend,s2a_rsi_fast,s2a_rsi_slow,s2a_ema_fast,s2a_ema_slow,s2a_ha,s2a_atr,s2a_adx,s2a_psar,s2a_macd,s2a_stoch,
        s2b_ema_trend,s2b_rsi_fast,s2b_rsi_slow,s2b_ema_fast,s2b_ema_slow,s2b_ha,s2b_atr,s2b_adx,s2b_psar,s2b_macd,s2b_stoch,
        s2c_ema_trend,s2c_rsi_fast,s2c_rsi_slow,s2c_ema_fast,s2c_ema_slow,s2c_ha,s2c_atr,s2c_adx,s2c_psar,s2c_macd,s2c_stoch,
        s2d_ema_trend,s2d_rsi_fast,s2d_rsi_slow,s2d_ema_fast,s2d_ema_slow,s2d_ha,s2d_atr,s2d_adx,s2d_psar,s2d_macd,s2d_stoch);
      
      // S2 filters E & F (buy signals)
      bool s2_buyE  = EvalOneFilter(S2_FilterE, S2_FilterE_TF, true,  s2e_ema_trend, s2e_rsi_fast, s2e_rsi_slow, s2e_ema_fast, s2e_ema_slow, s2e_ha, s2e_atr, s2e_adx, s2e_psar, s2e_macd, s2e_stoch);
      bool s2_buyF  = EvalOneFilter(S2_FilterF, S2_FilterF_TF, true,  s2f_ema_trend, s2f_rsi_fast, s2f_rsi_slow, s2f_ema_fast, s2f_ema_slow, s2f_ha, s2f_atr, s2f_adx, s2f_psar, s2f_macd, s2f_stoch);
      // S2 filters E & F (sell signals)  
      bool s2_sellE = EvalOneFilter(S2_FilterE, S2_FilterE_TF, false, s2e_ema_trend, s2e_rsi_fast, s2e_rsi_slow, s2e_ema_fast, s2e_ema_slow, s2e_ha, s2e_atr, s2e_adx, s2e_psar, s2e_macd, s2e_stoch);
      bool s2_sellF = EvalOneFilter(S2_FilterF, S2_FilterF_TF, false, s2f_ema_trend, s2f_rsi_fast, s2f_rsi_slow, s2f_ema_fast, s2f_ema_slow, s2f_ha, s2f_atr, s2f_adx, s2f_psar, s2f_macd, s2f_stoch);
      
      if(S2_FilterLogic==LOGIC_AND){ s2_buyOK = (s2_buyOK && s2_buyE && s2_buyF); s2_sellOK = (s2_sellOK && s2_sellE && s2_sellF); }
      else { s2_buyOK = (s2_buyOK || s2_buyE || s2_buyF); s2_sellOK = (s2_sellOK || s2_sellE || s2_sellF); }

      TradeSignal sig2=CheckStrategy(SelectedStrategy2,strat2flags, rsi_handle2,ha_handle2,s2_buyOK,s2_sellOK, Strategy2Timeframe,rsi_fast2,rsi_slow2);
      if(sig2!=SIGNAL_NONE){
        bool dirBuy = (sig2==SIGNAL_BUY);
        bool finalOK = dirBuy? s2_buyOK : s2_sellOK;
        if(finalOK){ if(!PassEntryGates(dirBuy, false, Strategy2Timeframe)) finalOK = false; }
        if(finalOK){
          double entry = dirBuy? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
          double sl1 = CalcStopLoss(SelectedStopLoss1, StopLossType1, entry, dirBuy, StopLossValue1, atr_handle2);
          double sl2 = CalcStopLoss(SelectedStopLoss2, StopLossType2, entry, dirBuy, StopLossValue2, atr_handle2);
          double sl=(sl1>0)?sl1:((sl2>0)?sl2:0);
          double tp1=(SelectedTakeProfit1==Fixed_TP)?CalcTakeProfit(SelectedTakeProfit1,TakeProfitType1,entry,dirBuy,TakeProfitValue1):0;
          double tp2=(SelectedTakeProfit2==Fixed_TP)?CalcTakeProfit(SelectedTakeProfit2,TakeProfitType2,entry,dirBuy,TakeProfitValue2):0;
          double tp = (tp1>0)?tp1:((tp2>0)?tp2:0);
          string tag="STRAT="+EnumToString(SelectedStrategy2);
          string reason=(dirBuy?"BUY":"SELL"); reason+="("+tag+") S2";
          trade.SetExpertMagicNumber(Magic_S2);
          if(dirBuy) trade.Buy(LotSize,_Symbol,entry,sl,tp,reason); else trade.Sell(LotSize,_Symbol,entry,sl,tp,reason);
          if(dirBuy) lastEntryPriceBuyS2 = entry; else lastEntryPriceSellS2 = entry;
          ZeroMemory(strat1flags); ZeroMemory(strat2flags);
        }
      }
    }
  } else if(!allowEntries && !hasPosition) {
    ZeroMemory(strat1flags); ZeroMemory(strat2flags);
  }

  // EXITS (Trailing + optional strategy exits)
  if(PositionSelect(_Symbol)){
    int positionType = (int)PositionGetInteger(POSITION_TYPE);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double current = (positionType==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
    double pip = PipSize();

    // Trailing SL1
    if(SelectedStopLoss1==Trailing_Stop){
      double off_start, off_step;
      if(StopLossType1 == SL_PIPS) { off_start = TrailingStart1 * pip; off_step = TrailingStep1 * pip; }
      else { off_start = entryPrice * TrailingStart1 / 100.0; off_step = entryPrice * TrailingStep1 / 100.0; }
      double trigger = (positionType==POSITION_TYPE_BUY) ? entryPrice + off_start : entryPrice - off_start;
      bool hit = (positionType==POSITION_TYPE_BUY) ? (current >= trigger) : (current <= trigger);
      if(hit){
        double newsl = (positionType==POSITION_TYPE_BUY) ? current - off_step : current + off_step;
        double curSL=PositionGetDouble(POSITION_SL);
        if(MathAbs(curSL-newsl)>_Point){ double curTP=PositionGetDouble(POSITION_TP); trade.PositionModify(_Symbol,newsl,curTP); LogChart("Trailing SL1 → "+DoubleToString(newsl,_Digits),current,clrViolet); }
      }
    }
    
    // Trailing SL2
    if(SelectedStopLoss2==Trailing_Stop){
      double off_start, off_step;
      if(StopLossType2 == SL_PIPS) { off_start = TrailingStart2 * pip; off_step = TrailingStep2 * pip; }
      else { off_start = entryPrice * TrailingStart2 / 100.0; off_step = entryPrice * TrailingStep2 / 100.0; }
      double trigger = (positionType==POSITION_TYPE_BUY) ? entryPrice + off_start : entryPrice - off_start;
      bool hit = (positionType==POSITION_TYPE_BUY) ? (current >= trigger) : (current <= trigger);
      if(hit){
        double newsl = (positionType==POSITION_TYPE_BUY) ? current - off_step : current + off_step;
        double curSL=PositionGetDouble(POSITION_SL);
        if(MathAbs(curSL-newsl)>_Point){ double curTP=PositionGetDouble(POSITION_TP); trade.PositionModify(_Symbol,newsl,curTP); LogChart("Trailing SL2 → "+DoubleToString(newsl,_Digits),current,clrViolet); }
      }
    }
    
    // Custom Trailing SL1
    if (SelectedStopLoss1 == Custom_Trailing) {
      double off_start, off_step;
      if(StopLossType1 == SL_PIPS) { off_start = TrailingStart1 * pip; off_step = TrailingStep1 * pip; }
      else { off_start = entryPrice * TrailingStart1 / 100.0; off_step = entryPrice * TrailingStep1 / 100.0; }
      double trigger = (positionType == POSITION_TYPE_BUY) ? entryPrice + off_start : entryPrice - off_start;
      bool hit = (positionType == POSITION_TYPE_BUY) ? (current >= trigger) : (current <= trigger);
      if (hit) {
        double newsl = (positionType == POSITION_TYPE_BUY) ? current - off_step : current + off_step;
        double curSL = PositionGetDouble(POSITION_SL);
        bool update = (positionType == POSITION_TYPE_BUY && newsl > curSL) || (positionType == POSITION_TYPE_SELL && newsl < curSL);
        if (update) { trade.PositionModify(_Symbol, newsl, PositionGetDouble(POSITION_TP)); LogChart("Custom Trailing SL1 → " + DoubleToString(newsl, _Digits), current, clrViolet); }
      }
    }
    
    // Custom Trailing SL2
    if (SelectedStopLoss2 == Custom_Trailing) {
      double off_start, off_step;
      if(StopLossType2 == SL_PIPS) { off_start = TrailingStart2 * pip; off_step = TrailingStep2 * pip; }
      else { off_start = entryPrice * TrailingStart2 / 100.0; off_step = entryPrice * TrailingStep2 / 100.0; }
      double trigger = (positionType == POSITION_TYPE_BUY) ? entryPrice + off_start : entryPrice - off_start;
      bool hit = (positionType == POSITION_TYPE_BUY) ? (current >= trigger) : (current <= trigger);
      if (hit) {
        double newsl = (positionType == POSITION_TYPE_BUY) ? current - off_step : current + off_step;
        double curSL = PositionGetDouble(POSITION_SL);
        bool update = (positionType == POSITION_TYPE_BUY && newsl > curSL) || (positionType == POSITION_TYPE_SELL && newsl < curSL);
        if (update) { trade.PositionModify(_Symbol, newsl, PositionGetDouble(POSITION_TP)); LogChart("Custom Trailing SL2 → " + DoubleToString(newsl, _Digits), current, clrViolet); }
      }
    }
    
    // ATR Trailing SL1
    if (SelectedStopLoss1 == ATR_Trailing) {
      double atr = GetATR(atr_handle1, 0);
      if(atr > 0) {
        double off_start = atr * ATR_Start_Multiplier;
        double off_step  = atr * ATR_Step_Multiplier;
        double trigger = (positionType == POSITION_TYPE_BUY) ? entryPrice + off_start : entryPrice - off_start;
        bool hit = (positionType == POSITION_TYPE_BUY) ? (current >= trigger) : (current <= trigger);
        if (hit) {
          double newsl = (positionType == POSITION_TYPE_BUY) ? current - off_step : current + off_step;
          double curSL = PositionGetDouble(POSITION_SL);
          bool update = (positionType == POSITION_TYPE_BUY && newsl > curSL) || (positionType == POSITION_TYPE_SELL && newsl < curSL);
          if (update) { trade.PositionModify(_Symbol, newsl, PositionGetDouble(POSITION_TP)); LogChart("ATR Trailing SL1 → " + DoubleToString(newsl, _Digits), current, clrViolet); }
        }
      }
    }
    
    // ATR Trailing SL2
    if (SelectedStopLoss2 == ATR_Trailing) {
      double atr = GetATR(atr_handle2, 0);
      if(atr > 0) {
        double off_start = atr * ATR_Start_Multiplier;
        double off_step  = atr * ATR_Step_Multiplier;
        double trigger = (positionType == POSITION_TYPE_BUY) ? entryPrice + off_start : entryPrice - off_start;
        bool hit = (positionType == POSITION_TYPE_BUY) ? (current >= trigger) : (current <= trigger);
        if (hit) {
          double newsl = (positionType == POSITION_TYPE_BUY) ? current - off_step : current + off_step;
          double curSL = PositionGetDouble(POSITION_SL);
          bool update = (positionType == POSITION_TYPE_BUY && newsl > curSL) || (positionType == POSITION_TYPE_SELL && newsl < curSL);
          if (update) { trade.PositionModify(_Symbol, newsl, PositionGetDouble(POSITION_TP)); LogChart("ATR Trailing SL2 → " + DoubleToString(newsl, _Digits), current, clrViolet); }
        }
      }
    }
    
    // Custom Trailing Profit TP1
    if (SelectedTakeProfit1 == Custom_Trailing_Profit) {
      double off_start, off_step;
      if(TakeProfitType1 == TP_PIPS) { off_start = TrailingTPStart1 * pip; off_step = TrailingTPStep1 * pip; }
      else { off_start = entryPrice * TrailingTPStart1 / 100.0; off_step = entryPrice * TrailingTPStep1 / 100.0; }
      double trigger = (positionType == POSITION_TYPE_BUY) ? entryPrice + off_start : entryPrice - off_start;
      bool hit = (positionType == POSITION_TYPE_BUY) ? (current >= trigger) : (current <= trigger);
      if (hit) {
        double newtp = (positionType == POSITION_TYPE_BUY) ? current - off_step : current + off_step;
        double curTP = PositionGetDouble(POSITION_TP);
        bool update = (positionType == POSITION_TYPE_BUY && newtp < curTP) || (positionType == POSITION_TYPE_SELL && newtp > curTP);
        if (update) { trade.PositionModify(_Symbol, PositionGetDouble(POSITION_SL), newtp); LogChart("Custom Trailing Profit TP1 → " + DoubleToString(newtp, _Digits), current, clrGold); }
      }
    }
    
    // Custom Trailing Profit TP2
    if (SelectedTakeProfit2 == Custom_Trailing_Profit) {
      double off_start, off_step;
      if(TakeProfitType2 == TP_PIPS) { off_start = TrailingTPStart2 * pip; off_step = TrailingTPStep2 * pip; }
      else { off_start = entryPrice * TrailingTPStart2 / 100.0; off_step = entryPrice * TrailingTPStep2 / 100.0; }
      double trigger = (positionType == POSITION_TYPE_BUY) ? entryPrice + off_start : entryPrice - off_start;
      bool hit = (positionType == POSITION_TYPE_BUY) ? (current >= trigger) : (current <= trigger);
      if (hit) {
        double newtp = (positionType == POSITION_TYPE_BUY) ? current - off_step : current + off_step;
        double curTP = PositionGetDouble(POSITION_TP);
        bool update = (positionType == POSITION_TYPE_BUY && newtp < curTP) || (positionType == POSITION_TYPE_SELL && newtp > curTP);
        if (update) { trade.PositionModify(_Symbol, PositionGetDouble(POSITION_SL), newtp); LogChart("Custom Trailing Profit TP2 → " + DoubleToString(newtp, _Digits), current, clrGold); }
      }
    }

    // Strategy-based optional exits
    bool isBuy = (positionType == POSITION_TYPE_BUY);
    string usedStrat=""; string pc = PositionGetString(POSITION_COMMENT);
    int p=StringFind(pc,"STRAT=");
    if(p>=0){
      usedStrat = StringSubstr(pc, p+6);
      int sp = StringFind(usedStrat, " ");
      int rp = StringFind(usedStrat, ")");
      int cut = sp; if(cut<0 || (rp>=0 && rp<cut)) cut = rp; if(cut>0) usedStrat = StringSubstr(usedStrat, 0, cut);
      StringTrimLeft(usedStrat); StringTrimRight(usedStrat);
    }
    bool shouldExit=false;
    if(usedStrat=="RSI2Cross"){ bool fromS1 = PosFromS1(pc); int hf = fromS1 ? rsi_fast1 : rsi_fast2; int hs = fromS1 ? rsi_slow1 : rsi_slow2; shouldExit = Strategy_RSI2Cross_ShouldExit(isBuy,hf,hs); }
    else if(usedStrat=="RSICrossHeikinV2"){ bool fromS1 = PosFromS1(pc); int rsi_h = fromS1 ? rsi_handle1 : rsi_handle2; int ha_h  = fromS1 ? ha_handle1 : ha_handle2; ENUM_TIMEFRAMES tf = fromS1 ? Strategy1Timeframe : Strategy2Timeframe; shouldExit = Exit_RH_V2(isBuy, fromS1?strat1flags:strat2flags, rsi_h, ha_h, tf); }
    else if(usedStrat=="HeikinComplete"){ bool fromS1 = PosFromS1(pc); int ha_h  = fromS1 ? ha_handle1 : ha_handle2; ENUM_TIMEFRAMES tf = fromS1 ? Strategy1Timeframe : Strategy2Timeframe; shouldExit = Strategy_HeikinComplete_ShouldExit(isBuy, ha_h, tf); }
    else if(usedStrat=="HeikinSAR"){ bool fromS1 = PosFromS1(pc); int hps = fromS1 ? psar_strat1 : psar_strat2; ENUM_TIMEFRAMES tf = fromS1 ? Strategy1Timeframe : Strategy2Timeframe; int sh = (HeikinSAR_UseClosedBar_Exit ? 1 : 0); if(hps!=INVALID_HANDLE){ double buf[]; ArraySetAsSeries(buf,true); if(CopyBuffer(hps,0,sh,1,buf)>0){ double psarVal = buf[0]; double close = iClose(_Symbol, tf, sh); shouldExit = isBuy ? (close < psarVal) : (close > psarVal); } } }
    if(shouldExit && UseStrategyExits){ trade.PositionClose(_Symbol); ZeroMemory(strat1flags); ZeroMemory(strat2flags); }
  }
}

void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
  if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
  ulong deal = trans.deal;
  int entry = (int)HistoryDealGetInteger(deal, DEAL_ENTRY);
  if(entry != DEAL_ENTRY_OUT) return;

  long mg = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
  int dirType = (int)HistoryDealGetInteger(deal, DEAL_TYPE); // SELL deal closes BUY
  bool wasBuy = (dirType==DEAL_TYPE_SELL);
  int reason = (int)HistoryDealGetInteger(deal, DEAL_REASON);
  double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);

  bool fromS1 = (mg == Magic_S1);
  bool fromS2 = (mg == Magic_S2);
  if(!fromS1 && !fromS2){
    string dc = HistoryDealGetString(deal, DEAL_COMMENT);
    if(StringFind(dc," S1")>=0) fromS1 = true;
    else if(StringFind(dc," S2")>=0) fromS2 = true;
    else {
      if(request.magic == Magic_S1) fromS1 = true;
      if(request.magic == Magic_S2) fromS2 = true;
    }
  }

  bool isStopExit = (reason == DEAL_REASON_SL || reason == DEAL_REASON_SO);
  if(LossLockoutTrades>0 && isStopExit){
    if(fromS1){
      if(wasBuy) skipBuyCountS1 = LossLockoutTrades;
      else       skipSellCountS1 = LossLockoutTrades;
    } else if(fromS2){
      if(wasBuy) skipBuyCountS2 = LossLockoutTrades;
      else       skipSellCountS2 = LossLockoutTrades;
    }
    if(EnableChartLogs) Print("LockoutTrades set after stop. fromS1=",fromS1,", wasBuy=",wasBuy);
  }

  if(profit > 0.0){
    if(fromS1){ if(wasBuy) skipBuyCountS1 = 0; else skipSellCountS1 = 0; }
    else if(fromS2){ if(wasBuy) skipBuyCountS2 = 0; else skipSellCountS2 = 0; }
  }

  if(LossLockoutBars>0 && isStopExit){
    bool forS1 = fromS1;
    ENUM_TIMEFRAMES tf = forS1 ? Strategy1Timeframe : Strategy2Timeframe;
    int curBar = Bars(_Symbol, tf);
    int until = curBar + LossLockoutBars;
    if(forS1){
      if(wasBuy) lockoutBuyUntilBarS1 = until; else lockoutSellUntilBarS1 = until;
    } else {
      if(wasBuy) lockoutBuyUntilBarS2 = until; else lockoutSellUntilBarS2 = until;
    }
    if(EnableChartLogs) Print("LockoutBars set to ",until," for ",(forS1?"S1":"S2")," wasBuy=",wasBuy);
  }
}