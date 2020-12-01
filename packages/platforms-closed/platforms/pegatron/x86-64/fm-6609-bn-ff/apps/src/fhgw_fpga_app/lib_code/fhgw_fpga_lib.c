#include <fhgw_fpga_ioctl.h>
#include <fhgw_fpga_lib.h>

int32_t fd;

#define FHGW_FPGA_DEV_NAME "/dev/fhgw_fpga_dev"

const uint32_t *fhgw_fpga_dpctrl[] = {
    FPGA_DATAPATH_CTRL_CH0,
    FPGA_DATAPATH_CTRL_CH1,
    FPGA_DATAPATH_CTRL_CH2,
    FPGA_DATAPATH_CTRL_CH3,
    FPGA_DATAPATH_CTRL_CH4,
    FPGA_DATAPATH_CTRL_CH5
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

int32_t fpga_reg_read(int32_t block, int32_t offset)
{
	ioctl_arg_t params;

    memset(&params, 0, sizeof(ioctl_arg_t));

	params.regaddr = block + offset;
	params.value = 0;

	if(ioctl(fd, FHGW_FPGA_READ_VALUE, &params) < 0) {
		printf("Error in ioctl get");
        return FPGA_RET_FAILED;
	}

    printf("\n LIB DBG : Read Reg Addr : 0x%x value : %d", params.regaddr, params.value);

	return params.value;
}

int8_t fpga_reg_write(int32_t block, int32_t offset, int32_t value)
{	
	ioctl_arg_t params;

    memset(&params, 0, sizeof(ioctl_arg_t));

	params.regaddr = block + offset;
	params.value = value;

	if(ioctl(fd, FHGW_FPGA_WRITE_VALUE, &params) < 0) {
		printf("Error in ioctl set");
        return FPGA_RET_FAILED;
	}

    printf("\n LIB DBG : Write Reg Addr : 0x%x value : %d", params.regaddr, params.value);

    return FPGA_RET_SUCCESS;
}

int32_t get_fpga_rev_ver()
{
	 return FHGW_FPGA_REG_READ(FPGA_SYSTEM_REGISTER_BASE, FPGA_REVISION);
}

int32_t rd_scratch_pad_reg()
{
	 return FHGW_FPGA_REG_READ(FPGA_SYSTEM_REGISTER_BASE, FPGA_SCRATCH_PAD);
}

int32_t wr_scratch_pad_reg(int32_t scr_val)
{
	return FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BASE, FPGA_SCRATCH_PAD, scr_val);
}

int8_t fpga_dr_linerate_configure(int8_t channel, int8_t linerate)
{	
	ioctl_arg_t params;
    fpga_dr_params *dr_params;
   
    dr_params = (fpga_dr_params *)malloc(sizeof(fpga_dr_params));
    if (dr_params == NULL)
        return FPGA_RET_FAILED;

    memset(&params, 0, sizeof(ioctl_arg_t));

	dr_params->channel_no = channel;
	dr_params->linerate = linerate;

    params.data = dr_params;

	if(ioctl(fd, FHGW_FPGA_DYNAMIC_RECONFIG_IP, &params) < 0) {
		printf("Error in ioctl dr configure");
        free(dr_params);
        return FPGA_RET_FAILED;
	}

    free(dr_params);
    return FPGA_RET_SUCCESS;
}

int8_t fpga_serdes_loopon(uint8_t channelno) 
{
    ioctl_arg_t params;
    fpga_dr_params *dr_params;

    dr_params = (fpga_dr_params *)malloc(sizeof(fpga_dr_params));
    if (dr_params == NULL)
        return FPGA_RET_FAILED;

    memset(&params, 0, sizeof(ioctl_arg_t));
    dr_params->channel_no = channelno;

    params.data = dr_params;

    if(ioctl(fd, FHGW_FPGA_SERDES_LOOPON, &params) < 0) {
        printf("Error in ioctl serdes loop on");
        free(dr_params);
        return FPGA_RET_FAILED;
    }

    free(dr_params);
    return FPGA_RET_SUCCESS;
}

int8_t fpga_general_calibration(uint8_t channel, uint8_t value)
{
    ioctl_arg_t params;
    fpga_dr_params *dr_params;

    dr_params = (fpga_dr_params *)malloc(sizeof(fpga_dr_params));
    if (dr_params == NULL)
        return FPGA_RET_FAILED;

    memset(&params, 0, sizeof(ioctl_arg_t));
    dr_params->channel_no = channel;
    dr_params->linerate = value;

    params.data = dr_params;

    if(ioctl(fd, FHGW_FPGA_GENERAL_CALIBRATION, &params) < 0) {
        printf("Error in ioctl general calibration");
        free(dr_params);
        return FPGA_RET_FAILED;
    }

    free(dr_params);
    return FPGA_RET_SUCCESS;
}

int8_t fpga_enable_ILB_without_calibration(uint8_t channelno)
{
    if(fpga_serdes_loopon(channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BASE, fhgw_fpga_dpctrl[channelno], 0xE);

    return FPGA_RET_SUCCESS;
}

int8_t fpga_enable_ILB_with_calibration(uint8_t channelno)
{
    if(fpga_serdes_loopon(channelno) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BASE, fhgw_fpga_dpctrl[channelno], 0xC);

    if (fpga_general_calibration(channelno, 1) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BASE, fhgw_fpga_dpctrl[channelno], 0xE);

    return FPGA_RET_SUCCESS;
}

int8_t fpga_enable_ELB_with_calibration(uint8_t channelno)
{
    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BASE, fhgw_fpga_dpctrl[channelno], 0xC);

    if (fpga_general_calibration(channelno, 0) != FPGA_RET_SUCCESS)
        return FPGA_RET_FAILED;

    FHGW_FPGA_REG_WRITE(FPGA_SYSTEM_REGISTER_BASE, fhgw_fpga_dpctrl[channelno], 0xE);
    
    return FPGA_RET_SUCCESS;
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

}

int8_t set_cpri_port_mode(int32_t  portno, int32_t port_mode)
{

}

int8_t set_loopback_mode(int32_t  portno, int32_t loopback_mode)
{

}

void *get_roe_srcaddress(int32_t portno)
{

}

int8_t set_roe_srcaddress(int32_t portno, void *addr)
{

}

char *get_roe_dstaddress(int32_t portno, void *addr)
{

}

int8_t set_roe_dstaddress(int32_t portno, void *addr)
{

}

int8_t get_roe_flowId(int32_t portno)
{

}

int8_t set_roe_flowid(int32_t portno, int32_t flowid)
{

}

struct roe_agn_mode *get_roe_agnostic_mode(int32_t portno)
{

}

int32_t set_roe_agnostic_mode(int32_t portno, struct roe_agn_mode *agm)
{

}

int32_t fhgw_led_ctrl(int32_t ledno, int32_t led_ctrl)
{

}
