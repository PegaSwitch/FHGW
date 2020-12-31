#!/bin/bash
## create by Jenny, for Porsche2 (Nephos)

MFG_WORK_DIR="/home/root/mfg"
OUTPUT_FOLDER="$MFG_WORK_DIR/sdk_configuration"

END_INIT_FLAG="init-done=true"
RELOAD_SPEED_FLAG=0

SFP_PORT_START=0
SFP_PORT_END=47
SFP_ETH_MACRO=( 2 3 4 5 8 10 12 14 16 17 18 19 )    ## layout defined, do not modify !
QSFP_PORT_START=48
QSFP_ETH_MACRO=( 20 21 26 27 28 29 )                ## layout defined, do not modify !
CPI_PORT_NUM=2
CPI_PORT=( 129 130 )

## CPI line setting
CPI_SWAP_DATA=( 0x00 0x01 )
CPI_POLARITY_DATA=( 0x00 0x00 )
CPI_PREEMPHASIS_PROPERTY=( c2 cn1 c1 c0 )
CPI_PREEMPHASIS_DATA=( { 0x01 0x01 0x03 0x02 } { 0x01 0x01 0x03 0x02 } )
## SFP line setting
{
SFP_TX_SWAP_DATA=( 0x00 0x01 0x02 0x03
                  0x02 0x03 0x00 0x01
                  0x00 0x01 0x02 0x03
                  0x00 0x03 0x02 0x01
                  0x03 0x02 0x01 0x00
                  0x02 0x03 0x00 0x01
                  0x02 0x03 0x00 0x01
                  0x02 0x03 0x00 0x01
                  0x00 0x01 0x02 0x03
                  0x00 0x01 0x02 0x03
                  0x00 0x01 0x02 0x03
                  0x00 0x01 0x02 0x03 )
SFP_RX_SWAP_DATA=( 0x00 0x01 0x02 0x03
                  0x02 0x03 0x00 0x01
                  0x00 0x01 0x02 0x03
                  0x03 0x02 0x01 0x00
                  0x00 0x03 0x02 0x01
                  0x00 0x03 0x02 0x01
                  0x00 0x03 0x02 0x01
                  0x00 0x03 0x02 0x01
                  0x02 0x01 0x00 0x03
                  0x02 0x01 0x00 0x03
                  0x02 0x01 0x00 0x03
                  0x02 0x01 0x00 0x03 )
SFP_TX_POLARITY_DATA=( 0x01 0x01 0x01 0x01
                      0x00 0x00 0x00 0x00
                      0x00 0x01 0x00 0x01
                      0x00 0x00 0x00 0x00
                      0x00 0x00 0x01 0x01
                      0x00 0x00 0x01 0x00
                      0x00 0x00 0x01 0x00
                      0x00 0x00 0x01 0x00
                      0x00 0x01 0x01 0x01
                      0x00 0x01 0x01 0x01
                      0x00 0x01 0x01 0x01
                      0x00 0x01 0x01 0x01 )
SFP_RX_POLARITY_DATA=( 0x00 0x01 0x00 0x01
                      0x00 0x01 0x00 0x01
                      0x01 0x01 0x01 0x01
                      0x01 0x01 0x01 0x01
                      0x00 0x01 0x01 0x01
                      0x00 0x01 0x01 0x01
                      0x00 0x01 0x01 0x01
                      0x00 0x01 0x01 0x01
                      0x00 0x00 0x01 0x00
                      0x00 0x00 0x01 0x00
                      0x00 0x00 0x01 0x00
                      0x00 0x00 0x01 0x00 )

SFP_PREEMPHASIS_PROPERTY=( c0 c1 cn1 c2 )

SFP_PREEMPHASIS_DATA_CAUI4=( { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 }
                           { 0x1d 0x07 0x00 0x00 } )
SFP_PREEMPHASIS_DATA_CR4=( { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x23 0x01 0x00 0x00 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 }
                           { 0x22 0x01 0x00 0x01 } )
SFP_PREEMPHASIS_DATA_10G=( { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 }
                           { 0x17 0x02 0x01 0x01 } )
SFP_PREEMPHASIS_DATA_LOOPBACK=( { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 }
                           { 0x11 0x00 0x00 0x00 } )
}
## QSFP line setting
{
QSFP_TX_SWAP_DATA_6_PORTS=(  0x03.02.01.00
                            0x01.02.03.00
                            0x01.02.03.00
                            0x03.02.01.00
                            0x03.02.01.00
                            0x01.02.03.00 )
QSFP_TX_SWAP_DATA_12_PORTS=( 0x03.02
                            0x01.00
                            0x01.02
                            0x03.00
                            0x01.02
                            0x03.00
                            0x03.02
                            0x01.00
                            0x03.02
                            0x01.00
                            0x01.02
                            0x03.00 )
QSFP_TX_SWAP_DATA_16_PORTS=( 0x03 0x02 0x01 0x00
                            0x01 0x02 0x03 0x00
                            0x01 0x02 0x03 0x00
                            0x03 0x02 0x01 0x00 )
QSFP_RX_SWAP_DATA_6_PORTS=(  0x03.00.01.02
                            0x03.00.01.02
                            0x03.01.02.00
                            0x03.02.01.00
                            0x03.02.01.00
                            0x00.01.02.03 )
QSFP_RX_SWAP_DATA_12_PORTS=( 0x03.00
                            0x01.02
                            0x03.00
                            0x01.02
                            0x03.01
                            0x02.00
                            0x03.02
                            0x01.00
                            0x03.02
                            0x01.00
                            0x00.01
                            0x02.03 )
QSFP_RX_SWAP_DATA_16_PORTS=( 0x03 0x00 0x01 0x02
                            0x03 0x00 0x01 0x02
                            0x03 0x01 0x02 0x00
                            0x03 0x02 0x01 0x00 )

QSFP_TX_POLARITY_DATA_6_PORTS=(  0x00.01.00.00
                                0x00.00.01.00
                                0x01.00.01.01
                                0x01.01.01.01
                                0x01.00.00.00
                                0x00.00.01.00 )
QSFP_TX_POLARITY_DATA_12_PORTS=(  0x00.01 0x00.00
                                0x00.00 0x01.00
                                0x01.00 0x01.01
                                0x01.01 0x01.01
                                0x01.00 0x00.00
                                0x00.00 0x01.00 )
QSFP_TX_POLARITY_DATA_16_PORTS=(  0x00 0x01 0x00 0x00
                                0x00 0x00 0x01 0x00
                                0x01 0x00 0x01 0x01
                                0x01 0x01 0x01 0x01
                                0x01 0x00 0x00 0x00
                                0x00 0x00 0x01 0x00 )
QSFP_RX_POLARITY_DATA_6_PORTS=(  0x00.01.00.00
                                0x00.00.01.00
                                0x00.00.01.01
                                0x00.01.00.01
                                0x00.01.00.01
                                0x01.01.01.01 )
QSFP_RX_POLARITY_DATA_12_PORTS=(  0x00.01 0x00.00
                                0x00.00 0x01.00
                                0x00.00 0x01.01
                                0x00.01 0x00.01
                                0x00.01 0x00.01
                                0x01.01 0x01.01 )
QSFP_RX_POLARITY_DATA_16_PORTS=(  0x00 0x01 0x00 0x00
                                0x00 0x00 0x01 0x00
                                0x00 0x00 0x01 0x01
                                0x00 0x01 0x00 0x01
                                0x00 0x01 0x00 0x01
                                0x01 0x01 0x01 0x01 )

QSFP_PREEMPHASIS_PROPERTY=( c0 c1 cn1 c2 )

QSFP_PREEMPHASIS_DATA_CAUI4_6_PORT=( { 0x1d.1d.1d.1d 0x7.7.7.7 0x0.0.0.0 0x0.0.0.0 }
                                    { 0x1b.1d.1b.1d 0x9.7.9.7 0x0.0.0.0 0x0.0.0.0 }
                                    { 0x1d.1d.1d.1d 0x7.7.7.7 0x0.0.0.0 0x0.0.0.0 }
                                    { 0x1d.1d.1d.1d 0x7.7.7.7 0x0.0.0.0 0x0.0.0.0 }
                                    { 0x1d.1d.1d.1d 0x7.7.7.7 0x0.0.0.0 0x0.0.0.0 }
                                    { 0x1d.1d.1d.1d 0x7.7.7.7 0x0.0.0.0 0x0.0.0.0 } )
QSFP_PREEMPHASIS_DATA_CR4_6_PORT=( { 0x23.22.23.22 0x1.1.1.1 0x0.0.0.0 0x0.1.0.1 }
                                    { 0x22.23.22.23 0x1.1.1.1 0x0.0.0.0 0x1.0.1.0 }
                                    { 0x22.22.22.22 0x1.1.1.1 0x0.0.0.0 0x1.1.1.1 }
                                    { 0x22.22.22.22 0x1.1.1.1 0x0.0.0.0 0x1.1.1.1 }
                                    { 0x22.22.22.22 0x1.1.1.1 0x0.0.0.0 0x1.1.1.1 }
                                    { 0x22.23.22.22 0x1.0.1.1 0x0.0.0.0 0x1.1.1.1 } )

QSFP_PREEMPHASIS_DATA_CAUI4_12_PORT=( { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1b.1d 0x9.7 0x0.0 0x0.0 }
                                    { 0x1b.1d 0x9.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 }
                                    { 0x1d.1d 0x7.7 0x0.0 0x0.0 } )
QSFP_PREEMPHASIS_DATA_CR4_12_PORT=( { 0x23.22 0x1.1 0x0.0 0x0.1 }
                                    { 0x23.22 0x1.1 0x0.0 0x0.1 }
                                    { 0x22.23 0x1.1 0x0.0 0x1.0 }
                                    { 0x22.23 0x1.1 0x0.0 0x1.0 }
                                    { 0x22.22 0x1.1 0x0.0 0x1.1 }
                                    { 0x22.22 0x1.1 0x0.0 0x1.1 }
                                    { 0x22.22 0x1.1 0x0.0 0x1.1 }
                                    { 0x22.22 0x1.1 0x0.0 0x1.1 }
                                    { 0x22.22 0x1.1 0x0.0 0x1.1 }
                                    { 0x22.22 0x1.1 0x0.0 0x1.1 }
                                    { 0x22.23 0x1.0 0x0.0 0x1.1 }
                                    { 0x22.22 0x1.1 0x0.0 0x1.1 } )

QSFP_PREEMPHASIS_DATA_CAUI4_16_PORT=( { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 }
                                    { 0x1d 0x7 0x0 0x0 } )

QSFP_PREEMPHASIS_DATA_CR4_16_PORT=( { 0x23 0x1 0x0 0x0 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x23 0x1 0x0 0x0 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x23 0x1 0x0 0x0 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x23 0x1 0x0 0x0 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x22 0x1 0x0 0x1 }
                                    { 0x22 0x1 0x0 0x1 } )

QSFP_PREEMPHASIS_DATA_40G=( { 0x17.17.17.17 0x2.2.2.2 0x1.1.1.1 0x1.1.1.1 }
                            { 0x17.17.17.17 0x2.2.2.2 0x1.1.1.1 0x1.1.1.1 }
                            { 0x17.17.17.17 0x2.2.2.2 0x1.1.1.1 0x1.1.1.1 }
                            { 0x17.17.17.17 0x2.2.2.2 0x1.1.1.1 0x1.1.1.1 }
                            { 0x17.17.17.17 0x2.2.2.2 0x1.1.1.1 0x1.1.1.1 }
                            { 0x17.17.17.17 0x2.2.2.2 0x1.1.1.1 0x1.1.1.1 } )
QSFP_PREEMPHASIS_DATA_10G=( { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 }
                            { 0x17 0x2 0x1 0x1 } )
}

