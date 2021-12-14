#!/bin/sh
# Script to run on the target to configure the wl18xx-conf.bin file to match the device capabilities

# version
VERSION=1.4

# defaults
binary_name="/lib/firmware/ti-connectivity/wl18xx-conf.bin"
wlconf_path="/usr/sbin/wlconf/"
ini_path="/usr/sbin/wlconf/official_inis"

# function for printing help
print_help()
{
	echo "Usage:  configure-device.sh <option>"
	echo "Options:"
	echo "      --version       show version"
	echo "      --help          show help"
	echo "      --dump			save wl18xx-conf.bin dump to wl18xx-conf-dump.txt"
	echo "      <empty>			configuration mode"
}


# function for printing dump
print_dump()
{
	echo "Saving wl18xx-conf.bin dump to wl18xx-conf-dump.txt"
	./wlconf -i $binary_name --get > wl18xx-conf-dump.txt
}

# function for printing summary
print_summary()
{
	echo ""
	echo "---------------------------------------------------------"
	echo ""
	echo "The device has been successfully configured."
	echo "TI Module: "$ti_mod
	echo "Chip Flavor: "$CHIP_FLAVOR
	echo "Base INI file used: "$ini_file_name
	echo "Number of 2.4GHz Antennas Fitted: "$number_2_4G_antenna
	echo "Number of 5GHz Antennas Fitted: "$number_5G_antenna
	echo "Diversity Support: "$diversity_5g
	echo "SISO40 Support: "$siso40mhz
	echo "Japanese Standards Applied: "$japan
	# Class 2 Permissive Change (C2PC) is always applied 
	#echo "Class 2 Permissive Change (C2PC) Applied: "$c2pc
if [ $TI_MODULE -eq 0 ]; then
	echo "105C Support:" $temp105
fi
	echo ""
	echo "---------------------------------------------------------"
	echo ""
}


# check for user option
if [ ! -z "$1" ]; then
	case $1 in
		"--version") echo "Version" $VERSION;exit;;
		"--help") print_help;exit;;
		"--dump") print_dump;exit;;
		*) echo "Unknown option entered";print_help;exit;;
	esac
fi

# start configuration
echo ""
echo "Please provide the following information."
echo ""

# ask if TI module is in use
TI_MODULE=-1;
while [ $TI_MODULE -eq -1 ]
do
	read -p 'Are you using a TI module? [y/n] : ' ti_mod
	case $ti_mod in
	    "n") TI_MODULE=0;;
	    "N") TI_MODULE=0;;
	    "y") TI_MODULE=1;;
	    "Y") TI_MODULE=1;;
	    *) echo "Please enter y or n.";TI_MODULE=-1;continue;;
    esac
done


# logic to be followed here is that if a device has a parameter with a value over 1 then there is a choice 
# that has to be made by user as to whether the feature will be used.
# e.g. a 2.4GHz MIMO capable device may only have a single antenna fitted
# assume that as 2.4GHz does not pass WFA test with 40MHz channels then we disable it for ALL devices
CHIP_FLAVOR=-1;
while [ $CHIP_FLAVOR -eq -1 ]
do
	read -p 'What is the chip flavor? [1801/1805/1807/1831/1835/1837 or 0 for unknown] : ' CHIP_FLAVOR
	case $CHIP_FLAVOR in
		1801) number_2_4G_antenna=1; number_5G_antenna=0;;
		1805) number_2_4G_antenna=2; number_5G_antenna=0;;
		1807) number_2_4G_antenna=2; number_5G_antenna=1;;
		1831) number_2_4G_antenna=1; number_5G_antenna=0;;
		1835) number_2_4G_antenna=2; number_5G_antenna=0;;
		1837) number_2_4G_antenna=2; number_5G_antenna=1;;
		0) number_2_4G_antenna=2; number_5G_antenna=1;;
		*) echo "Please enter 1801/1805/1807/1831/1835/1837 or 0 for unknown.";CHIP_FLAVOR=-1;continue;;
	esac
