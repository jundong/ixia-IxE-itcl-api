proc IxStartPacketGroups {Chas Card Port} {
    configPacketGroup $Chas $Card $Port
    
    lappend portList [list $Chas $Card $Port]
    #--before we start packetgroups we should stop it first
    ixStopPacketGroups portList
    #--start packetgroups-based stats
    ixStartPacketGroups portList
}

proc IxStopPacketGroups {Chas Card Port} {
    lappend portList [list $Chas $Card $Port]
    
    #--stop packetgroups-based stats
    ixStopPacketGroups portList
}

proc configPacketGroup {Chas Card Port} {
    lappend portList [list $Chas $Card $Port]
    
    port get $Chas $Card $Port
    port config -receiveMode  [expr $::portCapture|$::portRxSequenceChecking|$::portRxModeWidePacketGroup|$::portRxModePerFlowErrorStats]
    
    #-- configure stream as well as tx/rx mode
    set streamid   1
    set groupId    $streamid

    while {[stream get $Chas $Card $Port $streamid] != 1} {
        stream config -enableTimestamp  true
        stream config -name  _${Card}_${Port}_${streamid}
        if [stream set $Chas $Card $Port $streamid] {
            puts "Unable to set streams to IxHal!"
            set retVal 1
        }
        
        set groupId [expr $Card * 100 + $Port * 10 + $streamid]
        udf setDefault
        packetGroup setDefault
        packetGroup config -groupId $groupId
        packetGroup config -enableGroupIdMask true
        packetGroup config -enableInsertPgid true
        packetGroup config -groupIdMask 61440
        packetGroup config -insertSignature true
        
        if {[packetGroup setTx $Chas $Card $Port $streamid ]} {
            puts "Error calling packetGroup setTx $Chas $Card $Port $streamid"
        } 
        
        #autoDetectInstrumentation setDefault 
        #autoDetectInstrumentation config -enableTxAutomaticInstrumentation   true
        #if {[ eval autoDetectInstrumentation setTx $Chas $Card $Port $streamid ]} {
        #    puts "Error calling autoDetectInstrumentation on $Chas $Card $Port"
        #}
        #
        incr streamid
    }
    
    #ixSetAutoDetectInstrumentationMode portList
    if [ixWritePortsToHardware portList -noProtocolServer] {
        IxPuts -red "Can't write config to $Chas $Card $Port"
        set retVal 1   
    } 
    if [ixWriteConfigToHardware portList -noProtocolServer] {
        IxPuts -red "Can't write config to $Chas $Card $Port"
        set retVal 1  
    }
       
    if { [ ixCheckLinkState portList ] } {
        puts "Link on one or more ports is down"
        return 1                            
    }       
}

#!!================================================================
#过 程 名：     SmbStreamStats 
#程 序 包：     IXIA
#功能类别：     
#过程描述：     clear port streams
#用法：         
#示例：         
#               
#参数说明：     
#               Chas:     Ixia的hub号
#               Card:     Ixia接口卡所在的槽号
#               Port:     Ixia接口卡的端口号
#返 回 值：     成功返回0,失败返回1
#作    者：     Judo Xu
#生成日期：     2016-4-17
#修改纪录：     
#!!================================================================
proc SmbStreamStats  { Chas Card Port } {
    set streamid   1
    while {[stream get $Chas $Card $Port $streamid] != 1} {
        set groupId [expr $Card * 100 + $Port * 10 + $streamid]
        set rxChas ""
        set rxCard ""
        set rxPort ""
        foreach portList $m_portList {
            set rxChas [lindex $portList 0]
            set rxCard [lindex $portList 1]
            set rxPort [lindex $portList 2]
            #Don't use port itself as the receive side
            if {$rxChas == $Chas && $rxCard == $Card && $rxPort == Port} {
                continue
            }
            if {[packetGroupStats get $rxChas $rxCard $rxPort $groupId $groupId] != 1} {
                set rx [ packetGroupStats cget -totalFrames ]
                Deputs "stream $i rx: $rx"
                if {[streamTransmitStats get $Chas $Card $Port $streamid $streamid] != 1} {
                    set tx [streamTransmitStats cget -framesSent]
                    Deputs "stream $i tx: $tx"
                }
                set streamBasedFramesLoss [ expr $tx - $rx ]
               
                set result($i,txFrame)   $tx
                set result($i,rxFrame)   $rx
                set result($i,loss)      $streamBasedFramesLoss
                incr totalLoss           $streamBasedFramesLoss
                if { $streamBasedFramesLoss } {
                    set pass 0 
                }
                
                break
            } else {
                continue
            }
        }
    }
    return 0
}

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

