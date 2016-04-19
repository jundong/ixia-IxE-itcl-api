package provide IxTest 1.4

# Copyright (c) Ixia technologies, Inc.
#-------------------INFO--------------------
# Author            :  Eric Yu 
# Abstract          :  This file is to implement the tcl lib for IXIA automation test
# Current version   :  v1.4
# Changes made on version v1.0
#        a. create
# Changes made on version v1.1
#        a. add interface _encap
# Changes made on version v1.2
#        a. add interface _ip
#        d. add interface _gateway
#        e. add interface _pfxlen
#        f. add interface _srcip
#        g. add interface _dstip
# Changes made on version v1.3
#        a. add test result file log
#        b. fix phyMode invalid defect
#        c. add mac address
#        d. add ipv6 interface address 
# Changes made on version v1.4
#        a. add trial for 3sec step
#
#==
#Set the Tcl environment for IxTclHal package
#run if in windows platform
proc GetEnvTcl { product } {
   
   set productKey     "HKEY_LOCAL_MACHINE\\SOFTWARE\\Ixia Communications\\$product"
   set versionKey     [ registry keys $productKey ]
   set latestKey      [ lindex $versionKey end ]
   if { $latestKey == "Multiversion" } {
      set latestKey   [ lindex $versionKey [ mpexpr [ llength $versionKey ] - 2 ] ]
   }
   set installInfo    [ append productKey \\ $latestKey \\ InstallInfo ]            
   return             "[ registry get $installInfo  HOMEDIR ]/TclScripts/bin/ixiawish.tcl"

}

if { $::tcl_platform(platform) == "windows" } {

    # only valid for windows platform
    package require registry
    
    source  [ GetEnvTcl IxOS ]

} else {

    ## Environment variables here are all caps if saved and exported
    ## Upper and lower case if used temporarily to set other
    ## variables
    #IXIA_HOME=<install location>
    ## USER MAY NEED TO CHANGE THESE IF USING OWN TCL LIBRARY
    #TCL_HOME=<install location>
    #TCLver=8.4
    ## USER NORMALLY DOES NOT CHANGE ANY LINES BELOW
    #IxiaLibPath=$IXIA_HOME/lib
    #IxiaBinPath=$IXIA_HOME/bin
    #TCLLibPath=$TCL_HOME/lib
    #TCLBinPath=$TCL_HOME/bin
    #TCL_LIBRARY=$TCLLibPath/tcl$TCLver
    #TK_LIBRARY=$TCLLibPath/tk$TCLver
    #PATH=$IxiaBinPath:.:$TCLBinPath:$PATH
    ##TCLLIBPATH=$IxiaLibPath:$TCLLIBPath;
    ## does not work, not a set of paths, must point to Ixia only
    #TCLLIBPATH=$IxiaLibPath
    #LD_LIBRARY_PATH=$IxiaLibPath:$TCLLibPath:$LD_LIBRARY_PATH
    #IXIA_RESULTS_DIR=/tmp/Ixia/Results
    #IXIA_LOGS_DIR=/tmp/Ixia/Logs
    #IXIA_TCL_DIR=$IxiaLibPath
    #IXIA_SAMPLES=$IxiaLibPath/ixTcl1.0
    #IXIA_VERSION=<build version>
    #export IXIA_HOME TCL_LIBRARY TK_LIBRARY TCLLIBPATH
    #export LD_LIBRARY_PATH IXIA_RESULTS_DIR
    #export IXIA_LOGS_DIR IXIA_TCL_DIR IXIA_SAMPLES
    #export IXIA_TCL_DIR PATH IXIA_VERSION
    #$TCLBinPath/wish ${@+"$@"}

}



package require IxTclHal
#add by celia on version 1.3 start (a)
package require Mpexpr
#add by celia on version 1.3 end (a)
namespace eval IXIA {
    
    namespace export *

    set Debug       0
    set DebugLog    0
    #--
    # Debug puts
    #--
    proc Deputs { value } {
       if { $IXIA::Debug } {
          set timeVal  [ clock format [ clock seconds ] -format %T ]
          set clickVal [ clock clicks ]
          puts "\[TIME:$timeVal\]$value"
        }
        if { $IXIA::DebugLog } {
            IxLog $value
        }
    }
    
    #--
    # Enable debug puts
    #--
    proc IxDebugOn { { log 0 } } {
       set IXIA::Debug 1
    }
    
    #--
    # Disable debug puts
    #--
    proc IxDebugOff {} {
       set IXIA::Debug 0
    }
     
    set Log "log.txt"
    #--
    # Write log
    #--
    proc IxLog { value } {
        set filePath log.txt
        set timeVal  [ clock format [ clock seconds ] -format %T ]
        if { [catch {
            if { [ file exists $IXIA::Log ]} {
                set IOhandle [ open $filePath a ]
            } else {
                set IOhandle [ open $filePath {RDWR CREAT} ]
            } } code] } {
            puts stderr $code
        }
        puts $IOhandle "\[TIME:$timeVal\]$value"
        close $IOhandle
    }
    
