#ifndef __H_FHGW_FPGALIB_H__
#define __H_FHGW_FPGALIB_H__

#include <stdio.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/ioctl.h>
#include <stdbool.h>

#define FPGA_SYSTEM_REGISTER_BASE				0x00000000
#define FPGA_SYSTEM_REGISTER_SIZE				0x10000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH0_BASE		0x10000000
#define FPGA_DYNAMIC_RECONFIG_IP_CH0_SIZE		0x04000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH1_BASE		0x10800000
#define FPGA_DYNAMIC_RECONFIG_IP_CH1_SIZE		0x04000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH2_BASE		0x11000000
#define FPGA_DYNAMIC_RECONFIG_IP_CH2_SIZE		0x04000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH3_BASE		0x11800000
#define FPGA_DYNAMIC_RECONFIG_IP_CH3_SIZE		0x04000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH4_BASE		0x20000000
#define FPGA_DYNAMIC_RECONFIG_IP_CH4_SIZE		0x04000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH5_BASE		0x20800000
#define FPGA_DYNAMIC_RECONFIG_IP_CH5_SIZE		0x04000000

#define FPGA_ALDRIN_SIDE_ETHER_CH0_BASE			0x14000000
#define FPGA_ALDRIN_SIDE_ETHER_CH0_SIZE			0x04000000

#define FPGA_ALDRIN_SIDE_ETHER_CH1_BASE			0x14800000
#define FPGA_ALDRIN_SIDE_ETHER_CH1_SIZE			0x04000000

#define FPGA_ALDRIN_SIDE_ETHER_CH2_BASE			0x15000000
#define FPGA_ALDRIN_SIDE_ETHER_CH2_SIZE			0x04000000

#define FPGA_ALDRIN_SIDE_ETHER_CH3_BASE			0x15800000
#define FPGA_ALDRIN_SIDE_ETHER_CH3_SIZE			0x04000000

#define FPGA_ALDRIN_SIDE_ETHER_CH4_BASE			0x24000000
#define FPGA_ALDRIN_SIDE_ETHER_CH4_SIZE			0x04000000

#define FPGA_ALDRIN_SIDE_ETHER_CH5_BASE			0x24800000
#define FPGA_ALDRIN_SIDE_ETHER_CH5_SIZE			0x04000000

#define FPGA_ROE_CH0_BASE						0x30000000
#define FPGA_ROE_CH0_SIZE						0x00010000

#define FPGA_ROE_CH1_BASE						0x30010000
#define FPGA_ROE_CH1_SIZE						0x00010000

#define FPGA_ROE_CH2_BASE						0x30020000
#define FPGA_ROE_CH2_SIZE						0x00010000

#define FPGA_ROE_CH3_BASE						0x30030000
#define FPGA_ROE_CH3_SIZE						0x00010000

#define FPGA_ROE_CH4_BASE						0x30040000
#define FPGA_ROE_CH4_SIZE						0x00010000

#define FPGA_ROE_CH5_BASE						0x30050000
#define FPGA_ROE_CH5_SIZE						0x00010000

#define FPGA_SCRATCH_PAD				0x0000
#define FPGA_REVISION					0x0004
#define FPGA_LED_CONTROL_CPRI			0x0008
#define FPGA_LED_CONTROL_USER			0x000C
#define FPGA_INTERRUPT_STATUS			0x0010

#define FPGA_VERSION_MINOR				0x0
#define FPGA_VERSION_MAJOR				0x1 << 0x8
			
#define FPGA_LED_CPRI_0_CTRL			0x0
#define FPGA_LED_CPRI_1_CTRL			0x1 << 0x2
#define FPGA_LED_CPRI_2_CTRL			0x1 << 0x4
#define FPGA_LED_CPRI_3_CTRL			0x1 << 0x6
#define FPGA_LED_CPRI_4_CTRL			0x1 << 0x8
#define FPGA_LED_CPRI_5_CTRL			0x1 << 0xA

