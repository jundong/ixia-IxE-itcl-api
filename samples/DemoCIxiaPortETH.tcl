proc SetCustomPkt {{myValue 0} {pkt_len -1}} {
    puts "SetCustomPkt: $myValue  $pkt_len"    
    set myvalue $myValue
    
    protocol setDefault 
    protocol config -name mac
    protocol config -appName       noType
    protocol config -ethernetType  ethernetII

    stream setDefault        
    stream config -enable true
    
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
    stream config -frameType "86 DD"
    if { [llength $myvalue] >= 12 } {
        if { [lindex $myvalue 12] == "81" && [lindex $myvalue 13] == "00"} {
            set vlanOpts  0x[lindex $myvalue 14][lindex $myvalue 15]
            protocol config -enable802dot1qTag vlanSingle
            vlan setDefault
            # 12 bits Vlan ID
            vlan config -vlanID                 [expr $vlanOpts & 0x0FFF]
            # 3 bits Priority
            vlan config -userPriority           [expr [expr $vlanOpts >> 13] & 0x0007]
            vlan config -cfi                    [expr [expr $vlanOpts >> 12] & 0x0001]
            if {[vlan set $::chassis $::card $::port]} {
                errorMsg "Error calling vlan set $::chassis $::card $::port"
                set retCode $::TCL_ERROR
            }
            
            stream config -frameType "[lindex $myvalue 16] [lindex $myvalue 17]"
            stream config -pattern [lrange $myvalue 18 end]
        } else {
            stream config -frameType "[lindex $myvalue 12] [lindex $myvalue 13]"
            stream config -pattern [lrange $myvalue 14 end]
        }
    }      
    
    if {[string match [config_stream 1] $::TCL_ERROR]} {
        set retVal $::TCL_ERROR
        set retVal 0
    }

    if {[string match [config_port config] $::TCL_ERROR]} {
        set retVal $::TCL_ERROR
        set retVal 0
    }

    return 0
}

###########################################################################################
#@@Proc
#Name: config_port
#Desc: Config to port
#Args:
#    -ConfigType [write | config] write to port or config to port, config default
#       -NoProtServ args of ixWritePortsToHardware -noProtocolServer, ture or false(default),
#Usage: config_port -ConfigType write
###########################################################################################
proc config_port { configtype } {
    puts "proc config_port"
    switch [string toupper $configtype] {
        WRITE {
            set command "ixWritePortsToHardware"
        }
        CONFIG -
        default {
            set command "ixWriteConfigToHardware"
        }
    }
       if [catch {eval $command portList}] {
        error "Can't write config to $::chassis $::card $::port"
        set retVal $::TCL_ERROR   
       }    
    
    return 0
}

###########################################################################################
#@@Proc
#Name: config_stream
#Desc: Config to port
#Args:
#       -StreamId streamid default 1
#Usage: config_stream -StreamId 1
###########################################################################################
proc config_stream { streamId } {
    puts "proc config_stream"
    set streamid $streamId   
    puts "config_stream $streamid"
    if [catch {stream set $::chassis $::card $::port $streamid}] {
        error "Can't set stream $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }

    return 0
}

###########################################################################################
#@@Proc
#Name: DeleteAllStream
#Desc: to delete all streams of the target port
#Args: no
#Usage: port1 DeleteAllStream
###########################################################################################
proc DeleteAllStream {} {
    puts "Delete all streams of $::chassis $::card $::port..."
    set num 1

    while { [stream get $::chassis $::card $::port $num ] != 1 } {
        incr num
    }

    for { set i 1 } { $i < $num} { incr i} {
        if [stream remove $::chassis $::card $::port $i] {
            error "Error remove the stream of $::chassis $::card $::port"
            set retVal $::TCL_ERROR
        } 
    }
    set _streamid 1
    
    if {[string match [config_port config] $::TCL_ERROR]} {
        set retVal $::TCL_ERROR
    }
    
    return 0 
}