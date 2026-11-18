CC     = gcc
LIBS   = -lm
SRC    = pivot.c

BINS   = pivot_O0 pivot_O1 pivot_O2 pivot_O3 pivot_native

.PHONY: all clean

# 默认就编 -O2，和赛题参考命令一致
all: pivot_O2
	@echo "已生成 ./pivot_O2 ，运行： ./pivot_O2"

pivot_O0: $(SRC)
	$(CC) -O0 -o $@ $< $(LIBS)

pivot_O1: $(SRC)
	$(CC) -O1 -o $@ $< $(LIBS)

pivot_O2: $(SRC)
	$(CC) -O2 -o $@ $< $(LIBS)

pivot_O3: $(SRC)
	$(CC) -O3 -o $@ $< $(LIBS)

# -march=native 会针对当前 CPU 生成指令（可能启用 AVX2/AVX-512 与 FMA）
pivot_native: $(SRC)
	$(CC) -O3 -march=native -o $@ $< $(LIBS)

clean:
	rm -f pivot pivot_O0 pivot_O1 pivot_O2 pivot_O3 pivot_native result.txt
