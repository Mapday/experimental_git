# ##############################################################################
#		© 2021 NXP Confidential. All rights reserved
#
# File: 	Client_Scan_Assoc_A2DP_SNK.pl
# Author: 	GES Bangalore
# Date: 	16 APRIL 2021
#
# Purpose: Multi Profile Coex with A2DP_SNK + WLAN MoAP Enable.
#
# Type: Script file
# ##############################################################################

#Init Section

require('libs/Master_TestLib.pl');

use threads;
use threads::shared;
use List::Util qw( min max sum );
use Switch;

my $Activity_Flag;
my $AP;
my $AP_BACKEND_CMD;
my $BT_Duration;
my $BT_Interval;
my $client_num;
my $conn_flag;
my $count:shared;
my $Device1;
my $Device2;
my $Gap:shared;
my $Init_flag;
my $io_cap;
my $LinkType;
my $NUM_OF_A2DP_CONN;
my $pass_percent;
my $Rec_Duration;
my $Song_Duration;
my $THD:shared;
my $STA_counter;
my $STA_start_time:shared;
my $STA_total_time:shared;
my $Test_Duration;
my $Wlan_Duration;
my $total_conn_disc;
my @activity_threads;
my @APS;
my @AP_BACKENDS;
my @numOfAP_arr:shared;
my @wlan_scan_time_arr:shared;
my $mmh_client;
my $UAPUTL_PATH = "cd /usr/local/automation;";
$BLE_counter = 0;
$BLE_total_time = 0;
$STA_counter = 0;
$STA_total_time = 0;

# Check Input Arguments
&Check_Cmd_Arg();

@DEVICE = ('UUT', 'REF1');

if($wlan_device =~ /^EXT_AP(\d+)/i) {
    push(@DEVICE, $wlan_device);
    $client_num     = $1;
    $AP             = "EXT_AP$1";
    $AP_BACKEND_CMD = "AP_BACKEND$1";
    push(@APS, $AP);
    push(@AP_BACKENDS, $AP_BACKEND_CMD)
} elsif ($wlan_device =~ /^MMHAP(\d+)/i) {
    push(@DEVICE, $wlan_device);
    $client_num     = $1;
    $AP             = "MMHAP$1";
    $AP_BACKEND_CMD = "MMHAP$1";
    push(@APS, $AP);
    push(@AP_BACKENDS, $AP_BACKEND_CMD)
}

# initialization 
&Initialize('MoAP_A2DP_SNK', 'MMH',1);    

# Fetch SSID and STA Interface.

my $channel   = &get_db_data('UUT','CHANNEL');
my $intf_uap0 = &get_db_data('UUT','MMH_INTF');
my $ssid 	  = &get_db_data('UUT','SSID');
my $ApIntf    = $TBDEVICE{$TBDEVICE{"UUT"}."_$mmh_intf"};

#############################################################################################
# Initialization.

if($Init_flag == 'BT') {
    &Init_BT;
   # &Init_WLAN;
} 
elsif($Init_flag == 'WLAN'){
 #   &Init_WLAN;
    &Init_BT;
}

# Connection
if($conn_flag == 'WLAN') {
	#&Connect_WLAN;
	&Connect_BT;
}
elsif($conn_flag == 'BT') {
    &Connect_BT;
  #  &Connect_WLAN;
}

#A2DP Connection and Disconnection
for(my $iter = 1;$iter <= $NUM_OF_A2DP_CONN; $iter++) {
    &A2DP_Snk_Disconnect($Device1, $Device2);
    &my_sleep(2);
    &A2DP_Snk_Connect($Device1, $Device2);
    &my_sleep(2);
    print("\n-------------------------------connection counter: $iter---------------------\n");
}

# Threads for BT and WLAN Activity.
$A2DP_start_time = time;
$STA_Start_Time = time;

my $sta_thread;
my $A2DP_thread;

