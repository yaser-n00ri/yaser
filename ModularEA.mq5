#property copyright   "Modular EA"
#property version     "1.0.0"
#property strict

#include <Trade/Trade.mqh>

// ========================= ENUMERATIONS =========================
enum StrategyEnum {
  STRAT_NONE = 0,
  STRAT_EMA_CROSSOVER
};

enum FilterEnum {
  FILTER_NONE = 0,
  FILTER_EMA_TREND,
  FILTER_RSI_THRESHOLD,
  FILTER_ADX_TREND,
  FILTER_PSAR_TREND,
  FILTER_HEIKIN_FILTER
};

enum LogicMode { LOGIC_AND = 0, LOGIC_OR };

enum SLModeEnum { SL_NONE = 0, SL_PIPS, SL_PERCENT, SL_ATR };

enum TPModeEnum { TP_NONE = 0, TP_PIPS, TP_PERCENT, TP_RR };

// ========================= INPUTS (EVERY NUMBER IS INPUT) =========================
// Strategy selection
input StrategyEnum       Inp_SelectedStrategy         = STRAT_EMA_CROSSOVER;
input ENUM_TIMEFRAMES    Inp_StrategyTF               = PERIOD_CURRENT;

// Filters (up to 4) + logic
input FilterEnum         Inp_FilterA                  = FILTER_NONE;
input ENUM_TIMEFRAMES    Inp_FilterA_TF               = PERIOD_CURRENT;
input FilterEnum         Inp_FilterB                  = FILTER_NONE;
input ENUM_TIMEFRAMES    Inp_FilterB_TF               = PERIOD_CURRENT;
input FilterEnum         Inp_FilterC                  = FILTER_NONE;
input ENUM_TIMEFRAMES    Inp_FilterC_TF               = PERIOD_CURRENT;
input FilterEnum         Inp_FilterD                  = FILTER_NONE;
input ENUM_TIMEFRAMES    Inp_FilterD_TF               = PERIOD_CURRENT;
input LogicMode          Inp_FiltersLogic             = LOGIC_AND; // Apply across A..D

// Trading window
input bool               Inp_DisableTradingWindow     = true;  // if true, ignore window
input int                Inp_TradingStartHour         = 0;
input int                Inp_TradingStartMin          = 0;
input int                Inp_TradingEndHour           = 23;
input int                Inp_TradingEndMin            = 59;
input int                Inp_CloseAllHour             = -1;    // <0 disabled
input int                Inp_CloseAllMin              = 0;

// New bar / shift controls
input bool               Inp_UseClosedBar             = true;
input int                Inp_ClosedBarShift           = 1;
input int                Inp_OpenBarShift             = 0;
input int                Inp_PrevBarOffset            = 1;     // how far back for previous value
input int                Inp_CopyBarsCount            = 2;     // CopyBuffer bars to fetch

// Money management
input int                Inp_MagicNumber              = 20251015;
input string             Inp_OrderComment             = "ModularEA";
input bool               Inp_UseFixedLot              = true;
input double             Inp_FixedLot                 = 0.10;
input double             Inp_RiskPercent              = 1.0;   // used when UseFixedLot=false
input double             Inp_MinLot                   = 0.01;
input double             Inp_MaxLot                   = 10.0;
input double             Inp_SlippagePoints           = 10.0;  // points
input bool               Inp_UseMaxSpread             = true;
input double             Inp_MaxSpreadPoints          = 250.0; // points
input int                Inp_MaxOpenPositions         = 1;

// StopLoss / TakeProfit
input SLModeEnum         Inp_SLMode                   = SL_PIPS;
input double             Inp_SLValue                  = 300.0; // pips (if SL_PIPS), or percent (if SL_PERCENT), or ATR mult (if SL_ATR)
input TPModeEnum         Inp_TPMode                   = TP_RR; // Risk:Reward mode
input double             Inp_TPValue                  = 2.0;   // pips/percent or RR depending on mode

// ATR for SL/filters
input int                Inp_ATR_Period               = 14;

// EMA strategy parameters
input int                Inp_EMA_Fast_Period          = 9;
input int                Inp_EMA_Slow_Period          = 21;
input int                Inp_EMA_Mode                 = MODE_EMA;     // keep as input though enum under the hood
input int                Inp_EMA_Price                = PRICE_CLOSE;  // applied price

// RSI parameters
input int                Inp_RSI_Period               = 14;
input double             Inp_RSI_Low                  = 30.0;
input double             Inp_RSI_High                 = 70.0;

