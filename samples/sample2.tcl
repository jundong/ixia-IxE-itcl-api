package require registry

########################################################################
# Procedure: generateStreamsFromInterfaces
#
# This command creates streams from interfaces.
# 
# Note that when the streams are created, we assume either the ip
# addresses are configured or learned/discovered from DHCP
# This script assumes that  the DHCP sessions are already up & waiting to be retrieved.  
# This script is only meant to be run from IxExplorer in this fashion.
#
#  
########################################################################

proc generateStreamsFromInterfaces { portList } \
{
    set retCode $::TCL_OK
    set numBitsToShift		13	;# Number of bits to be shifted to setup the vlanId and priority values (4 bits priority 12 bits Id)
                                                                            
    # Building the ipV4/ipV6 address/vlan information lists
    foreach port $portList {
        scan $port "%d %d %d" chassId cardId portId

        set ipV6AddrList		[list]
        set ipV6AddrVlanList	[list]
        set ipV4AddrList		[list]
        set ipV4AddrVlanList	[list]

        if {[port isValidFeature $chassId $cardId $portId portFeatureTableUdf]} {
            if {![interfaceTable select $chassId $cardId $portId]} {
                if {[interfaceTable requestDiscoveredTable]} {
                        errorMsg "Error interfaceTable requestDiscoveredTable on $chassId $cardId $portId."
                }

                # We need to wait at least one second in order to have the table received flag set in IxTclHal
                # This script assumes that the DHCP sessions are already up & waiting to be retrieved.  
                # This script is only meant to be run from IxExplorer in this fashion.
                after 1000

                if {![interfaceTable getFirstInterface ]} {
                    
                    set	interfaceDescription	[interfaceEntry cget -description]
                    set macAddress				[interfaceEntry cget -macAddress]
                    set vlanId					[expr  ([interfaceEntry cget -vlanPriority] << $numBitsToShift ) | [interfaceEntry cget -vlanId]] 

                    if {![interfaceEntry getFirstItem $::addressTypeIpV6]} {

                        set ipV6Address  [interfaceIpV6 cget -ipAddress]

                        if {[interfaceEntry cget -enableVlan]} {
                                lappend  ipV6AddrVlanList [list $macAddress $ipV6Address $vlanId ]

                        } else {
                                lappend  ipV6AddrList [list $macAddress $ipV6Address]
                        }

                        while {![interfaceEntry getNextItem  $::addressTypeIpV6]} {					      

                            if {[interfaceEntry cget -enableVlan]} {
                                    lappend  ipV6AddrVlanList [list $macAddress [interfaceIpV6 cget -ipAddress] $vlanId ]
                            } else {
                                    lappend  ipV6AddrList [list $macAddress [interfaceIpV6 cget -ipAddress]]
                            }
                        }
                    } elseif { [interfaceEntry cget -enableDhcpV6] } {

                        set ipV6AddressList [getDhcpV6DiscoveredAddrList $interfaceDescription]
                
                        foreach ipV6Address $ipV6AddressList {

                                if {[interfaceEntry cget -enableVlan]} {
                                        lappend  ipV6AddrVlanList [list $macAddress $ipV6Address $vlanId ]

                                } else {
                                        lappend  ipV6AddrList [list $macAddress $ipV6Address]
                                }
                        }							
                    } 
                       
                    if {![interfaceEntry getFirstItem $::addressTypeIpV4]} {

                        set ipV4Address  [interfaceIpV4 cget -ipAddress]

                        if {[interfaceEntry cget -enableVlan]} {
                                lappend  ipV4AddrVlanList [list $macAddress $ipV4Address $vlanId ]

                        } else {
                                lappend  ipV4AddrList [list $macAddress $ipV4Address]
                        }

                        while {![interfaceEntry getNextItem  $::addressTypeIpV4]} {
                                if {[interfaceEntry cget -enableVlan]} {
                                        lappend  ipV4AddrVlanList [list $macAddress $ipV4Address $vlanId ]
                                } else {
                                        lappend  ipV4AddrList [list $macAddress $ipV4Address]
                                }
                        }
                    } elseif { [interfaceEntry cget -enableDhcp] } {
                
                        dhcpV4DiscoveredInfo setDefault
                        if {[interfaceTable getDhcpV4DiscoveredInfo  $interfaceDescription]} {
                                errorMsg "Error getting DhcpV4 Discovered table for $interfaceDescription on $chassId $cardId $portId."
                        }

                        set ipV4Address  [dhcpV4DiscoveredInfo cget -ipAddress]

                        if {[interfaceEntry cget -enableVlan]} {
                                lappend  ipV4AddrVlanList [list $macAddress $ipV4Address $vlanId ]

                        } else {
                                lappend  ipV4AddrList [list $macAddress $ipV4Address]
                        }						
                    }

                    while {![interfaceTable getNextInterface]} {

                        set	interfaceDescription	[interfaceEntry cget -description] 
                        set macAddress				[interfaceEntry cget -macAddress]
                        set vlanId					[expr  ([interfaceEntry cget -vlanPriority] << $numBitsToShift ) | [interfaceEntry cget -vlanId]] 

                        if {![interfaceEntry getFirstItem $::addressTypeIpV6]} {

                                set ipV6Address  [interfaceIpV6 cget -ipAddress]

                                if {[interfaceEntry cget -enableVlan]} {
                                        lappend  ipV6AddrVlanList [list $macAddress $ipV6Address $vlanId ]

                                } else {
                                        lappend  ipV6AddrList [list $macAddress $ipV6Address]
                                }

                                while {![interfaceEntry getNextItem  $::addressTypeIpV6]} {					      
                                        if {[interfaceEntry cget -enableVlan]} {
                                                lappend  ipV6AddrVlanList [list $macAddress $ipV6Address $vlanId ]
                                        } else {
                                                lappend  ipV6AddrList [list $macAddress $ipV6Address]
                                        }
                                }
                            } elseif { [interfaceEntry cget -enableDhcpV6] } {
                    
                                    set ipV6AddressList [getDhcpV6DiscoveredAddrList $interfaceDescription]
         
                                    foreach ipV6Address $ipV6AddressList {

                                            if {[interfaceEntry cget -enableVlan]} {
                                                    lappend  ipV6AddrVlanList [list $macAddress $ipV6Address $vlanId ]

                                            } else {
                                                    lappend  ipV6AddrList [list $macAddress $ipV6Address]
                                            }
                                    }   							
                            } 

                            if {![interfaceEntry getFirstItem $::addressTypeIpV4]} {

                                    set ipV4Address  [interfaceIpV4 cget -ipAddress]

                                    if {[interfaceEntry cget -enableVlan]} {
                                            lappend  ipV4AddrVlanList [list $macAddress $ipV4Address $vlanId ]

                                    } else {
                                            lappend  ipV4AddrList [list $macAddress $ipV4Address]
                                    }
                                    while {![interfaceEntry getNextItem  $::addressTypeIpV4]} {
                                            if {[interfaceEntry cget -enableVlan]} {
                                                    lappend  ipV4AddrVlanList [list $macAddress $ipV4Address $vlanId ]
                                            } else {
                                                    lappend  ipV4AddrList [list $macAddress $ipV4Address]
                                            }									  
                                    }

                            } elseif { [interfaceEntry cget -enableDhcp] } {
                    
                                dhcpV4DiscoveredInfo setDefault
                                if {[interfaceTable getDhcpV4DiscoveredInfo  $interfaceDescription]} {
                                        errorMsg "Error getting DhcpV4 Discovered table for $interfaceDescription on $chassId $cardId $portId."
                                }

                                set ipV4Address  [dhcpV4DiscoveredInfo cget -ipAddress]

                                if {[interfaceEntry cget -enableVlan]} {
                                        lappend  ipV4AddrVlanList [list $macAddress $ipV4Address $vlanId ]

                                } else {
                                        lappend  ipV4AddrList [list $macAddress $ipV4Address]
                                }
                                
                            }
                    }
                }
            }

            # Stop here, if there is no configured interface
            set numAddresses  [expr [llength $ipV4AddrList] + [llength $ipV6AddrList] + [llength $ipV6AddrVlanList] + [llength $ipV4AddrVlanList] ]
            if { $numAddresses == 0 } {
                    errorMsg "Error, there is no configured interface for port $chassId $cardId $portId."
                    set retCode $::TCL_ERROR
                    continue
            }

            # Disable the existing streams, before building the new ones
            set lastStreamId ""
            disableStreams $chassId $cardId $portId lastStreamId 

            set addrListNames [list ipV4AddrList ipV4AddrVlanList ipV6AddrList ipV6AddrVlanList]

            foreach addrList $addrListNames {

                    if { [llength [set $addrList]] == 0 } {
                            continue
                    }

                    set numAddresses  [llength [set $addrList]]
                    set protocolName	[string range $addrList 0 3]	
                    set vlanFlag $::false
                    if {[string first "Vlan" $addrList] >= 0} {
                            set vlanFlag $::true
                    }

                    # Configure the corresponding protocol
                    protocol setDefault        
                    protocol config -name				$protocolName
                    protocol config -appName			0
                    protocol config -ethernetType		ethernetII
                    protocol config -enable802dot1qTag	$vlanFlag

                    if { $protocolName == "ipV4" } {

                            set srcIpAddressOffset	26
                            set formatType			formatTypeIPv4
                            set size				4 

                            ip setDefault
                            if {[ip set $chassId $cardId $portId]} {
                                    errorMsg "Error, setting ip on $chassId $cardId $portId."
                                    set retCode $::TCL_ERROR
                                    break
                            }

                    } elseif { $protocolName == "ipV6" } {

                            set srcIpAddressOffset	22
                            set formatType			formatTypeIPv6 
                            set size				16 

                            ipV6 setDefault
                            if {[ipV6 addExtensionHeader udp]} {
                                    errorMsg "Error, ipV6 addExtensionHeader on $chassId $cardId $portId."
                                    set retCode $::TCL_ERROR
                                    break
                            }
                            if {[ipV6 set $chassId $cardId $portId]} {
                                    errorMsg "Error, setting ipV6 on $chassId $cardId $portId."
                                    set retCode $::TCL_ERROR
                                    break
                            }
                    } else {
                            errorMsg "Error, invalid protocol name, internal error, test aborted."
                            set retCode $::TCL_ERROR
                            break
                    }

                    # Setup the table udf column for the MAC address
                    tableUdf setDefault        
                    tableUdf clearColumns      
                    tableUdf config            -enable			true
                    tableUdfColumn setDefault        
                    tableUdfColumn config      -formatType		formatTypeMAC
                    tableUdfColumn config      -offset			6
                    tableUdfColumn config      -size			6
                    tableUdfColumn config      -name			"MAC"
                    tableUdfColumn config      -customFormat	""
                    
                    if {[tableUdf addColumn] } {
                            errorMsg "Error adding column to table udf for formatTypeMAC"
                            set retCode $::TCL_ERROR
                            break
                    }
                                     
                    if { $vlanFlag } {
                            set srcIpAddressOffset [expr $srcIpAddressOffset + 4]
                    }


                    # Setup the table udf column for the corresponding protocol type
                    tableUdfColumn setDefault        
                    tableUdfColumn config -formatType            $formatType
                    tableUdfColumn config -offset                $srcIpAddressOffset
                    tableUdfColumn config -size                  $size
                    tableUdfColumn config -name                  $protocolName
                    tableUdfColumn config -customFormat          ""
                    if {[tableUdf  addColumn] } {
                            errorMsg "Error adding column to table udf for $srcIpAddressOffset"
                            set retCode $::TCL_ERROR
                            break
                    }
                    

                    # Setup the table udf column for the vlanId and vlanPriority
                    if { $vlanFlag } {
                            tableUdfColumn setDefault        
                            tableUdfColumn config -formatType            formatTypeDecimal
                            tableUdfColumn config -offset                14
                            tableUdfColumn config -size                  2
                            tableUdfColumn config -name                  "VlanId"
                            tableUdfColumn config -customFormat          ""
                            if {[tableUdf  addColumn] } {
                                    errorMsg "Error adding column to table udf for $srcIpAddressOffset"
                                    set retCode $::TCL_ERROR
                                    break
                            }
                    }			

                    # Adding the rows for each column configured above
                    foreach rowValueList [set $addrList] {

                            if {[tableUdf addRow $rowValueList ] } {
                                    errorMsg "Error setting  tableUdf on $chassId $cardId $portId"
                                    set retCode $::TCL_ERROR
                                    break
                            }

                    }			
                    if {[tableUdf set $chassId $cardId $portId	] } {
                            errorMsg "Error setting  tableUdf on $chassId $cardId $portId"
                            set retCode $::TCL_ERROR
                            break
                    }

                    stream setDefault
                    stream config -framesize		100
                    stream config -numFrames		$numAddresses
                    stream config -dma				stopStream
                    stream config -daRepeatCounter	daArp

                    if [port isActiveFeature $chassId $cardId $portId portFeatureAtm] {
                            set queueId     1

                            if [stream setQueue $chassId $cardId $portId $queueId $lastStreamId] {
                                    errorMsg "Error stream setQueue on port $chassId $cardId $portId $queueId $lastStreamId"
                                    set retCode $::TCL_ERROR
                                    break
                            }
                    } else {
                            if [stream set $chassId $cardId $portId $lastStreamId] {
                                    errorMsg "Error setting stream on port $chassId $cardId $portId $lastStreamId"
                                    set retCode $::TCL_ERROR
                                    break
                            }
                    }
                    incr  lastStreamId
                }
                                                                                                        
        } else {
                errorMsg "Error, portFeatureTableUdf is not supported on port $chassId $cardId $portId"
                set retCode $::TCL_ERROR
        }
    }

    ixWriteConfigToHardware portList -noProtocolServer

    if { $retCode } {
            errorMsg "Error generating stream from interfaces."
    }

    return $retCode		
}


