#include <stdio.h>
#include <fhgw_fpga_lib.h>

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
		printf("\n 7. Close");
		printf("\n 8. Exit");

		printf("\n Enter the Option : ");
		scanf("%d", &Opt);

		if (Opt == 8)
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