if($Activity_Flag == 'WLAN') {
    $sta_thread = threads->create(\&WLAN_Activity);
    $A2DP_thread = threads->create(\&A2DP_Activity);
} else {
    $A2DP_thread   = threads->create(\&A2DP_Activity);
    $sta_thread = threads->create(\&WLAN_Activity);
}

push (@activity_threads, $sta_thread);
push (@activity_threads, $A2DP_thread);

foreach (@activity_threads){$_ -> join()}

&Disconnect_BT;
&Get_Result;

sub Check_Cmd_Arg {
    my $num_args = $#ARGV + 1;
    if ($num_args < 11) {
        &Dprint($DHOST, $DINF, "Missing Arguments", 1);
        &Dprint($DHOST, $DINF, "Usage:\n perl MoAP_enable.pl <FLAG> <Protocol> <Direction> <Device1_DUT_A2DP_Src> <Device2_A2DP_Snk> <ACL_Packet_Type> <Link_Type> <Duration> <COD> <Sniff_params>", 1);
        &Dprint($DHOST, $DINF, "example usage :perl DBC_STA_STA_A2DP.pl UUT:1,MMH:1,BT:1 TCP TX TX UUT REF1 EDR BCR_MASTER 30 COD_MAJOR_PHONE SNIFF_TRUE_0x0320_0x0320_4_1 BT UUT#CONN_ORDER#MMH_INTF,MMH_INTF1 UUT#TRAFFIC_ORDER#MMH_INTF1,MMH_INTF UUT#CHANNEL#MMH_INTF1#1 UUT#BAND#MMH_INTF1#BGN UUT#CHANNEL_WIDTH#MMH_INTF1#40 UUT#SECURITY#MMH_INTF1#OPEN UUT#BAND#MMH_INTF#AC5 UUT#CHANNEL_WIDTH#MMH_INTF#80 UUT#SECURITY#MMH_INTF#OPEN UUT#CHANNEL#MMH_INTF#36 UUT#NSS#MMH_INTF#2x2 UUT#NSS#MMH_INTF1#2x2 UUT#ANT_MODE#MMH_INTF#2x2 UUT#ANT_MODE#MMH_INTF1#2x2 \n", 1);
        &monitor_result('exit_script', "Missing Arguments");
    }

    foreach (@ARGV) {
        if ($_ =~ m/^PROTOCOL#(.*)$/) {
			# Protocol (TCP/UDP).                             
		    $Proto = $1;
	    } elsif ($_ =~ m/^WLAN_DIRECTION1#(.*)$/) {
			# WLAN Traffic Direction.  
            $Direction = $1;
	    } elsif ($_ =~ m/^DEVICE1#(.*)$/) {
			# Device1 (UUT).
            $Device1 = $1;
	    } elsif ($_ =~ m/^DEVICE2#(.*)$/) {
			# Device2 (REF1).
            $Device2 = $1;
	    } elsif ($_ =~ m/^SONG_DURATION#(.*)$/) {
			# SONG DURATION
            $Song_Duration = $1;
        } elsif ($_ =~ m/^REC_DURATION#(.*)$/) {
			# REC DURATION
            $Rec_Duration = $1;
		} elsif ($_ =~ m/^LINK_TYPE#(.*)$/) {
			# Master/Slave
            $Link_Type = $1;
		} elsif ($_ =~ m/^NUM_OF_A2DP_CONN#(.*)$/) {
			# num of A2DP Connection
		    $NUM_OF_A2DP_CONN = $1;
		} elsif ($_ =~ m/^IO_CAP#(.*)$/){
			# DisplayYesNo.
			$io_cap = $1;
		} elsif ($_ =~ m/^BT_DURATION#(.*)$/) {
			# BT Duration.
            $BT_Duration = $1;
	} elsif ($_ =~ m/^BT_INTERVAL#(.*)$/) {
			# BT Interval.
            $BT_Interval = $1;	 
	} elsif ($_ =~ m/^TEST_DURATION#(.*)$/) {
			# Test Duration.
            $Test_Duration = $1;   
		} elsif ($_ =~ m/^TRAFFIC#(.*)$/){
			# unicast.
			$Taffic = $1;
	    } elsif ($_ =~ m/^CONN_FLAG#(.*)$/) {
			# Connection First (WLAN/BT).
            $conn_flag= $1;
	    } elsif ($_ =~ m/^ACTIVITY_FLAG#(.*)$/) {
			# Activity Flag(WLAN/BT).
            $Activity_Flag= $1;
        } elsif ($_ =~ m/^INIT_FLAG#(.*)$/) {
			# Initialization Flag.
            $Init_flag = $1;
        } elsif ($_ =~ m/^IPERF_DURATION#(.*)$/) {              
			# Iperf Duration.
            $Iperf_Duration= $1;
        } elsif ($_ =~ m/^WLAN_INTERVAL#(.*)$/) {
		# WLAN Interval.
		$WLAN_Interval = $1;
	}elsif($_  =~ m/^MMH_INTERFACE#(.*)$/){
		#MMH INTERFACE
		$mmh_intf = $_;
	}elsif ($_ =~ /^(UAP_START_STOP|REF_STA_CONN_DISC|MoAP_ASSOC|MoAP_TRAFFIC):(\d+)/i){
	    @features_to_test = split(',', $_);
		foreach (@features_to_test){
		    my @tempFeatureArray = split(':', $_);
			$features_to_test{$tempFeatureArray[0]} = $tempFeatureArray[1];
		}
	}elsif($_ =~ m/TOTAL_CONN_DISC#(.*)$/){
		$total_conn_disc = $1;
	}elsif($_  =~ m/^MMH_INTERFACE#(.*)$/){
		#MMH INTERFACE
		$mmh_intf = $1;
	}elsif($_  =~ m/^MMH_CLIENT#(.*)$/){
		#MMH CLIENT
		$mmh_client = $1;
	}elsif ($_ =~ m/^WLAN_DURATION#(.*)$/) {
		# Test Duration.
		$Wlan_Duration = $1;
	    
	}
    }
}