## Default value, changed by user input or caculation.
config_qsfp_speed=100
config_sfp_speed=25
config_interface="fiber" # CAUI-4
config_fec="disable"
config_an="disable"
config_vlan="off"

qsfp_port_end=53
qsfp_port_num=6
qsfp_lane_per_port=4


function Write_Init_Header ()
{
    if (( $RELOAD_SPEED_FLAG == 1 )); then
        echo "init end stage task" > $OUTPUT_FILE_INIT
        echo "init end stage module" >> $OUTPUT_FILE_INIT
        echo "init end stage task-rsrc" >> $OUTPUT_FILE_INIT
        echo "init end stage low-level" >> $OUTPUT_FILE_INIT
        echo "init start stage low-level" >> $OUTPUT_FILE_INIT
    else
        echo "init start stage low-level" > $OUTPUT_FILE_INIT
    fi
}

function Write_Init_Buttom ()
{
    echo "init start stage task-rsrc" >> $OUTPUT_FILE_INIT
    echo "init start stage module" >> $OUTPUT_FILE_INIT
    echo "init start stage task" >> $OUTPUT_FILE_INIT
}

function Write_Init_Body_SFP ()
{
    request_sfp=$1

    for (( port = $SFP_PORT_START ; port <= $SFP_PORT_END ; port += 1 ))
    do
        index=$(( $port / 4 ))
        port_lane=$(( $port % 4 ))                ## lane 0 ~ 3
        port_eth_macro=${SFP_ETH_MACRO[$index]}
        echo "init set port-map port="$port" eth-macro="$port_eth_macro" lane="$port_lane" max-speed="$request_sfp"g active=true" >> $OUTPUT_FILE_INIT
    done
}

