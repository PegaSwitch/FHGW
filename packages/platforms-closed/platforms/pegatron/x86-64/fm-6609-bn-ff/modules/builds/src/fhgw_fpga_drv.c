#include "fhgw_fpga_drv.h"
#include "fhgw_fpga_ioctl.h"

dev_t devbase;
char fhgw_fpga_driver_name[] = "pci-fpga";
static struct class* fhgw_fpga_drv_class;

struct fhgw_fpga_dev *fpga_dev;

uint32_t fhgw_dp_ctrl[] = {
    FPGA_DATAPATH_CTRL_CH0,
    FPGA_DATAPATH_CTRL_CH1,
    FPGA_DATAPATH_CTRL_CH2,
    FPGA_DATAPATH_CTRL_CH3,
    FPGA_DATAPATH_CTRL_CH4,
    FPGA_DATAPATH_CTRL_CH5,
};

uint32_t fhgw_dp_status[] = {
    FPGA_DATAPATH_STATUS_DR_CH0,
    FPGA_DATAPATH_STATUS_DR_CH1,
    FPGA_DATAPATH_STATUS_DR_CH2,
    FPGA_DATAPATH_STATUS_DR_CH3,
    FPGA_DATAPATH_STATUS_DR_CH4,
    FPGA_DATAPATH_STATUS_DR_CH5,
};

uint32_t fhgw_dr_mode[] = {
    FPGA_MODE_SEL_CH0,
    FPGA_MODE_SEL_CH1,
    FPGA_MODE_SEL_CH2,
    FPGA_MODE_SEL_CH3,
    FPGA_MODE_SEL_CH4,
    FPGA_MODE_SEL_CH5,
};

static const struct pci_device_id fhgw_fpga_id_table[] = {
    { PCI_DEVICE(FHGW_FPGA_VENDOR_ID, FHGW_FPGA_DEVICE_ID), },
    { }, /* all-zero terminator sentinel */
};
MODULE_DEVICE_TABLE(pci, fhgw_fpga_id_table);

int32_t fhgw_fpga_read_data(void __iomem *base, uint32_t regbase, uint32_t offset)
{
    int32_t regVal = readl(base + regbase + (offset << 0x2));
    //printk("\n DRV DBG Read Address : 0x%x, Value : 0x%x", (base + regbase + (offset << 0x2)), regVal);
    return regVal;
}

void fhgw_fpga_write_data(void __iomem *base, uint32_t regbase, uint32_t offset, uint32_t value)
{
    writel(value, (base + regbase + (offset << 0x2)));
    //printk("\n DRV DBG Write Address : 0x%x, Value : 0x%x", (base + regbase + (offset << 0x2)), value);
}

void fhgw_fpga_read_stats(uint8_t option, fpga_txrx_stats *stats)
{
    uint32_t offset = 0;

    if (option == FHGW_FPGA_ETH_TX_STATS) {
        for (offset = 0; offset < 0; offset += 4) {
            stats->tx_stats[offset] = 0/* FPGA_READ */;
        }
    } else {
        for (offset = 0; offset < 0; offset += 4) {
            stats->rx_stats[offset] = 0/* FPGA READ */;
        }
    }
}

static inline uint8_t fghw_fpga_get_drmode(uint8_t channel_no)
{
    int32_t regVal = FHGW_FPGA_REG_READ(fpga_dev->regs, fhgw_dr_mode[channel_no], FHGW_FPGA_NO_SHIFT_OPS);

    if (regVal & CPRI_2p4G_tunneling)
        return CPRI_2p4G_tunneling;
    else if (regVal & CPRI_4p9G_tunneling)
        return CPRI_4p9G_tunneling;
    else if (regVal & CPRI_9p8G_tunneling)
        return CPRI_9p8G_tunneling;
    else if (regVal & CPRI_10G_TUNNEL)
        return CPRI_10G_TUNNEL;
    else if (regVal & E25G_PTP_FEC)
        return E25G_PTP_FEC;

    return 0;
}

static inline void fghw_fpga_set_drmode(uint8_t channel_no, uint8_t dr_mode)
{
    int32_t regVal = FHGW_FPGA_REG_READ(fpga_dev->regs, fhgw_dr_mode[channel_no], FHGW_FPGA_NO_SHIFT_OPS);
    regVal |= dr_mode;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, fhgw_dr_mode[channel_no], FHGW_FPGA_NO_SHIFT_OPS, regVal);
}

int8_t fhgw_fpga_enable_rsfec(uint32_t rsfec_base_addr, uint8_t channel_no)
{
    uint32_t rdata0;
    uint32_t wdata;

    if (channel_no == 0) {
        //i rsfec_top_clk_cfg
        // fec_lane_ena xx0x -> xx1x
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x5);
        // Single lane - lane 1
        wdata = (rdata0 & 0xFFFFFFFD) | 0x2;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x5, wdata);


        //ii rsfec_top_tx_cfg
        // Single lane - lane 3
        // core_tx_in_sel1 [6:4]  110 -> 001
        // 3'b110 : FEC Lane Disabled - tie inputs to 0
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x10);
        wdata = (rdata0 & 0xFFFFFF8F) | 0x10;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x10, wdata);

        //iii rsfec_top_rx_cfg
        // core_rx_out_sel3 [13:12]
        // core_rx_out_sel2 [9:8]
        // core_rx_out_sel1 [5:4] 00 -> 01
        // core_rx_out_sel0 [1:0]
        // Binary to Mask: 1100 1100 1100 1100
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x14);
        wdata = (rdata0 & 0xFFFFFFCF) | 0x10;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x14, wdata);
        return 0;
    } else if (channel_no == 1) {
        //i rsfec_top_clk_cfg
        // fec_lane_ena x0xx -> x1xx
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x5);
        // Single lane - lane 2
        wdata = (rdata0 & 0xFFFFFFFB) | 0x4;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x5, wdata);


        //ii rsfec_top_tx_cfg
        // Single lane - lane 2
        // core_tx_in_sel2 [10:8]  110 -> 001
        // 3'b110 : FEC Lane Disabled - tie inputs to 0
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x11);
        wdata = (rdata0 & 0xFFFFFFF8) | 0x01;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x11, wdata);

        //iii rsfec_top_rx_cfg
        // core_rx_out_sel3 [13:12]
        // core_rx_out_sel2 [9:8] 00 -> 01
        // core_rx_out_sel1 [5:4]
        // core_rx_out_sel0 [1:0]
        // Binary to Mask: 1100 1100 1100 1100
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x15);
        wdata = (rdata0 & 0xFFFFFFFC) | 0x01;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x15, wdata);
        return 0;
    } else if (channel_no == 2) {
        //i rsfec_top_clk_cfg
        // fec_lane_ena 0xxx -> 1xxx
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x5);
        // Single lane - lane 3
        wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x5, wdata);


        //ii rsfec_top_tx_cfg
        // Single lane - lane 3
        // core_tx_in_sel3 [14:12]  110 -> 001
        // 3'b110 : FEC Lane Disabled - tie inputs to 0
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x11);
        wdata = (rdata0 & 0xFFFFFF8F) | 0x10;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x11, wdata);

        //iii rsfec_top_rx_cfg
        // core_rx_out_sel3 [13:12] 00 -> 01
        // core_rx_out_sel2 [9:8]
        // core_rx_out_sel1 [5:4]
        // core_rx_out_sel0 [1:0]
        // Binary to Mask: 1100 1100 1100 1100
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x15);
        wdata = (rdata0 & 0xFFFFFFCF) | 0x10;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x15, wdata);
        return 0;
    }
    else {
        return 1;
    }
}

int8_t fhgw_fpga_disable_rsfec(uint32_t rsfec_base_addr, uint8_t channel_no)
{
    uint32_t rdata0;
    uint32_t wdata;

    if (channel_no == 0) {
        //i rsfec_top_clk_cfg
        // fec_lane_ena xx1x -> xx0x
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x5);
        // Single lane - lane 1
        wdata = (rdata0 & 0xFFFFFFFD) | 0x0;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x5, wdata);

        //ii rsfec_top_tx_cfg
        // core_tx_in_sel1 [6:4] 001 -> 110
        // 3'b110 : FEC Lane Disabled - tie inputs to 0
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x10);
        wdata = (rdata0 & 0xFFFFFF8F) | 0x60;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x10, wdata);

        //iii rsfec_top_rx_cfg
        // core_rx_out_sel3 [13:12]
        // core_rx_out_sel2 [9:8]
        // core_rx_out_sel1 [5:4] 01 -> 00
        // core_rx_out_sel0 [1:0]
        // Binary to Mask: 1100 1100 1100 1100
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x14);
        wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x14, wdata);
        return 0;
    } else if (channel_no == 1) {
        //i rsfec_top_clk_cfg
        // fec_lane_ena x1xx -> x0xx
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x5);
        // Single lane - lane 2
        wdata = (rdata0 & 0xFFFFFFFB) | 0x0;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x5, wdata);

        //ii rsfec_top_tx_cfg
        // core_tx_in_sel2 [10:8] 001 -> 110
        // 3'b110 : FEC Lane Disabled - tie inputs to 0
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x11);
        wdata = (rdata0 & 0xFFFFFFF8) | 0x06;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x11, wdata);

        //iii rsfec_top_rx_cfg
        // core_rx_out_sel3 [12:13]
        // core_rx_out_sel2 [9:8] 01 -> 00
        // core_rx_out_sel1 [5:4]
        // core_rx_out_sel0 [1:0]
        // Binary to Mask: 1100 1100 1100 1100
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x15);
        wdata = (rdata0 & 0xFFFFFFFC) | 0x0;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x15, wdata);
        return 0;
    } else if (channel_no == 2) {
        //i rsfec_top_clk_cfg
        // fec_lane_ena 1xxx -> 0xxx
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x5);
        // Single lane - lane 3
        wdata = (rdata0 & 0xFFFFFFF7) | 0x0;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x5, wdata);

        //ii rsfec_top_tx_cfg
        // core_tx_in_sel3 [14:12] 001 -> 110
        // 3'b110 : FEC Lane Disabled - tie inputs to 0
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x11);
        wdata = (rdata0 & 0xFFFFFF8F) | 0x60;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x11, wdata);

        //iii rsfec_top_rx_cfg
        // core_rx_out_sel3 [12:13] 01 -> 00
        // core_rx_out_sel2 [9:8]
        // core_rx_out_sel1 [5:4]
        // core_rx_out_sel0 [1:0]
        // Binary to Mask: 1100 1100 1100 1100
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, rsfec_base_addr, 0x15);
        wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, rsfec_base_addr, 0x15, wdata);
        return 0;
    } else {
        return 1;
    }
}

int32_t fhgw_fpga_polling_for_cal_bit (uint32_t xcvr_base_addr, uint32_t reg_num, uint16_t bit_num)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    int32_t iteration = 5000;
    int32_t i = 0;
    //Calibration Register polling : CHK 204 and 207
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);

    if (bit_num == 7) {
        while (((rdata0 & 0x80) != 0x80) && (i < iteration)) {
            i = i + 1;
            rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);
        }
    } else {
        while (((rdata0 & 0x01) != 0x01) && (i < iteration)) {
            i = i + 1;
            rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);
        }
    }

    if (i == iteration) {
        printk ("ERROR: Polling for xcvr cal bit register %lx failed\n", reg_num);
        return_value = 1;
    }
    udelay(2);

    return return_value;
}

int32_t fhgw_fpga_polling_for_cfg_bit (uint32_t xcvr_base_addr, uint32_t reg_num, uint16_t bit_num)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    int32_t iteration = 5000;
    int32_t i = 0;
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);

    if (bit_num == 7) {
        while (((rdata0 & 0x80) != 0x80) && (i < iteration)) {
            i = i + 1;
            rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);
        }
    } else {
        while (((rdata0 & 0x01) != 0x00) && (i < iteration)) {
            i = i + 1;
            rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);
        }
    }

    if (i == iteration) {
        printk ("ERROR: Polling for xcvr cfg bit register %lx failed\n", reg_num);
        return_value = 1;
    }
    udelay(2);

    return return_value;
}

int32_t fhgw_fpga_polling_for_cfg_value_compare (uint32_t xcvr_base_addr, uint32_t reg_num, uint16_t compare_value)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    int32_t iteration = 5000;
    int32_t i = 0;
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);

    while ((rdata0 != compare_value) && (i < iteration)) {
       // printk ("INFO: Polling for xcvr register: %lx, configuration bit 0, read data: %ld\n", reg_num, rdata0);
        i = i + 1;
        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);
    }

    if (i == iteration) {
        printk ("ERROR: Polling for xcvr register %lx failed\n", reg_num);
        return_value = 1;
    }
    udelay(2);

    return return_value;
}

int32_t fhgw_fpga_polling_for_calibration_status (uint32_t xcvr_base_addr, uint32_t reg_num)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    int32_t iteration = 5000;
    int32_t i = 0;
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);
    //printk ("INFO: rdata0 for xcvr register: 0x%lx, configuration bit 0, read data: 0x%lx\n", reg_num, rdata0);

    while (((rdata0 & 0x01) != 0x00) && (i < iteration)) {
        //printk ("INFO: Polling for xcvr register: 0x%lx, configuration bit 0, read data: 0x%lx for %d -th time\n", reg_num, rdata0, i);
        i = i + 1;
        // interupt required before each read to 0x88
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x0);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0xb);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x26);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x1);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);
        // Polling PMA register
        //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
        //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
        return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

        //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
        //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
        return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

        rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, reg_num);
    }

    if (i == iteration) {
        printk ("ERROR: calibration failed to complete, status register 0x88[0] is 0x1 \n");
        return_value = 1;
    }

    udelay(2);

    return return_value;
}

int32_t fhgw_fpga_serdes_loop_off (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // Disable the PMA serial loopback by using PMA attribute code 0x0008
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x8);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 8);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    return return_value;
}