sub Connect_UAP {
	#&Uap_bss_stop('UUT', $ApIntf);
	&Execute_Command('UUT', "$UAPUTL_PATH ./uaputl.exe -i $intf_uap0 sys_cfg_channel $channel");
    &Execute_Command('UUT', "$UAPUTL_PATH ./uaputl.exe -i $intf_uap0 sys_cfg_ssid $ssid");
	$CI = &WLAN_Associate($mmh_client, 'UUT');
	&StartPing($mmh_client, 'UUT', 10);
	
	#ToDo need to check REF sta connected or no at end of test case
}


sub UAP_BSS_start_stop{

	if ($features_to_test{'UAP_START_STOP'} == 1){
		for($iter=0; $iter < $total_conn_disc; $iter++){
			&Dprint("Stopping Uap", 1);
			#&FC18_uap_bss_stop('UUT', $ApIntf);
																			
			&Uap_bss_stop('UUT', $ApIntf);
			&my_sleep(5);
			
			&Dprint("Starting Uap", 1);

			&Uap_bss_start('UUT', $ApIntf);
		}
		#&Uap_bss_stop('UUT', $ApIntf);
		#&Execute_Command('UUT', "cd /usr/local/automation; ./uaputl.exe -i $intf_uap0 sys_cfg_channel $channel");
		#&Execute_Command('UUT', "cd /usr/local/automation; ./uaputl.exe -i $intf_uap0 sys_cfg_ssid $ssid");
		#&Uap_bss_start('UUT', $ApIntf);
	}
}


sub REF_STA_CONN_DISC{
	if ($feature_test_hash{'REF_STA_CONN_DISC'} == 1){
		$CI = &WLAN_Associate($mmh_client, 'UUT');
		&StartPing($mmh_client,'UUT',10);
		&my_sleep(5);
		for($iter=0; $iter < $total_conn_disc; $iter++){
			&Dprint($DHOST,$DINF,"REF_STA_conn_disc iteration $iter",1);
			
		}
	}
}


