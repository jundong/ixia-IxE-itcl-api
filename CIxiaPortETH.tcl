##############################################################
# Script Name     :   Port.tcl
# Class Name     :   CRouteTesterPort
# Description    :   Port Class, support port traffic operations.
# Related Script :   
# 修   改        :   jingbo 04512 2008.01.14
#                    1.  继承基类CTestInstrumentPort
#                    2.  修改构造函数constructor
#############################################################

#############################################################
# Modify history:
#############################################################
# 1.Create    2007-06-19        lhe@sigma-rt.com
#
#############################################################

#package require Itcl
package require cmdline
package require IxTclHal

package require Smartbits
package require packet
package require ixia_utilities
#引入基类
package require TestInstrument 1.0

package provide Ixia 1.0

#@@All Proc
#Ret: ::CIxia::gIxia_OK - if no error(s)
#     ferr - if error(s) occured
#Usage: CRouteTesterPort port1 {1 2 1}
::itcl::class CIxiaPortETH {
    private variable _chassis ""
    private variable _card ""
    private variable _port ""
    private variable _media ""
    private variable _streamid ""
    private variable portList ""

    #    constructor {lst} {
    #     set lst [lindex $lst 0]
    #        set _chassis [lindex $lst 0]
    #        set _card [lindex $lst 1]
    #        set _port [lindex $lst 2]
    #     set _streamid 1
    #        set portList [ list [ list $_chassis $_card $_port ] ]
    #
    #    Reset
    #    }

    #继承父类 
    inherit CTestInstrumentPort
    #构造函数
    constructor { obj port portObj } { CTestInstrumentPort::constructor $obj $port $portObj } {
        puts "CIxiaPortETH.CTR"
        set port [lindex $port 0]
        set _chassis [lindex $port 0]
        set _card [lindex $port 1]
        set _port [lindex $port 2]
        set _media [lindex $port 3]
        if {$_media == "c" || $_media == "C"  } {
            set _media 0
        } elseif {$_media == "f" || $_media == "F"} {
            set _media 1
        }
        set _streamid 1
        set portList [ list [ list $_chassis $_card $_port ] ]

        Reset
    }
    
    #析构函数
    destructor {}
    
    private method get_params { args }
    private method get_mac { args } 
    private method config_port { args }
    private method config_stream { args }
    
    #Traffic APIs
    public method Reset { args }
    public method Run { args }
    public method Stop { args }
    public method SetTrig {args }
    public method SetPortSpeedDuplex { args }
    public method SetTxSpeed { args }
    public method SetTxMode { args }
    public method SetCustomPkt { args }
    public method SetVFD1 { args }
    public method SetVFD2 { args }
    public method SetEthIIPkt { args }
    public method SetArpPkt { args }
    public method CreateCustomStream { args }
    public method CreateIPStream { args }
    public method CreateTCPStream { args }
    public method CreateUDPStream { args }
    public method SetCustomVFD { args }
    public method CaptureClear { args }
    public method StartCapture { args }
    public method StopCapture { args }
    public method ReturnCaptureCount { args }
    public method ReturnCapturePkt { args }
    public method GetPortInfo { args }
    public method GetPortStatus {}
    public method Clear { args }
    public method CreateIPv6Stream { args }
    public method CreateIPv6TCPStream { args }
    public method CreateIPv6UDPStream { args }
    public method DeleteAllStream {}
    public method DeleteStream { args } 
    public method SetErrorPacket { args }
    public method SetFlowCtrlMode { args }
    public method SetMultiModifier { args }
    public method SetPortAddress { args } 
    public method SetPortIPv6Address { args }
    public method SetTxPacketSize { args }
    
    #Protocol Emulation APIs
    public method ProtocolInit { args }
    public method StartRoutingEngine { args }
    public method StopRouteEngine { args }
    
    #OSPF
    public method AddOspfNei  { args }
    public method DeleteOspfNei {  args }
    public method EditOspfNei { args }
    public method EnableOspfNei { args }
    public method DisableOspfNei { args }
    public method AddOspfAse { args }
    public method AddOspfSummary   { args }
    public method AddOspfGrid { args }
    public method DeleteOspfGrid  { args }
    
    #RIP
    public method AddRipSession  { args }
    public method DeleteRipSession { args }
    public method OpenRipSession { args }
    public method CloseRipSession { args }
    public method AddRipRoutePool { args }
    public method DeleteRipRoutePool { args }
    public method EditRipSession { args }
    
    #RIPng
    public method AddRIPngSession { args }
    public method DeleteRIPngSession { args }
    public method OpenRIPngSession { args }
    public method CloseRIPngSession { args }
    public method AddRIPngRoutePool { args }
    public method DeleteRIPngRoutePool { args }
    
    #BGP
    public method AddBgpSession  { args }
    public method DeleteBgpSession { args }
    public method OpenBgpSession { args }
    public method CloseBgpSession { args }
    public method AddBgpRoutePool { args }
    public method DeleteBgpRoutePool { args }
    public method SetBgpPoolOption { args }
    public method SetBgpFlapOption   { args }
    public method StartBgpPoolFlap {args}
    public method StopBgpPoolFlap  { args }
    
    #ISIS
    public method AddIsisNei { args }
    public method DeleteIsisNei  { args }
    public method EnableIsisNei { args }
    public method DisableIsisNei { args }
    public method AddIsisNet { args }
    public method DeleteIsisNet  { args }
    
    #utili
    # public method MacTrans { macaddr } {
        # set macunit [ split $macaddr - ] 
        # set macnew ""
        # foreach unit $macunit {
            # while { [string length $unit] != 4} {
                # set unit "0$unit"
            # }
            # lappend 
        # }
        
    # }
    
    #处理并记录error错误
    method error {Str} {
        CTestException::Error $Str -origin Ixia
    } 
    
    #输出调试信息
    method Log {Str { Level info } }  {
        CTestLog::Log $Level $Str origin Ixia
    }
} ;# End of Class

###########################################################################################
#@@Proc
#Name: get_params
#Desc: get params from args
#Args: args, form as -var1 value1 -var2 value2
#Usage: get_params -x 1 -y 2
###########################################################################################
::itcl::body CIxiaPortETH::get_params { args } {
    puts "proc get_params"
    set argList ""
    set args [string tolower [lindex $args 0]]
    set tmp [split $args \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
            upvar [lindex $tmp_list 0] [lindex $tmp_list 0]
            append argList " [lindex $tmp_list 0].arg"
        }
    }
    set result [cmdline::getopt args $argList opt val]
    while {$result > 0} {
        set $opt $val
        set result [cmdline::getopt args $argList opt val] 
    }   
    if {$result < 0} {
        error "Invaild value:$args"
    }
}

