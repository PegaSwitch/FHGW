#ifndef FHGW_FPGA_IOCTL_H
#define FHGW_FPGA_IOCTL_H

#include <linux/ioctl.h>

typedef struct
{
    int8_t linerate;
    int8_t channel_no;
} fpga_dr_params;

typedef struct
{
    int32_t regaddr;
    int32_t offset;
    int32_t value;
    fpga_dr_params dr_params;
} ioctl_arg_t;
 
#define FHGW_FPGA_READ_VALUE _IOR('z', 1, ioctl_arg_t *)
#define FHGW_FPGA_WRITE_VALUE _IOW('z', 2, ioctl_arg_t *)
#define FHGW_FPGA_SERDES_LOOPON _IOW('z', 3, ioctl_arg_t *)
#define FHGW_FPGA_GENERAL_CALIBRATION _IOW('z', 4, ioctl_arg_t *)
#define FHGW_FPGA_DYNAMIC_RECONFIG_IP _IOW('z', 5, ioctl_arg_t *)
 
#endif /* FHGW_FPGA_IOCTL_H */
