#include <stdio.h>
#include <fhgw_fpga_lib.h>

int8_t fpga_dr_config_func()
{
    uint32_t channel_no = 0, linerate;
    int32_t opt;

    printf("\n Enter the channel number (0 - 5): ");
    scanf("%d", &channel_no);

    do {
        printf("\n 1. Enable Internal loop back without calibration");
        printf("\n 2. Enable Internal loop back with calibration");
        printf("\n 3. Enable External loop back with calibration");
        printf("\n 4. DR - Linerate change");
        printf("\n 5. Exit");
        printf("\nEnter the Option : ");
        scanf("%d", &opt);

        if (opt == 5)
            break;

        switch(opt) {
            case 1:
                fpga_enable_ILB_without_calibration(channel_no);
                break;
            case 2:
                fpga_enable_ILB_with_calibration(channel_no);
                break;
            case 3:
                fpga_enable_ELB_with_calibration(channel_no);
                break;
            case 4:
                printf("\n Line Rate Menu");
                printf("\n 1. CPRI_10G_TUNNEL");
                printf("\n 2. CPRI_2p4G_tunneling");
                printf("\n 3. CPRI_4p9G_tunneling");
                printf("\n 4. CPRI_9p8G_tunneling");
                printf("\n Choose the linerate :");
                scanf("%d", &linerate);

                if (linerate > 0 && linerate < 5)           
                    fpga_dr_linerate_configure(channel_no, linerate);
                else 
                    printf("\n Invalid linerate selection");

                printf("\n");
                break;
            default:
                break;
        };
        printf("\n");
    } while(1);

    return 0;
}

int main()
{
	int Opt = 0;
	int ret = 0;
	int block = 0, offset = 0, value = 0;

	do {
		printf("\n 1. Open");
		printf("\n 2. Read");
		printf("\n 3. Write");
		printf("\n 4. Read FPGA revision");
		printf("\n 5. Read Scratchpad reg");
		printf("\n 6. write Scratchpad reg");
		printf("\n 7. Dynamic onfiguration menu");
		printf("\n 8. Close");
		printf("\n 9. Exit");

		printf("\n Enter the Option : ");
		scanf("%d", &Opt);

		if (Opt == 9)
				break;

        switch(Opt) {
            case 1:
                ret = fpga_dev_open();
                if (ret < 0)
                    printf("\n Device Open Failed");
                else
                    printf("\n Device Open Success");
                break;

            case 2:
                printf("\n Enter the block : ");
                scanf("%x", &block);
                printf("\n Enter the offset : ");
                scanf("%x", &offset);

                value = fpga_reg_read(block, offset);
                if (ret < 0) {
                    printf("\n Device Read Failed");
                } else {
                    printf("\n Read Success Block :0x%x Offset : 0x%x Value : 0x%x", block, offset, value);
                }
                break;

            case 3:
                printf("\n Enter the block : ");
                scanf("%x", &block);
                printf("\n Enter the Offset : ");
                scanf("%x", &offset);
                printf("\n Enter the Value : ");
                scanf("%d", &value);
                ret = fpga_reg_write(block, offset, value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success block : %x Offset : 0x%x Value : 0x%x", block, offset, value);
                }
                break;

            case 4:
                value = get_fpga_rev_ver();
                printf("\n FPGA rev Version : 0x%x ", value);
                break;

            case 5: 
                value = rd_scratch_pad_reg();
                printf("\n Scratch pad value : 0x%x ", value);
                break;

            case 6:
                printf("\n Enter the Value : ");
                scanf("%d", &value);
                ret = wr_scratch_pad_reg(value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success ");
                }
                break;

            case 7:
                fpga_dr_config_func();
                break;
            case 8:
                fpga_dev_close();
                break;
            default:
                printf("\n Invalid Option !!!");
        }
		printf("\n");
	} while(1);

	printf("\n Application Exited Successfully !!!\n\n");

	return 0;
}