###########################################################################################
#@@Proc
#Name: get_mac
#Desc: get mac add
#Args: mac - ffff-ffff-ffff 
#Usage: get_mac ffff-ffff-ffff
#Ret:  ff ff ff ff ff ff
###########################################################################################
::itcl::body CIxiaPortETH::get_mac {mac} {
    regsub -all --  {-} $mac {} mac
    regsub -all {(\w\w)(\w\w)} $mac {\1 \2 } mac
    return $mac
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
::itcl::body CIxiaPortETH::config_port { args } {
    puts "proc config_port"
    set retVal $::CIxia::gIxia_OK
    set configtype config
    set noProtServ false
    get_params $args    
    switch [string toupper $noProtServ] {
        TURE {
            set cmd "-noProtocolServer"
        }
        FALSE -
        default {
            set cmd ""
        }
    }
    switch [string toupper $configtype] {
        WRITE {
            set command "ixWritePortsToHardware"
        }
        CONFIG -
        default {
            set command "ixWriteConfigToHardware"
        }
    }
       if [catch {eval $command portList $cmd}] {
        error "Can't write config to $_chassis $_card $_port\n$::ixErrorInfo"
        set retVal $::CIxia::gIxia_ERR   
       }    
    
    return $retVal
}

###########################################################################################
#@@Proc
#Name: config_stream
#Desc: Config to port
#Args:
#       -StreamId streamid default 1
#Usage: config_stream -StreamId 1
###########################################################################################
::itcl::body CIxiaPortETH::config_stream { args } {
    puts "proc config_stream"
    set retVal $::CIxia::gIxia_OK
    set streamid 1
    get_params $args    
    puts "config_stream $streamid"
    if [catch {stream set $_chassis $_card $_port $streamid}] {
        error "Can't set stream $_chassis $_card $_port $streamid\n$::ixErrorInfo"
        set retVal $::CIxia::gIxia_ERR
    }

    return $retVal
}

###########################################################################################
#@@Proc
#Name: Reset
#Desc: Reset current Port
#Args: args
#Usage: port1 Reset
###########################################################################################
::itcl::body CIxiaPortETH::Reset { args } {
    puts "proc Reset"
    Log "Reset port {$_chassis $_card $_port}..."
    set retVal $::CIxia::gIxia_OK
      
    stream setDefault
    if {[string match [config_stream -StreamId $_streamid] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }
    
          
    if [string match [Clear] $::CIxia::gIxia_ERR] {
        set retVal $::CIxia::gIxia_ERR
    }
    if [port setFactoryDefaults $_chassis $_card $_port] {
        error "Error setting factory defaults on port $_chassis,$_card,$_port."
        set retVal $::CIxia::gIxia_ERR
    }
         
    if { $_media != "" } {
        if [port setPhyMode $_media $_chassis $_card $_port] {
            error "Error setting media $_media on port $_chassis,$_card,$_port."
            set retVal $::CIxia::gIxia_ERR
        }
    }
    port get $_chassis $_card $_port

    port config -receiveMode  [expr $::portCapture|$::portRxFirstTimeStamp|$::portRxModeWidePacketGroup]  
    port config -transmitMode   portTxModeAdvancedScheduler        
    port set $_chassis $_card $_port
  
    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }        
    
    #$this ProtocolInit
    DeleteAllStream
    
    return $retVal
}

###########################################################################################
#@@Proc
#Name: Run
#Desc: Begin to send packects/stream
#Args: args
#Usage: port1 Run
###########################################################################################
::itcl::body CIxiaPortETH::Run { args } {
    Log "Start transmit at $_chassis $_card $_port..."
    set retVal $::CIxia::gIxia_OK
    if [ixCheckLinkState portList] {
        Log "Port $_chassis $_card $_port Link is down! Can not Run." warning
        set retVal $::CIxia::gIxia_ERR
        return $retVal
    }
    if [ixStartTransmit portList] {
        set retVal $::CIxia::gIxia_ERR
    }

    return $retVal
}

###########################################################################################
#@@Proc
#Name: Stop
#Desc: Stop to send packects/stream
#Args: args
#Usage: port1 Stop
###########################################################################################
::itcl::body CIxiaPortETH::Stop { args } {
    Log "Stop transmit at $_chassis $_card $_port..."
    set retVal $::CIxia::gIxia_OK
    if [ixStopTransmit portList] {
        set retVal $::CIxia::gIxia_ERR
    }

    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetTrig
#Desc: Set filter conditions
#Args:  
#    offset1:       offset of packect
#       pattern1:       trigger pattern
#    trigMode:      support && and ||
#       offset2:       offset of packet
#       pattern2:       trigger pattern
#Usage: port1 SetTrig 12 {00 10}
###########################################################################################
::itcl::body CIxiaPortETH::SetTrig {offset1 pattern1 {TrigMode ""} {offset2 ""} {pattern2 ""}} {
    set trigmode $TrigMode
    Log "Set trigger ($offset1 $pattern1 $trigmode $offset2 $pattern2) at $_chassis $_card $_port..."
    set retVal $::CIxia::gIxia_OK

    switch -- $trigmode {
        ""   {
                set TriggerMode pattern1
        }
        "||" {
                set TriggerMode pattern2
        }
        "&&" {
            set TriggerMode pattern1AndPattern2
        }
        default {
            error "Invaild trigmode: $trigmode"
        }
    }
    capture                      setDefault
    capture                      set               $_chassis $_card $_port
    filter                       setDefault
    filter                       config            -captureTriggerPattern              $TriggerMode
    filter                       config            -captureTriggerEnable               enable
    filter                       set               $_chassis $_card $_port
    filterPallette setDefault
    filterPallette config -pattern1 $pattern1
    filterPallette config -pattern2 $pattern2
    filterPallette config -patternOffset1 $offset1
    filterPallette config -patternOffset2 $offset2
    filterPallette set $_chassis $_card $_port

    if {[string match [config_port -ConfigType config] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }

       return $retVal
}

###########################################################################################
#@@Proc
#Name: SetPortSpeedDuplex
#Desc: set port speed and duplex 
#Args: autoneg : 0 - disable autoneg 
#         1 - enable autoneg
#      speed  : speed - 0x0002(10M),0x0008(100M) 0x0040(1G)or all
#      duplex : duplex - FULL(0) or HALF(1) or ALL
#Usage: port1 SetPortSpeedDuplex 1 10 full
###########################################################################################
::itcl::body CIxiaPortETH::SetPortSpeedDuplex {AutoNeg {Speed -1} {Duplex -1}} {
    Log "Set port speed duplex at $_chassis $_card $_port..."
    set retVal $::CIxia::gIxia_OK

    set autoneg $AutoNeg
    set speed [string toupper $Speed]
    set duplex [string toupper $Duplex]

    # check for errord parameters
    if {($speed != "0x0002")&&($speed != "0x0008")&&($speed != "0x0040")&&($speed != -1)} {
        error "illegal speed defined ($speed)"
        set retVal $::CIxia::gIxia_ERR 
    }
    if {($duplex != 0)&&($duplex != 1)&&($duplex != -1)} {
        error "illegal duplex mode defined ($duplex)"
        set retVal $::CIxia::gIxia_ERR 
    }
    if {($autoneg != 0)&&($autoneg != 1)} {
        error "illegal auto negotiate mode defined ($autoneg)"
        set retVal $::CIxia::gIxia_ERR 
    }
   
    if { $autoneg == 1 } {
        port config -autonegotiate  true
        if { $speed == -1 } {
            if { $duplex == -1 } {
                port config -advertise1000FullDuplex  true  
                port config -advertise100FullDuplex   true
                port config -advertise100HalfDuplex   true
                port config -advertise10FullDuplex   true
                port config -advertise10HalfDuplex   true
            } elseif { $duplex == 0 } {
                port config -advertise1000FullDuplex  true    
                port config -advertise100FullDuplex   true
                port config -advertise100HalfDuplex   false
                port config -advertise10FullDuplex   true
                port config -advertise10HalfDuplex   false
            } elseif { $duplex == 1 } {
                port config -advertise1000FullDuplex  false    
                port config -advertise100FullDuplex   false
                port config -advertise100HalfDuplex   true
                    port config -advertise10FullDuplex   false
                port config -advertise10HalfDuplex   true
            }
        } elseif { $speed == 0x0040 } {
            if { $duplex == -1 } {
                port config -advertise1000FullDuplex  true  
                port config -advertise100FullDuplex   false
                port config -advertise100HalfDuplex   false
                port config -advertise10FullDuplex   false
                port config -advertise10HalfDuplex   false
            } elseif { $duplex == 0 } {
                port config -advertise1000FullDuplex  true    
                port config -advertise100FullDuplex   false
                port config -advertise100HalfDuplex   false
                port config -advertise10FullDuplex   false
                port config -advertise10HalfDuplex   false
            } elseif { $duplex == 1 } {
                error "No 1000M Half this mode"
            }
        } elseif { $speed == 0x0008 } {
            if { $duplex == -1 } {
                port config -advertise100FullDuplex   true
                port config -advertise100HalfDuplex   true
                port config -advertise10FullDuplex   false
                port config -advertise10HalfDuplex   false
            } elseif { $duplex == 0 } {
                port config -advertise100FullDuplex   true
                port config -advertise100HalfDuplex   false
                port config -advertise10FullDuplex   false
                port config -advertise10HalfDuplex   false
            } elseif { $duplex == 1 } {
                port config -advertise100FullDuplex   false
                port config -advertise100HalfDuplex   true
                port config -advertise10FullDuplex   false
                port config -advertise10HalfDuplex   false
            }
        } elseif { $speed == 0x0002 } {
            if { $duplex == -1 } {
                port config -advertise100FullDuplex   false
                port config -advertise100HalfDuplex   false
                port config -advertise10FullDuplex   true
                port config -advertise10HalfDuplex   true
            } elseif { $duplex == 0 } {
                port config -advertise100FullDuplex   false
                port config -advertise100HalfDuplex   false
                port config -advertise10FullDuplex   true
                port config -advertise10HalfDuplex   false
            } elseif { $duplex == 1 } {
                port config -advertise100FullDuplex   false
                port config -advertise100HalfDuplex   false
                port config -advertise10FullDuplex   false
                port config -advertise10HalfDuplex   true
            }
        } 
    } else {
        # no autonegotiate
        if { $duplex == -1} {set duplex 0}
        switch $speed {
            0x0002 {set speed 10}
            0x0008 {set speed 100}
            0x0040 {set speed 1000}
            -1     {set speed 100}    
        }
        port config -autonegotiate  false
        
        if { $duplex == 0 } {
            port config -duplex full
        } elseif { $duplex == 1 } {
            port config -duplex half
        } else {
            error "illegal duplex mode inconjunction with auto negotiate settings ($duplex)"
            set retVal $::CIxia::gIxia_ERR 
        }
        port config -speed $speed
    }

    if { [port set $_chassis $_card $_port] } {
        error "failed to set port configuration on port $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    if {[string match [config_port -ConfigType write -NoProtServ ture] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }

    if [ixCheckLinkState portList] {
        Log "Port $_chassis $_card $_port Link is down!" warning
        set retVal $::CIxia::gIxia_ERR
    }
        
    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetTxSpeed
#Desc: send port send rate
#Args: utilization : port utilization
#Usage: port1 SetTxSpeed
###########################################################################################
::itcl::body CIxiaPortETH::SetTxSpeed {Utilization {Mode "Uti"}} {
    set utilization $Utilization

    Log "Set tx speed of {$_chassis $_card $_port}..."
    set retVal $::CIxia::gIxia_OK
    regsub {[%]} $utilization {} utilization
    set streamid   1

    while {[stream get $_chassis $_card $_port $streamid] != 1} {
        if { $Mode == "Uti" } {
            stream config -rateMode usePercentRate
            stream config -percentPacketRate $utilization
        } else {
            stream config -rateMode streamRateModeFps
            stream config -fpsRate $utilization
        }
    
        if {[string match [config_stream -StreamId $streamid] $::CIxia::gIxia_ERR]} {
            set retVal $::CIxia::gIxia_ERR
        }
        
        incr streamid
    }
    
    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }

    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetTxMode
#Desc: set port send mode
#Args: 
#    txmode: send mode
#        0 - CONTINUOUS_PACKET_MODE              
#        1 - SINGLE_BURST_MODE  attach 1 params: BurstCount
#        2 - MULTI_BURST_MODE   attach 4 params: BurstCount InterBurstGap InterBurstGapScale MultiburstCount
#        3 - CONTINUOUS_BURST_MODE   attach 3 params: BurstCount InterBurstGap InterBurstGapScale
#    BurstCount:  ever burst package count
#    MultiburstCount:    multiburst count
#    InterBurstGap:      interval of every 2 bursts
#    InterBurstGapScale: interval unit
#        0 - NanoSeconds            
#        1 - MICRO_SCALE   
#        2 - MILLI_SCALE   
#        3 - Seconds
#Usage: port1 SetTxMode 0
###########################################################################################
::itcl::body CIxiaPortETH::SetTxMode {TxMode {BurstCount 0} {InterBurstGap 0} {InterBurstGapScale 0} {MultiBurstCount 0}} {

    set txmode $TxMode
    set burstcount $BurstCount
    set interburstgap $InterBurstGap
    set interburstgapscale $InterBurstGapScale
    set multiburstcount $MultiBurstCount
    
    switch $interburstgapscale {
        0 {set interburstgapscale 4}
        1 {set interburstgapscale 0}
        2 {set interburstgapscale 1}
        3 {set interburstgapscale 2}
        4 {set interburstgapscale 3}
    }

    Log "Set tx mode of {$_chassis $_card $_port}..."
    set retVal $::CIxia::gIxia_OK
    set num 1
    while { [stream get $_chassis $_card $_port $num ] != 1 } {
        incr num
    }
    
    # According to requirement, we should calculate the burstcount by stream
    set burstcount [expr $burstcount / $num]
    if { $burstcount == 0 } {
        set burstcount 1
    }
    
    set streamid   1

    while {[stream get $_chassis $_card $_port $streamid] != 1} {
        switch  $txmode {
            0   {
                stream config -dma contPacket
            }
            1   {
                stream config -dma stopStream
                stream config -numBursts 1
                stream config -numFrames $burstcount
                stream config -startTxDelayUnit                   0
                stream config -startTxDelay                       0.0
            }
            2    {
                #对gap scale为bit单位的处理, 转为毫秒
                if { $interburstgapscale == 4 } {
                    set interburstgapscale 2
                }
                        
                stream config -dma advance
                stream config -enableIbg true
                stream config -numBursts $multiburstcount
                stream config -numFrames $burstcount
                stream config -ibg $interburstgap 
                stream config -gapUnit $interburstgapscale
            }
            3    {
                #对gap scale为bit单位的处理, 转为毫秒
                if { $interburstgapscale == 4 } {
                    set interburstgapscale 2
                }

                stream config -dma contBurst
                stream config -enableIbg true
                stream config -numFrames $burstcount
                stream config -ibg $interburstgap 
                stream config -gapUnit $interburstgapscale
            }
            default {    
                error "No such Transmit mode, please check 'txmode' "
                set retVal $::CIxia::gIxia_ERR
            }
        }
        if {[string match [config_stream -StreamId $streamid] $::CIxia::gIxia_ERR]} {
            set retVal $::CIxia::gIxia_ERR
        }
        
        incr streamid
    }
    if {[string match [config_port -ConfigType config -NoProtServ ture] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }

    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetCustomPkt
#Desc: set packet value
#Args: 
#    myValue eg:ff ff ff ff ff ff 00 00 00 00 00 01 08 00 45 00
#    pkt_len default -1
#Usage: port1 SetCustomPkt {ff ff ff ff ff ff 00 00 00 00 00 01 08 00 45 00}
###########################################################################################
::itcl::body CIxiaPortETH::SetCustomPkt {{myValue 0} {pkt_len -1}} {
    Log "Set custom packet of {$_chassis $_card $_port}..."
    set retVal $::CIxia::gIxia_OK
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
    stream config -frameType "86 DD"
    if { [llength $myvalue] >= 12 } {
        if { [lindex $myvalue 12] == "81" && [lindex $myvalue 13] == "00"} {
            set vlanOpts  0x[lindex $myvalue 14][lindex $myvalue 15]
            protocol config -enable802dot1qTag vlanSingle
            vlan setDefault
            # 12 bits Vlan ID
            vlan config -vlanID                 [expr $vlanOpts & 0x0FFF]
            # 3 bits Priority
            vlan config -userPriority           [expr $vlanOpts >> 13]
            if {[vlan set $_chassis $_card $_port]} {
                errorMsg "Error calling vlan set $_chassis $_card $_port"
                set retCode $::CIxia::gIxia_ERR
            }
            
            stream config -frameType "[lindex $myvalue 16] [lindex $myvalue 17]"
            stream config -pattern [lrange $myvalue 16 end]
        } else {
            stream config -frameType "[lindex $myvalue 12] [lindex $myvalue 13]"
            stream config -pattern [lrange $myvalue 12 end]
        }
    }      
    
    if {[string match [config_stream -StreamId 1] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
        set retVal 0
    }
    if {[string match [config_port -ConfigType config] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
        set retVal 0
    }

    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetEthIIPkt
#Desc: set packet value
#Args: 
#Usage: port1 SetEthIIPkt {ff ff ff ff ff ff 00 00 00 00 00 01 08 00 45 00}
###########################################################################################
::itcl::body CIxiaPortETH::SetEthIIPkt { args } {
    set PacketLen 60
    set SrcMac "0.0.0.1"
    set DesMac "ffff.ffff.ffff"
    set DesIP "1.1.1.2"
    set SrcIP "1.1.1.1"
    set TTL 64
    set Tos 0
    set EncapType EET_II
    set VlanID 0
    set Priority 0
    set Data ""
    set Protocol 1

    set argList {PacketLen.arg SrcMac.arg DesMac.arg DesIP.arg SrcIP.arg Tos.arg TTL.arg \
                 EncapType.arg VlanID.arg Priority.arg Data.arg Protocol.arg}

    set result [cmdline::getopt args $argList opt val]
    while {$result>0} {
        set $opt $val
        set result [cmdline::getopt args $argList opt val]        
    }
    
    if {$result<0} {
        Log "SetEthIIPkt has illegal parameter! $val"
        return $::CIxia::gIxia_ERR
    }

    # 参数检查
    set Match [MacValid $DesMac]
    if { $Match != 1} {
        Log "CIxiaPortETH::SetEthIIPkt >>> DesMac is invalid" warning
        return $::CIxia::gIxia_ERR
    }
    set Match [MacValid $SrcMac]
    if { $Match != 1} {
        Log "CIxiaPortETH::SetEthIIPkt >>> SrcMac is invalid" warning
        return $::CIxia::gIxia_ERR
    }
    set Match [IpValid $DesIP]
    if { $Match != 1} {
        Log "CIxiaPortETH::SetEthIIPkt >>> DesIP is invalid" warning
        return $::CIxia::gIxia_ERR
    }
    set Match [IpValid $SrcIP]
    if { $Match != 1} {
        Log "CIxiaPortETH::SetEthIIPkt >>> SrcIP is invalid" warning
        return $::CIxia::gIxia_ERR
    }

    if {$VlanID==0 && $Priority!=0} {
        Log "CIxiaPortETH::SetEthIIPkt >>> a vlan id is prefered if the priority is used"
        return $::CIxia::gIxia_ERR    
    }
    
    set EncapList {EET_II EET_802_2 EET_802_3 EET_SNAP}
    if {[lsearch $EncapList $EncapType] == -1} {
        Log "CIxiaPortETH::SetEthIIPkt >>> Invalid encapsulation type is prefered! $EncapType" warning
        return $::CIxia::gIxia_ERR
    }
    
    if {$PacketLen < 0} {
        Log "CIxiaPortETH::SetEthIIPkt >>> Invalid packet length is prefered! $PacketLen" warning
        return $::CIxia::gIxia_ERR
    }
    
    switch $EncapType {
        EET_II {
            set min_pktLen 34
            set frame_name eth_frame_hdr
        }
        EET_802_3 {
            set min_pktLen 34
            set frame_name 802.3_frame_hdr
         }
        EET_802_2 {
            set min_pktLen 37
            set frame_name 802.2_frame_hdr
        }
        EET_SNAP {
            set min_pktLen 42
            set frame_name snap_frame_hdr
        }
    }
    
    set vlan_tag_hdr ""
    if {$VlanID!=0} {
        set min_pktLen [expr $min_pktLen + 4]
        set PacketLen [expr $PacketLen + 4]
        
        set vlan_tag_hdr [::packet::conpkt vlan_tag -pri $Priority -tag $VlanID]
    }
    set Data [regsub -all "0x" $Data ""]
    set ipv4_packet [::packet::conpkt ipv4_header -srcip $SrcIP -desip $DesIP -ttl $TTL -tos $Tos -pro $Protocol -data $Data]
    set eth_packet [::packet::conpkt $frame_name -deth $DesMac -seth $SrcMac -vlantag $vlan_tag_hdr -data $ipv4_packet]
    
    Log "Set packet of {$_chassis $_card $_port}:\n\t$eth_packet"
    puts "Set packet of {$_chassis $_card $_port}:\n\t$eth_packet  $PacketLen"
    
    $this SetCustomPkt $eth_packet $PacketLen
    
    return $::CIxia::gIxia_OK
}

::itcl::body CIxiaPortETH::SetArpPkt { args } {
    set PacketLen 60
    set ArpType 1
    set DesMac 0
    set SrcMac 0
    set ArpDesIP "0.0.0.0"
    set ArpSrcIP "0.0.0.0"
    set ArpSrcMac 0
    set ArpDesMac 0
    set EncapType EET_II
    set VlanID 0
    set Priority 0

    set argList {PacketLen.arg ArpType.arg DesMac.arg SrcMac.arg ArpDesMac.arg ArpSrcMac.arg ArpDesIP.arg ArpSrcIP.arg \
                 EncapType.arg VlanID.arg Priority.arg}

    set result [cmdline::getopt args $argList opt val]
    while {$result>0} {
        set $opt $val
        set result [cmdline::getopt args $argList opt val]        
    }
    
    if {$result<0} {
        Log "SetIPXPacket has illegal parameter! $val"
        return $::CIxia::gIxia_ERR
    }
    
    # 如果不指定ArpSrcMac或者取0,则取ArpSrcMac等于SrcMac,如果两者只指定一个就同取一个值。如果两者都为0即都没有指定，
    #则取默认值0.0.1
    if {$ArpSrcMac == 0 && $SrcMac == 0} {  
        set ArpSrcMac 0.0.1 
        set SrcMac 0.0.1 
    } else {
        if {$ArpSrcMac == 0} {set ArpSrcMac $SrcMac }
        if {$SrcMac == 0} {set SrcMac $ArpSrcMac }
    }    
    
    # 如果不指定ArpDesMac或者取0,则取ArpDesMac等于DesMac,如果两者只指定一个就同取一个值。如果两者都为0即都没有指定，
    #则取默认值ffff.ffff.ffff
    if {$ArpDesMac == 0 && $DesMac == 0} {  
        set DesMac ffff.ffff.ffff 
        set ArpDesMac ffff.ffff.ffff 
    } else {
        if {$ArpDesMac == 0} {set ArpDesMac $DesMac }
        if {$DesMac == 0} {set DesMac $ArpDesMac }
    }
    #对于请求报文 ArpDesMac取0.0.0
    if {($ArpType == 1) } {
        set ArpDesMac 0.0.0 
    }
    # 参数检查
    set Match [MacValid $SrcMac]
    if { $Match != 1} {
        Log "CIxiaPortETH::SetArpPkt >>> ArpSrcMac is invalid" warning
        return $::CIxia::gIxia_ERR
    }
    set Match [MacValid $DesMac]
    if { $Match != 1} {
        Log "CIxiaPortETH::SetArpPkt >>> DesMac is invalid" warning
        return $::CIxia::gIxia_ERR
    }
    if {$ArpSrcMac != 0 } {
    set Match [MacValid $ArpSrcMac]
        if { $Match != 1} {
            Log "CIxiaPortETH::SetArpPkt >>> ArpSrcMac is invalid" warning
            return $::CIxia::gIxia_ERR
        }
    }
    
    if {$ArpDesMac != 0 } {
    set Match [MacValid $ArpDesMac]
        if { $Match != 1} {
            Log "CIxiaPortETH::SetArpPkt >>> ArpDesMac is invalid" warning
            return $::CIxia::gIxia_ERR
        }
    }
    
    set Match [IpValid $ArpSrcIP]
    if { $Match != 1} {
        Log "CIxiaPortETH::SetArpPkt >>> ArpSrcIP is invalid" warning
        return $::CIxia::gIxia_ERR
    }
    set Match [IpValid $ArpDesIP]
    if { $Match != 1} {
        Log "CIxiaPortETH::SetArpPkt >>> ArpDesIP is invalid" warning
        return $::CIxia::gIxia_ERR
    }

    if {$VlanID==0 && $Priority!=0} {
        Log "CIxiaPortETH::SetArpPkt >>> a vlan id is prefered if the priority is used"
        return $::CIxia::gIxia_ERR    
    }

    set EncapList {EET_II EET_802_2 EET_802_3 EET_SNAP}
    if {[lsearch $EncapList $EncapType] == -1} {
        Log "CIxiaPortETH::SetArpPkt >>> Invalid encapsulation type is prefered! $EncapType" warning
        return $::CIxia::gIxia_ERR
    }

    if {$PacketLen < 0} {
        Log "CIxiaPortETH::SetArpPkt >>> Invalid packet length is prefered! $PacketLen" warning
        return $::CIxia::gIxia_ERR
    }

    switch $EncapType {
        EET_II {set min_pktLen 42}
        EET_802_3 {set min_pktLen 42}
        EET_802_2 {set min_pktLen 45}
        EET_SNAP {set min_pktLen 50}
    }
    
    if {$PacketLen < $min_pktLen} {
        set PacketLen $min_pktLen
    }
    
    set arp_pkt [::packet::conpkt arp_pkt -deth $DesMac -seth $SrcMac -srcMac $ArpSrcMac -srcIp $ArpSrcIP \
                                          -desMac $ArpDesMac -desIp $ArpDesIP -oper $ArpType]
    Log "Set packet of {$_chassis $_card $_port}:\n\t$arp_pkt"
                                               
    return [$this SetCustomPkt $arp_pkt 60]
}

###########################################################################################
#@@Proc
#Name: CreateCustomStream
#Desc: set custom stream
#Args: 
#      framelen: frame length
#      utilization: send utilization(percent)
#      txmode: send mode,[0|1] 0 - continuous 1 - burst
#      burstcount: burst package count
#      protheader: define packet value same as setcustompkt；
#      portspeed: port speed
#Usage: port1 CreateCustomStream -FrameLen 64 -Utilization 10 -TxMode 0 -BurstCount 0 -ProHeader {ff ff ff ff ff ff 00 00 00 00 00 01 08 00 45 00}
#
###########################################################################################
::itcl::body CIxiaPortETH::CreateCustomStream {args} {
    Log "Create custom stream..."
    set retVal $::CIxia::gIxia_OK

    ##framelen utilization txmode burstcount protheader {portspeed 1000}
    set FrameLen 60
    set FrameRate 0
    set Utilization 1
    set TxMode 0
    set BurstCount 0
    set ProHeader ""

    set argList {FrameLen.arg Utilization.arg FrameRate.arg TxMode.arg BurstCount.arg ProHeader.arg}

    set result [cmdline::getopt args $argList opt val]
    while {$result>0} {
        set $opt $val
        set result [cmdline::getopt args $argList opt val]
    }    
    if {$result<0} {
        puts "CreateCustomStream has illegal parameter! $val"
        return $::CIxia::gIxia_ERR
    }
    #if {[llength $FrameLen]==2} {
    #    set FrameLen [expr ([llength $FrameLen 0] + [llength $FrameLen 1])/2]
    #}
    set framelen $FrameLen
    if { $FrameRate != 0 } {
        set utilization $FrameRate
        set mode "PktPerSec"
    } else {
        set utilization $Utilization
        set mode "Uti"
    }
    set txmode $TxMode
    set burstcount $BurstCount
    set protheader $ProHeader

    #port config -speed $portspeed
    set retVal1 [SetCustomPkt $protheader $framelen]
    if {[string match $retVal1 $::CIxia::gIxia_ERR]} {    
        error "CreateCustomStream:SetCustomPkt failed."
        set retVal $::CIxia::gIxia_ERR
    }
    set retVal2 [SetTxMode $txmode $burstcount]
    if {[string match $retVal2 $::CIxia::gIxia_ERR]} {    
        error "CreateCustomStream:SetTxMode failed."
        set retVal $::CIxia::gIxia_ERR
    }
    set retVal3 [SetTxSpeed $utilization $mode]
    if {[string match $retVal3 $::CIxia::gIxia_ERR]} {    
        error "CreateCustomStream:SetTxSpeed failed."
        set retVal $::CIxia::gIxia_ERR
    }
    return $retVal      
}


###########################################################################################
#@@Proc
#Name: CreateIPStream
#Desc: set IP stream
#Args: 
#      -name:    IP Stream name
#      -frameLen: frame length
#      -utilization: send utilization(percent), default 100
#      -txMode: send mode,[0|1] default 0 - continuous 1 - burst
#      -burstCount: burst package count
#      -desMac: destination MAC default ffff-ffff-ffff
#      -srcMac: source MAC default 0-0-0
#      -desIP: destination ip default 0.0.0.0
#      -srcIP: source ip, default 0.0.0.0
#      -tos: tos default 0
#      -_portSpeed: _port speed default 100                   
#      -data: content of frame, 0 by default means random
#             example: -data 0   ,  the data pattern will be random    
#                      -data abac,  use the "abac" as the data pattern
#       -signature: enable signature or not, 0(no) by default
#       -ipmode: how to change the IP
#               0                          no change (default)
#               ip_inc_src_ip              source IP increment
#               ip_inc_dst_ip              destination IP increment
#               ip_dec_src_ip              source IP decrement
#               ip_dec_dst_ip              destination IP decrement
#               ip_inc_src_ip_and_dst_ip   both source and destination IP increment
#               ip_dec_src_ip_and_dst_ip   both source and destination IP decrement
#       -ipbitsoffset1: bitoffset,0 by default 
#       -ipbitsoffset2: bitoffset,0 by default
#       -ipcount1:  the count that the first ip stream will vary,0 by default 
#       -ipcount2:  the count that the second ip stream will vary,0 by default
#       -stepcount1: the step size that the first ip will vary, it should be the power of 2, eg. 1,2,4,8..., 0 by default means no change
#       -stepcount2: the step size that the second ip will vary,it should be the power of 2, eg. 1,2,4,8..., 0 by default means no change
#
#Usage: _port1 CreateIPStream -SMac 0010-01e9-0011 -DMac ffff-ffff-ffff
###########################################################################################
::itcl::body CIxiaPortETH::CreateIPStream { args } {
    Log "Create IP stream..."
    set retVal $::CIxia::gIxia_OK

    set framelen   64
    set framerate  0
    set utilization 100
    set txmode     0
    set burstcount 1
    set desmac       ffff-ffff-ffff
    set srcmac       0000-0000-0000
    set desip        0.0.0.0
    set srcip        0.0.0.0
    set tos        0
    set _portspeed  100
    set data 0
    set userPattern 0
    set signature 0 
    set ipmode 0 
    set ipbitsoffset1 0
    set ipbitsoffset2 0 
    set ipcount1 0 
    set ipcount2 0 
    set stepcount1 0 
    set stepcount2 0 

    set name      ""
    set vlan       0
    set vlanid     0
    set pri        0
    set priority   0
    set cfi        0
    set type       "08 00"
    set ver        4
    set iphlen     5
    set dscp       0
    set tot        0
    set id         0
    set mayfrag    0
    set lastfrag   0
    set fragoffset 0
    set ttl        255        
    set protocol   17
    set change     0
    set enable     true
    set value      {{00 }}
    set strframenum    100
        
    #---------------added by liusongzhi---------------------#
    set group 1 
    #-----------------end-liusongzhi------------------------#  
            
    set udf1       0
    set udf1Offset 0
    set udf1ContinuousCount   0
    set udf1InitVal {00}
    set udf1Step    1
    set udf1ChangeMode 0
    set udf1Repeat  1
    set udf1Size  8
    set udf1CounterMode udfCounterMode
        
    set udf2       0
    set udf2Offset 0
    set udf2ContinuousCount   0
    set udf2InitVal {00}
    set udf2Step    1
    set udf2ChangeMode 0
    set udf2Repeat  1
    set udf2Size  8
    set udf2CounterMode udfCounterMode

    #get parameters
    set argList ""
    set temp ""
    for {set i 0} { $i < [llength $args]} {incr i} {
        lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
                append argList " [lindex $tmp_list 0].arg"
        }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val    
        puts "$opt: $val"
    }
    
    set srcmac [::ipaddress::format_mac_address $srcmac 6 ":"]
    set desmac [::ipaddress::format_mac_address $desmac 6 ":"]

    #format the IP address from decimal to hex
    set hexSrcIp [split $srcip \.]
    set hexDesIp [split $desip \.]
    for {set i 0} {$i < 4} {incr i} {
        lappend hex1 [format %x [lindex $hexSrcIp $i]]
        lappend hex2 [format %x [lindex $hexDesIp $i]]
    }
    set hexSrcIp [lrange $hex1 0 end]
    set hexDesIp [lrange $hex2 0 end]
    set vlan $vlanid
    set pri  $priority

    #Setting the _streamid.
    set streamCnt 1
    for {set i 1 } {1} {incr i} {
        if {[stream get $_chassis $_card $_port $i] == 0 } {incr streamCnt} else { break}
    }
    set _streamid $streamCnt

    #Define Stream parameters.
    stream setDefault        
    stream config -enable $enable
    stream config -name $name
    stream config -numBursts $burstcount        
    stream config -numFrames $strframenum
    if { $framerate != 0 } {
        stream config -rateMode streamRateModeFps
        stream config -fpsRate $framerate
    } else {
        stream config -percentPacketRate $utilization
        stream config -rateMode usePercentRate
    }
    stream config -sa $srcmac
    stream config -da $desmac
    
    switch $txmode {
        0 {stream config -dma contPacket}
        1 {
            stream config -dma stopStream
            stream config -numBursts 1
            stream config -numFrames $burstcount
            stream config -startTxDelayUnit                   0
            stream config -startTxDelay                       0.0
        }
        2 {stream config -dma advance}
        default {error "No such stream transmit mode, please check -strtransmode parameter."}
    }
    
    if {[llength $framelen] == 1} {
        stream config -framesize $framelen
        stream config -frameSizeType sizeFixed
    } else {
        stream config -framesize 318
        stream config -frameSizeType sizeRandom
        stream config -frameSizeMIN [lindex $framelen 0]
        stream config -frameSizeMAX [lindex $framelen 1]
    }
   
    stream config -frameType $type
    
    #Define protocol parameters 
    protocol setDefault        
    protocol config -name ipV4
    protocol config -ethernetType ethernetII
    
    ip setDefault        
    ip config -ipProtocol   $protocol
    #ip config -ipProtocol udp
    ip config -identifier   $id
    ip config -qosMode         ipV4ConfigTos
    switch $tos {
        0 { ip config -precedence       routine }
        1 { ip config -precedence       priority}
        2 { ip config -precedence       immediate}
        3 { ip config -precedence       flash }
        4 { ip config -precedence       flashOverride}
        5 { ip config -precedence       criticEcp}
        6 { ip config -precedence       internetControl}
        7 { ip config -precedence       networkControl}
    }
    
    
    switch $mayfrag {
        0 {ip config -fragment may}
        1 {ip config -fragment dont}
    }       
    switch $lastfrag {
        0 {ip config -fragment last}
        1 {ip config -fragment more}
    }       

    ip config -fragmentOffset 0
    ip config -ttl $ttl        
    ip config -sourceIpAddr $srcip
    ip config -destIpAddr   $desip
    if [ip set $_chassis $_card $_port] {
        error "Unable to set IP configs to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }
    # udp setDefault        
    # #tcp config -offset 5
   
    # if [udp set $_chassis $_card $_port] {
       # error "Unable to set UDP configs to IxHal!"
       # set retVal $::CIxia::gIxia_ERR
    # }
    
    if {$vlan != 0} {
        protocol config -enable802dot1qTag vlanSingle
        vlan setDefault        
        vlan config -vlanID $vlan
        vlan config -userPriority $pri
        if [vlan set $_chassis $_card $_port] {
            error "Unable to set vlan configs to IxHal!"
            set retVal $::CIxia::gIxia_ERR
        }
    }
    switch $cfi {
        0 {vlan config -cfi resetCFI}
        1 {vlan config -cfi setCFI}
    }

    if {$data == 0} {
            stream config -patternType  nonRepeat
            stream config -dataPattern  allZeroes
            stream config -pattern       "00 00"
    } else {
            stream config -patternType  nonRepeat
            stream config -pattern $data
            stream config -dataPattern 18
    }
    
    
    if { $ipmode != 0} {
        if {$ipbitsoffset1 > 7} { set ipbitsoffset1 7 }
        if {$ipbitsoffset2 > 7} { set ipbitsoffset2 7 }
        switch $ipmode {  
            ip_inc_src_ip  {
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp
                set udf1ChangeMode 0
                set udf1Step   $stepcount1                                
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]                                
            }
            ip_inc_dst_ip  { 
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp
                set udf2ChangeMode 0
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            ip_dec_src_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 1
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
            }
            ip_dec_dst_ip  {
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 1
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            ip_inc_src_ip_and_dst_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 0
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
                
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 0
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            ip_dec_src_ip_and_dst_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 1
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
                
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 1
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            default {
                error "Error: no such ipmode, please check your input!"
                set retVal $::CIxia::gIxia_ERR
            }
        }
    }
    


    #UDF Config
    if {$udf1 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf1Offset
        udf config -continuousCount  false
        switch $udf1ChangeMode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -bitOffset   $ipbitsoffset1
        udf config -initval $udf1InitVal
        udf config -repeat  $udf1Repeat              
        udf config -step    $udf1Step
        udf config -counterMode   $udf1CounterMode
        udf config -udfSize   $udf1Size
        if {[udf set 1]} {
            error "Error calling udf set 1"
            set retVal $::CIxia::gIxia_ERR
        }
    }
            
    if {$udf2 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf2Offset
        udf config -continuousCount  false
        
        switch $udf2ChangeMode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -bitOffset   $ipbitsoffset2
        udf config -initval $udf2InitVal
        udf config -repeat  $udf2Repeat              
        udf config -step    $udf2Step
        udf config -counterMode   $udf2CounterMode
        udf config -udfSize    $udf2Size
        if {[udf set 2]} {
            error "Error calling udf set 2"
            set retVal $::CIxia::gIxia_ERR
        }
    }
   
    
    #Table UDF Config        
    tableUdf setDefault        
    tableUdf clearColumns      
    tableUdf config -enable 0

    if [tableUdf set $_chassis $_card $_port] {
        error "Unable to set tableUdf to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }
        

    if {[string match [config_stream -StreamId $_streamid] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }
    if {[string match [config_port -ConifgType config -NoProtServ ture] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }
        
    return $retVal
}

###########################################################################################
#@@Proc
#Name: CreateTCPStream
#Desc: set TCP stream
#Args: args
#      -Name: the name of TCP stream
#       -FrameLen: frame length
#      -Utilization: send utilization(percent), default 100
#      -TxMode: send mode,[0|1] 0 - continuous，1 - burst
#      -BurstCount: burst package count
#      -DesMac: destination MAC，default ffff-ffff-ffff
#      -SrcMac: source MAC，default 0-0-0
#      -DesIP: destination ip，default 0.0.0.0
#      -SrcIP: source ip, default 0.0.0.0
#      -Des_port: destionation _port, default 2000
#      -Src_port: source _port，default 2000
#      -Tos: tos，default 0
#       -ipmode: how to change the IP
#               0                          no change (default)
#               ip_inc_src_ip              source IP increment
#               ip_inc_dst_ip              destination IP increment
#               ip_dec_src_ip              source IP decrement
#               ip_dec_dst_ip              destination IP decrement
#               ip_inc_src_ip_and_dst_ip   both source and destination IP increment
#               ip_dec_src_ip_and_dst_ip   both source and destination IP decrement
#       -ipbitsoffset1: bitoffset,0 by default 
#       -ipbitsoffset2: bitoffset,0 by default
#       -ipcount1:  the count that the first ip stream will vary,0 by default 
#      -ipcount2:  the count that the second ip stream will vary,0 by default
#      -stepcount1: the step size that the first ip will vary, it should be the power of 2, eg. 1,2,4,8..., 0 by default means no change
#       -stepcount2: the step size that the second ip will vary,it should be the power of 2, eg. 1,2,4,8..., 0 by default means no change
#      -_portSpeed: _port speed，default 100
#Usage: _port1 CreateTCPStream -SrcMac 0010-01e9-0011 -DesMac ffff-ffff-ffff
###########################################################################################
::itcl::body CIxiaPortETH::CreateTCPStream { args } {
    Log "Create TCP stream..."
    set retVal $::CIxia::gIxia_OK 
    
    set framelen        64
    set tos             0
    set txmode          0
    set framerate       0
    set utilization     100
    set burstcount      1
    set srcport         2000
    set desport         2000     
    set desmac          ffff-ffff-ffff
    set srcmac          0000-0000-0000
    set desip           0.0.0.0
    set srcip           0.0.0.0
    set _portspeed      100    

    set name            ""
    set vlan            0
    set vlanid          0
    set pri             0
    set priority        0
    set cfi             0
    set type            "08 00"
    set ver         4
    set iphlen      5
    set dscp        0
    set tot         0
    set id          1
    set mayfrag     0
    set lastfrag    0
    set fragoffset  0
    set ttl         255        
    set pro         4
    set change      0
    set enable      true
    set value       {{00 }}
    set strframenum 100
    set seq         0
    set ack         0
    set tcpopt      ""
    set window      0
    set urgent      0  
    set data        0
    set userPattern 0
    set ipmode      0
 

    set udf1                    0
    set udf1Offset              0
    set udf1ContinuousCount     0
    set udf1InitVal             {00}
    set udf1Step                1
    set udf1ChangeMode          0
    set udf1Repeat              1
    set udf1Size                8
    set udf1CounterMode         udfCounterMode
    
    set udf2                    0
    set udf2Offset              0
    set udf2ContinuousCount     0
    set udf2InitVal             {00}
    set udf2Step                1
    set udf2ChangeMode          0
    set udf2Repeat              1
    set udf2Size                8
    set udf2CounterMode         udfCounterMode
    
    #get parameters
    set argList ""
    set temp ""
    for {set i 0} { $i < [llength $args]} {incr i} {
        lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
            append argList " [lindex $tmp_list 0].arg"
        }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val    
    }
    
    set srcmac [::ipaddress::format_mac_address $srcmac 6 ":"]
    set desmac [::ipaddress::format_mac_address $desmac 6 ":"]
    
    #format the IP address from decimal to hex
    set hexSrcIp [split $srcip \.]
    set hexDesIp [split $desip \.]
    for {set i 0} {$i < 4} {incr i} {
        lappend hex1 [format %x [lindex $hexSrcIp $i]]
        lappend hex2 [format %x [lindex $hexDesIp $i]]
    }
    set hexSrcIp [lrange $hex1 0 end]
    set hexDesIp [lrange $hex2 0 end]

    set vlan $vlanid
    set pri  $priority

    #Setting the _streamid.
    set streamCnt 1 
    for {set i 1 } {1} {incr i} {
        if {[stream get $_chassis $_card $_port $i] == 0 } {incr streamCnt} else { break}
    }
    set _streamid $streamCnt

    #Define Stream parameters.
    stream setDefault        
    stream config -enable $enable
    stream config -name $name
    stream config -numBursts $burstcount        
    stream config -numFrames $strframenum
    if { $framerate != 0 } {
        stream config -rateMode streamRateModeFps
        stream config -fpsRate $framerate
    } else {
        stream config -percentPacketRate $utilization
        stream config -rateMode usePercentRate
    }
    stream config -sa $srcmac
    stream config -da $desmac
    switch $txmode {
        0 {stream config -dma contPacket}
        1 {
            stream config -dma stopStream
            stream config -numBursts 1
            stream config -numFrames $burstcount
            stream config -startTxDelayUnit                   0
            stream config -startTxDelay                       0.0
        }
        2 {stream config -dma advance}
        default {error "No such stream transmit mode, please check -strtransmode parameter."}
    }
    
    if {[llength $framelen] == 1} {
        stream config -framesize $framelen
        stream config -frameSizeType sizeFixed
    } else {
        stream config -framesize 318
        stream config -frameSizeType sizeRandom
        stream config -frameSizeMIN [lindex $framelen 0]
        stream config -frameSizeMAX [lindex $framelen 1]
    }
   
    stream config -frameType $type
    
    #Define protocol parameters 
    protocol setDefault        
    protocol config -name ipV4        
    protocol config -ethernetType ethernetII
   
    ip setDefault        
    ip config -ipProtocol ipV4ProtocolTcp
    ip config -identifier   $id

    switch $mayfrag {
        0 {ip config -fragment may}
        1 {ip config -fragment dont}
    }       
    switch $lastfrag {
        0 {ip config -fragment last}
        1 {ip config -fragment more}
    }       

    ip config -fragmentOffset 0
    ip config -ttl $ttl        
    ip config -sourceIpAddr $srcip
    ip config -destIpAddr   $desip
    if [ip set $_chassis $_card $_port] {
        error "Unable to set IP configs to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }

    #Dinfine TCP protocol
    tcp setDefault        
    tcp config -sourcePort $srcport
    tcp config -destPort $desport
    tcp config -sequenceNumber $seq
    tcp config -acknowledgementNumber $ack
    tcp config -window $window
    tcp config -urgentPointer $urgent
    
    if {[llength $tcpopt] != 0} {
        if { $tcpopt > 63 } { 
            error "Error: tcpopt couldn't no more than 63."
            set retVal $::CIxia::gIxia_ERR 
        } else {
            
            set tcpFlag [expr $tcpopt % 2]
            for {set i 2} { $i <= 32} { incr i $i} {
                lappend tcpFlag [expr $tcpopt / $i % 2 ]
            }
        }
        
        for { set i 0} { $i < 6} {incr i} {
            set tmp [lindex $tcpFlag $i]
            if {$tmp} { 
                case $i {
                    0 { tcp config -finished true }
                    1 { tcp config -synchronize true }
                    2 { tcp config -resetConnection true }
                    3 { tcp config -pushFunctionValid true }
                    4 { tcp config -acknowledgeValid true }
                    5 { tcp config -urgentPointerValid true }
                }
            }
        }
    }
    
    

    if [tcp set $_chassis $_card $_port] {
       error "Unable to set Tcp configs to IxHal!"
       set retVal $::CIxia::gIxia_ERR
    }
    
    if {$vlan != 0} {
        protocol config -enable802dot1qTag vlanSingle
        vlan setDefault        
        vlan config -vlanID $vlan
        vlan config -userPriority $pri
        if [vlan set $_chassis $_card $_port] {
                error "Unable to set vlan configs to IxHal!"
                set retVal $::CIxia::gIxia_ERR
        }
    }
    switch $cfi {
        0 {vlan config -cfi resetCFI}
        1 {vlan config -cfi setCFI}
    }
    
    if { $ipmode != 0} {
        if {$ipbitsoffset1 > 7} { set ipbitsoffset1 7 }
        if {$ipbitsoffset2 > 7} { set ipbitsoffset2 7 }
        switch $ipmode {    
            ip_inc_src_ip  {
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp
                set udf1ChangeMode 0
                set udf1Step   $stepcount1                                
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]                                
            }
            ip_inc_dst_ip  { 
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp
                set udf2ChangeMode 0
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]        
            }
            ip_dec_src_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 1
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
            }
            ip_dec_dst_ip  {
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 1
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            ip_inc_src_ip_and_dst_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 0
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
                
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 0
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            ip_dec_src_ip_and_dst_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 1
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
                
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 1
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            default {
                error "Error: no such ipmode, please check your input!"
                set retVal $::CIxia::gIxia_ERR
            }
        }
    }
    
    #UDF Config
    if {$udf1 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf1Offset
        udf config -continuousCount  false
        switch $udf1ChangeMode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
        }
        udf config -bitOffset   $ipbitsoffset1
        udf config -initval $udf1InitVal
        udf config -repeat  $udf1Repeat              
        udf config -step    $udf1Step
        udf config -counterMode   $udf1CounterMode
        udf config -udfSize   $udf1Size
        if {[udf set 1]} {
            error "Error calling udf set 1"
            set retVal $::CIxia::gIxia_ERR
        }
    }
            
    if {$udf2 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf2Offset
        udf config -continuousCount  false
        
        switch $udf2ChangeMode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
        }
        udf config -bitOffset   $ipbitsoffset2
        udf config -initval $udf2InitVal
        udf config -repeat  $udf2Repeat              
        udf config -step    $udf2Step
        udf config -counterMode   $udf2CounterMode
        udf config -udfSize    $udf2Size
        if {[udf set 2]} {
            error "Error calling udf set 2"
            set retVal $::CIxia::gIxia_ERR
        }
    }
 
    
    #Table UDF Config        
    tableUdf setDefault        
    tableUdf clearColumns      
    tableUdf config -enable 0
    # tableUdfColumn setDefault        
    # tableUdfColumn config -formatType formatTypeHex
    # if {$change == 0} {
        # tableUdfColumn config -offset [expr $framelen -5]} else {
        # tableUdfColumn config -offset $change
    # }
    # tableUdfColumn config -size 1
    # tableUdf addColumn         
    # set rowValueList $value
    # tableUdf addRow $rowValueList
    # if [tableUdf set $_chassis $_card $_port] {
        # error "Unable to set tableUdf to IxHal!"
        # set retVal $::CIxia::gIxia_ERR
    # }

    #_port config -speed $_portspeed

    if {$data == 0} {
        stream config -patternType patternTypeRandom
    } else {
        stream config -patternType  nonRepeat
        stream config -pattern $data
        stream config -dataPattern 18
    }
    
    
    # stream set $_chassis $_card $_port $streamID
    # stream write $_chassis $_card $_port $streamID

    if {[string match [config_stream -StreamId $_streamid] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }
    if {[string match [config_port -ConfigType config -NoProtServ ture] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }

    return $retVal
}


###########################################################################################
#@@Proc
#Name: CreateUDPStream
#Desc: set UDP stream
#Args: args
#      -FrameLen: frame length
#      -Utilization: send utilization(percent), default 100
#      -TxMode: send mode,[0|1] 0 - continuous，1 - burst
#      -BurstCount: burst package count
#      -DesMac: destination MAC，default ffff-ffff-ffff
#      -SrcMac: source MAC，default 0-0-0
#      -DesIP: destination ip，default 0.0.0.0
#      -SrcIP: source ip, default 0.0.0.0
#      -Tos: tos，default 0
#       -ipmode: how to change the IP
#               0                          no change (default)
#               ip_inc_src_ip              source IP increment
#               ip_inc_dst_ip              destination IP increment
#               ip_dec_src_ip              source IP decrement
#               ip_dec_dst_ip              destination IP decrement
#               ip_inc_src_ip_and_dst_ip   both source and destination IP increment
#               ip_dec_src_ip_and_dst_ip   both source and destination IP decrement
#       -ipbitsoffset1: bitoffset,0 by default 
#       -ipbitsoffset2: bitoffset,0 by default
#       -ipcount1:  the count that the first ip stream will vary,0 by default 
#      -ipcount2:  the count that the second ip stream will vary,0 by default
#      -stepcount1: the step size that the first ip will vary, it should be the power of 2, eg. 1,2,4,8..., 0 by default means no change
#       -stepcount2: the step size that the second ip will vary,it should be the power of 2, eg. 1,2,4,8..., 0 by default means no change
#      -_portSpeed: _port speed，default 100
#Usage: _port1 CreateUDPStream -SrcMac 0010-01e9-0011 -DesMac ffff-ffff-ffff
###########################################################################################
::itcl::body CIxiaPortETH::CreateUDPStream { args } {
    Log "Create UDP stream..."
    set retVal $::CIxia::gIxia_OK
    
    set framelen            64
    set tos                 0
    set txmode              0
    set framerate           0 
    set utilization         100
    set burstcount          1
    set srcport             2000
    set desport             2000     
    set desmac              ffff-ffff-ffff
    set srcmac              0000-0000-0000
    set desip               0.0.0.0
    set srcip               0.0.0.0
    set _portspeed          100

    set name        ""
    set vlan        0
    set vlanid      0
    set pri         0
    set priority    0
    set cfi         0
    set type        "08 00"
    set ver         4
    set iphlen      5
    set dscp        0
    set tot         0
    set id          1
    set mayfrag     0
    set lastfrag    0
    set fragoffset  0
    set ttl         255        
    set pro         4
    set change      0
    set enable      true
    set value       {{00 }}
    set strframenum  100
    set data        0 
    set ipmode      0
    
    
     set udf1                   0
    set udf1Offset              0
    set udf1ContinuousCount     0
    set udf1InitVal             {00}
    set udf1Step                1
    set udf1ChangeMode          0
    set udf1Repeat              1
    set udf1Size                8
    set udf1CounterMode         udfCounterMode
    
    set udf2                    0
    set udf2Offset              0
    set udf2ContinuousCount     0
    set udf2InitVal             {00}
    set udf2Step                1
    set udf2ChangeMode          0
    set udf2Repeat              1
    set udf2Size                8
    set udf2CounterMode         udfCounterMode
    
    #get parameters
    set argList                 ""
    set temp                    ""
    for {set i 0} { $i < [llength $args]} {incr i} {
        lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
            append argList " [lindex $tmp_list 0].arg"
        }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val    
    }
    
    set srcmac [::ipaddress::format_mac_address $srcmac 6 ":"]
    set desmac [::ipaddress::format_mac_address $desmac 6 ":"]
    
    #format the IP address from decimal to hex
    set hexSrcIp [split $srcip \.]
    set hexDesIp [split $desip \.]
    for {set i 0} {$i < 4} {incr i} {
        lappend hex1 [format %x [lindex $hexSrcIp $i]]
        lappend hex2 [format %x [lindex $hexDesIp $i]]
    }
    set hexSrcIp [lrange $hex1 0 end]
    set hexDesIp [lrange $hex2 0 end]
    
    # get_params $args
    set vlan $vlanid
    set pri  $priority

   #Setting the _streamid.
   set streamCnt 1 
   for {set i 1 } {1} {incr i} {
        if {[stream get $_chassis $_card $_port $i] == 0 } {incr streamCnt} else { break}
   }
   set _streamid $streamCnt


    #Define Stream parameters.
    stream setDefault        
    stream config -enable $enable
    stream config -name $name
    stream config -numBursts $burstcount        
    stream config -numFrames $strframenum
    if { $framerate != 0 } {
        stream config -rateMode streamRateModeFps
    stream config -fpsRate $framerate
    } else {
        stream config -percentPacketRate $utilization
        stream config -rateMode usePercentRate
    }
    stream config -sa $srcmac
    stream config -da $desmac
    switch $txmode {
        0 {stream config -dma contPacket}
        1 {
            stream config -dma stopStream
            stream config -numBursts 1
            stream config -numFrames $burstcount
            stream config -startTxDelayUnit                   0
            stream config -startTxDelay                       0.0
        }
        2 {stream config -dma advance}
        default {error "No such stream transmit mode, please check -strtransmode parameter."}
    }
    
    if {[llength $framelen] == 1} {
        stream config -framesize $framelen
        stream config -frameSizeType sizeFixed
    } else {
        stream config -framesize 318
        stream config -frameSizeType sizeRandom
        stream config -frameSizeMIN [lindex $framelen 0]
        stream config -frameSizeMAX [lindex $framelen 1]
    }
    
    stream config -frameType $type
    
    #Define protocol parameters 
    protocol setDefault        
    protocol config -name ipV4        
    protocol config -ethernetType ethernetII
    
    ip setDefault        
    ip config -ipProtocol ipV4ProtocolUdp
    ip config -identifier   $id
    switch $mayfrag {
        0 {ip config -fragment may}
        1 {ip config -fragment dont}
    }       
    switch $lastfrag {
        0 {ip config -fragment last}
        1 {ip config -fragment more}
    }       

    ip config -fragmentOffset 0
    ip config -ttl $ttl        
    ip config -sourceIpAddr $srcip
    ip config -destIpAddr   $desip
    if [ip set $_chassis $_card $_port] {
        error "Unable to set IP configs to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }
    #Dinfine UDP protocol
    udp setDefault        
    #tcp config -offset 5
    udp config -sourcePort $srcport
    udp config -destPort $desport
    if [udp set $_chassis $_card $_port] {
        error "Unable to set UDP configs to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }
    
    if {$vlan != 0} {
        protocol config -enable802dot1qTag vlanSingle
        vlan setDefault        
        vlan config -vlanID $vlan
        vlan config -userPriority $pri
        if [vlan set $_chassis $_card $_port] {
            error "Unable to set vlan configs to IxHal!"
            set retVal $::CIxia::gIxia_ERR
        }
    }
    switch $cfi {
        0 {vlan config -cfi resetCFI}
        1 {vlan config -cfi setCFI}
    }
    
    #UDF Config
    if { $ipmode != 0} {
        if {$ipbitsoffset1 > 7} { set ipbitsoffset1 7 }
        if {$ipbitsoffset2 > 7} { set ipbitsoffset2 7 }
        switch $ipmode {
            ip_inc_src_ip  {
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp
                set udf1ChangeMode 0
                set udf1Step   $stepcount1                                
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]                                
            }
            ip_inc_dst_ip  { 
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp
                set udf2ChangeMode 0
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]      
            }
            ip_dec_src_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 1
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
            }
            ip_dec_dst_ip  {
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 1
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            ip_inc_src_ip_and_dst_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 0
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
                
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 0
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            ip_dec_src_ip_and_dst_ip  { 
                set udf1 1
                set udf1Offset 26
                set udf1InitVal $hexSrcIp 
                set udf1ChangeMode 1
                set udf1Step $stepcount1
                set udf1Repeat $ipcount1
                set udf1Size [expr 32 - $ipbitsoffset1]    
                
                set udf2 1
                set udf2Offset 30
                set udf2InitVal $hexDesIp 
                set udf2ChangeMode 1
                set udf2Step $stepcount2
                set udf2Repeat $ipcount2
                set udf2Size [expr 32 - $ipbitsoffset2]    
            }
            default {
                error "Error: no such ipmode, please check your input!"
                set retVal $::CIxia::gIxia_ERR
            }
        }
    }
    
    #UDF Config
    if {$udf1 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf1Offset
        udf config -continuousCount  false
        switch $udf1ChangeMode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -bitOffset       $ipbitsoffset1
        udf config -initval         $udf1InitVal
        udf config -repeat          $udf1Repeat              
        udf config -step            $udf1Step
        udf config -counterMode     $udf1CounterMode
        udf config -udfSize         $udf1Size
        if {[udf set 1]} {
            error "Error calling udf set 1"
            set retVal $::CIxia::gIxia_ERR
        }
    }
            
    if {$udf2 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf2Offset
        udf config -continuousCount  false
        
        switch $udf2ChangeMode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
        }
        udf config -bitOffset   $ipbitsoffset2
        udf config -initval $udf2InitVal
        udf config -repeat  $udf2Repeat              
        udf config -step    $udf2Step
        udf config -counterMode   $udf2CounterMode
        udf config -udfSize    $udf2Size
        if {[udf set 2]} {
            error "Error calling udf set 2"
            set retVal $::CIxia::gIxia_ERR
        }
    }
    
    #Table UDF Config        
    tableUdf setDefault        
    tableUdf clearColumns      
    tableUdf config -enable 0
    
    if {$data == 0} {
        stream config -patternType patternTypeRandom
    } else {
        stream config -patternType  nonRepeat
        stream config -pattern $data
        stream config -dataPattern 18
    }
                                 
    
    
    # stream set $_chassis $_card $_port $streamID
    # stream write $_chassis $_card $_port $streamID

    #_port config -speed $_portspeed
        
    if {[string match [config_stream -StreamId $_streamid] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }
    if {[string match [config_port -ConfigType config -NoProtServ ture] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }

    return $retVal
}

###########################################################################################
#@@Proc
#Name: CreateIPv6Stream
#Desc: set IPv6 stream
#Args: 
#       -name:    IP Stream name
#      -frameLen: frame length
#      -utilization: send utilization(percent), default 100
#      -txMode: send mode,[0|1] default 0 - continuous 1 - burst
#      -burstCount: burst package count
#      -desMac: destination MAC default ffff-ffff-ffff
#      -srcMac: source MAC default 0-0-0
#      -_portSpeed: _port speed default 100                   
#       -data: content of frame, 0 by default means random
#             example: -data 0   ,  the data pattern will be random    
#                      -data abac,  use the "abac" as the data pattern
#     -VlanID: default 0
#     -Priority: the priority of vlan, 0 by default
#     -DesIP: the destination ipv6 address,the input format should be X:X::X:X
#     -SrcIP: the source ipv6 address, the input format should be X:X::X:X
#      -nextHeader: the next header, 59 by default
#     -hopLimit: 255 by default
#     -traffClass: 0 by default
#     -flowLable: 0 by default
#
#Usage: _port1 CreateIPv6Stream -SMac 0010-01e9-0011 -DMac ffff-ffff-ffff
###########################################################################################

::itcl::body CIxiaPortETH::CreateIPv6Stream { args } {
    Log  "Create IPv6 stream..."
    set retVal $::CIxia::gIxia_OK

    set framelen   128
    set framerate  0
    set utiliztion 100
    set txmode     0
    set burstcount 1
    set desmac       ffff-ffff-ffff
    set srcmac       0000-0000-0000
    set desip        ::
    set srcip        ::
    set portspeed    100
    set data         0
    set signature    0 

    set name       ""
    set vlan       0
    set vlanid     0
    set pri        0
    set priority   0
    set cfi        0
    #set type      "86 00"
    set ver        6
    set id         0    
    set protocol   41       
    set enable     true
    set value      {{00 }}
    set strframenum    100
    
    set nextheader  59
    set hoplimit    255
    set traffclass  0 
    set flowlabel   0 
            
    set udf1        0
    set udf1offset  0
    set udf1len     1
    set udf1initval {00}
    set udf1step    1
    set udf1changemode 0
    set udf1repeat  1
    
    set udf2        0
    set udf2offset  0
    set udf2len     1
    set udf2initval {00}
    set udf2step    1
    set udf2changemode 0
    set udf2repeat  1
    
    set udf3        0
    set udf3offset  0
    set udf3len     1
    set udf3initval {00}
    set udf3step    1
    set udf3changemode 0
    set udf3repeat  1
    
    set udf4        0
    set udf4offset  0
    set udf4len     1
    set udf4initval {00}
    set udf4step    1
    set udf4changemode 0
    set udf4repeat  1        
    
    set udf5        0
    set udf5offset  0
    set udf5len     1
    set udf5initval {00}
    set udf5step    1
    set udf5changemode 0
    set udf5repeat  1
    
    set tableudf    0 
    set change      0
    
    #get_params $args
        
    set argList     ""
    set temp        ""
    for {set i 0} { $i < [llength $args]} {incr i} {
        lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
            append argList " [lindex $tmp_list 0].arg"
        }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val        
    }
           
    set srcmac [::ipaddress::format_mac_address $srcmac 6 ":"]
    set desmac [::ipaddress::format_mac_address $desmac 6 ":"]
    
    set vlan $vlanid
    set pri  $priority

    #Setting the _streamid.
    set streamCnt 1 
    for {set i 1 } {1} {incr i} {
        if {[stream get $_chassis $_card $_port $i] == 0 } {incr streamCnt} else { break}
    }
    set _streamid $streamCnt
  
    #Define Stream parameters.
    stream setDefault        
    stream config -enable $enable
    stream config -name $name
    stream config -numBursts $burstcount        
    stream config -numFrames $strframenum
    if { $framerate != 0 } {
        stream config -rateMode streamRateModeFps
    stream config -fpsRate $framerate
    } else {
        stream config -percentPacketRate $utiliztion
        stream config -rateMode usePercentRate
    }
    stream config -sa $srcmac
    stream config -da $desmac
    
    switch $txmode {
        0 {stream config -dma contPacket}
        1 {
            stream config -dma stopStream
            stream config -numBursts 1
            stream config -numFrames $burstcount
            stream config -startTxDelayUnit                   0
            stream config -startTxDelay                       0.0
        }
        2 {stream config -dma advance}
        default {error "No such stream transmit mode, please check -strtransmode parameter."}
    }
    
    if {[llength $framelen] == 1} {
        stream config -framesize $framelen
        stream config -frameSizeType sizeFixed
    } else {
        stream config -framesize 318
        stream config -frameSizeType sizeRandom
        stream config -frameSizeMIN [lindex $framelen 0]
        stream config -frameSizeMAX [lindex $framelen 1]
    }
   
    #stream config -frameType $type
    
    #Define protocol parameters 
     protocol setDefault        
     protocol config -name ipV6
     protocol config -ethernetType ethernetII
     
     ipV6 setDefault 
     ipV6 config -sourceAddr $srcip
     ipV6 config -destAddr $desip
     ipV6 config -flowLabel $flowlabel
     ipV6 config -hopLimit  $hoplimit        
     ipV6 config -trafficClass $traffclass
     
     if { $nextheader != 59 } {
        switch $nextheader {
            0  { ipV6 addExtensionHeader ipV6HopByHopOptions}
            43 { ipV6 addExtensionHeader ipV6Routing}
            44 { ipV6 addExtensionHeader ipV6Fragment}
            50 { ipV6 addExtensionHeader ipV6EncapsulatingSecurityPayload}
            51 { ipV6 addExtensionHeader ipV6Authentication}
            60 { ipV6 addExtensionHeader ipV6DestinationOptions}
            6  { ipV6 addExtensionHeader tcp}
            17 { ipV6 addExtensionHeader udp}
            58 { ipV6 addExtensionHeader icmpV6}
            default { IxPuts -red "Wrong nextHeader type!"
                set retVal $::CIxia::gIxia_ERR
            }
        }
    }
    if [ipV6 set $_chassis $_card $_port] {
        IxPuts -red "Unable to set ipV6 configs to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }                 
    
    if {$vlan != 0} {
        protocol config -enable802dot1qTag vlanSingle
        vlan setDefault        
        vlan config -vlanID $vlan
        vlan config -userPriority $pri
        if [vlan set $_chassis $_card $_port] {
            error "Unable to set vlan configs to IxHal!"
            set retVal $::CIxia::gIxia_ERR
        }
    
        switch $cfi {
            0 {vlan config -cfi resetCFI}
            1 {vlan config -cfi setCFI}
        }
    }
    
    #UDF Config
    if {$udf1 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf1offset
        switch $udf1len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf1changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf1initval
        udf config -repeat  $udf1repeat              
        udf config -step    $udf1step
        udf set 1
    }
    if {$udf2 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf2offset
        switch $udf2len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf2changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf2initval
        udf config -repeat  $udf2repeat              
        udf config -step    $udf2step
        udf set 2
    }
    if {$udf3 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf3offset
        switch $udf3len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf3changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf3initval
        udf config -repeat  $udf3repeat              
        udf config -step    $udf3step
        udf set 3
    }
    if {$udf4 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf4offset
        switch $udf4len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf4changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf4initval
        udf config -repeat  $udf4repeat              
        udf config -step    $udf4step
        udf set 4
    }
    if {$udf5 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf5offset
        switch $udf5len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf5changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf5initval
        udf config -repeat  $udf5repeat              
        udf config -step    $udf5step
        udf set 5
    }        
    
    #Table UDF Config        
    if { $tableudf == 1 } {
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        if {$change == 0} {
            tableUdfColumn config -offset [expr $framelen -5]} else {
            tableUdfColumn config -offset $change
        }
        tableUdfColumn config -size 1
        tableUdf addColumn         
        set rowValueList $value
        tableUdf addRow $rowValueList
        if [tableUdf set $_chassis $_card $_port] {
            error "Unable to set tableUdf to IxHal!"
            set retVal $::CIxia::gIxia_ERR
        }
    } 
     
    # #data content    
    if {$data == 0} {
        stream config -patternType patternTypeRandom
    } else {stream config -patternType  nonRepeat
        stream config -pattern $data
        stream config -dataPattern 18
    }

    #port config -speed $portspeed
    if [stream set $_chassis $_card $_port $_streamid] {
        error "Stream set $_chassis $_card $_port $_streamid error"
        set retVal $::CIxia::gIxia_ERR
    }
    
    if  [stream write $_chassis $_card $_port $_streamid] {
        error "Stream write $_chassis $_card $_port $_streamid error"
        set retVal $::CIxia::gIxia_ERR
    }
    
    return $retVal
}


###########################################################################################
#@@Proc
#Name: CreateIPv6TCPStream
#Desc: set IPv6 TCP stream
#Args: 
#       -name:    IP Stream name
#      -frameLen: frame length
#      -utilization: send utilization(percent), default 100
#      -txMode: send mode,[0|1] default 0 - continuous 1 - burst
#      -burstCount: burst package count
#      -desMac: destination MAC default ffff-ffff-ffff
#      -srcMac: source MAC default 0-0-0
#      -_portSpeed: _port speed default 100                   
#       -data: content of frame, 0 by default means random
#             example: -data 0   ,  the data pattern will be random    
#                      -data abac,  use the "abac" as the data pattern
#     -VlanID: default 0
#     -Priority: the priority of vlan, 0 by default
#     -DesIP: the destination ipv6 address,the input format should be X:X::X:X
#     -SrcIP: the source ipv6 address, the input format should be X:X::X:X
#      -nextHeader: the next header, 59 by default
#     -hopLimit: 255 by default
#     -traffClass: 0 by default
#     -flowLable: 0 by default
#      -ipmode: how to change the IP
#               0                          no change (default)
#               ip_inc_src_ip              source IP increment
#               ip_inc_dst_ip              destination IP increment
#               ip_dec_src_ip              source IP decrement
#               ip_dec_dst_ip              destination IP decrement
#               ip_inc_src_ip_and_dst_ip   both source and destination IP increment
#               ip_dec_src_ip_and_dst_ip   both source and destination IP decrement
#      -ipcount1:  the count that the first ip stream will vary,0 by default 
#     -ipcount2:  the count that the second ip stream will vary,0 by default
#     -stepcount1: the step size that the first ip will vary, it should be the power of 2, eg. 1,2,4,8..., 0 by default means no change
#      -stepcount2: the step size that the second ip will vary,it should be the power of 2, eg. 1,2,4,8..., 0 by default means no change
#     -srcport: TCP source port , 2000 by default
#     -desport: TCP destination port, 2000 by default
#      -tcpseq:  TCP sequenceNumber, 123456 by default
#     -tcpack:  TCP acknowledgementNumber, 234567 by default
#     -tcpopts: TCP Flag, 16 (push) by default 
#     -tcpwindow: TCP window, 4096 by default
#
#Usage: port1 CreateIPv6TCPStream -SMac 0010-01e9-0011 -DMac ffff-ffff-ffff
###########################################################################################

::itcl::body CIxiaPortETH::CreateIPv6TCPStream { args } {
    Log  "Create IPv6 TCP stream..."
    set retVal $::CIxia::gIxia_OK

    set framelen   128
    set framerate  0
    set utiliztion 100
    set txmode     0
    set burstcount 1
    set desmac       ffff-ffff-ffff
    set srcmac       0000-0000-0000
    set desip        ::
    set srcip        ::
    set portspeed  100
    set data 0
    set signature 0 

    set name      ""
    set vlan       0
    set vlanid     0
    set pri        0
    set priority   0
    set cfi        0
    set ver        6
    set id         1    
    set protocol   41       
    set enable     true
    set value      {{00 }}
    set strframenum    100
   
    set nextheader  6
    set hoplimit   255
    set traffclass  0 
    set flowlabel   0 
    set ipmode 0
    set ipcount1 1 
    set ipcount2 1 
    set stepcount1 1 
    set stepcount2 1 
    
    set udf1       0
    set udf1offset 0
    set udf1len    1
    set udf1initval {00}
    set udf1step    1
    set udf1changemode 0
    set udf1repeat  1
    
    set udf2       0
    set udf2offset 0
    set udf2len    1
    set udf2initval {00}
    set udf2step    1
    set udf2changemode 0
    set udf2repeat  1
    
    set udf3       0
    set udf3offset 0
    set udf3len    1
    set udf3initval {00}
    set udf3step    1
    set udf3changemode 0
    set udf3repeat  1
    
    set udf4       0
    set udf4offset 0
    set udf4len    1
    set udf4initval {00}
    set udf4step    1
    set udf4changemode 0
    set udf4repeat  1        
    
    set udf5       0
    set udf5offset 0
    set udf5len    1
    set udf5initval {00}
    set udf5step    1
    set udf5changemode 0
    set udf5repeat  1
    
    set tableudf 0 
    set change   0
    
    set srcport 2000
    set desport 2000 
    set tcpseq 123456
    set tcpack 234567
    set tcpopts 16 
    set tcpwindow 4096
    set tcpFlag ""
    
    
    #get_params $args
    
    set argList ""
    set temp ""
    for {set i 0} { $i < [llength $args]} {incr i} {
    lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
                append argList " [lindex $tmp_list 0].arg"
        }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val        
    }
   
   
    set srcmac [::ipaddress::format_mac_address $srcmac 6 ":"]
    set desmac [::ipaddress::format_mac_address $desmac 6 ":"]

    set vlan $vlanid
    set pri  $priority


    #Setting the _streamid.
    set streamCnt 1 
    for {set i 1 } {1} {incr i} {
        if {[stream get $_chassis $_card $_port $i] == 0 } {incr streamCnt} else { break}
    }
    set _streamid $streamCnt


    #Define Stream parameters.
    stream setDefault        
    stream config -enable $enable
    stream config -name $name
    stream config -numBursts $burstcount        
    stream config -numFrames $strframenum
    if { $framerate != 0 } {
        stream config -rateMode streamRateModeFps
        stream config -fpsRate $framerate
    } else {
        stream config -percentPacketRate $utiliztion
        stream config -rateMode usePercentRate
    }
    stream config -sa $srcmac
    stream config -da $desmac
   
    switch $txmode {
        0 {stream config -dma contPacket}
        1 { stream config -dma stopStream
            stream config -numBursts 1
            stream config -numFrames $burstcount
            stream config -startTxDelayUnit                   0
            stream config -startTxDelay                       0.0
        }
       2 {stream config -dma advance}
       default {error "No such stream transmit mode, please check -strtransmode parameter."}
    }
   
    if {[llength $framelen] == 1} {
        stream config -framesize $framelen
        stream config -frameSizeType sizeFixed
    } else {
        stream config -framesize 318
        stream config -frameSizeType sizeRandom
        stream config -frameSizeMIN [lindex $framelen 0]
        stream config -frameSizeMAX [lindex $framelen 1]
    }
  
    #stream config -frameType $type   
    #Define protocol parameters 
    protocol setDefault        
    protocol config -name ipV6
    protocol config -ethernetType ethernetII
    
    ipV6 setDefault 
    ipV6 config -sourceAddr $srcip
    ipV6 config -destAddr $desip
    ipV6 config -flowLabel $flowlabel
    ipV6 config -hopLimit  $hoplimit        
    ipV6 config -trafficClass $traffclass
    
    switch $ipmode {
        0   {ipV6 config -sourceAddrMode ipV6Idle
            ipV6 config -destAddrMode ipV6Idle
        }
        ip_inc_src_ip {
            ipV6 config -sourceAddrMode ipV6IncrHost 
            ipV6 config -sourceAddrRepeatCount $ipcount1
            ipV6 config -sourceStepSize $stepcount1
        }
        ip_inc_dst_ip {
            ipV6 config -destAddrMode ipV6IncrHost 
            ipV6 config -destAddrRepeatCount $ipcount2
            ipV6 config -destStepSize $stepcount2
        }
        ip_dec_src_ip {
            ipV6 config -sourceAddrMode ipV6DecrHost 
            ipV6 config -sourceAddrRepeatCount $ipcount1
            ipV6 config -sourceStepSize $stepcount1                        
        }
        ip_dec_dst_ip {
            ipV6 config -destAddrMode ipV6DecrHost 
            ipV6 config -destAddrRepeatCount $ipcount2
            ipV6 config -destStepSize $stepcount2
        }
        ip_inc_src_ip_and_dst_ip {
            ipV6 config -sourceAddrMode ipV6IncrHost
            ipV6 config -destAddrMode ipV6IncrHost
            ipV6 config -sourceAddrRepeatCount $ipcount1
            ipV6 config -sourceStepSize $stepcount1                        
            ipV6 config -destAddrRepeatCount $ipcount2
            ipV6 config -destStepSize $stepcount2                                    
        }
        ip_dec_src_ip_and_dst_ip {
            ipV6 config -sourceAddrMode ipV6DecrHost
            ipV6 config -destAddrMode ipV6DecrHost
            ipV6 config -sourceAddrRepeatCount $ipcount1
            ipV6 config -sourceStepSize $stepcount1                        
            ipV6 config -destAddrRepeatCount $ipcount2
            ipV6 config -destStepSize $stepcount2    
        }
        default {
            set usage "ip_inc_src_ip,ip_inc_dst_ip,ip_dec_src_ip,ip_dec_dst_ip ,ip_inc_src_ip_and_dst_ip,ip_dec_src_ip_and_dst_ip"
            error "Error: ipmode should be $usage. "
            set retVal $::CIxia::gIxia_ERR 
        }
    }
    
    ipV6 config -nextHeader tcp
    if [ipV6 set $_chassis $_card $_port] {
        error  "Unable to set ipV6 configs to IxHal!"
        set retVal $::CIxia::gIxia_ERR 
    }                 
   
    if {$vlan != 0} {
       protocol config -enable802dot1qTag vlanSingle
       vlan setDefault        
       vlan config -vlanID $vlan
       vlan config -userPriority $pri
       if [vlan set $_chassis $_card $_port] {
           error "Unable to set vlan configs to IxHal!"
           set retVal $::CIxia::gIxia_ERR 
       }
   
       switch $cfi {
           0 {vlan config -cfi resetCFI}
           1 {vlan config -cfi setCFI}
       }
    }


   

    #TCP settings
    tcp setDefault
    tcp config -sourcePort $srcport
    tcp config -destPort $desport
    tcp config -useValidChecksum true
    tcp config -sequenceNumber $tcpseq
    tcp config -acknowledgementNumber $tcpack
    tcp config -window $tcpwindow
   
    if { $tcpopts > 63} { 
        error "Error: tcpopts couldn't no more than 63."
        set retVal $::CIxia::gIxia_ERR 
    } else {
        lappend tcpFlag [expr $tcpopts % 2 ]
        for {set i 1} { $i < 6} { incr i} {
           lappend tcpFlag [expr ($tcpopts / (2 * $i )) % 2 ]
        }
    }
   
    for { set i 0} { $i < 6} {incr i} {
        set tmp [lindex $tcpFlag $i]
        if {$tmp} { 
            case $i {
                0 { tcp config -finished true }
                1 { tcp config -synchronize true }
                2 { tcp config -resetConnection true }
                3 { tcp config -pushFunctionValid true }
                4 { tcp config -acknowledgeValid true }
                5 { tcp config -urgentPointerValid true }
            }
        }
    }
   
    if {[tcp set $_chassis $_card $_port ]} {
        error "Error setting tcp on port $_chassis.$_card.$_port"
        set retVal $::CIxia::gIxia_ERR 
    }
   
   
    #UDF Config
    if {$udf1 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf1offset
        switch $udf1len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf1changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf1initval
        udf config -repeat  $udf1repeat              
        udf config -step    $udf1step
        udf set 1
    }
    if {$udf2 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf2offset
        switch $udf2len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf2changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf2initval
        udf config -repeat  $udf2repeat              
        udf config -step    $udf2step
        udf set 2
    }
    if {$udf3 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf3offset
        switch $udf3len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf3changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf3initval
        udf config -repeat  $udf3repeat              
        udf config -step    $udf3step
        udf set 3
    }
    if {$udf4 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf4offset
        switch $udf4len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf4changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf4initval
        udf config -repeat  $udf4repeat              
        udf config -step    $udf4step
        udf set 4
    }
    if {$udf5 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf5offset
        switch $udf5len {
             1 { udf config -countertype c8  }                
             2 { udf config -countertype c16 }               
             3 { udf config -countertype c24 }                
             4 { udf config -countertype c32 }
        }
        switch $udf5changemode {
             0 {udf config -updown uuuu}
             1 {udf config -updown dddd}
        }
        udf config -initval $udf5initval
        udf config -repeat  $udf5repeat              
        udf config -step    $udf5step
        udf set 5
    }        
   
    #Table UDF Config        
    if { $tableudf == 1 } {
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        if {$change == 0} {
            tableUdfColumn config -offset [expr $framelen -5]} else {
            tableUdfColumn config -offset $change
        }
        tableUdfColumn config -size 1
        tableUdf addColumn         
        set rowValueList $value
        tableUdf addRow $rowValueList
        if [tableUdf set $_chassis $_card $_port] {
            error "Unable to set tableUdf to IxHal!"
            set retVal 1
        }
    } 
    
    # #data content    
    if {$data == 0} {
        stream config -patternType patternTypeRandom
    } else {stream config -patternType  nonRepeat
        stream config -pattern $data
        stream config -dataPattern 18
    }
    #port config -speed $portspeed
    if [stream set $_chassis $_card $_port $_streamid] {
        error "Stream set $_chassis $_card $_port $_streamid error"
        set retVal $::CIxia::gIxia_ERR 
    }
   
    if  [stream write $_chassis $_card $_port $_streamid] {
        error "Stream write $_chassis $_card $_port $_streamid error"
        set retVal $::CIxia::gIxia_ERR 
    }
   
    return $retVal
}

###########################################################################################
#@@Proc
#Name: CreateIPv6UDPStream
#Desc: set IPv6 UDP stream
#Args: 
#       -name:    IP Stream name
#      -frameLen: frame length
#      -utilization: send utilization(percent), default 100
#      -txMode: send mode,[0|1] default 0 - continuous 1 - burst
#      -burstCount: burst package count
#      -desMac: destination MAC default ffff-ffff-ffff
#      -srcMac: source MAC default 0-0-0
#      -_portSpeed: _port speed default 100                   
#       -data: content of frame, 0 by default means random
#             example: -data 0   ,  the data pattern will be random    
#                      -data abac,  use the "abac" as the data pattern
#     -VlanID: default 0
#     -Priority: the priority of vlan, 0 by default
#     -DesIP: the destination ipv6 address,the input format should be X:X::X:X
#     -SrcIP: the source ipv6 address, the input format should be X:X::X:X
#      -nextHeader: the next header, 59 by default
#     -hopLimit: 255 by default
#     -traffClass: 0 by default
#     -flowLabel: 0 by default
#     -srcport: UDP source port , 2000 by default
#     -desport: UDP destination port, 2000 by default
#
#Usage: port1 CreateIPv6UDPStream -SMac 0010-01e9-0011 -DMac ffff-ffff-ffff
###########################################################################################


::itcl::body CIxiaPortETH::CreateIPv6UDPStream { args } {
    Log  "Create IPv6 udp stream..."
    set retVal $::CIxia::gIxia_OK

    set framelen   128
    set framerate  0
    set utiliztion 100
    set txmode     0
    set burstcount 1
    set desmac       ffff-ffff-ffff
    set srcmac       0000-0000-0000
    set desip        ::
    set srcip        ::
    set portspeed   100
    set data        0
    set signature   0 

    set name       ""
    set vlan       0
    set vlanid     0
    set pri        0
    set priority   0
    set cfi        0
    set ver        6
    set id         1    
    set protocol   41       
    set enable     true
    set value      {{00 }}
    set strframenum    100
    
    set hoplimit    255
    set traffclass  0 
    set flowlabel   0 
    
    
    set udf1       0
    set udf1offset 0
    set udf1len    1
    set udf1initval {00}
    set udf1step    1
    set udf1changemode 0
    set udf1repeat  1
    
    set udf2       0
    set udf2offset 0
    set udf2len    1
    set udf2initval {00}
    set udf2step    1
    set udf2changemode 0
    set udf2repeat  1
    
    set udf3       0
    set udf3offset 0
    set udf3len    1
    set udf3initval {00}
    set udf3step    1
    set udf3changemode 0
    set udf3repeat  1
    
    set udf4       0
    set udf4offset 0
    set udf4len    1
    set udf4initval {00}
    set udf4step    1
    set udf4changemode 0
    set udf4repeat  1        
    
    set udf5       0
    set udf5offset 0
    set udf5len    1
    set udf5initval {00}
    set udf5step    1
    set udf5changemode 0
    set udf5repeat  1
    
    set tableudf 0 
    set change   0
    
    set desport 2000
    set srcport  2000 
  
    #get_params $args
    
    set argList ""
    set temp ""
    for {set i 0} { $i < [llength $args]} {incr i} {
        lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
            append argList " [lindex $tmp_list 0].arg"
        }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val        
    }
     
     
    set srcmac [::ipaddress::format_mac_address $srcmac 6 ":"]
    set desmac [::ipaddress::format_mac_address $desmac 6 ":"]
 
    set vlan $vlanid
    set pri  $priority

    #Setting the _streamid.
    set streamCnt 1 
    for {set i 1 } {1} {incr i} {
        if {[stream get $_chassis $_card $_port $i] == 0 } {incr streamCnt} else { break}
    }
    set _streamid $streamCnt
     
    #Define Stream parameters.
    stream setDefault        
    stream config -enable $enable
    stream config -name $name
    stream config -numBursts $burstcount        
    stream config -numFrames $strframenum
    if { $framerate != 0 } {
        stream config -rateMode streamRateModeFps
    stream config -fpsRate $framerate
    } else {
        stream config -percentPacketRate $utiliztion
        stream config -rateMode usePercentRate
    }
    stream config -sa $srcmac
    stream config -da $desmac
    
    switch $txmode {
        0 {stream config -dma contPacket}
        1 { stream config -dma stopStream
            stream config -numBursts 1
            stream config -numFrames $burstcount
            stream config -startTxDelayUnit                   0
            stream config -startTxDelay                       0.0
        }
        2 {stream config -dma advance}
        default {error "No such stream transmit mode, please check -strtransmode parameter."
            set retVal $::CIxia::gIxia_ERR
        }
    }
    
    if {[llength $framelen] == 1} {
        stream config -framesize $framelen
        stream config -frameSizeType sizeFixed
    } else {
        stream config -framesize 318
        stream config -frameSizeType sizeRandom
        stream config -frameSizeMIN [lindex $framelen 0]
        stream config -frameSizeMAX [lindex $framelen 1]
    }
    
    #stream config -frameType $type
    #Define protocol parameters 
    protocol setDefault        
    protocol config -name ipV6
    protocol config -ethernetType ethernetII
    ipV6 setDefault 
    ipV6 config -sourceAddr $srcip
    ipV6 config -destAddr $desip
    ipV6 config -flowLabel $flowlabel
    ipV6 config -hopLimit  $hoplimit        
    ipV6 config -trafficClass $traffclass
    ipV6 config -nextHeader udp
    
    if [ipV6 set $_chassis $_card $_port] {
        IxPuts -red "Unable to set ipV6 configs to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }          
    
    udp setDefault
    udp config -sourcePort $srcport
    udp config -destPort $desport
    
    if {[udp set $_chassis $_card $_port]} {
       error "Error udp set $_chassis $_card $_port"
       set retVal $::CIxia::gIxia_ERR 
   }
   
   if {$vlan != 0} {
       protocol config -enable802dot1qTag vlanSingle
       vlan setDefault        
       vlan config -vlanID $vlan
       vlan config -userPriority $pri
       if [vlan set $_chassis $_card $_port] {
           error "Unable to set vlan configs to IxHal!"
           set retVal $::CIxia::gIxia_ERR
       }
   
       switch $cfi {
           0 {vlan config -cfi resetCFI}
           1 {vlan config -cfi setCFI}
       }
   }
     
    #UDF Config
    if {$udf1 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf1offset
        switch $udf1len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf1changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf1initval
        udf config -repeat  $udf1repeat              
        udf config -step    $udf1step
        udf set 1
    }
    if {$udf2 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf2offset
        switch $udf2len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf2changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf2initval
        udf config -repeat  $udf2repeat              
        udf config -step    $udf2step
        udf set 2
    }
    if {$udf3 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf3offset
        switch $udf3len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf3changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf3initval
        udf config -repeat  $udf3repeat              
        udf config -step    $udf3step
        udf set 3
    }
    if {$udf4 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf4offset
        switch $udf4len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf4changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf4initval
        udf config -repeat  $udf4repeat              
        udf config -step    $udf4step
        udf set 4
    }
    if {$udf5 == 1} {
        udf setDefault        
        udf config -enable true
        udf config -offset $udf5offset
        switch $udf5len {
            1 { udf config -countertype c8  }                
            2 { udf config -countertype c16 }               
            3 { udf config -countertype c24 }                
            4 { udf config -countertype c32 }
        }
        switch $udf5changemode {
            0 {udf config -updown uuuu}
            1 {udf config -updown dddd}
        }
        udf config -initval $udf5initval
        udf config -repeat  $udf5repeat              
        udf config -step    $udf5step
        udf set 5
    }        
     
    #Table UDF Config        
    if { $tableudf == 1 } {
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        if {$change == 0} {
            tableUdfColumn config -offset [expr $framelen -5]} else {
            tableUdfColumn config -offset $change
        }
        tableUdfColumn config -size 1
        tableUdf addColumn         
        set rowValueList $value
        tableUdf addRow $rowValueList
        if [tableUdf set $_chassis $_card $_port] {
            error "Unable to set tableUdf to IxHal!"
            set retVal $::CIxia::gIxia_ERR
        }
    } 
      
    # #data content    
    if {$data == 0} {
        stream config -patternType patternTypeRandom
    } else {
        stream config -patternType  nonRepeat
        stream config -pattern $data
        stream config -dataPattern 18
    }
     
    #port config -speed $portspeed
    if [stream set $_chassis $_card $_port $_streamid] {
        error "Stream set $_chassis $_card $_port $_streamid error"
        set retVal $::CIxia::gIxia_ERR
    }
    
    if  [stream write $_chassis $_card $_port $_streamid] {
        error "Stream write $_chassis $_card $_port $_streamid error"
        set retVal $::CIxia::gIxia_ERR
    }
     
    return $retVal
}


###########################################################################################
#@@Proc
#Name: SetErrorPacket
#Desc: set Error packet
#Args: 
#     -crc     : enable CRC error
#     -align   : enable align error
#     -dribble : enable dribble error
#     -jumbo   : enable jumbo error
#Usage: port1 SetErrorPacket -crc 1
###########################################################################################
::itcl::body CIxiaPortETH::SetErrorPacket {args} {
    Log   "set errors packet..."
    set retVal $::CIxia::gIxia_OK
  
    set tmpList     [lrange $args 0 end]
    set idxxx      0
    set tmpllength [llength $tmpList]

    #  Set the defaults
    set Default    0
    set Crc        1
    set Nocrc      0
    set Dribble    0
    set Align      0
    set Jumbo      0
    
    # puts $tmpllength
    while { $tmpllength > 0  } {
        set cmdx [string tolower [lindex $args $idxxx]]
        #set argx [lindex $args [expr $idxxx + 1]]
       
        case $cmdx   {
            -crcerror      { set Crc 1 }
            -dribblebits  {set Dribble 1}
            -alignerror    {set Align 1}
            -jumbo    {set Jumbo 1}
            
            default   {
                set retVal $::CIxia::gIxia_ERR
                IxPuts -red "Error : cmd option $cmdx does not exist"
                return $retVal
            }
        }
        # incr idxxx  +2
        # incr tmpllength -2
        incr idxxx  +1
        incr tmpllength -1
    }

    if {[stream get $_chassis $_card $_port $_streamid]} {
        set retVal $::CIxia::gIxia_ERR
        IxPuts -red "Unable to retrive config of No.$_streamid stream from $_chassis $_card $_port!"
    }
    
    if {$Crc == 1} {
        set Default 1
        stream config -fcs 3
    }
    if {$Dribble == 1} {
        set Default 1
        stream config -fcs 2
    }
    if {$Align == 1} {
        stream config -fcs 1
    } 
    if {$Jumbo == 1} {
        set Default 1
        stream config -framesize 9000                
    }
    
    if {$Default == 0} {
        stream config -fcs 0
    }
    
    if [stream set $_chassis $_card $_port $_streamid] {
        IxPuts -red "Unable to set streams to IxHal!"
        set retVal  $::CIxia::gIxia_ERR
    }

    if [stream write $_chassis $_card $_port $_streamid] {
        IxPuts -red "Unable to write streams to IxHal!"
        set retVal  $::CIxia::gIxia_ERR
    }
    
    return $retVal
}  

###########################################################################################
#@@Proc
#Name: SetFlowCtrlMode
#Desc: set the flow control mode on a port
#Args: 
#     1   enable
#     0   disable
#Usage: port1 SetFlowCtrlMode 1
###########################################################################################
::itcl::body CIxiaPortETH::SetFlowCtrlMode {args} {
    Log   "set flow control mode..."
    set retVal $::CIxia::gIxia_OK

    # enable flow control
    if { [llength $args] > 0} {
        set FlowCtrlMode $args
    } else { 
        set FlowCtrlMode 1
    }
    set tmp [llength $args]
    port config -flowControl $FlowCtrlMode

    # type of flow control
    if {$FlowCtrlMode == 1}  {
        port config -autonegotiate  true
        port config -advertiseAbilities 0
    } 
    
    if { [port set $_chassis $_card $_port] } {
        IxPuts -red "failed to set port configuration on port $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }

    lappend portList [list $_chassis $_card $_port]
    if [ixWritePortsToHardware portList -noProtocolServer] {
        IxPuts -red "Can't write config to $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR   
    }    
    
    return $retVal
}
    

###########################################################################################
#@@Proc
#Name: DeleteAllStream
#Desc: to delete all streams of the target port
#Args: no
#Usage: port1 DeleteAllStream
###########################################################################################
::itcl::body CIxiaPortETH::DeleteAllStream {} {
    Log "Delete all streams of $_chassis $_card $_port..."
    set retVal $::CIxia::gIxia_OK
    puts "Delete all streams of $_chassis $_card $_port..."
    set num 1

    while { [stream get $_chassis $_card $_port $num ] != 1 } {
        incr num
    }

    for { set i 1 } { $i < $num} { incr i} {
        if [stream remove $_chassis $_card $_port $i] {
            error "Error remove the stream of $_chassis $_card $_port"
            set retVal $::CIxia::gIxia_ERR
        } 
    }
    set _streamid 1
    
    if {[string match [config_port -ConfigType config] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }
    
    return $retVal 
}

###########################################################################################
#@@Proc
#Name: SetMultiModifier
#Desc: change multi-field value in the existing stream
#Args: 
#     -srcmac {mode step count}
#       -desmac {mode step count}
#      -srcip  {mode step count}
#      -desip  {mode step count}
#      -srcport  {mode step count}
#      -desport {mode step count}
#     mode: 
#     random incr decr list
#    
#Usage: port1 SetMultiModifier -srcmac {incr 1 16}
###########################################################################################
::itcl::body CIxiaPortETH::SetMultiModifier {args} {    
    Log   "set multi-field value..."
    set retVal $::CIxia::gIxia_OK
   
    set srcMac      ""
    set desMac      ""
    set srcIp       "" 
    set desIp       ""
    set srcPort     ""
    set desPort     ""
    set counterIndex 0
   
    set udf1                0
    set udf1Offset          0
    set udf1ContinuousCount 0
    set udf1InitVal         {00}
    set udf1Step            1
    set udf1UpDown          "uuuu"
    set udf1Repeat          1
    set udf1Size            8
    set udf1CounterMode     udfCounterMode
    
    set udf2                0
    set udf2Offset          0
    set udf2ContinuousCount 0
    set udf2InitVal         {00}
    set udf2Step            1
    set udf2UpDown          "uuuu"
    set udf2Repeat          1
    set udf2Size            8
    set udf2CounterMode     udfCounterMode
    
    set udf3                0
    set udf3Offset          0
    set udf3ContinuousCount 0
    set udf3InitVal         {00}
    set udf3Step            1
    set udf3UpDown          "uuuu"
    set udf3Repeat          1
    set udf3Size            8
    set udf3CounterMode     udfCounterMode
 
    set udf4                0
    set udf4Offset          0
    set udf4ContinuousCount 0
    set udf4InitVal         {00}
    set udf4Step            1
    set udf4UpDown          "uuuu"
    set udf4Repeat          1
    set udf4Size            8
    set udf4CounterMode     udfCounterMode        
    set tableUdf            0
    
    set tmpList             [lrange $args 0 end]
    set idxxx               0
    set tmpllength          [llength $tmpList]
    #  Set the defaults
    set Default    1

    # puts $tmpllength
    while { $tmpllength > 0  } {
        set cmdx [string toupper [lindex $args $idxxx]]
        set argx [string toupper [lindex $args [expr $idxxx + 1]]]
    
        case $cmdx   {
            -SRCMAC      { set srcMac $argx}
            -DESMAC      {set desMac $argx }
            -SRCIP       {set srcIp $argx  }
            -DESIP       {set desIp $argx  }
            -SRCPORT     {set srcPort $argx}
            -DESPORT     {set desPort $argx}
            default   {
                set retVal $::CIxia::gIxia_ERR
                error  "Error : cmd option $cmdx does not exist"
                return $retVal
            }
        }
        incr idxxx  +2
        incr tmpllength -2
    }
    
    if {[stream get $_chassis $_card $_port $_streamid]} {
        set retVal $::CIxia::gIxia_ERR
        error  "Unable to retrive config of No.$_streamid stream from $_chassis $_card $_port!"
    }
    
    if {$srcMac != ""} {
        set tmp [lindex $srcMac 0]
        case $tmp {
            RANDOM { stream config -saRepeatCounter ctrRandom}
            INCR {
                stream config -saRepeatCounter increment
                stream config -saStep [lindex $srcMac 1]
                stream config -numSA [lindex $srcMac 2]
            }
            DECR {
                stream config -saRepeatCounter decrement
                stream config -saStep [lindex $srcMac 1]
                stream config -numSA [lindex $srcMac 2]
            }
            LIST {     
                set tableUdf 1 
                for {set i 1} { [lindex $srcMac $i] != ""} {incr i} {
                    set tmpSrcMac1 [lindex $srcMac $i] 
                    regsub -all --  {-} $tmpSrcMac1 {} tmpSrcMac1
                    regsub -all { } $tmpSrcMac1 {} tmpSrcMac1
                    lappend tmpSrcMac $tmpSrcMac1
                }
                # set tmpMac [lrange $tmpMac 1 end]
                lappend tmpSrcMac  6 6 formatTypeMAC
                set tableList(srcMac) $tmpSrcMac
            }
        }
    }
    
    
    if {$desMac != ""} {
        set tmp [lindex $desMac 0]
        case $tmp {
            RANDOM { stream config -daRepeatCounter ctrRandom}
            INCR {
                stream config -daRepeatCounter increment
                stream config -daStep [lindex $desMac 1]
                stream config -numDA [lindex $desMac 2]
            }
            DECR {
                stream config -daRepeatCounter decrement
                stream config -daStep [lindex $desMac 1]
                stream config -numDA [lindex $desMac 2]
            }
            LIST {     
                set tableUdf 1 
                for {set i 1} { [lindex $desMac $i] != ""} {incr i} {
                    set tmpDesMac1 [lindex $desMac $i]
                    regsub -all --  {-} $tmpDesMac1 {} tmpDesMac1
                    regsub -all { } $tmpDesMac1 {} tmpDesMac1
                    lappend tmpDesMac $tmpDesMac1
                }
                # set tmpMac [lrange $tmpMac 1 end]
                lappend tmpDesMac 0 6 formatTypeMAC
                set tableList(desMac) $tmpDesMac
            }
        }
    }
    
    if {$srcIp != ""} {
        set udf1 1
        if { [stream cget -frameType] == "08 00"} {    
            set udf1Offset 26                    
            set udf1InitVal [lrange [stream cget -packetView] 26 29]
        } else {
            set udf1Offset 34                    
            set udf1InitVal [lrange [stream cget -packetView] 34 37]
        }
        set udf1Step [lindex $srcIp 1]
        set udf1Repeat [lindex $srcIp 2]
        set udf1CounterMode udfCounterMode
        set udf1Size 32
            
        set tmpIp [lindex $srcIp 0]
        case $tmpIp {
            RANDOM { set udf1CounterMode udfRandomMode}
            INCR { set udf1UpDown "uuuu"   }
            DECR { set udf1UpDown "duuu"   }
            LIST { set udf1 0
                   set tableUdf 1
                   set tmpIp [lrange $srcIp 1 end]
                   if { $udf1Offset == 34 } {
                        lappend tmpIp 22 16 formatTypeIPv6
                    } else {
                        lappend tmpIp 26 4 formatTypeIPv4
                        }
                   set tableList(srcIp) $tmpIp
            }
        }            
    }
                 
    if {$desIp != ""} {
        set udf2 1
        if { [stream cget -frameType] == "08 00"} { 
            set udf2Offset 30                    
            set udf2InitVal [lrange [stream cget -packetView] 30 33]
        } else {
            set udf2Offset 50                    
            set udf2InitVal [lrange [stream cget -packetView] 50 53]
        }
        set udf2Step [lindex $desIp 1]
        set udf2Repeat [lindex $desIp 2]
        set udf2CounterMode udfCounterMode
        set udf2Size 32
                
        set tmpIp [lindex $desIp 0]
        case $tmpIp {   
            RANDOM { set udf2CounterMode udfRandomMode}
            INCR { set udf2UpDown "uuuu"   }
            DECR { set udf2UpDown "duuu"   }
            LIST {
                set udf2 0
                set tableUdf 1
                set tmpIp [lrange $desIp 1 end]
                if { $udf2Offset == 50 } {
                    lappend tmpIp 38 16    formatTypeIPv6
                } else {
                    lappend tmpIp 30 4 formatTypeIPv4
                }
                set tableList(desIp) $tmpIp
            }      
        }       
    }    

    if {$srcPort != ""} {
        set udf3 1         
        set udf3Offset 54                    
        set udf3InitVal [lrange [stream cget -packetView] 54 55]
        set udf3Step [lindex $srcPort 1]
        set udf3Repeat [lindex $srcPort 2]
        set udf3CounterMode udfCounterMode
        set udf3Size 16
                
        set tmpPort [lindex $srcPort 0]
        case $tmpPort { 
            RANDOM { set udf3CounterMode udfRandomMode}
            INCR { set udf3UpDown "uuuu"   }
            DECR { set udf3UpDown "duuu"   }
            LIST {
                set udf3 0
                set tableUdf 1
                set tmpPort [lrange $srcPort 1 end]
                lappend tmpPort 54 2 formatTypeDecimal    
                set tableList(srcPort) $tmpPort
            }        
        }  
    }    

    if {$desPort != ""} {
        set udf4 1
        set udf4Offset 56                    
        set udf4InitVal [lrange [stream cget -packetView] 56 57]
        set udf4Step [lindex $desPort 1]
        set udf4Repeat [lindex $desPort 2]
        set udf4CounterMode udfCounterMode
        set udf4Size 16
                
        set tmpPort [lindex $desPort 0]
        case $tmpPort {
            RANDOM { set udf4CounterMode udfRandomMode}
            INCR { set udf4UpDown "uuuu"   }
            DECR { set udf4UpDown "duuu"   }
            LIST {
                set udf4 0
                set tableUdf 1
                set tmpPort [lrange $desPort 1 end]
                lappend tmpPort  56 2 formatTypeDecimal        
                set tableList(desPort) $tmpPort
            }
                    
        } 
    }    
         
    if { $udf1 == 1 } {
        udf setDefault 
        udf config -enable                             true
        udf config -offset                             $udf1Offset
        udf config -counterMode                        $udf1CounterMode
        udf config -udfSize                            $udf1Size
        udf config -chainFrom                          udfNone
        
        
        if {$udf1CounterMode == "udfRandomMode"} {
            udf config -maskselect                         {00 00 00 00 }
            udf config -maskval                            {00 00 00 00 }
        } else {
            udf config -bitOffset                          0
            udf config -updown                             $udf1UpDown
            udf config -initval                            $udf1InitVal
            udf config -repeat                             $udf1Repeat
            udf config -cascadeType                        udfCascadeNone
            udf config -enableCascade                      false
            udf config -step                               $udf1Step    
        }
        
        if {[udf set 1]} {
            error "Error calling udf set 1"
            set retVal $::CIxia::gIxia_ERR
        }
    }
    if { $udf2 == 1 } {
        udf setDefault 
        udf config -enable                             true
        udf config -offset                             $udf2Offset
        udf config -counterMode                        $udf2CounterMode
        udf config -udfSize                            $udf2Size
        udf config -chainFrom                          udfNone
        
        if {$udf2CounterMode == "udfRandomMode"} {
            udf config -maskselect                         {00 00 00 00 }
            udf config -maskval                            {00 00 00 00 }
        } else {
            udf config -bitOffset                          0
            udf config -updown                             $udf2UpDown
            udf config -initval                            $udf2InitVal
            udf config -repeat                             $udf2Repeat
            udf config -cascadeType                        udfCascadeNone
            udf config -enableCascade                      false
            udf config -step                               $udf2Step         
        }
        
        if {[udf set 2]} {
            error "Error calling udf set 1"
            set retVal $::CIxia::gIxia_ERR
        }
    }
    if { $udf3 == 1 } {
        udf setDefault 
        udf config -enable                             true
        udf config -offset                             $udf3Offset
        udf config -counterMode                        $udf3CounterMode
        udf config -udfSize                            $udf3Size
        udf config -chainFrom                          udfNone

        if {$udf3CounterMode == "udfRandomMode"} {
            udf config -maskselect                         {00 00 00 00 }
            udf config -maskval                            {00 00 00 00 }
        } else {
            udf config -bitOffset                          0
            udf config -updown                             $udf3UpDown
            udf config -initval                            $udf3InitVal
            udf config -repeat                             $udf3Repeat
            udf config -cascadeType                        udfCascadeNone
            udf config -enableCascade                      false
            udf config -step                               $udf3Ste
        }
        
        if {[udf set 3]} {
            error "Error calling udf set 1"
            set retVal $::CIxia::gIxia_ERR
        }
    }
    
    if { $udf4 == 1 } {
        udf setDefault 
        udf config -enable                             true
        udf config -offset                             $udf4Offset
        udf config -counterMode                        $udf4CounterMode
        udf config -udfSize                            $udf4Size
        udf config -chainFrom                          udfNone
        
        if {$udf4CounterMode == "udfRandomMode"} {
            udf config -maskselect                         {00 00 00 00 }
            udf config -maskval                            {00 00 00 00 }
        } else {
            udf config -bitOffset                          0
            udf config -updown                             $udf4UpDown
            udf config -initval                            $udf4InitVal
            udf config -repeat                             $udf4Repeat
            udf config -cascadeType                        udfCascadeNone
            udf config -enableCascade                      false
            udf config -step                               $udf4Step
        }
        
        if {[udf set 4]} {
            error "Error calling udf set 1"
            set retVal $::CIxia::gIxia_ERR
        }
    }
    
    if { $tableUdf == 1} {
        tableUdf setDefault
        tableUdf clearColumns
        tableUdf config -enable true

        foreach fieldName [array names tableList] {
            for {set i 0} { $i < [expr [llength $tableList($fieldName)] - 3]} {incr i} {
                lappend rowList($i) [lindex $tableList($fieldName) $i]
                if { $i > $counterIndex } {
                    set counterIndex $i
                } 
            }
        
            set checkA [expr $i - 1]
            set checkB [expr $i - 2]
            if {$checkA != 0} {
                if {[llength $rowList($checkA)] != [llength $rowList($checkB)]} {
                    error "Error:The counts of values in columns are not equal."
                    set retVal $::CIxia::gIxia_ERR
                    break
                }
            }

            tableUdfColumn setDefault
            tableUdfColumn config -name $fieldName
            tableUdfColumn config -offset [lindex $tableList($fieldName) end-2]
            tableUdfColumn config -size [lindex $tableList($fieldName) end-1]
            tableUdfColumn config -formatType [lindex $tableList($fieldName) end]
            tableUdfColumn config -customFormat                       ""
            
            if {[tableUdf addColumn]} {
                error  "Error adding a column with formatType: \
                [lindex $tableList($fieldName) end]"
                set retVal $::CIxia::gIxia_ERR
                break
            }
        }    
        
        for {set i 0} { $i <= $counterIndex} {incr i} {
            if {[tableUdf addRow $rowList($i)] } {
                error "Error: the input $rowList($i) is not correct,error adding row  $rowList($i)"
                set retVal $::CIxia::gIxia_ERR
                break
            }
    
        }
        if {[tableUdf set $_chassis $_card $_port]} {
            error "Error calling tableUdf set $_chassis $_card $_port"
            set retVal $::CIxia::gIxia_ERR
        }
    }
    
    if [stream set $_chassis $_card $_port $_streamid] {
        error  "Unable to set streams to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }

    if [stream write $_chassis $_card $_port $_streamid] {
        error  "Unable to write streams to IxHal!"
        set retVal $::CIxia::gIxia_ERR
    }      
    
    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetPortAddress
#Desc: Set IP address on the target port
#Args: 
#     MacAddress: the mac address of the port
#     IpAddress: the ip address of the port
#     NetMask: the netmask of the ip address
#     GateWay: the gateway of the port
#     ReplyAllArp: send a response to the arp request
#
#Usage: port1 SetPortAddress -macaddress 112233445566 -ipaddress 192.168.1.1 -netmask 255.255.255.0 -replyallarp 1
###########################################################################################ss
::itcl::body CIxiaPortETH::SetPortAddress {args} {
    Log "Set the IP address on $_chassis $_card $_port..."
    set retVal $::CIxia::gIxia_OK
    set macaddress 0000-0000-1111
    set ipaddress 0.0.0.0 
    set netmask 255.255.255.0 
    set gateway 0.0.0.0 
    set replyallarp 0 
    set vlan 0
    set flag 0
    
    #Start to fetch param
    set argList ""
    set temp ""
    for {set i 0} { $i < [llength $args]} {incr i} {
        lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
            append argList " [lindex $tmp_list 0].arg"
        }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val        
    }
    
    #End of fetching param

    #Start to format the macaddress and IP netmask
    set macaddress [::ipaddress::format_mac_address $macaddress 6 ":"]
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
    port setFactoryDefaults $_chassis $_card $_port
    protocol setDefault
    protocol config -ethernetType ethernetII

    #Start to configure IP / Mac / gateway / autoArp /arpreply to the target port    
    interfaceTable select $_chassis $_card $_port
    interfaceTable clearAllInterfaces
    interfaceTable config -enableAutoArp true
    
    if {[interfaceTable set]} {
        error "Error calling interfaceTable set"
        set retVal $::CIxia::gIxia_ERR
    }
    
    interfaceIpV4 setDefault
    interfaceIpV4 config -ipAddress $ipaddress
    interfaceIpV4 config -gatewayIpAddress $gateway
    interfaceIpV4 config -maskWidth $netmask

    if [interfaceEntry addItem addressTypeIpV4] {
        error "Error interfaceEntry addItem addressTypeIpV4 on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
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
        error "Error interfaceTable addInterface on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    
    if [interfaceTable write] {
        error "Error interfaceTable write to $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    
    protocolServer setDefault
    protocolServer config -enableArpResponse $replyallarp
    protocolServer config -enablePingResponse   true
    if { [protocolServer set $_chassis $_card $_port] } {
        error "Error setting protocolServer on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    if { [protocolServer write $_chassis $_card $_port] } {
        error "Error writting protocolServer on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }

    #End of configuring  IP / Mac / gateway / autoArp / arpreply

    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetPortIPv6Address
#Desc: set IPv6 address on the target port
#Args: 
#     MacAddress: the mac address of the port
#     IpAddress: the ipv6 address of the port
#     PrefixLen: the prefix of the ipv6 address
#     GateWay: the gateway of the port
#     ReplyAllArp: send a response to the arp request
#
#Usage: port1 SetPortIPv6Address -macaddress 112233445566 -ipaddress 2001::1 -prefixLen 64 -replyallarp 1
###########################################################################################
::itcl::body CIxiaPortETH::SetPortIPv6Address {args} {
    Log "Set the IPv6 address on $_chassis $_card $_port..."
    set retVal $::CIxia::gIxia_OK
    set macaddress 0000-0000-0000
    set ipaddress 0:0:0:0:0:0:0:1 
    set prefixlen 64
    set gateway 0:0:0:0:0:0:0:0 
    set replyallarp 0 
    set vlan 0 
    set flag 0 


    #Start to fetch param
    set argList ""
    set temp ""
    for {set i 0} { $i < [llength $args]} {incr i} {
        lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
        set tmp_list [lindex $tmp $i]
        if {[llength $tmp_list] == 2} {
                append argList " [lindex $tmp_list 0].arg"
        }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val        
    }
    
    #End of fetching param

    #Start to format the macaddress
    set macaddress [::ipaddress::format_mac_address $macaddress 6 ":"]

    #End of formatting macaddress
    # port setFactoryDefaults $_chassis $_card $_port
    # protocol setDefault
    # protocol config -ethernetType ethernetII

    #Start to configure IP / Mac / gateway / autoArp /replyallarp to the target port    
    interfaceTable select $_chassis $_card $_port
    interfaceTable clearAllInterfaces
    interfaceTable config -enableAutoNeighborDiscovery true
    
    if {[interfaceTable set]} {
        error "Error calling interfaceTable set"
        set retVal $::CIxia::gIxia_ERR
    }    
    
    interfaceIpV6 setDefault
    interfaceIpV6 config -ipAddress $ipaddress
    interfaceIpV6 config -maskWidth $prefixlen

    
    if [interfaceEntry addItem addressTypeIpV6] {
        error "Error interfaceEntry addItem addressTypeIpV6 on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    
    interfaceEntry setDefault
    interfaceEntry config -enable true
    interfaceEntry config -description "_port $ipaddress/:01 Interface-1"
    interfaceEntry config -macAddress $macaddress
    interfaceEntry config -ipV6Gateway $gateway
    if {$vlan} { set flag true}
    interfaceEntry config -enableVlan                         $flag
    interfaceEntry config -vlanId                             $vlan
    interfaceEntry config -vlanPriority                       0
    interfaceEntry config -vlanTPID                           0x8100

    
    if [interfaceTable addInterface] {
        error "Error interfaceTable addInterface on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    
    
    if [interfaceTable write] {
        error "Error interfaceTable write to $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    
    }
    
    protocolServer setDefault
    protocolServer config -enableArpResponse $replyallarp
    protocolServer config -enablePingResponse   true
    if { [protocolServer set $_chassis $_card $_port] } {
        error "Error setting protocolServer on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    if { [protocolServer write $_chassis $_card $_port] } {
        error "Error writting protocolServer on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    #End of configuring  IP / Mac / gateway / autoArp / replyallarp
    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetTxPacketSize
#Desc: set the Tx packet size of the target stream
#Args: 
#       
#     0   set the packet size to randomSize
#Usage: port1 SetTxPacketSize 1500
###########################################################################################
::itcl::body CIxiaPortETH::SetTxPacketSize {args} {
    Log "Set the Tx packet size..."
    set retVal $::CIxia::gIxia_OK
    set minSize 64
    set maxSize 1518
    set stepSize 1
    set randomSize 0 

    if {[llength $args] > 0} {    
        set frameSize $args 
    } else {
        set randomSize 1  
    }

    if { $randomSize == 1 } {
        stream config -frameSizeType 1 
        stream config -frameSizeMIN $minSize
        stream config -frameSizeMAX $maxSize
        stream config -frameSizeStep $stepSize
        
    } else {
        stream config -frameSizeType 0 
        stream config -framesize $frameSize
    }
    
    if {$frameSize < 64} {
        puts "Warning: Truncated Packet, the frame size should be at least 64 bytes."
    }
    
    if {[ stream set $_chassis $_card $_port $_streamid ]} {
        error "Unable to config the stream on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    
    if {[stream write $_chassis $_card $_port $_streamid ]} {
        error "Unable to write configuration to $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
        
    return $retVal
}

###########################################################################################
#@@Proc
#Name: DeleteStream
#Desc: to disable a specific stream of the target port
#Args: -minindex: The first stream ID, start from 1. This could be a stream's name.
#       -maxindex: If the "minindex" is a digital, then this function will disable streams from "minindex" to "maxindex". 
#                 If the "minindex" is a stream's name, then this option make no sense.
#       
#Usage: port1 DeleteStream -minindex 1 -maxindex 10
#       port1 DeleteStream -minindex "stream_name"
###########################################################################################
::itcl::body CIxiaPortETH::DeleteStream {args} {
    Log "Disable the specific stream of $_chassis $_card $_port..."
    set retVal $::CIxia::gIxia_OK
    
    set minindex ""
    set maxindex ""
    set test ""
    set flag ""

    #Get param    
    set argList ""
    set temp ""
    for {set i 0} { $i < [llength $args]} {incr i} {
    lappend temp [ string tolower [lindex $args $i]]
    }
    set tmp [split $temp \-]
    set tmp_len [llength $tmp]
    for {set i 0 } {$i < $tmp_len} {incr i} {
            set tmp_list [lindex $tmp $i]
            if {[llength $tmp_list] == 2} {
                append argList " [lindex $tmp_list 0].arg"
            }
    }
    while {[set result [cmdline::getopt temp $argList opt val]] > 0} {
        set $opt $val        
    }
    #end get param
    
    if { [llength $minindex] != 0 } {
        # Stream ID
        if [string is digit $minindex] {
            if {[ llength $maxindex] != 0 } {
                for {set j $minindex} { $j <= $maxindex } { incr j } { 
                    stream config -enable 0 
                    stream set $_chassis $_card $_port $j
                    stream write $_chassis $_card $_port $j                
                }
            } else { 
                stream config -enable 0 
                stream set $_chassis $_card $_port $minindex
                stream write $_chassis $_card $_port $minindex
            }
        # Stream name     
        } else {
            for { set j 1} { $j } { incr j} {  
                if [stream get $_chassis $_card $_port $j] {
                    error "Couldn't find the stream ..."
                    set retVal $::CIxia::gIxia_ERR
                }
                set name [stream cget -name]
                if {$name == $minindex} {
                stream config -enable 0 
                stream set $_chassis $_card $_port $j 
                stream write $_chassis $_card $_port $j 
                }
            }
        }
    }
    return $retVal
}

###########################################################################################
#@@Proc
#Name: SetCustomVFD
#Desc: set VFD
#Args:
#                       -Vfd1           VFD1 change state, default OffState; value:
#                                       OffState 
#                                       StaticState 
#                                       IncreState 
#                                       DecreState 
#                                       RandomState 
#                       -Vfd1cycle     VFD1 cycle default no loop,continuous
#                       -Vfd1step    VFD1 change step,default 1
#                       -Vfd1offset     VFD1 offser,default 12, in bytes
#                       -Vfd1start      VFD1 start as {01} {01 0f 0d 13},default {00}
#                       -Vfd1len        VFD1 len [1~4], default 4
#                       -Vfd2           VFD2 change state, default OffState; value:
#                                       OffState 
#                                       StaticState 
#                                       IncreState 
#                                       DecreState 
#                                       RandomState 
#                       -Vfd2cycle     VFD2 cycle default no loop,continuous
#                       -Vfd2step    VFD2 step,default 1
#                       -Vfd2offset     VFD2 offset,default 12, in bytes
#                       -Vfd2start      VFD2 start,as {01} {01 0f 0d 13},default {00}
#                       -Vfd2len        VFD2 len [1~4], default 4
#Usage: port1 SetCustomVFD 
###########################################################################################
::itcl::body CIxiaPortETH::SetCustomVFD {Id Mode Range Offset Data DataCount {Step 1}} {
    Log "Set custom VFD..."
    set retVal $::CIxia::gIxia_OK

    #set vfd1       OffState
    #set vfd1cycle  1
    #set vfd1step   1
    #set vfd1offset 12
    #set vfd1start  {00}
    #set vfd1len    4
    #set vfd2       OffState
    #set vfd2cycle  1
    #set vfd2step   1
    #set vfd2offset 12
    #set vfd2start  {00}
    #set vfd2len    4
    #
    #get_params $args    

    if [stream get $_chassis $_card $_port $_streamid] {
        error "Unable to retrive config of No.$_streamid stream from port $_chassis $_card $_port!"
        set retVal $::CIxia::gIxia_ERR
        
        return $retVal
    }

    #UDF1 config
    if { $Id == 1 } {            
        switch $Mode {                
            1 { set vfd1 "RandomState" }
            2 { set vfd1 "IncreState" }
            3 { set vfd1 "DecreState" }
            4 { set vfd1 "List"}
            default { set vfd1 "OffState" }
        }

        set vfd1len $Range
        set vfd1offset [expr $Offset / 8]
        set vfd1start $Data
        
        #Added by zshan begin
        #Format the data, transform the input from {0x01 0x02} to {01 02} or to {{01} {02}}

        regsub -all --  {0x} $vfd1start {} vfd1start
        regsub -all --  {0X} $vfd1start {} vfd1start    
        set lenData [llength $vfd1start]
        if { $Mode == 4 && [expr $lenData % $Range] == 0 } {
            set cnt [expr $lenData / $Range]
            for { set i 0} { $i < $cnt} { incr i $Range} {
                lappend tempVfd1 [lrange $vfd1start $i [expr $Range - 1] ]
            }
            
            set vfd1start ""
            lappend vfd1start $tempVfd1
        }
        
        #Added by zshan  end        
        set vfd1cycle $DataCount
        set vfd1step $Step

        if {$vfd1 != "OffState"} {
            udf setDefault
            udf config -enable true
            switch $vfd1 {
                "RandomState" {
                    udf config -counterMode udfRandomMode
                }
                "StaticState" -
                "IncreState"  -
                "DecreState" {
                    udf config -counterMode udfCounterMode
                }
                #Added by zshan begin
                "List" {
                    if {[expr $lenData % $Range ] != 0} { 
                        error "The length of Data should be multiper of $Range."
                        set retVal $::CIxia::gIxia_ERR
                        return $retVal
                    } else {
                        udf config -counterMode udfValueListMode
                    }
                }
                #Added by zshan end
            }
            set vfd1len [llength $vfd1start]
            switch $vfd1len  {
                1 { udf config -countertype c8  }
                2 { udf config -countertype c16 }
                3 { udf config -countertype c24 }
                4 { udf config -countertype c32 }
                #Added by zshan begin: support more than 4 bytes
                default { 
                    udf config -conftertype c32 
                    set tempVfd [lrange $vfd1start [expr $Range - 4] end]
                    set vfd1start $tempVfd
                }
                # default {error "-vfd1start only support 1-4 bytes, for example: {11 11 11 11}"}
                #Added by zshan end
            }
            
            switch $vfd1 {
                "IncreState" {udf config -updown uuuu}
                "DecreState" {udf config -updown dddd}
            }
            
            puts vfd1start1111:$vfd1start
            udf config -offset  $vfd1offset
            
            if {$Mode == 4} {
                udf config -valueList $vfd1start
            } else {
                udf config -initval $vfd1start
                udf config -repeat  $vfd1cycle
                udf config -step    $vfd1step
            }
            udf set 1
        } elseif {$vfd1 == "OffState"} {
            udf setDefault
            udf config -enable false
            udf set 1
        }
    }

    #UDF2 config
    if { $Id == 2 } {
        switch $Mode {                
            1 { set vfd2 "RandomState" }
            2 { set vfd2 "IncreState" }
            3 { set vfd2 "DecreState" }
            4 { set vfd2 "List"       }
            default { set vfd2 "OffState" }
        }
        set vfd2len $Range
        set vfd2offset [expr $Offset / 8]
        set vfd2start $Data

        #Added by zshan begin
        #Format the data, transform the input from {0x01 0x02} to {01 02} or to {{01} {02}}
        regsub -all --  {0x} $vfd2start {} vfd2start
        regsub -all --  {0X} $vfd2start {} vfd2start
        set lenData [llength $vfd2start]
        if { $Mode == 4 && [expr $lenData % $Range] == 0 } {
            set cnt [expr $lenData / $Range]
            for { set i 0} { $i < $cnt} { incr i $Range} {
                lappend tempVfd2 [lrange $vfd2start $i [expr $Range - 1] ]
            }
            set vfd2start ""
            lappend vfd2start $tempVfd2
        }
        #Added by zshan  end        
        set vfd2cycle $DataCount
        set vfd2step $Step

        if {$vfd2 != "OffState"} {
            udf setDefault
            udf config -enable true
            switch $vfd2 {
                "RandomState" {
                    udf config -counterMode udfRandomMode
                }
                "StaticState" -
                "IncreState"  -
                "DecreState" {
                    udf config -counterMode udfCounterMode
                }
                #Added by zshan begin
                "List" {
                    if {[expr $lenData % $Range ] != 0} { 
                        error "The length of Data should be multiper of $Range."
                        set retVal $::CIxia::gIxia_ERR
                        return $retVal
                    } else {
                        udf config -counterMode udfValueListMode
                    }
                }
                #Added by zshan end
            }
            set vfd2len [llength $vfd2start]
            switch $vfd2len  {
                1 { udf config -countertype c8  }
                2 { udf config -countertype c16 }
                3 { udf config -countertype c24 }
                4 { udf config -countertype c32 }
                # default {error "-vfd2start only support 1-4 bytes, for example: {11 11 11 11}"}
                #Added by zshan begin: support more than 4 bytes
                default {              
                    udf config -conftertype c32 
                    set tempVfd [lrange $vfd2start [expr $Range - 4] end]
                    set vfd2start $tempVfd
                }
                #Added by zshan end
            }
            switch $vfd2 {
                "IncreState" {udf config -updown uuuu}
                "DecreState" {udf config -updown dddd}
            }
            udf config -offset  $vfd2offset

            if {$Mode == 4} {
                udf config -valueList $vfd2start
            } else {
                udf config -initval $vfd2start
                udf config -repeat  $vfd2cycle
                udf config -step    $vfd2step
            }
            udf set 2
        } elseif {$vfd2 == "OffState"} {
            udf setDefault
            udf config -enable false
            udf set 2
        }
    }

    if {[string match [config_stream -StreamId $_streamid] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }
    if {[string match [config_port -ConifgType config -NoProtServ ture] $::CIxia::gIxia_ERR]} {
        set retVal $::CIxia::gIxia_ERR
    }

    return $retVal
}


####################################################################
# 方法名称： SetVFD1
# 方法功能： 设置指定网卡发包的源MAC地址(使用VFD1)
# 入口参数：
#        Offset 偏移，in byte,注意不要偏移位设置到报文的CHECKSUM的字节上。
#       DataList   需要设定的数据list，如果超过6个字节则取前面6个字节
#        Mode   源MAC地址的变化形式，可取 
#                                     HVFD_RANDOM,
#                                     HVFD_INCR,
#                                     HVFD_DECR,
#                                     HVFD_SHUFFLE
#        Count  源地址变化的循环周期
#
# 出口参数： 无
# 其他说明： 使用了VFD1资源
# 例   子:
#            SetVFD1 8 {1 1} $::HVFD_SHUFFLE 100
#            SetVFD1 12 {0x00 0x10 0xec 0xff 0x00 0x12} $::HVFD_INCR 100
####################################################################
::itcl::body CIxiaPortETH::SetVFD1 {Offset DataList {Mode 1} {Count 0}} {
    set Offset [expr 8*$Offset]
    $this SetCustomVFD $::HVFD_1 $Mode [llength $DataList] $Offset $DataList $Count 1
}

####################################################################
# 方法名称： SetVFD2
# 方法功能： 设置指定网卡发包的源MAC地址(使用VFD2)
# 入口参数：
#        Offset 偏移，in byte,注意不要偏移位设置到报文的CHECKSUM的字节上。
#           DataList   需要设定的数据list，如果超过6个字节则取前面6个字节
#        Mode   源MAC地址的变化形式，可取 
#                                     HVFD_RANDOM,
#                                     HVFD_INCR,
#                                     HVFD_DECR,
#                                     HVFD_SHUFFLE
#        Count  源地址变化的循环周期
#
# 出口参数： 无
# 其他说明： 使用了VFD2资源
# 例   子:
#            SetVFD2 8 {1 1} $::HVFD_INCR 100
#            SetVFD2 12 {0x00 0x10 0xec 0xff 0x00 0x12} $::HVFD_INCR 100
####################################################################
::itcl::body CIxiaPortETH::SetVFD2 {Offset DataList {Mode 5}  {Count 0} } {
    set Offset [expr 8*$Offset]
    $this SetCustomVFD $::HVFD_2 $Mode [llength $DataList] $Offset $DataList $Count 1
}

###########################################################################################
#@@Proc
#Name: CaptureClear
#Desc: Clear capture buffer, in face, Ixia doesn't need clear the buffer, because each
#      time begin start capture, the buffer will clear automatically.
###########################################################################################
::itcl::body CIxiaPortETH::CaptureClear {} {
    Log "Capture clear..."
    set retVal $::CIxia::gIxia_OK 
    if {[ixStartPortCapture $_chassis $_card $_port] != 0} {
        error "Could not start capture on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    if {[ixStopPortCapture $_chassis $_card $_port] != 0} {
        error "Could not start capture on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    return $retVal
}

###########################################################################################
#@@Proc
#Name: StartCapture
#Desc: Start Port capture
#Args: mode: capture mode,1:capture trig,2:capture bad,0:capture all
#Usage: port1 StartCapture 
###########################################################################################
::itcl::body CIxiaPortETH::StartCapture {{CapMode 0}} {
    capture   setDefault
    switch $CapMode {
        0 { capture config -captureMode captureContinuousMode }
        1 { capture config -captureMode captureTriggerMode }
    }
    capture   set  $_chassis $_card $_port
    
    set retVal $::CIxia::gIxia_OK
    if [string match [CaptureClear] $::CIxia::gIxia_ERR] {
        error "Capture clear failed..."
        set retVal $::CIxia::gIxia_ERR
    }
    Log "Start capture on $_chassis $_card $_port"
    if {[ixStartPortCapture $_chassis $_card $_port] != 0} {
        error "Could not start capture on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    return $retVal
}

###########################################################################################
#@@Proc
#Name: StopCapture
#Desc: Stop Port capture
#Args:
#Usage: port1 StopCapture 
###########################################################################################
::itcl::body CIxiaPortETH::StopCapture { } {
    Log "Stop capture..."
    set retVal $::CIxia::gIxia_OK
    if {[ixStopPortCapture $_chassis $_card $_port] != 0} {
        error "Could not start capture on $_chassis $_card $_port"
        set retVal $::CIxia::gIxia_ERR
    }
    return $retVal
}

###########################################################################################
#@@Proc
#Name: ReturnCaptureCount
#Desc: Get capture buffer packet number. 
#Args:
#Ret:a list include 1.   ::CIxia::gIxia_OK or ::CIxia::gIxia_ERR, ::CIxia::gIxia_OK means ok, ::CIxia::gIxia_ERR means error.
#                   2.   the number of packet.
#Usage: port1 ReturnCaptureCount
###########################################################################################
::itcl::body CIxiaPortETH::ReturnCaptureCount { } {
    Log "Get capture count..."
    set retVal $::CIxia::gIxia_OK
    set PktCnt 0

    if {[capture get $_chassis $_card $_port]} {
       set retVal $::CIxia::gIxia_ERR
       error "get capture from $_chassis,$_card,$_port failed..."
    }
    set PktCnt [capture cget -nPackets]
    Log "total $PktCnt packets captured"
    lappend retList $retVal
    lappend retList $PktCnt
    #return $retList
    return $PktCnt
}

###########################################################################################
#@@Proc
#Name: ReturnCapturePkt
#Desc: Get detailed byte infomation of specific packet. 
#Args:
#    -index : the index of packet in buffer. default 0.
#       -offset: the bytes to be retrieved offset. default 0.
#       -len   : how many bytes to be retrieved.
#                                 default 0, means the whole packet, from the offset byte to end.
#Ret:a list include 1.   0 or 1, 0 means ok, 1 means error.
#                   2.   a list include the specific byte content of the packet.
#Usage: port1 ReturnCapturePkt
###########################################################################################
::itcl::body CIxiaPortETH::ReturnCapturePkt { {PktIndex 0} } {
    Log "Get capture packet..."
    set retVal $::CIxia::gIxia_OK

    set index      $PktIndex
    set offset     0
    set len        0
    set byteList   ""
    set PktCnt 0
    
    #get_params $args    

    if {[capture get $_chassis $_card $_port]} {
        set retVal $::CIxia::gIxia_ERR
        error "get capture from $_chassis,$_card,$_port failed..."
    }
    set PktCnt [capture cget -nPackets]
    Log "total $PktCnt packets captured"

    #Get all the packet from Chassis to pc.
    if [captureBuffer get $_chassis $_card $_port 1 $PktCnt] {
        set retVal $::CIxia::gIxia_ERR
        error "retrieve packets failed..."
    }

    #Notice: Ixia buffer index starts with 1.
    if [captureBuffer getframe [expr $index + 1]] {
        set retVal $::CIxia::gIxia_ERR
        error "read Index = $index packet failed..."
    }

    set data  [captureBuffer cget -frame]
    # if {$len == 0} {
        # set len [llength $data]
    # }
    # for {set i $offset} {$i < $len} {incr i} {
        # #lappend byteList "0x[lindex $data $i]"
        # lappend byteList " [lindex $data $i]"
    # }
    
    #error "Offset:$Offset, Index:$Index, Len:$Len"
    #lappend retList $retVal
    #lappend retList $byteList

    return $data
}

###########################################################################################
#@@Proc
#Name: GetPortInfo
#Desc: retrieve specific counter.
#Args:
#    -RcvPkt: received packets count
#    -TmtPkt: sent packets count
#    -RcvTrig: capture trigger packets count
#    -RcvTrigRate: capture trigger packets rate
#    -RcvByte: capture received packets bytes
#    -RcvByteRate: capture received packets rate
#    -RcvPktRate: received packets rate
#    -TmtPktRate: sent packects count
#    -CRC: received CRC errors packets count
#    -CRCRate: received CRC errors packets rate
#    -Collision: collision packets count
#    -CollisionRate: collision packets rate
#    -Align: alignment errors packets count
#    -AlignRate: alignment errors packets rate
#    -Oversize: oversize packets count
#    -OversizeRate: oversize packets rate
#    -Undersize: undersize packets count
#    -UndersizeRate: undersize packets rate
#Ret: success: eg: ::CIxia::gIxia_OK {-RcvPkt 100} {-RcvPktRate 20}
#     fail:    ::CIxia::gIxia_ERR {}
#Usage: port1 GetPortInfo -Undersize -Oversize
###########################################################################################
::itcl::body CIxiaPortETH::GetPortInfo { args } {
    set retVal $::CIxia::gIxia_OK

    set RcvPkt ""
    set TmtPkt ""
    set RcvTrig ""
    set RcvTrigRate ""
    set RcvByte ""
    set RcvByteRate ""
    set RcvPktRate ""
    set TmtPktRate ""
    set CRC ""
    set CRCRate ""
    set Align ""
    set AlignRate ""
    set Oversize ""
    set OversizeRate ""
    set Undersize ""
    set UndersizeRate ""
    
    set argList {RcvPkt.arg TmtPkt.arg RcvTrig.arg RcvTrigRate.arg RcvByte.arg RcvByteRate.arg RcvPktRate.arg TmtPktRate.arg \
                     CRC.arg CRCRate.arg Align.arg AlignRate.arg Oversize.arg OversizeRate.arg Undersize.arg UndersizeRate.arg}
        
    set result [cmdline::getopt args $argList opt val]
    while {$result>0} {
        set $opt $val
        set result [cmdline::getopt args $argList opt val]        
    }
    
    if {$result<0} {
        Log "GetPortInfo has illegal parameter! $val"
        return $$::CIxia::gIxia_ERR
    }
    
    if [stat get statAllStats $_chassis $_card $_port] {
        error "Get all Event counters Error"
        set retVal $::CIxia::gIxia_ERR
        
        return $retVal
    }
    
    if { $RcvPkt != "" } {
        upvar $RcvPkt m_RcvPktt
        set m_RcvPktt [stat cget -framesReceived]    
    }
    
    if { $TmtPkt != "" } {
        upvar $TmtPkt m_TmtPkt
        set m_TmtPkt [stat cget -framesSent]
    }
    
    if { $RcvTrig != "" } {
        upvar $RcvTrig m_RcvTrig
        set m_RcvTrig [stat cget -captureTrigger]
    }
    
    if { $RcvByte != "" } {
        upvar $RcvByte m_RcvByte
        set m_RcvByte [stat cget -bytesReceived]
    }
    
    if { $CRC != "" } {
        upvar $CRC m_CRC
        set m_CRC [stat cget -fcsErrors]
    }
    
    if { $Align != "" } {
        upvar $Align m_Align
        set m_Align [stat cget -alignmentErrors]
    }
    
    if { $Oversize != "" } {
        upvar $Oversize m_Oversize
        set m_Oversize [stat cget -oversize]
    }
                   
    if { $Undersize != "" } {
        upvar $Undersize m_Undersize
        set m_Undersize [stat cget -undersize]
    }
    
    if [stat getRate allStats $_chassis $_card $_port] {
            error "Get all Rate counters Error"
            set retVal $::CIxia::gIxia_ERR
        return $retVal
    }
    
    
    if { $RcvTrigRate != "" } {
        upvar $RcvTrigRate m_RcvTrigRate
        set m_RcvTrigRate [stat cget -captureTrigger]
    }
    
    if { $RcvByteRate != "" } {
        upvar $RcvByteRate m_RcvByteRate        
        set m_RcvByteRate [stat cget -bytesReceived]
    }
    
    if { $RcvPktRate != "" } {
        upvar $RcvPktRate m_RcvPktRate
        set m_RcvPktRate [stat cget -framesReceived]
    }
    
    if { $TmtPktRate != "" } {
        upvar $TmtPktRate m_TmtPktRate
        set m_TmtPktRate [stat cget -framesSent]
    }
    
    if { $CRCRate != "" } {
        upvar $CRCRate m_CRCRate
        set m_CRCRate [stat cget -fcsErrors]
    }
    
    if { $AlignRate != "" } {
        upvar $AlignRate m_AlignRate
        set m_AlignRate [stat cget -alignmentErrors]
    }
    
    if { $OversizeRate != "" } {
        upvar $OversizeRate m_OversizeRate
        set m_OversizeRate [stat cget -oversize]
    }
    
    if { $UndersizeRate != "" } {
        upvar $UndersizeRate m_UndersizeRate
        set m_UndersizeRate [stat cget -undersize]
    }
    
    return $::CIxia::gIxia_OK
}
###########################################################################################
#@@Proc
#Name: GetPortStatus
#Desc: retrieve specific port's status
#Args: No
#    
#Ret: success:  {up} {down}
#     fail:    ::CIxia::gIxia_ERR {}
#
#Usage: port1 GetPortInfo 
###########################################################################################

::itcl::body CIxiaPortETH::GetPortStatus {  } {
    set retVal $::CIxia::gIxia_OK
    
    if { [port get $_chassis $_card $_port] == 1} {
        set retVal  $::CIxia::gIxia_ERR
        error "can't get $_chassis $_card $_port."
        return $retVal
    }
    set portState [port cget -linkState]
    #set portSpeed [port cget -speed]
    if { $portState == 0 } {
        set retVal  down
    }
    if {$portState == 1} {
        set retVal up
    
    }

    return $retVal
}
###########################################################################################
#@@Proc
#Name: Clear
#Desc: Clear Counter
#Args:
#Usage: port1 Clear
###########################################################################################
::itcl::body CIxiaPortETH::Clear { args } {
    Log "Clear counter..."
    set retVal $::CIxia::gIxia_OK
    Log "Clear statistic counters for $_chassis $_card $_port..."
    if [ixClearPortStats $_chassis $_card $_port] {
       error "Can't Clear $_chassis $_card $_port counters"
       set retVal $::CIxia::gIxia_ERR
    }
    return $retVal
}

###################################################################################
#  Protocol emulated
#@@Proc 
#Name: ProtocolInit 
#Desc: Protocol Init Variables
#Args:
######################################################################
::itcl::body CIxiaPortETH::ProtocolInit {} {
    Log "Initializing Ports parameters"
    initPortpara $_chassis $_card $_port

    #Log "Initializing protocol server"
    #initProtocolServer  $_chassis $_card $_port

    #Log "Initializing Route protocol"
    #initRouteProtocol $_chassis $_card $_port
}
   
######################################################################
#@@Proc 
#Name: StartRouteEngine
#Desc: 
#Args:
#    portList   
#       protocol
######################################################################
::itcl::body CIxiaPortETH::StartRoutingEngine {{portInfo {}} {protocol {}}} {
    global protocolServiceEnable
    set retVal $::CIxia::gIxia_OK
    foreach enable_protocol $protocolServiceEnable($_chassis,$_card,$_port) {
        switch $enable_protocol {
            Rip   {
                if {[ixStartRip  portList]} {
                    Log "Start Rip protocol Error" warning
                    return $::CIxia::gIxia_ERR
                }
            }
            Ripng {
                if {[ixStartRipng  portList]} {
                    Log "Start Ripng protocol Error" warning
                    return $::CIxia::gIxia_ERR
                }
            }
            Ospf  {
                if {[ixStartOspf  portList]} {
                    Log "Start OSPF protocol Error" warning
                    return $::CIxia::gIxia_ERR
                }
            }
            Ospfv3 {
                if {[ixStartOspfV3  portList]} {
                    Log "Start Ospfv3 protocol Error" warning
                    return $::CIxia::gIxia_ERR
                }
            }
            Isis  {
                if {[ixStartIsis  portList]} {
                    Log "Start Isis protocol Error" warning
                    return $::CIxia::gIxia_ERR
                }
            }
            Bgp   {
                if {[ixStartBGP4  portList]} {
                    Log "Start Bgp protocol Error" warning
                    return $::CIxia::gIxia_ERR
                }
            }
        }
    }
    return $retVal
}

######################################################################
#@@Proc 
#Name: StopRouteEngine
#Desc: 
#Args:
#    portList   
#       protocol
######################################################################
::itcl::body CIxiaPortETH::StopRouteEngine {{portInfo {}} {protocol {}}} {
    global protocolServiceEnable

    set retVal 0
    foreach enable_protocol $protocolServiceEnable($_chassis,$_card,$_port) {
        switch $enable_protocol {
            Rip  {
                if {[ixStopRip  portList]} {
                    Log "Stop Rip protocol Error" warning
                    return -1
                }
            }
            Ripng {
                if {[ixStopRipng  portList]} {
                    Log "Stop Ripng protocol Error" warning
                    return -1
                }
            }
            Ospf  {
                if {[ixStopOspf  portList]} {
                    Log "Stop OSPF protocol Error" warning
                    return -1
                }
            }
            Ospfv3 {
                if {[ixStopOspfV3  portList]} {
                    Log "Stop Ospfv3 protocol Error" warning
                    return -1
                }
            }
            Isis  {
                if {[ixStopIsis  portList]} {
                    Log "Stop Isis protocol Error" warning
                    return -1
                }
            }
            Bgp   {
                if {[ixStopBGP4  portList]} {
                    Log "Stop Bgp protocol Error" warning
                    return -1
                }
            }
        }
    }
    return $retVal
}


######################################################################
##OSPF
#@@Proc 
#Name: AddOspfNei
#Desc: Add OSPF neighbor
#Args:
#     -NeiNo            Ospf Session id; unique 
#     -SutIp          SUT ip address    
#     -TestIp          tester ip address    
#     -PrefixLen          network mask; default 24
#     -SutRd        SUT router id  
#     -TestRd       tester router id  
#     -TestArea           test ospf area,default 0
# Usage: port1 AddOspfNei -NeiNo 1 -SutIp 1.1.1.1 -TestIp 1.1.1.2 -SutRd 1.1.1.1 -TestRd 1.1.1.2
######################################################################
::itcl::body CIxiaPortETH::AddOspfNei  { args }  {
    Log "***AddOspfNei $args"
    global protocolServiceEnable

    set retVal $::CIxia::gIxia_OK
    set args [string tolower $args]
    if {[checkForMissingArgs "-neino -sutip -testip -sutrd -testrd" $args] == -1} {
        return $::CIxia::gIxia_ERR
    }

    set prefixlen 24
    set testarea 0

    get_params $args
    if {[checkSessionCreated $_chassis  $_card  $_port $neino "Ospf"]} {
        Log "Ospf neighbor $neino has been created" warning
        return $::CIxia::gIxia_ERR  
    }
    
    Log " \n step Bring up Ospf Session... \n"
    
    set ipAddr [list $testip $prefixlen]
    if {[intfConfig -port "$_chassis $_card $_port" -proto_type "ipv4" -ipConf $ipAddr -gateway $sutip] == -1} {
        Log  "Configure Port ($_chassis:$_card:$_port) IPAddress/mask ( $ipAddr ) error " warning
        return $::CIxia::gIxia_ERR  
    }

    after 1000
    
    #This command configures the OSPF parameters.
    if {[rpe_ospf_conf $neino $_chassis $_card $_port $testarea $sutip $sutrd $testip $testrd $prefixlen] == -1} {     
        Log "Configure OSPF protcol on port ($_chassis:$_card:$_port) error" warning
        return $::CIxia::gIxia_ERR  
    }

    after 1000
    
    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }
    
    #set up statatistics on port
    stat config -enableProtocolServerStats true
    stat config -enableOspfStats true
    stat set  $_chassis $_card $_port
    
    if {[StartRoutingEngine $portList "Ospf"] == -1} {
        Log "Could not Start Ospf for $portList at AddOspfNei procedure" warning
        return $::CIxia::gIxia_ERR
    }
    Log "--------------------Checking Ospf Neighbor Status----------------------"
    set RETCODE [rpe_check_status -port "$_chassis $_card $_port" -timeout 45]
    if $RETCODE {
        set retVal $::CIxia::gIxia_ERR
    }
    Log "$_chassis $_card $_port - RETCODE $RETCODE"
    
    stat get statAllStats $_chassis $_card $_port
    set nei     [stat cget -ospfFullNeighbors]
    set ses     [stat cget -ospfTotalSessions]
    
    Log "Ospf FULL state Neighbous Number: $nei, Total session Number: $ses"
    Log "-----------------------------------------------------------------------"
    
    return $retVal
}

######################################################################
#@@Proc 
#Name: DeleteOspfNei
#Desc: delete OSPF neighbor
#Args:
#      -NeiNo,  OSPF Session id; option; 0 default, delete all neighbors on port
# Usage: port1 DeleteOspfNei -NeiNo 1 
######################################################################
::itcl::body CIxiaPortETH::DeleteOspfNei {  args  } {
    global Ospfindex

    set retVal $::CIxia::gIxia_OK
    set neino all
    get_params $args

    Log "***DeleteOspfNei -NeiNo $neino"
    # Select port for Ospf commands
    ospfServer   select  $_chassis $_card $_port

    if {$neino == "all"} {
        ospfServer clearAllRouters
        ospfServer set
        ospfServer write

        clearProtocolIndex "Ospf" $_chassis $_card $_port
        clearPoolInfo "Ospf" $_chassis $_card $_port
        clearService "Ospf" $_chassis $_card $_port

        if {[StopRouteEngine $portList "Ospf"]} {
            Log "Could not Stop Ospf protocol on port $portList" warning
            return $::CIxia::gIxia_ERR 
        }
    } elseif {[ospfServer getRouter $neino]} {
        Log "Could not retrieve Ospf neighbor $neino" warning
        return $::CIxia::gIxia_ERR
    } else {
        ospfServer delRouter $neino
        ospfServer set
        ospfServer write

        delOspfIndex $_chassis $_card $_port $neino
        DelOspfPoolInfo $neino $_chassis $_card $_port "all"

        if {[llength $Ospfindex($_chassis,$_card,$_port)] == 0} {
            if {[StopRouteEngine $portList "Ospf"] == -1} {
                Log "Could not Stop Ospf for $portList" warning
                return $::CIxia::gIxia_ERR 
            }
            clearService "Ospf" $_chassis $_card $_port
        }
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    if {[llength $Ospfindex($_chassis,$_card,$_port)] > 0} {
        if {[StartRoutingEngine $portList "Ospf" ]== -1} {
            Log "Could not Start Ospf for $portList" warning
            set retVal $::CIxia::gIxia_ERR   
        }
    }
    after 5000
    
    return $retVal
}


######################################################################
#@@Proc 
#Name: EditOspfNei
#Desc: Edit OSPF neighbor
#Args:
#       -NeiNo
#       -NetworkType 
#       -HelloInterval
#       -DeadInterval
#       -PollInterval 
#       -RetransmitInterval
#       -TransitDelay 
#       -MaxLSAsPerPacket
#Usage: port1 EditOspfNei -Neino 1 -HelloInterval 20 -DeadInterval 30
######################################################################
::itcl::body CIxiaPortETH::EditOspfNei { args } {
    global Ospfindex

    set args [string tolower $args]
    if {[checkForMissingArgs "-neino " $args] == -1} {
        return $::CIxia::gIxia_ERR
    }
    Log "***EditOspfNei $args"
    set retVal $::CIxia::gIxia_OK

    set networktype         Broadcast
    set updatenettype       0
    set hellointerval       10
    set updatehello         0
    set deadinterval        40
    set updatedead          0

    set pollinterval        60
    set retransmitinterval  5
    set transmitdelay       1
    set maxlsasperpacket    100
    get_params $args
 
    if {[string match -nocase $networktype "Broadcast"]} {
        set networktype ospfBroadcast
    } elseif {[string match -nocase $networktype "PToP"]} {
        set networktype ospfPointToPoint
    } elseif {[string match -nocase $networktype "PointToMulPoint"]} {
        set networktype ospfPointToMultipoint
    } else {
        error "Not support this network type $networktype"
        return $::CIxia::gIxia_ERR  
    }

    if {![string match -nocase $networktype "Broadcast"]} {
        if {$updatehello == 0} {
            set hellointerval 120 
        }
        if {$updatedead == 0} {
            set deadinterval  360 
        }
    }

    #check OSPF Session whether has been created
    if {[checkSessionCreated $_chassis $_card $_port $neino "Ospf"] == 0} {
       Log "Ospf Session $neino has not been created" warning
       return $::CIxia::gIxia_ERR 
    }

    ospfServer select $_chassis $_card $_port
    ospfServer getRouter $neino

    set intfindex [lsearch $Ospfindex($_chassis,$_card,$_port) $neino]
    set intfindex [expr $intfindex + 1]
    set intfId "interface_$intfindex"

    ospfRouter getInterface $intfId

    if {$updatenettype == 1} {
        ospfInterface config -networktype $networktype 
    }

    ospfInterface config -deadInterval $deadinterval
    ospfInterface config -helloInterval $hellointerval

    ospfRouter setInterface $intfId
    ospfServer setRouter $neino
    ospfServer set
    #ospfServer write

    enableServiceOspf  $_chassis $_card $_port
    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR 
    }

    if {[StartRoutingEngine $portList "Ospf"] == -1} {
        Log "Could not Start Ospf for $portList at EditOspfNei procedure" warning
        return $::CIxia::gIxia_ERR
    }

    return $retVal
}



######################################################################
#@@Proc 
#Name: EnableOspfNei
#Desc: 
#Args:
#            -NeiNo, default "all", enable all
#Usage: port1 EnableOspfNei
######################################################################
::itcl::body CIxiaPortETH::EnableOspfNei { args } {
    global Ospfindex
    set retVal $::CIxia::gIxia_OK
    set neino all
    get_params $args

    Log "***EnableOspfNei -NeiNo $neino" 

    if {$neino == "all"} {
        #start ospf server on port
        enableOspfSession -port $portList
    } else {
        enableOspfSession -port $portList -SessNo $neino 
    }

    # Enable the OSPF protocol
    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
         return $::CIxia::gIxia_ERR  
    }

    if {[StartRoutingEngine $portList "Ospf"] == -1} {
        Log "Could not Start Ospf for $portList at EnableOspfNei procedure" warning
        set retVal $::CIxia::gIxia_ERR   
    }
    return $retVal
}


######################################################################
#@@Proc 
#Name: DisableOspfNei
#Desc: 
#Args:
#            -NeiNo, default "all", enable all
#Usage: port1 DisableOspfNei
######################################################################
::itcl::body CIxiaPortETH::DisableOspfNei { args } {
    global Ospfindex
    set retVal $::CIxia::gIxia_OK
    set neino all
    get_params $args

    Log "***DisableOspfNei -NeiNo $neino"
    if {$neino == 0} {
        if {[disableOspfSession -port $portList] == -1} {
            Log "disable Ospf Session error" warning
            return $::CIxia::gIxia_ERR
        }
    } else {
        if {[disableOspfSession -port $portList -SessNo $neino] == -1} {
            Log "disable Ospf Session $neino error" warning
            return $::CIxia::gIxia_ERR      
        }
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR 
    }
    return $retVal
}


######################################################################
#@@Proc 
#Name: AddOspfGrid
#Desc: 
#Args:
#     -NeiNo,        Ospf Session id; mandatory;
#     -GridNo       Grid id; option ; default all;
#     -GridRows
#     -GridColumns
#     -ABRASBRTag
#     -LinkRow
#     -LinkColumn
#     -StartingRouterId
#     -StartingIpAddress
#Usage: port1 AddOspfGrid -NeiNo 1 -GridNo 10 -GridRows 2
######################################################################
::itcl::body CIxiaPortETH::AddOspfGrid { args }  {
    set retVal $::CIxia::gIxia_OK
    set args [string tolower $args]
    if {[checkForMissingArgs "-neino -gridno" $args] == -1} {
       return $::CIxia::gIxia_ERR        
    }

    Log "***AddOspfGrid $args"

    set metric         1
    #set routeorigin     ospfRouteOriginArea

    set gridrows         2
    set gridcolumns     2
    set abrasbrtag         0

    set startingrouterid    50.50.50.50
    set startingipaddress     80.1.1.0
    get_params $args

    if {[checkSessionCreated $_chassis $_card $_port $neino "Ospf"] == 0} {
       Log "Ospf Router $neino has not been created" warning
       return $::CIxia::gIxia_ERR   
    }

    if {[checkGridCreated $_chassis $_card $_port $neino $gridno "Ospf"] == 1} {
       Log " OSPF Grid $gridno has been created " warning
       return $::CIxia::gIxia_ERR   
    }

    addOspfGrid $_chassis $_card $_port $neino $gridrows $gridcolumns $startingrouterid $startingipaddress

    AddOspfGridInfo $neino $_chassis $_card $_port $gridno

    enableServiceOspf $_chassis $_card $_port

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    # Enable the Ospf protocol
    if {[StartRoutingEngine $portList "Ospf"] == -1} {
       Log "Could not Start Ospf for $portList at DelOspfRoutePool procedure" warning
       set retVal $::CIxia::gIxia_ERR    
    }

    return $retVal
}


######################################################################
#@@Proc 
#Name: DeleteOspfGrid
#Desc: 
#Args:
#     -NeiNo,        Neighbor id; mandatory;
#     -GridNo,      grid id; option ; default all;
#Usage: port1 DeleteOspfGrid -NeiNo 1 -GridNo 10
######################################################################
::itcl::body CIxiaPortETH::DeleteOspfGrid  { args }  {
    
    global GridOspfindex
    set retVal $::CIxia::gIxia_OK

    set neino all
    set gridno all
    get_params $args

    Log "***DeleteOspfGrid -NeiNo $neino -GridNo $gridno"

    if {$neino == "all" && $gridno != "all"} {
       error "Ospf grid identifier $gridno , but not specify Ospf Session identifier "
       return $::CIxia::gIxia_ERR 
    }

    if {$neino == "all" && $gridno == "all"} {
       DeleteOspfAllGrid $_chassis $_card $_port
    } elseif { $neino != "all" && $gridno == "all"} {
       if {[checkSessionCreated $_chassis $_card $_port $neino "Ospf"] == 0} {
          Log "Ospf session $neino has not been created" warning
          return $::CIxia::gIxia_ERR 
       }
       DeleteOspfSessionGrid $_chassis $_card $_port $neino
    } elseif {$neino != "all" && $gridno != "all"} {
       if {[checkSessionCreated $_chassis $_card $_port $neino "Ospf"] == 0} {
          Log "Ospf session $neino has not been created" warning
          return $::CIxia::gIxia_ERR 
       }
       DeleteOspfSpecificGrid $_chassis $_card $_port $neino $gridno
    }
    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    # Enable the Ospf protocol
    if {[StartRoutingEngine $portList "Ospf"] == -1} {
        Log "Could not Start Ospf for $portList at DelOspfGrid procedure" warning
        set retVal $::CIxia::gIxia_ERR    
    }

    return $retVal
}



######################################################################
#@@Proc 
#Name: AddOspfAse
#Desc: 
#Args:
#     -NeiNo,       Ospf Session id; mandatory;
#     -AseId
#     -FirstIp
#     -PrefixLen
#     -Number
#     -Metric
#     -MetricType
#     -Forwarding  (no support)
#Usage: port1 AddOspfAse -NeiNo 1 -AseId 3 -FirstIp 2.2.2.2 
######################################################################
::itcl::body CIxiaPortETH::AddOspfAse { args }  {
    set retVal $::CIxia::gIxia_OK

    set args [string tolower $args]
    if {[checkForMissingArgs "-neino -aseid -firstip" $args] == -1} {
       return $::CIxia::gIxia_ERR
    }

    Log "***AddOspfAse $args"

    set prefixlen 24
    set number 50
    set metric 1
    set metrictype "Type1"
    set forwarding 0.0.0.0
    get_params $args

    if {[checkSessionCreated $_chassis $_card $_port $neino "Ospf"] == 0} {
       Log "Ospf Router $neino has not been created" warning
       return $::CIxia::gIxia_ERR 
    }
    if {[checkPoolCreated $_chassis $_card $_port $neino $aseid "Ospf"] == 1} {
       Log "Ospf Routes Pool $aseid has been created " warning
       return $::CIxia::gIxia_ERR  
    }

    if {[string match -nocase $metrictype "Type1"]} {
       set metrictype ospfRouteOriginExternal
    } elseif {[string match -nocase $metrictype "Type2"]} {
       set metrictype ospfRouteOriginExternalType2 
    } else {
       error "No such metric type:$metrictype."
       return $::CIxia::gIxia_ERR
    }

    # Select the port and clear all defined routers
    ospfServer select $_chassis $_card $_port

    ospfRouteRange   setDefault
    ospfRouteRange   config     -enable                 true
    ospfRouteRange   config     -routeOrigin            $metrictype
    ospfRouteRange   config     -metric                 $metric
    ospfRouteRange   config     -numberOfNetworks       $number
    ospfRouteRange   config     -prefix                 $prefixlen
    ospfRouteRange   config     -networkIpAddress       $firstip
    ospfRouteRange   config     -enablePropagate        false

    if {[ospfServer getRouter $neino]} {
       Log "Get Ospf router $neino error " warning
       return $::CIxia::gIxia_ERR       
    }

    ospfRouter config  -enable true
    ospfRouter addRouteRange   $aseid
    ospfServer setRouter $neino
    ospfServer write

    AddOspfPoolInfo $neino $_chassis $_card $_port $aseid

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
       return $::CIxia::gIxia_ERR  
    }
    if {[StartRoutingEngine $portList "Ospf"] == -1} {
       Log "Could not Start Ospf for $portList" warning
       set retVal $::CIxia::gIxia_ERR    
    }

    return $retVal
}


######################################################################
#@@Proc 
#Name: AddOspfSummary
#Desc: 
#Args:
#     -NeiNo,       Ospf Session id; mandatory;
#     -SummaryId
#     -FirstIp
#     -PrefixLen
#     -Number
#Usage: 
######################################################################
::itcl::body CIxiaPortETH::AddOspfSummary   { args }  {
    set retVal $::CIxia::gIxia_OK
    set args [string tolower $args]
    if {[checkForMissingArgs "-neino -summaryid -firstip" $args] == -1} {
       return $::CIxia::gIxia_ERR
    }

    Log "***AddOspfSummary $args"

    set prefixlen 24
    set number 50
    set metric 1

    get_params $args

    if {[checkSessionCreated $_chassis $_card $_port $neino "Ospf"] == 0} {
       Log "Ospf Router $neino has not been created" warning
       return $::CIxia::gIxia_ERR 
    }

    if {[checkPoolCreated $_chassis $_card $_port $neino $summaryid "Ospf"] == 1} {
       Log "Ospf Routes Pool $summaryid has been created" warning
       return $::CIxia::gIxia_ERR  
    }

    # Select the port and clear all defined routers
    ospfServer select $_chassis $_card $_port

    ospfRouteRange   setDefault
    ospfRouteRange   config     -enable                 true
    ospfRouteRange   config     -routeOrigin            "ospfRouteOriginArea"
    ospfRouteRange   config     -metric                 $metric
    ospfRouteRange   config     -numberOfNetworks       $number
    ospfRouteRange   config     -prefix                 $prefixlen
    ospfRouteRange   config     -networkIpAddress       $firstip
    ospfRouteRange   config     -enablePropagate        false

    if {[ospfServer getRouter $neino]} {
       Log "Get Ospf router $neino error " warning
       return $::CIxia::gIxia_ERR        
    }

    ospfRouter config  -enable true
    ospfRouter addRouteRange   $summaryid
    ospfServer setRouter $neino
    ospfServer write

    AddOspfPoolInfo $neino $_chassis $_card $_port $summaryid

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
       return $::CIxia::gIxia_ERR  
    }

    if {[StartRoutingEngine $portList "Ospf"] == -1} {
       Log "Could not Start Ospf for $portList" warning
       set retVal $::CIxia::gIxia_ERR    
    }

    return $retVal
}

######################################################################
#@@Proc 
#Name: AddRipSession
#Desc: 
#Args:
#               -SessNo , session identifier ; mandatory
#               -SutIp , sut interface ip address, mandatory
#               -TestIp , tester interface ip address, mandatory
#               -PrefixLen, network mask, option ,default 24
#               -Metric ,option, default 2
#               -RouterId , option ,test interface ip address
#           -Rcvmode:
#                   1   ripReceiveVersion1      RIP Version 1 messages only.
#                   2   ripReceiveVersion2      (default) RIP Version 2 messages only.
#                   3   ripReceiveVersion1and2  Both RIP version messages.
#           -ResponseMode :
#                         0     ripDefault              
#                         1     ripSplitHorizon         
#                         2     ripPoisonReverse        
#                         3     ripSplitHorizonSpaceSaver  (default)
#                         4     ripSilent               
#           -SendMode:
#                    0    ripMulticast    (default) sends Version 2 packets via multicast
#                    1    ripBroadcastV1  sends V1 packets via broadcast.
#                    2    ripBroadcastV2  sends V2 packets via broadcast.
#Usage: port1 AddRipSession -SessNo 1 -SutIp 2.2.2.1 -TestIp 2.2.2.2
######################################################################
::itcl::body CIxiaPortETH::AddRipSession  { args }  {
    global protocolServiceEnable

    set retVal $::CIxia::gIxia_OK
    set args [string tolower $args]
    if {[checkForMissingArgs "-sessno -sutip -testip" $args] == -1} {
        return $::CIxia::gIxia_ERR
    }
    Log "***AddRipSession $args"

    set authmode 0
    set passwd ""
    set rcvmode 2
    set sendmode 0
    set responsemode 3
    set updateinterval 30

    set prefixlen 24
    set metric 2

    get_params $args
    switch $rcvmode {
        1 {set rcvmode ripReceiveVersion1}
        3 {set rcvmode ripReceiveVersion1and2}
        2 -
        default {set rcvmode ripReceiveVersion2}
    }
    switch $responsemode {
        0 {set responsemode ripDefault}
        1 {set responsemode ripSplitHorizon}
        2 {set responsemode ripPoisonReverse}
        4 {set responsemode ripSilent}
        3 -
        default {set responsemode ripSplitHorizonSpaceSaver}
    }
    switch $sendmode {
        1 {set sendmode ripBroadcastV1}
        2 {set sendmode ripBroadcastV2}
        0 -
        default {set sendmode ripMulticast}
    }

    if {![info exists routerid]} {
       set routerid $testip 
    }

    if {[checkSessionCreated $_chassis $_card $_port $sessno "Rip"]} {
       Log "RIP Session $sessno has been created" warning
       return $::CIxia::gIxia_ERR 
    }

    Log " \n step Bring up Rip Seesion... \n"

    set ipAddr [list $testip $prefixlen]

    if {[intfConfig -port "$_chassis $_card $_port" -proto_type "ipv4" -ipConf $ipAddr -gateway $sutip] == -1} {
       Log "Configure Port ($chassis_id:$card:$port) IPAddress/mask ( $ipAddr ) error " warning
       return $::CIxia::gIxia_ERR 
    }

    after 1000

    #This command configures the RIP parameters.
    if {[rpe_rip_conf $sessno $_chassis $_card $_port $testip $prefixlen $authmode $passwd $rcvmode $sendmode $responsemode $updateinterval] == -1} {
       Log "Configure RIP protcol on port ($chassis_id:$card:$port) error" warning
       return $::CIxia::gIxia_ERR 
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }
    if {[ ixCheckLinkState portList ] } {
            Log "One or more links are down" warning
            return $::CIxia::gIxia_ERR
    }
    if {[StartRoutingEngine $portList "Rip"] == -1} {
       Log "Could not Start Rip for $portList at AddRipSession procedure" warning
       return $::CIxia::gIxia_ERR
    }

    return $retVal
}


######################################################################
#@@Proc 
#Name: DeleteRipSession
#Desc: 
#Args:
#               -SessNo,        Rip Session id; option; default all neighbors on port
#Usage: port1 DeleteRipSession -SessNo 1
######################################################################
::itcl::body CIxiaPortETH::DeleteRipSession {  args  } {
    Log "***DeleteRipSession $args" 
    global Ripindex

    set retVal $::CIxia::gIxia_OK

    get_params $args

    #Select port for rip commands
    ripServer select $_chassis $_card $_port

    if {![info exists $sessno]} {
        ripServer clearAllRouters
        ripServer write
 
        clearProtocolIndex "Rip"  $_chassis $_card $_port
        clearPoolInfo "Rip" $_chassis $_card $_port
        clearService "Rip" $_chassis $_card $_port
        if {[StopRouteEngine $portList "Rip"]} {
           Log "Could not Stop Rip protocol on port $portList" warning
           return $::CIxia::gIxia_ERR
        }
    } elseif {[ ripServer getRouter $sessno]} {
        Log "Could not retrieve $sessno for Rip protocol " warning
        return $::CIxia::gIxia_ERR
    } else {
        ripServer delRouter $sessno
        ripServer write
 
        delRipIndex $_chassis $_card $_port $sessno
        DelRipPoolInfo "Rip" $_chassis $_card $_port "all"
 
        if {[llength $Ripindex($_chassis,$_card,$_port)] == 0} {
            if {[StopRouteEngine $portList "Rip"]} {
               Log "Could not Stop Rip protocol on port $portList" warning
               return $::CIxia::gIxia_ERR
            }
            clearService "Rip" $_chassis $_card $_port
        }
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    if {[llength $Ripindex($_chassis,$_card,$_port)] > 0}  {
        if {[StartRoutingEngine $portList "Rip"] == -1} {
            Log "Could not Start for $portList at DeleteRipSession procedure" warning
            return $::CIxia::gIxia_ERR
        }
    }

    return $retVal
}


######################################################################
#@@Proc 
#Name: OpenRipSession
#Desc: 
#Args:
#               -SessNo,        Rip Session id; option; default all neighbors on port
#Usage: port1 OpenRipSession -SessNo 1
######################################################################
::itcl::body CIxiaPortETH::OpenRipSession { args } {
    Log "***OpenRipSession $args"
    global Ripindex

    set retVal $::CIxia::gIxia_OK

    get_params $args
    if {![info exists $sessno]} {
        #start RIP server on port
        if {[enableRipSession -port $portList] == -1} {
           Log "enable Rip service error " warning
           return $::CIxia::gIxia_ERR 
        }
    } else {
        if {[enableRipSession -port $portList -SessNo $sessno] == -1} {
           Log "enable Rip service error" warning
           return $::CIxia::gIxia_ERR 
        }
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }

    if {[ ixCheckLinkState portList ] } {
        Log "One or more links are down" warning
        return $::CIxia::gIxia_ERR
    }

    # Enable the Rip protocol
    if {[StartRoutingEngine $portList "Rip"] == -1} {
       Log "Could not Start Rip for $portList at OpenRipSession procedure" warning
       set retVal $::CIxia::gIxia_ERR    
    }

    return $retVal
}


######################################################################
#@@Proc 
#Name: CloseRipSession
#Desc: 
#Args:
#                  -SessNo, Rip Session id; option; default all neighbors on port
#Usage: port1 CloseRipSession -SessNo 1
######################################################################
::itcl::body CIxiaPortETH::CloseRipSession { args } {
    Log "***CloseRipSession $args" 
    global Ripindex
    set retVal $::CIxia::gIxia_OK

    get_params $args

    if {![info exists sessno]} {
        if {[disableRipSession -port $portList ] == -1} {
            Log "disable Rip service error" warning
            return $::CIxia::gIxia_ERR 
        }
    } else {
        if {[disableRipSession -port $portList -SessNo $sessno] == -1} {
            Log "disable Rip service error" warning
            return $::CIxia::gIxia_ERR 
        }
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }

    # Enable the Rip protocol
    if {[StartRoutingEngine $portList "Rip"] == -1} {
        Log "Could not Start Rip for $portList at OpenRipSession procedure" warning
        set retVal $::CIxia::gIxia_ERR    
    }

    return $retVal
}

######################################################################
#@@Proc 
#Name: AddRipRoutePool
#Desc: 
#Args:
#                    -SessNo,        Rip Session id; mandatory;
#                    -PoolNo,
#                    -IpAddr,
#                    -PrefixLen
#                    -RouteNum
#                    -Metric
#                    -Modifier
#Usage: port1 AddRipRoutePool -SessNo 1 -PoolNo 1 -IpAddr 3.3.3.1
######################################################################
::itcl::body CIxiaPortETH::AddRipRoutePool { args }  {
    set retVal $::CIxia::gIxia_OK
    set args [string tolower $args]
    if {[checkForMissingArgs "-sessno -poolno -ipaddr" $args]== -1} {
        return $::CIxia::gIxia_ERR
    }
  
    Log "***AddRipRoutePool $args"

    set prefixlen 24
    set routenum 100
    set metric 2
    set modifier 1

    set nexthop "0.0.0.0"
    get_params $args

    if {[checkSessionCreated $_chassis $_card $_port $sessno "Rip"] == 0} {
       Log "RIP Session $sessno has not been created" warning
       return $::CIxia::gIxia_ERR 
    }

    if {[checkPoolCreated $_chassis $_card $_port $sessno $poolno "Rip"] == 1} {
       Log " Rip Routes Pool $poolno has been created " warning
       return $::CIxia::gIxia_ERR
    }

    # Select the port and clear all defined routers
    ripServer select $_chassis $_card $_port

    ripRouteRange setDefault
    ripRouteRange config -enableRouteRange true
    ripRouteRange config -routeTag 0
    ripRouteRange config -networkIpAddress $ipaddr
    ripRouteRange config -networkMaskWidth $prefixlen
    ripRouteRange config -numberOfNetworks $routenum
    ripRouteRange config -nextHop $nexthop
    ripRouteRange config -metric $metric

    # Create a name for each individual route range
    if {[ripServer getRouter $sessno]} {
       Log "get Rip router $sessno error " warning
       return $::CIxia::gIxia_ERR       
    }

    ripInterfaceRouter addRouteRange $poolno
    ripServer setRouter $sessno
    ripServer write

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
       return $::CIxia::gIxia_ERR  
    }

    if {[ ixCheckLinkState portList ] } {
        Log "One or more links are down" warning
        return $::CIxia::gIxia_ERR
    }

    AddRipPoolInfo $sessno $_chassis $_card $_port $poolno
    # Enable the Rip protocol
    if {[StartRoutingEngine $portList "Rip"] == -1} {
       Log "Could not Start Rip for $portList " warning
       set retVal $::CIxia::gIxia_ERR    
    }

    return $retVal 
}

######################################################################
#@@Proc 
#Name: DeleteRipRoutePool
#Desc: 
#Args: 
#            -SessNo,        Rip Session id; option; default all
#            -PoolNo,       routes pool id; option ; default all
#Usage: port1 DeleteRipRoutePool -SessNo 1 -PoolNo 1
######################################################################
::itcl::body CIxiaPortETH::DeleteRipRoutePool { args }  {
    set retVal $::CIxia::gIxia_OK

    Log "***DeleteRipRoutePool $args"
    set poolno 0
    set sessno 0
    get_params $args

    if {$sessno == 0 && $poolno != 0} {
        error "route Pool identifier $poolno , but not specify Rip Session identifier "
        return $::CIxia::gIxia_ERR        
    }

    if {$sessno == 0 && $poolno == 0} {
        DeleteRipAllPool $_chassis $_card $_port
    } elseif { $sessno != 0 && $poolno == 0} {
        if {[checkSessionCreated $_chassis $_card $_port $sessno "Rip"] == 0} {
            Log "Rip session $sessno has not been created" warning
            return $::CIxia::gIxia_ERR 
        }

       DeleteRipSessionPool $_chassis $_card $_port $sessno
    } elseif {$sessno != 0 && $poolno != 0} {
        if {[checkSessionCreated $_chassis $_card $_port $sessno "Rip"] == 0} {
            Log "Rip session $sessno has not been created" warning
            return $::CIxia::gIxia_ERR 
        }
        DeleteRipSpecificPool $_chassis $_card $_port $sessno $poolno
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }

    if {[StartRoutingEngine $portList "Rip"] == -1} {
        Log "Could not Start Rip for $portList at DeleteRipRoutePool procedure" warning
        set retVal $::CIxia::gIxia_ERR    
    }

    return $retVal
}

######################################################################
#@@Proc 
#Name: EditRipSession
#Desc: 
#Args:
#            -SessNo,        Rip Session id; mandatory
#            -ExpirationInterval ; option; default 180s  (no support)
#            -GarbageInterval     ; option; default 120s (no support)
#            -UpdateInterval      ; option; default 30s
#            -TriggeredInterval  ; option; default 5s   (no support)
#            -UpdateControl       ; option; default 2   (no support)
#Usage: 
######################################################################
::itcl::body CIxiaPortETH::EditRipSession { args }  {
    set retVal $::CIxia::gIxia_OK

    set args [string tolower $args]
    if {[checkForMissingArgs "-sessno" $args] == -1} {
        return $::CIxia::gIxia_ERR
    }
    Log "***EditRipSession $args"

    set expirationinterval 180000
    set garbageinterval 12000
    set updateinterval  30
    set triggeredinterval 5000
    set updatecontrol     2
    get_params $args

    if {[checkSessionCreated $_chassis $_card $_port $sessno "Rip"] == 0} {
        Log "RIP session $sessno has not been created" warning
        return $::CIxia::gIxia_ERR 
    }

    #Stop Rip route engine
    if {[StopRouteEngine $portList "Rip"] == -1} {
        Log "Stop Rip protocol Error" warning
        return $::CIxia::gIxia_ERR        
    }

    #This command configures the Rip parameters.
    ripServer select $_chassis $_card $_port
    ripServer getRouter $sessno

    ripInterfaceRouter config -updateInterval $updateinterval
    ripServer setRouter $sessno
    ripServer write

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    #Start RIp route engine
    if {[StartRoutingEngine $portList "Rip"] == -1} {
       Log "Start Rip protocol Error" warning
       return $::CIxia::gIxia_ERR 
    }

    return $retVal 
}

######################################################################
#@@Proc 
#Name: AddRIPngSession
#Desc: 
#Args:
#     -SessNo,            RIPng Session id; mandatory
#     -IpAddr,         simulated IP address on port; mandatory
#     -PrefixLen       option
#     -Rcvmode          protocol received mode ;option; default 2
#     -Rpsmode          response mode,;option; default 3
#     -UpdateInterval    update packet interval; option; default 30 second
#     -Rcvmode:
#            0  ripngIgnore          (default) Received updates are ignored.
#            1  ripngStore           Received updates are held and re-advertised.
#     -ResponseMode :
#            0  ripngSplitHorizon    (default) Do not include routes received from a router back to that router.
#            1  ripngNoSplitHorizon  Repeat all received routes back to all routers.
#            2  ripngPoisonReverse   Repeat routes received from a router back to that router, but with a metric of 16 indicating
#Usage: port1 AddRIPngSession -SessNo 1 -IpAddr 2007::1/64
######################################################################
::itcl::body CIxiaPortETH::AddRIPngSession { args }  {
    set retVal $::CIxia::gIxia_OK

    set args [string tolower $args]
    if {[checkForMissingArgs "-sessno -ipaddr" $args] == -1} {
        return $::CIxia::gIxia_ERR
    }
    Log "***AddRIPngSession $args"
    set prefixlen  64
    set rcvmode 0
    set responsemode 0
    set updateinterval 30
    get_params $args
    switch $rcvmode {
        1 {set rcvmode ripngStore}
        0 -
        default {set rcvmode ripngIgnore}
    }
    switch $responsemode {
        1 {set responsemode ripngNoSplitHorizon}
        2 {set responsemode ripngPoisonReverse}
        0 -
        default {set responsemode ripngSplitHorizon}
    }

    if {[checkSessionCreated $_chassis $_card $_port $sessno "Ripng"]} {
        Log "RIPng session $sessno has been created" warning
        return $::CIxia::gIxia_ERR 
    }

    Log " \n step Bring up RIPng Session... \n"

    set ipAddr [ list $ipaddr $prefixlen ]
    if {[intfConfig -port "$_chassis $_card $_port" -proto_type "ipv6" -ipv6Conf $ipAddr] == -1} {
        Log  "Configure Port ($chassis_id:$card:$port) IPAddress/preifx ( $ipAddr ) error " warning
        return $::CIxia::gIxia_ERR 
    }
    after 1000

    #This command configures the RIPng parameters.
    if {[rpe_ripng_conf $sessno $_chassis $_card $_port $ipaddr $rcvmode $responsemode $updateinterval]} {
        Log "Configure RIPng protcol on port ($chassis_id:$card:$port) error" warning
        return $::CIxia::gIxia_ERR 
    }
    after 1000

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    if {[ ixCheckLinkState portList ] } {
        Log "One or more links are down" warning
        return $::CIxia::gIxia_ERR
    }

    if {[StartRoutingEngine $portList "Ripng"] == -1} {
        Log "Could not Start RIPng for $portList at AddRIPngSession procedure" warning
        return $::CIxia::gIxia_ERR
    }
    
    return $retVal
}

######################################################################
#@@Proc 
#Name: DeleteRIPngSession
#Desc: 
#Args:
#            -SessNo,        RIPng Session id; option; default all neighbors on port
#Usage: port1 DeleteRIPngSession -SessNo 1
######################################################################
::itcl::body CIxiaPortETH::DeleteRIPngSession {  args  } {
    global Ripngindex

    set retVal $::CIxia::gIxia_OK
    get_params $args

    Log "***DeleteRIPngSession $args"    
    # Select port for ripng commands
    ripngServer select $_chassis $_card $_port

    if {![info exists sessno]} {

        ripngServer  clearAllRouters
        ripngServer set
        ripngServer write

        clearProtocolIndex "Ripng" $_chassis $_card $_port
        clearPoolInfo "Ripng" $_chassis $_card $_port
        clearService "Ripng" $_chassis $_card $_port

        if {[StopRouteEngine $portList "Ripng"]} {
            Log "Could not Stop RIPng protocol on port $portList" warning
            return $::CIxia::gIxia_ERR 
        }
    } elseif {[ripngServer getRouter $sessno]} {
        Log "Could not retrieve $sessno, RIPngServer" warning
        return $::CIxia::gIxia_ERR
    } else {
        ripngServer delRouter $sessno
        ripngServer set
        ripngServer write

        delRipngIndex $_chassis $_card $_port $sessno
        DelRipngPoolInfo "Ripng" $_chassis $_card $_port "all"

        if {[llength $Ripngindex($_chassis,$_card,$_port)] == 0} {
            if {[StopRouteEngine $portList "Ripng"]} {
                Log "Could not Stop RIPng protocol on port $portList" warning
                return $::CIxia::gIxia_ERR 
          }
            clearService "Ripng" $_chassis $_card $_port
        }
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    if {[llength $Ripngindex($_chassis,$_card,$_port)] > 0} {
        if {[StartRoutingEngine $portList "Ripng"] == -1} {
            Log "Could not Start RIPng for $portList at DeleteRIPngSession procedure" warning
            set retVal $::CIxia::gIxia_ERR   
        }
    }

    return $retVal
}

######################################################################
#@@Proc 
#Name: OpenRIPngSession
#Desc: 
#Args:
#            -SessNo, RIPng Session id; option; default all neighbors on port
#Usage: port1 OpenRIPngSession -SessNo 1
######################################################################
::itcl::body CIxiaPortETH::OpenRIPngSession { args } {    
    global Ripngindex
    set retVal $::CIxia::gIxia_OK

    Log "***OpenRIPngSession $args"
    get_params $args

    if {![info exists sessno]} {
        if {[enableRipngSession -port $portList] == -1} {
            Log "enable RIPng Session error" warning
            return $::CIxia::gIxia_ERR   
        }
    } else {
        if {[enableRipngSession -port $portList -SessNo $sessno] == -1} {
            Log "enable RIPng Session error" warning
            return $::CIxia::gIxia_ERR  
        }
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }

    # Enable the RIPng protocol
    if {[StartRoutingEngine $portList "Ripng"] == -1} {
        Log "Could not Start RIPng for $portList at OpenRIPngSession procedure" warning
        set retVal 0    
    }

    return $retVal
}



######################################################################
#@@Proc 
#Name: CloseRIPngSession
#Desc: 
#Args:
#     -SessNo,        RIPng Session id; option; default all neighbors on port
#Usage: port1 CloseRIPngSession -SessNo 1
######################################################################
::itcl::body CIxiaPortETH::CloseRIPngSession { args } {    
    global Ripngindex
    Log "***CloseRIPngSession $args"

    set retVal $::CIxia::gIxia_OK

    get_params $args

    if {![info exists sessno]} {
        if {[disableRipngNeighbor -port $portList] == -1} {
            Log "disable RIPng service error " warning
            return $::CIxia::gIxia_ERR        
        }
    } else {
       if {[disableRipngNeighbor -port $portList -SessNo $sessno] == -1}  {
           Log "disable RIPng service error" warning
           return $::CIxia::gIxia_ERR        
       }
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }

    # Enable the RIPng protocol
    if {[StartRoutingEngine $portList "Ripng"] == -1} {
        Log "Could not Start RIPng for $portList at OpenRIPngSession procedure" warning
        set retVal 0    
    }

    return $retVal
}


######################################################################
#@@Proc 
#Name: AddRIPngRoutePool
#Desc: 
#Args:
#     -SessNo,        RIPng Session id; mandatory;
#     -PoolNo,
#     -IpAddr
#     -PrefixLen  (default 64)
#     -RouteNum     (default 100)
#     -Nexthop    (default 0::0)
#     -Metric    (default 2)
#Usage: port1 AddRIPngRoutePool -SessNo 1 -PoolNo 1 -IpAddr 2006::1/6
######################################################################
::itcl::body CIxiaPortETH::AddRIPngRoutePool { args }  {
    set retVal $::CIxia::gIxia_OK

    set args [string tolower $args]
    if {[checkForMissingArgs "-sessno -poolno -ipaddr" $args] == -1} {
        return $::CIxia::gIxia_ERR   
    }
    Log "***AddRIPngRoutePool $args"
    set prefixlen 64
    set routenum 100
    set nexthop 0:0:0:0:0:0:0:0
    set metric 2
    get_params $args

    if {[checkSessionCreated $_chassis $_card $_port $sessno "Ripng"] == 0} {
        Log "RIPng Router $sessno has not been created" warning
        return $::CIxia::gIxia_ERR  
    }

    if {[checkPoolCreated $_chassis $_card $_port $sessno $poolno "Ripng"] == 1} {
        Log "Routes Pool $poolno has been created " warning
        return $::CIxia::gIxia_ERR
    }

    # Select the port and clear all defined routers
    ripngServer select $_chassis $_card $_port

    ripngRouteRange   setDefault
    ripngRouteRange   config       -enable          true
    ripngRouteRange   config       -routeTag        0
    ripngRouteRange   config       -networkIpAddress $ipaddr
    ripngRouteRange   config       -maskWidth        $prefixlen
    ripngRouteRange   config       -step             1
    ripngRouteRange   config       -numRoutes       $routenum
    ripngRouteRange   config       -nextHop         $nexthop
    ripngRouteRange   config       -metric          $metric
    ripngRouteRange   config       -enableIncludeLoopback    true
    ripngRouteRange   config       -enableIncludeMulticast   true

    if {[ripngServer getRouter $sessno]} {
        Log "get RIPng router $sessno error " warning
        return $::CIxia::gIxia_ERR        
    }

    ripngRouter config  -enable true
    ripngRouter addRouteRange  $poolno
    ripngServer setRouter $sessno
    ripngServer write

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    # Enable the Ripng protocol
    if {[StartRoutingEngine $portList "Ripng"] == -1} {
        Log "Could not Start RIPng for $portList at AddRIPngRoutePool procedure" warning
        set retVal $::CIxia::gIxia_ERR    
    }

    AddRipngPoolInfo $sessno $_chassis $_card $_port $poolno

    return $retVal
}

######################################################################
#@@Proc 
#Name: DeleteRIPngRoutePool
#Desc: 
#Args:
#     -SessNo,        RIPng Session id; mandatory;
#     -PoolNo,        routes pool id; option ; default all;
#Usage: port1 DeleteRIPngRoutePool -SessNo 1 -PoolNo 1
######################################################################
::itcl::body CIxiaPortETH::DeleteRIPngRoutePool { args }  {
    global PoolRipngindex
    set retVal $::CIxia::gIxia_OK
    set poolno 0
    set sessno 0
    get_params $args
    Log "DeleteRIPngRoutePool -SessNo $sessno -PoolNo $poolno"

    if {$sessno == 0 && $poolno != 0} {
        error "route Pool identifier $poolno , but not specify RIPng Session identifier "
        return $::CIxia::gIxia_ERR  
    }

    if {$sessno == 0 && $poolno == 0} {
        DeleteRipngAllPool $_chassis $_card $_port
    } elseif {$sessno != 0 && $poolno == 0} {
        if {[checkSessionCreated $_chassis $_card $_port $sessno "Ripng"] == 0} {
            Log "RIPng session $sessno has not been created" warning
            return $::CIxia::gIxia_ERR 
        }

        DeleteRipngSessionPool $_chassis $_card $_port $sessno
    } elseif {$sessno != 0 && $poolno != 0} {
        if {[checkSessionCreated $_chassis $_card $_port $sessno "Ripng"] == 0} {
            Log "RIPng session $sessno has not been created" warning
            return $::CIxia::gIxia_ERR 
        }
        DeleteRipngSpecificPool $_chassis $_card $_port $sessno $poolno
    }

    if {[string match [config_port -ConfigType write] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR  
    }

    # Enable the RIPng protocol
    if {[StartRoutingEngine $portList "Ripng"] == -1} {
        Log "Could not Start RIPng for $portList at DeleteRIPngRoutePool procedure" warning
        set retVal $::CIxia::gIxia_OK    
    }

    return $retVal
}


####### BGP protocol interface ##########

##############################################################################
# @@Proc
# Name:    AddBgpSession
# Desc:    Simulate a BGP neighbor and enable
# option:  -SessNo,     bgp Session id; mandatory
#        -Protocol,    IPv4/IPv6 ; option ; default Ipv4
#        -BgpType,    IBGP/EBGP/BGPVPN  ;option   ; default EBGP
#        -SutAS,      SUT AS number     ; manditory
#        -SutIp,      SUT IP address&mask    ; manditory
#        -TestAS      tester AS number  ;option    ; manditory
#        -TestIp      tester IP address&mask ; manditory
#        -PrefixLen   Ip address mask.
# return :
#            1    sucessful    
#          0    fail
##############################################################################

::itcl::body CIxiaPortETH::AddBgpSession  { args }  {
    global protocolServiceEnable

    set tmpList [string tolower [lrange $args 0 end]]
    
    if { [checkForMissingArgs "-sessno -sutas -sutip -testas -testip" $tmpList ]== -1 } {
        return $::CIxia::gIxia_ERR
    }
    
    set bgptype "EBGP"
    set protocol "ipv4"
    set prefixlen 24    
    
    get_params $args

    if { [checkSessionCreated $_chassis  $_card  $_port $sessno "Bgp" ] } {
        Log "Bgp Session $sessno has been created" warning
        return $::CIxia::gIxia_ERR 
    }
    
    #Check BGP neighbor type:IBGP/EBGP
    if { $bgptype == "EBGP" &&  $sutas == $testas } {
        error " Bgp Session type:$bgptype, Not match SutAS($sutas) and Tester AS($testas)"
        return $::CIxia::gIxia_ERR 
    } elseif { $bgptype == "IBGP" && $sutas != $testas } {
        error " Bgp Session type:$bgptype, match SutAS($sutas) and Tester AS($testas)"
        return $::CIxia::gIxia_ERR 
    }
    
    Log " \n Bring up Bgp Seesion... \n"
    
    #Config protocol interface parameter, ip address, mask, gateway
    set ipAddr [ list $testip $prefixlen ]
    
    if { [ intfConfig -port "$_chassis $_card $_port" -proto_type $protocol -ipConf $ipAddr -gateway $sutip ] == -1 } {
        Log  "Configure Port ($_chassis:$_card:$_port) IPAddress/mask ( $ipAddr ) error " warning
        return $::CIxia::gIxia_ERR }
    after 1000    
    
    #Config BGP protocol parameters
    #This command configures the BGP parameters. 
    if { [rpe_bgp_conf $sessno $_chassis $_card $_port $protocol $bgptype $testip $testas $sutip $sutas ] == -1 } {
        Log "Configure BGP protocol on port ($_chassis:$_card:$_port) error" warning
        return $::CIxia::gIxia_ERR }
    after 1000
    
    if {[ ixCheckLinkState portList ] } {
        Log "One or more links are down" warning
        return $::CIxia::gIxia_ERR
    }
    
    #set up statatistics on port
    stat config -enableBgpStats true
    stat set  $_chassis $_card $_port
    stat write  $_chassis $_card $_port
    
    if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
        return $::CIxia::gIxia_ERR  
    }    
    
    
    if { [ StartRoutingEngine $portList "Bgp" ] == -1 } {
        Log "Could not Start BGP4 for $portList at AddBgpSession procedure"     warning
        return $::CIxia::gIxia_ERR
    }
    
    Log "--------------------Checking bgp Neighbor Status----------------------"
    if [rpe_check_status -port "$_chassis $_card $_port" -timeout 30] {
        Log "$_chassis $_card $_port - RETCODE 1" warning
        return $::CIxia::gIxia_ERR
    }
    Log "$_chassis $_card $_port - RETCODE 0"
    
    stat get statAllStats $_chassis $_card $_port
    set nei     [stat cget -bgpTotalSessionsEstablished]
    set ses     [stat cget -bgpTotalSessions]
    
    Log "Bgp Established Neighbous Number: $nei, Total session Number: $ses"
    Log "-----------------------------------------------------------------------"
    
    if {[ ixCheckLinkState portList ] } {
        Log "One or more links are down" warning
        return $::CIxia::gIxia_ERR
    }
    
    return $::CIxia::gIxia_OK
}

##############################################################################
# @@Proc
# Name:    DeleteBgpSession
# Desc:    Delete a BGP neighbor 
# option:  -SessNo,  bgp Session id; option 
#             if no defined, so delete all Sessions on port
# return :
#            1    sucessful    
#          0    fail
##############################################################################

::itcl::body CIxiaPortETH::DeleteBgpSession {  args  } {
    Log "Delete BGP Session ..."
    global Bgpindex

    set retCode 1
    set session_flag  0
      
    get_params $args
    
    if [info exists sessno] {
        set session_flag 1
    }
    
    # Select port for bgp4 commands
    bgp4Server select $_chassis $_card $_port    
    
    if { $session_flag == 0 } {
        bgp4Server clearAllNeighbors
        bgp4Server set
        bgp4Server write
        
        clearProtocolIndex "Bgp" $_chassis $_card $_port
        clearPoolInfo "Bgp" $_chassis $_card $_port 
        clearService "Bgp" $_chassis $_card $_port
        
        if { [StopRouteEngine $portList "Bgp" ] } {
            Log "Could not Stop Bgp protocol on port $portList" warning
            return $::CIxia::gIxia_ERR 
        }
    } else {
        if { [bgp4Server delNeighbor $sessno] } {
            Log " Delete Bgp Session $sessno on port($_chassis,$_card,$_port) error " warning
            return $::CIxia::gIxia_ERR 
        }
        bgp4Server set
        bgp4Server write
           
        delBgpIndex $_chassis $_card $_port $sessno
        DelBgpPoolInfo $_chassis $_card $_port $sessno "all"
        
        if { [llength $Bgpindex($_chassis,$_card,$_port)] == 0 } {
            if { [StopRouteEngine $portList "Bgp" ] == -1 } {
                Log "Could not Stop BGP4 for $portList at DelBGPSession procedure" warning
                return $::CIxia::gIxia_ERR 
                }
            
            #Set all options about bgp in protocolServer false
            clearService "Bgp" $_chassis $_card $_port    
        }
    }    
    
    if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
        return $::CIxia::gIxia_ERR  
    }    
    
    if { [ llength $Bgpindex($_chassis,$_card,$_port) ]  > 0 } {
        if { [ StartRoutingEngine $portList "Bgp" ] == -1 } {
            Log "Could not Start BGP4 for $portList at AddBgpSession procedure"     warning
            return $::CIxia::gIxia_ERR
        }
    }
    return $retCode
}

##############################################################################
# @@Proc
# Name:    OpenBgpSession
# Desc:    Open a BGP session
# option:  -SessNo,  bgp Session id; option 
#             if no defined, so delete all Sessions on port
# return :
#            1    sucessful    
#          0    fail
##############################################################################

::itcl::body CIxiaPortETH::OpenBgpSession { args } {
    Log "Open BGP Session ..."
    global Bgpindex
    
    set retCode 1    
    set sess_flag 0
    
    get_params $args
    
    if [info exists sessno] {
        set session_flag 1
    }
    
    if { $sess_flag == 0 } {
        #start bgp4 server on port
        if { [enableBgpSession -port $portList ] == -1 } {
            Log "Enable BGP session failed !"  warning
            return $::CIxia::gIxia_ERR
        }
    } else {
        if { [enableBgpSession -port $portList -SessNo $sessno] == -1 } { 
            Log "Enable BGP session $sessno failed !"  warning
            return $::CIxia::gIxia_ERR 
        }
    }
        
    if { [StartRoutingEngine $portList "Bgp" ]== -1 } {
        Log "Could not Start BGP4 for $portList at OpenBgpSession procedure" warning
        set retCode $::CIxia::gIxia_ERR
    }
    
    return $retCode
}

##############################################################################
# @@Proc
# Name:    CloseBgpSession
# Desc:    Close a BGP session
# option:  -SessNo,  bgp Session id; option 
#             if no defined, so delete all Sessions on port
# return :
#            1    sucessful    
#          0    fail
##############################################################################

::itcl::body CIxiaPortETH::CloseBgpSession { args } {
    Log "Close BGP Session ..."
    global Bgpindex
    
    set    retCode 1 
    set sess_flag 0
    
    get_params $args
    
    if [info exists sessno] {
        set session_flag 1
    }

    if { $sess_flag == 0 } {
        #stop bgp4 server on port
        if { [disableBgpSession -port $portList] == -1 } { 
            return $::CIxia::gIxia_ERR
        }
    
        if { [StopRouteEngine $portList "Bgp" ] == -1 }    {
            Log "Could not stop BGP4 for $portList at CloseBgpSession procedure" warning
            return $::CIxia::gIxia_ERR
        }
    } else {
        if { [disableBgpSession -port $portList -SessNo $sessno ] == -1 } { 
            return $::CIxia::gIxia_ERR 
        }
    }
    
    return $retCode
}

##############################################################################
# @@Proc
# Name:    AddBgpRoutePool
# Desc:    Add BGP route pool
# option:  -SessNo,  Bgp Session id
#          -PoolNo,  Bgp pool id
#          -NextHop, next hop
#          -Protocol, Route pool type, one of ipv4/ipv6/ipv4ipv6, default ipv4
#          -FirstRoute, The first route of route pool
#          -PrefixLen, Prefix length
#          -Modifier, Increasement of route pool
#          -RouteNum, The number of route
# return :
#            1    sucessful    
#          0    fail
##############################################################################

::itcl::body CIxiaPortETH::AddBgpRoutePool { args }  {
    Log "Add BGP route pool ..."
    set retCode 1
    set tmpList [string tolower [lrange $args 0 end]]
    
    if { [checkForMissingArgs "-sessno -poolno -firstroute -nexthop" $tmpList ]== -1 } {
        return $::CIxia::gIxia_ERR
    }
    
    set protocol "ipv4"
    set prefix 24
    set routenum 50

    set bgporigin bgpOriginIGP            
    set aspathsetmode bgpRouteAsPathIncludeAsSeq
    set modifier 1
        
    get_params $args
    
    if { [checkSessionCreated $_chassis $_card $_port $sessno "Bgp" ] == 0 } {
        Log "Bgp Session $sessno has not been created" warning
        return $::CIxia::gIxia_ERR 
    }
        
    if { [ checkPoolCreated $_chassis $_card $_port $sessno $poolno "Bgp" ] == 1 } {
        Log  " Routes Pool $poolId has been created " warning
        return $::CIxia::gIxia_ERR
    }
    set rec_iptype [ getBgpSessionIptype $_chassis $_card  $_port $sessno ]
    if { [string compare -nocase $rec_iptype $protocol] != 0 } {
        Log " IP type ($rec_iptype) of created Session Not mattch with calling iptype($protocol)" warning
        return $::CIxia::gIxia_ERR
    }
    set aspathList {}
    set bgptype [ getBgptype $_chassis $_card $_port $sessno ]
    if { $bgptype == "IBGP" } {
        set aspathsetmode bgpRouteAsPathNoInclude
        set aspathList "20 30"
    } elseif { $bgptype == "EBGP" } { }
    
    bgp4Server select $_chassis $_card $_port
    if { [bgp4Server getNeighbor $sessno ] } {
        Log "Could not retrieve Bgp Session $sessno" warning
        return $::CIxia::gIxia_ERR
    }
    
    if { [string compare -nocase $protocol "ipv4"] == 0 } {
        set ip_type "addressTypeIpV4" 
    } elseif { [ string compare -nocase $protocol "ipv6" ] == 0 } {
        set ip_type "addressTypeIpV6"
    }
    
    bgp4AsPathItem   setDefault        
    bgp4AsPathItem   config   -enableAsSegment       true
    bgp4AsPathItem   config   -asList                $aspathList
    bgp4AsPathItem   config   -asSegmentType         bgpSegmentAsSequence
    bgp4RouteItem    addASPathItem     
    
    bgp4RouteItem    setDefault        
    bgp4RouteItem    config    -networkAddress       $firstroute
    bgp4RouteItem    config    -ipType               $ip_type
    bgp4RouteItem    config    -fromPrefix           $prefix
    bgp4RouteItem    config    -thruPrefix           $prefix
    bgp4RouteItem    config    -numRoutes            $routenum
    bgp4RouteItem    config    -fromPacking          0
    bgp4RouteItem    config    -thruPacking          0
    bgp4RouteItem    config    -enableRouteFlap      false
    bgp4RouteItem    config    -routeFlapTime        0
    bgp4RouteItem    config    -routeFlapDropTime    0
    bgp4RouteItem    config    -enableNextHop        true
    bgp4RouteItem    config    -nextHopIpAddress     $nexthop
    bgp4RouteItem    config    -nextHopIpType        $ip_type
    bgp4RouteItem    config    -nextHopMode          bgpRouteNextHopIncrement
    bgp4RouteItem    config    -nextHopSetMode       bgpRouteNextHopSetSameAsLocalIp
    
    bgp4RouteItem    config    -enableOrigin         true
    bgp4RouteItem    config    -originProtocol       $bgporigin
    
    bgp4RouteItem    config    -enableLocalPref      true
    bgp4RouteItem    config    -localPref            0
    
    bgp4RouteItem    config    -enableMED            false
    bgp4RouteItem    config    -med                  0
    
    bgp4RouteItem    config    -enableCommunity      false
    bgp4RouteItem    config    -communityList        ""
    
    bgp4RouteItem    config    -enableAtomicAggregate              false
    bgp4RouteItem    config    -enableAggregator                   false
    bgp4RouteItem    config    -aggregatorIpAddress                "0.0.0.0"
    bgp4RouteItem    config    -aggregatorASNum                    0
    bgp4RouteItem    config    -aggregatorIDMode                   1
    
    bgp4RouteItem    config    -enableOriginatorId                 false
    bgp4RouteItem    config    -originatorId                       "0.0.0.0"
    
    bgp4RouteItem    config    -enableCluster                      false
    bgp4RouteItem    config    -clusterList                        ""
    
    bgp4RouteItem    config    -enableASPath                       true
    bgp4RouteItem    config    -enablePartialFlap                  false
    bgp4RouteItem    config    -routesToFlapFrom                   0
    bgp4RouteItem    config    -routesToFlapTo                     0
    bgp4RouteItem    config    -iterationStep                      $modifier
    bgp4RouteItem    config    -enableGenerateUniqueRoutes         false
    bgp4RouteItem    config    -enableRouteRange                   true
    bgp4RouteItem    config    -asPathSetMode                      $aspathsetmode
    
    bgp4RouteItem    config    -enableIncludeLoopback              false
    bgp4RouteItem    config    -enableIncludeMulticast             false
    bgp4RouteItem    config    -enableProperSafi                   false
    bgp4RouteItem    config    -enableTraditionalNlriUpdate        true
    bgp4RouteItem    config    -delay                              0
    bgp4RouteItem    config    -endOfRIB                           0
    bgp4Neighbor     addRouteRange     $poolno
    
    #bgp4RouteItem    clearASPathList   
    
    bgp4Server setNeighbor $sessno
    bgp4Server set
    bgp4Server write
    
    if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
        return $::CIxia::gIxia_ERR  
    }    
    
    if { [StartRoutingEngine $portList "Bgp" ]== -1 } {
        Log "Could not Start Bgp for $portList " warning
        set retCode $::CIxia::gIxia_ERR     
    }
    
    if {[ ixCheckLinkState portList ] } {
        Log "One or more links are down" warning
        return $::CIxia::gIxia_ERR
    }
    
    AddBgpPoolInfo $sessno $_chassis $_card $_port $poolno
    return $retCode
}

##############################################################################
# @@Proc
# Name:    DeleteBgpRoutePool
# Desc:    Delete BGP route pool
# option:  -SessNo,  bgp Session id; option 
#             if no defined, so delete all Sessions on port
#          -PoolNo,  Route pool id; option
# return :
#            1    sucessful    
#          0    fail
##############################################################################

::itcl::body CIxiaPortETH::DeleteBgpRoutePool { args }  {
    Log "Delete BGP route pool ..."
    global PoolBgpindex

    set retCode 1
    set poolno 0 
    set sessno 0
    
    get_params $args
    
    if { $sessno == 0 && $poolno != 0 } {
        error "route Pool identifier $poolno , but not specify Bgp Session identifier "
        return $::CIxia::gIxia_ERR    
    }
    
    if { $sessno == 0 && $poolno == 0 } {
        DeleteBgpAllPool $_chassis $_card $_port
    } elseif { $sessno != 0 && $poolno == 0 } {
        if { [checkSessionCreated $_chassis $_card $_port $sessno "Bgp" ] == 0 } {
        Log "Bgp session $sessno has not been created" warning
        return $::CIxia::gIxia_ERR 
    }
    
        DeleteBgpSessionPool $_chassis $_card $_port $sessno
    } elseif { $sessno != 0 && $poolno != 0 } {
        if { [checkSessionCreated $_chassis $_card $_port $sessno "Bgp" ] == 0 } {
              Log "Bgp session $sessno has not been created" warning
              return $::CIxia::gIxia_ERR 
        }
    
        DeleteBgpSpecificPool $_chassis $_card $_port $sessno $poolno
    } 
    
    if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
        return $::CIxia::gIxia_ERR  
    }    
    
    if { [StartRoutingEngine $portList "Bgp" ]== -1 } {
        Log "Could not Start Bgp for $portList " warning
        set retCode $::CIxia::gIxia_ERR    
    }
    return $retCode
}

##############################################################################
# @@Proc
# Name:    SetBgpPoolOption
# Desc:    Set BGP pool option
# option:  -SessNo,  bgp Session id
#          -PoolNo,  Route pool id
#          -Advertise, Y/N, default Y
#          -Flap, Y/N, default N
# return :
#            1    sucessful    
#          0    fail
##############################################################################

#global BgpPoolOption { { SessNo { PoolNo_1 advertise flap } { PoolNo_2 advertise flap } } ...
#                       {SessNo { PoolNo_1 advertise flap } { PoolNo_2 advetise flap } } }
::itcl::body CIxiaPortETH::SetBgpPoolOption { args }  {
    Log "Set BGP pool option ..." 
    set retCode 1
    
    set tmpList [string tolower [lrange $args 0 end]]
    
    if { [checkForMissingArgs "-sessno -poolno" $tmpList ]== -1 } {
        return $::CIxia::gIxia_ERR
    }
    
    set retCode 1
    
    set advertise "Y"
    set flap "N"

    get_params $args
    
    if [info exists advertise] {
        set advertise [string toupper $advertise]
        if { $advertise != "Y" && $advertise != "N" } {
            error " Input error Advertise flag , should be (Y/N) but $advertise"
            return $::CIxia::gIxia_ERR    
        }
    }
    if [info exists flap] {
        set flap [string toupper $flap]
        if { $flap != "Y" && $flap != "N" } {
            error "Input error Flap parameter, should be (Y/N) but $flap"
            return $::CIxia::gIxia_ERR
        }
    }

    #check Session whether has been created
    if { [checkSessionCreated $_chassis  $_card  $_port $sessno "Bgp" ] == 0 } {
        Log "Bgp Session $sessno has not been created" warning
        return $::CIxia::gIxia_ERR 
    }
        
    #check Pool whether has been has been created 
    if { [ checkPoolCreated $_chassis $_card $_port $sessno $poolno "Bgp" ] == 0 } {
        Log  " Routes Pool $poolno has not been created " warning
        return $::CIxia::gIxia_ERR
    }
    
    if { [ updateBgpRoutePool $_chassis $_card $_port $sessno $poolno $advertise $flap ] == -1 } {
        Log "set Bgp  route Pool Option error" warning
        return $::CIxia::gIxia_ERR 
    }
    
    if { [ixStartBGP4  portList] } {
        Log "Start Bgp protocol Error" warning
        return $::CIxia::gIxia_ERR 
    }    
    
    if {[ ixCheckLinkState portList ] } {
        Log "One or more links are down" warning
        return $::CIxia::gIxia_ERR
    }
    
    return $retCode    
}

##############################################################################
# @@Proc
# Name:    SetBgpFlapOption
# Desc:    Edit BGP flap option
# option:  -SessNo,  bgp Session id
#          -RoutesPerUpdate, The number of route in update per flap
#          -InterUpdateDelay, The interval of update when Advertise 
#                             and withDraw, 1 -- 10000, default 1000
#          -AdvertiseToWithDrawDelay, Interval from Advertise to withDraw,
#                                     1 -- 7200000, default 10000
#          -WithDrawToAdvertiseDelay, Interval from withDraw to Advertise,
#                                     1 -- 7200000, default 10000
# return :
#            1    sucessful    
#          0    fail
##############################################################################
# global BgpFlapOption { {SessNo flap {RoutesPerUpdate , InterUpdateDelay,AdvertiseToWithDrawDelay, WithDrawToAdvertiseDelay } } ... {} }

::itcl::body CIxiaPortETH::SetBgpFlapOption   { args }  {
    Log "Edit BGP flap option ..."
    global PoolBgpindex
     
    set tmpList [string tolower [lrange $args 0 end]]
    
    if { [checkForMissingArgs "-sessno" $tmpList ]== -1 } {
        return $::CIxia::gIxia_ERR
    }
    
    set retCode 1
    
    set routesperupdate  1000
    set interupdatedelay 1000
    
    # default ms
    set advertisetowithdrawdelay 10000
    set withdrawtoadvertisedelay 10000
    
    get_params $args
    
    if [info exists routesperupdate] {
        if { $routesperupdate < 1 || $routesperupdate > 2000 } {
            error "Please input RoutesPerUpdate value 1--2000"
            return $::CIxia::gIxia_ERR 
        }
    }

    if [info exists interupdatedelay] {
        if { $interupdatedelay < 1 || $interupdatedelay > 10000 } {
            error "please input InterUpdateDelay value 1--10000"
            return $::CIxia::gIxia_ERR 
        }
    }

    if [info exists advertisetowithdrawdelay] {
        if { $advertisetowithdrawdelay < 1 || $advertisetowithdrawdelay > 7200000 } {
           error "Please input AdvertiseToWithDrawDelay value  1--7200000"
           return $::CIxia::gIxia_ERR 
         }
    }

    if [info exists withdrawtoadvertisedelay] {
        if { $withdrawtoadvertisedelay < 1 || $withdrawtoadvertisedelay > 7200000 } {
           error "Please input WithDrawToAdvertiseDelay value 1--7200000"
           return $::CIxia::gIxia_ERR 
        }
    }
    
    #check Session whether has been created
    if { [checkSessionCreated $_chassis  $_card  $_port $sessno "Bgp" ] == 0 } {
        Log "Bgp Session $sessno has not been created" warning
        return $::CIxia::gIxia_ERR 
    }
        
    if { [array exists PoolBgpindex ] == 0 } {
        Log "Pool has not been create on session $sessno" warning
        return $::CIxia::gIxia_ERR 
    } elseif { [ info exists PoolBgpindex($_chassis,$_card,$_port) ] == 0 } {
        Log "Pool has not been create on session $sessno" warning
        return $::CIxia::gIxia_ERR 
    }
    
    set InterUpdateDelay_s [ expr $interupdatedelay / 1000 ]
    set AdvertiseToWithDrawDelay_s [ expr $advertisetowithdrawdelay / 1000 ]
    set WithDrawToAdvertiseDelay_s [ expr $withdrawtoadvertisedelay / 1000 ]
    
    bgp4Server select $_chassis $_card $_port
    bgp4Server getNeighbor $sessno
    
    set PoolLen [ llength $PoolBgpindex($_chassis,$_card,$_port) ]
    
    set idx 0
    set updated 0
    foreach cursor $PoolBgpindex($_chassis,$_card,$_port) {
        set cur_sess [ lindex $cursor 0 ]
        
        if { $cur_sess == $sessno } {
            set var_pool [ lindex $cursor 1 ]
    
            if { [llength $var_pool] > 0 } {
                set updated  1
            }
                
            foreach cursor_1 $var_pool {
                bgp4Neighbor getRouteRange $cursor_1
                #bgp4RouteItem config -enableRouteFlap true
                bgp4RouteItem config -routeFlapTime  $AdvertiseToWithDrawDelay_s
                bgp4RouteItem config -routeFlapDropTime $WithDrawToAdvertiseDelay_s
                bgp4Neighbor setRouteRange $cursor_1            
            }
            bgp4Server setNeighbor $sessno
            break
        }
    }    
    
    if { $updated } {
        bgp4Server set
        bgp4Server write  
        if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
            Log "write Bgp configure parameter to hardware Error" warning
            return $::CIxia::gIxia_ERR  
        }    
    }
    
    #if { [ixStartBGP4  portList] } {
    #    Log "Start Bgp protocol Error" warning
    #    return 0 }    
    
    return $retCode
}

##############################################################################
# @@Proc
# Name:    StartBgpPoolFlap
# Desc:    Start BGP pool flap
# option:  -SessNo,  bgp Session id
#             if no defined, so delete all Sessions on port
# return :
#            1    sucessful    
#          0    fail
##############################################################################


::itcl::body CIxiaPortETH::StartBgpPoolFlap {args} {
    Log "Start BGP pool flap ..."
    global PoolBgpindex
    
    set retCode 1
    set sess_flag 0
   
    get_params $args
    
    if [info exists sessno] {
        set sess_flag 1
    }
    
    #check Session whether has been created
    if { [checkSessionCreated $_chassis $_card $_port $sessno "Bgp" ] == 0 } {
        Log "Bgp Session $sessno has not been created" warning
        return $::CIxia::gIxia_ERR 
    }

    if { [array exists PoolBgpindex] == 0 } {
        Log "Bgp Pool has not been created " warning
        return $::CIxia::gIxia_ERR
    } elseif { [info exists PoolBgpindex($_chassis,$_card,$_port)] == 0 } {
        Log "Bgp Pool has not been created" warning
        return $::CIxia::gIxia_ERR
    }
        
    set updated 0 
        
    bgp4Server select $_chassis $_card $_port
    
    if { $sess_flag == 0 } {
        foreach cursor $PoolBgpindex($_chassis,$_card,$_port) {
            set cur_sess [ lindex $cursor 0 ]
            set cur_pool [ lindex $cursor 1 ]
            
            if { [llength $cur_pool] == 0 } {
                continue }

            if { $updated == 0 } {
                set updated 1 }
                            
            bgp4Server getNeighbor $cur_sess
    
            foreach varPool $cur_pool {
                bgp4Neighbor getRouteRange $varPool
                bgp4RouteItem config -enableRouteFlap true
                bgp4Neighbor setRouteRange $varPool
            }    
    
            bgp4Server setNeighbor $cur_sess
        }
    } elseif { $sess_flag == 1 } {
        set finished 0
        foreach cursor $PoolBgpindex($_chassis,$_card,$_port) {
            set cur_sess [ lindex $cursor 0 ]
            if { $cur_sess == $sessno }  {
                set finished 1
                                
                set cur_pool [ lindex $cursor 1 ]
            
                    if { [llength $cur_pool] == 0 } {
                    break }

                 set updated  1
                bgp4Server getNeighbor $cur_sess
    
                foreach varPool $cur_pool {
                    bgp4Neighbor getRouteRange $varPool
                    bgp4RouteItem config -enableRouteFlap true
                    bgp4Neighbor setRouteRange $varPool
                }    
    
                bgp4Server setNeighbor $cur_sess
            }
            if { $finished } break
        }
    }

    if { $updated == 1 } {
        bgp4Server set
        bgp4Server write    
        if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
            Log "write Bgp configure parameter to hardware Error" warning
            return $::CIxia::gIxia_ERR  
        }    
    }
     
    if { [ixStartBGP4  portList] } {
        Log "Start Bgp protocol Error" warning
        return $::CIxia::gIxia_ERR
    }

    return $retCode         
}

##############################################################################
# @@Proc
# Name:    StopBgpPoolFlap
# Desc:    Stop BGP pool flap
# option:  -SessNo,  bgp Session id
#             if no defined, so delete all Sessions on port
# return :
#            1    sucessful    
#          0    fail
##############################################################################

::itcl::body CIxiaPortETH::StopBgpPoolFlap  { args }  {
    Log "Stop BGP pool flap ..."
    global PoolBgpindex

    set retCode 1
    set sess_flag 0
    
    get_params $args
    
    if [info exists sessno] {
        set sess_flag 1
    }

    #check Session whether has been created
    #if { [checkSessionCreated $chassis_id  $card  $port $sessionId "Bgp" ] == 0 } {
    #    Log "Bgp Session $sessionId has not been created" warning
    #    return 0 }

    if { [array exists PoolBgpindex] == 0 } {
        error "Bgp Pool has not been created "
        return $::CIxia::gIxia_ERR
    } elseif { [info exists PoolBgpindex($_chassis,$_card,$_port)] == 0 } {
        error "Bgp Pool has not been created"
        return $::CIxia::gIxia_ERR
    }
        
    set updated 0 
        
    bgp4Server select $_chassis $_card $_port
    
    if { $sess_flag == 0 } {
        foreach cursor $PoolBgpindex($_chassis,$_card,$_port) {
            set cur_sess [ lindex $cursor 0 ]
            set cur_pool [ lindex $cursor 1 ]
            
            if { [llength $cur_pool] == 0 } {
                continue }

            if { $updated == 0 } {
                set updated 1 }
                            
            bgp4Server getNeighbor $cur_sess
    
            foreach varPool $cur_pool {
                bgp4Neighbor getRouteRange $varPool
                bgp4RouteItem config -enableRouteFlap false
                bgp4Neighbor setRouteRange $varPool
            }    
    
            bgp4Server setNeighbor $cur_sess
        }
    } elseif { $sess_flag == 1 } {
        set finished 0
        foreach cursor $PoolBgpindex($_chassis,$_card,$_port) {
            set cur_sess [ lindex $cursor 0 ]
            if { $cur_sess == $sessno }  {
                set finished 1
                                
                set cur_pool [ lindex $cursor 1 ]
            
                    if { [llength $cur_pool] == 0 } {
                    break }

                 set updated  1
                bgp4Server getNeighbor $cur_sess
    
                foreach varPool $cur_pool {
                    bgp4Neighbor getRouteRange $varPool
                    bgp4RouteItem config -enableRouteFlap false
                    bgp4Neighbor setRouteRange $varPool
                }    
    
                bgp4Server setNeighbor $cur_sess
            }
            if { $finished } break
        }
    }

    if { $updated == 1 } {
        bgp4Server set
        bgp4Server write
        if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
            Log "write Bgp configure parameter to hardware Error" warning
            return $::CIxia::gIxia_ERR  
        }    
    }
      
    if { [ixStartBGP4  portList] } {
        Log "Start Bgp protocol Error" warning
        return $::CIxia::gIxia_ERR 
    }    
 
    return $retCode     
}


############################### Protocol ISIS API ######################

######################################################################
# @@Proc
# Name:    AddIsisNei
# Desc:    Simulate a ISIS neighbor and enable
# option:  -NeiNo,        Isis Session id; mandatory
#          -SutIp,        dut ip address
#          -TestIp,       tester ip address
#          -PrefixLen,    prefix length
#          -AreaId,       area id
#          -SysId,        system id
#          -Level,        level,one of L1/L2/L12
#          -IpMode,       ip mode, one of ipv4/ipv6/ipv4ipv6,default ipv4
#          -WideMetrics   wide metrics(Y/N), default N
# return : 
#          1    sucessful
#          0    fail
######################################################################

::itcl::body CIxiaPortETH::AddIsisNei { args }  {
    Log "Add Isis neighbor ..."
    set retCode 1
    
    set tmpList [string tolower [lrange $args 0 end]]
    
    if { [checkForMissingArgs "-neino -sutip -testip -areaid -sysid" $tmpList ]== -1 } {
        return $::CIxia::gIxia_ERR
    }
    
    #set default  value
    set prefixlen  24
    set configPrefixFlag 0
    
    set level isisLevel1Level2
    set ipmode ipv4
    set widemetrics "No"   

    get_params $args

    if [info exists prefixlen] {
        set configPrefixFlag 1
    }
        
    if [info exists level] {
        if { [ string compare -nocase $level "l1" ] == 0 } {
            set level isisLevel1
        } elseif { [string compare -nocase $level "l2" ] == 0 } {
            set level isisLevel2
        } elseif { [string compare -nocase $level "l12" ]== 0 } {
            set level isisLevel1Level2 
        }
    }
    
    if [info exists ipmode] {
        if { [string compare -nocase $ipmode "ipv4" ] == 0 } {
            set ipmode "ipv4"
        } elseif { [string compare -nocase $ipmode "ipv6"] == 0 } {
            set ipmode "ipv6"
        }
    }
    
    if { [checkSessionCreated $_chassis $_card  $_port $neino "Isis" ] } {
        Log "Isis Session $neino has been created" warning
        return $::CIxia::gIxia_ERR 
    }
    
    Log " \n step Bring up Isis Session... \n"
    
    if { [ string compare $ipmode "ipv4"] == 0 } {
        set ipAddr [ list $testip $prefixlen ]
    
        if { [ intfConfig -port "$_chassis $_card $_port" -proto_type "ipv4" -ipConf $ipAddr -gateway $sutip ] == -1 } {
            Log  "Configure Port ($_chassis:$_card:$_port) IPAddress/mask ( $ipAddr ) error " warning
            return $::CIxia::gIxia_ERR 
        }
    } elseif { [string compare $ipmode "ipv6"] == 0 } {
        if { $configPrefixFlag == 0 } {
            set prefixlen 64  
        }
        set ipAddr [ list $testip $prefixlen ]
            
        if { [ intfConfig -port "$_chassis $_card $_port" -proto_type "ipv6" -ipv6Conf $ipAddr ] == -1 } {
            Log  "Configure Port ($_chassis:$_card:$_port) IPAddress/mask ( $ipAddr ) error " warning
            return $::CIxia::gIxia_ERR 
        }
    }
    after 1000 
    
    #This command configures the Isis parameters. 
    if { [rpe_isis_conf $neino $_chassis $_card $_port $testip $prefixlen $areaid $sysid $level] == -1 } {
        Log "Configure Isis protcol on port ($_chassis:$_card:$_port) error" warning
        return $::CIxia::gIxia_ERR 
    }
    after 3000
    
    if { [ ixCheckLinkState portList ] } {
        Log "One or more links are down" warning
        return $::CIxia::gIxia_ERR 
    }
    
    if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
        return $::CIxia::gIxia_ERR
    }
        
    #set up statatistics on port
    stat config -enableProtocolServerStats true
    stat config -enableIsisStats true
    stat set  $_chassis $_card $_port
    stat write  $_chassis $_card $_port
        
    if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
        return $::CIxia::gIxia_ERR  
    }    
        
    if { [ StartRoutingEngine $portList "Isis" ] == -1 } {
        Log "Could not Start Isis for $portList at AddIsisNei procedure"     warning
        return $::CIxia::gIxia_ERR
    }
    
    Log "--------------------Checking Isis Neighbor Status----------------------"
    if [rpe_check_status -port "$_chassis $_card $_port" -timeout 60 -level $level] {
        Log "$_chassis $_card $_port - RETCODE 1" warning
        return $::CIxia::gIxia_ERR
    }
    Log "$_chassis $_card $_port - RETCODE 0"
    
    stat get statAllStats $_chassis $_card $_port
    set L1session     [stat cget -isisSessionsConfiguredL1]
    set L2session     [stat cget -isisSessionsConfiguredL2]
    
    set L1sessionup     [stat cget -isisSessionsUpL1]
    set L2sessionup     [stat cget -isisSessionsUpL2]
    
    Log "ISIS UP state L1Sessionup:$L1sessionup , Total Configure L1 session :$L1session"  
    Log "ISIS UP state L2Sessionup:$L2sessionup , Total Configure L2 session :$L2session"
    #Log "-----------------------------------------------------------------------"
    return $retCode
}


######################################################################
# @@Proc
# Name:    DeleteIsisNei
# Desc:    Delete a ISIS neighbor
# option:  -NeiNo,    ISIS Session id; option; default all neighbors on port 
# return:
#          1    sucessful
#          0    fail
######################################################################
::itcl::body CIxiaPortETH::DeleteIsisNei  {  args  } {
    Log "Delete ISIS neighbor ..."
    global Isisindex

    set retCode 1
    set neino   "all"
    
    get_params $args

    
    # Select port for Isis commands
    isisServer   select  $_chassis $_card $_port
    
    if { $neino == "all" } {
        isisServer clearAllRouters    
        isisServer write
        
        clearProtocolIndex "Isis" $_chassis $_card $_port
        clearPoolInfo "Isis" $_chassis $_card $_port
        clearService "Isis" $_chassis $_card $_port
        
        if { [StopRouteEngine $portList "Isis" ] } {
            Log "Could not Stop Isis protocol on port $portList" warning
        return $::CIxia::gIxia_ERR 
        }
        
    } elseif { [ isisServer getRouter $neino ] } {
            Log "Could not retrieve Isis neighbor $neino"  warning
            return $::CIxia::gIxia_ERR
    } else {
        isisServer delRouter $neino
        isisServer write
   
        delIsisIndex $_chassis $_card $_port $neino
        DelIsisPoolInfo $_chassis $_card $_port $neino "all"
            
        if { [llength $Isisindex($_chassis,$_card,$_port)] == 0 } {
            if { [StopRouteEngine $portList "Isis" ] == -1 } {
                Log "Could not Stop Isis for $portList at DeleteIsisNei procedure" warning
                return $::CIxia::gIxia_ERR    
            }
            clearService "Isis" $_chassis $_card $_port
        }    
    }
       
    if { [string match [config_port -ConfigType config] $::CIxia::gIxia_ERR] } {
        return $::CIxia::gIxia_ERR
    }
        
    if { [llength $Isisindex($_chassis,$_card,$_port)] > 0 } {
        if { [StartRoutingEngine $portList "Isis" ]== -1 } {
            Log "Could not Start Isis for $portList at DeleteIsisNei procedure" warning
            set retCode $::CIxia::gIxia_ERR    
       }
    }
    
    return $retCode
}

######################################################################
# @@Proc
# Name:    EnableIsisNei
# Desc:    Enable a ISIS neighbor
# option:  -NeiNo,    ISIS Session id; option; default all neighbors on port 
# return:
#          1    sucessful
#          0    fail
######################################################################

::itcl::body CIxiaPortETH::EnableIsisNei { args } {
    Log "Enable ISIS neighbor ..."
    global Ospfindex
    
    set retCode 1
    set neino   "all"
    
    get_params $args

    if { $neino == "all" } {
        #start ospf server on port
        if { [enableIsisSession -port $portList ] == -1 } {
            Log "Enable Isis Session error" warning
            return $::CIxia::gIxia_ERR 
        }
    } else {
        if { [enableIsisSession -port $portList -SessNo $neino] == -1 } {
            Log "Enable Isis Session error" warning
            return $::CIxia::gIxia_ERR 
        }
    }
        
    if {[string match [config_port -ConfigType config] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }
    
    if { [StartRoutingEngine $portList "Isis" ]== -1 } {
        Log "Could not Start Isis for $portList at EnableIsisNei procedure" warning
        set retCode $::CIxia::gIxia_ERR    
    }
    
    return $retCode
}

######################################################################
# @@Proc
# Name:    DisableIsisNei
# Desc:    Disable a ISIS neighbor
# option:  -NeiNo,    ISIS Session id; option; default all neighbors on port 
# return:
#          1    sucessful
#          0    fail
######################################################################

::itcl::body CIxiaPortETH::DisableIsisNei { args } {
    Log "Disable ISIS neighbor ..."
    global Ospfindex

    set retCode 1
    set neino   "all"
    
    get_params $args

    if { $neino == "all" } {
        if { [disableIsisSession -port $portList] == -1 } {
            Log "disable Isis Session error"  warning
            return $::CIxia::gIxia_ERR    
        }
    } else {
        if { [disableIsisSession -port $portList -SessNo $neino] == -1 } {
            Log "disable Isis Session $neino error"  warning
            return $::CIxia::gIxia_ERR    
        }
    }            
        
    if {[string match [config_port -ConfigType config] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }
    
    return $retCode
}

######################################################################
# @@Proc
# Name:    AddIsisNet
# Desc:    Add network on ISIS router
# option:  -NeiNo: ISIS Session id; option; default all neighbors on port 
#          -NetId: ISIS network id
#          -FirstIp: The first address of network
#          -PrefixLen: Prefix length
#          -Number: The number of routes
#          -IpMode: Ip mode, one of ipv4/ipv6/ipv4ipv6, default ipv4    
# return:
#          1    sucessful
#          0    fail
######################################################################

::itcl::body CIxiaPortETH::AddIsisNet { args } {
    Log "Add ISIS network ..."
    set tmpList [string tolower [lrange $args 0 end]]
    set retCode 1
    
    if { [checkForMissingArgs "-neino -netid -firstip" $tmpList ]== -1 } {
        return $::CIxia::gIxia_ERR
    }

    set prefixlen 24
    set number 50
    set ipmode "ipv4"
    
    get_params $args

    if [info exists ipmode] {
        if { [string compare -nocase $ipmode "ipv4" ] == 0 } {
            set ipmode "ipv4"
        } elseif { [string compare -nocase $ipmode "ipv6"] == 0 } {
            set ipmode "ipv6"
        }         
    }

    if { [checkSessionCreated $_chassis $_card $_port $neino "Isis" ] == 0 } {
        Log "Isis Router $neino has not been created" warning
        return $::CIxia::gIxia_ERR 
    }
    
    if { [ checkPoolCreated $_chassis $_card $_port $neino $netid "Isis" ] == 1 } {
        Log " Isis Routes Pool $netid has been created " warning
        return $::CIxia::gIxia_ERR 
    }
        
    if { $ipmode == "ipv4" } {
        set iptype addressTypeIpV4
    } elseif { $ipmode == "ipv6" } {
        set iptype addressTypeIpV6
    }
            
    # Select the port and clear all defined routers
    isisServer select $_chassis $_card $_port
        
    isisRouteRange       setDefault        
    isisRouteRange       config   -enable   true
    isisRouteRange       config   -metric   0
    isisRouteRange       config   -numberOfNetworks        $number
    isisRouteRange       config   -prefix                  $prefixlen
    isisRouteRange       config   -networkIpAddress        $firstip
    isisRouteRange       config   -enableRedistributed     false
    isisRouteRange       config   -routeOrigin             isisRouteInternal
    isisRouteRange       config   -ipType                  $iptype
    
    if { [isisServer getRouter $neino]} {
        Log "get Isis router $neino error " warning
        return 0
    }
        
    isisRouter    addRouteRange     $netid
    isisServer setRouter $neino
    isisServer write
    
    AddIsisPoolInfo $_chassis $_card $_port $neino  $netid
    
    if {[string match [config_port -ConfigType config] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }
    
    if { [StartRoutingEngine $portList "Isis" ]== -1 } {
        Log "Could not Start Isis for $portList at AddIsisNet procedure" warning
        set retCode $::CIxia::gIxia_ERR    
    }
    
    return $retCode
}

######################################################################
# @@Proc
# Name:    DeleteIsisNet
# Desc:    Delete ISIS route pool
# option:  -NeiNo: ISIS Session id; option; default all neighbors on port 
#          -NetId: ISIS route pool id; optional; default all
# return:
#          1    sucessful
#          0    fail
######################################################################
::itcl::body CIxiaPortETH::DeleteIsisNet  { args }  {
    Log "Delete Isis network ..."
    global PoolOspfindex
    
    set retCode 1

    set neino 0
    set netid 0
    
    if { $neino == 0 && $netid != 0 } {
        Log "route Pool identifier $netid , but not specify Isis Session identifier " warning
        return $::CIxia::gIxia_ERR    
    }
    
    if { $neino == 0 && $netid == 0 } {
        DeleteIsisAllPool $_chassis $_card $_port
    } elseif { $neino != 0 && $netid == 0 } {
        if { [checkSessionCreated $_chassis $_card $_port $neino "Isis" ] == 0 } {
            Log "Isis session $neino has not been created" warning
            return $::CIxia::gIxia_ERR 
        }
        DeleteIsisSessionPool $_chassis $_card $_port $neino
    } elseif { $neino != 0 && $netid != 0 } {
        if { [checkSessionCreated $_chassis $_card $_port $neino "Isis" ] == 0 } {
            Log "Isis session $neino has not been created" warning
            return $::CIxia::gIxia_ERR 
        }
        DeleteIsisSpecificPool $_chassis $_card $_port $neino $netid
    } 
    if {[string match [config_port -ConfigType config] $::CIxia::gIxia_ERR]} {
        return $::CIxia::gIxia_ERR
    }
    
    # Enable the Isis protocol
    if { [StartRoutingEngine $portList "Isis" ]== -1 } {
        Log "Could not Start Isis for $portList at DelIsisRoutePool procedure" warning
        set retCode $::CIxia::gIxia_ERR    
    }
    
    return $retCode
}
