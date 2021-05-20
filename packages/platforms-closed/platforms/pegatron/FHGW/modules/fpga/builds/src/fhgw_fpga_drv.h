#ifndef FHGW_FPGA_DRV_H__
#define FHGW_FPGA_DRV_H__

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/stddef.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/pci.h>
#include <linux/kthread.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>
#include <linux/delay.h>
#include <linux/kfifo.h>
#include <linux/workqueue.h>
#include <linux/interrupt.h>
#include <linux/irq.h>
#include <asm/irq.h>

#define FHGW_FPGA_VENDOR_ID 		0x1172
#define FHGW_FPGA_DEVICE_ID 		0x0000
#define ANY_ID_ 					(~0)

#define FHGW_FPGA_DRV_VERSION       1
#define FHGW_FPGA_DRV_SUBVERSION    0

#define FHGW_MAXDR_CHANNELS         6
#define FHGW_TIMEOUT_VALUE          1000

#define FHGW_FPGA_REG_SIZE		                0x40000000	/* 1024 MB */

#define FPGA_SYSTEM_REGISTER_BASE				0x00000000
#define FPGA_SYSTEM_REGISTER_SIZE				0x10000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH0_BASE		0x10000000
#define FPGA_DYNAMIC_RECONFIG_IP_CH0_SIZE		0x08000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH1_BASE		0x10800000
#define FPGA_DYNAMIC_RECONFIG_IP_CH1_SIZE		0x08000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH2_BASE		0x11000000
#define FPGA_DYNAMIC_RECONFIG_IP_CH2_SIZE		0x08000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH3_BASE		0x11800000
#define FPGA_DYNAMIC_RECONFIG_IP_CH3_SIZE		0x08000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH4_BASE		0x20000000
#define FPGA_DYNAMIC_RECONFIG_IP_CH4_SIZE		0x08000000

#define FPGA_DYNAMIC_RECONFIG_IP_CH5_BASE		0x20800000
#define FPGA_DYNAMIC_RECONFIG_IP_CH5_SIZE		0x08000000

#define FPGA_ALDRIN_SIDE_ETHER_CH0_BASE			0x14000000
#define FPGA_ALDRIN_SIDE_ETHER_CH0_SIZE			0x08000000

#define FPGA_ALDRIN_SIDE_ETHER_CH1_BASE			0x14800000
#define FPGA_ALDRIN_SIDE_ETHER_CH1_SIZE			0x08000000

#define FPGA_ALDRIN_SIDE_ETHER_CH2_BASE			0x15000000
#define FPGA_ALDRIN_SIDE_ETHER_CH2_SIZE			0x08000000

#define FPGA_ALDRIN_SIDE_ETHER_CH3_BASE			0x15800000
#define FPGA_ALDRIN_SIDE_ETHER_CH3_SIZE			0x08000000

#define FPGA_ALDRIN_SIDE_ETHER_CH4_BASE			0x24000000
#define FPGA_ALDRIN_SIDE_ETHER_CH4_SIZE			0x08000000

#define FPGA_ALDRIN_SIDE_ETHER_CH5_BASE			0x24800000
#define FPGA_ALDRIN_SIDE_ETHER_CH5_SIZE			0x08000000

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

#define FHGW_DR_GROUP1_BASE_ADDR            0x10000000
#define FHGW_DR_GROUP2_BASE_ADDR            0x20000000

#define FHGW_C3_ELANE_RECONFIG_CH0          (0x00000000 << 2)
#define FHGW_C3_XCVR_RECONFIG_CH0           (0x00100000 << 2)
#define FHGW_ELANE_AVMM_FRAMEGENCHK_CH0     (0x00001000 << 2)
#define FHGW_CPRI_AVMM_CONFIG_CH0           (0x00003000 << 2)
#define FHGW_RSFEC_AVMM_CONFIG_CH0          (0x00010000 << 2)