int32_t fhgw_fpga_serdes_loop_on (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // Enable the PMA serial loopback by using PMA attribute code 0x0008
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x8);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 8);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    return return_value;
}

int32_t fhgw_fpga_general_calibration (uint32_t xcvr_base_addr, uint16_t loopback_mode)
{
    int32_t return_value = 0;

    if (loopback_mode == 0) {
        //1 Enable external loopback or disable Internal serial loopback mode
        //printk ("INFO: Enable external loopback\n");
        fhgw_fpga_serdes_loop_off (xcvr_base_addr);
    }

    //2 set for zero effort calibration
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x18);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x2C);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    //  Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //  Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //  Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6C);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    // Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    // Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 0x2c);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //3 start calibration
    //printk ("INFO: Receiver Tuning Controls\n");
    // Disable the PMA by using PMA attribute code 0x0001
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x1); //Run initial adaptive equalization
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0xa);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 0xa);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //4 Read Receiver Tuning Parameters, calibration status
    //printk ("INFO: calibration status check\n");
    // Disable the PMA by using PMA attribute code 0x0001
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0xb);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x26);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    return_value += fhgw_fpga_polling_for_calibration_status (xcvr_base_addr, 0x88); // check for bit 0;to indicate calibration successful.

    return return_value;
}

int32_t fhgw_fpga_pma_analog_reset (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    //Reset the internal controller inside the PMA because the REFCLK source changed
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x200, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x201, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x202, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x203, 0x81);

    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x207, 7);

    return return_value;
}

int32_t fhgw_fpga_calibration_pma_configuration_load (uint32_t xcvr_base_addr, uint16_t loopback_mode)
{
    int32_t return_value = 0;

    if (loopback_mode == 1) {
        //1. set_operation_mode , Internal Serial LB
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x200, 0x1F);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x201, 0x00);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x202, 0x00);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x203, 0x93);

        //printk ("INFO: Set operation mode status check start..\n");
        return_value += fhgw_fpga_polling_for_cal_bit (xcvr_base_addr, 0x207, 7);
        return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x207, 0);
    } else {
        //set_operation_mode , External data source
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x200, 0x1E);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x201, 0x00);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x202, 0x00);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x203, 0x93);
        //printk ("INFO: Set operation mode status check start..\n");
        return_value += fhgw_fpga_polling_for_cal_bit (xcvr_base_addr, 0x207, 7);
        return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x207, 0);
    };

    //2. Load PMA configuration
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x40143, 0x80);  // load default configuration
    //udelay(100);

    //3. Read_load PMA configuration status
    //printk ("INFO: load PMA configuration status check start..\n");

    return_value += fhgw_fpga_polling_for_cal_bit (xcvr_base_addr, 0x40144, 0); //Read 0x40144[0] = 0x1. This shows PMA configuration load finish.
    if (loopback_mode == 1) {
        // Internal Serial LB, disable PRBS
        //4.PMA configuration_channel
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x200, 0xF2);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x201, 0x03); // internal loopback
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x202, 0x01);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x203, 0x96);

        return_value += fhgw_fpga_polling_for_cal_bit (xcvr_base_addr, 0x207, 7);
        return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x207, 0);
    } else { // External Loopback, disable PRBS
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x200, 0xF2);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x201, 0x01); // external loopback
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x202, 0x01);
        FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x203, 0x96);

        return_value += fhgw_fpga_polling_for_cal_bit (xcvr_base_addr, 0x207, 7);
        return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x207, 0);
    }

    //5.check_PMA configuration_stat
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x200, 0x01);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x201, 0x00);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x202, 0x00);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x203, 0x97);
    //printk ("INFO: PMA Calibration status check start..\n");
    return_value += fhgw_fpga_polling_for_cal_bit (xcvr_base_addr, 0x207, 7);
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x207, 0);

    return return_value;
}

int32_t fhgw_fpga_serdes_disable (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    // Disable the PMA by using PMA attribute code 0x0001
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 1);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    return return_value;
}

int32_t fhgw_fpga_serdes_enable (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    // Enable the PMA by using PMA attribute code 0x0001
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x7);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 1);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    return return_value;
}

int32_t fhgw_fpga_rx_phase_slip (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x9C);  //'d28 for NRZ Mode: BitWidth=32 PhaseSlip=28(32-4), bit[7]=1
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0xE);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 14);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    return return_value;
}

int32_t fhgw_fpga_rx_phase_slip_low_speed (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x90);  //'d16 for NRZ Mode: BitWidth=20 PhaseSlip=16(20-4), bit[7]=1
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0xE);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 14);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    return return_value;
}

int32_t fhgw_fpga_swith_pma_uc_clock_1 (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x3);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x30);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 0x30);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    return return_value;
}

int32_t fhgw_fpga_swith_pma_uc_clock_0 (uint32_t xcvr_base_addr)
{
    int32_t return_value = 0;

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x30);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    //  Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    //  Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 0x30);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    return return_value;
}

int32_t fhgw_fpga_tx_rx_width_mode (uint32_t xcvr_base_addr, uint32_t width_mode)
{
    int32_t return_value = 0;

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84,width_mode);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85,0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86,0x14);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87,0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90,0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 0x14);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    return return_value;
}

int32_t fhgw_fpga_dr_init(void)
{
    // Upon Power up, resets have been released
    // sl_csr_rst_n
    // sl_tx_rst_n
    // sl_rx_rst_n
    // i_reconfig_reset


    // Wait for the ehip_ready to be asserted from dut before enable serdes loopback
    // o_sl_rx_pcs_ready
    // o_sl_rx_block_lock
    // o_ehip_ready

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH0, FHGW_FPGA_NO_SHIFT_OPS, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH1, FHGW_FPGA_NO_SHIFT_OPS, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH2, FHGW_FPGA_NO_SHIFT_OPS, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH3, FHGW_FPGA_NO_SHIFT_OPS, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH4, FHGW_FPGA_NO_SHIFT_OPS, 0x1);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH5, FHGW_FPGA_NO_SHIFT_OPS, 0x1);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH0, FHGW_FPGA_NO_SHIFT_OPS,  0x8);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH1, FHGW_FPGA_NO_SHIFT_OPS,  0x8);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH2, FHGW_FPGA_NO_SHIFT_OPS,  0x8);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH3, FHGW_FPGA_NO_SHIFT_OPS,  0x8);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH4, FHGW_FPGA_NO_SHIFT_OPS,  0x8);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH5, FHGW_FPGA_NO_SHIFT_OPS,  0x8);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH0, FHGW_FPGA_NO_SHIFT_OPS, 0xC);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH1, FHGW_FPGA_NO_SHIFT_OPS, 0xC);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH2, FHGW_FPGA_NO_SHIFT_OPS, 0xC);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH3, FHGW_FPGA_NO_SHIFT_OPS, 0xC);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH4, FHGW_FPGA_NO_SHIFT_OPS, 0xC);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH5, FHGW_FPGA_NO_SHIFT_OPS, 0xC);

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH0, FHGW_FPGA_NO_SHIFT_OPS, 0xE);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH1, FHGW_FPGA_NO_SHIFT_OPS, 0xE);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH2, FHGW_FPGA_NO_SHIFT_OPS, 0xE);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH3, FHGW_FPGA_NO_SHIFT_OPS, 0xE);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH4, FHGW_FPGA_NO_SHIFT_OPS, 0xE);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, FPGA_DATAPATH_CTRL_CH5, FHGW_FPGA_NO_SHIFT_OPS, 0xE);

    return 0;
}

int32_t fhgw_10gcpri_to_25gptpfec(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    printk ("\nINFO: Dynamic reconfiguration: CPRI_9p8G --> 25G_PTP_RSFEC \n\n");

    // Serdes Disable
    fhgw_fpga_serdes_disable (xcvr_base_addr);

    // Perform refclk_mux select start
    //1. switch PMA uC clock to XCVR-Refclk 1
    fhgw_fpga_swith_pma_uc_clock_1 (xcvr_base_addr);

    //2. REFCLK SEL SET
    // EC[3:0] Select reference clocks [0-8] muxed onto refclkin_in_A
    // EE[3:0] Selects which reference clock [0-8] is mapped to refclk0 in the Native PHY IP core
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xEE); //[3:0] refclk0 lookup register
    wdata = (rdata0 & 0xFFFFFF0F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xEC, wdata);

    //3. Switch PMA uC Clock to XCVR-Refclk 0
    fhgw_fpga_swith_pma_uc_clock_0 (xcvr_base_addr);

    //4. PMA Analog Reset
    //Reset the internal controller inside the PMA because the REFCLK source changed
    fhgw_fpga_pma_analog_reset (xcvr_base_addr);
    // Perform refclk_mux select end

    // ============================ RS-FEC ===================================
    fhgw_fpga_enable_rsfec(rsfec_base_addr, channel_no);

    // --------------------- Reconfig to 25G+PTP+RSFEC -------------------------

    // AIB CLOCK1 & AIB CLOCK2
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x322);
    wdata = (rdata0 & 0xFFFFFFF0) | 0x9;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x322, wdata);

    // RX FIFO STOP READ & RX FIFO PEMPTY
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x313);
    wdata = (rdata0 & 0xFFFFFF80) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x313, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x31A);
    wdata = (rdata0 & 0xFFFFFFE3) | 0x0C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x31A, wdata);

    // RX FIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x312);
    wdata = (rdata0 & 0xFFFFFFC0) | 0x0F;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x312, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x315);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x315, wdata);

    // RX FIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x314);
    wdata = (rdata0 & 0xFFFFFFC0) | 0xA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x314, wdata);

    // TX AIB CLK1 SEL & TX AIB CLK2 SEL & TX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30D);
    wdata = (rdata0 & 0xFFFFFF03) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30D, wdata);

    // TX FIFO STOP RD & TX FIFO STOP WR
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x302);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x00;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x302, wdata);

    // TX GB TX IDWIDTH & TX GB TX ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x306);
    wdata = (rdata0 & 0xFFFFFFC1) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x306, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30E);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30E, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x301);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x301, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x303);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6A;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x303, wdata);

    // TX TXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x300);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x300, wdata);

    // DCC CSR EN FSM
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x3C);
    wdata = (rdata0 & 0xFFFFFFFD) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x3C, wdata);

    // RB CONT CAL & RB DCC BYP 7 RB DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x38);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x38, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x36);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x36, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x35);
    wdata = (rdata0 & 0xFFFFFF00) | 0x48;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x35, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x34);
    wdata = (rdata0 & 0xFFFFFF0C) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x34, wdata);

    // RXBIT CONTR PMA
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x37);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x37, wdata);

    // EN DIRECT TX & EN FEC D2 TX & EN TX GBX & TX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);
    wdata = (rdata0 & 0xFFFFFF58) | 0x24;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x5, wdata);

    // EN FIFO RD RX & RX FIFO CLK SEL & RX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);
    wdata = (rdata0 & 0xFFFFFF85) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x7, wdata);

    // RX GB ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xE);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xE, wdata);

    // RX SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xB);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xB, wdata);

    // RX TAG SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x9);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x9, wdata);

    // RXFIFO AE THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x11);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x11, wdata);

    // RXFIFO AE THLD & RX FIFO E THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x10);
    wdata = (rdata0 & 0xFFFFFF20) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x10, wdata);

    // RXFIFO AF THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x12);
    wdata = (rdata0 & 0xFFFFFF83) | 0x50;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x12, wdata);

    // RXFIFO RD EMPTY & RXFIFO WR FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x13);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x13, wdata);

    // SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x8);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8, wdata);

    // TX CLK DP SEL & TX DATA IN SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);
    wdata = (rdata0 & 0xFFFFFFA3) | 0x44;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x4, wdata);

    // TX GB IDWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xC);
    wdata = (rdata0 & 0xFFFFFF8F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xC, wdata);

    // TXFIFO PH COMP
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x17);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x17, wdata);

    // RX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x218);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x218, wdata);

    // RX FIFO DOUBLE WRITE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21C);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21C, wdata);

    // RD CLK SCG EN & WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x227);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x227, wdata);

    // RX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x226);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x226, wdata);

    // RX FIFO WR CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x225);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x40;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x225, wdata);

    // RX PHCOMP RD SEL & RX RXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21B);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21B, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x220);
    wdata = (rdata0 & 0xFFFFFF3F) | 0xC0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x220, wdata);

    // RX RXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21A);
    wdata = (rdata0 & 0xFFFFFF9F) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21A, wdata);

    // TX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x208);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x208, wdata);

    // TX FIFO DOUBLE READ
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x20B);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x20B, wdata);

    // TX FIFO RD CLK SCG EN & TX FIFO RD CLK SEL & TX FIFO WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x214);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x214, wdata);

    // HRDRST ALIGN BYPASS & HRDRST DCD CAL DONE BYPASS
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x215);
    wdata = (rdata0 & 0xFFFFFF5F) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x215, wdata);

    // TX TX FIFO POWER MODE & TX WORD ALIGN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x210);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x210, wdata);

    // TX AIB TX DCC BYP & TX AIB TX DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32E);
    wdata = (rdata0 & 0xFFFFFFE7) | 0x18;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32E, wdata);

    //TX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0xA5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 5);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //RX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0xA5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 6);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // set PMA tx/rx width mode , 32bits
    fhgw_fpga_tx_rx_width_mode (xcvr_base_addr, 0x55);

    // TX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);

    // RX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);

    // ------------------- Reconfig to 25G+PTP+RSFEC end -----------------------

    // rx phaseslip to change the o_rx_fifo_clk_phase
    fhgw_fpga_rx_phase_slip (xcvr_base_addr);

    // Serdes Enable
    fhgw_fpga_serdes_enable (xcvr_base_addr);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);

    printk ("\nINFO: End of dynamic reconfiguration: CPRI_9p8G --> 25G_PTP_RSFEC \n\n");

    return return_value;
}