function Write_Init_Body_QSFP ()
{
    request_qsfp=$1

    for (( port = $QSFP_PORT_START ; port <= $qsfp_port_end ; port += 1 ))
    do
        if [[ $request_qsfp == "100" ]] || [[ $request_qsfp == "40" ]]; then
            port_lane=0
            index=$(( $port % 6 ))
        elif [[ $request_qsfp == "50" ]]; then    ## lane 0/2 ;
            if (( $port % 2 != 0 )); then
                port_lane=2
            else
                port_lane=0
            fi
            index=$(( ( $port % 48 ) / 2 ))       ## macro 48~49:0 ; 50~51:1 ; 52~53:2 ; ... ; 58~59:5
        else
            port_lane=$(( $port % 4 ))            ## lane 0 ~ 3
            index=$(( ( $port / 4 ) % 12 ))       ## macro 48~51:0 ; 52~55:1 ; 56~59:2 ; 60~63:3
        fi
        port_eth_macro=${QSFP_ETH_MACRO[$index]}

        echo "init set port-map port="$port" eth-macro="$port_eth_macro" lane="$port_lane" max-speed="$request_qsfp"g active=true" >> $OUTPUT_FILE_INIT
    done
}

function Write_Init_Body_CPI ()
{
    echo "init set port-map port=129 eth-macro=0 lane=0 max-speed=10g active=true guarantee=true cpi=true" >> $OUTPUT_FILE_INIT
    echo "init set port-map port=130 eth-macro=0 lane=1 max-speed=10g active=true guarantee=true cpi=true" $END_INIT_FLAG >> $OUTPUT_FILE_INIT
}

