#property copyright   "RSIHeikin EA"
#property version     "0.1.0"
#property strict

#include <Trade/Trade.mqh>

// ========================= ENUMS =========================
enum UpdateMode { UM_CLOSE_ONLY = 0, UM_ON_TICK };
enum EvalMode   { EM_CLOSED_BAR = 0, EM_CURRENT_VALUE };
enum FilterType {
  FT_NONE = 0,
  FT_EMA_TREND,
  FT_EMA_CROSS,
  FT_RSI_X2_CROSS,
  FT_RSI_BOUNDS_CROSS,
  FT_ADX_TREND,
  FT_PSAR_TREND,
  FT_HEIKIN_FILTER,
  FT_ATR_GATE,
  FT_VOLUME
};
enum StopSetType { SS_NONE=0, SS_FIXED, SS_TRAILING, SS_BREAKEVEN, SS_ATR, SS_PSAR, SS_SWING, SS_TIME };
enum UnitMode { UM_PIPS=0, UM_PERCENT };
enum VolumeMode { VM_ABS_THRESHOLD=0, VM_MA_RATIO };
enum ExitFiltersCombine { EFC_ANY=0, EFC_BOTH };
enum ExitDecisionCombine { EDC_ANY=0, EDC_SOFT_OR_FILTERS, EDC_SOFT_AND_FILTERS };
enum MMMode { MM_FIXED_LOT=0, MM_RISK_PERCENT, MM_ATR_NORM, MM_HYBRID };
enum RiskBase { RB_BALANCE=0, RB_EQUITY, RB_FREE_MARGIN };
enum PositionCountScope { PCS_BY_SYMBOL=0, PCS_BY_MAGIC, PCS_GLOBAL };

// ========================= INPUTS =========================
// Core
input ENUM_TIMEFRAMES  Inp_StrategyTF         = PERIOD_M1;
input UpdateMode       Inp_SignalUpdateMode   = UM_CLOSE_ONLY;
input UpdateMode       Inp_MgmtUpdateMode     = UM_CLOSE_ONLY;
input bool             Inp_PlaceInitialSLTP   = true;     // set SL/TP server-side at entry
input long             Inp_MagicNumber        = 20251015;
input string           Inp_OrderComment       = "RSIHeikinEA";

// Position limits
input int              Inp_MaxOpenPositions   = 4;        // global limit
input PositionCountScope Inp_PosCountScope    = PCS_GLOBAL;
input bool             Inp_CountPendingOrders = true;

// Gates / generic protections
input bool             Inp_UseMaxSpread       = true;
input double           Inp_MaxSpreadPoints    = 250.0;
input double           Inp_SlippagePoints     = 10.0;
input int              Inp_LossLockoutBars    = -1;       // per-direction; -1 off
input double           Inp_PriceImproveATR    = -1.0;     // k*ATR improvement; -1 off
input int              Inp_MaxNCandlesAfterSignal = 8;    // expire RSI setup after N bars

// Money management
input MMMode           Inp_MM_Mode            = MM_FIXED_LOT;
input bool             Inp_UseFixedLot        = true;
input double           Inp_FixedLot           = 0.10;
input bool             Inp_UseRiskPercent     = false;
input double           Inp_RiskPercent        = 1.0;      // per trade
input RiskBase         Inp_RiskBase           = RB_BALANCE;
input bool             Inp_RequireSLForRisk   = true;
input double           Inp_FallbackLotIfNoSL  = 0.05;
input double           Inp_MinLot             = 0.01;
input double           Inp_MaxLot             = 10.0;
input bool             Inp_RiskIncludeCosts   = false;
input double           Inp_CommissionPerLot   = 0.0;
input double           Inp_ExtraSpreadPtsRisk = 0.0;
input int              Inp_ATR_Period_Lot     = 14;       // for ATR_NORM
input double           Inp_DollarPerATR       = 0.0;      // target $ per ATR move
input double           Inp_MinFreeMarginPct   = 5.0;      // block entries if free margin too low

// Time windows (entries only)
input bool             Inp_TW_Enable          = false;
enum TWMode { TW_INCLUDE_ONLY=0, TW_EXCLUDE_ONLY, TW_BOTH };
input TWMode           Inp_TW_Mode            = TW_BOTH;
input int              Inp_TW_Incl1_StartHHMM = 900;   input int Inp_TW_Incl1_EndHHMM = 1700; input int Inp_TW_Incl1_DaysMask = 127;
input int              Inp_TW_Incl2_StartHHMM = 0;     input int Inp_TW_Incl2_EndHHMM = 0;    input int Inp_TW_Incl2_DaysMask = 0;
input int              Inp_TW_Incl3_StartHHMM = 0;     input int Inp_TW_Incl3_EndHHMM = 0;    input int Inp_TW_Incl3_DaysMask = 0;
input int              Inp_TW_Incl4_StartHHMM = 0;     input int Inp_TW_Incl4_EndHHMM = 0;    input int Inp_TW_Incl4_DaysMask = 0;
input int              Inp_TW_Incl5_StartHHMM = 0;     input int Inp_TW_Incl5_EndHHMM = 0;    input int Inp_TW_Incl5_DaysMask = 0;
input int              Inp_TW_Incl6_StartHHMM = 0;     input int Inp_TW_Incl6_EndHHMM = 0;    input int Inp_TW_Incl6_DaysMask = 0;
input int              Inp_TW_Excl1_StartHHMM = 1500;  input int Inp_TW_Excl1_EndHHMM = 1800; input int Inp_TW_Excl1_DaysMask = 127;
input int              Inp_TW_Excl2_StartHHMM = 2000;  input int Inp_TW_Excl2_EndHHMM = 200;  input int Inp_TW_Excl2_DaysMask = 127; // overnight 20:00->02:00
input int              Inp_TW_Excl3_StartHHMM = 0;     input int Inp_TW_Excl3_EndHHMM = 0;    input int Inp_TW_Excl3_DaysMask = 0;
input int              Inp_TW_Excl4_StartHHMM = 0;     input int Inp_TW_Excl4_EndHHMM = 0;    input int Inp_TW_Excl4_DaysMask = 0;
input int              Inp_TW_Excl5_StartHHMM = 0;     input int Inp_TW_Excl5_EndHHMM = 0;    input int Inp_TW_Excl5_DaysMask = 0;
input int              Inp_TW_Excl6_StartHHMM = 0;     input int Inp_TW_Excl6_EndHHMM = 0;    input int Inp_TW_Excl6_DaysMask = 0;
input bool             Inp_SkipOneDay_Enable  = false;
input string           Inp_SkipOneDay_Date    = "2025-11-12"; // YYYY-MM-DD
input bool             Inp_SkipOneDay_CustomHours = false;
input int              Inp_SkipOneDay_StartHHMM   = 0;
input int              Inp_SkipOneDay_EndHHMM     = 0;