int32_t fhgw_4p9gcpri_to_25gptpfec(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    printk ("\nINFO: Starting dynamic reconfiguration: CPRI_4p9G --> 25G_PTP_RSFEC \n");

    // Serdes Disable
    fhgw_fpga_serdes_disable (xcvr_base_addr);

    // Perform refclk_mux select start
    //1. switch PMA uC clock to XCVR-Refclk 1
    fhgw_fpga_swith_pma_uc_clock_1 (xcvr_base_addr);

    //2. REFCLK SEL SET
    // EC[3:0] Select reference clocks [0-8] muxed onto refclkin_in_A
    // EE[3:0] Selects which reference clock [0-8] is mapped to refclk0 in the Native PHY IP core
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xEE); //[3:0] refclk0 lookup register
    wdata = (rdata0 & 0xFFFFFF0F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xEC, wdata);

    //3. Switch PMA uC Clock to XCVR-Refclk 0
    fhgw_fpga_swith_pma_uc_clock_0 (xcvr_base_addr);

    //4. PMA Analog Reset
    //Reset the internal controller inside the PMA because the REFCLK source changed
    fhgw_fpga_pma_analog_reset (xcvr_base_addr);
    // Perform refclk_mux select end

    // ============================ RS-FEC ===================================
    fhgw_fpga_enable_rsfec(rsfec_base_addr, channel_no);

    // --------------------- Reconfig to Eth 25gptpfec ------------------------
    // r_aibdprio0
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x231);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x231, wdata);

    // r_aibdprio0
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x233);
    wdata = (rdata0 & 0xFFFFFFC0) | 0x38;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x233, wdata);

    // hssi_pldadapt_tx_308
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x309);
    wdata = (rdata0 & 0xFFFFFF00) | 0x23;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x309, wdata);

    // hssi_pldadapt_tx_310
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x310);
    wdata = (rdata0 & 0xFFFFFF00) | 0x1A;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x310, wdata);

    // hssi_pldadapt_tx_310
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x311);
    wdata = (rdata0 & 0xFFFFFF00) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x311, wdata);

    //
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x318);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x318, wdata);

    // hssi_pldadapt_tx_320
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x320);
    wdata = (rdata0 & 0xFFFFFF00) | 0x12;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x320, wdata);

    // hssi_pldadapt_tx_320
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32C);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32C, wdata);

    // AIB CLOCK1 & AIB CLOCK2
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x322);
    wdata = (rdata0 & 0xFFFFFFF0) | 0x9;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x322, wdata);

    // RX FIFO STOP READ & RX FIFO PEMPTY
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x313);
    wdata = (rdata0 & 0xFFFFFFB2) | 0x02;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x313, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x31A);
    wdata = (rdata0 & 0xFFFFFFE3) | 0x0C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x31A, wdata);

    // RX FIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x312);
    wdata = (rdata0 & 0xFFFFFF00) | 0x4F;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x312, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x315);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x315, wdata);

    // RX FIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x314);
    wdata = (rdata0 & 0xFFFFFFEE) | 0x02;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x314, wdata);

    // TX AIB CLK1 SEL & TX AIB CLK2 SEL & TX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30D);
    wdata = (rdata0 & 0xFFFFFF03) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30D, wdata);

    // TX FIFO STOP RD & TX FIFO STOP WR
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x302);
    wdata = (rdata0 & 0xFFFFFF20) | 0x02;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x302, wdata);

    // TX GB TX IDWIDTH & TX GB TX ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x306);
    wdata = (rdata0 & 0xFFFFFF09) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x306, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30E);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30E, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x301);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x301, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x303);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6A;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x303, wdata);

    // TX TXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x300);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x300, wdata);

    // DCC CSR EN FSM
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x3C);
    wdata = (rdata0 & 0xFFFFFFFD) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x3C, wdata);

    // RB CONT CAL & RB DCC BYP 7 RB DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x38);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x01;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x38, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x36);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x36, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x35);
    wdata = (rdata0 & 0xFFFFFF00) | 0x48;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x35, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x34);
    wdata = (rdata0 & 0xFFFFFF0C) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x34, wdata);

    // RXBIT CONTR PMA
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x37);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x37, wdata);

    // EN DIRECT TX & EN FEC D2 TX & EN TX GBX & TX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);
    wdata = (rdata0 & 0xFFFFFF58) | 0x24;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x5, wdata);

    // EN FIFO RD RX & RX FIFO CLK SEL & RX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);
    wdata = (rdata0 & 0xFFFFFF85) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x7, wdata);

    // RX GB ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xE);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xE, wdata);

    // RX SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xB);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xB, wdata);

    // RX TAG SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x9);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x9, wdata);

    // RXFIFO AE THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x11);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x11, wdata);

    // RXFIFO AE THLD & RX FIFO E THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x10);
    wdata = (rdata0 & 0xFFFFFF20) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x10, wdata);

    // RXFIFO AF THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x12);
    wdata = (rdata0 & 0xFFFFFF83) | 0x50;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x12, wdata);

    // RXFIFO RD EMPTY & RXFIFO WR FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x13);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x13, wdata);

    // SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x8);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8, wdata);

    // TX CLK DP SEL & TX DATA IN SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);
    wdata = (rdata0 & 0xFFFFFFA3) | 0x44;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x4, wdata);

    // TX GB IDWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xC);
    wdata = (rdata0 & 0xFFFFFF8F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xC, wdata);

    // TXFIFO PH COMP
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x17);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x17, wdata);

    // RX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x218);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x218, wdata);

    // RX FIFO DOUBLE WRITE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21C);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21C, wdata);

    // RD CLK SCG EN & WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x227);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x227, wdata);

    // RX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x226);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x226, wdata);

    // RX FIFO WR CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x225);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x40;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x225, wdata);

    // RX PHCOMP RD SEL & RX RXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21B);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21B, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x220);
    wdata = (rdata0 & 0xFFFFFF3F) | 0xC0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x220, wdata);

    // RX RXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21A);
    wdata = (rdata0 & 0xFFFFFF00) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21A, wdata);

    // TX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x208);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x208, wdata);

    // TX FIFO DOUBLE READ
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x20B);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x20B, wdata);

    // TX FIFO RD CLK SCG EN & TX FIFO RD CLK SEL & TX FIFO WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x214);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x214, wdata);

    // HRDRST ALIGN BYPASS & HRDRST DCD CAL DONE BYPASS
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x215);
    wdata = (rdata0 & 0xFFFFFF5F) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x215, wdata);

    // TX TX FIFO POWER MODE & TX WORD ALIGN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x210);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x210, wdata);

    // TX AIB TX DCC BYP & TX AIB TX DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32E);
    wdata = (rdata0 & 0xFFFFFFE7) | 0x18;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32E, wdata);

    //TX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0xA5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 5);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //RX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0xA5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 6);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // set PMA tx/rx width mode , 32bits
    fhgw_fpga_tx_rx_width_mode (xcvr_base_addr, 0x55);

    // TX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);

    // RX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);

    // ------------------- Reconfig to 25G+PTP+RSFEC end -----------------------

    // rx phaseslip to change the o_rx_fifo_clk_phase
    fhgw_fpga_rx_phase_slip (xcvr_base_addr);

    // Serdes Enable
    fhgw_fpga_serdes_enable (xcvr_base_addr);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);


    printk ("\nINFO: End of dynamic reconfiguration: CPRI_4p9G --> 25G_PTP_RSFEC \n");


    return return_value;
}

int32_t fhgw_2p4gcpri_to_25gptpfec(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    printk ("\nINFO: Starting dynamic reconfiguration: CPRI_2p4G --> 25G_PTP_RSFEC \n");

    // Serdes Disable
    fhgw_fpga_serdes_disable (xcvr_base_addr);

    // Perform refclk_mux select start
    //1. switch PMA uC clock to XCVR-Refclk 1
    fhgw_fpga_swith_pma_uc_clock_1 (xcvr_base_addr);

    //2. REFCLK SEL SET
    // EC[3:0] Select reference clocks [0-8] muxed onto refclkin_in_A
    // EE[3:0] Selects which reference clock [0-8] is mapped to refclk0 in the Native PHY IP core
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xEE); //[3:0] refclk0 lookup register
    wdata = (rdata0 & 0xFFFFFF0F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xEC, wdata);

    //3. Switch PMA uC Clock to XCVR-Refclk 0
    fhgw_fpga_swith_pma_uc_clock_0 (xcvr_base_addr);

    //4. PMA Analog Reset
    //Reset the internal controller inside the PMA because the REFCLK source changed
    fhgw_fpga_pma_analog_reset (xcvr_base_addr);
    // Perform refclk_mux select end

    // ============================ RS-FEC ===================================
    fhgw_fpga_enable_rsfec(rsfec_base_addr, channel_no);

    // --------------------- Reconfig to Eth 25gptpfec ------------------------
    // r_aibdprio0
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x231);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x231, wdata);

    // r_aibdprio0
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x233);
    wdata = (rdata0 & 0xFFFFFFC0) | 0x38;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x233, wdata);

    // hssi_pldadapt_tx_308
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x309);
    wdata = (rdata0 & 0xFFFFFF00) | 0x23;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x309, wdata);

    // hssi_pldadapt_tx_310
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x310);
    wdata = (rdata0 & 0xFFFFFF00) | 0x1A;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x310, wdata);

    // hssi_pldadapt_tx_310
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x311);
    wdata = (rdata0 & 0xFFFFFF00) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x311, wdata);

    //
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x318);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x318, wdata);

    // hssi_pldadapt_tx_320
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x320);
    wdata = (rdata0 & 0xFFFFFF00) | 0x12;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x320, wdata);

    // hssi_pldadapt_tx_320
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32C);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32C, wdata);

    // AIB CLOCK1 & AIB CLOCK2
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x322);
    wdata = (rdata0 & 0xFFFFFFF0) | 0x9;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x322, wdata);

    // RX FIFO STOP READ & RX FIFO PEMPTY
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x313);
    wdata = (rdata0 & 0xFFFFFFB2) | 0x02;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x313, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x31A);
    wdata = (rdata0 & 0xFFFFFFE3) | 0x0C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x31A, wdata);

    // RX FIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x312);
    wdata = (rdata0 & 0xFFFFFF00) | 0x4F;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x312, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x315);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x315, wdata);

    // RX FIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x314);
    wdata = (rdata0 & 0xFFFFFFEE) | 0x02;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x314, wdata);

    // TX AIB CLK1 SEL & TX AIB CLK2 SEL & TX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30D);
    wdata = (rdata0 & 0xFFFFFF03) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30D, wdata);

    // TX FIFO STOP RD & TX FIFO STOP WR
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x302);
    wdata = (rdata0 & 0xFFFFFF20) | 0x02;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x302, wdata);

    // TX GB TX IDWIDTH & TX GB TX ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x306);
    wdata = (rdata0 & 0xFFFFFF09) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x306, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30E);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30E, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x301);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x301, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x303);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6A;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x303, wdata);

    // TX TXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x300);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x300, wdata);

    // DCC CSR EN FSM
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x3C);
    wdata = (rdata0 & 0xFFFFFFFD) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x3C, wdata);

    // RB CONT CAL & RB DCC BYP 7 RB DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x38);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x01;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x38, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x36);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x36, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x35);
    wdata = (rdata0 & 0xFFFFFF00) | 0x48;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x35, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x34);
    wdata = (rdata0 & 0xFFFFFF0C) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x34, wdata);

    // RXBIT CONTR PMA
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x37);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x37, wdata);

    // EN DIRECT TX & EN FEC D2 TX & EN TX GBX & TX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);
    wdata = (rdata0 & 0xFFFFFF58) | 0x24;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x5, wdata);

    // EN FIFO RD RX & RX FIFO CLK SEL & RX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);
    wdata = (rdata0 & 0xFFFFFF85) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x7, wdata);

    // RX GB ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xE);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xE, wdata);

    // RX SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xB);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xB, wdata);

    // RX TAG SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x9);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x9, wdata);

    // RXFIFO AE THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x11);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x11, wdata);

    // RXFIFO AE THLD & RX FIFO E THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x10);
    wdata = (rdata0 & 0xFFFFFF20) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x10, wdata);

    // RXFIFO AF THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x12);
    wdata = (rdata0 & 0xFFFFFF83) | 0x50;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x12, wdata);

    // RXFIFO RD EMPTY & RXFIFO WR FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x13);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x13, wdata);

    // SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x8);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8, wdata);

    // TX CLK DP SEL & TX DATA IN SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);
    wdata = (rdata0 & 0xFFFFFFA3) | 0x44;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x4, wdata);

    // TX GB IDWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xC);
    wdata = (rdata0 & 0xFFFFFF8F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xC, wdata);

    // TXFIFO PH COMP
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x17);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x17, wdata);

    // RX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x218);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x218, wdata);

    // RX FIFO DOUBLE WRITE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21C);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21C, wdata);

    // RD CLK SCG EN & WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x227);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x227, wdata);

    // RX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x226);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x226, wdata);

    // RX FIFO WR CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x225);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x40;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x225, wdata);

    // RX PHCOMP RD SEL & RX RXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21B);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21B, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x220);
    wdata = (rdata0 & 0xFFFFFF3F) | 0xC0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x220, wdata);

    // RX RXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21A);
    wdata = (rdata0 & 0xFFFFFF00) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21A, wdata);

    // TX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x208);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x208, wdata);

    // TX FIFO DOUBLE READ
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x20B);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x20B, wdata);

    // TX FIFO RD CLK SCG EN & TX FIFO RD CLK SEL & TX FIFO WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x214);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x214, wdata);

    // HRDRST ALIGN BYPASS & HRDRST DCD CAL DONE BYPASS
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x215);
    wdata = (rdata0 & 0xFFFFFF5F) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x215, wdata);

    // TX TX FIFO POWER MODE & TX WORD ALIGN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x210);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x210, wdata);

    // TX AIB TX DCC BYP & TX AIB TX DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32E);
    wdata = (rdata0 & 0xFFFFFFE7) | 0x18;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32E, wdata);

    //TX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0xA5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 5);
    return_value +=fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //RX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0xA5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 6);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // set PMA tx/rx width mode , 32bits
    fhgw_fpga_tx_rx_width_mode (xcvr_base_addr, 0x55);

    // TX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);

    // RX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);

    // ------------------- Reconfig to 25G+PTP+RSFEC end -----------------------

    // rx phaseslip to change the o_rx_fifo_clk_phase
    fhgw_fpga_rx_phase_slip (xcvr_base_addr);

    // Serdes Enable
    fhgw_fpga_serdes_enable (xcvr_base_addr);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);


    printk ("\nINFO: End of dynamic reconfiguration: CPRI_2p4G --> 25G_PTP_RSFEC \n");


    return return_value;
}