function Write_Cfg_LaneSwap ()
{
    request_sfp=$1
    request_qsfp=$2

    ## Tx lane-swap
    for (( port = $SFP_PORT_START ; port <= $SFP_PORT_END ; port += 1 ))
    do
        echo "phy set lane-swap portlist="$port" lane-cnt=1 property=tx data=${SFP_TX_SWAP_DATA[$port]}" >> $OUTPUT_FILE_CFG
    done

    for (( port = $QSFP_PORT_START , index = 0 ; port <= $qsfp_port_end , index < $qsfp_port_num ; port += 1 , index += 1 ))
    do
        if [[ $request_qsfp == "100" ]] || [[ $request_qsfp == "40" ]]; then
            assign_array=("${QSFP_TX_SWAP_DATA_6_PORTS[@]}")
        elif [[ $request_qsfp == "50" ]]; then
            assign_array=("${QSFP_TX_SWAP_DATA_12_PORTS[@]}")
        else
            assign_array=("${QSFP_TX_SWAP_DATA_16_PORTS[@]}")
        fi

        echo "phy set lane-swap portlist="$port" lane-cnt="$qsfp_lane_per_port" property=tx data=${assign_array[$index]}" >> $OUTPUT_FILE_CFG
    done

    for (( port = 0 ; port < $CPI_PORT_NUM ; port += 1 ))
    do
        echo "phy set lane-swap portlist="${CPI_PORT[$port]}" lane-cnt=1 property=tx data=${CPI_SWAP_DATA[$port]}" >> $OUTPUT_FILE_CFG
    done

    echo "" >> $OUTPUT_FILE_CFG

    ## Rx lane-swap
    for (( port = $SFP_PORT_START ; port <= $SFP_PORT_END ; port += 1 ))
    do
        echo "phy set lane-swap portlist="$port" lane-cnt=1 property=rx data=${SFP_RX_SWAP_DATA[$port]}" >> $OUTPUT_FILE_CFG
    done

    for (( port = $QSFP_PORT_START , index = 0 ; port <= $qsfp_port_end , index < $qsfp_port_num ; port += 1 , index += 1 ))
    do
        if [[ $request_qsfp == "100" ]] || [[ $request_qsfp == "40" ]]; then
            assign_array=("${QSFP_RX_SWAP_DATA_6_PORTS[@]}")
        elif [[ $request_qsfp == "50" ]]; then
            assign_array=("${QSFP_RX_SWAP_DATA_12_PORTS[@]}")
        else
            assign_array=("${QSFP_RX_SWAP_DATA_16_PORTS[@]}")
        fi

        echo "phy set lane-swap portlist="$port" lane-cnt="$qsfp_lane_per_port" property=rx data=${assign_array[$index]}" >> $OUTPUT_FILE_CFG
    done

    for (( port = 0 ; port < $CPI_PORT_NUM ; port += 1 ))
    do
        echo "phy set lane-swap portlist="${CPI_PORT[$port]}" lane-cnt=1 property=rx data=${CPI_SWAP_DATA[$port]}" >> $OUTPUT_FILE_CFG
    done

    echo "" >> $OUTPUT_FILE_CFG
}

