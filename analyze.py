#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
读取 bench.sh 产出的 bench.csv，算出每个编译版本的时间统计与加速比。

用法：
    python3 analyze.py                 # 读 bench.csv，基线默认 pivot_O0
    python3 analyze.py bench.csv
    BASE=pivot_O1 python3 analyze.py   # 换基线
输出：
    1) 终端打印 Markdown 表格，可直接贴进说明文件
    2) summary.csv，方便导入 Excel 填记录表
"""
import csv
import os
import statistics
import sys
from collections import defaultdict

path = sys.argv[1] if len(sys.argv) > 1 else "bench.csv"
base = os.environ.get("BASE", "pivot_O0")

rows = defaultdict(list)
bad = defaultdict(int)
with open(path, newline="", encoding="utf-8") as f:
    for rec in csv.DictReader(f):
        if rec["time_ms"] in ("NA", ""):
            bad[rec["binary"]] += 1
            continue
        rows[rec["binary"]].append(float(rec["time_ms"]))
        if rec["correct"].strip().lower() != "yes":
            bad[rec["binary"]] += 1

if not rows:
    sys.exit(f"{path} 里没有可用数据，先跑 ./bench.sh")

baseline = statistics.mean(rows[base]) if base in rows else None
order = [b for b in ["pivot_O0", "pivot_O1", "pivot_O2", "pivot_O3", "pivot_native"] if b in rows]
order += [b for b in rows if b not in order]

print("| 编译选项 | 次数 | 均值(s) | 中位数(s) | 标准差(s) | 离散度 | 加速比 | 结果一致 |")
print("|---|---|---|---|---|---|---|---|")
summary = []
for b in order:
    t = rows[b]
    mean = statistics.mean(t)
    median = statistics.median(t)
    sd = statistics.stdev(t) if len(t) > 1 else 0.0
    cv = sd / mean * 100 if mean else 0
    spd = baseline / mean if baseline else float("nan")
    flag = "OK" if bad.get(b, 0) == 0 else f"{bad[b]} 次异常"
    warn = "  ⚠ 离散度偏高" if cv > 5 else ""
    print(f"| {b.replace('pivot_', '-')} | {len(t)} | {mean/1000:.3f} | {median/1000:.3f} | "
          f"{sd/1000:.3f} | {cv:.1f}%{warn} | {spd:.2f}× | {flag} |")
    summary.append([b, len(t), f"{mean/1000:.3f}", f"{median/1000:.3f}",
                    f"{sd/1000:.3f}", f"{cv:.1f}%", f"{spd:.2f}", flag])

with open("summary.csv", "w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["binary", "runs", "mean_s", "median_s", "stdev_s", "cv", "speedup", "correct"])
    w.writerows(summary)

print("\n已写 summary.csv")
if any(bad.values()):
    print("注意：有版本结果与 refer 不一致，加速比再高也不能用，先查浮点一致性（见教程 7.5）")
