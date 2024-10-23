default: all

.PHONY: clean download

all: download build

build: build/01-compiletest.bin

build/unqlite.c: build/unqlite_amalgamation_119.zip
	unzip -o build/unqlite_amalgamation_119.zip -d build

build/unqlite_amalgamation_119.zip:
	mkdir -p build
	wget -O build/unqlite_amalgamation_119.zip https://symisc.net/unqlite_amalgamation_119.zip

download: build/unqlite_amalgamation_119.zip

build/%.bin: src/%.c build/unqlite.c 
	mkdir -p build
	$(CC) -o $@ $^ -Ibuild -O2 -Wall -Wextra -Werror -Wno-unused-parameter -Wno-unused-function -Wno-unused-variable -Wno-unused-value -Wno-unused-but-set-variable -Wno-unused-label -Wno-unused-result -Wno-unused-const-variable -Wno-unused-local-typedefs -Wno-unused-macros