// Strategy: RSIHeikin
input int              Inp_RSI_Period         = 14;
input double           Inp_RSI_Low            = 30.0;
input double           Inp_RSI_High           = 70.0;
input ENUM_APPLIED_PRICE Inp_RSI_AppliedPrice = PRICE_CLOSE;
input EvalMode         Inp_RSI_CrossEvalMode  = EM_CLOSED_BAR;

input ENUM_TIMEFRAMES  Inp_HeikinSeq_TF       = PERIOD_M1; // default use StrategyTF in init
input EvalMode         Inp_HeikinSeq_EvalMode = EM_CLOSED_BAR;
input int              Inp_N_RequiredHeikin_Buy  = 2;
input int              Inp_N_MaxWaitBars_Buy     = 10;
input int              Inp_N_RequiredHeikin_Sell = 3;
input int              Inp_N_MaxWaitBars_Sell    = 10;
input bool             Inp_RefreshOnNewCross     = true;
input bool             Inp_ResetOnOppositeCross  = true;
input bool             Inp_AllowMultipleEntriesPerSetup = false; // must remain false per spec

// Entry filters (6 slots, AND)
input EvalMode         Inp_EntryFiltersEvalMode = EM_CLOSED_BAR;
input FilterType       Inp_EntryFilter1_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_EntryFilter1_TF = PERIOD_M1; input bool Inp_EntryFilter1_UseClosedBar=true;
input FilterType       Inp_EntryFilter2_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_EntryFilter2_TF = PERIOD_M1; input bool Inp_EntryFilter2_UseClosedBar=true;
input FilterType       Inp_EntryFilter3_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_EntryFilter3_TF = PERIOD_M1; input bool Inp_EntryFilter3_UseClosedBar=true;
input FilterType       Inp_EntryFilter4_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_EntryFilter4_TF = PERIOD_M1; input bool Inp_EntryFilter4_UseClosedBar=true;
input FilterType       Inp_EntryFilter5_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_EntryFilter5_TF = PERIOD_M1; input bool Inp_EntryFilter5_UseClosedBar=true;
input FilterType       Inp_EntryFilter6_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_EntryFilter6_TF = PERIOD_M1; input bool Inp_EntryFilter6_UseClosedBar=true;

// Exit filters: two lists (A & B), each 6 slots AND; combine ANY/BOTH
input EvalMode         Inp_ExitFiltersEvalMode = EM_CLOSED_BAR;
input ExitFiltersCombine Inp_ExitFiltersAB_Combine = EFC_ANY;
// List A
input FilterType       Inp_ExitA_Filter1_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitA_Filter1_TF = PERIOD_M1; input bool Inp_ExitA_Filter1_UseClosedBar=true;
input FilterType       Inp_ExitA_Filter2_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitA_Filter2_TF = PERIOD_M1; input bool Inp_ExitA_Filter2_UseClosedBar=true;
input FilterType       Inp_ExitA_Filter3_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitA_Filter3_TF = PERIOD_M1; input bool Inp_ExitA_Filter3_UseClosedBar=true;
input FilterType       Inp_ExitA_Filter4_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitA_Filter4_TF = PERIOD_M1; input bool Inp_ExitA_Filter4_UseClosedBar=true;
input FilterType       Inp_ExitA_Filter5_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitA_Filter5_TF = PERIOD_M1; input bool Inp_ExitA_Filter5_UseClosedBar=true;
input FilterType       Inp_ExitA_Filter6_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitA_Filter6_TF = PERIOD_M1; input bool Inp_ExitA_Filter6_UseClosedBar=true;
// List B
input FilterType       Inp_ExitB_Filter1_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitB_Filter1_TF = PERIOD_M1; input bool Inp_ExitB_Filter1_UseClosedBar=true;
input FilterType       Inp_ExitB_Filter2_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitB_Filter2_TF = PERIOD_M1; input bool Inp_ExitB_Filter2_UseClosedBar=true;
input FilterType       Inp_ExitB_Filter3_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitB_Filter3_TF = PERIOD_M1; input bool Inp_ExitB_Filter3_UseClosedBar=true;
input FilterType       Inp_ExitB_Filter4_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitB_Filter4_TF = PERIOD_M1; input bool Inp_ExitB_Filter4_UseClosedBar=true;
input FilterType       Inp_ExitB_Filter5_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitB_Filter5_TF = PERIOD_M1; input bool Inp_ExitB_Filter5_UseClosedBar=true;
input FilterType       Inp_ExitB_Filter6_Type = FT_NONE; input ENUM_TIMEFRAMES Inp_ExitB_Filter6_TF = PERIOD_M1; input bool Inp_ExitB_Filter6_UseClosedBar=true;

// Exit decision combination
input ExitDecisionCombine Inp_ExitDecisionMode = EDC_ANY;

// Stop sets (two independent)
input StopSetType      Inp_StopSet1_Type = SS_ATR;
input UnitMode         Inp_StopSet1_Mode = UM_PIPS; // for FIXED/TRAILING/BREAKEVEN
input ENUM_TIMEFRAMES  Inp_StopSet1_TF   = PERIOD_M1;
input bool             Inp_StopSet1_UseClosedBar = true;
input double           Inp_StopSet1_Value = 300.0; // FIXED
input double           Inp_StopSet1_TrailStart = 50.0; input double Inp_StopSet1_TrailStep = 20.0; // TRAILING
input double           Inp_StopSet1_BETrigger = 50.0; input double Inp_StopSet1_BEOffset = 5.0;  // BREAKEVEN
input int              Inp_StopSet1_ATR_Period = 14; input double Inp_StopSet1_ATR_Mult = 2.0; input bool Inp_StopSet1_ATR_Recalc = false;
input double           Inp_StopSet1_PSAR_Step = 0.02; input double Inp_StopSet1_PSAR_Max = 0.2;
input int              Inp_StopSet1_Swing_Lookback = 5; input double Inp_StopSet1_Swing_OffsetPips = 5.0;
input int              Inp_StopSet1_Time_MaxBars = 0; input int Inp_StopSet1_Time_MaxMinutes = 0;