#define FPGA_LED_USER_0_CTRL			0x0
#define FPGA_LED_USER_1_CTRL			0x1 << 0x2
#define FPGA_LED_USER_2_CTRL			0x1 << 0x4
#define FPGA_LED_USER_3_CTRL			0x1 << 0x6
#define FPGA_LED_USER_4_CTRL			0x1 << 0x8

#define FPGA_INTR_LINK_DOWN				0x0
#define FPGA_INTR_ROE					0x1 << 0x10

#define FPGA_DATAPATH_LINERATE			0x0
#define FPGA_DATAPATH_SEL				0x1 << 0x3

#define FPGA_LOOPBACK_SEL				0x0

#define FPGA_DR_STATUS_EHIP_READY		0x0
#define FPGA_DR_STATUS_RX_LOCK			0x1 << 0x1
#define FPGA_DR_STATUS_TX_LOCK			0x1 << 0x2
#define FPGA_DR_STATUS_RX_READY			0x1 << 0x3
#define FPGA_DR_STATUS_TX_PTP_READY		0x1 << 0x4
#define FPGA_DR_STATUS_RX_PTP_READY		0x1 << 0x5

#define FPGA_ETH_STATUS_EHIP_READY		0x0
#define FPGA_ETH_STATUS_RX_LOCK			0x1 << 0x1
#define FPGA_ETH_STATUS_TX_LOCK			0x1 << 0x2
#define FPGA_ETH_STATUS_RX_READY		0x1 << 0x3
#define FPGA_ETH_STATUS_TX_PTP_READY	0x1 << 0x4
#define FPGA_ETH_STATUS_RX_PTP_READY	0x1 << 0x5

#define FPGA_RECONFIG_RESET				0x0
#define FPGA_SL_RX_RSTN					0x1 << 0x1
#define FPGA_SL_TX_RSTN					0x1 << 0x2
#define FPGA_CSR_RSTN					0x1 << 0x3
#define FPGA_EFIFO_RESET_N				0x1 << 0x4
#define FPGA_TUNNELING_ENALED			0x1 << 0xA

#define FPGA_REC_CLK_SEL				0x0

#define FPGA_MODE_SEL_CH0				0x10000
#define FPGA_LOOPBACK_SEL_CH0			0x10004
#define FPGA_DATAPATH_STATUS_DR_CH0		0x10008
#define FPGA_DATAPATH_STATUS_ETH_CH0	0x1000C
#define FPGA_DATAPATH_CTRL_CH0			0x10010
#define FPGA_REC_CLK_SEL_CH0			0x10014

#define FPGA_MODE_SEL_CH1				0x20000
#define FPGA_LOOPBACK_SEL_CH1			0x20004
#define FPGA_DATAPATH_STATUS_DR_CH1		0x20008
#define FPGA_DATAPATH_STATUS_ETH_CH1	0x2000C
#define FPGA_DATAPATH_CTRL_CH1			0x20010
#define FPGA_REC_CLK_SEL_CH1			0x20014

#define FPGA_MODE_SEL_CH2				0x30000
#define FPGA_LOOPBACK_SEL_CH2			0x30004
#define FPGA_DATAPATH_STATUS_DR_CH2		0x30008
#define FPGA_DATAPATH_STATUS_ETH_CH2	0x3000C
#define FPGA_DATAPATH_CTRL_CH2			0x30010
#define FPGA_REC_CLK_SEL_CH2			0x30014

#define FPGA_MODE_SEL_CH3				0x40000
#define FPGA_LOOPBACK_SEL_CH3			0x40004
#define FPGA_DATAPATH_STATUS_DR_CH3		0x40008
#define FPGA_DATAPATH_STATUS_ETH_CH3	0x4000C
#define FPGA_DATAPATH_CTRL_CH3			0x40010
#define FPGA_REC_CLK_SEL_CH3			0x40014

