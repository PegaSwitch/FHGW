#include <fhgw_fpga_ioctl.h>
#include <fhgw_fpga_lib.h>

int32_t fd;
event_fp fhgw_fpga_event_func;

#define FHGW_FPGA_DEV_NAME "/dev/fhgw_fpga_dev"

uint32_t fhgw_fpga_drChannel[] = {
    FPGA_DYNAMIC_RECONFIG_IP_CH0_BASE,
    FPGA_DYNAMIC_RECONFIG_IP_CH1_BASE,
    FPGA_DYNAMIC_RECONFIG_IP_CH2_BASE,
    FPGA_DYNAMIC_RECONFIG_IP_CH3_BASE,
    FPGA_DYNAMIC_RECONFIG_IP_CH4_BASE,
    FPGA_DYNAMIC_RECONFIG_IP_CH5_BASE
};

uint32_t fhgw_fpga_ethChannel[] = {
    FPGA_ALDRIN_SIDE_ETHER_CH0_BASE,
    FPGA_ALDRIN_SIDE_ETHER_CH1_BASE,
    FPGA_ALDRIN_SIDE_ETHER_CH2_BASE,
    FPGA_ALDRIN_SIDE_ETHER_CH3_BASE,
    FPGA_ALDRIN_SIDE_ETHER_CH4_BASE,
    FPGA_ALDRIN_SIDE_ETHER_CH5_BASE
};

uint32_t fhgw_fpga_roeChannel[] = {
    FPGA_ROE_CH0_BASE,
    FPGA_ROE_CH1_BASE,
    FPGA_ROE_CH2_BASE,
    FPGA_ROE_CH3_BASE,
    FPGA_ROE_CH4_BASE,
    FPGA_ROE_CH5_BASE
};

uint32_t fhgw_fpga_dpctrl[] = {
    FPGA_DATAPATH_CTRL_CH0,
    FPGA_DATAPATH_CTRL_CH1,
    FPGA_DATAPATH_CTRL_CH2,
    FPGA_DATAPATH_CTRL_CH3,
    FPGA_DATAPATH_CTRL_CH4,
    FPGA_DATAPATH_CTRL_CH5
};

uint32_t fhgw_fpga_port_mode[] = {
    FPGA_MODE_SEL_CH0,
    FPGA_MODE_SEL_CH1,
    FPGA_MODE_SEL_CH2,
    FPGA_MODE_SEL_CH3,
    FPGA_MODE_SEL_CH4,
    FPGA_MODE_SEL_CH5
};

uint32_t fhgw_fpga_port_loopback[] = {
    FPGA_LOOPBACK_SEL_CH0,
    FPGA_LOOPBACK_SEL_CH1,
    FPGA_LOOPBACK_SEL_CH2,
    FPGA_LOOPBACK_SEL_CH3,
    FPGA_LOOPBACK_SEL_CH4,
    FPGA_LOOPBACK_SEL_CH5
};

int32_t fpga_dev_open()
{
    fd = open(FHGW_FPGA_DEV_NAME, O_RDWR);
    if (fd < 0) {
        printf("\nError: Device open");
        return FPGA_RET_FAILED;
    }
    return FPGA_RET_SUCCESS;
}

void fpga_dev_close()
{
    close(fd);
}

int8_t fpga_validate_input_params(uint8_t option, uint8_t value)
{
    switch(option) {
        case FPGA_VALIDATE_BLOCK:
            if (value >= FPGA_SYSTEM_REGISTER_BLOCK && value <= FPGA_PTP_REGISTER_BLOCK)
                return FPGA_RET_SUCCESS;
            break;
        case FPGA_VALIDATE_CHANNEL:
            if (value >= FPGA_MIN_CHANNEL_NUM && value <= FPGA_MAX_CHANNEL_NUM)
                return FPGA_RET_SUCCESS;
            break;
        case FPGA_VALIDATE_PORTNUM:
            if (value >= ETH_PORT0 && value <= CPRI_PORT5)
                return FPGA_RET_SUCCESS;
            break;
        case FPGA_VALIDATE_PORTSPEED:
            if (value >= E25G_PTP_FEC && value <= CPRI_10G_TUNNEL)
                return FPGA_RET_SUCCESS;
            break;
        case FPGA_VALIDATE_LED:
            if (value >= LED_CPRI0 && value <= LED_USR4)
                return FPGA_RET_SUCCESS;
            break;
    };
    return FPGA_RET_FAILED;
}