input StopSetType      Inp_StopSet2_Type = SS_NONE;
input UnitMode         Inp_StopSet2_Mode = UM_PIPS;
input ENUM_TIMEFRAMES  Inp_StopSet2_TF   = PERIOD_M1;
input bool             Inp_StopSet2_UseClosedBar = true;
input double           Inp_StopSet2_Value = 300.0;
input double           Inp_StopSet2_TrailStart = 50.0; input double Inp_StopSet2_TrailStep = 20.0;
input double           Inp_StopSet2_BETrigger = 50.0; input double Inp_StopSet2_BEOffset = 5.0;
input int              Inp_StopSet2_ATR_Period = 14; input double Inp_StopSet2_ATR_Mult = 2.0; input bool Inp_StopSet2_ATR_Recalc = false;
input double           Inp_StopSet2_PSAR_Step = 0.02; input double Inp_StopSet2_PSAR_Max = 0.2;
input int              Inp_StopSet2_Swing_Lookback = 5; input double Inp_StopSet2_Swing_OffsetPips = 5.0;
input int              Inp_StopSet2_Time_MaxBars = 0; input int Inp_StopSet2_Time_MaxMinutes = 0;

// Global parameters for filters (shared across slots to keep inputs manageable)
// EMA
input int              Inp_EMA_Period_Default = 50; input int Inp_EMA_Mode_Default = MODE_EMA; input int Inp_EMA_Price_Default = PRICE_CLOSE;
input int              Inp_EMA_Fast_Default = 9; input int Inp_EMA_Slow_Default = 21;
// RSI X2
input int              Inp_RSI_Fast_Default = 5; input int Inp_RSI_Slow_Default = 25;
// ADX
input int              Inp_ADX_Period_Default = 14; input double Inp_ADX_Threshold_Default = 20.0; input int Inp_ADX_PlusDI_Index_Default = 1; input int Inp_ADX_MinusDI_Index_Default = 2;
// PSAR
input double           Inp_PSAR_Step_Default = 0.02; input double Inp_PSAR_Max_Default = 0.2;
// ATR Gate
input int              Inp_ATR_Period_Default = 14; input double Inp_ATR_Threshold_Default = 0.0007;
// Volume
input VolumeMode       Inp_VolumeMode_Default = VM_ABS_THRESHOLD; input double Inp_VolumeThreshold_Default = 1000.0; input int Inp_VolumeMAPeriod_Default = 20; input double Inp_VolumeRatio_Default = 1.3;

// ========================= STATE =========================
CTrade trade;

datetime g_lastBarTime[256]; // per TF new-bar tracking
// rsiheikin state
bool g_waitBuy=false, g_waitSell=false;
int  g_crossBarBuy=-1, g_crossBarSell=-1; // bar index in StrategyTF when RSI cross detected
int  g_heikinCountBuy=0, g_heikinCountSell=0;

// lockout & improvement
int  g_lockBuyUntilBar=-1, g_lockSellUntilBar=-1;
double g_lastEntryBuy=0.0, g_lastEntrySell=0.0;

// ========================= UTILS =========================
double PipSize(){ return (_Digits==3||_Digits==5)? 10.0*_Point : _Point; }
int TFIndex(ENUM_TIMEFRAMES tf){ return ((int)tf)&255; }
bool NewBarTF(ENUM_TIMEFRAMES tf){ int idx=TFIndex(tf); datetime t=iTime(_Symbol,tf,0); if(t==0) return false; if(t!=g_lastBarTime[idx]){ g_lastBarTime[idx]=t; return true; } return false; }
int HHMMToMinutes(int hhmm){ int hh=hhmm/100; int mm=hhmm%100; return hh*60+mm; }
bool TimeInWindow(int stHHMM,int enHHMM,int curMinutes){ int s=HHMMToMinutes(stHHMM); int e=HHMMToMinutes(enHHMM); if(s==0 && e==0) return false; if(e>=s) return (curMinutes>=s && curMinutes<=e); return (curMinutes>=s || curMinutes<=e); }
bool DayMaskMatch(int mask,int wday){ if(mask==0) return false; int bit=1<<wday; return (mask & bit)!=0; }
bool InTimeWindowEntries(){ if(!Inp_TW_Enable) return true; MqlDateTime tm; TimeToStruct(TimeCurrent(),tm); int wday=tm.day_of_week; int cur=tm.hour*60+tm.min;
  // includes
  bool inIncl=false; if(Inp_TW_Mode!=TW_EXCLUDE_ONLY){
    if(DayMaskMatch(Inp_TW_Incl1_DaysMask,wday) && TimeInWindow(Inp_TW_Incl1_StartHHMM,Inp_TW_Incl1_EndHHMM,cur)) inIncl=true;
    if(DayMaskMatch(Inp_TW_Incl2_DaysMask,wday) && TimeInWindow(Inp_TW_Incl2_StartHHMM,Inp_TW_Incl2_EndHHMM,cur)) inIncl=true;
    if(DayMaskMatch(Inp_TW_Incl3_DaysMask,wday) && TimeInWindow(Inp_TW_Incl3_StartHHMM,Inp_TW_Incl3_EndHHMM,cur)) inIncl=true;
    if(DayMaskMatch(Inp_TW_Incl4_DaysMask,wday) && TimeInWindow(Inp_TW_Incl4_StartHHMM,Inp_TW_Incl4_EndHHMM,cur)) inIncl=true;
    if(DayMaskMatch(Inp_TW_Incl5_DaysMask,wday) && TimeInWindow(Inp_TW_Incl5_StartHHMM,Inp_TW_Incl5_EndHHMM,cur)) inIncl=true;
    if(DayMaskMatch(Inp_TW_Incl6_DaysMask,wday) && TimeInWindow(Inp_TW_Incl6_StartHHMM,Inp_TW_Incl6_EndHHMM,cur)) inIncl=true;
  } else inIncl=true; // include not used
  // excludes
  bool inExcl=false; if(Inp_TW_Mode!=TW_INCLUDE_ONLY){
    if(DayMaskMatch(Inp_TW_Excl1_DaysMask,wday) && TimeInWindow(Inp_TW_Excl1_StartHHMM,Inp_TW_Excl1_EndHHMM,cur)) inExcl=true;
    if(DayMaskMatch(Inp_TW_Excl2_DaysMask,wday) && TimeInWindow(Inp_TW_Excl2_StartHHMM,Inp_TW_Excl2_EndHHMM,cur)) inExcl=true;
    if(DayMaskMatch(Inp_TW_Excl3_DaysMask,wday) && TimeInWindow(Inp_TW_Excl3_StartHHMM,Inp_TW_Excl3_EndHHMM,cur)) inExcl=true;
    if(DayMaskMatch(Inp_TW_Excl4_DaysMask,wday) && TimeInWindow(Inp_TW_Excl4_StartHHMM,Inp_TW_Excl4_EndHHMM,cur)) inExcl=true;
    if(DayMaskMatch(Inp_TW_Excl5_DaysMask,wday) && TimeInWindow(Inp_TW_Excl5_StartHHMM,Inp_TW_Excl5_EndHHMM,cur)) inExcl=true;
    if(DayMaskMatch(Inp_TW_Excl6_DaysMask,wday) && TimeInWindow(Inp_TW_Excl6_StartHHMM,Inp_TW_Excl6_EndHHMM,cur)) inExcl=true;
  }
  // skip one day
  if(Inp_SkipOneDay_Enable){ string d=TimeToString(TimeCurrent(),TIME_DATE); if(d==Inp_SkipOneDay_Date){ if(Inp_SkipOneDay_CustomHours){ if(TimeInWindow(Inp_SkipOneDay_StartHHMM,Inp_SkipOneDay_EndHHMM,cur)) return false; } else return false; } }
  bool allowed = inIncl && !inExcl; return allowed; }