#define FPGA_MODE_SEL_CH4				0x50000
#define FPGA_LOOPBACK_SEL_CH4			0x50004
#define FPGA_DATAPATH_STATUS_DR_CH4		0x50008
#define FPGA_DATAPATH_STATUS_ETH_CH4	0x5000C
#define FPGA_DATAPATH_CTRL_CH4			0x50010
#define FPGA_REC_CLK_SEL_CH4			0x50014

#define FPGA_MODE_SEL_CH5				0x60000
#define FPGA_LOOPBACK_SEL_CH5			0x60004
#define FPGA_DATAPATH_STATUS_DR_CH5		0x60008
#define FPGA_DATAPATH_STATUS_ETH_CH5	0x6000C
#define FPGA_DATAPATH_CTRL_CH5			0x60010
#define FPGA_REC_CLK_SEL_CH5			0x60014

typedef enum {
    FPGA_RET_FAILED = -1,
    FPGA_RET_SUCCESS,
} ret;

typedef enum {
    LED_OFF,
    LED_BLINK,
    LED_ON,
} led_ctrl;

typedef enum {
    LED_CPRI0,
    LED_CPRI1,
    LED_CPRI2,
    LED_CPRI3,
    LED_CPRI4,
    LED_CPRI5,
    LED_USR0,
    LED_USR1,
    LED_USR2,
    LED_USR3,
    LED_USR4,
} ledno;

struct roe_agn_mode 
{
    bool en_agn_mode;
    bool en_str_agn_mode_tunl;
};

typedef enum {
	E25G_PTP_FEC,
	CPRI_9p8G_tunneling,
	CPRI_4p9G_tunneling,
	CPRI_2p4G_tunneling,
	CPRI_10G_TUNNEL,
} port_mode;

typedef enum {
	no_loopback,
	loopback_portside,
	loopback_switchside,
	roe_loopback,
} loopback_mode;

typedef enum {
	ETH_PORT0,
	ETH_PORT1,
	ETH_PORT2,
	ETH_PORT3,
	ETH_PORT4,
	ETH_PORT5,
	CPRI_PORT0,
	CPRI_PORT1,
	CPRI_PORT2,
	CPRI_PORT3,
	CPRI_PORT4,
	CPRI_PORT5,
} port_no;

int32_t fpga_dev_open();
void fpga_dev_close();

int32_t fpga_reg_read(int32_t block, int32_t offset);
int32_t fpga_reg_write(int32_t block, int32_t offset, int32_t value);

void set_fheth_tx_mac_address(int32_t portno, void *addr);

void *fheth_get_port_speed(int32_t portno);
void *fheth_set_port_speed(int32_t portno);

void *fheth_get_tx_stats(int32_t portno);
void *fheth_get_rx_stats(int32_t portno);

int32_t get_cpri_port_mode(int32_t  portno);
int32_t set_cpri_port_mode(int32_t  portno, int32_t port_mode);

int32_t set_loopback_mode(int32_t  portno, int32_t loopback_mode);

void *get_roe_srcaddress(int32_t portno);
int32_t set_roe_srcaddress(int32_t portno, void *addr);
char *get_roe_dstaddress(int32_t portno, void *addr);
int32_t set_roe_dstaddress(int32_t portno, void *addr);
int32_t get_roe_flowId(int32_t portno);
int32_t set_roe_flowid(int32_t portno, int32_t flowid);

struct roe_agn_mode *get_roe_agnostic_mode(int32_t portno);
int32_t set_roe_agnostic_mode(int32_t portno, struct roe_agn_mode *agm);

int32_t fhgw_led_ctrl(int32_t ledno, int32_t led_ctrl);

int32_t get_fpga_rev_ver();
int32_t rd_scratch_pad_reg();
int32_t wr_scratch_pad_reg(int32_t scr_val);
int32_t fhgw_intr_status_reg();

#endif