int32_t fhgw_9p8gcpri_to_25gptpfec(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    printk ("\nINFO: Dynamic reconfiguration: CPRI_9p8G --> 25G_PTP_RSFEC \n\n");

    // Serdes Disable
    fhgw_fpga_serdes_disable (xcvr_base_addr);

    // Perform refclk_mux select start
    //1. switch PMA uC clock to XCVR-Refclk 1
    fhgw_fpga_swith_pma_uc_clock_1 (xcvr_base_addr);

    //2. REFCLK SEL SET
    // EC[3:0] Select reference clocks [0-8] muxed onto refclkin_in_A
    // EE[3:0] Selects which reference clock [0-8] is mapped to refclk0 in the Native PHY IP core
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xEE); //[3:0] refclk0 lookup register
    wdata = (rdata0 & 0xFFFFFF0F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xEC, wdata);

    //3. Switch PMA uC Clock to XCVR-Refclk 0
    fhgw_fpga_swith_pma_uc_clock_0 (xcvr_base_addr);

    //4. PMA Analog Reset
    //Reset the internal controller inside the PMA because the REFCLK source changed
    fhgw_fpga_pma_analog_reset (xcvr_base_addr);
    // Perform refclk_mux select end

    // ============================ RS-FEC ===================================
    fhgw_fpga_enable_rsfec(rsfec_base_addr, channel_no);

    // --------------------- Reconfig to 25G+PTP+RSFEC -------------------------

    // AIB CLOCK1 & AIB CLOCK2
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x322);
    wdata = (rdata0 & 0xFFFFFFF0) | 0x9;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x322, wdata);

    // RX FIFO STOP READ & RX FIFO PEMPTY
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x313);
    wdata = (rdata0 & 0xFFFFFF80) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x313, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x31A);
    wdata = (rdata0 & 0xFFFFFFE3) | 0x0C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x31A, wdata);

    // RX FIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x312);
    wdata = (rdata0 & 0xFFFFFFC0) | 0x0F;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x312, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x315);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x315, wdata);

    // RX FIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x314);
    wdata = (rdata0 & 0xFFFFFFC0) | 0xA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x314, wdata);

    // TX AIB CLK1 SEL & TX AIB CLK2 SEL & TX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30D);
    wdata = (rdata0 & 0xFFFFFF03) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30D, wdata);

    // TX FIFO STOP RD & TX FIFO STOP WR
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x302);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x00;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x302, wdata);

    // TX GB TX IDWIDTH & TX GB TX ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x306);
    wdata = (rdata0 & 0xFFFFFFC1) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x306, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30E);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30E, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x301);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x301, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x303);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6A;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x303, wdata);

    // TX TXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x300);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x300, wdata);

    // DCC CSR EN FSM
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x3C);
    wdata = (rdata0 & 0xFFFFFFFD) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x3C, wdata);

    // RB CONT CAL & RB DCC BYP 7 RB DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x38);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x38, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x36);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x36, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x35);
    wdata = (rdata0 & 0xFFFFFF00) | 0x48;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x35, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x34);
    wdata = (rdata0 & 0xFFFFFF0C) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x34, wdata);

    // RXBIT CONTR PMA
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x37);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x37, wdata);

    // EN DIRECT TX & EN FEC D2 TX & EN TX GBX & TX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);
    wdata = (rdata0 & 0xFFFFFF58) | 0x24;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x5, wdata);

    // EN FIFO RD RX & RX FIFO CLK SEL & RX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);
    wdata = (rdata0 & 0xFFFFFF85) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x7, wdata);

    // RX GB ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xE);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xE, wdata);

    // RX SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xB);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xB, wdata);

    // RX TAG SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x9);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x9, wdata);

    // RXFIFO AE THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x11);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x11, wdata);

    // RXFIFO AE THLD & RX FIFO E THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x10);
    wdata = (rdata0 & 0xFFFFFF20) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x10, wdata);

    // RXFIFO AF THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x12);
    wdata = (rdata0 & 0xFFFFFF83) | 0x50;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x12, wdata);

    // RXFIFO RD EMPTY & RXFIFO WR FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x13);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x13, wdata);

    // SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x8);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8, wdata);

    // TX CLK DP SEL & TX DATA IN SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);
    wdata = (rdata0 & 0xFFFFFFA3) | 0x44;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x4, wdata);

    // TX GB IDWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xC);
    wdata = (rdata0 & 0xFFFFFF8F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xC, wdata);

    // TXFIFO PH COMP
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x17);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x17, wdata);

    // RX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x218);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x218, wdata);

    // RX FIFO DOUBLE WRITE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21C);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21C, wdata);

    // RD CLK SCG EN & WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x227);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x227, wdata);

    // RX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x226);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x226, wdata);

    // RX FIFO WR CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x225);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x40;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x225, wdata);

    // RX PHCOMP RD SEL & RX RXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21B);
    wdata = (rdata0 & 0xFFFFFF00) | 0x6E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21B, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x220);
    wdata = (rdata0 & 0xFFFFFF3F) | 0xC0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x220, wdata);

    // RX RXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21A);
    wdata = (rdata0 & 0xFFFFFF9F) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21A, wdata);

    // TX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x208);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x208, wdata);

    // TX FIFO DOUBLE READ
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x20B);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x20B, wdata);

    // TX FIFO RD CLK SCG EN & TX FIFO RD CLK SEL & TX FIFO WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x214);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x214, wdata);

    // HRDRST ALIGN BYPASS & HRDRST DCD CAL DONE BYPASS
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x215);
    wdata = (rdata0 & 0xFFFFFF5F) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x215, wdata);

    // TX TX FIFO POWER MODE & TX WORD ALIGN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x210);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x210, wdata);

    // TX AIB TX DCC BYP & TX AIB TX DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32E);
    wdata = (rdata0 & 0xFFFFFFE7) | 0x18;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32E, wdata);

    //TX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0xA5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 5);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //RX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0xA5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 6);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // set PMA tx/rx width mode , 32bits
    fhgw_fpga_tx_rx_width_mode (xcvr_base_addr, 0x55);

    // TX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);

    // RX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);

    // ------------------- Reconfig to 25G+PTP+RSFEC end -----------------------

    // rx phaseslip to change the o_rx_fifo_clk_phase
    fhgw_fpga_rx_phase_slip (xcvr_base_addr);

    // Serdes Enable
    fhgw_fpga_serdes_enable (xcvr_base_addr);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);

    printk ("\nINFO: End of dynamic reconfiguration: CPRI_9p8G --> 25G_PTP_RSFEC \n\n");

    return return_value;
}

int32_t fhgw_25gptpfec_to_10gcpri(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    // DR start:  assert tx/rx reset ports
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, fhgw_dp_ctrl[channel_no], FHGW_FPGA_NO_SHIFT_OPS, 0x8);

    // Serdes Disable
    fhgw_fpga_serdes_disable (xcvr_base_addr);

    // Perform refclk_mux select start
    //1. switch PMA uC clock to XCVR-Refclk 1
    fhgw_fpga_swith_pma_uc_clock_1 (xcvr_base_addr);

    //2. REFCLK SEL SET
    // EC[3:0] Select reference clocks [0-8] muxed onto refclkin_in_A
    // EE[7:4] Selects which reference clock [0-8] is mapped to refclk1 in the Native PHY IP core
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xEE); //[7:4] refclk1 lookup register
    wdata = ((rdata0 >> 4) & 0xFFFFFF0F) | 0x0; // {4'b0000,rdata0[7:4]}
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xEC, wdata);

    //3. Switch PMA uC Clock to XCVR-Refclk 0
    fhgw_fpga_swith_pma_uc_clock_0 (xcvr_base_addr);
    //4. PMA Analog Reset
    //Reset the internal controller inside the PMA because the REFCLK source changed
    fhgw_fpga_pma_analog_reset (xcvr_base_addr);

    fhgw_fpga_disable_rsfec(rsfec_base_addr, channel_no);

    //Perform refclk mux select end
    // ============================ PMA config ===================================
    // xcvrif_ctrl0
    // cfg_tx_data_in_sel [4:2] 001  ->    000
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);
    wdata = (rdata0 & 0xFFFFFFE3) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x4, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);

    // xcvrif_ctrl0
    // cfg_clk_en_fec_d2_tx [13]    1  - >   0
    // cfg_clk_en_pcs_d2_tx [12]    0  - >   1
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x10;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x5, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);

    // xcvrif_ctrl0
    // cfg_rx_fifo_clk_sel [30:29] 0 -> 2
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);
    wdata = (rdata0 & 0xFFFFFF9F) | 0x40;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x7, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);

	//cfg_rx_bit_counter_rollover 13'd5248 (13'h1480) -> 13'd6304 (13'h18A0) (FEC-->Non-FEC)
    //0x34 [3:0] rx bit counter serializations factor : 11 = count by 32, 10=count by 20
	// Bit [16:4]
	rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x34);
	wdata = (rdata0 & 0xFFFFFF0F) | 0x3;
	FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x34, wdata);

	rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x35);
	wdata = (rdata0 & 0xFFFFFF00) | 0x8A;
	FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x35, wdata);

	rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x36);
	wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
	FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x36, wdata);

 	// RXBIT CNTR PMA [7] = 1  for nofec
	rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x37);
	wdata = (rdata0 & 0xFFFFFF7F) | 0x80;
	FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x37, wdata);

    // ============================ EHIP CONFIG ===================================

    // phy_ehip_pcs_modes
    // use_aligner     [9]   0  -> 1
    // use_am_insert   [4]   1  -> 0
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES);
    wdata = (rdata0 & 0xFFFFFDE7) | 0x200;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES);

    // phy_ehip_mode_muxes
    // 30D txpcsmux_sel[5:3] 000 -> 001
    // Select input to TX PCS
    // 0:TX MAC
    // 1:TX PLD Interface
    // 2:RX PCS
    // 3-7:Reserved
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x30D);
    wdata = (rdata0 & 0xFFFFFFC7) | 0x08; // {readdata[31:6],3'd1,readdata[2:0]}
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x30D, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x30D);

    // tx_pld_conf
    // 350 tx_ehip_mode[2:0] 001 -> 010
    // Selects how the synchronous input to the EHIP will be mapped
    // 3h0: MAC interface
    // 3h1: MAC interface with PTP
    // 3h2: PCS (MII) interface <--
    // 3h3: PCS66 interface with forced encoder and scrambler bypass
    // 3h4: PCS66 interface
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x02; // {readdata[31:3],3'd2}
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);

    // rx_pld_conf
    // 355 rx_ehip_mode[2:0] 001 -> 010
    // Select RX Portmap Selects how data from the EHIP is presented through the AIB
    // 3h0: MAC interface
    // 3h1: MAC interface with PTP
    // 3h2: PCS (MII) interface <--
    // 3h3: PCS66 interface for OTN (forced descrambler bypass)
    // 3h4: PCS66 interface (descrambler optional)
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x02; // {readdata[31:3],3'd2}
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);

    // txmac_ehip_cfg
    // flowreg_rate    [8:6]    3  -> 7
    // am_width        [5:3]    4  -> 1

    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, FHGW_FPGA_TXMAC_EHIP_CFG);
    // Mask (AND) bit location that need update to 0, then OR with desired value
    wdata = (rdata0 & 0xFFFFFE07) | 0x1C8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, FHGW_FPGA_TXMAC_EHIP_CFG, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, FHGW_FPGA_TXMAC_EHIP_CFG);

   // ============================= CPRI SOFT CONFIG================================

         //[3:0] = cpri_rate_sel;
         //[4] = cpri_fec_en;
        //[9:5] = i_sl_rx_bitslipboundary_sel;
        //24G+FEC = 1B, 10G NoFEC = 9
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, cprisoft_base_addr, 0x0);
    wdata = (rdata0 & 0xE0) | 0x9;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, cprisoft_base_addr, 0x0, wdata);

    //================================= PMA CONFIG =================================

    // tx bit/refclk ratio for 10G (Based on 184.32MHz ref clk
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x37);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);
    // read_xcvr_user_cfgcsr_reg(xcvr_base_addr, 0x84, 1, 0x37);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 5);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // rx bit/refclk ratio for 10G (Based on 184.32MHz ref clk
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x37);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);
    // read_xcvr_user_cfgcsr_reg(xcvr_base_addr, 0x84, 1, 0x37);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 6);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // set PMA tx/rx width mode , 32bits
    fhgw_fpga_tx_rx_width_mode (xcvr_base_addr, 0x55);

    // rx phaseslip to change the o_rx_fifo_clk_phase
    fhgw_fpga_rx_phase_slip (xcvr_base_addr);

    // Serdes Enable
    fhgw_fpga_serdes_enable (xcvr_base_addr);
    // printk ("INFO: after:fhgw_fpga_serdes_enable\n");

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);

    printk ("\nINFO: End of dynamic reconfiguration: 25G_PTP_RSFEC --> CPRI_10G\n\n");

    return return_value;
}