proc getDhcpV6DiscoveredAddrList { interfaceDescription } \
{
    set ipV6AddressList []  
    
    if {[dhcpV6Properties cget -iaType] == $::dhcpV6IaTypePrefixDelegation } {
        interfaceTable getDiscoveredList

        if {![discoveredList getFirstAddress]} { 
            ipV6Address decode [discoveredAddress cget -ipAddress]
            if {[ipV6Address cget -prefixType] != $::ipV6LinkLocalUnicast } {
                    set ipV6AddressList [discoveredAddress cget -ipAddress]
            }

            while {![discoveredList getNextAddress] } {
                ipV6Address decode [discoveredAddress cget -ipAddress]
                if {[ipV6Address cget -prefixType] != $::ipV6LinkLocalUnicast } {
                        lappend ipV6AddressList [discoveredAddress cget -ipAddress]
                }
            }
        }
    } else {

        dhcpV6DiscoveredInfo setDefault
	    if {[interfaceTable getDhcpV6DiscoveredInfo  $interfaceDescription]} {
		    errorMsg "Error getting DhcpV6 Discovered table for $interfaceDescription on $chassId $cardId $portId."
	    }

        set ipV6AddressList   [dhcpV6DiscoveredInfo cget -discoveredAddressList]
    }

    return $ipV6AddressList
}


