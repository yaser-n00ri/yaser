import re
import csv
from dataclasses import dataclass
from typing import List, Optional, Tuple, Dict
from statistics import mean
import pandas as pd
import pytz
import yfinance as yf

RAW_TEXT = r"""
Max risk 1% 

10 octobr 

Sell  limit  13:37 

En: 4020-4022 

Sl 4026 

Tp 4000 

Sell  limit  13:37 

En: 4038 

Sl 4043 

Tp 4004 

buy limit  13:40 this order is zone-hunt if hunted and stop entry again 

En: 3975 

Sl 3971 

Tp 3996 

buy limit  13:40 

En: 3970 

Sl 3964 

Tp 3996 
 

13 octobr 

Sell  limit ATH 11:37 

En: 4091-4094 

Sl 4096 

Tp 4060 

buy  limit   scalp 11:38 

En: 4038 

Sl 4034 

Tp 4055 

buy  limit   scalp 11:40 

En: 4071 

Sl 4067 

Tp 4090 
 

14 octobr 

Sell  limit ATH 07:12 

En: 4178-4181 

Sl 4184 

Tp 4155 

buy  limit scalp  07:12 

En: 4124 

Sl 4120 

Tp 4155 

buy  limit   07:12 

En: 4086 

Sl 4080 

Tp 4100 
 

15 octobr 

Buy limit  10:46 

En: 4188 

Sl 4184 

Tp 4208 

Buy limit  10:46 

En: 4188 

Sl 4184 

Tp 4208 

Sell  limit ATH 10:47 

En: 4206-4209 

Sl 4211 

Tp 4185 

Sell  limit ATH 13:09 

En: 4230-4233 

Sl 4235 

Tp 4200 

Sell  limit  13:08 

En: 4209-4213 

Sl 4215 

Tp 4190 

buy  limit  13:10 

En: 4153 

Sl 4148 

Tp 4180 
 

16 octobr 

Sell  limit ATH 12:10 

En: 4253-4256 

Sl 4259 

Tp 4230 

Sell  limit ATH 12:11 

En: 4265 

Sl 4270 

Tp 4244 

Buy limit  12:12 

En: 4188-4185 

Sl 4183 

Tp 4206 

Buy limit  scalp 13:07 

En: 4219 

Sl 4215 

Tp 4240 
 

17 octobr 

buy limit 11:11 

En: 4296-4293 

Sl 4290 

Tp 4323 

Buy limit 11:11 

En: 4266-4263 

Sl 4260 

Tp 4296 

Sell limit ATH 11:11 

En: 4407-4410 

Sl 4413 

Tp 4388 

Sell limit scalp 11:11 

En: 4362 

Sl 4366 

Tp 4343 

buy limit scalp14:34 

En: 4325 

Sl 4320 

Tp 4350 
 

20 octobr 

buy limit 09:12 

En: 4200.5-4197 

Sl 4195 

Tp 4222 

Buy limit scalp 09:11 

En: 4226-4223 

Sl 4220 

Tp 4250 

Sell limit 09:13 

En: 4284-4287 

Sl 4290 

Tp 4250 

Buy limit scalp 14:19 

En: 4231 

Sl 4227 

Tp 4252 

sell limit  15:51 

En: 4308-4311 

Sl 4313 

Tp 4280 
 

21 octobr 

buy limit 11:07  

En: 4282-4279 

Sl 4276 

Tp 4310 

Buy limit 11:08 

En: 4260-4257 

Sl 4254 

Tp 4282 

Buy limit 11:26 

En: 4227-4224 

Sl 4221 

Tp 4255 

Sell limit 12:39 high risk 

En: 4295 

Sl 4299 

Tp 4260 

Sell limit 12:40 

En: 4333-4336 

Sl 4339 

Tp 4300 

Sell limit scalp 14:04 

En: 4268-4270 

Sl 4273 

Tp 4244 

Buy limit 17:22 high risk 

En: 4162-4159 

Sl 4156 

Tp 4200 
 

22 octobr 

sell limit scalp10:03 high risk 

En: 4166-4169 

Sl 4171 

Tp 4144 

Sell limit 10:04 

En: 4192-4195 

Sl 4198 

Tp 4166 

Sell limit 10:05 

En: 4230 

Sl 4235 

Tp 4208 

Buy limit scalp 11:44 

En: 4062 

Sl 4056 

Tp 4080 
 

23 octobr 

Buy limit scalp11:30 

En: 4087 

Sl 4083 

Tp 4110 

Buy limit 11:50 

En: 3999-3996 

Sl 3993 

Tp 4022 

sell limit scalp11:51 

En: 4165 

Sl 4170 

Tp 4144 

sell limit 11:51 

En: 4187-4190 

Sl 4193 

Tp 4166 
 

24 octobr 

Sell limit 11:11 

En: 4110-4112 

Sl 4115 

Tp 4080 

Sell limit 11:13 

En: 4166 

Sl 4171 

Tp 4144 

Buy limit scalp11:13 

En: 4065 

Sl 4060 

Tp 4086 

Buy limit scalp11:11 

En: 4049-4060 

Sl 4043 

Tp 4072 
 

27 octobr 

Sell limit 9:37 

En: 4090-4093 

Sl 4096 

Tp 4066 

Sell limit 11:43 

En: 4095-4098 

Sl 4101 

Tp 4070 

Sell limit 11:44 

En: 4110-4113 

Sl 4116 

Tp 4088 

Sell limit scalp 11:42 

En: 4083-4086 

Sl 4089 

Tp 4061 

buy limit 11:31 

En: 4060-4062 

Sl 4056 

Tp 4084 

Buy limit 11:51 

En: 4030-4027 

Sl 4024 

Tp 4055 

Buy limit 11:53 

En: 4000-3997 

Sl 3994 

Tp 4022 
"""