int CountPositionsAndPendings(){ int count=0; // positions
  for(int i=0;i<PositionsTotal();++i){ if(PositionSelectByIndex(i)){ count++; } }
  if(Inp_CountPendingOrders){ int ot=OrdersTotal(); for(int j=0;j<ot;++j){ ulong ticket=OrderGetTicket(j); if(ticket==0) continue; if(OrderSelect(ticket)){ ENUM_ORDER_TYPE typ=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE); if(typ==ORDER_TYPE_BUY_LIMIT || typ==ORDER_TYPE_SELL_LIMIT || typ==ORDER_TYPE_BUY_STOP || typ==ORDER_TYPE_SELL_STOP || typ==ORDER_TYPE_BUY_STOP_LIMIT || typ==ORDER_TYPE_SELL_STOP_LIMIT) count++; } } }
  return count; }

// ========================= HEIKIN-ASHI INTERNAL =========================
bool HeikinBull(ENUM_TIMEFRAMES tf,int shift){ // compute HA open/close recursively
  // We compute haClose = avg( O,H,L,C ); haOpen = avg(prev_haOpen, prev_haClose)
  // For shift -> need prev (shift+1)
  double o=iOpen(_Symbol,tf,shift), h=iHigh(_Symbol,tf,shift), l=iLow(_Symbol,tf,shift), c=iClose(_Symbol,tf,shift);
  double haClose=(o+h+l+c)/4.0;
  // prev
  double op=iOpen(_Symbol,tf,shift+1), hp=iHigh(_Symbol,tf,shift+1), lp=iLow(_Symbol,tf,shift+1), cp=iClose(_Symbol,tf,shift+1);
  double haClosePrev=(op+hp+lp+cp)/4.0;
  double haOpenPrev=(op+cp)/2.0; // initialization for prev using raw O,C approx if deeper history missing
  // refine a bit further back
  double opp=iOpen(_Symbol,tf,shift+2), cpp=iClose(_Symbol,tf,shift+2);
  double haOpenPrevPrev=(opp+cpp)/2.0;
  haOpenPrev=(haOpenPrev+haOpenPrevPrev)/2.0;
  double haOpen=(haOpenPrev+haClosePrev)/2.0;
  return (haClose>haOpen);
}

bool HeikinBear(ENUM_TIMEFRAMES tf,int shift){ return !HeikinBull(tf,shift); }

// ========================= FILTERS EVAL (using global defaults) =========================
bool GetClose(ENUM_TIMEFRAMES tf,int shift,double &out){ out=iClose(_Symbol,tf,shift); return (out!=0.0); }