#define FHGW_C3_ELANE_RECONFIG_CH1          (0x00000000 << 2) + (0x200000 << 2)
#define FHGW_C3_XCVR_RECONFIG_CH1           (0x00100000 << 2) + (0x200000 << 2)
#define FHGW_ELANE_AVMM_FRAMEGENCHK_CH1     (0x00001000 << 2) + (0x200000 << 2)
#define FHGW_CPRI_AVMM_CONFIG_CH1           (0x00003000 << 2) + (0x200000 << 2)
#define FHGW_RSFEC_AVMM_CONFIG_CH1          (0x00010000 << 2) + (0x200000 << 2)

#define FHGW_C3_ELANE_RECONFIG_CH2          (0x00000000 << 2) + (0x400000 << 2)
#define FHGW_C3_XCVR_RECONFIG_CH2           (0x00100000 << 2) + (0x400000 << 2)
#define FHGW_ELANE_AVMM_FRAMEGENCHK_CH2     (0x00001000 << 2) + (0x400000 << 2)
#define FHGW_CPRI_AVMM_CONFIG_CH2           (0x00003000 << 2) + (0x400000 << 2)
#define FHGW_RSFEC_AVMM_CONFIG_CH2          (0x00010000 << 2) + (0x400000 << 2)

#define FHGW_C3_ELANE_RECONFIG_CH3          (0x00000000 << 2) + (0x600000 << 2)
#define FHGW_C3_XCVR_RECONFIG_CH3           (0x00100000 << 2) + (0x600000 << 2)
#define FHGW_ELANE_AVMM_FRAMEGENCHK_CH3     (0x00001000 << 2) + (0x600000 << 2)
#define FHGW_CPRI_AVMM_CONFIG_CH3           (0x00003000 << 2) + (0x600000 << 2)
#define FHGW_RSFEC_AVMM_CONFIG_CH3          (0x00010000 << 2) + (0x600000 << 2)

#define FHGW_C3_ELANE_RECONFIG_CH4          (0x00000000 << 2)
#define FHGW_C3_XCVR_RECONFIG_CH4           (0x00100000 << 2)
#define FHGW_ELANE_AVMM_FRAMEGENCHK_CH4     (0x00001000 << 2)
#define FHGW_CPRI_AVMM_CONFIG_CH4           (0x00003000 << 2)
#define FHGW_RSFEC_AVMM_CONFIG_CH4          (0x00010000 << 2)

#define FHGW_C3_ELANE_RECONFIG_CH5          (0x00000000 << 2) + (0x200000 << 2)
#define FHGW_C3_XCVR_RECONFIG_CH5           (0x00100000 << 2) + (0x200000 << 2)
#define FHGW_ELANE_AVMM_FRAMEGENCHK_CH5     (0x00001000 << 2) + (0x200000 << 2)
#define FHGW_CPRI_AVMM_CONFIG_CH5           (0x00003000 << 2) + (0x200000 << 2)
#define FHGW_RSFEC_AVMM_CONFIG_CH5          (0x00010000 << 2) + (0x200000 << 2)

#define FHGW_FPGA_PHY_EHIP_PCS_MODES                0x30E
#define FHGW_FPGA_TXMAC_EHIP_CFG                    0x40B

#define FHGW_FPGA_NO_SHIFT_OPS              0x0

#define FHGW_FPGA_REG_READ(base, regbase, offset)           fhgw_fpga_read_data(base, regbase, offset)
#define FHGW_FPGA_REG_WRITE(base, regbase, offset, value)   fhgw_fpga_write_data(base, regbase, offset, value)

#define FHGW_FPGA_ETH_TX_STATS  0x1
#define FHGW_FPGA_ETH_RX_STATS  0x2

#define KFIFO_BUFFER_SIZE       1024

struct semaphore fpga_sem;

typedef struct {    
    int irq_sts;
} fpga_irq_info;
fpga_irq_info irq_info;

typedef struct {
    struct workqueue_struct *irq_wq;
} fhgw_fpga_work_queue;
fhgw_fpga_work_queue *fpga_wq = NULL;

