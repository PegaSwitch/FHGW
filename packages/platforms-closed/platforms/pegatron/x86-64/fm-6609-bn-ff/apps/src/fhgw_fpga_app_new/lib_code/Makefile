CC = gcc
CFLAGS = -g -Wall
TARGET_LIB = fhgw_fpga_lib

SRC = $(TARGET_LIB).c

BASEDIR = $(shell pwd)/..
INCLUDES = -I $(BASEDIR)/include
LIBINCLUDES = 
INC = $(INCLUDES) $(LIBINCLUDES)

all: 
	$(CC) $(CFLAGS) $(INC) -c $(SRC)
   
clean:
	$(RM) $(TARGET_LIB).o