int32_t fhgw_25gptpfec_to_9p8gcpri(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    // DR start:  assert tx/rx reset ports
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, fhgw_dp_ctrl[channel_no], FHGW_FPGA_NO_SHIFT_OPS, 0x8);

    // Serdes Disable
    fhgw_fpga_serdes_disable (xcvr_base_addr);

    // Perform refclk_mux select start
    //1. switch PMA uC clock to XCVR-Refclk 1
    fhgw_fpga_swith_pma_uc_clock_1 (xcvr_base_addr);

    //2. REFCLK SEL SET
    // EC[3:0] Select reference clocks [0-8] muxed onto refclkin_in_A
    // EF[3:0] Selects which reference clock [0-8] is mapped to refclk2 in the Native PHY IP core
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xEF); //[3:0] refclk2 lookup register
    wdata = (rdata0 & 0xFFFFFF0F) | 0x0; // {4'b0000,rdata0[3:0]}
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xEC, wdata);

    //3. Switch PMA uC Clock to XCVR-Refclk 0
    fhgw_fpga_swith_pma_uc_clock_0 (xcvr_base_addr);

    //4. PMA Analog Reset
    //Reset the internal controller inside the PMA because the REFCLK source changed
    fhgw_fpga_pma_analog_reset (xcvr_base_addr);
    // Perform refclk_mux select end

    // ============================ RS-FEC ===================================
    fhgw_fpga_disable_rsfec(rsfec_base_addr, channel_no);

    // ------------------------- Reconfig to CPRI 9p8g -------------------------

    // AIB CLOCK1 & AIB CLOCK2 Select
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x322);
    wdata = (rdata0 & 0xFFFFFFF0) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x322, wdata);

    // RX FIFO STOP READ & RX FIFO PEMPTY
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x313);
    wdata = (rdata0 & 0xFFFFFF80) | 0x44;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x313, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x31A);
    wdata = (rdata0 & 0xFFFFFFE3) | 0x1C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x31A, wdata);

    // RX FIFO FULL Threshold
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x312);
    wdata = (rdata0 & 0xFFFFFFC0) | 0x3F;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x312, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x315);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x5;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x315, wdata);

    // RX FIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x314);
    wdata = (rdata0 & 0xFFFFFFC0) | 0x14;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x314, wdata);

    // TX AIB CLK1 SEL & TX AIB CLK2 SEL & TX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30D);
    wdata = (rdata0 & 0xFFFFFF03) | 0x18;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30D, wdata);

    // TX FIFO STOP RD & TX FIFO STOP WR
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x302);
    wdata = (rdata0 & 0xFFFFFF3F) | 0xC0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x302, wdata);

    // TX GB TX IDWIDTH & TX GB TX ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x306);
    wdata = (rdata0 & 0xFFFFFFC1) | 0x2A;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x306, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30E);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30E, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x301);
    wdata = (rdata0 & 0xFFFFFF00) | 0x5E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x301, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x303);
    wdata = (rdata0 & 0xFFFFFF00) | 0xF2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x303, wdata);

    // TX TXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x300);
    wdata = (rdata0 & 0xFFFFFF1F) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x300, wdata);

    // DCC CSR EN FSM
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x3C);
    wdata = (rdata0 & 0xFFFFFFFD) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x3C, wdata);

    // RB CONT CAL & RB DCC BYP 7 RB DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x38);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x6;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x38, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x36);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x36, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x35);
    wdata = (rdata0 & 0xFFFFFF00) | 0x48;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x35, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x34);
    wdata = (rdata0 & 0xFFFFFF0C) | 0xC2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x34, wdata);

    // RXBIT CONTR PMA
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x37);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x37, wdata);

    // EN DIRECT TX & EN FEC D2 TX & EN TX GBX & TX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);
    wdata = (rdata0 & 0xFFFFFF58) | 0x83;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x5, wdata);

    // EN FIFO RD RX & RX FIFO CLK SEL & RX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);
    wdata = (rdata0 & 0xFFFFFF85) | 0x68;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x7, wdata);

    // RX GB ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xE);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x5;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xE, wdata);

    // RX SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xB);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xB, wdata);

    // RX TAG SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x9);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x9, wdata);

    // RXFIFO AE THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x11);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x11, wdata);

    // RXFIFO AE THLD & RX FIFO E THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x10);
    wdata = (rdata0 & 0xFFFFFF20) | 0x40;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x10, wdata);

    // RXFIFO AF THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x12);
    wdata = (rdata0 & 0xFFFFFF83) | 0x08;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x12, wdata);

    // RXFIFO RD EMPTY & RXFIFO WR FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x13);
    wdata = (rdata0 & 0xFFFFFF3F) | 0xC0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x13, wdata);

    // SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x8);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8, wdata);

    // TX CLK DP SEL & TX DATA IN SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);
    wdata = (rdata0 & 0xFFFFFFA3) | 0x0C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x4, wdata);

    // TX GB IDWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xC);
    wdata = (rdata0 & 0xFFFFFF8F) | 0x50;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xC, wdata);

    // TXFIFO PH COMP
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x17);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x30;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x17, wdata);

    // RX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x218);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x218, wdata);

    // RX FIFO DOUBLE WRITE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21C);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21C, wdata);

    // RD CLK SCG EN & WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x227);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x30;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x227, wdata);

    // RX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x226);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x226, wdata);

    // RX FIFO WR CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x225);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x225, wdata);

    // RX PHCOMP RD SEL & RX RXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21B);
    wdata = (rdata0 & 0xFFFFFF00) | 0x47;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21B, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x220);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x220, wdata);

    // RX RXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21A);
    wdata = (rdata0 & 0xFFFFFF9F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21A, wdata);

    // TX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x208);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x208, wdata);

    // TX FIFO DOUBLE READ
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x20B);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x20B, wdata);

    // TX FIFO RD CLK SCG EN & TX FIFO RD CLK SEL & TX FIFO WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x214);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x214, wdata);

    // HRDRST ALIGN BYPASS & HRDRST DCD CAL DONE BYPASS
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x215);
    wdata = (rdata0 & 0xFFFFFF5F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x215, wdata);

    // TX TX FIFO POWER MODE & TX WORD ALIGN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x210);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x210, wdata);

    // TX AIB TX DCC BYP & TX AIB TX DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32E);
    wdata = (rdata0 & 0xFFFFFFE7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32E, wdata);

    //TX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x40);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 5);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //RX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x40);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 6);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // set PMA tx/rx width mode , 20bits
    fhgw_fpga_tx_rx_width_mode (xcvr_base_addr, 0x11);

    // TX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);

    // RX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);

  // ============================= CPRI SOFT CONFIG================================

         //[3:0] = cpri_rate_sel;
         //[4] = cpri_fec_en;
        //[9:5] = i_sl_rx_bitslipboundary_sel;
        //24G+FEC = 1B, 10G NoFEC = 9 , 9G =6
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, cprisoft_base_addr, 0x0);
    wdata = (rdata0 & 0xE0) | 0x6;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, cprisoft_base_addr, 0x0, wdata);

    // --------------------- Reconfig to CPRI 9p8g end -------------------------

    // rx phaseslip to change the o_rx_fifo_clk_phase
    fhgw_fpga_rx_phase_slip_low_speed (xcvr_base_addr);
    // Serdes Enable
    fhgw_fpga_serdes_enable (xcvr_base_addr);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    printk ("\nINFO: End of dynamic reconfiguration: 25G_PTP_RSFEC --> CPRI_9p8G \n\n");

    return return_value;
}

int32_t fhgw_25gptpfec_to_4p9gcpri(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    FHGW_FPGA_REG_WRITE(fpga_dev->regs, fhgw_dp_ctrl[channel_no], FHGW_FPGA_NO_SHIFT_OPS, 0xE);

    // DR start:  assert tx/rx reset ports
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, fhgw_dp_ctrl[channel_no], FHGW_FPGA_NO_SHIFT_OPS, 0x8);

    printk ("\nINFO: Dynamic reconfiguration: 25G_PTP_RSFEC --> CPRI_4p9G \n\n");

    // Serdes Disable
    fhgw_fpga_serdes_disable (xcvr_base_addr);

    // Perform refclk_mux select start
    //1. switch PMA uC clock to XCVR-Refclk 1
    fhgw_fpga_swith_pma_uc_clock_1 (xcvr_base_addr);

    //2. REFCLK SEL SET
    // EC[3:0] Select reference clocks [0-8] muxed onto refclkin_in_A
    // EF[3:0] Selects which reference clock [0-8] is mapped to refclk2 in the Native PHY IP core
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xEF); //[3:0] refclk2 lookup register
    wdata = (rdata0 & 0xFFFFFF0F) | 0x0; // {4'b0000,rdata0[3:0]}
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xEC, wdata);

    //3. Switch PMA uC Clock to XCVR-Refclk 0
    fhgw_fpga_swith_pma_uc_clock_0 (xcvr_base_addr);

    //4. PMA Analog Reset
    //Reset the internal controller inside the PMA because the REFCLK source changed
    fhgw_fpga_pma_analog_reset (xcvr_base_addr);
    // Perform refclk_mux select end

    // ============================= CPRI SOFT CONFIG================================

    //[3:0] = cpri_rate_sel;
    //[4] = cpri_fec_en;
    //[9:5] = i_sl_rx_bitslipboundary_sel;
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, cprisoft_base_addr, 0x0);
    wdata = (rdata0 & 0xE0) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, cprisoft_base_addr, 0x0, wdata);

    fhgw_fpga_disable_rsfec(rsfec_base_addr, channel_no);

    // ------------------------- Reconfig to CPRI 4p9g -------------------------

    // AIB CLOCK1 & AIB CLOCK2 Select
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x322);
    wdata = (rdata0 & 0xFFFFFFF0) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x322, wdata);

    // RX FIFO STOP READ & RX FIFO PEMPTY
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x313);
    wdata = (rdata0 & 0xFFFFFF00) | 0xC5;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x313, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x31A);
    wdata = (rdata0 & 0xFFFFFFE3) | 0x1C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x31A, wdata);

    // RX FIFO FULL Threshold
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x312);
    wdata = (rdata0 & 0xFFFFFF00) | 0x3F;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x312, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x315);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x5;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x315, wdata);

    // RX FIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x314);
    wdata = (rdata0 & 0xFFFFFF00) | 0xD9;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x314, wdata);

    // TX AIB CLK1 SEL & TX AIB CLK2 SEL & TX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30D);
    wdata = (rdata0 & 0xFFFFFF03) | 0x18;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30D, wdata);

    // TX FIFO STOP RD & TX FIFO STOP WR
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x302);
    wdata = (rdata0 & 0xFFFFFF00) | 0xE4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x302, wdata);

    // TX GB TX IDWIDTH & TX GB TX ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x306);
    wdata = (rdata0 & 0xFFFFFF00) | 0x2B;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x306, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30E);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30E, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x301);
    wdata = (rdata0 & 0xFFFFFF00) | 0x5E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x301, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x303);
    wdata = (rdata0 & 0xFFFFFF00) | 0xF4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x303, wdata);

    // TX TXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x300);
    wdata = (rdata0 & 0xFFFFFF1F) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x300, wdata);

    // DCC CSR EN FSM
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x3C);
    wdata = (rdata0 & 0xFFFFFF00) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x3C, wdata);

    // RB CONT CAL & RB DCC BYP 7 RB DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x38);
    wdata = (rdata0 & 0xFFFFFF00) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x38, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x36);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x36, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x35);
    wdata = (rdata0 & 0xFFFFFF00) | 0x48;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x35, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x34);
    wdata = (rdata0 & 0xFFFFFF0C) | 0xC2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x34, wdata);

    // RXBIT CONTR PMA
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x37);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x37, wdata);

    // EN DIRECT TX & EN FEC D2 TX & EN TX GBX & TX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);
    wdata = (rdata0 & 0xFFFFFF58) | 0x83;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x5, wdata);

    // EN FIFO RD RX & RX FIFO CLK SEL & RX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);
    wdata = (rdata0 & 0xFFFFFF85) | 0x68;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x7, wdata);

    // RX GB ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xE);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x5;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xE, wdata);

    // RX SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xB);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xB, wdata);

    // RX TAG SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x9);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x9, wdata);

    // RXFIFO AE THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x11);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x11, wdata);

    // RXFIFO AE THLD & RX FIFO E THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x10);
    wdata = (rdata0 & 0xFFFFFF20) | 0x40;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x10, wdata);

    // RXFIFO AF THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x12);
    wdata = (rdata0 & 0xFFFFFF83) | 0x08;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x12, wdata);

    // RXFIFO RD EMPTY & RXFIFO WR FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x13);
    wdata = (rdata0 & 0xFFFFFF3F) | 0xC0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x13, wdata);

    // SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x8);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8, wdata);

    // TX CLK DP SEL & TX DATA IN SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);
    wdata = (rdata0 & 0xFFFFFFA3) | 0x0C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x4, wdata);

    // TX GB IDWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xC);
    wdata = (rdata0 & 0xFFFFFF8F) | 0x50;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xC, wdata);

    // TXFIFO PH COMP
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x17);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x30;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x17, wdata);

    // RX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x218);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x218, wdata);

    // RX FIFO DOUBLE WRITE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21C);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21C, wdata);

    // RD CLK SCG EN & WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x227);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x30;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x227, wdata);

    // RX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x226);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x226, wdata);

    // RX FIFO WR CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x225);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x225, wdata);

    // RX PHCOMP RD SEL & RX RXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21B);
    wdata = (rdata0 & 0xFFFFFF00) | 0x47;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21B, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x220);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x220, wdata);

    // RX RXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21A);
    wdata = (rdata0 & 0xFFFFFF00) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21A, wdata);

    // TX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x208);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x208, wdata);

    // TX FIFO DOUBLE READ
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x20B);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x20B, wdata);

    // TX FIFO RD CLK SCG EN & TX FIFO RD CLK SEL & TX FIFO WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x214);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x214, wdata);

    // HRDRST ALIGN BYPASS & HRDRST DCD CAL DONE BYPASS
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x215);
    wdata = (rdata0 & 0xFFFFFF5F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x215, wdata);

    // TX TX FIFO POWER MODE & TX WORD ALIGN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x210);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x210, wdata);

    // TX AIB TX DCC BYP & TX AIB TX DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32E);
    wdata = (rdata0 & 0xFFFFFFE7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32E, wdata);

    // RX FIFO FULL Threshold
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x231);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x231, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x233);
    wdata = (rdata0 & 0xFFFFFFC0) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x233, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x309);
    wdata = (rdata0 & 0xFFFFFF00) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x309, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x310);
    wdata = (rdata0 & 0xFFFFFF00) | 0x19;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x310, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x311);
    wdata = (rdata0 & 0xFFFFFF00) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x311, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x318);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x318, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x320);
    wdata = (rdata0 & 0xFFFFFF00) | 0x11;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x320, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32C);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32C, wdata);

    //TX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x20);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 5);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //RX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x20);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 6);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // set PMA tx/rx width mode , 20bits
    fhgw_fpga_tx_rx_width_mode (xcvr_base_addr, 0x11);

    // TX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);

    // RX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);

    // --------------------- Reconfig to CPRI 4p9g end -------------------------

    // rx phaseslip to change the o_rx_fifo_clk_phase
    fhgw_fpga_rx_phase_slip_low_speed (xcvr_base_addr);
    // Serdes Enable
    fhgw_fpga_serdes_enable (xcvr_base_addr);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    printk ("\nINFO: End of dynamic reconfiguration: 25G_PTP_RSFEC --> CPRI_4p9G\n\n");

    return return_value;
}

