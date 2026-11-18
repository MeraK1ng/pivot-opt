#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 编译选项对比实验脚本（不改代码，只换编译选项）
#
# 设计要点：
#   1) 交错执行（第 1 轮跑完所有版本，再跑第 2 轮），而不是一个版本连着跑完
#      —— 能抵消 CPU 升温降频、邻居负载变化带来的系统性漂移
#   2) 每次运行都做 diff 校验，正确性不过关的数据没有意义
#   3) 输出 CSV，交给 analyze.py 算均值和加速比
#
# 用法：
#   chmod +x bench.sh
#   ./bench.sh                       # 每个版本 3 轮
#   ROUNDS=5 ./bench.sh              # 每个版本 5 轮
#   BINS="pivot_O0 pivot_O2" ./bench.sh
#   CPU=2 ./bench.sh                 # 绑定到 2 号核（强烈建议）
# ---------------------------------------------------------------------------
set -u

ROUNDS=${ROUNDS:-3}
BINS=${BINS:-"pivot_O0 pivot_O1 pivot_O2 pivot_O3 pivot_native"}
REF=${REF:-refer-2dim-5h.txt}
CSV=${CSV:-bench.csv}
LOG_DIR=${LOG_DIR:-logs}
CPU=${CPU:-}          # 空 = 不绑核

mkdir -p "$LOG_DIR"
echo "binary,round,time_ms,correct" > "$CSV"

# 记录实验环境，写报告要用
{
    echo "### 实验开始 $(date '+%F %T')"
    echo "host: $(hostname)"
    echo "kernel: $(uname -r)"
    echo "gcc: $(gcc --version | head -1)"
    echo "load: $(cat /proc/loadavg)"
    echo "cpu mhz: $(awk -F: '/MHz/{print $2; exit}' /proc/cpuinfo | xargs)"
    echo "bind core: ${CPU:-none}"
} | tee "$LOG_DIR/environment.txt"

for r in $(seq 1 "$ROUNDS"); do
    for b in $BINS; do
        if [ ! -x "./$b" ]; then
            echo "[跳过] ./$b 不存在，先 make" >&2
            continue
        fi
        log="$LOG_DIR/${b}_r${r}.log"
        if [ -n "$CPU" ] && command -v taskset >/dev/null 2>&1; then
            taskset -c "$CPU" "./$b" > "$log" 2>&1
        else
            "./$b" > "$log" 2>&1
        fi

        # 程序输出形如： Using time : 12345.678900 ms
        ms=$(awk '/Using time/ {print $(NF-1); exit}' "$log")

        if [ -f result.txt ] && diff -q result.txt "$REF" >/dev/null 2>&1; then
            ok=yes
        else
            ok=no
        fi
        cp -f result.txt "$LOG_DIR/${b}_r${r}_result.txt" 2>/dev/null

        echo "$b,$r,${ms:-NA},$ok" >> "$CSV"
        printf '  第 %d 轮 %-14s %12s ms   一致:%s\n' "$r" "$b" "${ms:-NA}" "$ok"
    done
done

echo
echo "明细已写入 $CSV，接着运行： python3 analyze.py"