proc disableStreams { chassId cardId portId LastStreamId } \
{
	set retCode $::TCL_OK

	upvar $LastStreamId lastStreamId

	set  lastStreamId 1

	# Disable the existing streams here
	if {[port isActiveFeature $chassId $cardId $portId portFeatureAtm]} {
		set queueId     1

		if {[streamQueueList select $chassId $cardId $portId]} {
			errorMsg "Error selecting streamQueueList on port $chassId $cardId $portId"
			set retCode $::TCL_ERROR
		}
		# Disable all the stream on all the queues
		while {[streamQueue get $chassId $cardId $portId $queueId] == $::TCL_OK} {

			set streamId 1

			while { ![stream getQueue $chassId $cardId $portId $queueId $streamId]} {
				stream config -enable $::false

				if [stream setQueue $chassId $cardId $portId $queueId $streamId] {
					errorMsg "Error stream setQueue on port $chassId $cardId $portId $queueId $streamId"
					set retCode $::TCL_ERROR
					break
				}
				incr  streamId
			
			}
			if {$queueId == 1} {
				set lastStreamId $streamId
			}	
			incr queueId
		}

			
	} else {
		set streamId 1
		while {![stream get $chassId $cardId $portId $streamId]} {
			stream config -enable $::false

			if [stream set $chassId $cardId $portId $streamId] {
				errorMsg "Error setting stream on port $chassId $cardId $portId $streamId"
				set retCode $::TCL_ERROR
				break
			}
			incr  streamId
		}
		set lastStreamId $streamId
	} 
					
	return $retCode		
}

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

