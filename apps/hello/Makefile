ROOT_PATH=../..
CC=$(ROOT_PATH)/build/bin/clang
LIBLDB=$(ROOT_PATH)/libldb/libldb.a
CFLAGS=-g -O3 -fno-omit-frame-pointer -fno-optimize-sibling-calls -fdebug-default-version=3 -I$(ROOT_PATH)/libldb/include

.PHONY: all
all: hello

hello: hello.c $(LIBLDB)
	$(CC) $(CFLAGS) $^ -lpthread -o $@
