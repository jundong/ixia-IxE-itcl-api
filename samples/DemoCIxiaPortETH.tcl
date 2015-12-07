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

proc SetTxSpeed {Utilization {Mode "Uti"}} {
    set utilization $Utilization
    set _uti $Utilization
    set _mode $Mode

    set retVal 0
    regsub {[%]} $utilization {} utilization
    set streamid   1

    while {[stream get $::chassis $::card $::port $streamid] != 1} {
        if { $Mode == "Uti" } {
            stream config -rateMode usePercentRate
            stream config -percentPacketRate $utilization
        } else {
            stream config -rateMode streamRateModeFps
            stream config -fpsRate $utilization
        }
    
        if {[string match [config_stream $streamid] $::TCL_ERROR]} {
            set retVal $::TCL_ERROR
        }
        
        incr streamid
    }
    
    if {[string match [config_port write] $::TCL_ERROR]} {
        set retVal $::TCL_ERROR
    }

    return $retVal
}

proc SetPortAddress { macaddress ipaddress  netmask replyallarp } {
    set retVal $::TCL_ERROR
    
    #set macaddress 00:00:00:00:11:11
    #set ipaddress 0.0.0.0 
    #set netmask 255.255.255.0 
    #set gateway 0.0.0.0 
    #set replyallarp 0
    set macaddress $macaddress
    set ipaddress $ipaddress 
    set netmask $netmask
    set gateway 0.0.0.0 
    set replyallarp $replyallarp
    set vlan 0
    set flag 0

    #Start to format the macaddress and IP netmask
    if {[string length $netmask] > 2} {
        set netmask [split $netmask \.]
        for {set j 0 } { $j < [llength $netmask]} {incr j} {
            set mod [expr [lindex $netmask $j] % 255]
            if {$mod} {
                set j [expr $j * 8]
                set tag 128 
                while {[expr $mod % $tag]} {
                    set tag [expr $tag / 2]
                    set j [expr $j + 1]
                }
                set netmask [expr $j + 1]
                break
            }        
        }
    }
    #End of formatting macaddress and IP netmask
    #port setFactoryDefaults $::chassis $::card $::port
    #protocol setDefault
    #protocol config -ethernetType ethernetII
    
    #Start to configure IP / Mac / gateway / autoArp /arpreply to the target port    
    interfaceTable select $::chassis $::card $::port
    interfaceTable clearAllInterfaces
    interfaceTable config -enableAutoArp true
    
    if {[interfaceTable set]} {
        error "Error calling interfaceTable set"
        set retVal $::TCL_ERROR
    }
    
    interfaceIpV4 setDefault
    interfaceIpV4 config -ipAddress $ipaddress
    interfaceIpV4 config -gatewayIpAddress $gateway
    interfaceIpV4 config -maskWidth $netmask

    if [interfaceEntry addItem addressTypeIpV4] {
        error "Error interfaceEntry addItem addressTypeIpV4 on $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }
    interfaceEntry setDefault
    interfaceEntry config -enable true
    interfaceEntry config -description "_port $ipaddress\:01 Interface-1"
    interfaceEntry config -macAddress $macaddress
    if {$vlan} { set flag true}
    interfaceEntry config -enableVlan                         $flag
    interfaceEntry config -vlanId                             $vlan
    interfaceEntry config -vlanPriority                       0
    interfaceEntry config -vlanTPID                           0x8100
    
    if [interfaceTable addInterface] {
        error "Error interfaceTable addInterface on $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }
    
    if [interfaceTable write] {
        error "Error interfaceTable write to $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }
    
    protocolServer setDefault
    protocolServer config -enableArpResponse $replyallarp
    protocolServer config -enablePingResponse   true
    if { [protocolServer set $::chassis $::card $::port] } {
        error "Error setting protocolServer on $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }
    if { [protocolServer write $::chassis $::card $::port] } {
        error "Error writting protocolServer on $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }

    #End of configuring  IP / Mac / gateway / autoArp / arpreply

    return $retVal
}