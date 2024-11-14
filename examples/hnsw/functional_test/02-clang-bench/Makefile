.PHONY: clean

default: all

clean:
	rm -rf output

output:
	mkdir -p output

build: output/benchmark

output/benchmark: output benchmark.c
	gcc -std=c99 -O3 -o output/benchmark benchmark.c -lsqlite3

all: build run

run: output/benchmark
	./output/benchmark