####################################################################
# CSMBPortETH::SetIGMPv1Group -Group 225.0.0.1 -VlanID 100 -Mode JOIN -Count 100 -Step 2
################################################################################################
proc SetIGMPv1Group { Group  VlanID Mode Count Step SrcIP SrcMac} {
    set retVal 1
    set SrcMac 9999-9999-9999
    set SrcIP 1.1.1.1
    set Group $Group
    set VlanID $VlanID
    set Priority 0
    set Mode $Mode
    set Count $Count
    set Step $Step
    
    protocol config -ethernetType ethernetII
    protocol config -name ipV4
    #ip setDefault
    if { [ ip get 1 1 1 ] } {
        errorMsg "Error calling ip get $::chassis $::card $::port"
        set retVal $::TCL_ERROR  
    }
    ip config -ipProtocol ipV4ProtocolIgmp
    
    #stream setDefault
    if { [ stream get 1 1 1 1 ] } {
        errorMsg "Error calling stream get $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }
    
    #SrcMac,不指定的情况下使用端口MAC地址,不做任何处理
    #if {$SrcMac != "0000-0000-0001"} {
    #    set SrcMac [::ipaddress::format_mac_address $SrcMac 6 ":"]
    #    stream config -sa $SrcMac
    #    
    #    if { [ stream set $::chassis $::card $::port 1 ] } {
    #        errorMsg "Error calling stream set $::chassis $::card $::port"
    #        set retVal $::TCL_ERROR 
    #    }
    #}
    #
    #SrcIP,不指定的情况下使用端口IP地址,不做任何处理
    if {$SrcIP != "0.0.0.0"} {
        ip config -sourceIpAddr $SrcIP
    }
    if {[ip set 1 1 1]} {
        errorMsg "Error calling ip set $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }
    
    if { $VlanID != 0 || $Priority != 0 } {
        protocol config -enable802dot1qTag vlanSingle
        vlan setDefault
        if { [ vlan get $::chassis $::card $::port ] } {
            errorMsg "Error calling vlan get $::chassis $::card $::port"
            set retVal $::TCL_ERROR 
        }
        
        vlan config -vlanID $VlanID
        vlan config -userPriority $Priority
        
        if {[vlan set 1 1 1]} {
            errorMsg "Error calling vlan set $::chassis $::card $::port"
            set retVal $::TCL_ERROR
        }
    }
    
    igmp setDefault
    if { [ igmp get 1 1 1 ] } {
        errorMsg "Error calling stream get $::chassis $::card $::port"
        set retVal $::TCL_ERROR  
    }
    if { [ string tolower $Mode ] == "join" } {
        igmp config -type membershipReport1
    }
    igmp config -version        igmpVersion1
    igmp config -groupIpAddress $Group
    igmp config -mode           igmpIncrement
    igmp config -repeatCount    $Count 
    #igmp config -sourceIpAddressList                ""
    if {[igmp set 1 1 1]} {
        errorMsg "Error calling igmp set $::chassis $::card $::port"
        set retVal $::TCL_ERROR
    }
    if {[string match [config_port config] $::TCL_ERROR]} {
        set retVal $::TCL_ERROR
    }                                        
    return $retVal
}

####################################################################
# CSMBPortETH::SetIGMPv2Group 225.0.0.1 100 JOIN 100 2 1.1.1.1 9999-9999-9999
################################################################################################
proc SetIGMPv2Group { Group  VlanID Mode Count Step SrcIP SrcMac} {
    set retVal 1
    set SrcMac $SrcMac
    set SrcIP $SrcIP
    set Group $Group
    set VlanID $VlanID
    set Priority 0
    set Mode $Mode
    set Count $Count
    set Step $Step
    
    protocol config -ethernetType ethernetII
    protocol config -name ipV4
    #ip setDefault
    if { [ ip get $::chassis $::card $::port ] } {
        errorMsg "Error calling ip get $::chassis $::card $::port"
        set retVal $::CIxia::gIxia_ERR  
    }
    ip config -ipProtocol ipV4ProtocolIgmp
    
    #stream setDefault
    if { [ stream get $::chassis $::card $::port 1 ] } {
        errorMsg "Error calling stream get $::chassis $::card $::port"
        set retVal $::CIxia::gIxia_ERR  
    }
    
    #SrcMac,不指定的情况下使用端口MAC地址,不做任何处理
    #if {$SrcMac != "0000-0000-0001"} {
    #    set SrcMac [::ipaddress::format_mac_address $SrcMac 6 ":"]
    #    stream config -sa $SrcMac
    #    
    #    if { [ stream set $::chassis $::card $::port 1 ] } {
    #        errorMsg "Error calling stream set $::chassis $::card $::port"
    #        set retVal $::CIxia::gIxia_ERR  
    #    }
    #}
    
    #SrcIP,不指定的情况下使用端口IP地址,不做任何处理
    if {$SrcIP != "0.0.0.0"} {
        ip config -sourceIpAddr $SrcIP
    }
    if {[ip set $::chassis $::card $::port]} {
        errorMsg "Error calling ip set $::chassis $::card $::port"
        set retVal $::CIxia::gIxia_ERR 
    }
    
    if { $VlanID != 0 || $Priority != 0 } {
        protocol config -enable802dot1qTag vlanSingle
        vlan setDefault
        if { [ vlan get $::chassis $::card $::port ] } {
            errorMsg "Error calling vlan get $::chassis $::card $::port"
            set retVal $::CIxia::gIxia_ERR  
        }
        
        vlan config -vlanID $VlanID
        vlan config -userPriority $Priority
        
        if {[vlan set $::chassis $::card $::port]} {
            errorMsg "Error calling vlan set $::chassis $::card $::port"
            set retCode $::CIxia::gIxia_ERR
        }
    }
    
    igmp setDefault
    if { [ igmp get $::chassis $::card $::port ] } {
        errorMsg "Error calling stream get $::chassis $::card $::port"
        set retVal $::CIxia::gIxia_ERR  
    }
    if { [ string tolower $Mode ] == "join" } {
        igmp config -type membershipReport2
    } else {
        igmp config -type leaveGroup
    }
    igmp config -version        igmpVersion2
    igmp config -groupIpAddress $Group
    igmp config -mode           igmpIncrement
    igmp config -repeatCount    $Count 
    #igmp config -sourceIpAddressList                ""
    if {[igmp set $::chassis $::card $::port]} {
        errorMsg "Error calling igmp set $::chassis $::card $::port"
        set retVal $::CIxia::gIxia_ERR  
    }
    if {[string match [config_port config] $::TCL_ERROR]} {
        set retVal $::TCL_ERROR
    }                                          
    return $retVal
}