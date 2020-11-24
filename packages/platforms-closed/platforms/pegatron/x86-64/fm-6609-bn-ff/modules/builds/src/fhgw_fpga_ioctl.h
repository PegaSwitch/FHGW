#ifndef FHGW_FPGA_IOCTL_H
#define FHGW_FPGA_IOCTL_H

#include <linux/ioctl.h>
 
typedef struct
{
    int32_t regaddr;
    int32_t value;
} ioctl_arg_t;
 
#define FHGW_FPGA_READ_VALUE _IOR('z', 1, ioctl_arg_t *)
#define FHGW_FPGA_WRITE_VALUE _IOW('z', 2, ioctl_arg_t *)
 
#endif /* FHGW_FPGA_IOCTL_H */