function Write_Cfg_Polarity ()
{
    request_sfp=$1
    request_qsfp=$2

    ## Tx polarity
    for (( port = $SFP_PORT_START ; port <= $SFP_PORT_END ; port += 1 ))
    do
        echo "phy set polarity-rev portlist="$port" lane-cnt=1 property=tx data=${SFP_TX_POLARITY_DATA[$port]}" >> $OUTPUT_FILE_CFG
    done

    for (( port = $QSFP_PORT_START , index = 0 ; port <= $qsfp_port_end , index < $qsfp_port_num ; port += 1 , index += 1 ))
    do
        if [[ $request_qsfp == "100" ]] || [[ $request_qsfp == "40" ]]; then
            assign_array=("${QSFP_TX_POLARITY_DATA_6_PORTS[@]}")
        elif [[ $request_qsfp == "50" ]]; then
            assign_array=("${QSFP_TX_POLARITY_DATA_12_PORTS[@]}")
        else
            assign_array=("${QSFP_TX_POLARITY_DATA_16_PORTS[@]}")
        fi

        echo "phy set polarity-rev portlist="$port" lane-cnt="$qsfp_lane_per_port" property=tx data=${assign_array[$index]}" >> $OUTPUT_FILE_CFG
    done

    for (( port = 0 ; port < $CPI_PORT_NUM ; port += 1 ))
    do
        echo "phy set polarity-rev portlist="${CPI_PORT[$port]}" lane-cnt=1 property=tx data=${CPI_POLARITY_DATA[$port]}" >> $OUTPUT_FILE_CFG
    done

    echo "" >> $OUTPUT_FILE_CFG

    ## Rx polarity
    for (( port = $SFP_PORT_START ; port <= $SFP_PORT_END ; port += 1 ))
    do
        echo "phy set polarity-rev portlist="$port" lane-cnt=1 property=rx data=${SFP_RX_POLARITY_DATA[$port]}" >> $OUTPUT_FILE_CFG
    done

    for (( port = $QSFP_PORT_START , index = 0 ; port <= $qsfp_port_end , index < $qsfp_port_num ; port += 1 , index += 1 ))
    do
        if [[ $request_qsfp == "100" ]] || [[ $request_qsfp == "40" ]]; then
            assign_array=("${QSFP_RX_POLARITY_DATA_6_PORTS[@]}")
        elif [[ $request_qsfp == "50" ]]; then
            assign_array=("${QSFP_RX_POLARITY_DATA_12_PORTS[@]}")
        else
            assign_array=("${QSFP_RX_POLARITY_DATA_16_PORTS[@]}")
        fi

        echo "phy set polarity-rev portlist="$port" lane-cnt="$qsfp_lane_per_port" property=rx data=${assign_array[$index]}" >> $OUTPUT_FILE_CFG
    done

    for (( port = 0 ; port < $CPI_PORT_NUM ; port += 1 ))
    do
        echo "phy set polarity-rev portlist="${CPI_PORT[$port]}" lane-cnt=1 property=rx data=${CPI_POLARITY_DATA[$port]}" >> $OUTPUT_FILE_CFG
    done

    echo "" >> $OUTPUT_FILE_CFG
}