bool FilterPass(FilterType type,bool forBuy, ENUM_TIMEFRAMES tf, bool useClosedBar){ int sh = useClosedBar? 1:0; switch(type){
  case FT_NONE: return true;
  case FT_EMA_TREND:{ int per=Inp_EMA_Period_Default; int mode=Inp_EMA_Mode_Default; int price=Inp_EMA_Price_Default; int h=iMA(_Symbol,tf,per,0,mode,price); double ema[1]; ArraySetAsSeries(ema,true); if(CopyBuffer(h,0,sh,1,ema)<1) return false; double cl=iClose(_Symbol,tf,sh); return forBuy? (cl>ema[0]) : (cl<ema[0]); }
  case FT_EMA_CROSS:{ int f=Inp_EMA_Fast_Default, s=Inp_EMA_Slow_Default; int mode=Inp_EMA_Mode_Default; int price=Inp_EMA_Price_Default; int hf=iMA(_Symbol,tf,f,0,mode,price); int hs=iMA(_Symbol,tf,s,0,mode,price); double af[2], as[2]; ArraySetAsSeries(af,true); ArraySetAsSeries(as,true); if(CopyBuffer(hf,0,sh,2,af)<2) return false; if(CopyBuffer(hs,0,sh,2,as)<2) return false; bool up   =(af[1]<=as[1] && af[0]>as[0]); bool down =(af[1]>=as[1] && af[0]<as[0]); return forBuy? up:down; }
  case FT_RSI_X2_CROSS:{ int rf=Inp_RSI_Fast_Default, rs=Inp_RSI_Slow_Default; int hf=iRSI(_Symbol,tf,rf,Inp_RSI_AppliedPrice); int hs=iRSI(_Symbol,tf,rs,Inp_RSI_AppliedPrice); double af[2],as2[2]; ArraySetAsSeries(af,true); ArraySetAsSeries(as2,true); if(CopyBuffer(hf,0,sh,2,af)<2) return false; if(CopyBuffer(hs,0,sh,2,as2)<2) return false; bool up=(af[1]<=as2[1] && af[0]>as2[0]); bool down=(af[1]>=as2[1] && af[0]<as2[0]); return forBuy? up:down; }
  case FT_RSI_BOUNDS_CROSS:{ int hr=iRSI(_Symbol,tf,Inp_RSI_Period,Inp_RSI_AppliedPrice); double r[2]; ArraySetAsSeries(r,true); if(CopyBuffer(hr,0,sh,2,r)<2) return false; bool buy=(r[1]<Inp_RSI_Low && r[0]>=Inp_RSI_Low); bool sell=(r[1]>Inp_RSI_High && r[0]<=Inp_RSI_High); return forBuy? buy:sell; }
  case FT_ADX_TREND:{ int ha=iADX(_Symbol,tf,Inp_ADX_Period_Default); double adx[1],pdi[1],mdi[1]; ArraySetAsSeries(adx,true); ArraySetAsSeries(pdi,true); ArraySetAsSeries(mdi,true); if(CopyBuffer(ha,Inp_ADX_PlusDI_Index_Default-1,sh,1,adx)<1){} // keep for index alignment
    if(CopyBuffer(ha,0,sh,1,adx)<1) return false; if(CopyBuffer(ha,Inp_ADX_PlusDI_Index_Default,sh,1,pdi)<1) return false; if(CopyBuffer(ha,Inp_ADX_MinusDI_Index_Default,sh,1,mdi)<1) return false; if(adx[0]<Inp_ADX_Threshold_Default) return false; return forBuy? (pdi[0]>mdi[0]) : (mdi[0]>pdi[0]); }
  case FT_PSAR_TREND:{ int h=iSAR(_Symbol,tf,Inp_PSAR_Step_Default,Inp_PSAR_Max_Default); double ps[1]; ArraySetAsSeries(ps,true); if(CopyBuffer(h,0,sh,1,ps)<1) return false; double cl=iClose(_Symbol,tf,sh); return forBuy? (cl>ps[0]) : (cl<ps[0]); }
  case FT_HEIKIN_FILTER:{ bool bull=HeikinBull(tf,sh); return forBuy? bull:(!bull); }
  case FT_ATR_GATE:{ int h=iATR(_Symbol,tf,Inp_ATR_Period_Default); double a[1]; ArraySetAsSeries(a,true); if(CopyBuffer(h,0,sh,1,a)<1) return false; return (a[0]>=Inp_ATR_Threshold_Default); }
  case FT_VOLUME:{
    double vol = (double)iVolume(_Symbol,tf, (useClosedBar?1:0) );
    if(Inp_VolumeMode_Default==VM_ABS_THRESHOLD){ return (vol>=Inp_VolumeThreshold_Default); }
    else { // MA_RATIO
      double sma=0.0; int n=Inp_VolumeMAPeriod_Default; int got=0; for(int i=(useClosedBar?1:0); i<(useClosedBar?1:0)+n; ++i){ double vi = (double)iVolume(_Symbol,tf,i); if(vi<=0.0) break; sma+=vi; got++; }
      if(got==0) return false; sma/=got; return (sma>0.0 && vol >= Inp_VolumeRatio_Default * sma);
    }
  }
  return true; }

bool EvalFiltersAND(bool forBuy, EvalMode listMode,
  FilterType t1,ENUM_TIMEFRAMES tf1,bool u1,
  FilterType t2,ENUM_TIMEFRAMES tf2,bool u2,
  FilterType t3,ENUM_TIMEFRAMES tf3,bool u3,
  FilterType t4,ENUM_TIMEFRAMES tf4,bool u4,
  FilterType t5,ENUM_TIMEFRAMES tf5,bool u5,
  FilterType t6,ENUM_TIMEFRAMES tf6,bool u6){
  bool useSh1 = (listMode==EM_CLOSED_BAR);
  if(!FilterPass(t1,forBuy,tf1, u1 && useSh1)) return false;
  if(!FilterPass(t2,forBuy,tf2, u2 && useSh1)) return false;
  if(!FilterPass(t3,forBuy,tf3, u3 && useSh1)) return false;
  if(!FilterPass(t4,forBuy,tf4, u4 && useSh1)) return false;
  if(!FilterPass(t5,forBuy,tf5, u5 && useSh1)) return false;
  if(!FilterPass(t6,forBuy,tf6, u6 && useSh1)) return false;
  return true;
}

// ========================= RSI CROSS HELPERS =========================
bool RSICrossUpThreshold(ENUM_TIMEFRAMES tf, EvalMode em, double thr){ int sh = (em==EM_CLOSED_BAR)?1:0; int hp=iRSI(_Symbol,tf,Inp_RSI_Period,Inp_RSI_AppliedPrice); double r[2]; ArraySetAsSeries(r,true); if(CopyBuffer(hp,0,sh,2,r)<2) return false; return (r[1]<thr && r[0]>=thr); }
bool RSICrossDownThreshold(ENUM_TIMEFRAMES tf, EvalMode em, double thr){ int sh = (em==EM_CLOSED_BAR)?1:0; int hp=iRSI(_Symbol,tf,Inp_RSI_Period,Inp_RSI_AppliedPrice); double r[2]; ArraySetAsSeries(r,true); if(CopyBuffer(hp,0,sh,2,r)<2) return false; return (r[1]>thr && r[0]<=thr); }

// ========================= STOPS =========================
void ComputeFixedSLTP(bool isBuy,double entryPrice, UnitMode mode, double val, double &sl, double &tp){ double points=0; if(mode==UM_PIPS) points = val*PipSize()/_Point; else points = (val/100.0)*entryPrice/_Point; if(points>0){ sl = isBuy? entryPrice - points*_Point : entryPrice + points*_Point; } tp=0.0; }

double ComputeATRPoints(ENUM_TIMEFRAMES tf,int period,double mult){ int h=iATR(_Symbol,tf,period); double a[1]; ArraySetAsSeries(a,true); if(CopyBuffer(h,0,1,1,a)<1) return 0.0; return mult*(a[0]/_Point); }

void ComputeStopSetSL(bool isBuy, StopSetType type, UnitMode mode, ENUM_TIMEFRAMES tf, bool useClosedBar,
  // FIXED
  double value,
  // TRAIL
  double trailStart,double trailStep,
  // BE
  double beTrigger,double beOffset,
  // ATR
  int atrPeriod,double atrMult,bool atrRecalc,
  // PSAR
  double psarStep,double psarMax,
  // SWING
  int swingLookback,double swingOffsetPips,
  // TIME
  int timeMaxBars,int timeMaxMinutes,
  // inputs
  double entryPrice, datetime entryTime, double &slOut){
  slOut=0.0; int sh=(useClosedBar?1:0);
  switch(type){
    case SS_NONE: break;
    case SS_FIXED:{ double points=(mode==UM_PIPS)? value*PipSize()/_Point : (value/100.0)*entryPrice/_Point; if(points>0) slOut=isBuy? entryPrice - points*_Point : entryPrice + points*_Point; break; }
    case SS_ATR:{ double pts=ComputeATRPoints(tf,atrPeriod,atrMult); if(pts>0) slOut=isBuy? entryPrice - pts*_Point : entryPrice + pts*_Point; break; }
    case SS_PSAR:{ int h=iSAR(_Symbol,tf,psarStep,psarMax); double ps[1]; ArraySetAsSeries(ps,true); if(CopyBuffer(h,0,sh,1,ps)>0){ slOut = ps[0]; } break; }
    case SS_SWING:{ int lb=swingLookback; if(lb>0){
        if(isBuy){ double minLow=DBL_MAX; for(int i=(useClosedBar?1:0); i<(useClosedBar?1:0)+lb; ++i){ double lv=iLow(_Symbol,tf,i); if(lv==0.0) break; if(lv<minLow) minLow=lv; } if(minLow<DBL_MAX) slOut = minLow - swingOffsetPips*PipSize(); }
        else { double maxHigh=-DBL_MAX; for(int i=(useClosedBar?1:0); i<(useClosedBar?1:0)+lb; ++i){ double hv=iHigh(_Symbol,tf,i); if(hv==0.0) break; if(hv>maxHigh) maxHigh=hv; } if(maxHigh>-DBL_MAX) slOut = maxHigh + swingOffsetPips*PipSize(); }
      } break; }
    case SS_BREAKEVEN: // handled in management (dynamic)
    case SS_TRAILING:  // handled in management (dynamic)
    case SS_TIME:      // handled in management
      break;
  }
}

// ========================= MM =========================
double CalcLotsByRisk(double slPoints){ // slPoints in points
  if(Inp_UseFixedLot || Inp_MM_Mode==MM_FIXED_LOT || !Inp_UseRiskPercent){ double lot=Inp_FixedLot; lot=MathMax(lot,Inp_MinLot); lot=MathMin(lot,Inp_MaxLot); return lot; }
  if(Inp_RequireSLForRisk && slPoints<=0.0){ double lot=Inp_FallbackLotIfNoSL; lot=MathMax(lot,Inp_MinLot); lot=MathMin(lot,Inp_MaxLot); return lot; }
  double base=0; if(Inp_RiskBase==RB_BALANCE) base=AccountInfoDouble(ACCOUNT_BALANCE); else if(Inp_RiskBase==RB_EQUITY) base=AccountInfoDouble(ACCOUNT_EQUITY); else base=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  double riskValue = base*(Inp_RiskPercent/100.0);
  double tickVal = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
  double tickSz  = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
  if(tickVal<=0 || tickSz<=0) return Inp_FixedLot;
  double pointValuePerLot = (tickVal/tickSz)*_Point; // $ per point per lot
  if(Inp_RiskIncludeCosts){ riskValue = MathMax(0.0, riskValue - Inp_CommissionPerLot - (Inp_ExtraSpreadPtsRisk*_Point*pointValuePerLot)); }
  double lots = riskValue / (slPoints*pointValuePerLot);
  lots = MathMax(lots,Inp_MinLot); lots=MathMin(lots,Inp_MaxLot); return lots; }

// ========================= ENTRY LOGIC =========================
bool CanOpenMore(){ if(Inp_PosCountScope!=PCS_GLOBAL){ /* simplified: use global */ } return CountPositionsAndPendings() < Inp_MaxOpenPositions; }

bool EntryFiltersPass(bool forBuy){ return EvalFiltersAND(forBuy, Inp_EntryFiltersEvalMode,
  Inp_EntryFilter1_Type,Inp_EntryFilter1_TF,Inp_EntryFilter1_UseClosedBar,
  Inp_EntryFilter2_Type,Inp_EntryFilter2_TF,Inp_EntryFilter2_UseClosedBar,
  Inp_EntryFilter3_Type,Inp_EntryFilter3_TF,Inp_EntryFilter3_UseClosedBar,
  Inp_EntryFilter4_Type,Inp_EntryFilter4_TF,Inp_EntryFilter4_UseClosedBar,
  Inp_EntryFilter5_Type,Inp_EntryFilter5_TF,Inp_EntryFilter5_UseClosedBar,
  Inp_EntryFilter6_Type,Inp_EntryFilter6_TF,Inp_EntryFilter6_UseClosedBar ); }

bool ExitFiltersListPass(bool forBuy,
  FilterType t1,ENUM_TIMEFRAMES tf1,bool u1,
  FilterType t2,ENUM_TIMEFRAMES tf2,bool u2,
  FilterType t3,ENUM_TIMEFRAMES tf3,bool u3,
  FilterType t4,ENUM_TIMEFRAMES tf4,bool u4,
  FilterType t5,ENUM_TIMEFRAMES tf5,bool u5,
  FilterType t6,ENUM_TIMEFRAMES tf6,bool u6){
  return EvalFiltersAND(!forBuy, Inp_ExitFiltersEvalMode, // inverse direction logic for exit
    t1,tf1,u1, t2,tf2,u2, t3,tf3,u3, t4,tf4,u4, t5,tf5,u5, t6,tf6,u6);
}

bool ExitFiltersPass(bool forBuy){ bool A = ExitFiltersListPass(forBuy,
  Inp_ExitA_Filter1_Type,Inp_ExitA_Filter1_TF,Inp_ExitA_Filter1_UseClosedBar,
  Inp_ExitA_Filter2_Type,Inp_ExitA_Filter2_TF,Inp_ExitA_Filter2_UseClosedBar,
  Inp_ExitA_Filter3_Type,Inp_ExitA_Filter3_TF,Inp_ExitA_Filter3_UseClosedBar,
  Inp_ExitA_Filter4_Type,Inp_ExitA_Filter4_TF,Inp_ExitA_Filter4_UseClosedBar,
  Inp_ExitA_Filter5_Type,Inp_ExitA_Filter5_TF,Inp_ExitA_Filter5_UseClosedBar,
  Inp_ExitA_Filter6_Type,Inp_ExitA_Filter6_TF,Inp_ExitA_Filter6_UseClosedBar);
  bool B = ExitFiltersListPass(forBuy,
  Inp_ExitB_Filter1_Type,Inp_ExitB_Filter1_TF,Inp_ExitB_Filter1_UseClosedBar,
  Inp_ExitB_Filter2_Type,Inp_ExitB_Filter2_TF,Inp_ExitB_Filter2_UseClosedBar,
  Inp_ExitB_Filter3_Type,Inp_ExitB_Filter3_TF,Inp_ExitB_Filter3_UseClosedBar,
  Inp_ExitB_Filter4_Type,Inp_ExitB_Filter4_TF,Inp_ExitB_Filter4_UseClosedBar,
  Inp_ExitB_Filter5_Type,Inp_ExitB_Filter5_TF,Inp_ExitB_Filter5_UseClosedBar,
  Inp_ExitB_Filter6_Type,Inp_ExitB_Filter6_TF,Inp_ExitB_Filter6_UseClosedBar);
  return (Inp_ExitFiltersAB_Combine==EFC_ANY)? (A||B) : (A&&B);
}

bool SpreadOK(){ if(!Inp_UseMaxSpread) return true; double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double spr=(ask-bid)/_Point; return (spr<=Inp_MaxSpreadPoints); }

void ResetBuySetup(){ g_waitBuy=false; g_crossBarBuy=-1; g_heikinCountBuy=0; }
void ResetSellSetup(){ g_waitSell=false; g_crossBarSell=-1; g_heikinCountSell=0; }

void TryStartSetups(){ if(RSICrossUpThreshold(Inp_StrategyTF,Inp_RSI_CrossEvalMode,Inp_RSI_Low)){
    g_waitBuy=true; g_heikinCountBuy=0; g_crossBarBuy=Bars(_Symbol,Inp_StrategyTF);
    if(Inp_RefreshOnNewCross){ /* already refreshed */ }
  }
  if(RSICrossDownThreshold(Inp_StrategyTF,Inp_RSI_CrossEvalMode,Inp_RSI_High)){
    g_waitSell=true; g_heikinCountSell=0; g_crossBarSell=Bars(_Symbol,Inp_StrategyTF);
  }
  if(Inp_ResetOnOppositeCross){ if(g_waitBuy && RSICrossDownThreshold(Inp_StrategyTF,Inp_RSI_CrossEvalMode,Inp_RSI_High)) ResetBuySetup(); if(g_waitSell && RSICrossUpThreshold(Inp_StrategyTF,Inp_RSI_CrossEvalMode,Inp_RSI_Low)) ResetSellSetup(); }
}

bool HeikinUpdateCount(bool forBuy){ ENUM_TIMEFRAMES tf = Inp_HeikinSeq_TF; int sh = (Inp_HeikinSeq_EvalMode==EM_CLOSED_BAR)?1:0; bool isBull = HeikinBull(tf, sh); if(forBuy){ if(isBull) g_heikinCountBuy++; else g_heikinCountBuy=0; return (g_heikinCountBuy>=Inp_N_RequiredHeikin_Buy); } else { bool isBear = !isBull; if(isBear) g_heikinCountSell++; else g_heikinCountSell=0; return (g_heikinCountSell>=Inp_N_RequiredHeikin_Sell); } }

bool SetupExpired(bool forBuy){ int curBars=Bars(_Symbol,Inp_StrategyTF); if(forBuy){ if(g_crossBarBuy<0) return false; return (curBars > g_crossBarBuy + Inp_N_MaxWaitBars_Buy); } else { if(g_crossBarSell<0) return false; return (curBars > g_crossBarSell + Inp_N_MaxWaitBars_Sell); } }

// ========================= ORDER SENDING =========================
void ComputeInitialSLTP(bool isBuy,double entryPrice,double &sl,double &tp){ sl=0.0; tp=0.0; // StopSet1 & StopSet2 -> choose closest to price (max for buy, min for sell)
  double sl1=0.0, sl2=0.0; datetime now=TimeCurrent();
  ComputeStopSetSL(isBuy, Inp_StopSet1_Type, Inp_StopSet1_Mode, Inp_StopSet1_TF, Inp_StopSet1_UseClosedBar,
    Inp_StopSet1_Value, Inp_StopSet1_TrailStart, Inp_StopSet1_TrailStep, Inp_StopSet1_BETrigger, Inp_StopSet1_BEOffset,
    Inp_StopSet1_ATR_Period, Inp_StopSet1_ATR_Mult, Inp_StopSet1_ATR_Recalc,
    Inp_StopSet1_PSAR_Step, Inp_StopSet1_PSAR_Max,
    Inp_StopSet1_Swing_Lookback, Inp_StopSet1_Swing_OffsetPips,
    Inp_StopSet1_Time_MaxBars, Inp_StopSet1_Time_MaxMinutes,
    entryPrice, now, sl1);
  ComputeStopSetSL(isBuy, Inp_StopSet2_Type, Inp_StopSet2_Mode, Inp_StopSet2_TF, Inp_StopSet2_UseClosedBar,
    Inp_StopSet2_Value, Inp_StopSet2_TrailStart, Inp_StopSet2_TrailStep, Inp_StopSet2_BETrigger, Inp_StopSet2_BEOffset,
    Inp_StopSet2_ATR_Period, Inp_StopSet2_ATR_Mult, Inp_StopSet2_ATR_Recalc,
    Inp_StopSet2_PSAR_Step, Inp_StopSet2_PSAR_Max,
    Inp_StopSet2_Swing_Lookback, Inp_StopSet2_Swing_OffsetPips,
    Inp_StopSet2_Time_MaxBars, Inp_StopSet2_Time_MaxMinutes,
    entryPrice, now, sl2);
  double chosen=0.0; if(isBuy){ if(sl1>0 && sl2>0) chosen=MathMax(sl1,sl2); else chosen = (sl1>0? sl1: sl2); } else { if(sl1>0 && sl2>0) chosen=MathMin(sl1,sl2); else chosen = (sl1>0? sl1: sl2); }
  sl = chosen; tp = 0.0; // TP optional; can add TP logic later if needed
}

bool DoEntry(bool isBuy){ if(!SpreadOK()) return false; if(!InTimeWindowEntries()) return false; if(!CanOpenMore()) return false;
  if(!EntryFiltersPass(isBuy)) return false;
  double price = isBuy? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
  double sl=0.0,tp=0.0; ComputeInitialSLTP(isBuy,price,sl,tp);
  double slPoints = (sl>0.0? MathAbs(price-sl)/_Point : 0.0);
  double lots = CalcLotsByRisk(slPoints);
  trade.SetExpertMagicNumber(Inp_MagicNumber);
  trade.SetDeviationInPoints((int)Inp_SlippagePoints);
  bool ok = isBuy? trade.Buy(lots,_Symbol,price, Inp_PlaceInitialSLTP?sl:0.0, Inp_PlaceInitialSLTP?tp:0.0, Inp_OrderComment)
                  : trade.Sell(lots,_Symbol,price, Inp_PlaceInitialSLTP?sl:0.0, Inp_PlaceInitialSLTP?tp:0.0, Inp_OrderComment);
  if(ok){ int curBars=Bars(_Symbol,Inp_StrategyTF); if(isBuy){ g_lastEntryBuy=price; g_lockBuyUntilBar = (Inp_LossLockoutBars>0? curBars+Inp_LossLockoutBars : -1); ResetBuySetup(); } else { g_lastEntrySell=price; g_lockSellUntilBar=(Inp_LossLockoutBars>0? curBars+Inp_LossLockoutBars : -1); ResetSellSetup(); } }
  return ok;
}

// ========================= MANAGEMENT (TRAIL/BE/EXIT FILTERS) =========================
void ManageOpenPositions(){ // iterate positions for this symbol
  for(int i=PositionsTotal()-1;i>=0;--i){ if(!PositionSelectByIndex(i)) continue; string sym=PositionGetString(POSITION_SYMBOL); if(sym!=_Symbol) continue; long type=PositionGetInteger(POSITION_TYPE); bool isBuy=(type==POSITION_TYPE_BUY); double price=PositionGetDouble(POSITION_PRICE_OPEN); double sl=PositionGetDouble(POSITION_SL); double tp=PositionGetDouble(POSITION_TP);
    // Soft stops (trailing/breakeven/time) - simplified minimal version
    // Breakeven
    if((isBuy && Inp_StopSet1_Type==SS_BREAKEVEN) || (isBuy && Inp_StopSet2_Type==SS_BREAKEVEN) || (!isBuy && (Inp_StopSet1_Type==SS_BREAKEVEN || Inp_StopSet2_Type==SS_BREAKEVEN))){ double cur=iClose(_Symbol, Inp_StrategyTF, 0); double triggerPoints = ((Inp_StopSet1_Type==SS_BREAKEVEN? Inp_StopSet1_BETrigger: Inp_StopSet2_BETrigger) * ((Inp_StopSet1_Mode==UM_PIPS || Inp_StopSet2_Mode==UM_PIPS)? (PipSize()/_Point) : (price/100.0/_Point)) ); if(triggerPoints>0){ if(isBuy && cur>=price+triggerPoints*_Point){ double be=price + ((Inp_StopSet1_Type==SS_BREAKEVEN? Inp_StopSet1_BEOffset: Inp_StopSet2_BEOffset) * ((Inp_StopSet1_Mode==UM_PIPS || Inp_StopSet2_Mode==UM_PIPS)? PipSize() : price/100.0)); if(sl<be) trade.PositionModify(_Symbol,be,tp); } if(!isBuy && cur<=price-triggerPoints*_Point){ double be=price - ((Inp_StopSet1_Type==SS_BREAKEVEN? Inp_StopSet1_BEOffset: Inp_StopSet2_BEOffset) * ((Inp_StopSet1_Mode==UM_PIPS || Inp_StopSet2_Mode==UM_PIPS)? PipSize() : price/100.0)); if(sl==0.0 || sl>be) trade.PositionModify(_Symbol,be,tp); } } }
    // Trailing (simple pips)
    if((Inp_StopSet1_Type==SS_TRAILING) || (Inp_StopSet2_Type==SS_TRAILING)){
      double cur=iClose(_Symbol, Inp_StrategyTF, 0);
      double trailStartPts = ( (Inp_StopSet1_Type==SS_TRAILING? Inp_StopSet1_TrailStart: Inp_StopSet2_TrailStart) * ((Inp_StopSet1_Mode==UM_PIPS || Inp_StopSet2_Mode==UM_PIPS)? (PipSize()/_Point) : (price/100.0/_Point)) );
      double trailStepPts  = ( (Inp_StopSet1_Type==SS_TRAILING? Inp_StopSet1_TrailStep : Inp_StopSet2_TrailStep ) * ((Inp_StopSet1_Mode==UM_PIPS || Inp_StopSet2_Mode==UM_PIPS)? (PipSize()/_Point) : (price/100.0/_Point)) );
      if(trailStartPts>0 && trailStepPts>0){ if(isBuy){ if(cur>=price+trailStartPts*_Point){ double targetSL = cur - trailStepPts*_Point; if(sl<targetSL) trade.PositionModify(_Symbol,targetSL,tp); } } else { if(cur<=price-trailStartPts*_Point){ double targetSL = cur + trailStepPts*_Point; if(sl==0.0 || sl>targetSL) trade.PositionModify(_Symbol,targetSL,tp); } } }
    }
    // Exit filters combination (soft/filter)
    bool exitByFilters = ExitFiltersPass(isBuy);
    bool exitBySoft    = false; // For brevity we treat trail/BE triggers as modifying SL; actual closing happens by SL hit
    if(Inp_ExitDecisionMode==EDC_ANY){ if(exitByFilters){ trade.PositionClose(_Symbol); continue; } }
    else if(Inp_ExitDecisionMode==EDC_SOFT_OR_FILTERS){ if(exitByFilters || exitBySoft){ trade.PositionClose(_Symbol); continue; } }
    else if(Inp_ExitDecisionMode==EDC_SOFT_AND_FILTERS){ if(exitBySoft && exitByFilters){ trade.PositionClose(_Symbol); continue; } }
  }
}

// ========================= LIFECYCLE =========================
int OnInit(){ ArrayInitialize(g_lastBarTime,0); return(INIT_SUCCEEDED); }
void OnDeinit(const int reason){ }

void OnTick(){ bool doSignalUpdate = (Inp_SignalUpdateMode==UM_ON_TICK) || NewBarTF(Inp_StrategyTF);
  bool doMgmtUpdate   = (Inp_MgmtUpdateMode==UM_ON_TICK)   || NewBarTF(Inp_StrategyTF);
  if(doSignalUpdate){ // start/refresh setups
    TryStartSetups();
    // process pending buy
    if(g_waitBuy){ if(SetupExpired(true)) ResetBuySetup(); else { bool ok=HeikinUpdateCount(true); if(ok){ if(DoEntry(true)) ResetBuySetup(); else { /* keep waiting */ } } } }
    // process pending sell
    if(g_waitSell){ if(SetupExpired(false)) ResetSellSetup(); else { bool ok=HeikinUpdateCount(false); if(ok){ if(DoEntry(false)) ResetSellSetup(); else { /* keep waiting */ } } } }
  }
  if(doMgmtUpdate){ ManageOpenPositions(); }
}
