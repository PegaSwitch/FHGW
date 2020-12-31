#! /bin/bash

function CPU_Model_Check ()
{
    cpu_name=$( cat /proc/cpuinfo | grep -m 1 "model name" | cut -c14- )
    if [[ "$cpu_name" == *"$CPU_RANGELEY"* ]]; then
        I2C_BUS=1
        SUPPORT_CPU="RANGELEY"
    elif [[ "$cpu_name" == *"$CPU_DENVERTON"* ]]; then
        I2C_BUS=0
        SUPPORT_CPU="DENVERTON"
    else
        for (( i = 0 ; i < ${#CPU_BDXDE[@]} ; i++ ))
        do
            if [[ "$cpu_name" == *"${CPU_BDXDE[$i]}"* ]]; then
                I2C_BUS=0
                SUPPORT_CPU="BDXDE"
                break
            fi
        done

        if [[ "$SUPPORT_CPU" == "no" ]]; then
            echo "### Unrecognized CPU !!!  Will exit script immediately !!!"
            exit 1
        fi
    fi
    # sleep 1
}

function Project_ID_Check ()
{
    # Proj Name   Proj ID
    # Cadillac    xxx0_0000 (0x0)
    # Mercedes    xxx0_0001 (0x1)
    # Mercedes3   xxx0_0010 (0x2)
    # Porsche     xxx0_0011 (0x3)
    # Bugatti     xxx0_0100 (0x4)
    # Bugatti2    xxx0_0111 (0x7)
    # Jaguar      xxx0_0101 (0x5)
    # AstonMartin xxx0_1000 (0x8)
    # Gemini      xxx0_1001 (0x9)

    if [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
        ## read boardID by GPIO_15,14,16,18 to determine value. So check GPIO status bit_1 : 1 (=2) means high ; 0 (=0) means low.
        readGPIO_15=$( { /sbin/gpio r 15 | cut -c30- ; } 2>&1 )
        if [[ "$readGPIO_15" == "2" ]]; then
            readGPIO_15=1
        fi
        readGPIO_14=$( { /sbin/gpio r 14 | cut -c30- ; } 2>&1 )
        if [[ "$readGPIO_14" == "2" ]]; then
            readGPIO_14=1
        fi
        readGPIO_16=$( { /sbin/gpio r 16 | cut -c30- ; } 2>&1 )
        if [[ "$readGPIO_16" == "2" ]]; then
            readGPIO_16=1
        fi
        readGPIO_18=$( { /sbin/gpio r 18 | cut -c30- ; } 2>&1 )
        if [[ "$readGPIO_18" == "2" ]]; then
            readGPIO_18=1
        fi
        board_ID_bit=$( { echo $readGPIO_15$readGPIO_14$readGPIO_16$readGPIO_18 ; } 2>&1 )
        #echo $board_ID_bit
    #elif [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
    else    ## BDXDE
        if [[ ! -f "$GPIO_MUTEX_NODE" ]]; then
            touch $GPIO_MUTEX_NODE
            echo "480" > /sys/class/gpio/export    #GPIO_44
            echo "481" > /sys/class/gpio/export    #GPIO_45
            echo "482" > /sys/class/gpio/export    #GPIO_46
            echo "494" > /sys/class/gpio/export    #GPIO_58
        fi
        bit3=$( { cat /sys/class/gpio/gpio494/value ; } 2>&1 )
        bit2=$( { cat /sys/class/gpio/gpio482/value ; } 2>&1 )
        bit1=$( { cat /sys/class/gpio/gpio481/value ; } 2>&1 )
        bit0=$( { cat /sys/class/gpio/gpio480/value ; } 2>&1 )
        board_ID_bit=$( { echo $bit3$bit2$bit1$bit0 ; } 2>&1 )

        if (( 0 )); then
            rm $GPIO_MUTEX_NODE
            echo "480" > /sys/class/gpio/unexport
            echo "481" > /sys/class/gpio/unexport
            echo "482" > /sys/class/gpio/unexport
            echo "494" > /sys/class/gpio/unexport
        fi
    fi

    case $board_ID_bit in
        0000)   PROJECT_NAME="CADILLAC";;
        0001)   PROJECT_NAME="MERCEDES";;
        0010)   PROJECT_NAME="MERCEDES";;
        0100)   PROJECT_NAME="BUGATTI";;    #Tomhawk
        0111)   PROJECT_NAME="BUGATTI"      #Trident3
                ;;
        0011)   PROJECT_NAME="PORSCHE"
                ;;
        0101)   PROJECT_NAME="JAGUAR"
                ;;
        1000)   PROJECT_NAME="ASTON"
                ;;
        1001)   PROJECT_NAME="GEMINI"
                ;;
        1111)   ## if strap pin are full, will decide by CPLD register (0xFE [6:0])
                i2cset -y $I2C_BUS 0x73 0x0 0x1  ## $I2C_MUX_B_CHANNEL_0
                data_result=$( { i2cget -y $I2C_BUS 0x74 0xFE ; } 2>&1 )
                board_ID_bit=$(( $data_result & 0x7f ))
                case $board_ID_bit in
                    0001001) PROJECT_NAME="GEMINI";;
                    *) PROJECT_NAME="??";;
                esac
                ;;
        *) board_ID="??"
           printf "\n[MFG Error Msg] Current project NOT support yet !!!\n"
           exit 1
           ;;
    esac
    echo " # current project is $PROJECT_NAME" > /tmp/projectCheck

    # sleep 1
}

CPU_Model_Check
Project_ID_Check