def parse_orders(raw: str):
    orders = []
    current_day = None
    current_order = None

    def finalize():
        nonlocal current_order
        if current_order and current_order.get('sl') is not None and current_order.get('tp') is not None and (current_order.get('entry') is not None or (current_order.get('entry_lo') is not None and current_order.get('entry_hi') is not None)):
            orders.append(current_order)
        current_order = None

    lines = [ln.strip() for ln in raw.splitlines()]
    for ln in lines:
        if not ln:
            continue
        mday = re.match(r"^(\d{1,2})\s+octobr", ln, flags=re.I)
        if mday:
            finalize()
            current_day = int(mday.group(1))
            continue
        if re.search(r"\b(buy|sell)\b", ln, flags=re.I) and 'En:' not in ln and not re.match(r"^(Sl|Tp)\b", ln, flags=re.I):
            finalize()
            side = 'buy' if re.search(r"\bbuy\b", ln, flags=re.I) else 'sell'
            otype = 'limit' if re.search(r"\blimit\b", ln, flags=re.I) else None
            tags = []
            if re.search(r"\bATH\b", ln, flags=re.I):
                tags.append('ATH')
            if re.search(r"\bscalp\b", ln, flags=re.I):
                tags.append('scalp')
            if re.search(r"high\s*risk", ln, flags=re.I):
                tags.append('high_risk')
            if re.search(r"zone-?hunt", ln, flags=re.I):
                tags.append('zone_hunt')
            tm = re.search(r"(\d{1,2}:\d{2})", ln)
            time_str = tm.group(1) if tm else None
            current_order = {
                'day': current_day,
                'side': side,
                'type': otype,
                'time': time_str,
                'tags': tags,
                'entry': None,
                'entry_hi': None,
                'entry_lo': None,
                'sl': None,
                'tp': None,
            }
            continue
        if ln.lower().startswith('en'):
            nums = re.findall(r"[-+]?\d+(?:\.\d+)?", ln)
            if not nums:
                continue
            if len(nums) == 1:
                current_order['entry'] = float(nums[0])
            elif len(nums) >= 2:
                a, b = float(nums[0]), float(nums[1])
                current_order['entry_lo'] = min(a, b)
                current_order['entry_hi'] = max(a, b)
            continue
        if ln.lower().startswith('sl'):
            nums = re.findall(r"[-+]?\d+(?:\.\d+)?", ln)
            if nums:
                current_order['sl'] = float(nums[0])
            continue
        if ln.lower().startswith('tp'):
            nums = re.findall(r"[-+]?\d+(?:\.\d+)?", ln)
            if nums:
                current_order['tp'] = float(nums[0])
            continue
    finalize()
    return orders