    #--
    # Transfer unit like s|m|h
    #--
    proc TimeTrans { value } {
        set ms  *0.001
        set sec *1
        set min *60
        set hour *3600
        if { [ string is integer $value ] } {
            return $value
        }
        if { [ regexp -nocase {^([0-9]+)(sec|min|hour|s|m|h|ms)$} $value match digit unit ] } {
            set unit [string tolower $unit]
            if { $unit == "" } {
                return $value
            } else {
                if { $unit == "s" } { set unit sec }
                if { ($unit == "m") || ($unit == "min") } { set unit min }
                if { ($unit == "h") || ($unit == "hour") } { set unit hour }
                if { $unit == "ms" } { set unit ms }
            }
            return [eval expr $digit$$unit ]
        } else {
            return NAN
        }
    }
    #--
    # Frame loss test
    #   ARGS:
    #   -chassis    : chassis hostname or IP address
    #
    #   RETURN:
    #   0 for success
    #   1 for incompleted test or input error
    #--
    proc TestFrameLoss { args } {
        
        set tag "proc TestFrameLoss [info script]"
        Deputs "----- TAG: $tag -----"

        #default value
        set user                "NO_USER"
        set bi_direction        "0"

        #param collection
        Deputs "Args:$args "
        foreach { key value } $args {
            set key [string tolower $key]
            switch -exact -- $key {
               -chassis {
                   set chassis $value
               }
               -user {
                   set user $value
               }
               -srcport {
                   set src_port_list [list]
                   foreach port $value {
                       if { [ regexp {(\d+)\/(\d+)} $port match c p ] } {
                           lappend src_port_list $match
                       } else {
                           IxLog "Wrong format of $key ... $port"
                           return 1                            
                       }
                   }
               }
               -dstport {
                   set dst_port_list $value
                   foreach port $value {
                       if { [ regexp {(\d+)\/(\d+)} $port match c p ] } {
                           lappend dst_port_list $match
                       } else {
                           IxLog "Wrong format of $key ... $port"
                           return 1                            
                       }
                   }
               }
               -bi {
                   if { ( $value == "1" ) || ( $value == "0" )  } {
                       set bi_direction $value
                   } else {
                       IxLog "Wrong format of $key ... $value"
                       return 1
                   }
               }
               -phy {
                   foreach portPhyVal  $value {
                       if { ![ regexp {\d+\/\d+:(copper|fiber)} $portPhyVal ] } {
                           IxLog "Wrong format of $key ... $portPhyVal"
                           return 1
                       }
                   }
                   set portPhy $value
               }
               -duration {
                   set trans [ TimeTrans $value ]
                   if { [ string is integer $trans ] } {
                       set duration $value
                   } else {
                       IxLog "Wrong format of $key ... $value"
                       return 1                        
                   }
               }
               -speed {
                   #port:speed like 1/2:1000
                   foreach portSpeedVal $value {
                       if { ![ regexp {^\d+\/\d+:(1000|100|10)$} $portSpeedVal ] } {
                           IxLog "Wrong format of $key ... $portSpeedVal"
                           return 1
                       }                        
                   }
                   set portSpeed $value
               }
               -autoneg {
                   #port:speed like 1/2:1000
                   foreach portNeg $value {
                       if { ![ regexp {^\d+\/\d+:(1|0)$} $portNeg ] } {
                           IxLog "Wrong format of $key ... $portNeg"
                           return 1
                       }                        
                   }
                   set autoneg $value
               }
               -framesize {
                   if { [ string is integer $value ] == 0 } {
                       IxLog "Wrong format of $key ... $value"
                       return 1
                   } else {
                       set framesize $value
                   }
               }
               -streamrate {
                   set streamRate $value
               }
               -rateunit {
                  Deputs "rateunit = $value"
                   if { [ regexp {^(fps|bps|percent)$} $value ] } {
                       set rateUnit $value
                       Deputs "rateUnit is $value"
                   } else {
                       IxLog "Wrong format of $key ... $value"
                       return 1
                   }
               }
               -vlan {
                   foreach vlanId $value {
                       if { ![ regexp {^\d+\/\d+:(.*)$} $vlanId ] } {
                           IxLog "Wrong format of $key ... $vlanId"
                           return 1
                       }
                   }
                   set vlan $value
               }                
               -encap {
                    #==modified by Celia on version 1.1 change (a)
                   foreach portEncapVal $value {
                       if { ![ regexp -nocase {^\d+\/\d+:(IPV4|IPV6|IPV4_TCP|IPV6_TCP|IPV4_UDP|IPV6_UDP)$} $portEncapVal ] } {
                           IxLog "Wrong format of $key ... $portEncapVal"
                           return 1
                       }
                   }
                   set encap $value                              
                   #==end modified by Celia on version 1.1 change (a)
               }
               -ip {
                    #==modified by Celia on version 1.2 change (a)
                    foreach ipInfo $value {
                          if { ![ regexp {^\d+/\d+:(\d+\.\d+\.\d+\.\d+)$} $ipInfo total ipAddr ] } {
                              IxLog "Wrong format of $key  ... $ipInfo, must be such as 1/1:192.168.1.1!"
                              return 1
                          }
                          if { ![isIpv4Addr $ipAddr] } {
                               IxLog "Wrong format of $key ip Address... $ipAddr,the range of the address is 0.0.0.0 ~ 255.255.255.255!"          
                               return 1
                            }
                      
                    }
                   set intfIpList $value  
		   #==modified by Celia on version 1.2 change (a)
                }
                -ipv6 {
                    #==add by Celia on version 1.3 to add  interface ipv6 address start (b)
                    foreach ipInfo $value {
                          if { ![ regexp {^\d+/\d+:(.*)\/(.*)$} $ipInfo total ipAddr ipGateway] } {
                              IxLog "Wrong format of $key  ... $ipInfo, must be such as 1/1:192.168.1.1!"
                              return 1
                          }
                          if { ![isIpv6Addr $ipAddr] || ![isIpv6Addr $ipGateway]} {
                               IxLog "Wrong format of $key ip Address... $ipAddr,the range of the address is 0.0.0.0 ~ 255.255.255.255!"          
                               return 1
                            }
                      
                    }                     
                   set intfIpv6List $value  
		   #==add by Celia on version 1.3 to add  interface ipv6 address end (b)
                }
               -gateway {
                    foreach gatewayInfo $value {
                          if { ![ regexp {^\d+/\d+:(\d+\.\d+\.\d+\.\d+)$} $gatewayInfo total ipAddr ] } {
                                IxLog "Wrong format of $key  ... $ipInfo, must be such as 1/1:192.168.1.1!"
                                return 1
                          }
                          if { ![isIpv4Addr $ipAddr] } {
                               IxLog "Wrong format of $key ip Address... $ipAddr,the range of the address is 0.0.0.0 ~ 255.255.255.255!"          
                               return 1
                            }
                   
                    }
                   set gateway $value
                 }
               -pfxlen {
                  foreach pfxInfo $value {
                        if { ![ regexp {^\d+/\d+:(\d+)$} $pfxInfo total pfxLen ] } {
                              IxLog "Wrong format of $key  ... $ipInfo, must be such as 1/1:192.168.1.1!"
                              return 1
                        }
                        if { $pfxLen >32 || $pfxLen < 0 } {
                              IxLog "Wrong format of pfxlen,the range of the it is 0~32!"          
                              return 1
                        }                    
                  }
                  set pfxlen $value                
               }            
               -srcip { 
                  foreach srcipInfo $value {
                        #changed by celia on version 1.3 to set the ipv6 srcaddress start(c)
                        if { ![ regexp {^\d+/\d+:(.*)$} $srcipInfo total ipAddr ] } {
                            IxLog "Wrong format of $key ... $$srcipInfo,must be such as 1/1:192.168.1.1!"
                            return 1
                        }
                        if { ![isIpv4Addr $ipAddr]  && ![isIpv6Addr $ipAddr] } {
                            Deputs "Wrong format of $key ip Address... $ipAddr,it is not ipv4 or ipv6 address!"  
                            IxLog "Wrong format of $key ip Address... $ipAddr,the range of the address is 0.0.0.0 ~ 255.255.255.255!"          
                             return 1
                        }
                        #changed by celia on version 1.3 to set the ipv6 srcaddress end(c)
                  }
                 set srcIpList $value  
               }
               -dstip { 
                  foreach dstipInfo $value {
                        #changed by celia on version 1.3 to set the ipv6 dstaddress start(d)
                        if { ![ regexp {^\d+/\d+:(.*)$} $dstipInfo total ipAddr ] } {
                            IxLog "Wrong format of $key ... $dstipInfo,must be such as 1/1:192.168.1.1!"
                            return 1
                           }
                        if { ![isIpv4Addr $ipAddr]  && ![isIpv6Addr $ipAddr] } {
                            Deputs "Wrong format of $key ip Address... $ipAddr,it is not ipv4 or ipv6 address!" 
                            IxLog "Wrong format of $key ip Address... $ipAddr,it is not ipv4 or ipv6 address!"          
                            return 1
                        }                           
                       #changed by celia on version 1.3 to set the ipv6 dstaddress end(d)
                  }
                 set dstIpList $value
               #==end modified by Celia on version 1.2 change (a)
               }
               -srcmac {
                   #add by celia on version 1.3 to set the mac srcaddress start(e)
                  foreach srcmaci $value {                       
                        if { ![ regexp {^\d+/\d+:(.*)$} $srcmaci total srcmac ] } {
                            IxLog "Wrong format of $srcmaci .. !"
                            return 1
                           }                 
                  }
                 set srcMacList $value
                   #add by celia on version 1.3 to set the mac srcaddress end(e)
               }
               -dstmac {
                  #add by celia on version 1.3 to set the mac dstaddress start(f)
                  foreach dstmaci $value {                            
                           if { ![ regexp {^\d+/\d+:(.*)$} $dstmaci total dstmac ] } {
                               IxLog "Wrong format of $dstmaci ...  !"
                               return 1
                              }                       
                     }
                    set dstMacList $value
                  #add by celia on version 1.3 to set the mac dstaddress end(f)
               }
               -testresultfile {
                    set testresultfile $value
                      
               }
            }
        }        
        #check madatory params
Deputs Step10
        if { [ info exists chassis ] == 0 } {
            IxLog "Madatory parameter missing: -chassis"
            return 1
        }
Deputs Step20
        if { [ info exists duration ] == 0 } {
            IxLog "Madatory parameter missing: -duration"
            return 1
        }
                      
Deputs Step30
        set portPairList [ list ]
        set portList     [ list ]
        if { [ info exists src_port_list ] && [ info exists dst_port_list ] } {
            set portPairList [ concat $portPairList \
                [ genMeshPortList $src_port_list $dst_port_list $bi_direction ] ]
            foreach port $src_port_list {
                if { [ lsearch -exact $portList $port ] == -1 } {
                    lappend portList $port
                }
            }
            foreach port $dst_port_list {
                if { [ lsearch -exact $portList $port ] == -1 } {
                    lappend portList $port
                }
            }
        } else {
            if { [ info exists src_port_list ] } {
                set portPairList [ concat $portPairList \
                    [ genFullMeshPortList $src_port_list ] ]
                foreach port $src_port_list {
                    if { [ lsearch -exact $portList $port ] == -1 } {
                        lappend portList $port
                    }
                }
            }
            if { [ info exists dst_port_list ] } {
                set portPairList [ concat $portPairList \
                    [ genFullMeshPortList $dst_port_list ] ]
                foreach port $dst_port_list {
                    if { [ lsearch -exact $portList $port ] == -1 } {
                        lappend portList $port
                    }
                }
            }
        }
Deputs "port pair: $portPairList"
Deputs "port list: $portList"
Deputs Step40        
        #-- connect to chassis
        set chassis	  [ connect $chassis $user ]
        chassis get $chassis
        set chasId        [ chassis cget -id ]
Deputs "chassis id: $chasId"
        #-- take ownership
        set portCellList   [list]
Deputs Step50
        foreach port $portList {
            set portInfo [ split $port "/" ]
            set c        [ lindex $portInfo 0 ]
            set p        [ lindex $portInfo 1 ]
            lappend portCellList [ list $chasId $c $p ]
        }
Deputs "port cell list: $portCellList"
        if { [ ixTakeOwnership $portCellList ] } {
            IxLog "Fail to take ownership on port: $portCellList"
            return 1
        }
        
        #--set default factory
Deputs Step60
        foreach port $portCellList {
            eval port setFactoryDefaults $port
        }
        #ixWritePortsToHardware portCellList
        #-- config specific phy mode
Deputs Step70
        if { [ info exists portPhy ] } {
            foreach phymode $portPhy {
                if { [ regexp -nocase {(\d+)\/(\d+):(copper|fiber)} $phymode match card port mode ] } {
                    set mode [ string tolower $mode ]
                    Deputs "set phy mode on port:${card}/$port $mode"
                    switch $mode {
                        fiber {
                           set mode 1
                        }
                        copper {
                           set mode 0
                        }
                    }
                    Deputs "mode:$mode chas:$chasId card:$card port:$port"
                    #port get $chasId $card $port
                    port setPhyMode $mode $chasId $card $port
                }
            }
        }
        #-- config auto-negotiation
Deputs Step80
        if { [ info exists autoneg ] } {
         IxLog "-----autonegtiation setting....<$autoneg>" 
            foreach auto1 $autoneg {
                if { [ regexp {^(\d+)\/(\d+):(1|0)$} $auto1 match card port auto ] } {
                    Deputs "set auto-negotiation on port:${card}/$port $auto"
                    IxLog "set auto-negotiation on port:${card}/$port $auto"
                    port get $chasId $card $port
                    port config -autonegotiate $auto
                    port set $chasId $card $port
                }                        
            }
        }
        #-- config specific speed
Deputs Step90
        if { [ info exists portSpeed ] } {
         IxLog "----portSpeed setting....<$portSpeed>"
            foreach speed $portSpeed {
                if { [ regexp {^(\d+)\/(\d+):(1000|100|10)$} $speed match card port speed ] } {
                    Deputs "set speed on port:${card}/$port $speed"
                    IxLog "set speed on port:${card}/$port $speed"
                    port get $chasId $card $port
                    port config -speed $speed
                    port config -advertise${speed}FullDuplex             true
                    port set $chasId $card $port
                }                        
            }
        }
        
         #-- config srcip , dstip and interface ip   
         #==modified by Celia on version 1.2 change (b)
         #create ipSrc and ipDst to be used as source and destination address in stream for ipv4 protocol
         #srcIpList and dstIpList have the priority to be as the source and destination address
         #if some port has no infomation in srcIpList or dstIpList,intfIpList will be searched for ipv4 address.
         
         array set ipSrc   [list]
         array set ipDst   [list]
         array set ipIntf  [list]
         array set ipGatewayIntf  [list]
         array set ipPfxLenIntf   [list]
         #-- put gateway address for the ipv4 address in array ipGatewayIntf
Deputs Step100
         if { [ info exists gateway ] } {
            foreach gatewayi $gateway {
               regexp {^(\d+/\d+):(\d+\.\d+\.\d+\.\d+)$} $gatewayi total intf ipAd      
               set ipGatewayIntf($intf) $ipAd 
            }
         }
         #-- put size of the mask for the address in array ipPfxLenIntf
Deputs Step110
         if { [ info exists pfxlen ] } {
            foreach pfxleni $pfxlen {
               regexp {^(\d+/\d+):(\d+)$} $pfxleni total intf prefix 
               set ipPfxLenIntf($intf) $prefix 
            }
         }
       
        
         
         # put the srcip of the stream in the array ipSrc
Deputs Step120
         if { [ info exists srcIpList ] } {
            foreach srcIpListi $srcIpList {
               #changed by celia on version 1.3 to add ipv6 addresss start(g)
               regexp {^(\d+/\d+):(.*)$} $srcIpListi total intf srcipAd     
               set ipSrc($intf) $srcipAd
               #changed by celia on version 1.3 to add ipv6 addresss end(g)
            }
         }
         #put the dstip of the stream in the array ipDst
Deputs Step130
         if { [ info exists dstIpList ] } {
            foreach dstIpListi $dstIpList {
               #changed by celia on version 1.3 to add ipv6 addresss start(h)
               regexp {^(\d+/\d+):(.*)$} $dstIpListi total intf dstipAd    
               set ipDst($intf) $dstipAd
               #changed by celia on version 1.3 to add ipv6 addresss end(h)
            }
         }
         
         
          #-- config the ipv4 address for the port,the gateway address and the size of mask for the ipv4 address.
Deputs Step140
         if { [ info exists intfIpList ] } { 
            foreach intfIpListi $intfIpList {
               
               regexp {^(\d+)/(\d+):(\d+\.\d+\.\d+\.\d+)$} $intfIpListi total card port ipAd      
               set intf "$card/$port"
               set ipIntf($intf) $ipAd
               set ipSrc($intf)  $ipAd
               set ipDst($intf)  $ipAd
               
              arpServer setDefault 
               arpServer config -retries                            3
               arpServer config -mode                               arpGatewayOnly
               arpServer config -rate                               2083333
               arpServer config -requestRepeatCount                 3
               if {[arpServer set $chasId $card $port]} {
                       IxLog "Error calling arpServer set $chassis $card $port"
                       return 1
               }
               if {[interfaceTable select $chasId $card $port]} {
                     IxLog "Error calling interfaceTable select $chasId $card $port"
                     return 1
               }
                
               interfaceTable setDefault  
               if {[interfaceTable set]} {
                     IxLog "Error calling interfaceTable set"
                     return 1
                }
               
               interfaceTable clearAllInterfaces               
               interfaceEntry clearAllItems addressTypeIpV6
               interfaceEntry clearAllItems addressTypeIpV4
               interfaceEntry setDefault
               
               interfaceIpV4  setDefault
               if { [ info exists ipGatewayIntf($intf) ] } {
                     interfaceIpV4 config -gatewayIpAddress                   $ipGatewayIntf($intf)
               }               
               if { [info exists ipPfxLenIntf($intf) ] } {
                     interfaceIpV4 config -maskWidth                          $ipPfxLenIntf($intf)
               }
               interfaceIpV4 config -ipAddress                          $ipAd
               if {[interfaceEntry addItem addressTypeIpV4]} {
                     IxLog "Error calling interfaceEntry addItem addressTypeIpV4"
                     return 1
               }
               interfaceEntry config -enable                             true
               if {[interfaceTable addInterface interfaceTypeConnected]} {
                     IxLog "Error calling interfaceTable addInterface interfaceTypeConnected"
                     return 1
               } 
            }       
         }
         #==end modified by Celia on version 1.2 change (b)
         
         #==add by Celia on version 1.3 change to set interface ipv6 address start (i)
Deputs Step150
         if { [info exists intfIpv6List]} { 
        
            foreach intfIpListi $intfIpv6List {
               
               regexp {^(\d+)/(\d+):(.*)\/(.*)$} $intfIpListi total card port ipAd ipGateway     
               set intf "$card/$port"
               Deputs "intfIpv6List  : $intf --- $ipAd --$ipGateway"
               puts "intfIpv6List  : $intf --- $ipAd --$ipGateway"
               set ipv6Add($intf)  $ipAd
               set ipv6Gateway($intf)  $ipGateway               
              
               if {[interfaceTable select $chasId $card $port]} {
                     IxLog "Error calling interfaceTable select $chasId $card $port"
                     return 1
               }
                
               interfaceTable setDefault                 
               if {[interfaceTable set]} {
                     IxLog "Error calling interfaceTable set"
                     return 1
                }
               interfaceTable clearAllInterfaces               
               interfaceEntry clearAllItems addressTypeIpV6
               interfaceEntry clearAllItems addressTypeIpV4
               interfaceEntry setDefault
               
               interfaceIpV6 setDefault 
               interfaceIpV6 config -maskWidth                          64
               interfaceIpV6 config -ipAddress                          $ipAd
               if {[interfaceEntry addItem addressTypeIpV6]} {
                     IxLog "Error calling interfaceEntry addItem addressTypeIpV6"
                     return 1
                  } 
               interfaceEntry config -enable                            true                      
               interfaceEntry config -ipV6Gateway                       $ipGateway
               if {[interfaceTable addInterface interfaceTypeConnected]} {
                     IxLog "Error calling interfaceTable addInterface interfaceTypeConnected"
                     return 1
                  }
             }   
         }
         #==add by Celia on version 1.3 change to set interface ipv6 address end(i)
          
         #add by celia on version 1.3 to set the mac address start(j)
Deputs Step160
         if { [info exists srcMacList]} {
          foreach srcMacListi $srcMacList {
               
               regexp {^(\d+)/(\d+):(.*)$} $srcMacListi total card port macAd
               set intf "$card/$port"
               
               set macAddress [ getMacAddr $macAd ]
               Deputs "macAddress = $macAddress"
               if {  $macAddress == 0  } {
                 Deputs "there is errror in macAddress!"
                 return 1
               }
               Deputs " macAddress =  $card/$port $macAddress"
               set srcMacAdd($intf)  $macAddress
               Deputs " srcMacAdd over"
            }
         }
        
Deputs Step170
        if { [info exists dstMacList]} {
          foreach dstMacListi $dstMacList {
               
               regexp {^(\d+)/(\d+):(.*)$} $dstMacListi total card port macAd
               set intf "$card/$port"               
               set macAddress [ getMacAddr $macAd ]
               if {  $macAddress == 0 } {
                 Deputs "there is errror in macAddress!"
                 return 1
               }
               Deputs " macAddress =  $card/$port $macAddress"
               set dstMacAdd($intf)  $macAddress
               Deputs " dstMacAdd over"
            }
         }
         #add by celia on version 1.3 to set the mac address end(j)
       
        #Deputs " celia  $dstMacAdd($intf) "
        #-- configure stream as well as tx/rx mode
        set streamId    1
        array set stream [list]
        set rxPortList [list]
        set txPortList [list]
        foreach pair $portPairList {
            set tx  [ lindex $pair 0 ]
            set rx  [ lindex $pair 1 ]
Deputs "tx:$tx"
Deputs "rx:$rx"        
            set txPort  [ concat $chasId [ split $tx "/" ] ]
            set rxPort  [ concat $chasId [ split $rx "/" ] ]
Deputs "txPort: $txPort"
Deputs "rxPort: $rxPort"
            lappend rxPortList $rxPort
            lappend txPortList $txPort
Deputs "rxPortList: $rxPortList"
Deputs "txPortList: $txPortList"
            set stream($streamId,txPort)  $txPort
            set stream($streamId,rxPort)  $rxPort

            set txMac   [ eval genPortMac $txPort ]
            set rxMac   [ eval genPortMac $rxPort ]
            
            #add by celia on version 1.3 to set the mac address start(k)
            if { [ info exists  srcMacAdd($tx) ] } {
                Deputs "exists  srcMacAdd($txPort) "
                set txMac $srcMacAdd($tx)
            }
            
            if { [ info exists  dstMacAdd($tx) ] } {
                Deputs "exists  dstMacAdd($txPort)"
                set rxMac $dstMacAdd($tx)
            }
            #add by celia on version 1.3 to set the mac address end(k)
             
            Deputs "txMac: $txMac"
            Deputs "rxMac: $rxMac" 

            set stream($streamId,txMac)  $txMac
            set stream($streamId,rxMac)  $rxMac

            if { [ info exists stream($tx,streamId) ] } {
                incr stream($tx,streamId)
Deputs "stream id: $stream($tx,streamId)"
            } else {
                set stream($tx,streamId) 1
            }
            set stream($streamId,pgId) $stream($tx,streamId)
            
            stream setDefault
            stream config -name                               "stream${tx}-${rx}"
            stream config -enable                             true
            stream config -dma                                contPacket
            stream config -sa                                 $txMac
            stream config -da                                 $rxMac
            stream config -frameSizeType                      sizeFixed
	    

            if { [ info exists framesize ] } {
                stream config -framesize                          $framesize                
            }
            set rateOption "percentPacketRate"
            #-- config stream rate
            if { [ info exists rateUnit ] } {
               #changed by celia on version 1.3 to change $value to $rateUnit as following.(l)
                if { [ regexp {(fps|bps|percent)} $rateUnit match unit ] } {
                    Deputs "unit = $unit ,value = $value "
                    switch $unit {
                        "percent" {
                            stream config -rateMode 1
                            set rateOption "percentPacketRate"
                            Deputs " set rateOption percentPacketRate"
                        }
                        "fps" {
                            stream config -rateMode 2
                            set rateOption "fpsRate"
                            Deputs "set rateOption fpsRate"
                        }
                        "bps" {
                            stream config -rateMode 3
                            set rateOption "bpsRate"
                            Deputs "set rateOption bpsRate"
                        }
                    }
                }
            } else {
                stream config -rateMode 1
            }
            if { [ info exists streamRate ] } {
                stream config -$rateOption $streamRate
            } 
            #==modified by Celia on version 1.1 change (b)

            protocol setDefault            
             #-- config encap 
            if { [info exists encap] } {
            
                foreach {portEncapVal} $encap {
                
                 if { [ regexp $tx $portEncapVal ] == 0 } {
                        continue
                  } 
                 regexp -nocase {^(\d+)\/(\d+):(IPV4|IPV6|IPV4_TCP|IPV6_TCP|IPV4_UDP|IPV6_UDP)$} $portEncapVal total card port ipProtocol
                     set ipProtocol [string toupper $ipProtocol]
                     switch $ipProtocol {
                                 IPV4 {                                  
                                        protocol config -name                               ipV4
                                        protocol config -ethernetType                       ethernetII
                                        ip setDefault
                                        ip config -ipProtocol                               ipV4ProtocolReserved255
                                        
                                        #==modified by Celia on version 1.2 change (c)
                                        if { [info exists ipSrc($tx)] } {
                                            ip config -sourceIpAddr                         $ipSrc($tx)
                                        }
                                        if { [info exists ipDst($tx)] } {
                                            ip config -destIpAddr                           $ipDst($tx)
                                        }
                                        #==end modified by Celia on version 1.2 change (c)
                                        if {[ip set $chasId $card $port]} { 
                                             IxLog "Error calling ip set $chasId $card $port (IPV4)"
                                             #return 1
                                         }
                                         
                                        break
                                  }                  
                                 IPV4_TCP {
                                        protocol config -name                               ipV4
                                        protocol config -ethernetType                       ethernetII
                                        ip setDefault
                                        ip config -ipProtocol                               ipV4ProtocolTcp
                                        #==modified by Celia on version 1.2 change (d)
                                        if { [info exists ipSrc($tx)] } {
                                            ip config -sourceIpAddr                         $ipSrc($tx)
                                        }
                                        if { [info exists ipDst($tx)] } {
                                            ip config -destIpAddr                           $ipDst($tx)
                                        }
                                        #==end modified by Celia on version 1.2 change (d)
                                        if {[ip set $chasId $card $port]} { 
                                             IxLog "Error calling ip set $chasId $card $port in (IPV4_TCP )"
                                             #return 1
                                         }
                                        tcp setDefault                                        
                                        if {[tcp set $chasId $card $port]} {
                                              IxLog  "Error calling tcp set $chasId $card $port in IPV4_TCP"
                                              #return 1
                                           }
                                        break
                                 }                 
                                 IPV4_UDP {
                                        protocol config -name                               ipV4
                                        protocol config -ethernetType                       ethernetII
                                        ip setDefault
                                        ip config -precedence                               routine
                                        ip config -ipProtocol                               ipV4ProtocolUdp
                                        #==modified by Celia on version 1.2 change (e)
                                        if { [info exists ipSrc($tx)] } {
                                            ip config -sourceIpAddr                         $ipSrc($tx)
                                        }
                                        if { [info exists ipDst($tx)] } {
                                            ip config -destIpAddr                           $ipDst($tx)
                                        }
                                        #==end modified by Celia on version 1.2 change (e)
                                        if {[ip set $chasId $card $port]} { 
                                             IxLog "Error calling ip set $chasId $card $port in IPV4_UDP"
                                             #return 1
                                         }
                
                                        udp setDefault
                                       if {[udp set $chasId $card $port]} {
                                              IxLog  "Error calling udp set $chasId $card $port in IPV4_UDP"
                                              #return 1
                                           }
                                        break
                                 }
                                 IPV6  {
                                    Deputs "now config ipv6 address!"
                                        protocol config -name                               ipV6
                                        protocol config -ethernetType                       ethernetII
                                        ipV6 setDefault 
                                        ipV6 config -nextHeader                            ipV6NoNextHeader
                                       #add by celia  on version 1.3 start(m)
                                        
                                        if { [info exists ipv6Add($tx)] } {
                                           Deputs "exists ipv6Add($tx)  "
                                            ipV6 config -sourceAddr                          $ipv6Add($tx)
                                        } elseif { [info exists ipSrc($tx)] } {
                                          
                                            ipV6 config -sourceAddr                          $ipSrc($tx)
                                        }
                                        
                                        Deputs "exists ipDst($tx) " 
                                        if { [info exists ipDst($tx)] } {
                                           Deputs "config ipDst address!"
                                            ipV6 config -destAddr                           $ipDst($tx)
                                        }
                                        #add by celia  on version 1.3 end(m)
                                        if {[ipV6 set $chasId $card $port]} {
                                              IxLog  "Error calling IPV6 set $chasId $card $port "
                                              #return 1
                                           }
                                         
                                        break                  
                                 }
                                 IPV6_TCP {
                                        protocol config -name                               ipV6
                                        protocol config -ethernetType                       ethernetII
                                        ipV6 setDefault 
                                        ipV6 config -nextHeader                             ipV4ProtocolTcp
                                        ipV6 clearAllExtensionHeaders
                                        ipV6 addExtensionHeader ipV4ProtocolTcp
                                        #add by celia  on version 1.3 start(n)
                                        
                                        if { [info exists ipv6Add($tx)] } {
                                            ipV6 config -sourceAddr                          $ipv6Add($tx)
                                        } elseif { [info exists ipSrc($tx)] } {
                                            ipV6 config -sourceAddr                          $ipSrc($tx)
                                        }
                                        
                                        if { [info exists ipDst($tx)] } {
                                            ipV6 config -destAddr                           $ipDst($tx)
                                        }
                                        #add by celia  on version 1.3 end(n)
                                         if {[ipV6 set $chasId $card $port]} {
                                              IxLog  "Error calling IPV6 set $chasId $card $port in IPV6_TCP"
                                              #return 1
                                           }
                                        tcp setDefault
                                        if {[tcp set $chasId $card $port]} {
                                              IxLog  "Error calling tcp set $chasId $card $port in IPV6_TCP"
                                              #return 1
                                           }
                                        break
                                 }
                                 IPV6_UDP {
                                        protocol config -name                               ipV6
                                        protocol config -ethernetType                       ethernetII
                                        ipV6 setDefault
                                        ipV6 config -nextHeader                             ipV4ProtocolUdp
                                        ipV6 clearAllExtensionHeaders
                                        ipV6 addExtensionHeader ipV4ProtocolUdp
                                       #add by celia  on version 1.3 start(o)
                                       if { [info exists ipv6Add($tx)] } {
                                            ipV6 config -sourceAddr                          $ipv6Add($tx)
                                        } elseif { [info exists ipSrc($tx)] } {
                                            ipV6 config -sourceAddr                          $ipSrc($tx)
                                        }
                                        if { [info exists ipDst($tx)] } {
                                            ipV6 config -destAddr                           $ipDst($tx)
                                        }
                                        #add by celia  on version 1.3 end(o)
                                        if {[ipV6 set $chasId $card $port]} {
                                              IxLog  "Error calling IPV6 set $chasId $card $port in IPV6_UDP"
                                              #return 1
                                           }
                                        udp setDefault 
                                        if {[udp set $chasId $card $port]} {
                                              IxLog  "Error calling udp set $chasId $card $port in IPV6_UDP"
                                              #return 1
                                           }
                                        break                    
                                 }                 
                     }         
                }               
            }            
            
         
            #==end modified by Celia on version 1.1 change (b)
            #-- config vlan           
            
            if { [ info exists vlan ] } {
                foreach vlanId  $vlan {
                    if { [ regexp $tx $vlanId ] == 0 } {
                        continue
                    }
                    regexp {(\d+)\/(\d+):(.*)} $vlanId match card port id
                     Deputs "vlan configuration:$vlanId"
                     Deputs "config vlan on ${card}/$port : $id"
                    if { [ llength $id ] > 1 } {
                        protocol config -enable802dot1qTag                  vlanStacked
                        stackedVlan setDefault 
                        set vlanPosition 1
                        vlan setDefault 
                        vlan config -vlanID      [ lindex $id 0 ]
                        Deputs "first stack: [ lindex $id 0 ]"
                        stackedVlan setVlan $vlanPosition
                        incr vlanPosition
                        vlan setDefault 
                        vlan config -vlanID      [ lindex $id 1 ]
                        Deputs "first stack: [ lindex $id 1 ]"
                        stackedVlan setVlan $vlanPosition
                        stackedVlan set $chasId $card $port
                    } else {
                        protocol config -enable802dot1qTag                  vlanSingle
                        vlan setDefault 
                        vlan config -vlanID                             $id
                        vlan set $chasId $card $port
                    }
                    break
                }
            }      
           
            
            if {[ eval stream set $txPort $stream($tx,streamId) ]} {
                IxLog "Error stream set $txPort $stream($tx,streamId)"
                #return 1
            }
            #==modified by Celia on version 1.1 change (c)
            #if not add this,the signature data will overlap with udf5,there will be warning
            udf setDefault
            packetGroup setDefault
            packetGroup config -groupId $stream($tx,streamId)
            
            if {[eval packetGroup setTx $txPort $stream($tx,streamId) ]} {
                  IxLog "Error calling dataIntegrity setTx $txPort"
                   #return 1
               } 
            
            dataIntegrity setDefault
            if {[eval dataIntegrity setTx $txPort $stream($tx,streamId) ]} {
                  IxLog "Error calling dataIntegrity setTx $txPort"
                   #return 1
               } 
            #==end modified by Celia on version 1.1 change (c)
            
            autoDetectInstrumentation setDefault 
            autoDetectInstrumentation config -enableTxAutomaticInstrumentation   true
            if {[ eval autoDetectInstrumentation setTx $txPort $stream($tx,streamId) ]} {
                IxLog "Error calling autoDetectInstrumentation on $txPort"
               # return 1
            }
            
            incr streamId
        } 
        ixSetAutoDetectInstrumentationMode rxPortList
        
        ixWriteConfigToHardware portCellList -noProtocolServer
        #-- commit port configuration
        ixWritePortsToHardware portCellList
           
        if { [ ixCheckLinkState portCellList ] } {
            IxLog "Link on one or more ports is down"
            return 1                            
        }       

         #-- for trial
Deputs Step180
        ixStartTransmit txPortList
        after 3000
	ixStopTransmit txPortList
        after 1000
        #--clear stats number on both port
        ixClearStats portCellList
        #--start packetgroups-based stats
        ixStartPacketGroups portCellList
        #--start transmitting
	#modified by celia on version 1.3 start(p)
        #ixStartTransmit portCellList
        Deputs "txPortList = $txPortList"
        ixStartTransmit txPortList
        after [ mpexpr $duration * 1000 ]
	ixStopTransmit txPortList
	#modified by celia on version 1.3 end(p)
        #--for the sake of any latency for packet loss
        after 1000
        ixStopPacketGroups portCellList
        
         ##--create a result file
         if { [ info exists testresultfile ] } {
            set filePath $testresultfile  
         } else {
            set filePath "result.txt"
         }
         if { [catch {
            if { [ file exists filePath ]} {
                set IOhandle [ open $filePath w ]
            } else {
                set IOhandle [ open $filePath {RDWR CREAT} ]
            }
         } code] } {
            IxLog "Fail to write result file: $code"
            return 1
        }
        
        #--stream-based statistics
        array set result [list]
        set pass        1
        set totalLoss   0
        for {set i 1} {$i < $streamId} {incr i} {
            eval packetGroupStats get $stream($i,rxPort) $stream($i,pgId) $stream($i,pgId)
            set rx [ packetGroupStats cget -totalFrames ]
Deputs "stream $i rx: $rx"
	    eval streamTransmitStats get $stream($i,txPort) $stream($i,pgId) $stream($i,pgId)
            set tx [streamTransmitStats cget -framesSent]
Deputs "stream $i tx: $tx"
            set streamBasedFramesLoss [ expr $tx - $rx ]
           
            set result($i,txFrame)   $tx
            set result($i,rxFrame)   $rx
            set result($i,txPort)    $stream($i,txPort)
            set result($i,rxPort)    $stream($i,rxPort)
            set result($i,loss)      $streamBasedFramesLoss
            incr totalLoss           $streamBasedFramesLoss
            if { $streamBasedFramesLoss } {
                set pass 0 
            }
            
        }
        
        if { $pass } {
            puts $IOhandle "return=pass"
        } else {
            puts $IOhandle "return=fail"
        }
        
        set nvFormat "    %-28s : %s"
        puts $IOhandle "==============="
        puts $IOhandle "Test Parameters"
        puts $IOhandle "==============="
        foreach { key value } $args {
            puts $IOhandle [format $nvFormat "$key" "$value"]
        }
        puts $IOhandle "==============="
        puts $IOhandle "Test Result Details"
        puts $IOhandle "==============="
        for {set i 1} {$i < $streamId} {incr i} {
            puts $IOhandle "Stream $i Result:"
            puts $IOhandle "-----------------"
            puts $IOhandle [format $nvFormat "TxPort" "$result($i,txPort)"]
            puts $IOhandle [format $nvFormat "RxPort" "$result($i,rxPort)"]
            puts $IOhandle [format $nvFormat "TxFrame" "$result($i,txFrame)"]
            puts $IOhandle [format $nvFormat "RxFrame" "$result($i,rxFrame)"]
            puts $IOhandle [format $nvFormat "Frame Loss" "$result($i,loss)"]
        }
        puts $IOhandle "==============="
        puts $IOhandle "   Total Loss  "
        puts $IOhandle "==============="
        puts $IOhandle [format $nvFormat "Total Frame Loss" "$totalLoss"]
        puts $IOhandle "Runtime:[ clock format [ clock seconds ] -format "%D %T" ]"
        close $IOhandle
        
	ixClearOwnership $portCellList
        return 0
    }
    