int32_t fhgw_25gptpfec_to_2p4gcpri(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    // DR start:  assert tx/rx reset ports
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, fhgw_dp_ctrl[channel_no], FHGW_FPGA_NO_SHIFT_OPS, 0x8);

    // Serdes Disable
    fhgw_fpga_serdes_disable (xcvr_base_addr);

    // Perform refclk_mux select start
    //1. switch PMA uC clock to XCVR-Refclk 1
    fhgw_fpga_swith_pma_uc_clock_1 (xcvr_base_addr);

    //2. REFCLK SEL SET
    // EC[3:0] Select reference clocks [0-8] muxed onto refclkin_in_A
    // EF[3:0] Selects which reference clock [0-8] is mapped to refclk2 in the Native PHY IP core
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xEF); //[3:0] refclk2 lookup register
    wdata = (rdata0 & 0xFFFFFF0F) | 0x0; // {4'b0000,rdata0[3:0]}
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xEC, wdata);

    //3. Switch PMA uC Clock to XCVR-Refclk 0
    fhgw_fpga_swith_pma_uc_clock_0 (xcvr_base_addr);

    //4. PMA Analog Reset
    //Reset the internal controller inside the PMA because the REFCLK source changed
    fhgw_fpga_pma_analog_reset (xcvr_base_addr);
    // Perform refclk_mux select end

    // ============================= CPRI SOFT CONFIG================================
         //[3:0] = cpri_rate_sel;
         //[4] = cpri_fec_en;
        //[9:5] = i_sl_rx_bitslipboundary_sel;
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, cprisoft_base_addr, 0x0);
    wdata = (rdata0 & 0xE0) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, cprisoft_base_addr, 0x0, wdata);

    fhgw_fpga_disable_rsfec(rsfec_base_addr, channel_no);

    // ------------------------- Reconfig to CPRI 2p4g -------------------------

    // AIB CLOCK1 & AIB CLOCK2 Select
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x322);
    wdata = (rdata0 & 0xFFFFFFF0) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x322, wdata);

    // RX FIFO STOP READ & RX FIFO PEMPTY
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x313);
    wdata = (rdata0 & 0xFFFFFF00) | 0xC5;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x313, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x31A);
    wdata = (rdata0 & 0xFFFFFFE3) | 0x1C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x31A, wdata);

    // RX FIFO FULL Threshold
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x312);
    wdata = (rdata0 & 0xFFFFFF00) | 0x3F;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x312, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x315);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x5;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x315, wdata);

    // RX FIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x314);
    wdata = (rdata0 & 0xFFFFFF00) | 0xD9;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x314, wdata);

    // TX AIB CLK1 SEL & TX AIB CLK2 SEL & TX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30D);
    wdata = (rdata0 & 0xFFFFFF03) | 0x18;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30D, wdata);

    // TX FIFO STOP RD & TX FIFO STOP WR
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x302);
    wdata = (rdata0 & 0xFFFFFF00) | 0xE4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x302, wdata);

    // TX GB TX IDWIDTH & TX GB TX ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x306);
    wdata = (rdata0 & 0xFFFFFF00) | 0x2B;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x306, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x30E);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x30E, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x301);
    wdata = (rdata0 & 0xFFFFFF00) | 0x5E;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x301, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x303);
    wdata = (rdata0 & 0xFFFFFF00) | 0xF4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x303, wdata);

    // TX TXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x300);
    wdata = (rdata0 & 0xFFFFFF1F) | 0xA0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x300, wdata);

    // DCC CSR EN FSM
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x3C);
    wdata = (rdata0 & 0xFFFFFF00) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x3C, wdata);

    // RB CONT CAL & RB DCC BYP 7 RB DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x38);
    wdata = (rdata0 & 0xFFFFFF00) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x38, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x36);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x1;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x36, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x35);
    wdata = (rdata0 & 0xFFFFFF00) | 0x48;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x35, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x34);
    wdata = (rdata0 & 0xFFFFFF0C) | 0xC2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x34, wdata);

    // RXBIT CONTR PMA
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x37);
    wdata = (rdata0 & 0xFFFFFF7F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x37, wdata);

    // EN DIRECT TX & EN FEC D2 TX & EN TX GBX & TX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x5);
    wdata = (rdata0 & 0xFFFFFF58) | 0x83;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x5, wdata);

    // EN FIFO RD RX & RX FIFO CLK SEL & RX ML SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x7);
    wdata = (rdata0 & 0xFFFFFF85) | 0x68;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x7, wdata);

    // RX GB ODWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xE);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x5;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xE, wdata);

    // RX SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xB);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xB, wdata);

    // RX TAG SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x9);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x9, wdata);

    // RXFIFO AE THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x11);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x11, wdata);

    // RXFIFO AE THLD & RX FIFO E THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x10);
    wdata = (rdata0 & 0xFFFFFF20) | 0x40;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x10, wdata);

    // RXFIFO AF THLD
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x12);
    wdata = (rdata0 & 0xFFFFFF83) | 0x08;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x12, wdata);

    // RXFIFO RD EMPTY & RXFIFO WR FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x13);
    wdata = (rdata0 & 0xFFFFFF3F) | 0xC0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x13, wdata);

    // SH LOCATION
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x8);
    wdata = (rdata0 & 0xFFFFFFDF) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8, wdata);

    // TX CLK DP SEL & TX DATA IN SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x4);
    wdata = (rdata0 & 0xFFFFFFA3) | 0x0C;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x4, wdata);

    // TX GB IDWIDTH
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0xC);
    wdata = (rdata0 & 0xFFFFFF8F) | 0x50;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0xC, wdata);

    // TXFIFO PH COMP
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x17);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x30;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x17, wdata);

    // RX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x218);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x218, wdata);

    // RX FIFO DOUBLE WRITE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21C);
    wdata = (rdata0 & 0xFFFFFFFE) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21C, wdata);

    // RD CLK SCG EN & WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x227);
    wdata = (rdata0 & 0xFFFFFFCF) | 0x30;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x227, wdata);

    // RX FIFO RD CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x226);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x226, wdata);

    // RX FIFO WR CLK SEL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x225);
    wdata = (rdata0 & 0xFFFFFF1F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x225, wdata);

    // RX PHCOMP RD SEL & RX RXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21B);
    wdata = (rdata0 & 0xFFFFFF00) | 0x47;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21B, wdata);

    // RX FIFO POWER MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x220);
    wdata = (rdata0 & 0xFFFFFF3F) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x220, wdata);

    // RX RXFIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x21A);
    wdata = (rdata0 & 0xFFFFFF00) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x21A, wdata);

    // TX DATAPATH MAPPING MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x208);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x208, wdata);

    // TX FIFO DOUBLE READ
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x20B);
    wdata = (rdata0 & 0xFFFFFFF7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x20B, wdata);

    // TX FIFO RD CLK SCG EN & TX FIFO RD CLK SEL & TX FIFO WR CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x214);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x214, wdata);

    // HRDRST ALIGN BYPASS & HRDRST DCD CAL DONE BYPASS
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x215);
    wdata = (rdata0 & 0xFFFFFF5F) | 0x80;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x215, wdata);

    // TX TX FIFO POWER MODE & TX WORD ALIGN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x210);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x210, wdata);

    // TX AIB TX DCC BYP & TX AIB TX DCC EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32E);
    wdata = (rdata0 & 0xFFFFFFE7) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32E, wdata);

    // RX FIFO FULL Threshold
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x231);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x231, wdata);

    // RX FIFO MODE
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x233);
    wdata = (rdata0 & 0xFFFFFFC0) | 0x20;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x233, wdata);

    // HIP OSC CLK SCG EN
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x309);
    wdata = (rdata0 & 0xFFFFFF00) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x309, wdata);

    // TX PHCOMP RD SEL & TX TXFIFO FULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x310);
    wdata = (rdata0 & 0xFFFFFF00) | 0x19;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x310, wdata);

    // TXFIFO POWER MODE & TX TXFIFO PFULL
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x311);
    wdata = (rdata0 & 0xFFFFFF00) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x311, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x318);
    wdata = (rdata0 & 0xFFFFFFFC) | 0x2;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x318, wdata);

    // RX BIT COUNTER ROLLOVER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x320);
    wdata = (rdata0 & 0xFFFFFF00) | 0x11;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x320, wdata);

    // RX BIT COUNTER ROLLOVER & SEL BIT COUNTER ADDER
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x32C);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x4;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x32C, wdata);

    //TX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x10);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x5);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 5);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    //RX REFCLK RATIO
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x84, 0x10);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x85, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x86, 0x6);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x87, 0x0);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x90, 0x1);

    // Polling PMA register
    // 4. Verify that the PMA register read/write is sent to the PMA by verifying that 0x8A[7] is asserted.
    //    Addr: 8A,bit7: cfg_core_int_in_prog_assert: Expect 1
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8A, 7);

    // 5. Verify that 0x8B[0] de-asserts to indicate that the PMA register read/write transaction completed.
    //   Addr: 8B,bit0: cfg_core_int_in_progress: Expect 0
    return_value += fhgw_fpga_polling_for_cfg_bit (xcvr_base_addr, 0x8B, 0);

    //Verify that 0x88 ,0x89 PMA attribute code is expected to return data
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x88, 6);
    return_value += fhgw_fpga_polling_for_cfg_value_compare (xcvr_base_addr, 0x89, 0);

    // Write 1'b1 to 0x8A[7] to clear the 0x8A[7] value
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x8A, 0x80);

    // set PMA tx/rx width mode , 20bits
    fhgw_fpga_tx_rx_width_mode (xcvr_base_addr, 0x11);

    // TX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);

    // RX DATA PATH MUX
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x7;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);

    // --------------------- Reconfig to CPRI 2p4g end -------------------------

    // rx phaseslip to change the o_rx_fifo_clk_phase
    fhgw_fpga_rx_phase_slip_low_speed (xcvr_base_addr);
    // Serdes Enable
    fhgw_fpga_serdes_enable (xcvr_base_addr);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    printk ("\nINFO: End of dynamic reconfiguration: 25G_PTP_RSFEC --> CPRI_2p4G\n\n");

    return return_value;
}

int32_t fhgw_rcfg_10gcpri_to_10gcpritunnel (uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    printk ("\nINFO: Start of dynamic reconfiguration: 10G_CPRI --> 10G_CPRI_tunnel\n\n");

    // ============================ EHIP CONFIG ===================================

    // phy_ehip_pcs_modes
    // use_striper [3]   0  -> 1
    // use_scr     [1]   1  -> 0
    // use_enc     [0]   1  -> 0

    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES);
    wdata = (rdata0 & 0xFFFFFFF4) | 0x8;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES);

    // tx_pld_conf
    // 350 tx_ehip_mode[2:0] 001 -> 010
    // Selects how the synchronous input to the EHIP will be mapped
    // 3h0: MAC interface
    // 3h1: MAC interface with PTP
    // 3h2: PCS (MII) interface <--
    // 3h3: PCS66 interface with forced encoder and scrambler bypass
    // 3h4: PCS66 interface
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x03;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);

    // rx_pld_conf
    // 355 rx_ehip_mode[2:0] 001 -> 010
    // Select RX Portmap Selects how data from the EHIP is presented through the AIB
    // 3h0: MAC interface
    // 3h1: MAC interface with PTP
    // 3h2: PCS (MII) interface <--
    // 3h3: PCS66 interface for OTN (forced descrambler bypass)
    // 3h4: PCS66 interface (descrambler optional)
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x03;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);

    // ============================= CPRI SOFT CONFIG================================

    //[3:0] = cpri_rate_sel;
    //[4] = cpri_fec_en;
    //[9:5] = i_sl_rx_bitslipboundary_sel;
    //[31] = cpri_tunneling_en;
    //24G+FEC = 1B, 10G NoFEC = 9
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, cprisoft_base_addr, 0x0);
    wdata = (rdata0 & 0x7FFFFFFF ) | 0x80000000;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, cprisoft_base_addr, 0x0, wdata);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);

    printk ("\nINFO: End of dynamic reconfiguration: 10G_CPRI --> 10G_CPRI_tunnel\n\n");

    return return_value;
}