def expand_legs_with_group(orders):
    legs = []
    group_id = 0
    for od in orders:
        entries = []
        if od.get('entry') is not None:
            entries = [od['entry']]
        elif od.get('entry_lo') is not None and od.get('entry_hi') is not None:
            # two legs, higher then lower by convention
            entries = [od['entry_hi'], od['entry_lo']]
        else:
            continue
        legs_count = len(entries)
        group_id += 1
        for en in entries:
            side = od['side']
            sl = od['sl']
            tp = od['tp']
            if side == 'buy':
                sl_dist = en - sl
                tp_dist = tp - en
            else:
                sl_dist = sl - en
                tp_dist = en - tp
            if sl_dist <= 0 or tp_dist <= 0:
                rr = None
            else:
                rr = tp_dist / sl_dist
            legs.append({
                'group_id': group_id,
                'legs_in_group': legs_count,
                'day': od['day'],
                'time': od['time'],
                'side': side,
                'tags': ';'.join(od['tags']) if od['tags'] else '',
                'entry': en,
                'sl': sl,
                'tp': tp,
                'sl_dist': sl_dist,
                'tp_dist': tp_dist,
                'rr': rr,
            })
    return legs


def to_utc(dt_naive: pd.Timestamp) -> pd.Timestamp:
    tehran = pytz.timezone('Asia/Tehran')
    dt_local = tehran.localize(dt_naive)
    return dt_local.astimezone(pytz.UTC)