    proc genPortMac { chas card port } {
        set chasHex [ format %x $chas ]
        if { [ string length $chasHex ] == 1 } {
            set chasHex "0$chasHex"
        }
        set cardHex [ format %x $card ]
        if { [ string length $cardHex ] == 1 } {
            set cardHex "0$cardHex"
        }
        set portHex [ format %x $port ]
        if { [ string length $portHex ] == 1 } {
            set portHex "0$portHex"
        }
        return [ concat { 00 00 00 } $chasHex $cardHex $portHex ]
    }
    proc genMeshPortList { src_list dst_list bi } {
        
        set pairList [list]
        
        foreach src $src_list {
            foreach dst $dst_list {
                
                if { $src == $dst } {
                    continue
                }
                if { [ lsearch -exact $pairList [ list $src $dst ] ] == -1 } {
                    lappend pairList [ list $src $dst ]
                    if { $bi } {
                        lappend pairList [ list $dst $src ]
                    }
                }
            }
        }
        
        return $pairList
    }
    
    proc genFullMeshPortList { port_list } {
        
        set pairList [list]
        
        foreach src $port_list {
            foreach dst $port_list {
                
                if { $src == $dst } {
                    continue
                }
                
                lappend pairList [ list $src $dst ]
            }
        }
    }
    
