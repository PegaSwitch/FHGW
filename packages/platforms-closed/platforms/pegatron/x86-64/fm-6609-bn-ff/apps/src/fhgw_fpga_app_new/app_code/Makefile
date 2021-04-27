CC = gcc
CFLAGS = -g -Wall

TARGET_APP = fhgw_fpga_dr_test_app
TARGET_LIB = fhgw_fpga_lib

OBJS = $(TARGET_LIB).o
SRC = $(TARGET_APP).c

BASEDIR = $(shell pwd)/..
INCLUDES = -I $(BASEDIR)/include
LIB_PATH = $(BASEDIR)/lib_code
LIBINCLUDES = $(LIB_PATH)/$(OBJS)
#LIBINCLUDES =
LIBS = -lpthread 
INC = $(INCLUDES) $(LIBINCLUDES)
 
all:
	$(CC) $(CFLAGS) $(INC) $(LIBS) -o $(TARGET_APP) $(SRC)

clean:
	$(RM) $(TARGET_APP)

