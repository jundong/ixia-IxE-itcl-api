#!/bin/sh
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

set userName {IxiaTclUser}
set hostname {172.16.174.137}
set retCode $::TCL_OK

ixLogin $userName
ixPuts "\nUser logged in as: $userName"

set recCode [ixConnectToChassis $hostname]
if {$retCode != $::TCL_OK} {
    return $retCode
}

set chasId [ixGetChassisID $hostname]
if {$retCode != $::TCL_OK} {
    return $retCode
}

if { $chasId == -1 } {
    chassis get $hostname
    set chasId	  [chassis cget -id]
}
set card1 1
set port1 1

set card2 2
set port2 1

set portList {}
lappend portList [list $chasId $card1 $port1]
lappend portList [list $chasId $card2 $port2]

ixWritePortsToHardware portList
ixCheckLinkState portList

if { [ixTakeOwnership $portList] } {
    return $::TCL_ERROR
}

proc clearOwnershipAndLogout {} {
    global portList
    ixClearOwnership $portList
    ixLogout
    cleanUp
}

ixPuts "\nIxTclHAL Version :[version cget -ixTclHALVersion]"
ixPuts "Product version :[version cget -productVersion]"
ixPuts "Installed version :[version cget -installVersion]\n"

proc SetCustomPkt {{myValue 0} {pkt_len -1}} {
    global portList
    puts "Set custom packet of $::_chassis $::_card $::_port..."
    set retVal $::TCL_OK
    puts "SetCustomPkt: $myValue  $pkt_len"    
    set myvalue $myValue
       
    if {[llength $pkt_len] == 1} {
        if [string match $pkt_len "-1"] {
            set pkt_len [llength $myvalue]
        }
        stream config -framesize [expr $pkt_len + 4]
        stream config -frameSizeType sizeFixed
    } else {
        stream config -framesize 318
        stream config -frameSizeType sizeRandom
        stream config -frameSizeMIN [lindex $pkt_len 0]
        stream config -frameSizeMAX [lindex $pkt_len 1]
    }
    
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
        stream config -pattern [lrange $myvalue 12 end]
    } 
           
    if [catch {stream set $::_chassis $::_card $::_port 1}] {
        error "Can't set stream $::_chassis $::_card $::_port 1"
        set retVal $::TCL_ERROR
    }

    ixWriteConfigToHardware portList -noProtocolServer
    
    return $retVal
}

set ::_chassis $chasId
set ::_card $card1
set ::_port $port1

SetCustomPkt "01 00 5e 01 01 01 00 01 00 01 00 01 81 00 10 00 08 00 45 00 00 1c 00 00 00 00 01 02 b3 10 ae cb 76 02 e1 01 01 01 16 64 07 99 e1 01 01 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00"