sub Wlan_Ping{
	
	if (MoAP_features_to_test{'MoAP_ASSOC'} == 1){
		print "inside Wlan_Ping\n\n";
		&#Connect_WLAN;		
		#&Wlan_connect_disconnect;
		
		#$CI = &WLAN_Associate('UUT', $AP);
		#push (@wlan_assoc_time_arr, $wlan_assoc_time);
		&StartPing($mmh_client, 'UUT',$Wlan_Duration,1);
		print "Wlan_Ping is done\n\n";
	}	
}


sub Wlan_Traffic{
	
	if ($features_to_test{'MoAP_TRAFFIC'} == 1){
		&Dprint($DHOST,$DINF,"WLAN_Traffic between UUT & REF_STA",1);
		&WLAN_Traffic_Start('UUT',$mmh_client, $Traffic, $Proto, $Direct_.$StaIntf, $Iperf_Duration, PORT, "-CI $CIsta1");
		&my_sleep($Iperf_Duration+5);
		&WLAN_Traffic_Stop('UUT',$mmh_client, PORT);
		my $throughput_MMH_var = &Measure_WLAN_Throughput('UUT',$mmh_client, $Direct_.$StaIntf, PORT);	
		my $result_string =  "$_: $throughput_MMH_var \n";
		push (@throughput_MMH, $result_string);
		print "\ntput array: @throughput_MMH\n";
	}
	#&my_sleep($WLAN_Interval);
	
}


sub WLAN_Activity{
	
	#&FC18_uap_bss_start('UUT', $ApIntf);
	#&Uap_bss_start('UUT', $ ); # MasterTestLib.pl
	&Connect_UAP;
	&REF_STA_CONN_DISC;
	&UAP_BSS_start_stop;
	&Wlan_Ping;
	&Wlan_Traffic;
	
}


sub A2DP_Activity{
	&A2DP_Src_Stream_Start($Device2, $Song_Duration, 1);
    #A2DP Start recording
	&A2DP_Rec_Start($Device1, 10, 0);
	&my_sleep($Rec_Duration);

	#A2DP Stop Recording
	&A2DP_Rec_Stop($Device1);
	&A2DP_Src_Stream_Stop($Device2);

	#Mearsure A2DP Audio Quality
	$Gap = &A2DP_Measure_Audio_Quality();
	$THD = &A2DP_Measure_THD();

    &my_sleep($BT_Interval);
}


sub Connect_BT{
	
	#A2DP Connection
	&Enable_Page_Inq_Scan($Device2);
	&Inquiry($Device1, 0, 10, $Device2);
	&Pair_Dev($Device1, $Device2);
	&Accept_Pairing($Device2, $Device1);
	&A2DP_Snk_Connect($Device2, $Device1);
	if (uc($LinkType) eq "BCR_SLAVE") {
	    &BT_Role_Switch($Device1, $Device2, 10, 0, "0x01");
	}	
}


sub Disconnect_BT {
	
	#Disconnect A2DP
	&A2DP_Snk_Disconnect($Device2, $Device1);
	&Unpair_Dev($Device1, $Device2);
	&Unpair_Dev($Device2, $Device1);
}


########################################################################
sub Init_BT{
	
    &Register_Agent($Device1, $io_cap);
    &Register_Agent($Device2, $io_cap);
    &Set_Link_Mode($Device1, "MASTER");
    
}


sub Get_Result{
	if ($features_to_test{'MoAP_TRAFFIC'} == 1){
		&monitor_result('end_test', "WLAN_throughput : throughput_MMH , A2DP GAP: $Gap and THDs: $THD \n", @ARGV);
	}else{
		&monitor_result('end_test', "A2DP GAP: $Gap and THDs: $THD \n", @ARGV);
	}
}
