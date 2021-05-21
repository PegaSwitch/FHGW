#include <stdio.h>
#include <fhgw_fpga_lib.h>

uint32_t fhgw_fpga_DpCtrl[] = {
    FPGA_DATAPATH_CTRL_CH0,
    FPGA_DATAPATH_CTRL_CH1,
    FPGA_DATAPATH_CTRL_CH2,
    FPGA_DATAPATH_CTRL_CH3,
    FPGA_DATAPATH_CTRL_CH4,
    FPGA_DATAPATH_CTRL_CH5
};

void fghw_fpga_event(void *);

void fghw_fpga_event(void *irq_event_in)
{
    fhgw_fpga_irq_event_info *irq_event_info = (fhgw_fpga_irq_event_info *)irq_event_in;

    if(irq_event_info == NULL) {
        printf("irq_event_info - NULL");
    } else {
        printf("EVENT : %d", irq_event_info->event_val);
    }
}

int8_t fpga_dr_config_func()
{
    uint32_t channel_no = 0, linerate;
    int32_t opt;

    printf("\n Enter the channel number (0 - 5): ");
    scanf("%d", &channel_no);

    do {
        printf("\n 1. DR Init");
        printf("\n 2. Enable Internal loop back without calibration");
        printf("\n 3. Enable Internal loop back with calibration");
        printf("\n 4. Enable External loop back with calibration");
        printf("\n 5. DR - Linerate change");
        printf("\n 6. Exit");
        printf("\nEnter the Option : ");
        scanf("%d", &opt);

        if (opt == 6)
            break;

        switch(opt) {
            case 1:
                fpga_dr_init();
                break;
            case 2:
                fpga_enable_ILB_without_calibration(channel_no);
                break;
            case 3:
                fpga_enable_ILB_with_calibration(channel_no);
                break;
            case 4:
                fpga_enable_ELB_with_calibration(channel_no);
                break;
            case 5:
                fpga_reg_write(FPGA_SYSTEM_REGISTER_BLOCK, channel_no, fhgw_fpga_DpCtrl[channel_no], 0x8);
                printf("\n Line Rate Menu");
                printf("\n 1. E25G_PTP_FEC");
                printf("\n 2. CPRI_9p8G_tunneling");
                printf("\n 3. CPRI_4p9G_tunneling");
                printf("\n 4. CPRI_2p4G_tunneling");
                printf("\n 5. CPRI_10G_TUNNEL");
                printf("\n Choose the linerate :");
                scanf("%d", &linerate);

                if (linerate > 0 && linerate <= 5) {          
                    fpga_dr_linerate_configure(channel_no, linerate);
                    fpga_reg_write(FPGA_SYSTEM_REGISTER_BLOCK, channel_no, fhgw_fpga_DpCtrl[channel_no], 0xe);
                } else 
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
    int ledno, led_ctrl, loop;
	int block = 0, channel = 0, offset = 0, value = 0, portno = 0;
    struct roe_stats_cnt *stats_cnt = NULL;
    stats_cnt = (struct roe_stats_cnt *)malloc(sizeof(struct roe_stats_cnt));
    struct roe_agn_mode *agm = NULL;
    agm = (struct roe_agn_mode *)malloc(sizeof(struct roe_agn_mode));
    char srcaddr[6] = { 0 };
    char dstaddr[6] = { 0 };
    char txmacaddr[6] = { 0 };

    ret = fpga_dev_open();
    if (ret < 0)
        printf("\n Device Open Failed");
    else
        printf("\n Device Open Success");

	do {
		printf("\n 1. Open");
		printf("\n 2. Read");
		printf("\n 3. Write");
		printf("\n 4. Read FPGA revision");
		printf("\n 5. Read Scratchpad reg");
		printf("\n 6. Write Scratchpad reg");
		printf("\n 7. Dynamic Reconfiguration menu");
		printf("\n 8. Clear Tx Counter reg");
		printf("\n 9. Clear Rx Counter reg");
		printf("\n 10. Read ROE Use Seq reg");
		printf("\n 11. Write ROE Use Seq reg");
		printf("\n 12. Read ROE packet length reg");
		printf("\n 13. Write ROE Packet length reg");
		printf("\n 14. Read ROE accept time window reg");
		printf("\n 15. Write ROE accept time window reg");
		printf("\n 16. Get ROE Stats Count reg");
		printf("\n 17. Set Led Control reg");
		printf("\n 18. Get ROE Agnostic Mode reg");
		printf("\n 19. Set ROE Agnostic Mode reg");
		printf("\n 20. Read ROE flow id reg");
		printf("\n 21. Write ROE flow id reg");
		printf("\n 22. Read CPRI Port Mode reg");
		printf("\n 23. Write CPRI Port Mode reg");
		printf("\n 24. Get ROE Source Address reg");
		printf("\n 25. Set ROE Source Address reg");
		printf("\n 26. Get ROE Destination Address reg");
		printf("\n 27. Set ROE Destination Address reg");
		printf("\n 28. Set Ethernet Tx Mac Address reg");
		printf("\n 29. Set Loopback Mode reg");
		printf("\n 30. Close");
		printf("\n 31. Exit");

		printf("\n Enter the Option : ");
		scanf("%d", &Opt);

		if (Opt == 31)
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
                printf("\n Enter the channel : ");
                scanf("%x", &channel);
                printf("\n Enter the offset : ");
                scanf("%x", &offset);

                value = fpga_reg_read(block, channel, offset);
                if (ret < 0) {
                    printf("\n Device Read Failed");
                } else {
                    printf("\n Read Success... Block :0x%x Offset : 0x%x Value : 0x%x", block, offset, value);
                }
                break;

            case 3:
                printf("\n Enter the block : ");
                scanf("%x", &block);
                printf("\n Enter the channel : ");
                scanf("%x", &channel);
                printf("\n Enter the Offset : ");
                scanf("%x", &offset);
                printf("\n Enter the Value : ");
                scanf("%d", &value);
                ret = fpga_reg_write(block, channel, offset, value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success... Block : %x Offset : 0x%x Value : 0x%x", block, offset, value);
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
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                printf("\n Enter the Value : ");
                scanf("%d", &value);
                ret = fpga_clear_tx_counter(portno,value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success.. PortNo: %d Value: %d ", portno, value);
                }
                break;
            case 9:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                printf("\n Enter the Value : ");
                scanf("%d", &value);
                ret = fpga_clear_rx_counter(portno,value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success.. PortNo: %d Value: %d ", portno, value);
                }
                break;
            case 10:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                value = fpga_get_roe_use_seq(portno);
                printf("\n ROE Use Seq value : %d ", value);
                break;

            case 11:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                printf("\n Enter the Value : ");
                scanf("%d", &value);
                ret = fpga_set_roe_use_seq(portno, value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success.. PortNo: %d Use Seq: %d ", portno, value);
                }
                break;
            case 12:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                value = fpga_get_roe_packet_len(portno);
                printf("\n ROE Packet length : %d ", value);
                break;

            case 13:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                printf("\n Enter the Value : ");
                scanf("%d", &value);
                ret = fpga_set_roe_packet_len(portno, value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success.. PortNo: %d PacketLen: %d ", portno, value);
                }
                break;
            case 14:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                value = fpga_get_roe_acccept_time_window(portno);
                printf("\n ROE accept time window : %d ", value);
                break;
            case 15:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                printf("\n Enter the Value : ");
                scanf("%d", &value);
                ret = fpga_set_roe_accept_time_window(portno, value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success.. PortNo: %d Accep time window: %d ", portno, value);
                }
                break;
            case 16:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);

                get_roe_stats_count(portno, stats_cnt);
                
                printf("\n roe_out_of_window_cnt : %d ", stats_cnt->roe_out_of_window_cnt);
                printf("\n roe_seqnum_err_cnt : %d ", stats_cnt->roe_seqnum_err_cnt);
                printf("\n roe_drop_of_pckts_cnt : %d ", stats_cnt->roe_drop_of_pckts_cnt);
                printf("\n roe_inject_pckts_cnt : %d ", stats_cnt->roe_inject_pckts_cnt);
                break;
            case 17:
                printf("\n Enter the ledno : ");
                scanf("%d", &ledno);
                printf("\n Enter the led control(OFF/BLINK/ON) : ");
                scanf("%d", &led_ctrl);
                ret = fhgw_led_ctrl(ledno, led_ctrl);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else if (ledno < LED_USR0) {
                    printf("\n CPRI Led No: %d led status: %d ", ledno, led_ctrl);
                } else
                    printf("\n USER Led No: %d led status: %d ", ledno, led_ctrl);
                break;
            case 18:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);

                get_roe_agnostic_mode(portno, agm);

                printf("\n en_agn_mode : %d ", agm->en_agn_mode);
                printf("\n en_str_agn_mode_tunl : %d ", agm->en_str_agn_mode_tunl);
                break;
            case 19:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                agm->en_agn_mode = 0x1;
                agm->en_str_agn_mode_tunl = 0x2; 
                
                ret = set_roe_agnostic_mode(portno, agm);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success.. ");
                }
                break;
            case 20:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                value = get_roe_flowId(portno);
                printf("\n ROE Flow Id : %d ", value);
                break;
            case 21:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                printf("\n Enter the flow id : ");
                scanf("%d", &value);
                ret = set_roe_flowid(portno, value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success.. PortNo: %d flow Id: %d ", portno, value);
                }
                break;
            case 22:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                value = get_cpri_port_mode(portno);
                break;
            case 23:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                printf("\n Enter the port mode : ");
                scanf("%d", &value);
                ret = set_cpri_port_mode(portno, value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success..");
                }
                break;
            case 24:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                ret = get_roe_srcaddress(portno, (void *)srcaddr);
                printf("\n ROE SRC ADDR : ");
                for (loop = 0; loop < 6; loop++)
                    printf("\n 0x%x ", *((char *)srcaddr + 1*loop));
                break;
            case 25:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                
                srcaddr[0] = 0x0C;
                srcaddr[1] = 0x01;
                srcaddr[2] = 0x00;
                srcaddr[3] = 0x00;
                srcaddr[4] = 0x10;
                srcaddr[5] = 0x01;

                value = set_roe_srcaddress(portno, (void *)srcaddr);
                break;
            case 26:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                ret = get_roe_dstaddress(portno, (void *)dstaddr);

                printf("\n ROE DST ADDR : ");
                for (loop = 0; loop < 6; loop++) 
                    printf("\n 0x%x ", *((char *)dstaddr + 1*loop));
                break;
            case 27:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                dstaddr[0] = 0x14;
                dstaddr[1] = 0x01;
                dstaddr[2] = 0x00;
                dstaddr[3] = 0x00;
                dstaddr[4] = 0x18;
                dstaddr[5] = 0x01;

                value = set_roe_dstaddress(portno,(void *)dstaddr);
                break;

            case 28:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                txmacaddr[0] = 0x30;
                txmacaddr[1] = 0x10;
                txmacaddr[2] = 0x00;
                txmacaddr[3] = 0x00;
                txmacaddr[4] = 0x34;
                txmacaddr[5] = 0x10;

                value = set_fheth_tx_mac_address(portno, (void *)txmacaddr);
                
                break;
            case 29:
                printf("\n Enter the portno : ");
                scanf("%d", &portno);
                printf("\n Enter the loopback mode(no_loopback/loopback_portside/loopback_switchside/roe_loopback) : ");
                scanf("%d", &value);
                ret = set_loopback_mode(portno, value);
                if (ret < 0) {
                    printf("\n Device Write Failed");
                } else {
                    printf("\nWrite Success.. PortNo: %d Loopback Mode: %d ", portno, value);
                }
                break;

            case 30:
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