function Write_Cfg_Preemphasis ()
{
    request_sfp=$1
    request_qsfp=$2
    request_interface=$3

    ## SFP
    if [[ "$request_interface" == "lbm" ]]; then
        assign_array_sfp=("${SFP_PREEMPHASIS_DATA_LOOPBACK[@]}")
    else
        if (( "$request_sfp" == 10 )); then
            assign_array_sfp=("${SFP_PREEMPHASIS_DATA_10G[@]}")
        elif [[ "$request_interface" == "dac" ]]; then
            assign_array_sfp=("${SFP_PREEMPHASIS_DATA_CR4[@]}")
        else    ## fiber
            assign_array_sfp=("${SFP_PREEMPHASIS_DATA_CAUI4[@]}")
        fi
    fi

    for (( port = $SFP_PORT_START ; port <= $SFP_PORT_END ; port += 1 ))
    do
        for (( index = 0 ; index < 4 ; index += 1 ))
        do
            echo "phy set pre-emphasis portlist="$port" lane-cnt=1 property="${SFP_PREEMPHASIS_PROPERTY[$index]}" data="${assign_array_sfp[ $port * 6 + ($index + 1)]} >> $OUTPUT_FILE_CFG    ## '6' is because array data inclue '{' & '}' & 4 values.
        done
        echo "" >> $OUTPUT_FILE_CFG
    done

    ## QSFP
    if (( "$request_qsfp" == 40 )); then
        assign_array_qsfp=("${QSFP_PREEMPHASIS_DATA_40G[@]}")
    elif (( "$request_qsfp" == 10 )); then
        assign_array_qsfp=("${QSFP_PREEMPHASIS_DATA_10G[@]}")
    elif (( "$request_qsfp" == 100 )); then
        if [[ "$request_interface" == "dac" ]] || [[ "$request_interface" == "lbm" ]]; then
            assign_array_qsfp=("${QSFP_PREEMPHASIS_DATA_CR4_6_PORT[@]}")
        else    ## fiber
            assign_array_qsfp=("${QSFP_PREEMPHASIS_DATA_CAUI4_6_PORT[@]}")
        fi
    elif (( "$request_qsfp" == 50 )); then
        if [[ "$request_interface" == "dac" ]] || [[ "$request_interface" == "lbm" ]]; then
            assign_array_qsfp=("${QSFP_PREEMPHASIS_DATA_CR4_12_PORT[@]}")
        else    ## fiber
            assign_array_qsfp=("${QSFP_PREEMPHASIS_DATA_CAUI4_12_PORT[@]}")
        fi
    elif (( "$request_qsfp" == 25 )); then
        if [[ "$request_interface" == "dac" ]] || [[ "$request_interface" == "lbm" ]]; then
            assign_array_qsfp=("${QSFP_PREEMPHASIS_DATA_CR4_16_PORT[@]}")
        else    ## fiber
            assign_array_qsfp=("${QSFP_PREEMPHASIS_DATA_CAUI4_16_PORT[@]}")
        fi
    fi

    for (( port = $QSFP_PORT_START ; port <= $qsfp_port_end ; port += 1 ))
    do
        port_index=$(( port - 48 ))
        for (( index = 0 ; index < 4 ; index += 1 ))
        do
            echo "phy set pre-emphasis portlist="$port" lane-cnt="$qsfp_lane_per_port" property="${QSFP_PREEMPHASIS_PROPERTY[$index]}" data="${assign_array_qsfp[ $port_index * 6 + ($index + 1) ]} >> $OUTPUT_FILE_CFG    ## '6' is because array data inclue '{' & '}' & 4 values.
        done
        echo "" >> $OUTPUT_FILE_CFG
    done

    ## CPI
    for (( port = 0 ; port < $CPI_PORT_NUM ; port += 1 ))
    do
        for (( index = 0 ; index < 4 ; index += 1 ))
        do
            echo "phy set pre-emphasis portlist="${CPI_PORT[$port]}" lane-cnt=1 property="${CPI_PREEMPHASIS_PROPERTY[$index]}" data="${CPI_PREEMPHASIS_DATA[ $index + 1 ]} >> $OUTPUT_FILE_CFG
        done
        echo "" >> $OUTPUT_FILE_CFG
    done

    echo "" >> $OUTPUT_FILE_CFG

    if [[ "$request_interface" == "dac" ]]; then
        echo "diag set addr addr=0x03A4211C data=0x02020030" >> $OUTPUT_FILE_CFG
        echo "diag set addr addr=0x03A4611C data=0x02020030" >> $OUTPUT_FILE_CFG
        echo "diag set addr addr=0x03A4A11C data=0x02020030" >> $OUTPUT_FILE_CFG
        echo "diag set addr addr=0x03A4E11C data=0x02020030" >> $OUTPUT_FILE_CFG
        echo "" >> $OUTPUT_FILE_CFG
    fi
}