// ADX parameters
input int                Inp_ADX_Period               = 14;
input double             Inp_ADX_Threshold            = 20.0;
input int                Inp_ADX_BufferIndex          = 0;     // 0=ADX line
input int                Inp_ADX_PlusDI_Index         = 1;     // +DI buffer index
input int                Inp_ADX_MinusDI_Index        = 2;     // -DI buffer index

// PSAR parameters
input double             Inp_PSAR_Step                = 0.02;
input double             Inp_PSAR_Max                 = 0.2;
input int                Inp_PSAR_BufferIndex         = 0;

// Heikin-Ashi parameters
input string             Inp_HeikinIndicator          = "Heiken_Ashi";
input int                Inp_Heikin_Open_Index        = 0;     // iCustom buffer index for HA open
input int                Inp_Heikin_Close_Index       = 3;     // iCustom buffer index for HA close

// Entry gating
input int                Inp_MaxNCandlesAfterSignal   = 5;
input int                Inp_LossLockoutBars          = -1;    // -1 disabled
input double             Inp_PriceImproveATR          = -1.0;  // -1 disabled, require k*ATR improvement

// ========================= STATE / HANDLES =========================
CTrade trade;

// Indicator handles for strategy timeframe
int hEMA_Fast = INVALID_HANDLE;
int hEMA_Slow = INVALID_HANDLE;
int hRSI      = INVALID_HANDLE;
int hATR      = INVALID_HANDLE;
int hADX      = INVALID_HANDLE;
int hPSAR     = INVALID_HANDLE;
int hHA       = INVALID_HANDLE;

// New bar tracking per TF (index with timeframe value masked with 255)
datetime g_lastBarTime[256];

// Price memory for gating
int     g_lastSignalBar = -1;        // bar index when last entry signal happened
bool    g_lockBuy       = false;     // lockout flags
bool    g_lockSell      = false;
double  g_lastEntryBuy  = 0.0;       // last buy price for price-improve gate
double  g_lastEntrySell = 0.0;       // last sell price for price-improve gate

// ========================= UTILS =========================
double PipSize() {
  return ((_Digits == 3 || _Digits == 5) ? 10.0 * _Point : _Point);
}

double CurrentSpreadPoints() {
  double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  return (ask - bid) / _Point;
}

bool InTradingWindow(int hour, int min) {
  if (Inp_DisableTradingWindow)
    return true;
  int start = Inp_TradingStartHour * 60 + Inp_TradingStartMin;
  int end   = Inp_TradingEndHour   * 60 + Inp_TradingEndMin;
  int cur   = hour * 60 + min;
  if (start <= end)
    return (cur >= start && cur <= end);
  // overnight window
  return (cur >= start || cur <= end);
}

bool NewBarTF(ENUM_TIMEFRAMES tf) {
  int idx = ((int)tf) & 255;
  datetime t = iTime(_Symbol, tf, 0);
  if (t == 0) return false;
  if (t != g_lastBarTime[idx]) {
    g_lastBarTime[idx] = t;
    return true;
  }
  return false;
}

int EntryShift() {
  return (Inp_UseClosedBar ? Inp_ClosedBarShift : Inp_OpenBarShift);
}

bool CopyOne(int handle, int buffer, int shift, int count, double &out[]) {
  ArraySetAsSeries(out, true);
  return (CopyBuffer(handle, buffer, shift, count, out) == count);
}

// ========================= INDICATOR LOADING =========================
bool LoadStrategyHandles() {
  // shared ATR
  hATR = iATR(_Symbol, Inp_StrategyTF, Inp_ATR_Period);

  switch (Inp_SelectedStrategy) {
    case STRAT_EMA_CROSSOVER:
      hEMA_Fast = iMA(_Symbol, Inp_StrategyTF, Inp_EMA_Fast_Period, 0, Inp_EMA_Mode, Inp_EMA_Price);
      hEMA_Slow = iMA(_Symbol, Inp_StrategyTF, Inp_EMA_Slow_Period, 0, Inp_EMA_Mode, Inp_EMA_Price);
      break;
    case STRAT_NONE:
    default:
      break;
  }

  // Common optional handles for filters
  hRSI = iRSI(_Symbol, Inp_StrategyTF, Inp_RSI_Period, PRICE_CLOSE);
  hADX = iADX(_Symbol, Inp_StrategyTF, Inp_ADX_Period);
  hPSAR = iSAR(_Symbol, Inp_StrategyTF, Inp_PSAR_Step, Inp_PSAR_Max);
  hHA  = iCustom(_Symbol, Inp_StrategyTF, Inp_HeikinIndicator);

  return true;
}