    proc connect { chassis { user NO_USER } } {
        #--connect to tcl server, only necessary in Linux/Unix platform
        if { $::tcl_platform(platform) != "windows" } {

            ixConnectToTclServer $chassis
        }
        #--connect to chassis
        ixConnectToChassis   $chassis
        chassis get $chassis
        set chasId	  [chassis cget -id]
        
        if { $user != "NO_USER" } {
            ixLogin $user
        }
        
        return $chasId
    }
    
    #Proc Name : isIpv4Addr
    #Function  : check the format of ipv4 address is correct or not
    #Parameters:
    #         - ipAddr
    #             ipv4 address ,eg:"255.0.0.45"
    #Usage     : set ret [ipIpv4Addr "255.0.0.45"]
    #Return    : 0 or 1 ;return 1 if the format is correct,or will return 0
    #Author    :celia chen 
    #Modification version: v1.2
    proc isIpv4Addr { ipAddr } {       
      if { [regexp {^(\d+)\.(\d+)\.(\d+)\.(\d+)$} $ipAddr total ip_1 ip_2 ip_3 ip_4 ] } {    
          if { $ip_1 < 0 || $ip_1 > 255 || $ip_2 < 0 || $ip_2 > 255 ||$ip_3 < 0 || $ip_3 > 255 || $ip_4 < 0 || $ip_4 > 255 } {
                  IxLog "is not ipv4Address : $ipAddr !"
                  return 0
           }
      } else {
         IxLog "is not ipv4Address : $ipAddr !"
         return 0
      }
      return 1
    }
    #Proc Name : isIpv6Addr
    #Function  : check the format of ipv6 address is correct or not
    #Parameters:
    #         - ipAddr
    #             ipv6 address ,eg:"3555:5555:6666:6666:7777:7777:8888:8888" / "FE80:0:0:0:200:FF:FE00:300"
    #Usage     : set ret [ipIpv6Addr "3555:5555:6666:6666:7777:7777:8888:8888" ]
    #Return    : 0 or 1 ;return 1 if the format is correct,or will return 0
    #Author    :celia chen 
    #Modification version: v1.3
    proc isIpv6Addr { ipAddr } {       
      if { [regexp {^([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)$} $ipAddr total ] || [regexp {^([0-9a-fA-F]+)\:\:([0-9a-fA-F]+)$} $ipAddr total ] } {    
            Deputs "it is ipv6 address ! $ipAddr"
            return 1 
      } else {
         IxLog "is not ipv6Address : $ipAddr !"
         return 0
      }
    }
    #Proc Name : getMacAddr
    #Function  : check the format of mac address is correct or not
    #Parameters:
    #         - macAddr
    #             mac address ,eg:"00.00.AB.BA.DE.CA"  
    #Usage     : set ret [ipIpv6Addr "00.00.AB.BA.DE.CA" ]
    #Return    : macAddress [list 00 00 AB BA DE CA] ;return 0 if failed
    #Author    :celia chen 
    #Modification version: v1.3
    proc getMacAddr { macAddr } {       
      if { [regexp {^([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)\:([0-9a-fA-F]+)$} $macAddr total mac1 mac2 mac3 mac4 mac5 mac6 ] } {    
            set retMac "$mac1 $mac2 $mac3 $mac4 $mac5 $mac6"
            Deputs "it is mac address ! $macAddr ,$retMac "
            return $retMac 
      } else {
         IxLog "is not mac address ! $macAddr!"
         return 0
      }
    }
}