function Write_Cfg_Property ()
{
    request_sfp=$1
    request_qsfp=$2
    request_interface=$3
    request_fec=$4
    request_an=$5

    if [[ "$request_interface" == "fiber" ]]; then
        interface_sfp="sr"
        if (( $request_qsfp == 50 )); then
            interface_qsfp="sr2"
        elif (( $request_qsfp == 25 || $request_qsfp == 10 )); then
            interface_qsfp="sr"
        else
            interface_qsfp="sr4"
        fi
    else
        interface_sfp="cr"
        if (( $request_qsfp == 50 )); then
            interface_qsfp="cr2"
        elif (( $request_qsfp == 25 || $request_qsfp == 10 )); then
            interface_qsfp="cr"
        else
            interface_qsfp="cr4"
        fi
    fi

    if [[ "$request_fec" == "on" ]]; then
        fec_sfp="enable"
        fec_qsfp="rs"
    else
        fec_sfp=$request_fec
        fec_qsfp=$request_fec
    fi

    echo "" >> $OUTPUT_FILE_CFG

    ## SFP
    echo "port set property portlist="$SFP_PORT_START"-"$SFP_PORT_END" speed="$request_sfp"g" >> $OUTPUT_FILE_CFG
    echo "port set property portlist="$SFP_PORT_START"-"$SFP_PORT_END" medium-type="$interface_sfp >> $OUTPUT_FILE_CFG
    echo "port set property portlist="$SFP_PORT_START"-"$SFP_PORT_END" fec="$fec_sfp >> $OUTPUT_FILE_CFG
    echo "port set property portlist="$SFP_PORT_START"-"$SFP_PORT_END" an="$request_an >> $OUTPUT_FILE_CFG
    echo "port set property portlist="$SFP_PORT_START"-"$SFP_PORT_END" admin=enable" >> $OUTPUT_FILE_CFG

    ## QSFP
    echo "port set property portlist="$QSFP_PORT_START"-"$qsfp_port_end" speed="$request_qsfp"g" >> $OUTPUT_FILE_CFG
    echo "port set property portlist="$QSFP_PORT_START"-"$qsfp_port_end" medium-type="$interface_qsfp >> $OUTPUT_FILE_CFG
    echo "port set property portlist="$QSFP_PORT_START"-"$qsfp_port_end" fec="$fec_qsfp >> $OUTPUT_FILE_CFG
    echo "port set property portlist="$QSFP_PORT_START"-"$qsfp_port_end" an="$request_an >> $OUTPUT_FILE_CFG
    echo "port set property portlist="$QSFP_PORT_START"-"$qsfp_port_end" admin=enable" >> $OUTPUT_FILE_CFG

    ## CPI
    echo "port set property portlist="${CPI_PORT[0]}"-"${CPI_PORT[1]}" speed=10g">> $OUTPUT_FILE_CFG
    echo "port set property portlist="${CPI_PORT[0]}"-"${CPI_PORT[1]}" medium-type=kr">> $OUTPUT_FILE_CFG
    echo "port set adver portlist="${CPI_PORT[0]}"-"${CPI_PORT[1]}" speed-10g-kr">> $OUTPUT_FILE_CFG
    echo "port set property portlist="${CPI_PORT[0]}"-"${CPI_PORT[1]}" an=enable">> $OUTPUT_FILE_CFG

    echo "" >> $OUTPUT_FILE_CFG
}

function Help_Input ()
{
    echo "Please enter at least 2 parameters (QSFP & SFP speed)!!!"
    echo "    # QSFP          [*100/50/40/25/10]"
    echo "    # SFP           [*25/10]"
    echo "    # Interface     [*fiber/DAC/lbm]"
    echo "    # VLAN          [*off/on/single]"
    echo "    # FEC           [*off/fc-fec/rs-fec/on (SFP:FC-FEC;QSFP:RS-FEC)]"
    echo "    # Auto-Neg      [*off/on]"
    echo "    Ps. '*' means default setting"
    echo ""
    echo "    Ex: ./sdk_start qsfp=100 sfp=25"
    echo "    Ex: ./sdk_start qsfp=100 sfp=25 if=fiber an=on fec=rs-fec vlan=on "
}