int32_t fhgw_rcfg_10gcpritunnel_to_10gcpri(uint8_t channel_no, uint32_t eth_base_addr,
    uint32_t xcvr_base_addr, uint32_t rsfec_base_addr,
    uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    printk ("\nINFO: Dynamic reconfiguration: 10G_CPRI_tunnel --> 10G_CPRI\n\n");

    // ============================ EHIP CONFIG ===================================

    // phy_ehip_pcs_modes
    // use_striper [3]   0  <- 1
    // use_scr     [1]   1  <- 0
    // use_enc     [0]   1  <- 0
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES);
    wdata = (rdata0 & 0xFFFFFFF4) | 0x3;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, FHGW_FPGA_PHY_EHIP_PCS_MODES);

    // tx_pld_conf
    // 350 tx_ehip_mode[2:0] 001 <- 010
    // Selects how the synchronous input to the EHIP will be mapped
    // 3h0: MAC interface
    // 3h1: MAC interface with PTP
    // 3h2: PCS (MII) interface <--
    // 3h3: PCS66 interface with forced encoder and scrambler bypass
    // 3h4: PCS66 interface
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x02;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x350, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x350);
    // rx_pld_conf
    // 355 rx_ehip_mode[2:0] 001 -> 010
    // Select RX Portmap Selects how data from the EHIP is presented through the AIB
    // 3h0: MAC interface
    // 3h1: MAC interface with PTP
    // 3h2: PCS (MII) interface <--
    // 3h3: PCS66 interface for OTN (forced descrambler bypass)
    // 3h4: PCS66 interface (descrambler optional)
    // rx_pld_conf
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);
    wdata = (rdata0 & 0xFFFFFFF8) | 0x02;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, eth_base_addr, 0x355, wdata);
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, eth_base_addr, 0x355);

    // ============================= CPRI SOFT CONFIG================================

    //[3:0] = cpri_rate_sel;
    //[4] = cpri_fec_en;
    //[9:5] = i_sl_rx_bitslipboundary_sel;
    //[31] = cpri_tunneling_en;
    //24G+FEC = 1B, 10G NoFEC = 9
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, cprisoft_base_addr, 0x0);
    wdata = (rdata0 & 0x7FFFFFFF ) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, cprisoft_base_addr, 0x0, wdata);

    // Overwrite for MAC+PCS loop-back configuration
    //serdes_loop_on (xcvr_base_addr);

    printk ("\nINFO: End of dynamic reconfiguration: 10G_CPRI_tunnel --> 10G_CPRI\n\n");
    return return_value;
}

// Reconfiguration to CPRI Tunneling
int32_t fhgw_rcfg_enable_cpri_ls_tunneling(uint8_t channel_no, uint32_t xcvr_base_addr,
                                            uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    // ============================= CPRI SOFT CONFIG================================

        //[3:0] = cpri_rate_sel;
        //[4] = cpri_fec_en;
        //[9:5] = i_sl_rx_bitslipboundary_sel;
        //24G+FEC = 1B, 10G NoFEC = 9 , 9G =6
    	//[31] = tunneling_enabled;
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, cprisoft_base_addr, 0x0);
    wdata = (rdata0 | 0x80000000);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, cprisoft_base_addr, 0x0, wdata);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    printk ("\nINFO: End of dynamic reconfiguration: CPRI_low_speed --> CPRI_low_speed_tunneling\n\n");

    return return_value;
}

// Reconfiguration to CPRI
int32_t fhgw_rcfg_disable_cpri_ls_tunneling(uint8_t channel_no, uint32_t xcvr_base_addr,
                                                uint32_t cprisoft_base_addr)
{
    int32_t return_value = 0;
    uint32_t rdata0;
    uint32_t wdata;

    // ============================= CPRI SOFT CONFIG================================

    //[3:0] = cpri_rate_sel;
    //[4] = cpri_fec_en;
    //[9:5] = i_sl_rx_bitslipboundary_sel;
    //24G+FEC = 1B, 10G NoFEC = 9 , 9G =6
    //[31] = tunneling_enabled;
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, cprisoft_base_addr, 0x0);
    wdata = (rdata0 & 0x7FFFFFFF);
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, cprisoft_base_addr, 0x0, wdata);

    // Reset AIB - Assert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0xAA;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    // Reset AIB - Deassert
    rdata0 = FHGW_FPGA_REG_READ(fpga_dev->regs, xcvr_base_addr, 0x400E2);
    wdata = (rdata0 & 0xFFFFFF55) | 0x0;
    FHGW_FPGA_REG_WRITE(fpga_dev->regs, xcvr_base_addr, 0x400E2, wdata);

    printk ("\nINFO: End of dynamic reconfiguration: CPRI_low_speed_tunneling --> CPRI_low_speed \n\n");

    return return_value;
}

void fhgw_fpga_update_address(uint8_t channel_no, fpga_address *regaddr)
{
    switch(channel_no) {
        case FHGW_FPGA_DR_CH0:
            regaddr->eth_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_C3_ELANE_RECONFIG_CH0;
            regaddr->xcvr_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_C3_XCVR_RECONFIG_CH0;
            regaddr->rsfec_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_RSFEC_AVMM_CONFIG_CH0;
            regaddr->cprisoft_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_CPRI_AVMM_CONFIG_CH0;
            break;
        case FHGW_FPGA_DR_CH1:
            regaddr->eth_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_C3_ELANE_RECONFIG_CH1;
            regaddr->xcvr_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_C3_XCVR_RECONFIG_CH1;
            regaddr->rsfec_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_RSFEC_AVMM_CONFIG_CH1;
            regaddr->cprisoft_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_CPRI_AVMM_CONFIG_CH1;
            break;
        case FHGW_FPGA_DR_CH2:
            regaddr->eth_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_C3_ELANE_RECONFIG_CH2;
            regaddr->xcvr_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_C3_XCVR_RECONFIG_CH2;
            regaddr->rsfec_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_RSFEC_AVMM_CONFIG_CH2;
            regaddr->cprisoft_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_CPRI_AVMM_CONFIG_CH2;
            break;
        case FHGW_FPGA_DR_CH3:
            regaddr->eth_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_C3_ELANE_RECONFIG_CH3;
            regaddr->xcvr_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_C3_XCVR_RECONFIG_CH3;
            regaddr->rsfec_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_RSFEC_AVMM_CONFIG_CH3;
            regaddr->cprisoft_base_addr = FHGW_DR_GROUP1_BASE_ADDR + FHGW_CPRI_AVMM_CONFIG_CH3;
            break;
        case FHGW_FPGA_DR_CH4:
            regaddr->eth_base_addr = FHGW_DR_GROUP2_BASE_ADDR + FHGW_C3_ELANE_RECONFIG_CH4;
            regaddr->xcvr_base_addr = FHGW_DR_GROUP2_BASE_ADDR + FHGW_C3_XCVR_RECONFIG_CH4;
            regaddr->rsfec_base_addr = FHGW_DR_GROUP2_BASE_ADDR + FHGW_RSFEC_AVMM_CONFIG_CH4;
            regaddr->cprisoft_base_addr = FHGW_DR_GROUP2_BASE_ADDR + FHGW_CPRI_AVMM_CONFIG_CH4;
            break;
        case FHGW_FPGA_DR_CH5:
            regaddr->eth_base_addr = FHGW_DR_GROUP2_BASE_ADDR + FHGW_C3_ELANE_RECONFIG_CH5;
            regaddr->xcvr_base_addr = FHGW_DR_GROUP2_BASE_ADDR + FHGW_C3_XCVR_RECONFIG_CH5;
            regaddr->rsfec_base_addr = FHGW_DR_GROUP2_BASE_ADDR + FHGW_RSFEC_AVMM_CONFIG_CH5;
            regaddr->cprisoft_base_addr = FHGW_DR_GROUP2_BASE_ADDR + FHGW_CPRI_AVMM_CONFIG_CH5;
            break;
        default:
            break;
    }

    printk("\n DRV DBG: eth_base_addr : 0x%x, xcvr_base_addr : 0x%x, rsfec_base_addr : 0x%x, cprisoft_base_addr : 0x%x", regaddr->eth_base_addr, regaddr->xcvr_base_addr, regaddr->rsfec_base_addr, regaddr->cprisoft_base_addr);
}