done


# decide upon the correct ini file

temp105="y";
SUPPORT_105=-1;
HIGHTEMP_TXPOWER=-1;
low_band_component_type=-1;
spare0=0x80
spare1=0x22
JP_STANDARD=-1;
japan="n";
jp_support=0;

if [ $TI_MODULE -eq 0 ]; then
	ini_file_name="WL8_COB_INI.ini"
else
	case $CHIP_FLAVOR in
			1801) ini_file_name="WL1835MOD_INI_C2PC.ini";;
			1805) ini_file_name="WL1835MOD_INI_C2PC.ini";;
			1807) ini_file_name="WL1837MOD_INI_FCC_CE.ini"; jp_support=1;;
			1831) ini_file_name="WL1835MOD_INI_C2PC.ini";;
			1835) ini_file_name="WL1835MOD_INI_C2PC.ini";;
			1837) ini_file_name="WL1837MOD_INI_FCC_CE.ini"; jp_support=1;;
			0) ini_file_name="WL1835MOD_INI.ini";;
	esac

	while [ $JP_STANDARD -eq -1 ]
	do
		if [ $jp_support -eq 1 ]; then
			read -p 'Should Japanese standards be applied? [y/n] : ' japan
			case $japan in
				"n") ini_file_name="WL1837MOD_INI_FCC_CE.ini";JP_STANDARD=0;;
				"N") ini_file_name="WL1837MOD_INI_FCC_CE.ini";JP_STANDARD=0;;
				"y") ini_file_name="WL1837MOD_INI_FCC_CE_JP.ini";JP_STANDARD=0;;  			 
				"Y") ini_file_name="WL1837MOD_INI_FCC_CE_JP.ini";JP_STANDARD=0;;
				*) echo "Please enter y or n";JP_STANDARD=-1;continue;;
			esac
		else
			# set to required number to exit loop
			JP_STANDARD=$jp_support;
		fi
	done
fi

# add the ini file path to the ini file name
ini_file_name=$ini_path"/"$ini_file_name

# check if the correct ini file exist
if [ ! -e $ini_file_name ]; then                                                                                                                     
    echo "$ini_file_name does not exist. Please contact your local TI representative or post a question on http://e2e.ti.com"
	exit;  
fi


# ask if one or two antennas will be fitted in 2.4GHz band
NUM_OF_ANTENNAS=-1;
while [ $NUM_OF_ANTENNAS -eq -1 ]
do
	if [ $number_2_4G_antenna -gt 1 ]; then
		read -p 'How many 2.4GHz antennas are fitted? [1/2] : ' NUM_OF_ANTENNAS
		case $NUM_OF_ANTENNAS in
			"1") number_2_4G_antenna=1;ht_mode=2;;
			"2") number_2_4G_antenna=2;ht_mode=0;;
			*) echo "Please enter 1 or 2 antennas";NUM_OF_ANTENNAS=-1;continue;;
        esac
	else
		# set to required number to exit loop
		NUM_OF_ANTENNAS=$number_2_4G_antenna;
	fi
done


# ask if a 5GHz antenna will be fitted
NUM_OF_ANTENNAS=-1;
while [ $NUM_OF_ANTENNAS -eq -1 ]
do
	if [ $number_5G_antenna -eq 1 ]; then
		read -p 'How many 5GHz antennas are fitted (using 2 antennas requires a proper switch)? [0/1/2] : ' NUM_OF_ANTENNAS
		case $NUM_OF_ANTENNAS in
			"0") number_5G_antenna=0;;
			"1") number_5G_antenna=1;;
			"2") number_5G_antenna=2;;
			*) echo "Please enter 0, 1 or 2";NUM_OF_ANTENNAS=-1;continue;;
        esac
	else
		# set to required number to exit loop
		NUM_OF_ANTENNAS=$number_5G_antenna;
	fi
