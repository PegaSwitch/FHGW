CC = gcc
CFLAGS = -g -Wall

TARGET_APP = fhgw_fpga_app
TARGET_LIB = fhgw_fpga_lib

OBJS = $(TARGET_LIB).o
SRC = $(TARGET_APP).c

BASEDIR = $(shell pwd)/..
INCLUDES = -I $(BASEDIR)/include
LIB_PATH = $(BASEDIR)/lib_code
LIBINCLUDES = $(LIB_PATH)/$(OBJS)
#LIBINCLUDES = 
INC = $(INCLUDES) $(LIBINCLUDES)
 
all:
	$(CC) $(CFLAGS) $(INC) -o $(TARGET_APP) $(SRC)

clean:
	$(RM) $(TARGET_APP)
