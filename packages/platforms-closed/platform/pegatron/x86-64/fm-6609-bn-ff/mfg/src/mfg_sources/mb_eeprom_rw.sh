#! /bin/bash
####################################################
# This script is to access info in MB EEPROM
#   ex. S/N number , product name
# $1 : r/w
# $2 : item , ex: serial_number , product_name
# $3 : write-in value, if $1 = w
####################################################

## variables defined ::
source /home/root/mfg/mfg_sources/platform_detect.sh

ARRAY_ITEMS=4
ARRAY_ACTION=("serial_number" "product_name" "mac_amount" "mac_address")
ARRAY_ACTION_NAME=("S/N number" "Product name" "MAC amount" "MAC address")
ARRAY_EXAMPLE_VALUE=("1234-5670" "FN-6254-DN-F" "73" "00:a0:c9:44:55:66")
ARRAY_ONIE_TYPE=("$ONIE_SN_TYPECODE" "$ONIE_PRODUCTNAME_TYPECODE" "$ONIE_MACNUM_TYPECODE" "$ONIE_MAC_TYPECODE")

ETHERNET_INTERFACE=$ETHTOOL_NAME
if [[ "$SUPPORT_CPU" == "RANGELEY" ]]; then
    MAC_START_ADDRESS=0x0000
    MAC_START_ADDRESS_BASE=0000
    MAC_START_ADDRESS_BYTE=1
elif [[ "$SUPPORT_CPU" == "DENVERTON" ]]; then
    MAC_START_ADDRESS=0x0288
    MAC_START_ADDRESS_BASE=0280
    MAC_START_ADDRESS_BYTE=9
elif [[ "$SUPPORT_CPU" == "BDXDE" ]]; then
    MAC_START_ADDRESS=0x0000
    MAC_START_ADDRESS_BASE=0000
    MAC_START_ADDRESS_BYTE=1
fi

LENGTH_MAC_NUMBER=2
LENGTH_MAC_ADDRESS=6
LENGTH_MAC_ADDRESS_CHAR=12
LENGTH_MAC_ADDRESS_CHAR_MARK=17        ## 17 means aa:bb:cc:dd:ee:ff , include ':' mark.
LENGTH_SN=32
declare -a char_array
declare -a ascii_array

function Write_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3
    i2c_data=$4

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cset -y $i2c_bus $i2c_device $i2c_register $i2c_data
    else
        swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_SET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE $i2c_data ; } 2>&1 )
    fi
    usleep $I2C_ACTION_DELAY
}

function Read_I2C_Device_Node()
{
    i2c_bus=$1
    i2c_device=$2
    i2c_register=$3

    if (( $FLAG_USE_IPMI == "$FALSE" )); then
        i2cget -y $i2c_bus $i2c_device $i2c_register
        usleep $I2C_ACTION_DELAY
    else
        value_get_through_ipmi=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_I2C_GET $i2c_bus $i2c_device $i2c_register $BMC_I2C_ACCESS_DATALEN_ONE ; } 2>&1 )
        usleep $I2C_ACTION_DELAY
        ## 20200921 Due to BMC v3 will return fail msg, so need to add case to handle
        if [[ "$value_get_through_ipmi" == *"Unspecified error"* ]]; then
            ipmi_value_toHex=0x00
        else
            ipmi_value_toHex=$( { printf '0x%02x\n' "$((16#$(expr substr "$value_get_through_ipmi" 2 2)))" ; } 2>&1 )    # orig value format is " XX" , so just get XX then transform as 0xXX format.
        fi
        echo $ipmi_value_toHex    # this line is to make return with value 0xXX
        return
    fi
}

function Open_EEPROM_Access ()
{
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_B $I2C_MUX_CHANNEL_MB_EEPROM_WP

    ## to disable eeprom write protection bit.
    orig_value=$( { Read_I2C_Device_Node $I2C_BUS $CPLD_MCR2_CONTROL $CPLD_MCR2_REG ; } 2>&1 )
    bit_invert=$(( ~ CPLD_MCR2_EEPROM_WP_BIT ))
    new_value=$(( $orig_value & $bit_invert ))
    Write_I2C_Device_Node $I2C_BUS $CPLD_MCR2_CONTROL $CPLD_MCR2_REG $new_value

    ## change MUX A channel 2 to access EEPROM
    Write_I2C_Device_Node $I2C_BUS $I2C_MUX_MB_EEPROM $I2C_MUX_CHANNEL_MB_EEPROM

    ## make sure 0x54 show up.
    #i2cdetect -y $I2C_BUS
}