// ========================= FILTERS =========================
bool EvalFilter(FilterEnum f, bool isBuy, ENUM_TIMEFRAMES tf) {
  if (f == FILTER_NONE) return true;

  int sh = EntryShift();
  int prev = sh + Inp_PrevBarOffset;

  double buf0[4];
  ArrayInitialize(buf0, 0.0);

  switch (f) {
    case FILTER_EMA_TREND: {
      // Price vs EMA trend
      int hEMAtrend = iMA(_Symbol, tf, Inp_EMA_Slow_Period, 0, Inp_EMA_Mode, Inp_EMA_Price);
      if (hEMAtrend == INVALID_HANDLE) return false;
      double ema[2];
      if (!CopyOne(hEMAtrend, 0, sh, 1, ema)) return false;
      double price = iClose(_Symbol, tf, sh);
      return (isBuy ? (price > ema[0]) : (price < ema[0]));
    }
    case FILTER_RSI_THRESHOLD: {
      int h = iRSI(_Symbol, tf, Inp_RSI_Period, PRICE_CLOSE);
      if (h == INVALID_HANDLE) return false;
      double rsi[2];
      if (!CopyOne(h, 0, sh, 1, rsi)) return false;
      if (isBuy) return (rsi[0] <= Inp_RSI_Low);
      return (rsi[0] >= Inp_RSI_High);
    }
    case FILTER_ADX_TREND: {
      int h = iADX(_Symbol, tf, Inp_ADX_Period);
      if (h == INVALID_HANDLE) return false;
      double adx[2], pdi[2], mdi[2];
      if (!CopyOne(h, Inp_ADX_BufferIndex, sh, 1, adx)) return false;
      if (!CopyOne(h, Inp_ADX_PlusDI_Index, sh, 1, pdi)) return false;
      if (!CopyOne(h, Inp_ADX_MinusDI_Index, sh, 1, mdi)) return false;
      if (adx[0] < Inp_ADX_Threshold) return false;
      return (isBuy ? (pdi[0] > mdi[0]) : (mdi[0] > pdi[0]));
    }
    case FILTER_PSAR_TREND: {
      int h = iSAR(_Symbol, tf, Inp_PSAR_Step, Inp_PSAR_Max);
      if (h == INVALID_HANDLE) return false;
      double psar[2];
      if (!CopyOne(h, Inp_PSAR_BufferIndex, sh, 1, psar)) return false;
      double close = iClose(_Symbol, tf, sh);
      return (isBuy ? (close > psar[0]) : (close < psar[0]));
    }
    case FILTER_HEIKIN_FILTER: {
      int h = iCustom(_Symbol, tf, Inp_HeikinIndicator);
      if (h == INVALID_HANDLE) return false;
      double o[2], c[2];
      if (!CopyOne(h, Inp_Heikin_Open_Index,  sh, 1, o)) return false;
      if (!CopyOne(h, Inp_Heikin_Close_Index, sh, 1, c)) return false;
      bool bull = (c[0] > o[0]);
      return (isBuy ? bull : !bull);
    }
    default: return true;
  }
}

bool EvalFilterBank(bool forBuy) {
  bool okA = EvalFilter(Inp_FilterA, forBuy, Inp_FilterA_TF);
  bool okB = EvalFilter(Inp_FilterB, forBuy, Inp_FilterB_TF);
  bool okC = EvalFilter(Inp_FilterC, forBuy, Inp_FilterC_TF);
  bool okD = EvalFilter(Inp_FilterD, forBuy, Inp_FilterD_TF);

  if (Inp_FiltersLogic == LOGIC_AND)
    return (okA && okB && okC && okD);
  return (okA || okB || okC || okD);
}

// ========================= STRATEGY: EMA CROSSOVER =========================
bool EmaCrossSignal(bool &buySignal, bool &sellSignal) {
  buySignal = false; sellSignal = false;
  if (hEMA_Fast == INVALID_HANDLE || hEMA_Slow == INVALID_HANDLE)
    return false;

  int sh = EntryShift();
  int prev = sh + Inp_PrevBarOffset;

  double f[4], s[4], fPrev[4], sPrev[4];
  if (!CopyOne(hEMA_Fast, 0, sh, 1, f)) return false;
  if (!CopyOne(hEMA_Slow, 0, sh, 1, s)) return false;
  if (!CopyOne(hEMA_Fast, 0, prev, 1, fPrev)) return false;
  if (!CopyOne(hEMA_Slow, 0, prev, 1, sPrev)) return false;

  bool crossedUp   = (fPrev[0] <= sPrev[0] && f[0] > s[0]);
  bool crossedDown = (fPrev[0] >= sPrev[0] && f[0] < s[0]);

  // Apply filter banks
  if (crossedUp && EvalFilterBank(true))  buySignal  = true;
  if (crossedDown && EvalFilterBank(false)) sellSignal = true;

  return (buySignal || sellSignal);
}