typedef struct {
    struct work_struct irq_work;
} irq_intr_work;
irq_intr_work *pirq_work;

/* Wait queue for events to wait on single wait queue */
static wait_queue_head_t event_queue;

/* kfifo for the event */
struct kfifo event_rxkfifo;

struct fhgw_fpga_dev {
    struct pci_dev *pdev;
    void __iomem *regs;

    // Data to for MSI completion
    int msi_capability;         // Offset of MSI capability
    uint64_t interrupt_addr;    // Address to trigger MSI interrupt
    uint32_t interrupt_data;    // Data to be sent with interrupt packet
    unsigned int irq;

    dev_t devno;
    struct cdev cdev;
    struct device* chardev;
};

typedef struct {
    uint32_t eth_base_addr;
    uint32_t xcvr_base_addr;
    uint32_t rsfec_base_addr;
    uint32_t cprisoft_base_addr;
} fpga_address;

typedef enum {
    FHGW_FPGA_DR_CH0 = 0,
    FHGW_FPGA_DR_CH1,
    FHGW_FPGA_DR_CH2,
    FHGW_FPGA_DR_CH3,
    FHGW_FPGA_DR_CH4,
    FHGW_FPGA_DR_CH5,
} channel_no;

typedef enum {
    E25G_PTP_FEC = 1,
    CPRI_9p8G_tunneling,
    CPRI_4p9G_tunneling,
    CPRI_2p4G_tunneling,
    CPRI_10G_TUNNEL,
} port_mode;

static irqreturn_t fhgw_fpga_msi_complete(int irq, void *dev_bk);
static int fhgw_fpga_pcie_intr_probe(struct pci_dev *pdev);
int32_t fhgw_fpga_read_data(void __iomem *base, uint32_t regbase, uint32_t offset);
void fhgw_fpga_write_data(void __iomem *base, uint32_t regbase, uint32_t offset, uint32_t value);
int32_t fhgw_fpga_dr_init(void);
int32_t fhgw_25gptpfec_to_2p4gcpri(uint8_t channel_no, uint32_t eth_base_addr, uint32_t xcvr_base_addr, uint32_t rsfec_base_addr, uint32_t cprisoft_base_addr);
int32_t fhgw_2p4gcpri_to_2p4gtunneling(uint8_t channel_no, uint32_t eth_base_addr, uint32_t xcvr_base_addr, uint32_t rsfec_base_addr, uint32_t cprisoft_base_addr);
int32_t flow_25gptpfec_to_4p9gcpri(uint8_t channel_no, uint32_t eth_base_addr, uint32_t xcvr_base_addr, uint32_t rsfec_base_addr, uint32_t cprisoft_base_addr);
int32_t fhgw_4p9gcpri_to_4p9gtunneling(uint8_t channel_no, uint32_t eth_base_addr, uint32_t xcvr_base_addr, uint32_t rsfec_base_addr, uint32_t cprisoft_base_addr);
int32_t fhgw_25gptpfec_to_9p8gcpri(uint8_t channel_no, uint32_t eth_base_addr, uint32_t xcvr_base_addr, uint32_t rsfec_base_addr, uint32_t cprisoft_base_addr);
int32_t fhgw_9p8gcpri_to_9p8gtunneling(uint8_t channel_no, uint32_t eth_base_addr, uint32_t xcvr_base_addr, uint32_t rsfec_base_addr, uint32_t cprisoft_base_addr);
int32_t fhgw_25gptpfec_to_10gcpri(uint8_t channel_no, uint32_t eth_base_addr, uint32_t xcvr_base_addr, uint32_t rsfec_base_addr, uint32_t cprisoft_base_addr);
int32_t fhgw_10gcpri_to_10gcpritunnel(uint8_t channel_no, uint32_t eth_base_addr, uint32_t xcvr_base_addr, uint32_t rsfec_base_addr, uint32_t cprisoft_base_addr);

#endif /* FHGW_FPGA_DRV_H */