uint32_t fpga_get_base_addr(uint32_t block, uint8_t channelno)
{
    uint32_t base_addr = 0;

    switch(block) {
        case FPGA_SYSTEM_REGISTER_BLOCK:
            base_addr = FPGA_SYSTEM_REGISTER_BASE;
            break;
        case FPGA_DR_REGISTER_BLOCK:
            base_addr = fhgw_fpga_drChannel[channelno];
            break;
        case FPGA_ETH_REGISTER_BLOCK:
            base_addr = fhgw_fpga_ethChannel[channelno];
            break;
        case FPGA_ROE_REGISTER_BLOCK:
            base_addr = fhgw_fpga_roeChannel[channelno];
            break;
        case FPGA_PTP_REGISTER_BLOCK:
            /* PTP block */
            break;
    }

    return base_addr;
}

int32_t fpga_reg_read(uint8_t block, uint8_t channelno, uint32_t offset)
{
	ioctl_arg_t params;

    memset(&params, 0, sizeof(ioctl_arg_t));

	if(fpga_validate_input_params(FPGA_VALIDATE_BLOCK, block) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

	if(fpga_validate_input_params(FPGA_VALIDATE_CHANNEL, channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

	params.regaddr = fpga_get_base_addr(block, channelno);
	params.offset = offset;
	params.value = 0;

	if(ioctl(fd, FHGW_FPGA_READ_VALUE, &params) < 0) {
		printf("Error in ioctl get");
        return FPGA_RET_FAILED;
	}

    printf("\n LIB DBG : Read   Reg Addr : 0x%x Offset : 0x%x Value : %d", params.regaddr, params.offset, params.value);

	return params.value;
}

int8_t fpga_reg_write(uint8_t block, uint8_t channelno, uint32_t offset, uint32_t value)
{	
    ioctl_arg_t params;

    memset(&params, 0, sizeof(ioctl_arg_t));

    if(fpga_validate_input_params(FPGA_VALIDATE_BLOCK, block) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_CHANNEL, channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    params.regaddr = fpga_get_base_addr(block, channelno);
    params.offset = offset;
    params.value = value;

    if(ioctl(fd, FHGW_FPGA_WRITE_VALUE, &params) < 0) {
        printf("Error in ioctl set");
        return FPGA_RET_FAILED;
    }

    printf("\n LIB DBG : Write  Reg Addr : 0x%x Offset : 0x%x Value : %d", params.regaddr, params.offset, params.value);

    return FPGA_RET_SUCCESS;
}

int8_t fhgw_fpga_EventHandlerInit(event_fp *func_ptr)
{
    if (!func_ptr)
        return FPGA_RET_FAILED;

    fhgw_fpga_event_func = (event_fp *)func_ptr;

    if(pthread_create(&pThread_id, NULL, fhgw_fpga_wait_evnt_irq, NULL)){
        printf("\n Pthread create failed");
    }

    return FPGA_RET_SUCCESS;
}

void fhgw_fpga_EventHandlerExit(void)
{
    if(pthread_cancel(pThread_id) != 0)
        printf("\n Failed in pthread cancel");
}

void *fhgw_fpga_wait_evnt_irq(void)
{
    uint32_t ret;
    ioctl_arg_t params;
    fhgw_fpga_irq_event_info irq_event_info;

    while(1){
        memset(&irq_event_info, 0, sizeof(fhgw_fpga_irq_event_info));
        ret = ioctl(fd, FHGW_FPGA_EVENT_WAIT, &params);
        if(ret){
            usleep(300000);
            continue;
        }

        irq_event_info.event_val = params.intr_params.irq_sts;

        if(fhgw_fpga_event_func != NULL)
            ((event_fp)fhgw_fpga_event_func)(&irq_event_info);
        else
            printf("Event Function pointer - NULL");
    }
    pthread_exit(NULL);
}

int32_t get_fpga_rev_ver()
{
    return FHGW_FPGA_REG_READ(FPGA_SYSTEM_REGISTER_BLOCK, 0, FPGA_REVISION);
}

int32_t rd_scratch_pad_reg()
{
    return FHGW_FPGA_REG_READ(FPGA_SYSTEM_REGISTER_BLOCK, 0, FPGA_SCRATCH_PAD);
}

int32_t wr_scratch_pad_reg(uint32_t scr_val)
{
    return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, FPGA_SCRATCH_PAD, scr_val);
}

int8_t fpga_dr_linerate_configure(uint8_t channel, uint8_t linerate)
{	
    ioctl_arg_t params;

    if(fpga_validate_input_params(FPGA_VALIDATE_CHANNEL, channel) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTSPEED, linerate) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    params.dr_params.channel_no = channel;
    params.dr_params.linerate = linerate;

    if(ioctl(fd, FHGW_FPGA_DYNAMIC_RECONFIG_IP, &params) < 0) {
        printf("Error in ioctl dr configure");
        return FPGA_RET_FAILED;
    }

    return FPGA_RET_SUCCESS;
}

int8_t fpga_serdes_loopon(uint8_t channelno) 
{
    ioctl_arg_t params;

    if(fpga_validate_input_params(FPGA_VALIDATE_CHANNEL, channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    params.dr_params.channel_no = channelno;

    if(ioctl(fd, FHGW_FPGA_SERDES_LOOPON, &params) < 0) {
        printf("Error in ioctl serdes loop on");
        return FPGA_RET_FAILED;
    }

    return FPGA_RET_SUCCESS;
}

int8_t fpga_general_calibration(uint8_t channel, uint8_t value)
{
    ioctl_arg_t params;

    if(fpga_validate_input_params(FPGA_VALIDATE_CHANNEL, channel) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    params.dr_params.channel_no = channel;
    params.dr_params.linerate = value;

    if(ioctl(fd, FHGW_FPGA_GENERAL_CALIBRATION, &params) < 0) {
        printf("Error in ioctl general calibration");
        return FPGA_RET_FAILED;
    }

    return FPGA_RET_SUCCESS;
}

int8_t fpga_dr_init()
{
    ioctl_arg_t params;

    if(ioctl(fd, FHGW_FPGA_DR_INIT, &params) < 0) {
        printf("Error in ioctl dr init");
        return FPGA_RET_FAILED;
    }

    return FPGA_RET_SUCCESS;
}

int8_t fpga_enable_ILB_without_calibration(uint8_t channelno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_CHANNEL, channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0x8);

    if(fpga_serdes_loopon(channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0xE);
}

int8_t fpga_enable_ILB_with_calibration(uint8_t channelno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_CHANNEL, channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0x8);

    if(fpga_serdes_loopon(channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    if (FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0xC) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    if (fpga_general_calibration(channelno, 1) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0xE);
}

int8_t fpga_enable_ELB_with_calibration(uint8_t channelno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_CHANNEL, channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0x8);

    if (FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0xC) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    if (fpga_general_calibration(channelno, 0) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0xE);
}

int8_t set_fheth_tx_mac_address(uint8_t portno, void *addr)
{
    uint64_t value = 0;

    if (!addr)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    value = *(uint64_t *)addr;

    if (FHGW_FPGA_REG_WRITE(FPGA_ETH_REGISTER_BLOCK, portno, FPGA_MAC_SRC_ADDR_HBYTES, value >> 32) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_ETH_REGISTER_BLOCK, portno, FPGA_MAC_SRC_ADDR_LBYTES, (value & 0xFFFFFFFF));
}

int8_t fheth_get_port_speed(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FPGA_RET_SUCCESS;
}

int8_t fheth_set_port_speed(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FPGA_RET_SUCCESS;
}

int8_t fheth_get_tx_stats(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FPGA_RET_SUCCESS;
}

int8_t fheth_get_rx_stats(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FPGA_RET_SUCCESS;
}

int8_t fpga_clear_tx_counter(uint8_t portno, int8_t cntr_cfg)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return (FHGW_FPGA_REG_WRITE(FPGA_ETH_REGISTER_BLOCK, portno, TX_CFG_STATS_ADDRESS, cntr_cfg));
}

int8_t fpga_clear_rx_counter(uint8_t portno, int8_t cntr_cfg)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return (FHGW_FPGA_REG_WRITE(FPGA_ETH_REGISTER_BLOCK, portno, RX_CFG_STATS_ADDRESS, cntr_cfg));
}

int8_t get_cpri_port_mode(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return (FHGW_FPGA_REG_READ(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_port_mode[portno]) & FPGA_DATAPATH_MODE_SEL);
}

int8_t set_cpri_port_mode(uint8_t portno, uint8_t port_mode)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTSPEED, port_mode) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return (FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_port_mode[portno], port_mode) & (0x1 << 3));
}

int8_t set_loopback_mode(uint8_t portno, int8_t loopback_mode)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return (FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_port_loopback[portno], loopback_mode));
}