// ========================= RISK / LOTS =========================
double CalcLotsByRisk(double slPoints) {
  // Fallback to fixed lot when inputs are not usable
  if (Inp_UseFixedLot || slPoints <= 0.0) {
    double lot = Inp_FixedLot;
    lot = MathMax(lot, Inp_MinLot);
    lot = MathMin(lot, Inp_MaxLot);
    return lot;
  }
  // Approx: risk value in account currency
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  double riskValue = balance * (Inp_RiskPercent / 100.0);
  // Tick value per lot
  double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  if (tickValue <= 0.0 || tickSize <= 0.0) {
    double lot = Inp_FixedLot;
    lot = MathMax(lot, Inp_MinLot);
    lot = MathMin(lot, Inp_MaxLot);
    return lot;
  }
  double pointValuePerLot = (tickValue / tickSize) * _Point;
  double lots = riskValue / (slPoints * pointValuePerLot);
  lots = MathMax(lots, Inp_MinLot);
  lots = MathMin(lots, Inp_MaxLot);
  return lots;
}

// ========================= SL/TP COMPUTATION =========================
void ComputeSLTP(bool isBuy, double entryPrice, double &sl, double &tp) {
  sl = 0.0; tp = 0.0;

  // Compute SL distance in points
  double slPoints = 0.0;
  if (Inp_SLMode == SL_PIPS) {
    slPoints = Inp_SLValue * PipSize() / _Point;
  } else if (Inp_SLMode == SL_PERCENT) {
    double percent = Inp_SLValue / 100.0;
    slPoints = percent * entryPrice / _Point;
  } else if (Inp_SLMode == SL_ATR) {
    double a[2];
    if (hATR != INVALID_HANDLE && CopyOne(hATR, 0, EntryShift(), 1, a))
      slPoints = Inp_SLValue * (a[0] / _Point);
  }

  // Set SL
  if (slPoints > 0.0) {
    if (isBuy) sl = entryPrice - slPoints * _Point; else sl = entryPrice + slPoints * _Point;
  }

  // TP
  if (Inp_TPMode == TP_NONE) {
    tp = 0.0;
  } else if (Inp_TPMode == TP_PIPS) {
    double tpPoints = Inp_TPValue * PipSize() / _Point;
    if (isBuy) tp = entryPrice + tpPoints * _Point; else tp = entryPrice - tpPoints * _Point;
  } else if (Inp_TPMode == TP_PERCENT) {
    double tpPoints = (Inp_TPValue / 100.0) * entryPrice / _Point;
    if (isBuy) tp = entryPrice + tpPoints * _Point; else tp = entryPrice - tpPoints * _Point;
  } else if (Inp_TPMode == TP_RR) {
    if (slPoints > 0.0) {
      double tpPoints = Inp_TPValue * slPoints;
      if (isBuy) tp = entryPrice + tpPoints * _Point; else tp = entryPrice - tpPoints * _Point;
    }
  }
}

// ========================= ENTRY GATES =========================
bool PassEntryGates(bool isBuy, ENUM_TIMEFRAMES tf) {
  // Spread
  if (Inp_UseMaxSpread && CurrentSpreadPoints() > Inp_MaxSpreadPoints)
    return false;

  // Loss lockout bars
  if (Inp_LossLockoutBars > 0 && g_lastSignalBar >= 0) {
    int barsNow = Bars(_Symbol, tf);
    if (isBuy && g_lockBuy && barsNow < g_lastSignalBar + Inp_LossLockoutBars) return false;
    if (!isBuy && g_lockSell && barsNow < g_lastSignalBar + Inp_LossLockoutBars) return false;
  }

  // Price improvement vs last entry, scaled by ATR
  if (Inp_PriceImproveATR > 0.0) {
    double a[2];
    if (hATR != INVALID_HANDLE && CopyOne(hATR, 0, EntryShift(), 1, a)) {
      double minDelta = Inp_PriceImproveATR * a[0];
      double cur = iClose(_Symbol, tf, 0);
      if (isBuy && g_lastEntryBuy > 0.0 && cur < g_lastEntryBuy + minDelta) return false;
      if (!isBuy && g_lastEntrySell > 0.0 && cur > g_lastEntrySell - minDelta) return false;
    }
  }
  return true;
}