done


# ask if 5GHz diversity is needed
if [[ $TI_MODULE -eq 1 ]] &&
   [[ $CHIP_FLAVOR -eq 1807 || $CHIP_FLAVOR -eq 1837 ]]; then
	diversity_5g="y";
	high_band_component_type=0x0a;
elif [ $number_5G_antenna -eq 2 ]; then
	diversity_5g="y";
	high_band_component_type=0x0a;
else
	diversity_5g="n";
	high_band_component_type=0x09;
fi


# ask if SISO40 should be enabled
SISO40=-1;
siso40mhz="y";
while [ $SISO40 -eq -1 ]
do
	if [ $number_2_4G_antenna -eq 1 ]; then
		read -p 'Should SISO40 support be applied? [y/n] : ' siso40mhz
		case $siso40mhz in
			"n") ht_mode=2;SISO40=0;;
			"N") ht_mode=2;SISO40=0;;
			"y") ht_mode=1;SISO40=0;;  			 
			"Y") ht_mode=1;SISO40=0;;
			*) echo "Please enter y or n";SISO40=-1;continue;;
		esac
	else
		# set to required number to exit loop
		SISO40=0;
	fi
done

if [ $TI_MODULE -eq 0 ]; then

	while [ $SUPPORT_105 -eq -1 ]
	do
		read -p 'Does COB Design support RF switch with 105C range ( default is 85C ) ? [y/n] : ' support105
			case $support105 in
				"n") SUPPORT_105=0;temp105="n";low_band_component_type=0x5;;
				"N") SUPPORT_105=0;temp105="n";low_band_component_type=0x5;;
				"y") SUPPORT_105=1;temp105="y";low_band_component_type=0x8;;  			 
				"Y") SUPPORT_105=1;temp105="y";low_band_component_type=0x8;;
				*) echo "Please enter y or n";SUPPORT_105=-1;continue;;
			esac


	done


	if [ $SUPPORT_105 -eq 1 ]; then
		
		while [ $HIGHTEMP_TXPOWER -eq -1 ]
		do
			read -p 'Reduce Tx Power at Higher Temperature ( default is 'n' ) ? [y/n] : ' hightemp_reduce_txpower

			case $hightemp_reduce_txpower in
                       		 "n") HIGHTEMP_TXPOWER=0;spare0=0x80;;
                        	 "N") HIGHTEMP_TXPOWER=0;spare0=0x80;;
                        	 "y") HIGHTEMP_TXPOWER=1;spare0=0x90;;
                        	 "Y") HIGHTEMP_TXPOWER=1;spare0=0x90;;
                        	 *) echo "Please enter y or n.";HIGHTEMP_TXPOWER=-1;continue;;

        		esac
		done
	

	fi

		
fi


# remove the wlcore_sdio module before updating the bin file
rmmod wlcore_sdio


# create clean file
cd $wlconf_path
./wlconf -o $binary_name -I $ini_file_name
  
  
# finally write values to binary
./wlconf -i $binary_name -o $binary_name -s wl18xx.phy.number_of_assembled_ant2_4=$number_2_4G_antenna
./wlconf -i $binary_name -o $binary_name -s wl18xx.phy.number_of_assembled_ant5=$number_5G_antenna
./wlconf -i $binary_name -o $binary_name -s wl18xx.phy.high_band_component_type=$high_band_component_type
./wlconf -i $binary_name -o $binary_name -s wl18xx.ht.mode=$ht_mode
./wlconf -i $binary_name -o $binary_name -s wl18xx.phy.spare1=$spare1

if [ $TI_MODULE -eq 0 ]; then
./wlconf -i $binary_name -o $binary_name -s wl18xx.phy.low_band_component_type=$low_band_component_type
./wlconf -i $binary_name -o $binary_name -s wl18xx.phy.spare0=$spare0
fi

print_summary

# reinsert the wlcore_sdio
modprobe wlcore_sdio