def simulate_leg(
    df: pd.DataFrame,
    start_utc: pd.Timestamp,
    end_utc: pd.Timestamp,
    side: str,
    entry: float,
    sl: float,
    tp: float,
    sequencing: str = 'conservative',
    trailing_points: Optional[float] = None,
    be_after_r: Optional[float] = None,
    allow_reentry_once: bool = False,
) -> Tuple[str, float, Optional[pd.Timestamp], Optional[pd.Timestamp]]:
    # Filter df window
    w = df.loc[(df.index >= start_utc) & (df.index <= end_utc)].copy()
    in_pos = False
    fill_time = None
    stop = sl
    max_fav = None
    min_fav = None
    reentered = False
    # define helpers
    def hit_entry(row):
        h = row['High']
        l = row['Low']
        if side == 'buy':
            return l <= entry <= h
        else:
            return l <= entry <= h

    def after_fill_hit(row, stop_level, take_level):
        h = row['High']
        l = row['Low']
        hit_sl = (l <= stop_level) if side == 'buy' else (h >= stop_level)
        hit_tp = (h >= take_level) if side == 'buy' else (l <= take_level)
        if hit_sl and hit_tp:
            if sequencing == 'conservative':
                return 'SL'
            elif sequencing == 'optimistic':
                return 'TP'
            else:
                return 'SL'
        elif hit_sl:
            return 'SL'
        elif hit_tp:
            return 'TP'
        else:
            return None

    for ts, row in w.iterrows():
        if not in_pos:
            if hit_entry(row):
                in_pos = True
                fill_time = ts
                # initialize MFE tracking
                if side == 'buy':
                    max_fav = row['High'] - entry
                    min_fav = entry - row['Low']
                else:
                    max_fav = entry - row['Low']
                    min_fav = row['High'] - entry
                # If trailing active, stop already defined as sl
                # After fill, we should also check if SL/TP hit within the same bar
                outcome = after_fill_hit(row, stop, tp)
                if outcome:
                    if outcome == 'SL':
                        if allow_reentry_once and not reentered:
                            # reset state: allow a single reentry later
                            in_pos = False
                            reentered = True
                            fill_time = None
                            stop = sl
                            max_fav = None
                            min_fav = None
                        else:
                            return ('SL', -1.0, fill_time, ts)
                    else:
                        rr = (tp - entry) / (entry - sl) if side == 'buy' else (entry - tp) / (sl - entry)
                        return ('TP', rr, fill_time, ts)
                continue
        else:
            # update MFE
            if side == 'buy':
                max_fav = max(max_fav, row['High'] - entry)
            else:
                max_fav = max(max_fav, entry - row['Low'])
            # trailing update
            stop_level = stop
            if trailing_points is not None:
                if side == 'buy':
                    trail_base = entry + max_fav
                    new_stop = trail_base - trailing_points
                    stop = max(stop, new_stop)
                else:
                    trail_base = entry - max_fav
                    new_stop = trail_base + trailing_points
                    stop = min(stop, new_stop)
                stop_level = stop
            # BE rule after X R
            if be_after_r is not None and be_after_r > 0:
                sl_dist = (entry - sl) if side == 'buy' else (sl - entry)
                trigger = be_after_r * sl_dist
                if max_fav is not None and max_fav >= trigger:
                    # move stop to entry (break-even)
                    stop = max(stop, entry) if side == 'buy' else min(stop, entry)
                    stop_level = stop
            # check exits
            outcome = after_fill_hit(row, stop_level, tp)
            if outcome:
                if outcome == 'SL':
                    if allow_reentry_once and not reentered:
                        # allow single reentry later
                        in_pos = False
                        reentered = True
                        fill_time = None
                        stop = sl
                        max_fav = None
                        min_fav = None
                        continue
                    return ('SL', -1.0, fill_time, ts)
                else:
                    rr = (tp - entry) / (entry - sl) if side == 'buy' else (entry - tp) / (sl - entry)
                    return ('TP', rr, fill_time, ts)
    # no exit till end; settle at last bar close vs stop
    if not in_pos:
        return ('NC', 0.0, None, None)  # not triggered
    # If in position, mark to market at last close vs stop
    last = w.iloc[-1]
    last_price = last['Close']
    if side == 'buy':
        if last_price <= stop:
            return ('SL', -1.0, fill_time, w.index[-1])
        # unrealized R based on current price
        rr_cur = (last_price - entry) / (entry - sl)
    else:
        if last_price >= stop:
            return ('SL', -1.0, fill_time, w.index[-1])
        rr_cur = (entry - last_price) / (sl - entry)
    return ('OPEN', rr_cur, fill_time, w.index[-1])