function Close_EEPROM_Access ()
{
    Write_I2C_Device_Node $I2C_BUS $CPLD_MCR2_CONTROL $CPLD_MCR2_REG $orig_value
}

function Check_Request_Action ()
{
    _action=$1

    for (( k = 0 ; k < $ARRAY_ITEMS ; k++ ))
    do
        if [[ "$_action" == "${ARRAY_ACTION[k]}" ]]; then
            action_name=${ARRAY_ACTION_NAME[k]}
            onie_type_code=${ARRAY_ONIE_TYPE[k]}
            flag_found=$TRUE
            break
        fi
    done
    ## come here means actioin input is not valid !
    if (( $flag_found == $FALSE )); then
        echo " # action value '$_action' is not valid. "
        exit 1
    fi

    if [[ "$action_name" == "MAC amount" ]]; then
        target_length=$LENGTH_MAC_NUMBER
    elif [[ "$action_name" == "MAC address" ]]; then
        target_length=$LENGTH_MAC_ADDRESS
    else
        target_length=${#input_value}
    fi
}

function Search_Target_Address ()
{
    for (( i = $ONIE_TLVDATA_START_OFFSET ; i < $MB_EEPROM_SIZE ; i++ ))
    do
        read_type=$( { Read_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $i ; } 2>&1 )
        if [[ "$read_type" == "$onie_type_code" ]]; then
            read_length=$( { Read_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $((i + 1)) ; } 2>&1 )
            if [[ "$read_length" != "0xff" ]]; then
                read_len=$( { echo $read_length | awk '{printf "%d", $1}' ; } 2>&1 )
                ## if last data byte exist and also next last byte is 'line feed' mark , present it is target type value.
                read_last_byte=$( { Read_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $((i + 1 + $read_len)) ; } 2>&1 )

                read_out_bound=$( { Read_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $((i + 1 + $read_len + 1)) ; } 2>&1 )
                if [[ "$read_last_byte" != "0xff" && "$read_out_bound" == "0x0a" ]]; then
                    avalible_start_addr=$i
                    break
                fi
            fi
        fi
    done
}

function Search_EEPROM_Empty_Block ()
{
    useful_block=0

    for (( m = $ONIE_TLVDATA_START_OFFSET ; m < $MB_EEPROM_SIZE ; m++ ))
    do
        offset=$m
        read_byte_check=$( { Read_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $offset ; } 2>&1 )
        if [[ "$read_byte_check" == "0xff" ]]; then
            useful_block=$(( $useful_block + 1 ))
        else    # not continual null space, need to re-find one.
            useful_block=0
        fi

        if [[ $useful_block == $(( $target_length + 3 )) ]]; then
            avalible_start_addr=$(( $m - ( $target_length + 2 ) ))
            # echo $avalible_start_addr
            break
        fi
    done

    ## for prevent user misunderstand info were wrote in.
    if (( $useful_block == 0 )); then
        echo " Sorry, there is no enough EEPROM space to store data ..."
        Close_EEPROM_Access
        exit 1
    fi
}

function Handle_MAC_Address_Format ()
{
    if (( ${#input_value} != $LENGTH_MAC_ADDRESS_CHAR_MARK )); then
        for (( i = 0 , b = 0 ; i < ${#input_value} ; i+=2 , b+=1 ))
        do
            mac_upper_bound=$( { echo ${input_value:i:2} | tr '[:lower:]' '[:upper:]' ; } 2>&1 )    # 2-char is a group of byte, trans to upper bound.
            char_array[b]=$mac_upper_bound
        done
        mac_addr_format=${char_array[0]}":"${char_array[1]}":"${char_array[2]}":"${char_array[3]}":"${char_array[4]}":"${char_array[5]}
    else
        mac_upper_bound=$( { echo $input_value | tr '[:lower:]' '[:upper:]' ; } 2>&1 )    # trans to upper bound.

        for (( i = 1 , b = 0 ; i <= $LENGTH_MAC_ADDRESS ; i+=1 , b+=1 ))
        do
            char_array[b]=$( { echo $mac_upper_bound | cut -d ':' -f $i ; } 2>&1 )
        done
    fi
}

function Update_MAC_In_Mainboard_EEPROM ()
{
    ## write new MAC address (6-byte) to Ethernet controller's EEPROM.
    for (( b = 0 ; b < $LENGTH_MAC_ADDRESS ;  b += 1 ))
    do
        write_hex=$( { echo "0x"${char_array[b]} ;} 2>&1 )
        offset_addr=$(( $MAC_START_ADDRESS + $b ))
        hex_value=$( { echo obase=16"; $offset_addr" | bc ; } 2>&1 )
        offset_addr_hex=$( { echo "0x0"$hex_value ; } 2>&1 )
        ethtool -E $ETHERNET_INTERFACE magic $INTEL_MAGIC_NUMBER offset $offset_addr_hex value $write_hex
        # echo "ethtool -E $ETHERNET_INTERFACE magic $INTEL_MAGIC_NUMBER offset $offset_addr value $write_hex"   # [debug]
        usleep 200000
    done
}

function Mutex_Check_And_Create()
{
    ## check whether mutex key create by others process, if exist, wait until this procedure can create then keep go test.
    while [ -f $I2C_MUTEX_NODE ]
    do
        #echo " !!! Wait for I2C bus free !!!"
        sleep 1
        if [ ! -f $I2C_MUTEX_NODE ]; then
            break
        fi
    done
    ## create mutex key
    touch $I2C_MUTEX_NODE
    sync
    usleep 100000
}

function Mutex_Clean()
{
    rm $I2C_MUTEX_NODE
    sync
    usleep 100000
}

function Help_Message ()
{
    for (( i = 0 ; i < $ARRAY_ITEMS ; i++ ))
    do
        echo " Please enter action bit (r/w). Ex: ./mfg_sources/mb_eeprom_rw.sh r ${ARRAY_ACTION[i]}"
        echo "             value if 'w' mode. Ex: ./mfg_sources/mb_eeprom_rw.sh w ${ARRAY_ACTION[i]} ${ARRAY_EXAMPLE_VALUE[i]}"
    done
}

if (( $# < 2 )); then
    Help_Message
else
    if [[ "$1" == "w" ]]; then
        if [[ -z "$3" ]]; then
            for (( j = 0 ; j < $ARRAY_ITEMS ; j++ ))
            do
                if [[ "$2" == "${ARRAY_ACTION[j]}" ]]; then
                    action_name=${ARRAY_ACTION_NAME[0]}
                    break
                fi
            done
            echo " # need $action_name value to be setting."
            exit 1
        else
            ## Input value exist, but need validation check. If valid, decide others variables.
            input_value=$3
            Check_Request_Action $2

            if [[ "$action_name" == "S/N number" ]] && (( ${#input_value} > $LENGTH_SN ));then
                echo " # Out of length, only accept $LENGTH_SN bytes."
                exit 1
            elif [[ "$action_name" == "MAC amount" ]] && (( $input_value > 65535 ));then
                echo " Invalid MAC amount, only accept 1 ~ 65535"
                exit 1
            elif [[ "$action_name" == "MAC address" ]]; then
                if (( ( ${#input_value} != $LENGTH_MAC_ADDRESS_CHAR ) && ( ${#input_value} != $LENGTH_MAC_ADDRESS_CHAR_MARK ) ));then
                    echo " Invalid MAC address, only accept 6-byte"
                    exit 1
                else
                    Handle_MAC_Address_Format
                    ## for check MAC address validation
                    ## case 1 : multicase address (byte[0]'s bit[0] can't be 1
                    temp_val=${char_array[0]}
                    hex_value=$(( 16#$temp_val ))
                    if (( ( $hex_value & 0x01 ) == 1 )); then
                        echo " ! Invalid input address ! It ( ${char_array[0]} ) is a multicast address ..."
                        exit 1
                    fi
                    ## case 2 : zero address
                    zero_count=0
                    for (( b = 0 ; b < $LENGTH_MAC_ADDRESS ; b+=1 ))
                    do
                        if [[ "${char_array[b]}" == "00" ]]; then
                            zero_count=$(( $zero_count + 1 ))
                        fi
                    done
                    if (( $zero_count == 6 )); then
                        echo " ! Invalid input address ! It is a zero address ..."
                        exit 1
                    fi
                    ## check End
                fi
            fi

            ## Start to access EEPROM
            Mutex_Check_And_Create
            if (( $FLAG_USE_IPMI == "$TRUE" )); then
                swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
            fi

            if (( $ONIE_ACCESS_WAY == 1 )); then
                if [[ "$action_name" == "MAC address" ]]; then
                    if (( ${#input_value} != $LENGTH_MAC_ADDRESS_CHAR_MARK )); then
                        onie_syseeprom -s $ONIE_MAC_TYPECODE="$mac_addr_format"
                    else
                        onie_syseeprom -s $ONIE_MAC_TYPECODE="$mac_upper_bound"
                    fi

                    ## write new MAC address (6-byte) to Ethernet controller's EEPROM.
                    Update_MAC_In_Mainboard_EEPROM
                else
                    onie_syseeprom -s $onie_type_code="$input_value"
                fi
            else
                # echo "$input_value" | xxd -ps   ## [debug] translate to ASCII for check ; !!! But 'xxd' not supported on our rootfs !!!
                Open_EEPROM_Access

                ## dump out EEPROM value before write new SN.
                # i2cdump -y $I2C_BUS $MB_EEPROM_ADDR b

                ## search value stored location, if it is exist.
                Search_Target_Address

                ## case 1 : Above search result exist, so clean old first.
                if [[ ! -z "$avalible_start_addr" ]]; then
                    for (( l = 0 ; l < $(( read_len + 3 )) ; l++ ))
                    do
                        offset=$(( $avalible_start_addr + $l ))
                        Write_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $offset 0xff b
                    done
                else    ## case 2 : above action didn't find out the target , so need to find a new continual null space to store new data.
                    Search_EEPROM_Empty_Block
                fi

                ## start to write new data.
                Write_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $avalible_start_addr $onie_type_code b              ## checked byte - typecode

                ascii_var=$( { echo "${#input_value}" | od -h | sed -n "1p" | cut -c15-16 ; } 2>&1 )
                ascii_var_hex=$( { echo "0x"$ascii_var ;} 2>&1 )
                #echo $ascii_var_hex
                Write_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $(( avalible_start_addr + 1 )) $target_length b    ## target string length

                if [[ "$action_name" == "MAC amount" ]]; then
                    hex_value=0x$( { echo obase=16"; $input_value" | bc ; } 2>&1 )
                    # echo $hex_value ## [debug]
                    offset=$(( $avalible_start_addr + 2 ))
                    Write_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $offset $hex_value w
                else
                    if [[ "$action_name" == "MAC address" ]]; then
                        Update_MAC_In_Mainboard_EEPROM
                    fi

                    for (( i = 0 ; i < ${#input_value} ; i++ ))
                    do
                        ## handle input string and then translate into hex.
                        char_array[i]=${input_value:i:1}
                        # echo "${char_array[$i]}" | xxd -ps | cut -c1-2   ## [debug] translate to ASCII for check, But 'xxd' not supported on our rootfs !
                        ascii_array[i]=$( { echo "${char_array[i]}" | od -h | sed -n "1p" | cut -c15-16 ; } 2>&1 )
                        write_hex=$( { echo "0x"${ascii_array[i]} ;} 2>&1 )
                        # printf "%c , %s\n" "${char_array[i]}" "$write_hex"   ## [debug]

                        offset=$(( $avalible_start_addr + 2 + $i ))

                        ## write data to pointed location bit.
                        Write_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $offset $write_hex
                    done
                fi

                offset=$(( $avalible_start_addr + 2 + $target_length ))
                Write_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $offset 0x0a

                ## dump out EEPROM value for check ( in bye format)
                i2cdump -y $I2C_BUS $MB_EEPROM_ADDR b

                Close_EEPROM_Access
            fi

            Mutex_Clean
            if (( $FLAG_USE_IPMI == "$TRUE" )); then
                swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
            fi

            ## for dynamic change current ethernet port's MAC address so that if using ifconfig can be checked, if needed.
            if (( 0 )); then
                mac_addr_format=${char_array[0]}":"${char_array[1]}":"${char_array[2]}":"${char_array[3]}":"${char_array[4]}":"${char_array[5]}
                /etc/init.d/networking stop
                ifconfig $ETHTOOL_NAME hw ether $mac_addr_format
                /etc/init.d/networking start
            fi

            echo " # Set $action_name done."
        fi
    elif [[ "$1" == "r" ]]; then
        Check_Request_Action $2

        Mutex_Check_And_Create
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_DISABLE ; } 2>&1 )    # disable BMC sensor monitor to prevent job was paused or interfered in.
        fi

        if (( $ONIE_ACCESS_WAY == 1 )); then
            get_value=$( { onie_syseeprom -g $onie_type_code ; } 2>&1 )
            printf " # $action_name : "
            echo $get_value
        else
            Open_EEPROM_Access

            ## look for exsit target value.
            Search_Target_Address

            if [[ -z "$avalible_start_addr" ]]; then
                echo " # $action_name has not been set yet !"
            else
                for (( i = 0 ; i < $read_len ; i++ ))
                do
                    offset=$(( $avalible_start_addr + 2 + $i ))
                    read_data=$( { Read_I2C_Device_Node $I2C_BUS $MB_EEPROM_ADDR $offset ; } 2>&1 )

                    if [[ "$action_name" == "MAC amount" ]]; then
                        char_array[i]=$( { echo $read_data | cut -c3-4 ; } 2>&1 )
                        if (( $i == 0 )); then
                            mac_amount_result=$( { echo 0x${char_array[i]} | awk '{printf "%d", $1}' ; } 2>&1 )
                        else
                            mac_amount_result=$(( $mac_amount_result + ( 256 * $i * $( { echo 0x${char_array[i]} | awk '{printf "%d", $1}' ; } 2>&1 ) ) ))
                        fi
                    elif [[ "$action_name" == "MAC address" ]]; then
                        char_array[i]=$( { echo $read_data | cut -c3-4 ; } 2>&1 )
                    else
                        if [[ "$read_data" == "0xff" || "$read_data" == "0x0a" ]]; then
                            break;
                        else
                            ## way 1, for 'xxd' use
                            # ascii_array[i]=$( { echo $read_data | cut -c3-4 ; } 2>&1 )
                            # tmp=$( { echo $tmp${ascii_array[i]} ; } 2>&1 )

                            ## way 2
                            char_array[i]=$( { echo $read_data | awk '{printf "%c", $1}' ; } 2>&1 )
                        fi
                    fi
                done

                ## way 1. translate from ASCII to char ! But 'xxd' not supported on our rootfs !!!
                # echo "$tmp" | xxd -ps -r

                ## way 2.
                printf " # $action_name : "
                if [[ "$action_name" == "MAC amount" ]]; then
                    echo $mac_amount_result
                elif [[ "$action_name" == "MAC address" ]]; then
                    macaddr_mbeeprom=${charArray[0]}":"${charArray[1]}":"${charArray[2]}":"${charArray[3]}":"${charArray[4]}":"${charArray[5]}
                    macaddr_mbeeprom_upb=$( { echo $macaddr_mbeeprom | tr '[:lower:]' '[:upper:]' ; } 2>&1 )
                    printf " [MB] = "
                    echo $macaddr_mbeeprom_upb
                else
                    printf "%c" ${char_array[@]}
                    printf "\n"
                fi
            fi

            Close_EEPROM_Access
        fi

        Mutex_Clean
        if (( $FLAG_USE_IPMI == "$TRUE" )); then
            swallow_empty_line=$( { ipmitool raw $BMC_NET_FUNCTION $BMC_SENSOR_MONITOR_REG $BMC_SENSOR_ENABLE ; } 2>&1 )
        fi

        if [[ "$action_name" == "MAC address" ]]; then     ## MAC address another way : search in Ethernet controller's EEPROM
            for (( i = $MAC_START_ADDRESS_BYTE ; i < $(( $LENGTH_MAC_ADDRESS + $MAC_START_ADDRESS_BYTE )) ; i++ ))
            do
                readData=$( { ethtool -e $ETHERNET_INTERFACE | grep $MAC_START_ADDRESS_BASE | cut -d ' ' -f $i ; } 2>&1 )
                # usleep 200000
                if [[ "$i" == "1" ]]; then
                    charArray[i]=$( { echo $readData | cut -c9-10 ; } 2>&1 )
                else
                    charArray[i]=$readData
                fi
            done

            macaddr_ethcontroller=${charArray[$(( $MAC_START_ADDRESS_BYTE ))]}":"${charArray[$(( $MAC_START_ADDRESS_BYTE + 1 ))]}":"${charArray[$(( $MAC_START_ADDRESS_BYTE + 2 ))]}":"${charArray[$(( $MAC_START_ADDRESS_BYTE + 3 ))]}":"${charArray[$(( $MAC_START_ADDRESS_BYTE + 4 ))]}":"${charArray[$(( $MAC_START_ADDRESS_BYTE + 5 ))]}
            mac_upb=$( { echo $macaddr_ethcontroller | tr '[:lower:]' '[:upper:]' ; } 2>&1 )    # trans to upper bound.
            printf " # $action_name [NPU] = "
            echo $mac_upb
        fi
    else
        echo " Error input !"
        Help_Message
    fi
fi