// ========================= POSITION HELPERS =========================
bool HasPosition(int &posType, double &entryPrice, string &posComment) {
  if (!PositionSelect(_Symbol)) return false;
  posType = (int)PositionGetInteger(POSITION_TYPE);
  entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
  posComment = PositionGetString(POSITION_COMMENT);
  return true;
}

int CountOpenPositions() {
  int total = PositionsTotal();
  int cnt = 0;
  for (int i = 0; i < total; ++i) {
    ulong ticket = PositionGetTicket(i);
    if (ticket == 0) continue;
    string sym = PositionGetString(POSITION_SYMBOL);
    if (sym == _Symbol) cnt++;
  }
  return cnt;
}

// ========================= LIFECYCLE =========================
int OnInit() {
  trade.SetExpertMagicNumber(Inp_MagicNumber);
  if (!LoadStrategyHandles()) {
    Print("Failed to load indicator handles");
    return INIT_FAILED;
  }
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
  // Release created handles (optional, terminal clears on unload)
  if (hEMA_Fast  != INVALID_HANDLE) IndicatorRelease(hEMA_Fast);
  if (hEMA_Slow  != INVALID_HANDLE) IndicatorRelease(hEMA_Slow);
  if (hRSI       != INVALID_HANDLE) IndicatorRelease(hRSI);
  if (hATR       != INVALID_HANDLE) IndicatorRelease(hATR);
  if (hADX       != INVALID_HANDLE) IndicatorRelease(hADX);
  if (hPSAR      != INVALID_HANDLE) IndicatorRelease(hPSAR);
  if (hHA        != INVALID_HANDLE) IndicatorRelease(hHA);
}

void OnTick() {
  if (!NewBarTF(Inp_StrategyTF)) return;

  MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
  if (Inp_CloseAllHour >= 0 && tm.hour == Inp_CloseAllHour && tm.min == Inp_CloseAllMin) {
    if (PositionSelect(_Symbol)) trade.PositionClose(_Symbol);
    return;
  }
  if (!InTradingWindow(tm.hour, tm.min)) return;

  // Prevent too many positions
  if (CountOpenPositions() >= Inp_MaxOpenPositions) return;

  int posType = -1; double posEntry = 0.0; string posComment = "";
  bool hasPos = HasPosition(posType, posEntry, posComment);

  bool buySignal = false, sellSignal = false;
  bool gotSignal = false;

  switch (Inp_SelectedStrategy) {
    case STRAT_EMA_CROSSOVER:
      gotSignal = EmaCrossSignal(buySignal, sellSignal);
      break;
    case STRAT_NONE:
    default:
      gotSignal = false; break;
  }

  if (!gotSignal) return;

  int shBars = Bars(_Symbol, Inp_StrategyTF);
  if (Inp_MaxNCandlesAfterSignal > 0 && g_lastSignalBar >= 0) {
    if (shBars > g_lastSignalBar + Inp_MaxNCandlesAfterSignal) {
      buySignal = false; sellSignal = false; // stale
    }
  }

  // Execute
  if (buySignal && !hasPos && PassEntryGates(true, Inp_StrategyTF)) {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = 0.0, tp = 0.0; ComputeSLTP(true, price, sl, tp);
    double slPoints = (sl > 0.0 ? MathAbs(price - sl) / _Point : 0.0);
    double lots = CalcLotsByRisk(slPoints);
    trade.SetDeviationInPoints((int)Inp_SlippagePoints);
    trade.Buy(lots, _Symbol, price, sl, tp, Inp_OrderComment);
    g_lastEntryBuy = price; g_lastSignalBar = shBars; g_lockBuy = false; // reset lock on new entry
  }
  if (sellSignal && !hasPos && PassEntryGates(false, Inp_StrategyTF)) {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = 0.0, tp = 0.0; ComputeSLTP(false, price, sl, tp);
    double slPoints = (sl > 0.0 ? MathAbs(price - sl) / _Point : 0.0);
    double lots = CalcLotsByRisk(slPoints);
    trade.SetDeviationInPoints((int)Inp_SlippagePoints);
    trade.Sell(lots, _Symbol, price, sl, tp, Inp_OrderComment);
    g_lastEntrySell = price; g_lastSignalBar = shBars; g_lockSell = false;
  }
}
