#include <fhgw_fpga_ioctl.h>
#include <fhgw_fpga_lib.h>

int32_t fd;

#define FHGW_FPGA_DEV_NAME "/dev/fhgw_fpga_dev"

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

	params.regaddr = block + offset;
	params.value = 0;

	if(ioctl(fd, FHGW_FPGA_READ_VALUE, &params) < 0) {
		printf("Error in ioctl get");
        return FPGA_RET_FAILED;
	}

	return params.value;
}

int32_t fpga_reg_write(int32_t block, int32_t offset, int32_t value)
{	
	ioctl_arg_t params;

	params.regaddr = block + offset;
	params.value = value;

	if(ioctl(fd, FHGW_FPGA_WRITE_VALUE, &params) < 0) {
		printf("Error in ioctl set");
        return FPGA_RET_FAILED;
	}

    return FPGA_RET_SUCCESS;
}

int32_t get_fpga_rev_ver()
{
	 return fpga_reg_read(FPGA_SYSTEM_REGISTER_BASE, FPGA_REVISION);
}

int32_t rd_scratch_pad_reg()
{
	 return fpga_reg_read(FPGA_SYSTEM_REGISTER_BASE, FPGA_SCRATCH_PAD);
}

int32_t wr_scratch_pad_reg(int32_t scr_val)
{
	return fpga_reg_write(FPGA_SYSTEM_REGISTER_BASE, FPGA_SCRATCH_PAD, scr_val);
}

#if 0
void set_fheth_tx_mac_address(int32_t portno, void * addr)
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

int32_t get_cpri_port_mode(int32_t  portno)
{

    return FPGA_RET_SUCCESS;
}

int32_t set_cpri_port_mode(int32_t  portno, int32_t port_mode)
{

    return FPGA_RET_SUCCESS;
}

int32_t set_loopback_mode(int32_t  portno, int32_t loopback_mode)
{

    return FPGA_RET_SUCCESS;
}

void *get_roe_srcaddress(int32_t portno)
{

}

int32_t set_roe_srcaddress(int32_t portno, void *addr)
{

    return FPGA_RET_SUCCESS;
}

char *get_roe_dstaddress(int32_t portno, void *addr)
{

    return FPGA_RET_SUCCESS;
}

int32_t set_roe_dstaddress(int32_t portno, void *addr)
{

    return FPGA_RET_SUCCESS;
}

int32_t get_roe_flowId(int32_t portno)
{

    return FPGA_RET_SUCCESS;
}

int32_t set_roe_flowid(int32_t portno, int32_t flowid)
{

    return FPGA_RET_SUCCESS;
}

struct roe_agn_mode *get_roe_agnostic_mode(int32_t portno)
{

}

int32_t set_roe_agnostic_mode(int32_t portno, struct roe_agn_mode *agm)
{

    return FPGA_RET_SUCCESS;
}

int32_t fhgw_led_ctrl(int32_t ledno, int32_t led_ctrl)
{

    return FPGA_RET_SUCCESS;
}

int32_t fhgw_intr_status_reg()
{

    return FPGA_RET_SUCCESS;
}
#endif