function Input_Get ()
{
    input_string=$1
    IFS='=' read -ra input_parts <<< "$input_string"
    input_item=${input_parts[0]}
    input_value=${input_parts[1]}

    if [[ $input_item == "qsfp" ]] || [[ $input_item == "QSFP" ]]; then
        if [[ $input_value == "100" ]] || [[ $input_value == "50" ]] || [[ $input_value == "40" ]] || [[ $input_value == "25" ]] || [[ $input_value == "10" ]]; then
            if [[ $input_value == "100" ]] || [[ $input_value == "40" ]]; then
                qsfp_port_end=53
                qsfp_port_num=6
                qsfp_lane_per_port=4
            elif [[ $input_value == "50" ]]; then
                qsfp_port_end=59
                qsfp_port_num=12
                qsfp_lane_per_port=2
            elif [[ $input_value == "25" ]] || [[ $input_value == "10" ]]; then
                qsfp_port_end=63
                qsfp_port_num=16
                qsfp_lane_per_port=1
            fi
            config_qsfp_speed=$input_value
            echo " # QSFP : $config_qsfp_speed G"    ## for show/debug
        else
            echo "  Invalid QSFP speed setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "sfp" ]] || [[ $input_item == "SFP" ]]; then
        if [[ $input_value == "25" ]] || [[ $input_value == "10" ]]; then
            config_sfp_speed=$input_value
            echo " # SFP : $config_sfp_speed G"    ## for show/debug
        else
            echo "  Invalid SFP speed setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "if" ]] || [[ $input_item == "interface" ]] || [[ $input_item == "Interface" ]]; then
        if [[ $input_value == "DAC" ]] || [[ $input_value == "dac" ]] || [[ $input_value == "fiber" ]] || [[ $input_value == "lbm" ]] ; then
            if [[ $input_value == "DAC" ]]; then
                input_value="dac"
            fi
            config_interface=$input_value
            echo " # Interface : $config_interface"    ## for show/debug
        else
            echo "  Invalid interface setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "vlan" ]] || [[ $input_item == "VLAN" ]] || [[ $input_item == "vl" ]]; then
        if [[ $input_value == "on" ]] || [[ $input_value == "off" ]] || [[ $input_value == "single" ]]; then
            config_vlan=$input_value
            echo " # VLAN : $config_vlan"    ## for show/debug
        else
            echo "  Invalid VLAN setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "fec" ]] || [[ $input_item == "FEC" ]]; then
        if [[ $input_value == "off" ]] || [[ $input_value == "fc-fec" ]] || [[ $input_value == "rs-fec" ]] || [[ $input_value == "on" ]]; then
            if [[ $input_value == "off" ]]; then
                sdk_fec="disable"
            elif [[ $input_value == "fc-fec" ]]; then
                sdk_fec="enable"
            elif [[ $input_value == "rs-fec" ]]; then
                sdk_fec="rs"
            elif [[ $input_value == "on" ]]; then
                sdk_fec="on"
            fi
            config_fec=$sdk_fec
            echo " # FEC : $input_value"    ## for show/debug
        else
            echo "  Invalid FEC setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "an" ]] || [[ $input_item == "AN" ]]; then
        if [[ $input_value == "off" ]] || [[ $input_value == "on" ]]; then
            config_an=$input_value
            echo " # AN : $config_an"    ## for show/debug
        else
            echo "  Invalid AutoNeg setting!"
            Help_Input
            exit 1
        fi
    elif [[ $input_item == "reset" ]]; then
        RELOAD_SPEED_FLAG=1
    fi

    ## Output to configure file.
    if (( $RELOAD_SPEED_FLAG == 1 ));then
        if [[ ! -d $OUTPUT_FOLDER ]]; then
            mkdir $OUTPUT_FOLDER
        fi
        OUTPUT_FILE_INIT="$OUTPUT_FOLDER/init_"$config_sfp_speed"Gx48_"$config_qsfp_speed"Gx"$qsfp_port_num".dsh"
        OUTPUT_FILE_CFG="$OUTPUT_FOLDER/cfg_"$config_sfp_speed"Gx48_"$config_qsfp_speed"Gx"$qsfp_port_num".dsh"
    else
        OUTPUT_FILE_INIT="$MFG_WORK_DIR/init.dsh"
        OUTPUT_FILE_CFG="$MFG_WORK_DIR/cfg.dsh"
    fi

    if [[ -f $OUTPUT_FILE_INIT ]]; then
        rm $OUTPUT_FILE_INIT
    fi
    if [[ -f $OUTPUT_FILE_CFG ]]; then
        rm $OUTPUT_FILE_CFG
    fi
}

function Input_Help ()
{
    input_string=$1

    if [[ $input_string == "-h" ]] || [[ $input_string == "-help" ]] || [[ $input_string == "--h" ]] || [[ $input_string == "--help" ]] || [[ $input_string == "?" ]]; then
        Help_Input
        exit 1
    fi
}

Input_Help $1

Input_Get $1
Input_Get $2
Input_Get $3
Input_Get $4
Input_Get $5
Input_Get $6

## For init.dsh
Write_Init_Header
Write_Init_Body_SFP $config_sfp_speed
Write_Init_Body_QSFP $config_qsfp_speed
Write_Init_Body_CPI
Write_Init_Buttom

## For cfg.dsh
Write_Cfg_LaneSwap $config_sfp_speed $config_qsfp_speed
Write_Cfg_Polarity $config_sfp_speed $config_qsfp_speed
Write_Cfg_Preemphasis $config_sfp_speed $config_qsfp_speed $config_interface
Write_Cfg_Property $config_sfp_speed $config_qsfp_speed $config_interface $config_fec $config_an

if [[ "$config_vlan" != "off" ]]; then
    echo "" >> $OUTPUT_FILE_CFG
    echo "wait set delay=3" >> $OUTPUT_FILE_CFG
    if [[ "$config_vlan" == "on" ]]; then
        echo "diag load script name=$OUTPUT_FOLDER/vlan_set.dsh" >> $OUTPUT_FILE_CFG
    elif [[ "$config_vlan" == "single" ]]; then
        echo "diag load script name=$OUTPUT_FOLDER/vlan_set_perport.dsh" >> $OUTPUT_FILE_CFG
    fi
fi

#cat $OUTPUT_FILE    ## for debug

if (( $RELOAD_SPEED_FLAG != 1 )); then
    $MFG_WORK_DIR/sdk_ref
fi
