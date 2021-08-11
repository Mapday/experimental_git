# ##############################################################################
#		© 2021 NXP Confidential. All rights reserved
#
# File: 	BLE_ADV.pl
# Author: 	GES Bangalore
# Date: 	08 APRIL 2021
#
# Purpose: Multi Profile Coex with BLE_ADV + WLAN Traffic on STA.
#
# Type: Script file
# ##############################################################################

#Init Section

require('libs/Master_TestLib.pl');

use threads;
use threads::shared;

my $A2DP_start_time;
my $A2DP_total_time;
my $AP;
my $AP_BACKEND_CMD;
my $Activity_Flag;
my $ADV_start_time:shared;
my $assoc_status;
my $ADV_total_time:shared;
my $BT_Duration;
my $BT_Interval;
my $CI;
my $client_num;
my $conn_flag;
my $conn_status_flag;
my $Device1;
my $Device2;
my $Device3;
my $GAP;
my $Direction;
my $Init_flag;
my $Iperf_Duration;
my $io_cap;
my $LinkType;
my $mmh_client;
my $NUM_OF_A2DP_CONN;
my $Proto;
my $Song_Duration;
my $THD;
my $THDs;
my $test_ap;
my $Test_Duration;
my $Taffic;
my $wlan_assoc_time;
my $WLAN_Interval;
my $WLAN_start_time:shared;
my $WLAN_total_time:shared;

my @activity_threads;
my @thread_array:shared;
my @wlan_assoc_time_arr;

$A2DP_total_time = 0;
$ADV_total_time = 0;
$WLAN_total_time = 0;

&Check_Cmd_Arg();

@DEVICE = ('UUT');

if($test_ap =~ /^EXT_AP(\d+)/i) {
	push(@DEVICE, $test_ap);
	$client_num     = $1;
	$AP             = "EXT_AP$1";
	$AP_BACKEND_CMD = "AP_BACKEND$1";
}elsif ($test_ap =~ /^MMHAP(\d+)/i) {
	push(@DEVICE, $test_ap);
	$client_num     = $1;
	$AP             = "MMHAP$1";
	$AP_BACKEND_CMD = "MMHAP$1";
}

push(@DEVICE, $mmh_client);

# Initialization.
&Initialize('MoAP_BLE_ADV_A2DP_Snk_M', 'MoAP');

my $StaIntf = $TBDEVICE{$TBDEVICE{"UUT"}."_$sta_intf"};
my $ApIntf  = $TBDEVICE{$TBDEVICE{"UUT"}."_$mmh_intf"};

&Init_BT;

# Connection
if($conn_flag == 'WLAN') {
	&Connect_WLAN;
	&Connect_BT;
}
elsif($conn_flag == 'BT') {
    &Connect_BT;
    &Connect_WLAN;
}

&BT_Traffic_start;

#A2DP Connection and Disconnection
for(my $iter = 1;$iter <= $NUM_OF_A2DP_CONN; $iter++) {
    &A2DP_Snk_Disconnect($Device2, $Device1);
    &my_sleep(2);
    &A2DP_Snk_Connect($Device2, $Device1);

    &my_sleep(2);

}

# Threads for BT and WLAN Activity.
$A2DP_start_time = time;
$ADV_start_time = time;
$WLAN_Start_Time = time;

my $WLAN_thread;
my $ADV_thread;
my $A2DP_thread;

if($Activity_Flag == 'WLAN') {
    $WLAN_thread = threads->create(\&WLAN_Activity);
    $ADV_thread = threads->create(\&ADV_Activity);
    $A2DP_thread   = threads->create(\&A2DP_Activity);
} else {
    $ADV_thread   = threads->create(\&ADV_Activity);
    $A2DP_thread   = threads->create(\&A2DP_Activity);
    $WLAN_thread = threads->create(\&WLAN_Activity);
}

push (@activity_threads, $WLAN_thread);
push (@activity_threads, $ADV_thread);
push (@activity_threads, $A2DP_thread);

foreach (@activity_threads){$_ -> join()}

########################################################################

&monitor_result('end_test', "WLAN Throughput :$throughput_STA  and BT Total Gaps: $GAP and THD: $THD");

########################################################################
# END OF SCRIPT
########################################################################

########################################################################

sub Check_Cmd_Arg {
	my $num_args = $#ARGV + 1;
	if ($num_args < 7) {
		&Dprint($DHOST, $DINF, "Missing Arguments", 1);
		&Dprint($DHOST, $DINF, "Usage:\n perl BLE_ADV_BLE_SCAN.pl <Device1> <Device2> <Device3> ", 1);
		&Dprint($DHOST, $DINF, "example usage :perl BLE_ADV_BLE_SCAN.pl UUT REF1 REF2 \n", 1);
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
            } elsif ($_ =~ m/^DEVICE3#(.*)$/) {
	        # Device3 (REF2)
            $Device3 = $1;
	    } elsif ($_ =~ m/^A2DP_FLAG#(.*)$/){
			# SOURCE/SINK
			$A2DP_Flag = $1;
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
			# DisplayYesNo
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
	}elsif($_  =~ m/^MMH_CLIENT#(.*)$/){
		#MMH CLIENT
		$mmh_client = $1;
	}elsif($_  =~ m/^TEST_AP#(.*)$/){
		#TEST AP
		$test_ap = $1;
	}elsif($_  =~ m/^STA_INTERFACE#(.*)$/){
		#STA INTERFACE
		$sta_intf = $1;
	}elsif($_  =~ m/^MMH_INTERFACE#(.*)$/){
		#MMH INTERFACE
		$mmh_intf = $1;
	}elsif($_ =~ m/TOTAL_CONN_DISC#(.*)$/){
		$total_conn_disc = $1;
	}elsif ($_ =~ m/^EXT_AP(.*)#SSID_(.*)#(.*)/){
		$SSID = $3;
	}elsif ($_ =~ m/^MMHAP(.*)#SSID_(.*)#(.*)/){
		$SSID = $3;
	}
}

}