int8_t get_roe_srcaddress(uint8_t portno, void *addr)
{
    uint64_t src_addr = 0;

    if (!addr)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    src_addr = *(uint64_t *)addr;

    src_addr = (uint64_t)FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SOURCE_ADDRESS_MSB) << 32;
    src_addr |= (uint64_t)FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SOURCE_ADDRESS_LSB);

    return FPGA_RET_SUCCESS;
}

int8_t set_roe_srcaddress(uint8_t portno, void *addr)
{
    uint64_t src_addr = 0;

    if (!addr)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    src_addr = *(int64_t *)addr;

    if (FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SOURCE_ADDRESS_MSB, src_addr >> 32) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SOURCE_ADDRESS_LSB, (src_addr & 0xFFFFFFFF));
}

int8_t get_roe_dstaddress(uint8_t portno, void *addr)
{
    uint64_t dst_addr = 0;

    if (!addr)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    dst_addr = *(uint64_t *)addr;

    dst_addr = (uint64_t)FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DESTINATION_ADDRESS_MSB) << 32;
    dst_addr |= (uint64_t)FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DESTINATION_ADDRESS_LSB);
    
    return FPGA_RET_SUCCESS;
}

int8_t set_roe_dstaddress(uint8_t portno, void *addr)
{
    uint64_t dst_addr = 0;

    if (!addr)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    dst_addr = *(uint64_t *)addr;

    if (FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DESTINATION_ADDRESS_MSB, dst_addr >> 32) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DESTINATION_ADDRESS_LSB, dst_addr & 0xFFFFFFFF);
}