def run_backtest(sequencing: str, trailing_points: Optional[float] = None, be_after_r: Optional[float] = None) -> Dict:
    orders = parse_orders(RAW_TEXT)
    legs = expand_legs_with_group(orders)
    # resolve duplicated orders (same day/time/side/sl/tp/entry) into same group id to split risk
    # For simplicity we reuse given grouping; duplicates appear as separate single-entry groups; we merge by key
    groups: Dict[Tuple, List[int]] = {}
    for idx, leg in enumerate(legs):
        key = (leg['day'], leg['time'], leg['side'], round(leg['sl'],3), round(leg['tp'],3))
        groups.setdefault(key, []).append(idx)
    # adjust legs_in_group based on duplicates
    for key, idxs in groups.items():
        # also split by entry values uniqueness
        count = len(idxs)
        for i in idxs:
            legs[i]['legs_in_group'] = count
            legs[i]['group_id'] = abs(hash(key)) % (10**9)

    # Download price data once
    start_date = pd.Timestamp('2025-10-09')
    end_date = pd.Timestamp('2025-10-28')
    # Use 5m because Yahoo limits 1m to last ~8 days per request
    interval = '5m'
    df = yf.download('GC=F', start=start_date.strftime('%Y-%m-%d'), end=end_date.strftime('%Y-%m-%d'), interval=interval, auto_adjust=True, prepost=False)
    if df.empty:
        raise RuntimeError('Price data download failed for GC=F')
    # Flatten columns if multi-index like ('High','GC=F')
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = [c[0] for c in df.columns]
    df = df[['Open','High','Low','Close']]
    # yfinance returns tz-aware UTC index for intraday; ensure UTC
    if df.index.tz is None:
        df.index = df.index.tz_localize('UTC')
    else:
        df.index = df.index.tz_convert('UTC')

    results = []
    for leg in legs:
        day = leg['day']
        time_str = leg['time'] or '00:00'
        # Build Tehran datetime
        dt_local = pd.Timestamp(f'2025-10-{day:02d} {time_str}:00')
        start_utc = to_utc(dt_local)
        # Cancel at end of day Tehran
        eod_local = pd.Timestamp(f'2025-10-{day:02d} 23:59:59')
        end_utc = to_utc(eod_local)
        side = leg['side']
        entry = leg['entry']
        sl = leg['sl']
        tp = leg['tp']
        allow_reentry = 'zone_hunt' in (leg['tags'] or '')
        outcome, r_mult, t_fill, t_exit = simulate_leg(
            df,
            start_utc,
            end_utc,
            side,
            entry,
            sl,
            tp,
            sequencing=sequencing,
            trailing_points=trailing_points,
            be_after_r=be_after_r,
            allow_reentry_once=allow_reentry,
        )
        results.append({
            **leg,
            'outcome': outcome,
            'r_mult': r_mult,
            'fill_time': t_fill.isoformat() if t_fill else '',
            'exit_time': t_exit.isoformat() if t_exit else '',
        })
    # Aggregate PnL with 1% account risk per group, split equally per leg
    account = 1000.0
    risk_perc = 0.01
    pnl_total = 0.0
    wins = 0
    losses = 0
    open_cnt = 0
    notrig_cnt = 0
    # compute legs per group
    group_to_count: Dict[int,int] = {}
    for r in results:
        gid = r['group_id']
        group_to_count[gid] = max(group_to_count.get(gid, 0), r['legs_in_group'])
    for r in results:
        gid = r['group_id']
        leg_risk_usd = account * risk_perc / group_to_count[gid]
        if r['outcome'] == 'TP':
            rr = r['r_mult'] if r['r_mult'] is not None else 0.0
            pnl_total += leg_risk_usd * rr
            wins += 1
        elif r['outcome'] == 'SL':
            pnl_total -= leg_risk_usd
            losses += 1
        elif r['outcome'] == 'OPEN':
            # mark-to-market: count as zero for now
            open_cnt += 1
        else:
            notrig_cnt += 1
    total_closed = wins + losses
    winrate = (wins / total_closed * 100.0) if total_closed > 0 else 0.0
    return {
        'sequencing': sequencing,
        'trailing_points': trailing_points,
        'wins': wins,
        'losses': losses,
        'not_triggered': notrig_cnt,
        'open': open_cnt,
        'winrate_percent': round(winrate, 2),
        'pnl_usd': round(pnl_total, 2),
        'results': results,
    }


def main():
    scenarios = [
        ('conservative', None, None),
        ('optimistic', None, None),
        ('conservative', None, 1.0),  # BE at +1R
        ('conservative', 10.0, None),  # trailing 10 points
        ('conservative', 15.0, None),
        ('conservative', 20.0, None),
    ]
    rows = []
    for seq, trail, be_r in scenarios:
        bt = run_backtest(seq, trail, be_r)
        print({'seq': seq, 'trail': trail, 'be_after_R': be_r, 'wins': bt['wins'], 'losses': bt['losses'], 'notrig': bt['not_triggered'], 'open': bt['open'], 'winrate%': bt['winrate_percent'], 'pnl$': bt['pnl_usd']})
        rows.append(bt)
    # write detailed csv
    # last scenario detailed
    last = rows[0]
    with open('/workspace/backtest_results.csv','w', newline='') as f:
        fieldnames = list(last['results'][0].keys())
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in last['results']:
            w.writerow(r)

if __name__ == '__main__':
    main()