sub WLAN_Activity{
	&Dprint($DHOST, $DINF, "Inside wlan_Activity\n");
	
	&Wlan_connect_disconnect;

	&Wlan_Scan_Traffic_thread;
}

sub A2DP_Activity{
	while ($A2DP_total_time < $Test_Duration) {
		#A2DP Start recording
		&A2DP_Rec_Start($Device1, 10, 0);
		&my_sleep($Rec_Duration);

		#A2DP Stop Recording
		&A2DP_Rec_Stop($Device1);

		#Mearsure A2DP Audio Quality
		$Gap = &A2DP_Measure_Audio_Quality();
		$THD = &A2DP_Measure_THD();

        push (@Gaps, $Gap);
		push (@THDs, $THD);

		&my_sleep($BT_Interval);

	        $A2DP_total_time += (time - $A2DP_start_time);
	        $A2DP_start_time = time;
	}	
}

########################################################################
sub ADV_Activity{
	while ($ADV_total_time < $Test_Duration) {
		&Start_LE_advertise($Device1, $BT_Duration, 1);
		&LE_Scan($Device3, $Device1, $BT_Duration, 0);
		&my_sleep(2);

		&my_sleep($BT_Interval);
		$ADV_total_time += (time - $ADV_start_time);
		$ADV_start_time = time;
		&Manage_Iteration_Result($Test_Duration, undef,$ADV_total_time);

    }
}
########################################################################
sub BT_Traffic_start{
	#A2DP Stream start 
	&A2DP_Src_Stream_Start($Device2, $Song_Duration, 1);	
}

sub BT_Traffic_stop{
	#A2DP Stream stop 
	&A2DP_Src_Stream_Stop($Device2);	
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

sub Init_BT{
	&Register_Agent($Device1, $io_cap);
	&Register_Agent($Device2, $io_cap);
	&Register_Agent($Device3, $io_cap);
	&Set_Link_Mode($Device1, "MASTER");
}


sub Wlan_Scan_Traffic_thread{
	my $scan_thread = threads->create(\&Wlan_Scan);
	my $traffic_thread = threads->create(\&Wlan_Traffic);
	
	push(@thread_array, $scan_thread);
	push(@thread_array, $traffic_thread);
	
	foreach(@thread_array) { $_ -> join()}
}


sub Connect_WLAN {
	
	#&Execute_Command('UUT', $StaIntf, 'deauth', 'DEAUTH');
	$CI = &WLAN_Associate('UUT', $AP, "-STA_INTF $StaIntf");
	&Dprint($DHOST, $DINF, "Association time in : $wlan_assoc_time seconds", 1);
	push (@wlan_assoc_time_arr, $wlan_assoc_time);
	&StartPing($AP_BACKEND_CMD, 'UUT',10,1);
	
}

sub Connect_UAP {
	
	$CI = &WLAN_Associate($mmh_client, 'UUT');
	&StartPing($mmh_client,'UUT',10);
	#ToDo need to check REF sta connected or no at end of test case
}

sub Wlan_Scan{
	print "inside Wlan_Scan\n\n";
	while ($STA_Total_Time < $Wlan_Duration) {
		print "inside wlan_scan and current secs are : $STA_Total_Time\n\n";
		my $scan_status = &WLAN_sta_scan('UUT', $StaIntf, $SSID);
		#push (@wlan_scan_time_arr, $sta_scan_time);
		#push (@numOfAP_arr, $numOfAP);
		$STA_Total_Time +=  (time - $STA_Start_Time);
		$STA_Start_Time = time;
		&my_sleep(5);
	}
	print "Wlan_Scan is done at $STA_Total_Time\n\n";
}



sub Wlan_Traffic{
	
	&Dprint($DHOST,$DINF,"WLan_Traffic between UUT & AP_BACKEND",1);
	&WLAN_Traffic_Start('UUT',$AP_BACKEND_CMD, $Traffic, $Proto, $Direct_.$StaIntf, $Iperf_Duration, PORT, "-CI $CIsta1");
	&my_sleep($Iperf_Duration+5);
	&WLAN_Traffic_Stop('UUT',$AP_BACKEND_CMD, PORT);
	my $throughput_STA_var = &Measure_WLAN_Throughput('UUT',$AP_BACKEND_CMD, $Direct_.$StaIntf, PORT);	
	my $tmpResStrSTA = "STA::".$Proto."::".$Direct_.$StaIntf."::".$CIsta."::"."$throughput_STA Mbps";
	my $ResultString = "Throughput: $StaIntf=$throughput_STA Mbps";
	push(@throughput_STA, $tmpResStrSTA);

	#&my_sleep($WLAN_Interval);
}


sub Wlan_connect_disconnect{
	for(my $iter=0; $iter < $total_conn_disc; $iter++){
		&Dprint($DHOST,$DINF,"Wlan_connect_disconnect iteration $iter",1);
		&Execute_Command('UUT', $StaIntf, 'deauth', 'DEAUTH');
		&my_sleep(3);
		$CI = &WLAN_Associate('UUT', $AP, "-STA_INTF $StaIntf");
		&my_sleep(2);
	}
}