set userName IxiaTclUser
set hostname 172.16.174.137
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

set card1 1
set port1 1

set card2 2
set port2 1

set portList [list [list $chasId $card1 $port1] [list $chasId $card2 $port2]]

set macAddress(sa,$chasId,$card1,$port1) [format "be ef be ef %02x %02x" $card1 $port1]
set macAddress(sa,$chasId,$card2,$port2) [format "be ef be ef %02x %02x" $card1 $port1]
set macAddress(da,$chasId,$card1,$port1) $macAddress(sa,$chasId,$card2,$port2)
set macAddress(da,$chasId,$card2,$port2) $macAddress(sa,$chasId,$card1,$port1)
set ipAddress(sa,$chasId,$card1,$port1) [format "199.17.%d.%d" $card1 $port1]
set ipAddress(sa,$chasId,$card2,$port2) [format "199.17.%d.%d" $card2 $port2]
set ipAddress(da,$chasId,$card2,$port2) $ipAddress(sa,$chasId,$card1,$port1)
set ipAddress(da,$chasId,$card1,$port1) $ipAddress(sa,$chasId,$card2,$port2)

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

ixPuts "Setting ports to factory defaults..."
foreach item $portList {
    scan $item "%d %d %d" chasId card port
    if {[port setFactoryDefaults $chasId $card $port]} {
        errorMsg "Error setting factory defaults on $chasId.$card.$port"
        clearOwnershipAndLogout
        
        return $::TCL_ERROR
    }
    
    if {[ixWritePortsToHardware portList]} {
        clearOwnershipAndLogout
        return $::TCL_ERROR
    }
    
    if {[ixCheckLinkState portList]} {
        clearOwnershipAndLogout
        return $::TCL_ERROR
    }
    
    #ixPuts "Configuring streams..."
    #ixGlobalSetDefault
    #protocol config -ethernetType ethernetII
    #protocol config -name ip
    #
    #stream config -numFrames 10
    #stream config -rateMode streamRateModePercentRate
    #stream config -percentPacketRate 42
    #
    #foreach item $portList {
    #    scan $item "%d %d %d" chasId card port
    #    set frameSize 64
    #    
    #    ip config -sourceIpAddr $ipAddress(sa,$chasId,$card1,$port1)
    #    ip config -destIpAddr $ipAddress(da,$chasId,$card1,$port1)
    #    
    #    puts "debug info source IP address for port $port is:$ipAddress(sa,$chasId,$card1,$port1)"
    #    puts "debug info destination IP address for port $port is:$ipAddress(da,$chasId,$card1,$port1)"
    #    
    #    if {[ip set $chasId $card $port]} {
    #        logMsg "Error setting IP on $chasId,$card,$port"
    #        set retCode $::TCL_ERROR
    #        break
    #    }
    #    
    #    stream config -sa $macAddress(sa,$chasId,$card1,$port1)
    #    stream config -da $macAddress(da,$chasId,$card1,$port1)
    #}
}

generateStreamsFromInterfaces $portList

disableStreams $chassId $card1 $port1 1