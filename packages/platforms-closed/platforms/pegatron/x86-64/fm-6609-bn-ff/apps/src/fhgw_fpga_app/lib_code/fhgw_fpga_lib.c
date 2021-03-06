#include <fhgw_fpga_ioctl.h>
#include <fhgw_fpga_lib.h>

int32_t fd;

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

int32_t fpga_reg_read(uint32_t block, uint8_t channelno, uint32_t offset)
{
	ioctl_arg_t params;

    memset(&params, 0, sizeof(ioctl_arg_t));

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

int8_t fpga_reg_write(uint32_t block, uint8_t channelno, uint32_t offset, uint32_t value)
{	
	ioctl_arg_t params;

    memset(&params, 0, sizeof(ioctl_arg_t));

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
    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0x8);

    if(fpga_serdes_loopon(channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0xE);
}

int8_t fpga_enable_ILB_with_calibration(uint8_t channelno)
{
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
    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0x8);
    
    if (FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0xC) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    if (fpga_general_calibration(channelno, 0) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_dpctrl[channelno], 0xE);
}

void set_fheth_tx_mac_address(int32_t portno, void *addr)
{

}

void *fheth_get_port_speed(int32_t portno)
{

}

void *fheth_set_port_speed(int32_t portno)
{

}

void *fheth_get_tx_stats(int32_t portno)
{

}

void *fheth_get_rx_stats(int32_t portno)
{

}

int8_t get_cpri_port_mode(int32_t  portno)
{
    return (FHGW_FPGA_REG_READ(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_port_mode[portno]) & FPGA_DATAPATH_MODE_SEL);
}

int8_t set_cpri_port_mode(int32_t  portno, int32_t port_mode)
{
    return (FHGW_FPGA_REG_READ(FPGA_SYSTEM_REGISTER_BLOCK, 0, fhgw_fpga_port_mode[portno]) & (0x1 << 3));
}

int8_t set_loopback_mode(int32_t  portno, int32_t loopback_mode)
{
}

void *get_roe_srcaddress(int32_t portno)
{
    uint64_t src_addr = 0;

    src_addr = (uint64_t)FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SOURCE_ADDRESS_MSB) << 32;
    src_addr |= (uint64_t)FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SOURCE_ADDRESS_LSB);

    return (void *)&src_addr;
}

int8_t set_roe_srcaddress(int32_t portno, void *addr)
{
    uint64_t value = *(int*)addr;

    if (FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SOURCE_ADDRESS_MSB, value >> 32) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_SOURCE_ADDRESS_LSB, (value & 0xFFFFFFFF));
}

char *get_roe_dstaddress(int32_t portno, void *addr)
{
    uint64_t dst_addr = 0;

    dst_addr = (uint64_t)FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DESTINATION_ADDRESS_MSB) << 32;
    dst_addr |= (uint64_t)FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DESTINATION_ADDRESS_LSB);

    return (void *)&dst_addr;
}

int8_t set_roe_dstaddress(int32_t portno, void *addr)
{
    uint64_t value = *(int*)addr;

    if (FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DESTINATION_ADDRESS_MSB, value >> 32) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;
    
    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_DESTINATION_ADDRESS_LSB, value & 0xFFFFFFFF);
}

int8_t get_roe_flowId(int32_t portno)
{
    return FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_FLOW_ID);
}

int8_t set_roe_flowid(int32_t portno, int32_t flowid)
{
    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_FLOW_ID, flowid);
}

struct roe_agn_mode *get_roe_agnostic_mode(int32_t portno)
{
    uint32_t value;
    struct roe_agn_mode agm;

    value = FHGW_FPGA_REG_READ(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_AGNOSTIC_MODE_CONFIGURATION);

    agm.en_agn_mode = value & 0x1; 
    agm.en_str_agn_mode_tunl = value & 0x2;
    
   return &agm;
}

int32_t set_roe_agnostic_mode(int32_t portno, struct roe_agn_mode *agm)
{
    uint32_t value;

    value = agm->en_agn_mode & 0x1; 
    value |= agm->en_str_agn_mode_tunl & 0x2;

    return FHGW_FPGA_REG_WRITE(FPGA_ROE_REGISTER_BLOCK, portno, FPGA_ROE_AGNOSTIC_MODE_CONFIGURATION, value);
}

int8_t fhgw_led_ctrl(int32_t ledno, int32_t led_ctrl)
{
    if (ledno < LED_USR0) {
        return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, FPGA_LED_CONTROL_CPRI, led_ctrl << (ledno * 0x2));
    } else {
        ledno -= LED_USR0; 
        return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BLOCK, 0, FPGA_LED_CONTROL_USER, led_ctrl << (ledno * 0x2));
    }
}
