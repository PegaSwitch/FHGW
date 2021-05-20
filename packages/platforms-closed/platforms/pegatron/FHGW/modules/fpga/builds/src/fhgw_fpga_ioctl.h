#ifndef FHGW_FPGA_IOCTL_H
#define FHGW_FPGA_IOCTL_H

#include <linux/ioctl.h>

#define FPGA_ETH_MAX_TX_STATS   70
#define FPGA_ETH_MAX_RX_STATS   70

typedef struct {
    uint32_t tx_stats[FPGA_ETH_MAX_TX_STATS];
    uint32_t rx_stats[FPGA_ETH_MAX_RX_STATS];
} fpga_txrx_stats;

typedef struct {
    uint32_t irq_sts;
} fpga_intr_params;

typedef struct {
    uint8_t linerate;
    uint8_t channel_no;
} fpga_dr_params;

typedef struct {
    uint32_t regaddr;
    uint32_t offset;
    uint32_t value;
    fpga_dr_params dr_params;
    fpga_intr_params intr_params;
    fpga_txrx_stats txrx_stats;
} ioctl_arg_t;

#define FHGW_FPGA_READ_VALUE            _IOR('s', 1, ioctl_arg_t *)
#define FHGW_FPGA_WRITE_VALUE           _IOW('s', 2, ioctl_arg_t *)
#define FHGW_FPGA_DR_INIT               _IOW('s', 3, ioctl_arg_t *)
#define FHGW_FPGA_SERDES_LOOPON         _IOW('s', 4, ioctl_arg_t *)
#define FHGW_FPGA_GENERAL_CALIBRATION   _IOW('s', 5, ioctl_arg_t *)
#define FHGW_FPGA_DYNAMIC_RECONFIG_IP   _IOW('s', 6, ioctl_arg_t *)
#define FHGW_FPGA_EVENT_WAIT            _IOW('s', 7, ioctl_arg_t *)
#define FHGW_FPGA_ETH_READ_STATS        _IOW('s', 8, ioctl_arg_t *)

#endif /* FHGW_FPGA_IOCTL_H */
