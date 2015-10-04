
##############################################################
# This Script has been generated by Ixia ScriptGen
#      Software Version : IxOS 6.90.1150.9 EA         
##############################################################


package require registry
proc GetEnvTcl { product } {       
    set productKey     "HKEY_LOCAL_MACHINE\\SOFTWARE\\Ixia Communications\\$product"
    if { [ catch {
            set versionKey     [ registry keys $productKey ]
    } err ] } {
            return ""
    }        
    
    set latestKey      [ lindex $versionKey end ]
    set mutliVKeyIndex [ lsearch $versionKey "Multiversion" ]
    if { $mutliVKeyIndex > 0 } {
       set latestKey   [ lindex $versionKey [ expr $mutliVKeyIndex - 2 ] ]
    }
    set installInfo    [ append productKey \\ $latestKey \\ InstallInfo ]            
    return             "[ registry get $installInfo  HOMEDIR ]/TclScripts/bin/ixiawish.tcl"   
}    

# IxOS is optional 
set ixPath [ GetEnvTcl IxOS ]
if { [file exists $ixPath] == 1 } {
    source [ GetEnvTcl IxOS ]
    package require IxTclHal
}

# Command Option Mode - Full (generate full configuration)


if {[isUNIX]} {
	if {[ixConnectToTclServer 172.16.174.137]} {
		errorMsg "Error connecting to Tcl Server 172.16.174.137 "
		return $::TCL_ERROR
	}
}

######### Chassis list - {172.16.174.137} #########

ixConnectToChassis   {172.16.174.137}

set portList {}



######### Chassis-172.16.174.137 #########

chassis get "172.16.174.137"
set chassis	  [chassis cget -id]

######### Card Type : Ixia Virtual Load Module ############

set card     1

######### Chassis-172.16.174.137 Card-1  Port-1 #########

set port     1

port setFactoryDefaults $chassis $card $port
if {[port set $chassis $card $port]} {
	errorMsg "Error calling port set $chassis $card $port"
	set retCode $::TCL_ERROR
}

lappend portList [list $chassis $card $port]

######### Card Type : Ixia Virtual Load Module ############

set card     2

######### Chassis-172.16.174.137 Card-2  Port-1 #########

set port     1

port setFactoryDefaults $chassis $card $port
if {[port set $chassis $card $port]} {
	errorMsg "Error calling port set $chassis $card $port"
	set retCode $::TCL_ERROR
}

lappend portList [list $chassis $card $port]

ixWritePortsToHardware portList
ixCheckLinkState portList



###################################################################
######### Generating streams for all the ports from above #########
###################################################################


######### Chassis-172.16.174.137 Card-1  Port-1 #########

chassis get "172.16.174.137"
set chassis	  [chassis cget -id]
set card     1
set port     1
streamRegion get $chassis $card $port
if {[streamRegion enableGenerateWarningList  $chassis $card $port 0]} {
	errorMsg "Error calling streamRegion enableGenerateWarningList  $chassis $card $port 0"
	set retCode $::TCL_ERROR
}

set streamId 1

if {[port resetStreamProtocolStack $chassis $card $port]} {
	errorMsg "Error calling port resetStreamProtocolStack $chassis $card $port"
	set retCode $::TCL_ERROR
}

#  Stream 1
stream setDefault 
stream config -name                               "MyStream"
stream config -enable                             true

set myvalue "01 00 5e 01 01 01 00 01 00 01 00 01 81 00 10 00 08 00 45 00 00 1c 00 00 00 00 01 02 b3 10 ae cb 76 02 e1 01 01 01 16 64 07 99 e1 01 01 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
set pkt_len [llength $myvalue]
stream config -framesize [expr $pkt_len + 4]
stream config -frameSizeType sizeFixed

if { $pkt_len < 60 } {
    set pkt_len 60
}
if { $pkt_len > [llength $myvalue] } {
    set patch_value [string repeat "00 " [expr $pkt_len - [llength $myvalue]]]
    set myvalue [concat $myvalue $patch_value]
    puts "$myvalue"
}

if { [llength $myvalue] >= 12} {
    stream config -da [lrange $myvalue 0 5]
    stream config -sa [lrange $myvalue 6 11]
} elseif { [llength $myvalue] > 6 } {
    stream config -da [lrange $myvalue 0 5]
    for {set i 0} {$i < [llength $myvalue] - 7} {incr i} {
        set Dstmac [lreplace $Dstmac $i $i [lindex $myvalue $i]]
    }
    stream config -sa $Dstmac
} else {
    for {set i 0} { $i < [llength $myvalue]} {incr i} {
        set Srcmac [lreplace $Srcmac $i $i [lindex $myvalue $i]]
    }
    stream config -da $Srcmac
}

stream config -patternType repeat
stream config -dataPattern userpattern
stream config -frameType "08 00"
if { [llength $myvalue] >= 12 } {
    if { [lindex $myvalue 12] == "81" && [lindex $myvalue 13] == "00"} {
        set vlanOpts    0x[lindex $myvalue 14][lindex $myvalue 15]
        vlan setDefault 
        vlan config -vlanID                 [expr $vlanOpts & 0x0FFF]
        vlan config -userPriority           [expr $vlanOpts >> 13]
        if {[vlan set $chassis $card $port]} {
                errorMsg "Error calling vlan set $chassis $card $port"
                set retCode $::TCL_ERROR
        }
        stream config -frameType "[lindex $myvalue 16] [lindex $myvalue 17]"
        stream config -pattern [lrange $myvalue 16 end]
    } else {
        stream config -frameType "[lindex $myvalue 12] [lindex $myvalue 13]"
        stream config -pattern [lrange $myvalue 12 end]
    }
} 

protocol setDefault 
protocol config -name                               ipV4
protocol config -appName                            noType
protocol config -ethernetType                       ethernetII
protocol config -enable802dot1qTag                  vlanSingle

if {[port isValidFeature $chassis $card $port $::portFeatureTableUdf]} { 
	tableUdf setDefault
	tableUdf clearColumns
	if {[tableUdf set $chassis $card $port]} {
		errorMsg "Error calling tableUdf set $chassis $card $port"
		set retCode $::TCL_ERROR
	}
}

if {[port isValidFeature $chassis $card $port $::portFeatureRandomFrameSizeWeightedPair]} { 
	weightedRandomFramesize setDefault
	if {[weightedRandomFramesize set $chassis $card $port]} {
		errorMsg "Error calling weightedRandomFramesize set $chassis $card $port"
		set retCode $::TCL_ERROR
	}

}

if {[stream set $chassis $card $port $streamId]} {
	errorMsg "Error calling stream set $chassis $card $port $streamId"
	set retCode $::TCL_ERROR
}

incr streamId
streamRegion generateWarningList $chassis $card $port

######### Chassis-172.16.174.137 Card-2  Port-1 #########

set card     2
set port     1
streamRegion get $chassis $card $port
if {[streamRegion enableGenerateWarningList  $chassis $card $port 0]} {
	errorMsg "Error calling streamRegion enableGenerateWarningList  $chassis $card $port 0"
	set retCode $::TCL_ERROR
}

if {[port reset $chassis $card $port]} {
	errorMsg "Error calling port reset $chassis $card $port"
	set retCode $::TCL_ERROR
}

streamRegion generateWarningList $chassis $card $port
ixWriteConfigToHardware portList -noProtocolServer

puts $portList