int8_t get_roe_flowId(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_FLOW_ID);
}

int8_t set_roe_flowid(uint8_t portno, int8_t flowid)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_FLOW_ID, flowid);
}

int8_t fpga_get_roe_use_seq(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_USE_SEQUENCE);
}

int8_t fpga_set_roe_use_seq(uint8_t portno, uint8_t use_seq)
{ 
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_USE_SEQUENCE, use_seq);
}

int8_t fpga_get_roe_packet_len(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_PACKET_LENGTH);
}

int8_t fpga_set_roe_packet_len(uint8_t portno, uint16_t packetlen)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_PACKET_LENGTH, packetlen);
}

int8_t fpga_get_roe_acccept_time_window(uint8_t portno)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_ACCEPT_TIME_WINDOW);
}

int8_t fpga_set_roe_accept_time_window(uint8_t portno, uint32_t time_window)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_ACCEPT_TIME_WINDOW, time_window);
}

int8_t get_roe_stats_count(uint8_t portno, struct roe_stats_cnt *stats_cnt)
{
    if (!stats_cnt)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    stats_cnt->roe_out_of_window_cnt = FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_OUT_OF_WINDOW_CNT);
    stats_cnt->roe_seqnum_err_cnt = FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SEQNUM_ERR_CNT);
    stats_cnt->roe_drop_of_pckts_cnt = FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DROP_OF_PCKTS_CNT);
    stats_cnt->roe_inject_pckts_cnt = FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_INJECT_PCKTS_CNT);
    
    return FPGA_RET_SUCCESS;
}

int8_t get_roe_agnostic_mode(uint8_t portno, struct roe_agn_mode *agm)
{
    uint32_t value;

    if (!agm)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    value = FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_AGNOSTIC_MODE_CONFIGURATION);

    agm->en_agn_mode = value & 0x1; 
    agm->en_str_agn_mode_tunl = value & 0x2;
    
    return FPGA_RET_SUCCESS;
}

int8_t set_roe_agnostic_mode(uint8_t portno, struct roe_agn_mode *agm)
{
    uint32_t value;

    if (!agm)
        return FPGA_RET_FAILED;

    if(fpga_validate_input_params(FPGA_VALIDATE_PORTNUM, portno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    value = agm->en_agn_mode & 0x1; 
    value |= agm->en_str_agn_mode_tunl & 0x2;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_AGNOSTIC_MODE_CONFIGURATION, value);
}

int8_t fhgw_led_ctrl(uint8_t ledno, uint8_t led_ctrl)
{
    if(fpga_validate_input_params(FPGA_VALIDATE_LED, ledno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    if (ledno < LED_USR0) {
        return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, FPGA_LED_CONTROL_CPRI, led_ctrl << (ledno * 0x2));
    } else {
        ledno -= LED_USR0; 
        return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, FPGA_LED_CONTROL_USER, led_ctrl << (ledno * 0x2));
    }
}

int8_t fpga_mm_dump(uint8_t channelno, struct fpga_address *dr_mm_table)
{	
    ioctl_arg_t params;

    params.dr_params.channel_no = channelno;

    if(ioctl(fd, FHGW_FPGA_MM_DUMP, &params) < 0) {
        printf("Error in ioctl set\n");
        return FPGA_RET_FAILED;
    }
    memcpy(dr_mm_table, &params.dr_mm_table, sizeof(struct fpga_address));
    return FPGA_RET_SUCCESS;
}