void fhgw_fpga_ecpri_to_cpri_switch(uint8_t channel_no, uint8_t linerate)
{
    uint8_t mode = 0;

    fpga_address regaddr;

    fhgw_fpga_update_address(channel_no, &regaddr);

    mode = fghw_fpga_get_drmode(channel_no);
    printk ("\nINFO: ******Current Mode****** : %d ",mode);

    if (mode == CPRI_9p8G_tunneling || mode == CPRI_4p9G_tunneling || mode == CPRI_2p4G_tunneling) {
        fhgw_rcfg_disable_cpri_ls_tunneling(channel_no, regaddr.xcvr_base_addr, regaddr.cprisoft_base_addr);
    }

    switch(mode) {
        printk ("\nINFO: Switch Mode Calling ");
        case CPRI_9p8G_tunneling:
        fhgw_9p8gcpri_to_25gptpfec(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
        break;
        case CPRI_4p9G_tunneling:
        fhgw_4p9gcpri_to_25gptpfec(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
        break;
        case CPRI_2p4G_tunneling:
        fhgw_2p4gcpri_to_25gptpfec(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
        break;
        case CPRI_10G_TUNNEL:
        fhgw_rcfg_10gcpritunnel_to_10gcpri(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
        fhgw_10gcpri_to_25gptpfec(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
        break;
        default:
        break;
    }

    switch(linerate) {
        case CPRI_9p8G_tunneling:
            fhgw_25gptpfec_to_9p8gcpri(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
            break;
        case CPRI_4p9G_tunneling:
            fhgw_25gptpfec_to_4p9gcpri(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
            break;
        case CPRI_2p4G_tunneling:
            fhgw_25gptpfec_to_2p4gcpri(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
            break;
        case CPRI_10G_TUNNEL:
            fhgw_25gptpfec_to_10gcpri(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
            fhgw_rcfg_10gcpri_to_10gcpritunnel(channel_no, regaddr.eth_base_addr, regaddr.xcvr_base_addr, regaddr.rsfec_base_addr, regaddr.cprisoft_base_addr);
            break;
        default:
            break;
    }

    if (linerate == CPRI_9p8G_tunneling || linerate == CPRI_4p9G_tunneling || linerate == CPRI_2p4G_tunneling) {
        fhgw_rcfg_enable_cpri_ls_tunneling(channel_no, regaddr.xcvr_base_addr, regaddr.cprisoft_base_addr);
    }

    fghw_fpga_set_drmode(channel_no, linerate);
}

static void fhgw_fpga_pcie_intr_remove(struct fhgw_fpga_dev *fpga_dev)
{
    free_irq(pci_irq_vector(fpga_dev->pdev, 0), fpga_dev->pdev);
    pci_free_irq_vectors(fpga_dev->pdev);
}

/* irq_task_handler - work queue task handler for IRQ Events*/
static void irq_task_handler(struct work_struct *work)
{
    irq_intr_work *task_work = container_of(work, irq_intr_work, irq_work);
    int no_bytes = 0;

    printk("%s: Eent Task Handler\n", __func__);

    irq_info.irq_sts = FHGW_FPGA_REG_READ(fpga_dev->regs, FPGA_INTERRUPT_STATUS, FHGW_FPGA_NO_SHIFT_OPS);

    /* Post to user space only for valid event */
    down(&fpga_sem);
    if(kfifo_is_full(&event_rxkfifo) || (kfifo_len(&event_rxkfifo) % sizeof(irq_info))) {
        printk("%s: kfifoin check failed: kfifo_len = %d\n", __func__, kfifo_len(&event_rxkfifo));
        up(&fpga_sem);
        kfree(task_work);
        return;
    }

    no_bytes = kfifo_in(&event_rxkfifo, &irq_info, sizeof(irq_info));
    if(no_bytes == sizeof(irq_info)) {
        printk("%s: kfifoin of %d bytes done\n", __func__, no_bytes);
    }
    else {
        printk("%s: kfifoin of %d bytes failed\n", __func__, no_bytes);
        /*Handle kfifo out here */
    }
    up(&fpga_sem);
    wake_up_interruptible(&event_queue);
    kfree(task_work);
    return;
}

static irqreturn_t fhgw_fpga_msi_complete(int irq, void *dev_bk)
{
    int ret = 0;

    printk("\n MSI IRQ Received !!!");

    /* Allocate IRQ work memory to pass data to the work */
    pirq_work = (irq_intr_work *)kmalloc(sizeof(irq_intr_work), GFP_ATOMIC);
    if (pirq_work) {

        /* Initialize IRQ Work Structure */
        INIT_WORK((struct work_struct *)&pirq_work->irq_work, irq_task_handler);

        /*Pass IRQ status to work and queue the work*/
        //pirq_work->irq_sts = FHGW_FPGA_REG_READ(fpga_dev->regs, FPGA_INTERRUPT_STATUS, FHGW_FPGA_NO_SHIFT_OPS);
        ret = queue_work(fpga_wq->irq_wq, (struct work_struct *)&pirq_work->irq_work);
        if (ret == 0) {
            printk("%s: queue_work - IRQ failed %d\n", __func__, ret);
            return IRQ_NONE;
        }
    } else {
        printk("%s: IRQ work memory allocation failed %d\n", __func__, ret);
        return IRQ_NONE;
    }

    return IRQ_HANDLED;
}

static int fhgw_fpga_pull_intr_data(void)
{
    int retval;
    int msi_capability;
    uint32_t msi_header, temp_addr;
    uint32_t interrupt_data;
    uint64_t interrupt_addr;

    // Determine if MSI is enabled
    msi_capability = pci_find_capability(fpga_dev->pdev, PCI_CAP_ID_MSI);
    if (!msi_capability) {
        printk("couldn't find associated msi capability structure");
        retval = -EOPNOTSUPP;
        goto failed_msi_init;
    }

    if (pci_read_config_dword(fpga_dev->pdev,
                msi_capability, &msi_header)) {
        printk("error reading msi header from device config space");
        goto failed_msi_init;
    }

    // Determine address used to trigger MSI interrupt
    // Read lower address register
    if (pci_read_config_dword(fpga_dev->pdev,
                msi_capability + 0x4, &temp_addr)) {
        printk("error reading msi lower address from device config space");
        goto failed_msi_init;
    }

    interrupt_addr = temp_addr;
    // Read upper address register, if present
    if ((msi_header >> 0x10) & 0x0080) { // 64 bit address capable field
        // Read upper address register
        if (pci_read_config_dword(fpga_dev->pdev,
                    msi_capability + 0x8, &temp_addr)) {
            printk("error reading msi upper address from device config space");
            goto failed_msi_init;
        }

        interrupt_addr |= temp_addr << 0x10;
    }

    // Determine data used to trigger MSI interrupt
    if ((msi_header >> 0x10) & 0x0080) { // 64-bit address enabled
        if ((msi_header >> 0x10) & 0x0200) { // Extended message enable
            retval = pci_read_config_dword(fpga_dev->pdev,
                    msi_capability + 0xc, &interrupt_data);
        } else {
            retval = pci_read_config_word(fpga_dev->pdev,
                    msi_capability + 0xc, (uint16_t *) &interrupt_data);
        }
    } else {
        if ((msi_header >> 0x10) & 0x0200) { // Extended message enable
            retval = pci_read_config_dword(fpga_dev->pdev,
                    msi_capability + 0x8, &interrupt_data);
        } else {
            retval = pci_read_config_word(fpga_dev->pdev,
                    msi_capability + 0x8, (uint16_t *) &interrupt_data);
        }
    }

    if (retval) {
        printk("error reading msi data from device config space");
        fhgw_fpga_pcie_intr_remove(fpga_dev);
        goto failed_msi_init;
    }

    fpga_dev->msi_capability = msi_capability;
    fpga_dev->interrupt_addr = interrupt_addr;
    fpga_dev->interrupt_data = interrupt_data;

    return 0;

failed_msi_init:
    return retval;
}

static int fhgw_fpga_pcie_intr_probe(struct pci_dev *pdev)
{
    // Determine if MSI is enabled
    if (!pci_find_capability(pdev, PCI_CAP_ID_MSI)) {
        printk("couldn't find associated msi capability structure");
        goto failed_alloc_irq;
    }

    // Allocate irq vectors and register interrupt handler
    if (pci_alloc_irq_vectors(pdev, 1, 1, PCI_IRQ_ALL_TYPES) <= 0) {
        printk("couldn't allocate irq vectors");
        goto failed_alloc_irq;
    }

    if (request_irq(pci_irq_vector(pdev, 0), fhgw_fpga_msi_complete, 0, "fhgw_fpga_drv", pdev)) {
        printk("couldn't register interrupt");
        goto failed_request_irq;
    }

#if 0
    if (fhgw_fpga_pull_intr_data()) {
        printk("couldn't read necessary data from capability structure");
        goto failed_msi_init;
    }
#endif

    /* Allocate memory to store work queue */
    fpga_wq = (fhgw_fpga_work_queue *)kzalloc(sizeof(fhgw_fpga_work_queue), GFP_KERNEL);
    if(!fpga_wq) {
        printk("%s: Event handler Workqueue struct Memory Allocation Failed\n", __func__);
    }

    /* KFIFO Memory Allocation for Events */
    if(kfifo_alloc(&event_rxkfifo, KFIFO_BUFFER_SIZE, GFP_KERNEL)) {
        printk("%s: event_rxkfifo allocation failed\n", __func__);
    }

    /*wait queue Initializayion at run time */
    init_waitqueue_head(&event_queue);

    /* Create Workqueue and initialize task handlers */
    fpga_wq->irq_wq = create_workqueue("event_wq");

    /* Initialize Semaphore */
    sema_init(&fpga_sem, 1);

    return 0;

failed_msi_init:
    free_irq(pci_irq_vector(pdev, 0), pdev);
failed_request_irq:
    pci_free_irq_vectors(pdev);
failed_alloc_irq:
    return -1;
}

static int fhgw_fpga_drv_open(struct inode* inode, struct file* file)
{
    return 0;
}

static long fhgw_fpga_drv_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
    ioctl_arg_t params = {0};
    fpga_address regaddr;
    fpga_irq_info event_rxkfifo_data;
    int bytes_read = 0;

    if(!file)
        return -EACCES;

    if (copy_from_user(&params, (ioctl_arg_t *)arg, sizeof(ioctl_arg_t))) {
        return -EACCES;
    }

    switch (cmd) {
        case FHGW_FPGA_READ_VALUE:
            params.value = FHGW_FPGA_REG_READ(fpga_dev->regs, params.regaddr + params.offset, FHGW_FPGA_NO_SHIFT_OPS);
            if (copy_to_user((ioctl_arg_t *)arg, &params, sizeof(ioctl_arg_t))) {
                return -EACCES;
            }
            break;

        case FHGW_FPGA_WRITE_VALUE:
            FHGW_FPGA_REG_WRITE(fpga_dev->regs, params.regaddr + params.offset, FHGW_FPGA_NO_SHIFT_OPS, params.value);
            break;

        case FHGW_FPGA_DR_INIT:
            fhgw_fpga_dr_init();
            break;

        case FHGW_FPGA_SERDES_LOOPON:
            fhgw_fpga_update_address(params.dr_params.channel_no, &regaddr);
            printk("\n DRV DBG : FHGW_FPGA_SERDES_LOOPON  Channel : %d regaddr.xcvr_base_addr : 0x%x", params.dr_params.channel_no, regaddr.xcvr_base_addr);
            fhgw_fpga_serdes_loop_on(regaddr.xcvr_base_addr);
            break;

        case FHGW_FPGA_GENERAL_CALIBRATION:
            printk("\n DRV DBG : FHGW_FPGA_GENERAL_CALIBRATION Channel : %d linerate : %d", params.dr_params.channel_no, params.dr_params.linerate);
            fhgw_fpga_update_address(params.dr_params.channel_no, &regaddr);
            fhgw_fpga_general_calibration (regaddr.xcvr_base_addr, params.dr_params.linerate);
            break;

        case FHGW_FPGA_DYNAMIC_RECONFIG_IP:
            printk("\n DRV DBG : FHGW_FPGA_GENERAL_CALIBRATION Channel : %d linerate : %d", params.dr_params.channel_no, params.dr_params.linerate);
            fhgw_fpga_ecpri_to_cpri_switch(params.dr_params.channel_no, params.dr_params.linerate);
            break;

        case FHGW_FPGA_ETH_READ_STATS:
            fhgw_fpga_read_stats(FHGW_FPGA_ETH_TX_STATS, &params.txrx_stats);
            fhgw_fpga_read_stats(FHGW_FPGA_ETH_RX_STATS, &params.txrx_stats);

            if (copy_to_user((ioctl_arg_t *)arg, &params, sizeof(ioctl_arg_t))) {
                return -EACCES;
            }
            break;

        case FHGW_FPGA_EVENT_WAIT:
            printk("%s: Waiting for Event\n", __func__);
            if(wait_event_interruptible(event_queue, (kfifo_is_empty(&event_rxkfifo) == 0))) {
                printk("%s: wait_event_interruptible failed\n", __func__);
                return -EINVAL;
            }
            printk("%s: Event woken up\n", __func__);

            /*Read event data from kfifo*/
            bytes_read = kfifo_out(&event_rxkfifo, &event_rxkfifo_data, sizeof(irq_info));
            if(bytes_read == sizeof(irq_info)) {
                printk("%s: kfifo out of %d bytes done\n", __func__, bytes_read);
            }
            else {
                printk("%s: kfifo out of %d bytes failed\n", __func__, bytes_read);
                return -EINVAL;
            }

            params.intr_params.irq_sts = event_rxkfifo_data.irq_sts;

            /* Copy the Eent information to user application */
            if (copy_to_user((ioctl_arg_t *)arg, &params, sizeof(ioctl_arg_t))) {
                return -EACCES;
            }

            printk("%s: Event kfifo_to_user Done\n", __func__);
            break;

        default:
            return -EINVAL;
    }

    return 0;
}

static struct file_operations fhgw_fpga_drv_fops = {
    .owner = THIS_MODULE,
    .open = fhgw_fpga_drv_open,
    .unlocked_ioctl = fhgw_fpga_drv_ioctl,
};

static void fhgw_fpga_drv_remove_chardev(void)
{
    device_destroy(fhgw_fpga_drv_class, devbase);
    class_destroy(fhgw_fpga_drv_class);
    cdev_del(&fpga_dev->cdev);
    unregister_chrdev_region(devbase, 1);
}

static int fhgw_fpga_drv_setup_chardev(void)
{
    if (alloc_chrdev_region(&devbase, 0, 1, "fhgw_fpga_drv") < 0)
        return -1;

    cdev_init(&fpga_dev->cdev, &fhgw_fpga_drv_fops);

    if (cdev_add(&fpga_dev->cdev, devbase, 1) < 0)
        goto err_chrdev_region;

    if ((fhgw_fpga_drv_class = class_create(THIS_MODULE, "fhgw_fpga_class")) == NULL) {
        goto err_unregister_chrdev;
    }

    if (device_create(fhgw_fpga_drv_class, NULL, devbase,
                NULL, "fhgw_fpga_dev") == NULL) {
        goto err_destroy_class;
    }

    return 0;

err_destroy_class:
    class_destroy(fhgw_fpga_drv_class);
err_unregister_chrdev:
    cdev_del(&fpga_dev->cdev);
err_chrdev_region:
    unregister_chrdev_region(devbase, 1);
    return -1;
}

static struct
fhgw_fpga_dev *fhgw_fpga_setup_dev(struct pci_dev *pdev)
{
	if(pci_enable_device(pdev)) {
		dev_err(&pdev->dev,"FPGA nic PCI enable failed\n");
		return NULL;
	}

	if(!(pci_resource_flags(pdev, 0) & IORESOURCE_MEM)) {
		dev_err(&pdev->dev,"PCI base address find failure in pci_resource_flags()\n");
		goto out_disable_dev;
	}

	if(pci_request_regions(pdev, fhgw_fpga_driver_name)) {
		dev_err(&pdev->dev, "Could not request PCI mem regions\n");
		goto out_disable_dev;
	}

	pci_set_master(pdev);

	fpga_dev->regs = ioremap_nocache(pci_resource_start(pdev, 0), FHGW_FPGA_REG_SIZE);
	if (!fpga_dev->regs)	{
		dev_err(&pdev->dev,"PCI memory remap failure\r\n");
		goto out_release_regions;
	}

	printk("BASE ADDRESS: %lx\r\n", (uint32_t *)fpga_dev->regs);

    if (fhgw_fpga_drv_setup_chardev())
            goto out_release_regions;

	return fpga_dev;

out_release_regions:
	pci_release_regions(pdev);
out_disable_dev:
	pci_disable_device(pdev);
	return NULL;
}

void
fhgw_fpga_remove(struct pci_dev *pdev)
{
    fhgw_fpga_pcie_intr_remove(fpga_dev);
	iounmap(fpga_dev->regs);
	pci_release_regions(fpga_dev->pdev);
}

static int
fhgw_fpga_probe(struct pci_dev *pdev, const struct pci_device_id *pent)
{
    fpga_dev = fhgw_fpga_setup_dev(pdev);
    if(fpga_dev == NULL) {
        return -1;
    }

    fpga_dev->pdev = pdev;

    // Save the fpga_dev in (private) driver data
    pci_set_drvdata(pdev, fpga_dev);

    if (fhgw_fpga_pcie_intr_probe(fpga_dev->pdev) < 0) {
        fhgw_fpga_drv_remove_chardev();
        kfree(fpga_dev);
        return -1;
    }

    return 0;
}

static struct pci_driver fhgw_fpga_driver = {
    .name 		=    "fhgw_fpga_drv",
    .id_table 	=    fhgw_fpga_id_table,
    .remove 	=    fhgw_fpga_remove,
    .probe 		=    fhgw_fpga_probe,
    .suspend 	=    NULL,
    .resume 	=    NULL,
    .shutdown 	=    NULL,
    .err_handler =  NULL,
};

static int
fhgw_fpga_init_module(void)
{
    int status;

    fpga_dev = (struct fhgw_fpga_dev *)kmalloc(sizeof(struct fhgw_fpga_dev), GFP_KERNEL);
    if (!fpga_dev)
        return -1;

    status = pci_register_driver(&fhgw_fpga_driver);
    if (status)
        return -1;

    printk("\n FHGW FPGA DRIVER VERSION : %d.%d", FHGW_FPGA_DRV_VERSION, FHGW_FPGA_DRV_SUBVERSION);

    return 0;
}

static void
__exit fhgw_fpga_driver_exit(void)
{
	pci_unregister_driver(&fhgw_fpga_driver);
	fhgw_fpga_drv_remove_chardev();
	kfree(fpga_dev);
	printk("exiting fhgw fpga driver\n");
}

MODULE_DEVICE_TABLE(pci, fhgw_fpga_id_table);
module_init(fhgw_fpga_init_module);
module_exit(fhgw_fpga_driver_exit);
MODULE_LICENSE("GPL");
