import re
import csv
from statistics import mean, median

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
        if current_order and current_order.get('entry') is not None and current_order.get('sl') is not None and current_order.get('tp') is not None:
            orders.append(current_order)
        current_order = None

    lines = [ln.strip() for ln in raw.splitlines()]
    for ln in lines:
        if not ln:
            continue
        # date header
        mday = re.match(r"^(\d{1,2})\s+octobr", ln, flags=re.I)
        if mday:
            finalize()
            current_day = int(mday.group(1))
            continue
        # new order line with side/type/time/tags
        if re.search(r"\b(buy|sell)\b", ln, flags=re.I) and 'En:' not in ln and not re.match(r"^(Sl|Tp)\b", ln, flags=re.I):
            finalize()
            side = 'buy' if re.search(r"\bbuy\b", ln, flags=re.I) else 'sell'
            otype = 'limit' if re.search(r"\blimit\b", ln, flags=re.I) else None
            # tags
            tags = []
            if re.search(r"\bATH\b", ln, flags=re.I):
                tags.append('ATH')
            if re.search(r"\bscalp\b", ln, flags=re.I):
                tags.append('scalp')
            if re.search(r"high\s*risk", ln, flags=re.I):
                tags.append('high_risk')
            if re.search(r"zone-?hunt", ln, flags=re.I):
                tags.append('zone_hunt')
            # time
            tm = re.search(r"(\d{1,2}:\d{2})", ln)
            time_str = tm.group(1) if tm else None
            current_order = {
                'day': current_day,
                'side': side,
                'type': otype,
                'time': time_str,
                'tags': tags,
                'entry': None,  # may be single value
                'entry_hi': None,  # for ranges hi/lo
                'entry_lo': None,
                'sl': None,
                'tp': None,
            }
            continue
        # entry line
        if ln.lower().startswith('en'):
            # format: En: 4020-4022  OR  En: 4038
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
        # SL line
        if ln.lower().startswith('sl'):
            nums = re.findall(r"[-+]?\d+(?:\.\d+)?", ln)
            if nums:
                current_order['sl'] = float(nums[0])
            continue
        # TP line
        if ln.lower().startswith('tp'):
            nums = re.findall(r"[-+]?\d+(?:\.\d+)?", ln)
            if nums:
                current_order['tp'] = float(nums[0])
            continue
    finalize()
    return orders


def expand_legs(orders):
    legs = []
    for od in orders:
        entries = []
        if od.get('entry') is not None:
            entries = [od['entry']]
        elif od.get('entry_lo') is not None and od.get('entry_hi') is not None:
            entries = [od['entry_hi'], od['entry_lo']]  # preserve typical order: higher then lower
        else:
            continue
        for i, en in enumerate(entries, start=1):
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


def summarize(legs, tag_filter=None):
    sel = [l for l in legs if (tag_filter in (None, '') or tag_filter in l['tags'].split(';'))]
    if not sel:
        return None
    sls = [l['sl_dist'] for l in sel if l['sl_dist'] is not None and l['sl_dist'] > 0]
    tps = [l['tp_dist'] for l in sel if l['tp_dist'] is not None and l['tp_dist'] > 0]
    rrs = [l['rr'] for l in sel if l['rr'] is not None]
    return {
        'count': len(sel),
        'sl_mean': round(mean(sls), 3) if sls else None,
        'sl_median': round(median(sls), 3) if sls else None,
        'tp_mean': round(mean(tps), 3) if tps else None,
        'tp_median': round(median(tps), 3) if tps else None,
        'rr_mean': round(mean(rrs), 3) if rrs else None,
        'rr_median': round(median(rrs), 3) if rrs else None,
    }


def main():
    orders = parse_orders(RAW_TEXT)
    legs = expand_legs(orders)
    # write csv
    with open('/workspace/orders_parsed.csv', 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(legs[0].keys()))
        w.writeheader()
        for row in legs:
            w.writerow(row)
    cats = [None, 'ATH', 'scalp', 'high_risk']
    print('Summary of SL/TP distances and RR by category:')
    for cat in cats:
        summ = summarize(legs, tag_filter=cat)
        name = 'overall' if not cat else cat
        print(name, ':', summ)


if __name__ == '__main__':
    main()
