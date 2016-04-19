#############################################################################################
#   Version 8.01
#   
#   File: sgStream.tcl
#
#   Copyright © 2011 IXIA.
#   All Rights Reserved.
#
#	Revision Log:
#	04-02-2001	EM	Genesis
#
#
#############################################################################################


########################################################################
# Procedure: getProtocolInStream
#
# This command generates commands for specific protocol in the stream
# Arguments(s):
#
# cmd     : command. ( arp, icmp,igmp, ip, ipx, rip, tcp, udp, pauseControl )
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id

########################################################################
proc scriptGen::getProtocolInStream { cmd chassis card port packet { circuitId 0 } {enableSet yes} } \
{
    set retCode $::TCL_OK

    set  isProtocol 1
    if {[llength $packet] != 0 } {
		if { $circuitId } {
			set isProtocol   [expr ![$cmd  decode $packet $chassis $card $port $circuitId]]
		} else {
			set isProtocol   [expr ![$cmd  decode $packet $chassis $card $port ]]
		}
    }

    if {[$cmd get $chassis $card $port]} {
        errorMsg "Error getting $cmd on $chassis $card $port"
        set retCode $::TCL_ERROR 
    }

    if {($retCode == 0) && $isProtocol} {
        generateCommand $cmd

        if { $enableSet == "yes" } {
			if { [isVcatProtocol $cmd] } {
				sgPuts "$cmd set [format "$%s $%s $%s $%s" chassis card port circuitId]"
			} else {
				sgPuts "$cmd set [format "$%s $%s $%s" chassis card port]"
			}
        }
    } else {
		set retCode  $::TCL_ERROR
	}

    return $retCode    
}


########################################################################
# Procedure: generateCommonStreamConfigs
#
# This command generates commands for protocols in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id

########################################################################
proc scriptGen::generateCommonStreamConfig { chassis card port streamId seqTypeOrId  } \
{    
	set streamCommandExcludeList ""
	if {![port isValidFeature $chassis $card $port $::portFeatureUseInterfaceInStream]} { 
		lappend streamCommandExcludeList enableSourceInterface sourceInterfaceDescription		
    }
    
    if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {
        lappend streamCommandExcludeList sa da daRepeatCounter daStep daMaskValue daMaskSelect enableDaContinueFromLastValue numDA numSA \
                                         saRepeatCounter saStep saMaskValue saMaskSelect enableSaContinueFromLastValue numSA
    }
    generateCommand stream yes $streamCommandExcludeList
       
    sgPuts ""

    set protocolList [list name appName ethernetType enable802dot1qTag enableISLtag \
                           enableMPLS enableMacSec enableOAM ] 
	                           
    if {[port isValidFeature $chassis $card $port $::portFeatureCiscoMetaDataTag]} {
    	lappend protocolList enableCMD
    }
    
    if {[port isValidFeature $chassis $card $port $::portFeatureDataCenterEncapsulation]} {
    	lappend protocolList enableDataCenterEncapsulation
    }
    
    if {![port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {
    	lappend protocolList enableProtocolPad
    }
    
    partiallyGenerateCommand protocol $protocolList
    sgPuts ""

    # Start of the gre config generation
    if { [isGrePacket $chassis $card $port $seqTypeOrId] } {

        generateGreProtocols $chassis $card $port $seqTypeOrId

        # We need one more stream get here in order to get the outer IP configuration
        if {[port isActiveFeature $chassis $card $port $::portFeatureAtm]} {
            if {[stream getQueue $chassis $card $port $seqTypeOrId $streamId]} {
                errorMsg "Error getting stream queue $seqTypeOrId on $chassis $card $port for stream $streamId "
                set retCode $::TCL_ERROR 
            }
        } elseif {[port isActiveFeature $chassis $card $port $::portFeatureVcat]} {
            if {[stream getCircuit $chassis $card $port $seqTypeOrId $streamId]} {
                errorMsg "Error getting stream circuit $seqTypeOrId on $chassis $card $port for stream $streamId "
                set retCode $::TCL_ERROR 
            }
        } else {
            if {[stream get $chassis $card $port $streamId $seqTypeOrId]} {
                errorMsg "Error getting stream on $chassis $card $port for stream $streamId "
                set retCode $::TCL_ERROR 
            }
        }
        # since we've already generated the appName stuff <dhcp, rip, etc.>, we can disable it
        protocol config -appName none
    }
    # End of Gre code

    if {![port isActiveFeature $chassis $card $port $::portFeatureVcat]} {
        # We don't need this seqTypeOrId after this point for non VCAT 
        set seqTypeOrId 0

    }
	
	generateAllProtocols		$chassis $card $port $seqTypeOrId
	generateOtherL2Config		$chassis $card $port $seqTypeOrId
    getUdfInStream				$chassis $card $port
	getPacketLengthInsertionInStream $chassis $card $port
	getTableUdfInStream			$chassis $card $port
    getSequenceNumberUdfInStream $chassis $card $port
    getWeightedRandomFrameSize	$chassis $card $port

    set retCode $::TCL_OK


}


########################################################################
# Procedure: generateAllProtocols
#
# This command generates commands for protocols in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id

########################################################################
proc scriptGen::generateAllProtocols { chassis card port circuitId } \
{
    variable generatePacketView

    set retCode $::TCL_OK

    # We don't care to decode the packet, when generatePacketView is set to 0
    # and the generated code will be based on the serialized stream information,
    # instead of packet view

    set packet [list]
    if { $generatePacketView } {
        set packet  [stream cget -packetView]
    } 

    # We don't want to generate ip configurations when appName is Arp,
    # the default protocol name for ARP is ipV4 when we do stream get
    # since ip config is not needed for ARP, then we have to check the
    # the appName in order to skip the ip configuration generation

	set l4Protocol 0

    switch [protocol cget -name] \
        $::ip { \
            if { [protocol cget -appName ] != $::Arp } { \
                getProtocolInStream ip $chassis $card $port $packet $circuitId; \
				set l4Protocol  [ip cget -ipProtocol ];	\
            } \
        } \
        $::ipx { \
            getProtocolInStream ipx $chassis $card $port $packet \
        }\
        $::ipV6 { \
            getProtocolInStream ipV6 $chassis $card $port $packet $circuitId no ; \
            set ipV6NextHeader [ipV6 cget -nextHeader] ;            \
            if { ($ipV6NextHeader != $::ipV6NoNextHeader) } { ; \
				set l4Protocol [getIpV6ExtensionHeaders] ;\
			}; \
        
            sgPuts "ipV6 set [format "$%s $%s $%s" chassis card port]";\

        } \
        $::pauseControl { \
            getProtocolInStream pauseControl $chassis $card $port $packet; \
        } \
        $::fcoe { \
			getFcoeInStream $chassis $card $port $packet; \
        } \
        $::nativeFc { \
            getNativeFcInStream $chassis $card $port $packet; \
        }

    # Generate code for tunneled IP.  If we have IP but not tunneled IP,
	# we must reset the "other" protocol back to defaults.
    switch $l4Protocol \
        $::ip { \
            if { [protocol cget -appName ] != $::Arp } { \
                getProtocolInStream ip $chassis $card $port $packet $circuitId; \
				set l4Protocol  [ip cget -ipProtocol ];	\
            } \
        } \
        $::ipV4ProtocolIpv6 { \
            getProtocolInStream ipV6 $chassis $card $port $packet $circuitId no ; \
            set ipV6NextHeader [ipV6 cget -nextHeader] ;            \
            if { ($ipV6NextHeader != $::ipV6NoNextHeader) } { ; \
				set l4Protocol [getIpV6ExtensionHeaders] ;\
			}; \
        
            sgPuts "ipV6 set [format "$%s $%s $%s" chassis card port]"\
        } 
        
	getLayer4Protocols $chassis $card $port $l4Protocol $circuitId

    if { $generatePacketView } {
        getProtocolInStream arp $chassis $card $port $packet
		getDhcpInStream $chassis $card $port $packet $circuitId 
        getRipInStream  $chassis $card $port $packet $circuitId 

    } else {
        switch [protocol cget -appName ] \
            $::SrpArp - \
            $::Arp { \
                getProtocolInStream arp $chassis $card $port $packet ; \
            } \
		    $::Dhcp { \
                getDhcpInStream  $chassis $card $port $packet $circuitId; \
            } \
		    $::Rip { \
                getRipInStream   $chassis $card $port $packet $circuitId; \
            } \
			$::Ptp { \
                getPtpInStream   $chassis $card $port $packet; \
			}
    }

    return $retCode    
}

########################################################################
# Procedure: getNativeFcInStream
#
# This command generates commands for Native Fibre Channel
# in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getNativeFcInStream { chassis card port packet } \
{
    variable generatePacketView

    set retCode 0
    
    # This is a dirty hack. We need to think about how to avoid this. Currently the
    # only way to know what native FC protocol is active is to decode the packet. Of
    # course there is no packet available if the user has chosen to generate stream
    # data from the frame data. A better alternative would be to provide an true
    # fcNative container in the ProtocolStack and a method on the container that
    # could tell TCL what is active. 
    if { $generatePacketView == 0 } {
        set packet [stream cget -packetView]
    }    
    
    set retCode [ expr [getFcSOFInStream            $chassis $card $port $packet] || $retCode ]
    set retCode [ expr [getFibreChannelInStream     $chassis $card $port $packet] || $retCode ]
    set retCode [ expr [getCommonTransportInStream  $chassis $card $port $packet] || $retCode ]
    set retCode [ expr [getBlsInStream              $chassis $card $port $packet] || $retCode ]
    set retCode [ expr [getElsInStream              $chassis $card $port $packet] || $retCode ]
    set retCode [ expr [getFcpInStream              $chassis $card $port $packet] || $retCode ]
    set retCode [ expr [getFcEOFInStream            $chassis $card $port $packet] || $retCode ]

    return $retCode
}

########################################################################
# Procedure: getCommonTransportInStream
#
# This command generates commands for Fibre Channel Commmon Transport
# in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getCommonTransportInStream { chassis card port packet } \
{
    set retCode 0

    if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {

		set isCommonTransport 0
		if {[llength $packet] != 0 && [commonTransport decode $packet $chassis $card $port] == 0} {
			set isCommonTransport 1
		}
		if {[commonTransport get $chassis $card $port]} {
			errorMsg "Error getting Fibre Channel Common Transport on $chassis $card $port"
			set retCode 1 
		}
		if {($retCode == 0) && $isCommonTransport} {
        
			switch [commonTransport cget -ctCommand] "
				$::ctGetAllNextRequest { 
					generateCommand ctGetAllNextRequest 
				} 
				$::ctGetAllNextAccept {  
					generateCommand ctGetAllNextAccept 
				} 
				$::ctGetPortNameRequest { 
					generateCommand ctGetPortNameRequest 
				} 
				$::ctGetPortNameAccept {  
					generateCommand ctGetPortNameAccept 
				}
				$::ctGetNodeNameRequest {  
					generateCommand ctGetNodeNameRequest 
				}
               	$::ctGetNodeNameAccept {  
					generateCommand ctGetNodeNameAccept 
				} 
               	$::ctGetFC4TypeRequest {  
					generateCommand ctGetFC4TypeRequest 
				} 
               	$::ctRegisterNodeNameRequest {  
					generateCommand ctRegisterNodeNameRequest 
				}  
			"
			sgPuts ""
			generateCommand ctPreamble

			sgPuts ""
			generateCommand commonTransport

			sgPuts {commonTransport set $chassis $card $port}
		}
	}    

    return $retCode
}

########################################################################
# Procedure:    getFibreChannelOptHeaderInStream
#
# Description:  Generate commands for FibreChannelHeader Optional Header
#               commands in the stream.
#
# Arguments(s): chassis : chassis Id
#               card    : card Id
#               port    : port Id
#				packet	: contains packet bytes from the packet view
#
########################################################################
proc scriptGen::getFibreChannelOptHeaderInStream {chassis card port packet} \
{
    if {![port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {
        return 
    }

    variable enumsArray

	set enumList [list nhIEEE48BitAddress nhIEEEExtended nhLocallyAssigned nhIEEERegistered \
                       nhIEEERegisteredExtended nhEUI64Mapped nhNone]
	setEnumValList $enumList enumValList
	set enumsArray(networkHeader,destinationFormat) $enumValList
    set enumsArray(networkHeader,sourceFormat) $enumValList
    
    fibreChannel get $chassis $card $port 
    if {![fibreChannel getOptHeader $::optESPHeader $chassis $card $port]} {
        generateCommand espHeader
        sgPuts {fibreChannel setOptHeader optESPHeader $chassis $card $port}
    }

    if {![fibreChannel getOptHeader $::optAssociationHeader $chassis $card $port]} {
        generateCommand associationHeader
        sgPuts {fibreChannel setOptHeader optAssociationHeader $chassis $card $port}
    }    

    if {![fibreChannel getOptHeader $::optNetworkHeader $chassis $card $port]} {
        
        set doPuts 1

        switch [networkHeader cget -destinationFormat] "
            $::nhIEEE48BitAddress { 
                generateCommand  iEEE48BitAddressDest
            } 
            $::nhIEEEExtended {  
                generateCommand iEEEExtendedDest
            } 
            $::nhLocallyAssigned { 
                generateCommand  locallyAssignedDest
            } 
            $::nhIEEERegistered {  
                generateCommand iEEERegisteredDest
            }
            $::nhIEEERegisteredExtended {  
                generateCommand iEEERegisteredExtendedDest
            } 
            $::nhEUI64Mapped {  
                generateCommand eUI64MappedDest
            } 
            default {  
                set doPuts 0
            }             
        "
        if {$doPuts} {
            sgPuts ""
        }

        set doPuts 1

        switch [networkHeader cget -sourceFormat] "
            $::nhIEEE48BitAddress { 
                generateCommand  iEEE48BitAddressSrc 
            } 
            $::nhIEEEExtended {  
                generateCommand iEEEExtendedSrc
            } 
            $::nhLocallyAssigned { 
                generateCommand  locallyAssignedSrc
            } 
            $::nhIEEERegistered {  
                generateCommand iEEERegisteredSrc
            }
            $::nhIEEERegisteredExtended {  
                generateCommand iEEERegisteredExtendedSrc
            } 
            $::nhEUI64Mapped {  
                generateCommand eUI64MappedSrc
            } 
            default {  
                set doPuts 0
            }             
        "
        if {$doPuts} {
            sgPuts ""
        }        

        generateCommand networkHeader
        sgPuts {fibreChannel setOptHeader optNetworkHeader $chassis $card $port}
    }
}

########################################################################
# Procedure:    getFibreChannelExtHeaderInStream
#
# Description:  Generate commands for FibreChannelHeader Extended Header
#               commands in the stream.
#
# Arguments(s): chassis : chassis Id
#               card    : card Id
#               port    : port Id
#				packet	: contains packet bytes from the packet view
#
########################################################################
proc scriptGen::getFibreChannelExtHeaderInStream {chassis card port packet} \
{
    if {![port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {
        return 
    }

    variable enumsArray

	set enumList [list vftBestEfrort vftBacvftground vftSpare vftExcellentEffort \
                       vftControlledLoad vftVideo vftVoice vftNetworvftControl]
	setEnumValList $enumList enumValList
	set enumsArray(vftHeader,priority) $enumValList
    
    # Extended headers are like TLVs. There can be any number of them
    # and within that set there can be multiples of the same type
    # of extended header. To show them to the user they are iterated.

    set headerList($::extVFTHeader) "extVFTHeader"
    set headerList($::extIFRHeader) "extIFRHeader"
    set headerList($::extEncHeader) "extEncHeader"
   
    sgPuts {fibreChannel clearAllExtHeaders $chassis $card $port}

    set headerCount [fibreChannel getExtHeaderCount $chassis $card $port]

    for {set index 0} {$index < $headerCount} {incr index} {
        fibreChannel getExtHeader $index $chassis $card $port
        set headerType [fibreChannel getExtHeaderType $index $chassis $card $port]
        switch $headerType "
            $::extVFTHeader { 
                generateCommand  vftHeader
            } 
            $::extIFRHeader {  
                generateCommand ifrHeader
            } 
            $::extEncHeader { 
                generateCommand  encHeader
            }
        " 
        sgPuts "fibreChannel addExtHeader [format "%s $%s $%s $%s" $headerList($headerType) chassis card port]"
    }
}

########################################################################
# Procedure:    getFibreChannelInStream
#
# Description:  Generate commands for FibreChannelHeader commands in the stream.
#               Function extracted for reuse with Native FC & FCoE
#
# Arguments(s): chassis : chassis Id
#               card    : card Id
#               port    : port Id
#				packet	: contains packet bytes from the packet view
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getFibreChannelInStream {chassis card port packet} \
{
	variable enumsArray 

    set retCode $::TCL_OK

	if {![fibreChannel get $chassis $card $port]} {

		# sequenceContext enums
		if {[fibreChannel cget -sequenceContext]} {
			set enumList [list fibreChannelDiscardMultiple fibreChannelDiscardSingle fibreChannelProcessPolicy fibreChannelDiscardMultipleWithRetransmission];\
		} else {
			set enumList [list fibreChannelContinue fibreChannelPerformAbts fibreChannelStop fibreChannelRetransmissionRequested]
		} 
		setEnumValList $enumList enumValList
		set enumsArray(fibreChannel,abortSequenceCondition)  $enumValList

		switch [fibreChannel cget -routingControlType] \
            $::fibreChannelDeviceDataFrames - \
            $::fibreChannelFc4LinkData { \
				set enumList [list fibreChannelUncategorizedInformation fibreChannelSolicitedData fibreChannelUnsolicitedControl \
					fibreChannelSolicitedControl fibreChannelUnsolicitedData fibreChannelDataDescriptor \
					fibreChannelUnsolicitedCommand fibreChannelCommandStatus ];\
            } \
		    $::fibreChannelExtendedLinkServices { \
				set enumList [list fibreChannelSolicitedData fibreChannelRequest fibreChannelReply ];\
            } \
		    $::fibreChannelVideoData { \
				set enumList [list fibreChannelUnsolicitedData  ];\
            } \
            $::fibreChannelExtenderHeaders { \
				set enumList [list fibreChannelVirtualFabricTaggingHeader  fibreChannelInterFabricRoutingHeader \
					fibreChannelEncapsulationHeader ];\
            } \
			$::fibreChannelBasicLinkServices { \
				set enumList [list fibreChannelNoOperation fibreChannelAbortSequence fibreChannelRemoveConnection \
				   fibreChannelBasicAccept fibreChannelBasicReject fibreChannelDedicatedConnectionPreempted ];\
			}\
            $::fibreChannelLinkControlFrame { \
				set enumList [list fibreChannelAcknowledge1 fibreChannelAcknowledge0 fibreChannelNxPortReject \
					fibreChannelFabricReject fibreChannelNxPortBusy fibreChannelFabricBusyToDataFrame \
					fibreChannelFabricBusyToLinkControlFrame fibreChannelLinkCreditReset fibreChannelNotify fibreChannelEnd ]\
            } \
			$::fibreChannelExtendedRouting { \
				set enumList [list fibreChannelVendorUnique ];\
            }
		setEnumValList $enumList enumValList
		set enumsArray(fibreChannel,routingControlInformation)  $enumValList
	}


    generateCommand fibreChannel
    sgPuts ""

    getFibreChannelExtHeaderInStream $chassis $card $port $packet
    getFibreChannelOptHeaderInStream $chassis $card $port $packet

    sgPuts "fibreChannel set [format "$%s $%s $%s" chassis card port]"

    return $retCode    
}


########################################################################
# Procedure:    getFcoeInStream
#
# Description:  Generate commands for FCoE commands in the stream.
#
# Arguments(s): chassis : chassis Id
#               card    : card Id
#               port    : port Id
#				packet	: contains packet bytes from the packet view
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getFcoeInStream {chassis card port packet} \
{
	variable enumsArray 

    set retCode $::TCL_OK

	getProtocolInStream fcoe $chassis $card $port $packet
	
	set retCode [getFibreChannelInStream $chassis $card $port $packet ]

    return $retCode    
}


########################################################################
# Procedure: generateOtherL2Config
#
# This command generates other stream config parameters
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id

########################################################################
proc scriptGen::generateOtherL2Config { chassis card port { seqTypeOrId 0 } } \
{
    variable generateHdlcPerStream

    set retCode $::TCL_OK

	getDataCenterEncapsulationInStream		$chassis $card $port         
    getSrpInStream		$chassis $card $port
    getRprInStream		$chassis $card $port
	getIslInStream		$chassis $card $port      
	getVlanInStream		$chassis $card $port         
	getMacSecInStream	$chassis $card $port
	getCmdInStream		$chassis $card $port
	getOamInStream      $chassis $card $port  
	getMplsInStream		$chassis $card $port
	getProtocolPadInStream    $chassis $card $port

	set isVcat [port isActiveFeature $chassis $card $port $::portFeatureVcat]

	if { $generateHdlcPerStream } {
		if {![getCommand hdlc $chassis $card $port $seqTypeOrId]} { 
			if { $isVcat } {
				sgPuts  {hdlc set $chassis $card $port $circuitId}
			} else {
				sgPuts  {hdlc set $chassis $card $port}
			}					              
        } 
	}

	if {$isVcat} {
		set headerType [sonetCircuitProperties cget -payloadType]
	} else {			
		set headerType [sonet cget -header]
	}

    if {[port isActiveFeature $chassis $card $port $::portFeatureSonet] } {

        if { $headerType == $::sonetFrameRelay1490   || \
             $headerType == $::sonetFrameRelayCisco  || \
             $headerType == $::sonetFrameRelay2427 } {

            if {![getCommand frameRelay  $chassis $card $port $seqTypeOrId]} {
				if { $isVcat } {
					sgPuts  {frameRelay set $chassis $card $port $circuitId}
				} else {
					sgPuts  {frameRelay set $chassis $card $port}
				}
			}
        }
		if { $headerType == $::sonetGfp } {
           if {![getCommand gfp  $chassis $card $port $seqTypeOrId]} {
				if { $isVcat } {
					sgPuts  {gfp set $chassis $card $port $circuitId}
				} else {
					sgPuts  {gfp set $chassis $card $port}
				}
			}
        }
    }

    if { [protocol cget -ethernetType] == $::protocolOffsetType } {
		if {[protocolOffset get $chassis $card $port] == $::TCL_OK} {
			generateCommand protocolOffset
			sgPuts {protocolOffset set $chassis $card $port}
		}
	}

    #Set it to original value 
	set generateHdlcPerStream 0

    return $retCode    
}


########################################################################
# Procedure: getLayer4Protocols
#
# This command generates commands for ip protocols ( Layer 4 protocols)
# Arguments(s):
#
# chassis		: chassis Id
# card			: card Id
# port			: port Id
# l4Protocol	: inner (when Gre is present) or outer IP protocol
# packet		: packet bytes
#
########################################################################
proc scriptGen::getLayer4Protocols { chassis card port l4Protocol circuitId } \
{
    variable generatePacketView

    set packet [list]

    set retCode $::TCL_OK

    set appNameFlag 1
    if { $generatePacketView } {
        set packet  [stream cget -packetView]
        set l4Protocol [list $::ipV4ProtocolIcmp $::ipV4ProtocolTcp $::ipV4ProtocolUdp $::ipV4ProtocolIgmp $::ipV4ProtocolIpv6Icmp]

    } else {
        # We don't need to generate any L4 protocol config when appName is ARP
        if { ([protocol cget -appName ] == $::SrpArp) || ([protocol cget -appName ] == $::Arp) } {
			set appNameFlag 0 
        } 
    }

	if {$appNameFlag } {	
		foreach protocol $l4Protocol {
			# We don't need to generate any L4 protocol config when appName is ARP
			switch $protocol \
				$::ipV4ProtocolUdp { \
					getProtocolInStream udp $chassis $card $port $packet $circuitId \
				} \
				$::ipV4ProtocolTcp { \
					getProtocolInStream tcp $chassis $card $port $packet $circuitId \
				} \
				$::igmp { \
					if {![ getProtocolInStream igmp $chassis $card $port $packet $circuitId no]} { ;\
						getIgmpV3GroupRecords ;\
						sgPuts "igmp set [format "$%s $%s $%s" chassis card port]" ;\
					};\
				} \
				$::ipV4ProtocolIcmp { \
					getProtocolInStream icmp $chassis $card $port $packet $circuitId \
				}\
				$::ipV4ProtocolIpv6Icmp { \
					if {![ getProtocolInStream icmpV6 $chassis $card $port $packet $circuitId no]} { ;\
						getIcmpV6InStream $chassis $card $port ;\
						sgPuts "icmpV6 set [format "$%s $%s $%s" chassis card port]" ;\
					};\
				}
		}
	}

    return $retCode    
}


########################################################################
# Procedure: isGrePacket
#
# This command checks if the packet is a Gre packet
# Arguments(s):
#
# chassis		: chassis Id
# card			: card Id
# port			: port Id
#
# Return values :
#   1 if TRUE
#   0 if FALSE
#
########################################################################
proc scriptGen::isGrePacket { chassis card port circuitId} \
{
    variable generatePacketView

    set retCode $::true

    set packet [list]
    if { $generatePacketView } {
        set packet  [stream cget -packetView]
    }

	#
	# NOTE: Assuming there was a stream get performed before this
	#
	# Encapsulated gre protocol
	# Find out if Gre is enabled either in ip or ipV6 

	if {[port isValidFeature $chassis $card $port $::portFeatureGre]} {

		if { $generatePacketView } {
			if {[ip decode $packet $chassis $card $port $circuitId]} {
				if {[ipV6 decode $packet $chassis $card $port $circuitId]} {
					return $::false
				} 
			}
		}

		if {[ip get $chassis $card $port]} {
			errorMsg "Error getting ip on $chassis $card $port"
			set retCode $::false 
		}

		if {[ipV6 get $chassis $card $port]} {
			errorMsg "Error getting ipV6 on $chassis $card $port"
			set retCode $::false 
		}
		if {$retCode && ([ip cget -ipProtocol] != $::ipV4ProtocolGre) && ( [getIpV6NextHeader] != $::ipV4ProtocolGre)} {
			set retCode $::false 
		}
	} else {
		set retCode $::false
	}							
							
    return $retCode    
}


########################################################################
# Procedure: generateGreProtocols
#
# This command generates commands for gre along with it's encapsulated
# protocols
#
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
########################################################################
proc scriptGen::generateGreProtocols { chassis card port circuitId } \
{
    variable generatePacketView

    set retCode $::TCL_OK

	# save the original...
	set protocolName [protocol cget -name]

    # We don't care to decode the packet, when generatePacketView is set to 0
    # and the generated code will be based on the serialized stream information,
    # instead of packet view

    set packet [list]
    if { $generatePacketView } {
        set packet  [stream cget -packetView]
		if {[llength $packet] != 0 } {
			if {[gre decode $packet $chassis $card $port $circuitId]} {
				errorMsg "Error getting gre on port $chassis $card $port $circuitId"
				set retCode $::TCL_ERROR 
			}
		}    
	} 

	if {[gre get $chassis $card $port]} {
		errorMsg "Error getting gre on port $chassis $card $port"
		set retCode $::TCL_ERROR 
	}

	# now we need to know what the next thing is, so get it from the gre protocol type
	switch [gre cget -protocolType] {
		"08 00" {
			protocol config -name ip
		}
		"86 dd" {
			protocol config -name ipV6
		} 
	}

	# note - this just gets the inner IP protocol stuff
	generateAllProtocols $chassis $card $port $circuitId

	generateCommand gre
	sgPuts "gre set [format "$%s $%s $%s" chassis card port]"

	# put back the original
	protocol config -name	$protocolName

    return $retCode    
}

proc isAutoSizeFCoEWithInstrumentation { sizeType chassis card port streamID } {
    set ret 0
    if {[port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode]  && ($sizeType == $::sizeAuto) } {

        if { ![autoDetectInstrumentation getTx $chassis $card $port $streamID] } {

            if {[autoDetectInstrumentation cget -enableTxAutomaticInstrumentation]} {
                set ret 1
            }
         }
     }
     
     return $ret    

}

########################################################################
# Procedure: getStreamScript
#
# This command generates commands for streams
# Arguments(s):
#
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
########################################################################
proc scriptGen::getStreamScript { chassis card port} \
{
    set retCode $::TCL_OK

    set streamId 1

    set streamSequenceTypeList $::streamSequenceTypeAll

    # need to account for dcc flows
    if {[port isActiveFeature $chassis $card $port $::portFeatureTxDccFlowsSpeStreams] ||
        [port isActiveFeature $chassis $card $port $::portFeatureTxDccFlowsSpeAdvancedScheduler]} {
        set streamSequenceTypeList {streamSequenceTypeStreams streamSequenceTypeFlows}
    }

    foreach streamSequenceType $streamSequenceTypeList {

		if { [stream get $chassis $card $port $streamId $streamSequenceType] } {
		    sgPuts {port reset $chassis $card $port}
			continue
		}
        sgPuts "set streamId 1"
        sgPuts

        for {set streamId 1} {[stream get $chassis $card $port $streamId $streamSequenceType] != 1} {incr streamId} {
            
            # This call will reset any protocol configurations already in the protocol stack.
            # This is done because the TCLPort has a "cached" version of the CProtocolStack
            # that is used for every stream on the port. If it isn't cleared then settings
            # from previous streams are carried through to the current stream. THIS IS 
            # UNDESIRABLE BEHAVIOR.
            sgPuts {port resetStreamProtocolStack $chassis $card $port}        
            sgPuts "#  Stream $streamId"
            
            set sizeType [stream cget -frameSizeType]
            set isAutoSizeFCoE [isAutoSizeFCoEWithInstrumentation $sizeType $chassis $card $port $streamId]
            
            if { $isAutoSizeFCoE } {
                getInstrumentation  $chassis $card $port $streamId $streamSequenceType
            }
            
			generateCommonStreamConfig $chassis $card $port $streamId $streamSequenceType 
        
        	if { [port isActiveFeature $chassis $card $port $::portFeatureCiscoCDL] } {
                if {[cdlPreamble get $chassis $card $port] == $::TCL_OK} {
            	    generateCommand cdlPreamble
              	    sgPuts {cdlPreamble set $chassis $card $port}
                } else {
                     errorMsg "Error getting cdlPreamble $chassis $card $port"
                     set retCode $::TCL_ERROR
                }                    
        	}
            
            if {$streamSequenceType == $::streamSequenceTypeAll} {
                sgPuts {stream set $chassis $card $port $streamId}
            } else {
                sgPuts [format {stream set $chassis $card $port $streamId $::%s} $streamSequenceType]
            }
            
            if { !$isAutoSizeFCoE } {
                getInstrumentation  $chassis $card $port $streamId $streamSequenceType
            }
            
 
            sgPuts "incr streamId"                            
        }
    }

    return $retCode
}



########################################################################
# Procedure:    getInstrumentation
#
# Description:  Generate commands for Instrumentation commands in the stream.
#
# Arguments(s): chassis : chassis Id
#               card    : card Id
#               port    : port Id
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getInstrumentation {chassis card port streamId seqTypeOrId } \
{
    set retCode         $::TCL_OK
    set generateFlag    1


	set subCmdGet		"getQueueTx"		
	set subCmdSet		"setQueueTx"
	set idName			"queueId"		
	if {[port isActiveFeature $chassis $card $port $::portFeatureVcat]} {
		set subCmdGet	"getCircuitTx"	
		set subCmdSet	"setCircuitTx"
		set idName		"circuitId"		
	}
    set udfSequenceNumberCommandList [ list repeat continuousCount initval updown cascadeType step ]

	if {[port isActiveFeature $chassis $card $port $::portFeatureAtm] || \
		[port isActiveFeature $chassis $card $port $::portFeatureVcat] } {

        if {![packetGroup $subCmdGet $chassis $card $port $seqTypeOrId $streamId]} {
            if { [packetGroup cget -insertSignature] || [packetGroup cget -insertSequenceSignature] } {
                if { [packetGroup cget -allocateUdf] } {
                    partiallyGenerateCommand udf $udfSequenceNumberCommandList
                }
                set packetGroupCommandExcludeList ""
                if { ![port isValidFeature $chassis $card $port $::portFeatureDelayVariation]} { 
					lappend packetGroupCommandExcludeList delayVariationMode
				}
				generateCommand packetGroup yes $packetGroupCommandExcludeList 
				
                sgPuts [format {packetGroup %s $chassis $card $port $%s $streamId } $subCmdSet $idName]
            }
        } else {
             errorMsg "Error getting packet Group $chassis $card $port $seqTypeOrId $streamId"
             set retCode $::TCL_ERROR
        }
           
        if {![dataIntegrity $subCmdGet $chassis $card $port $seqTypeOrId $streamId]} {
            if {[dataIntegrity cget -insertSignature]} {
                generateCommand dataIntegrity 
                sgPuts [format {dataIntegrity %s $chassis $card $port $%s $streamId } $subCmdSet $idName]
            }
        } else {
             errorMsg "Error getting dataIntegrity $chassis $card $port $seqTypeOrId $streamId"
             set retCode $::TCL_ERROR
        }

	    if {[port isValidFeature $chassis $card $port $::portFeatureAutoDetectTx]} {

            if {![autoDetectInstrumentation $subCmdGet $chassis $card $port $seqTypeOrId $streamId]} {
                if {[autoDetectInstrumentation cget -enableTxAutomaticInstrumentation]} {
			        set autoDetectInstrCommandList [list enableTxAutomaticInstrumentation signature ]
					if {[port isValidFeature $chassis $card $port $::portFeaturePRBS]} {
						lappend autoDetectInstrCommandList enablePRBS
					}
			        partiallyGenerateCommand autoDetectInstrumentation $autoDetectInstrCommandList
                    sgPuts [format {autoDetectInstrumentation %s $chassis $card $port $%s $streamId } $subCmdSet $idName]
                }
            } else {
                 errorMsg "Error getting autoDetectInstrumentation $chassis $card $port $seqTypeOrId $streamId"
                 set retCode $::TCL_ERROR
            }
        }

	} else {

        if {$seqTypeOrId == $::streamSequenceTypeAll} {
            set pgCmd [format {packetGroup setTx $chassis $card $port $streamId}]
            set diCmd [format {dataIntegrity setTx $chassis $card $port $streamId}]
            set inCmd [format {autoDetectInstrumentation setTx $chassis $card $port $streamId}]
        } else {
            set pgCmd [format {packetGroup setTx $chassis $card $port $streamId $::%s} $seqTypeOrId]
            set diCmd [format {dataIntegrity setTx $chassis $card $port $streamId $::%s} $seqTypeOrId]
            set inCmd [format {autoDetectInstrumentation setTx $chassis $card $port $streamId $::%s} $seqTypeOrId]
        }

        if { ![packetGroup getTx $chassis $card $port $streamId] } {
            if { [packetGroup cget -insertSignature] || [packetGroup cget -insertSequenceSignature] } {
                if { [packetGroup cget -allocateUdf] } {
                    partiallyGenerateCommand udf $udfSequenceNumberCommandList
                }            
                set packetGroupCommandExcludeList ""
                if { ![port isValidFeature $chassis $card $port $::portFeatureDelayVariation]} { 
					lappend packetGroupCommandExcludeList delayVariationMode
				}
				generateCommand packetGroup yes $packetGroupCommandExcludeList
                sgPuts $pgCmd
            }
        } else {
             errorMsg "Error getting packet Group $chassis $card $port $streamId"
             set retCode $::TCL_ERROR
        }   

        if { ![dataIntegrity getTx $chassis $card $port $streamId] } {
            if [dataIntegrity cget -insertSignature] {
                generateCommand dataIntegrity 
                sgPuts $diCmd
            }
        } else {
             errorMsg "Error getting dataIntegrity $chassis $card $port $streamId"
             set retCode $::TCL_ERROR
        } 

	    if {[port isValidFeature $chassis $card $port $::portFeatureAutoDetectTx]} {

            if { ![autoDetectInstrumentation getTx $chassis $card $port $streamId] } {
                if {[autoDetectInstrumentation cget -enableTxAutomaticInstrumentation]} {

			        set autoDetectInstrCommandList [list enableTxAutomaticInstrumentation signature ]
					if {[port isValidFeature $chassis $card $port $::portFeaturePRBS]} {
						lappend autoDetectInstrCommandList enablePRBS
					}
			        partiallyGenerateCommand autoDetectInstrumentation $autoDetectInstrCommandList
                    sgPuts $inCmd
                }
            } else {
                 errorMsg "Error getting autoDetectInstrumentation $chassis $card $port $streamId"
                 set retCode $::TCL_ERROR
            }
        }

	}

    return $retCode
}

########################################################################
# Procedure: getWeightedRandomFrameSize
#
# This command generates commands for Rip and rip routes in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getWeightedRandomFrameSize { chassis card port } \
{
    set retCode $::TCL_OK

    if { [port isActiveFeature $chassis $card $port $::portFeatureRandomFrameSizeWeightedPair] \
		|| [port isValidFeature $chassis $card $port $::portFeatureRandomFrameSizeUniform] \
		|| [port isValidFeature $chassis $card $port $::portFeatureRandomFrameSizePredefinedDistributions] } {
    
		if {![weightedRandomFramesize get $chassis $card $port] } {

			if { [weightedRandomFramesize cget -randomType] != $::randomUniform } {

				if {[weightedRandomFramesize cget -randomType] == $::randomQuadGaussian } {
					sgPuts "weightedRandomFramesize setDefault"
					sgPuts "weightedRandomFramesize config -randomType randomQuadGaussian"
					set excludedParmList [list randomType]
					for { set curveId 1} { $curveId <= 4 } { incr curveId} {

						if {![weightedRandomFramesize retrieveQuadGaussianCurve $curveId] } {
							generateCommand weightedRandomFramesize no	$excludedParmList
							sgPuts "weightedRandomFramesize updateQuadGaussianCurve $curveId"					
						} 					                    
					}
				} else {           
					set excludedParmList [list weight center widthAtHalf]
					generateCommand weightedRandomFramesize	yes $excludedParmList
				}

				if {[weightedRandomFramesize cget -randomType] == $::randomWeightedPair } {

					foreach weightPair [weightedRandomFramesize cget -pairList] {

						set frSize [lindex $weightPair 0]
						set weight [lindex $weightPair 1]

						weightedRandomFramesize addPair $frSize  $weight
						sgPuts "weightedRandomFramesize addPair $frSize  $weight"
					}
				}
			 
				sgPuts {weightedRandomFramesize set $chassis $card $port}
			} else {
				# This needs to be added just in case if the previous script or configuration has the
				# weightedRandomFramesize configured
				sgPuts
				sgPuts -noFormat "if \{\[port isValidFeature \$chassis \$card \$port \$::portFeatureRandomFrameSizeWeightedPair\]\} \{ "
				sgPuts -noFormat {	weightedRandomFramesize setDefault}
				sgPuts -noFormat {	weightedRandomFramesize set $chassis $card $port}
				sgPuts -noFormat "\}"
				sgPuts
			}
		}
	}
        
    return $retCode
}




########################################################################
# Procedure: getUdfInStream
#
# This command generates commands for udf in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id

########################################################################
proc scriptGen::getUdfInStream { chassis card port } \
{
	set retCode $::TCL_OK

    variable obsoleteParamsArray 

    if {![port isCapableFeature $chassis $card $port $::portFeatureUdfBitSize]} {
		# Generate countertype only for the ports that doesn't support this feature
        catch {unset obsoleteParamsArray(udf)}	;# for now we just have one obsolete parm
    }

    set maxUdfNum 4
    set maxUdfCount [lindex [lindex [lindex [port getFeature $chassis $card $port maximumUdfCount] 0] 1] 0]
    if { $maxUdfCount != "" } {
	set maxUdfNum $maxUdfCount
    } elseif {[port isValidFeature $chassis $card $port $::portFeatureUdf5]} {
        set maxUdfNum 5
    }


    for {set udfId 1} {$udfId <= $maxUdfNum} {incr udfId} {
        if {[udf get $udfId] } {
             errorMsg "Error getting udf$udfId for $streamId "
             set retCode $::TCL_ERROR
        }

        if { [udf cget -enable ] && [udf isUsedBySelf $udfId ] } {
            if {[udf cget -counterMode] == $::udfRangeListMode } {
                set  udfParamList [list enable offset counterMode chainFrom countertype bitOffset udfSize initval repeat step cascadeType]

                if { ![udf getFirstRange] } {

                    sgPuts "udf clearRangeList"
                    partiallyGenerateCommand udf $udfParamList
                    sgPuts "udf addRange"
                    
                    while {![udf getNextRange]} {
                        partiallyGenerateCommand udf $udfParamList
                        sgPuts "udf addRange"
                    }
                } else {
					set  udfParamList [list enable offset counterMode chainFrom countertype bitOffset udfSize cascadeType]
					partiallyGenerateCommand udf $udfParamList
				}
            } elseif {[udf cget -counterMode] == $::udfValueListMode } {
				if { [port isValidFeature $chassis $card $port $::portFeatureTLU $udfId] } {
					# If lookup mode is available, output indexMode
					set  udfParamList [list  enable offset counterMode chainFrom countertype enableIndexMode valueList bitOffset udfSize cascadeType]
				} else {
					set  udfParamList [list  enable offset counterMode chainFrom countertype valueList bitOffset udfSize cascadeType]
				}
				if { [port isValidFeature $chassis $card $port $::portFeatureKillBitMode $udfId] } {
					# If KillBitMode is available, output KillBitMode and Size
					lappend udfParamList enableKillBitMode killBitUDFSize
				}
				if { [port isValidFeature $chassis $card $port $::portFeatureUdfValueListRepeatCount $udfId] } {
					lappend udfParamList valueRepeatCount
				}
				partiallyGenerateCommand udf $udfParamList

            } elseif {[udf cget -counterMode] == $::udfIPv4Mode } {
                set udfParamList [list enable offset counterMode chainFrom countertype bitOffset udfSize initval innerRepeat innerStep \
                                       continuousCount repeat enableSkipZerosAndOnes skipMaskBits cascadeType]
               partiallyGenerateCommand udf $udfParamList

            } elseif {[udf cget -counterMode] == $::udfNestedCounterMode } {
				set udfParamList [list enable offset counterMode chainFrom countertype bitOffset udfSize initval \
										continuousCount repeat step  innerRepeat innerLoop innerStep cascadeType ]
				if { [port isValidFeature $chassis $card $port $::portFeatureTripleNestedUdf $udfId] } {
					lappend udfParamList tripleNestedLoop0Increment
				}
               partiallyGenerateCommand udf $udfParamList
			
			} elseif {[udf cget -counterMode] == $::udfRandomMode } {
				set udfParamList [list enable offset counterMode  countertype udfSize chainFrom maskselect maskval ]
               partiallyGenerateCommand udf $udfParamList
			
			} else {
				set udfParamList [list enable continuousCount offset counterMode chainFrom countertype  bitOffset udfSize \
									   updown initval repeat cascadeType enableCascade step ]

               partiallyGenerateCommand udf $udfParamList
            }                                     
            sgPuts "udf set $udfId"
        }
    }
    set udfParamList {}

    return $retCode
}

########################################################################
# Procedure: getPacketLengthInsertionInStream
#
# This command generates commands for Packet Length Insertions in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id

########################################################################
proc scriptGen::getPacketLengthInsertionInStream { chassis card port } \
{
	set retCode $::TCL_OK
    if {[port isCapableFeature $chassis $card $port $::portFeaturePacketLengthInsertion]} {
		set count [ packetLengthInsertion getCount ]
		if { $count > 0 } {
			# Generate output only for ports capable of this feature and they are present in the stream
			sgPuts "packetLengthInsertion add $count"
			for { set i 1} { $i <= $count } {incr i } {
				packetLengthInsertion get $i
				#force setDefault to clear previous state if any
				generateCommand packetLengthInsertion yes
				sgPuts "packetLengthInsertion set $i"
			}
		}
    }
    return $retCode
}

########################################################################
# Procedure: getTableUdfInStream
#
# This command generates commands for udf in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
########################################################################
proc scriptGen::getTableUdfInStream { chassis card port } \
{
	set retCode TCL_OK
    if {[port isValidFeature $chassis $card $port $::portFeatureTableUdf] } {

		if {[tableUdf get $chassis $card $port] } {
			 errorMsg "Error getting tableUdf on port $chassis $card $port "
			 set retCode $::TCL_ERROR
		}

		if {[tableUdf cget -enable] } {
			sgPuts "tableUdf setDefault"
			sgPuts "tableUdf clearColumns"
			sgPuts "tableUdf config -enable [tableUdf cget -enable]"

			if { ![tableUdf getFirstColumn] } {
				generateCommand tableUdfColumn
				sgPuts "tableUdf addColumn"
				while {![tableUdf getNextColumn]} {
					generateCommand tableUdfColumn
					sgPuts "tableUdf addColumn"
				}
				set numRows [tableUdf cget -numRows]
				if {$numRows > 0 } {
					set rowValueList [tableUdf getFirstRow]
					while {[llength $rowValueList]} {
						sgPuts "set rowValueList [list $rowValueList]" 
						sgPuts {tableUdf addRow $rowValueList}
						set rowValueList [tableUdf getNextRow]
					} 
				}
			}
            sgPuts {tableUdf set $chassis $card $port}
		} else {
			# This is needed to clear from the previous	script configuration
			sgPuts
			sgPuts -noFormat "if \{\[port isValidFeature \$chassis \$card \$port \$::portFeatureTableUdf\]\} \{ "
			sgPuts -noFormat "	tableUdf setDefault"
			sgPuts -noFormat "	tableUdf clearColumns"
			sgPuts -noFormat {	tableUdf set $chassis $card $port}
			sgPuts -noFormat "\}"
			sgPuts
		}
	}
	return $retCode		       

}


########################################################################
# Procedure: getSequenceNumberUdfInStream
#
# This command generates commands for udf in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
########################################################################
proc scriptGen::getSequenceNumberUdfInStream { chassis card port } \
{
	set retCode TCL_OK
    if {[port isValidFeature $chassis $card $port $::portFeatureSequenceNumberUdf] } {

		if {[sequenceNumberUdf get $chassis $card $port] } {
			 errorMsg "Error getting sequenceNumberUdf on port $chassis $card $port "
			 set retCode $::TCL_ERROR
		}
        
        if {[sequenceNumberUdf cget -enable] } {
            generateCommand sequenceNumberUdf   
            sgPuts {sequenceNumberUdf set $chassis $card $port}
        }       
	}
	return $retCode		       
    
}


########################################################################
# Procedure: getDhcpInStream
#
# This command generates commands for dhcp in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id

########################################################################

proc scriptGen::getDhcpInStream { chassis card port packet circuitId } \
{
    set retCode 0

    set  isProtocol 1
    if {[llength $packet] != 0 } {
        set isProtocol   [expr ![dhcp  decode $packet $chassis $card $port $circuitId]]
    }

    if [dhcp get $chassis $card $port] {
        errorMsg "Error getting dhcp on $chassis $card $port"
        set retCode 1 
    }
    if {($retCode == 0) && $isProtocol} {
        
        generateCommand dhcp 

		if {![dhcp getFirstOption]} {
			set data [dhcp cget -optionData]
			set optionEnum [getDhcpOptionString [dhcp cget -optionCode]]
			if {[string length $data] > 0 } {
				sgPuts "dhcp config -optionData       {$data}"
				sgPuts "dhcp setOption                $optionEnum"
			} else {
				sgPuts "dhcp setOption                $optionEnum"
			}
							
			while {![dhcp getNextOption]} {
				set data [dhcp cget -optionData]
				set optionEnum [getDhcpOptionString [dhcp cget -optionCode]]
				
				if {[string length $data] > 0 } {
					sgPuts "dhcp config -optionData       {$data}"
					sgPuts "dhcp setOption                $optionEnum"
				} else {
				        if { $optionEnum == "dhcpAgentInformationOption" } {
				            sgPuts "dhcp config -optionData       {00}"
				        } 
					sgPuts "dhcp setOption                $optionEnum"
				}
			}
		}
		sgPuts {dhcp set $chassis $card $port}			
    }
    return $retCode
}

proc scriptGen::getDhcpOptionString { optionValue } \
{
    variable dhcpOptionDataList

	set retString ""
	set index 0

	foreach item $dhcpOptionDataList {
		set value [set ::$item]
		if { $value == $optionValue } {
			set retString [lindex $dhcpOptionDataList $index]
		}
		incr index 
	}
	return $retString
}


########################################################################
# Procedure: getPtpInStream
#
# This command generates commands for Ptp in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getPtpInStream { chassis card port packet } \
{
    set retCode 0

    if {[port isValidFeature $chassis $card $port $::portFeaturePtp]} {

		set  isPtp 1
		if {[llength $packet] != 0 } {
			set isPtp   [expr ![ptp  decode $packet $chassis $card $port]]
		}
		if {[ptp get $chassis $card $port]} {
			errorMsg "Error getting Ptp on $chassis $card $port"
			set retCode 1 
		}
		if {($retCode == 0) && $isPtp} {
        
			switch [ptp cget -messageType] "
				$::ptpSyncMessage { 
					generateCommand  ptpSync 
				} 
				$::ptpDelayRequestMessage {  
					generateCommand ptpDelayRequest 
				} 
				$::ptpFollowUpMessage { 
					generateCommand  ptpFollowUp 
				} 
				$::ptpDelayResponseMessage {  
					generateCommand ptpDelayResponse 
				}
				$::ptpAnnounceMessage {  
					generateCommand ptpAnnounce 
				} 
			"
			sgPuts ""
			generateCommand ptp

			sgPuts {ptp set $chassis $card $port}
		}
	}    

    return $retCode
}

########################################################################
# Procedure: getFcSOFInStream
#
# This command generates commands for Fibre Channel SOF in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getFcSOFInStream { chassis card port packet } \
{
    set retCode 0

    if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {

		set isFcSOF 0
		if {[llength $packet] != 0 && [fcSOF decode $packet $chassis $card $port] == 0} {
			set isFcSOF 1
		}
		if {[fcSOF get $chassis $card $port]} {
			errorMsg "Error getting fcSOF on $chassis $card $port"
			set retCode 1 
		}
		if {($retCode == 0) && $isFcSOF} {
			generateCommand fcSOF

			sgPuts {fcSOF set $chassis $card $port}
		}
	}    

    return $retCode
}


########################################################################
# Procedure: getFcEOFInStream
#
# This command generates commands for Fibre Channel EOF in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getFcEOFInStream { chassis card port packet } \
{
    set retCode 0

    if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {

		set  isFcEOF 0
		if {[llength $packet] != 0 && [fcEOF decode $packet $chassis $card $port] == 0} {
			set isFcEOF 1
		}
		if {[fcEOF get $chassis $card $port]} {
			errorMsg "Error getting fcEOF on $chassis $card $port"
			set retCode 1 
		}
		if {($retCode == 0) && $isFcEOF} {
			generateCommand fcEOF

			sgPuts {fcEOF set $chassis $card $port}
		}
	}    

    return $retCode
}

########################################################################
# Procedure: getBlsInStream
#
# This command generates commands for Basic Link Services in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getBlsInStream { chassis card port packet } \
{
    set retCode 0

    if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {

		set  isBasicLinkServices 0
		if {[llength $packet] != 0 && [basicLinkServices decode $packet $chassis $card $port] == 0} {
			set isBasicLinkServices 1
		}
		if {[basicLinkServices get $chassis $card $port]} {
			errorMsg "Error getting basicLinkServices on $chassis $card $port"
			set retCode 1 
		}
		if {($retCode == 0) && $isBasicLinkServices} {
			generateCommand basicLinkServices

			sgPuts {basicLinkServices set $chassis $card $port}
		}
	}    

    return $retCode
}

########################################################################
# Procedure: getElsInStream
#
# This command generates commands for Fibre Channel Extended Link
# Services in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getElsInStream { chassis card port packet } \
{
    set retCode 0

    if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {

		set  isExtendedLinkServices 0
		if {[llength $packet] != 0 && [extendedLinkServices decode $packet $chassis $card $port] == 0} {
			set isExtendedLinkServices 1
		}
		if {[extendedLinkServices get $chassis $card $port]} {
			errorMsg "Error getting Fibre Channel Extended Link Services on $chassis $card $port"
			set retCode 1 
		}
		if {($retCode == 0) && $isExtendedLinkServices} {
        
			switch [extendedLinkServices cget -protocolType] "
				$::elsLsRjt { 
					generateCommand elsLsRjt 
				} 
				$::elsLsAcc {  
					generateCommand elsLsAcc 
				} 
				$::elsPlogi { 
					generateCommand elsPlogi 
				} 
				$::elsFlogi {  
					generateCommand elsFlogi 
				}
				$::elsLogo {  
					generateCommand elsLogo 
				}
               	$::elsFdisc {  
					generateCommand elsFdisc 
				} 
               	$::elsRscn {  
					generateCommand elsRscn 
				} 
               	$::elsScr {  
					generateCommand elsScr 
				}  
			"
			sgPuts ""
			generateCommand extendedLinkServices

			sgPuts {extendedLinkServices set $chassis $card $port}
		}
	}    

    return $retCode
}

########################################################################
# Procedure: getFcpInStream
#
# This command generates commands for Fibre Channel Protocol in the 
# stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getFcpInStream { chassis card port packet } \
{
    set retCode 0

    if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {

		set  isFcp 0
		if {[llength $packet] != 0 && [fcp decode $packet $chassis $card $port] == 0} {
			set isFcp 1
		}
		if {[fcp get $chassis $card $port]} {
			errorMsg "Error getting Fibre Channel Extended Link Services on $chassis $card $port"
			set retCode 1 
		}
		if {($retCode == 0) && $isFcp} {
        
            if {[fcp cget -selectedIU] == $::fcpCommandStatus} {
                generateCommand fcpSnsInfo
                sgPuts ""
            }


			switch [fcp cget -selectedIU] "
				$::fcpUnsolicitedCommand { 
					generateCommand fcpUnsolicitedCommand 
				} 
				$::fcpCommandStatus {  
					generateCommand fcpCommandStatus 
				} 
				$::fcpDataDescriptor { 
					generateCommand fcpDataDescriptor 
				} 
			"
            sgPuts ""

            if {[fcp cget -selectedIU] == $::fcpUnsolicitedCommand} {
                switch [fcpUnsolicitedCommand cget -cdbType] "
                    $::fcpScsiRead {
                        generateCommand fcpScsiRead
                    }
                    $::fcpScsiWrite {
                        generateCommand fcpScsiWrite
                    }
                    $::fcpScsiInquiry {
                        generateCommand fcpScsiInquiry
                    }                
                "
            }

			sgPuts ""
			generateCommand fcp

			sgPuts {fcp set $chassis $card $port}
		}
	}    

    return $retCode
}


########################################################################
# Procedure: getRipInStream
#
# This command generates commands for Rip and rip routes in the stream
# Arguments(s):
#
# packet  : 
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
# Return value:
#   1 if TCL_ERORR
#   0 if TCL_OK
########################################################################
proc scriptGen::getRipInStream { chassis card port packet circuitId } \
{
    set retCode 0

    set  isRip 1
    if {[llength $packet] != 0 } {
        set isRip   [expr ![rip  decode $packet $chassis $card $port $circuitId]]
    }
    if [rip get $chassis $card $port] {
        errorMsg "Error getting rip on $chassis $card $port"
        set retCode 1 
    }
    if {($retCode == 0) && $isRip} {
        
        generateCommand rip
        for {set routeID 1} {![ripRoute get $routeID]} {incr routeID} {
            generateCommand ripRoute
            sgPuts "ripRoute set $routeID"
        }

		sgPuts {rip set $chassis $card $port}
    }    

    return $retCode
}

########################################################################
# Procedure:    getSrpInStream
#
# Description:  Generate commands for Srp commands in the stream.
#
# Arguments(s): chassis : chassis Id
#               card    : card Id
#               port    : port Id
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getSrpInStream {chassis card port } \
{
    set retCode         $::TCL_OK
    set generateFlag    1

    if {[sonet cget -header] == $::sonetSrp} {
        if {[port isActiveFeature $chassis $card $port $::portFeatureSrpFullFeatured]} {

            switch [protocol cget -appName ] "
                $::SrpDiscovery {
                    set command srpDiscovery
                }                         
               	$::SrpArp {
                    set command srpArp
                }                  
		        $::SrpIps {
                    set command srpIps
                }
                default {
                    set generateFlag    0
                }
             
            "
            if {$generateFlag } {
                if {[$command get $chassis $card $port]} {
                    errorMsg "Error getting $command on $chassis $card $port"
                    set retCode $::TCL_ERROR 
                }
                generateCommand $command
                if {$command == "srpDiscovery" } {
                    getSrpMacBindingList
                }
                sgPuts "$command set [format "$%s $%s $%s" chassis card port]"
            } elseif {[protocol cget -name ] == $::ip ||  [protocol cget -name ] == $::mac} {
                if {[srpHeader get $chassis $card $port]} {
                    errorMsg "Error getting srpHeader on $chassis $card $port"
                    set retCode $::TCL_ERROR 
                }
                generateCommand srpHeader
                sgPuts {srpHeader set $chassis $card $port}
            }
        }
    }

    return $retCode
}                


########################################################################
# Procedure:    getSrpMacBindingList
#
# Description:  Generate commands for srpMacBinding in the stream.
#
# Arguments(s): chassis : chassis Id
#               card    : card Id
#               port    : port Id
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getSrpMacBindingList {} \
{
    set retCode $::TCL_OK

    sgPuts "srpDiscovery clearAllMacBindings"
        
    if {![srpDiscovery getFirstMacBinding]} {

        generateCommand srpMacBinding
        sgPuts "srpDiscovery addMacBinding"

        while {![srpDiscovery getNextMacBinding]} {
            generateCommand srpMacBinding
            sgPuts "srpDiscovery addMacBinding"
        }
    }
    return $retCode
}


        
########################################################################
# Procedure: getAtmStreamQueueScript
#
# This command generates commands for stream queues
# Arguments(s):
#
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
########################################################################
proc scriptGen::getAtmStreamQueueScript { chassis card port } \
{    
	set retCode $::TCL_OK

    if [streamQueueList select $chassis $card $port] {
        errorMsg "Error selecting port for streamQueueList..."
        set retCode $::TCL_ERROR
        return $retCode
    }
    set queueId 1

    sgPuts {streamQueueList select $chassis $card $port}
	sgPuts {streamQueueList clear}

	if {[streamQueue get $chassis $card $port $queueId] } {
		return $retCode
	} 

    sgPuts "set                          queueId          1"

    while {[streamQueue get $chassis $card $port $queueId] == $::TCL_OK} {
        sgPuts "############  Queue $queueId ############"
        sgPuts "streamQueueList add"

        generateCommand streamQueue
        sgPuts {streamQueue set $chassis $card $port $queueId}
        
        set streamId 1

		if { [stream getQueue $chassis $card $port $queueId $streamId] } {
			sgPuts {streamQueue clear $chassis $card $port $queueId}
			incr queueId
			sgPuts "incr queueId"
			continue
		}	

        while {[stream getQueue $chassis $card $port $queueId $streamId] == $::TCL_OK} {
            sgPuts "############  Stream $streamId ############"
            sgPuts "set                          streamId          $streamId"
            if {[port isActiveFeature $chassis $card $port $::portFeature10GigWan] || \
                [port isActiveFeature $chassis $card $port $::portFeature10GigLan] ||
                [port isActiveFeature $chassis $card $port $::portFeaturePos] } {
                stream config -rateMode usePercentRate
            }

			generateCommonStreamConfig $chassis $card $port $streamId $queueId 

            if {[atmHeader get $chassis $card $port]} {
                errorMsg "Error getting atmHeader for port $chassis $card $port"
                set retCode $::TCL_ERROR
                return $retCode
            }
            if {[getVpiVci]} {
                errorMsg "Error getting Vpi/Vci"
                set retCode $::TCL_ERROR
                return $retCode
            }

            generateCommand atmHeader
            sgPuts {atmHeader set $chassis $card $port}
                  
            sgPuts {stream setQueue $chassis $card $port $queueId $streamId} 
            
            getInstrumentation  $chassis $card $port $streamId $queueId
			  
            sgPuts "incr streamId"                                    
            incr streamId
        }
		sgPuts "incr queueId"
        incr queueId
        set  streamId 1
        sgPuts "set                          streamId          1"
    }
    
    return $retCode
}



########################################################################
# Procedure: getVpiVci
#
# This command generates commands atmHeaderCounter for vpi and vci
# Arguments(s):
#
#
########################################################################
proc scriptGen::getVpiVci { } \
{    
	set retCode $::TCL_OK

    if {[atmHeaderCounter get atmVpi]} {
        errorMsg "Error getting atmHeaderCounter for atmVpi"
        set retCode $::TCL_ERROR
    } else {
        generateCommand atmHeaderCounter
        sgPuts "atmHeaderCounter set atmVpi"
    }

    if {[atmHeaderCounter get atmVci]} {
        errorMsg "Error getting atmHeaderCounter for atmVci"
        set retCode $::TCL_ERROR
    } else {
        generateCommand atmHeaderCounter
        sgPuts "atmHeaderCounter set atmVci"
    }

    return $retCode
}

########################################################################
# Procedure:    getIpV6NextHeader
#
# Description:  Generate commands for each Tlv in the rpr topology.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getIpV6NextHeader { } \
{

    set ipV6NextHeader  [ipV6 cget -nextHeader]

    if { ($ipV6NextHeader != $::ipV4ProtocolTcp) && ($ipV6NextHeader != $::ipV4ProtocolUdp) && \
		 ($ipV6NextHeader != $::ipV4ProtocolIpv6Icmp) && ($ipV6NextHeader != $::ipV4ProtocolGre) && \
         ($ipV6NextHeader != $::ipV6HopByHopOptions) && ( $ipV6NextHeader != $::ipV6EncapsulatingSecurityPayload) } {

        set extHeaderObject [ipV6 getFirstExtensionHeader]
        set lastExtHeaderObject  $extHeaderObject

	    if {$extHeaderObject != "NULL" } {

            set ipV6NextHeader  [$extHeaderObject cget -nextHeader]
            set lastExtHeaderObject  $extHeaderObject
		    set extHeaderObject [ipV6 getNextExtensionHeader]
            while {$extHeaderObject != "NULL"} {
                set ipV6NextHeader  [$extHeaderObject cget -nextHeader]
                set lastExtHeaderObject  $extHeaderObject
			    set extHeaderObject [ipV6 getNextExtensionHeader]
            }
        }

	    if {$lastExtHeaderObject != "NULL" } {
            set ipV6NextHeader  [$lastExtHeaderObject cget -nextHeader]
        }
    } 
          
    return $ipV6NextHeader
}

########################################################################
# Procedure:    getIpV6ExtensionHeaders
#
# Description:  Generate commands for each Tlv in the rpr topology.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getIpV6ExtensionHeaders { } \
{
    sgPuts "ipV6 clearAllExtensionHeaders"

    set ipV6NextHeader  [ipV6 cget -nextHeader]


    if { ($ipV6NextHeader != $::ipV4ProtocolTcp) && ($ipV6NextHeader != $::ipV4ProtocolUdp) && \
		 ($ipV6NextHeader != $::ipV4ProtocolIpv4) && \
		 ($ipV6NextHeader != $::ipV4ProtocolIpv6Icmp) && ($ipV6NextHeader != $::ipV4ProtocolGre) && \
         ($ipV6NextHeader != $::ipV6EncapsulatingSecurityPayload) } {

        set extHeaderObject [ipV6 getFirstExtensionHeader]
        set lastExtHeaderObject  $extHeaderObject

	    if {$extHeaderObject != "NULL" } {
		    generateExtensionHeader $ipV6NextHeader

            set ipV6NextHeader  [$extHeaderObject cget -nextHeader]
            set lastExtHeaderObject  $extHeaderObject
		    set extHeaderObject [ipV6 getNextExtensionHeader]

            while {$extHeaderObject != "NULL"} {
		        generateExtensionHeader $ipV6NextHeader
                set ipV6NextHeader  [$extHeaderObject cget -nextHeader]
                set lastExtHeaderObject  $extHeaderObject
			    set extHeaderObject [ipV6 getNextExtensionHeader]
            }
        }

	    if {$lastExtHeaderObject != "NULL" } {
            set ipV6NextHeader  [$lastExtHeaderObject cget -nextHeader]
            generateExtensionHeader $ipV6NextHeader
        }
    } else {
        generateExtensionHeader $ipV6NextHeader
    }
          
    return $ipV6NextHeader
}


########################################################################
# Procedure: generateExtensionHeader
#
# This command gets Tlvs for the RPR Topology
# Arguments(s):
#
# tlvObject: pointer to Tlv object.
#
# Returned Result:
########################################################################      
proc scriptGen::generateExtensionHeader {ipV6ExtHeaderType} \
{  
    set retCode 0
    
	set generateCmdFlag 1

    set headerType "ipV6Routing"

    switch $ipV6ExtHeaderType "
        $::ipV6Routing { 
            generateCommand  ipV6Routing 
			set headerType ipV6Routing 
        } 
        $::ipV6Fragment {  
            generateCommand ipV6Fragment 
			set headerType ipV6Fragment 
        } 
        $::ipV6Authentication { 
            generateCommand ipV6Authentication 
			set headerType ipV6Authentication 
        } 
        $::ipV6DestinationOptions { 
			set headerType ipV6DestinationOptions 
			generateIpV6Options	ipV6Destination
        }
        $::ipV6HopByHopOptions {
            set headerType ipV6HopByHopOptions 
            generateIpV6Options ipV6HopByHop
        }
        $::ipV6EncapsulatingSecurityPayload {
	        set generateCmdFlag 0
            set headerType ipV6EncapsulatingSecurityPayload 
            sgPuts \"#****** WARNING: Currently no IxTclHal support for ipV6EncapsulatingSecurityPayload.\" 
        }
        $::ipV4ProtocolTcp {
            set headerType ipV4ProtocolTcp 
        }
        $::ipV4ProtocolUdp {
            set headerType ipV4ProtocolUdp
        }
        $::ipV4ProtocolGre {
            set headerType ipV4ProtocolGre 
        }
        $::ipV4ProtocolIpv4 {
            set headerType ipV4ProtocolIpv4 
        }
        $::ipV4ProtocolIpv6Icmp {
            set headerType ipV4ProtocolIpv6Icmp 
        }
		$::ipV6NoNextHeader {
			set generateCmdFlag 0
		}         
    " 
   
    if { $generateCmdFlag } {
		sgPuts ""
        sgPuts "ipV6 addExtensionHeader $headerType " 
    }
    
    return $retCode
}

########################################################################
# Procedure:    generateIpV6Options
#
# Description:  Generate commands for IpV6 HopByHop Options.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::generateIpV6Options { cmd } \
{
    set retCode $::TCL_OK

	sgPuts ""
    sgPuts "$cmd clearAllOptions"

    set optionObject [$cmd getFirstOption]


	if {$optionObject != "NULL" } {
        set optionType [$optionObject cget -optionType]
		generateOptions $optionType	$cmd
		set optionObject [$cmd getNextOption]

        while {$optionObject != "NULL"} {
            set optionType [$optionObject cget -optionType]
            generateOptions  $optionType $cmd
			set optionObject [$cmd getNextOption]
        }
    }
            
    return $retCode
}

########################################################################
# Procedure: generateOptions
#
# This command generates IpV6 HopByHop Options
# Arguments(s):
#
#   type    - the option type to be generated
#
# Returned Result:
########################################################################      
proc scriptGen::generateOptions {type cmd } \
{  
    variable enumsArray

    set retCode 0

	# All the options have the same list values
	foreach optionItem $enumsArray(ipV6OptionPAD1,optionType) {
		set value	[lindex $optionItem 1]
		set name	[lindex $optionItem 0]
		if {$value == $type } {
			break
		}
	} 
  
	if { $type == $::ipV6OptionPAD1} {
		generateCommand $name no
	} else {
		generateCommand $name
	}

    sgPuts "$cmd addOption $name"
    sgPuts ""
    
    return $retCode
}

########################################################################
# Procedure:    getIcmpV6InStream
#
# Description:  Generate commands for ICMPV6 messages and options.
#
########################################################################
proc scriptGen::getIcmpV6InStream { chassis card port } \
{
	variable enumsArray 

	set messageTypeName($::icmpV6DestUnreachableMessage) icmpV6DestUnreachableMessage
	set messageTypeName($::icmpV6PacketTooBigMessage) icmpV6PacketTooBigMessage
	set messageTypeName($::icmpV6TimeExceededMessage) icmpV6TimeExceededMessage
	set messageTypeName($::icmpV6ParameterProblemMessage) icmpV6ParameterProblemMessage
	set messageTypeName($::icmpV6EchoRequestMessage) icmpV6EchoRequestMessage
	set messageTypeName($::icmpV6EchoReplyMessage) icmpV6EchoReplyMessage
	set messageTypeName($::icmpV6MulticastListenerQueryMessage) icmpV6MulticastListenerQueryMessage
	set messageTypeName($::icmpV6MulticastListenerReportMessage) icmpV6MulticastListenerReportMessage
	set messageTypeName($::icmpV6MulticastListenerDoneMessage) icmpV6MulticastListenerDoneMessage
	set messageTypeName($::icmpV6RouterSolicitationMessage) icmpV6RouterSolicitationMessage
	set messageTypeName($::icmpV6RouterAdvertisementMessage) icmpV6RouterAdvertisementMessage
	set messageTypeName($::icmpV6NeighborSolicitationMessage) icmpV6NeighborSolicitationMessage
	set messageTypeName($::icmpV6NeighborAdvertisementMessage) icmpV6NeighborAdvertisementMessage
	set messageTypeName($::icmpV6RedirectMessage) icmpV6RedirectMessage

    set messageType  [icmpV6 cget -type]
 
	if  {[info exists messageTypeName($messageType)] } {
		sgPuts "icmpV6 setType $messageTypeName($messageType) " 
	} else {
		sgPuts "icmpV6 setType $messageType" 
	}
	
    sgPuts "" 

	set flagDefaultSpecial 0
	set cmd icmpV6Error
	set enumList [list icmpV6NoRouteToDestination icmpV6CommunicationProhibted icmpV6NotAssigned icmpV6AddressUnreachable icmpV6PortUnreachable icmpV6SourceAddressFailed icmpV6RejectRouteDestination ]
	
	switch $messageType \
		$::icmpV6TimeExceededMessage { 
			set enumList [list icmpV6HopLimitExceeded icmpV6FragmentReassemblyTimeExceeded ]
        	set flagDefaultSpecial 1
        	set cmd icmpV6Error
        }\
		$::icmpV6ParameterProblemMessage {
			set enumList [list icmpV6ErroneousHeaderFieldDetected icmpV6UnrecognizedNextheaderType icmpV6UnrecognizedIpV6Option]
        	set flagDefaultSpecial 1
        	set cmd icmpV6Error
        }\
        $::icmpV6DestUnreachableMessage -\
        $::icmpV6PacketTooBigMessage {
			# uses the default enumList
			
         	set flagDefaultSpecial 1
        	set cmd icmpV6Error
		}\
  		$::icmpV6RouterSolicitationMessage -\
		$::icmpV6RouterAdvertisementMessage -\
		$::icmpV6NeighborSolicitationMessage -\
		$::icmpV6NeighborAdvertisementMessage -\
		$::icmpV6RedirectMessage {
			set flagDefaultSpecial 1
			set cmd icmpV6NeighborDiscovery
        } 
 
	setEnumValList $enumList enumValList
	set enumsArray(icmpV6Error,code)  $enumValList
	
	# The below if condition is creating the default value array for icmpV6Error and icmpV6NeighborDiscovery messages
	# because the available parameter list will change based on the message type
    if { $flagDefaultSpecial } {
		set defaultValueArray [format "%sDefaultValueArray" $cmd]
		variable $defaultValueArray		
		catch { unset ::scriptGen::$defaultValueArray}
		icmpV6 setType $messageType
		getParmValueArray $cmd ::scriptGen::$defaultValueArray

		# Refresh the actual icmpV6Error and icmpV6NeighborDiscovery message parameter values
		# after building the default value array
		icmpV6 get $chassis $card $port
	}

    switch $messageType "
		$::icmpV6DestUnreachableMessage -
		$::icmpV6PacketTooBigMessage -
		$::icmpV6TimeExceededMessage	-
        $::icmpV6ParameterProblemMessage { 
            generateCommand  icmpV6Error 
        }
  		$::icmpV6EchoRequestMessage	-
        $::icmpV6EchoReplyMessage { 
            generateCommand  icmpV6Informational 
        }
   		$::icmpV6MulticastListenerQueryMessage -
		$::icmpV6MulticastListenerReportMessage	-
        $::icmpV6MulticastListenerDoneMessage { 
            generateCommand  icmpV6MulticastListener 
        }  
        $::icmpV6RouterSolicitationMessage -
		$::icmpV6RouterAdvertisementMessage	-
 		$::icmpV6NeighborSolicitationMessage	-
		$::icmpV6NeighborAdvertisementMessage	-
		$::icmpV6RedirectMessage {
			getIcmpV6NeighborDiscoveryAndOptions
        }
        default {
            generateCommand  icmpV6UserDefine 
		}
    " 
}


########################################################################
# Procedure:    getIcmpV6NeighborDiscoveryAndOptions
#
# Description:  Generate commands for all options for the icmpV6 message 
#				types.
#
########################################################################
proc scriptGen::getIcmpV6NeighborDiscoveryAndOptions { } \
{
    sgPuts "icmpV6NeighborDiscovery clearAllOptions"
	generateCommand  icmpV6NeighborDiscovery
    sgPuts "" 

	set messageTypeName($::icmpV6OptionLinkLayerSource) icmpV6OptionLinkLayerSource
	set messageTypeName($::icmpV6OptionLinkLayerDestination) icmpV6OptionLinkLayerDestination
	set messageTypeName($::icmpV6OptionPrefixInformation) icmpV6OptionPrefixInformation
	set messageTypeName($::icmpV6OptionRedirectedHeader) icmpV6OptionRedirectedHeader
	set messageTypeName($::icmpV6OptionMaxTransmissionUnit) icmpV6OptionMaxTransmissionUnit
	
    set optionObject [icmpV6NeighborDiscovery getFirstOption]

	if {$optionObject != "NULL" } {	
		generateCommand $optionObject
		set optionType [$optionObject cget -type]
		if {[info exists messageTypeName($optionType)]} {
			sgPuts "icmpV6NeighborDiscovery addOption $messageTypeName($optionType)" 
		} else {
			sgPuts "icmpV6NeighborDiscovery addOption $optionType"
		}
		 
		set optionObject [icmpV6NeighborDiscovery getNextOption]
		
        while {$optionObject != "NULL"} {
			sgPuts "" 
			generateCommand $optionObject
			set optionType [$optionObject cget -type]
			if {[info exists messageTypeName($optionType)]} {
				sgPuts "icmpV6NeighborDiscovery addOption $messageTypeName($optionType)" 
			} else {
				sgPuts "icmpV6NeighborDiscovery addOption $optionType"
			} 
 			set optionObject [icmpV6NeighborDiscovery getNextOption]
       }
    }   
}


########################################################################
# Procedure:    getRprInStream
#
# Description:  Generate commands for Srp commands in the stream.
#
# Arguments(s): packet  :
#                   chassis : chassis Id
#                   card    : card Id
#                   port    : port Id
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getRprInStream {chassis card port } \
{
    set retCode         $::TCL_OK
    set generateFlag    1

    if {[sonet cget -header] == $::sonetRpr} {
        if {[port isActiveFeature $chassis $card $port $::portFeatureRpr]} {

            if {[rprRingControl get $chassis $card $port]} {
                errorMsg "Error getting rprRingControl on $chassis $card $port"
                set retCode $::TCL_ERROR 
            }

            generateCommand rprRingControl
            sgPuts {rprRingControl set $chassis $card $port}

            switch [protocol cget -appName ] "
                $::RprTopology {
                    set command rprTopology
                }                         
		        $::RprProtection {
                    set command rprProtection
                }
                $::RprOam {
                    set command rprOam
                }
                default {
                    set generateFlag    0
                }
             
            "

            if {$generateFlag } {
                if {[$command get $chassis $card $port]} {
                    errorMsg "Error getting $command on $chassis $card $port"
                    set retCode $::TCL_ERROR 
                }
                if {$command == "rprTopology" } {
                    sgPuts "rprTopology clearAllTlvs" 
                    getTlvs
                }
                generateCommand $command
                sgPuts "$command set [format "$%s $%s $%s" chassis card port]"

            }
        }
    }

    return $retCode
}   
                 
########################################################################
# Procedure:    getTlvs
#
# Description:  Generate commands for each Tlv in the rpr topology.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getTlvs { } \
{
    set retCode $::TCL_OK

    set tlvObject [rprTopology getFirstTlv]

	if {$tlvObject != "NULL" } {
        set tlvType [$tlvObject cget -type]
		generateTlv $tlvType

		set tlvObject [rprTopology getNextTlv]
        while {$tlvObject != "NULL"} {
            set tlvType [$tlvObject cget -type]
		    generateTlv $tlvType
			set tlvObject [rprTopology getNextTlv]
        }
    }
            
    return $retCode
}


########################################################################
# Procedure: generateTlv
#
# This command gets Tlvs for the RPR Topology
# Arguments(s):
#
# tlvObject: pointer to Tlv object.
#
# Returned Result:
########################################################################      
proc scriptGen::generateTlv {type} \
{  
    set retCode 0
    
	set tlvType "rprTlvWeight"

    switch $type "
        $::rprWeight {
            generateCommand  rprTlvWeight
			set tlvType rprWeight
        } 
        $::rprTotalBandwidth {
            generateCommand rprTlvTotalBandwidth
			set tlvType rprTotalBandwidth
        }
        $::rprStationName {
            generateCommand rprTlvStationName
			set tlvType rprStationName
        } 
        $::rprNeighborAddress {
            generateCommand rprTlvNeighborAddress
			set tlvType rprNeighborAddress
        } 
        $::rprIndividualBandwidth { 
            getTlvBandwidthPairs
            generateCommand rprTlvIndividualBandwidth
			set tlvType rprIndividualBandwidth
        }
		$::rprVendorSpecific { 
            generateCommand rprTlvVendorSpecific 
			set tlvType rprVendorSpecific
        } 
    "
    sgPuts "rprTopology addTlv $tlvType" 
	
	sgPuts "" 
    
    return $retCode
}


########################################################################
# Procedure:    getTlvBandwidthPairs
#
# Description:  Generate commands for srpMacBinding in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getTlvBandwidthPairs {} \
{
    set retCode $::TCL_OK

    sgPuts "rprTlvIndividualBandwidth clearAllBandwidthPairs"
        
    if {![rprTlvIndividualBandwidth getFirstBandwidthPair]} {

        generateCommand rprTlvBandwidthPair
        sgPuts "rprTlvIndividualBandwidth addBandwidthPair"

        while {![rprTlvIndividualBandwidth getNextBandwidthPair]} {
            generateCommand rprTlvBandwidthPair
            sgPuts "rprTlvIndividualBandwidth addBandwidthPair"
        }
    } 

    return $retCode
}


########################################################################
# Procedure:    getIgmpV3GroupRecords
#
# Description:  Generate commands for IgmpV3GroupRecords in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getIgmpV3GroupRecords {} \
{
    set retCode $::TCL_OK

	if {([igmp cget -version] == $::igmpVersion3) && ([igmp cget -type] == $::membershipReport3 ) } {
		if {![igmp getFirstGroupRecord]} {
			sgPuts "igmp clearGroupRecords"
			generateCommand igmpGroupRecord
			sgPuts "igmp addGroupRecord"

			while {![igmp getNextGroupRecord]} {
				generateCommand igmpGroupRecord
				sgPuts "igmp addGroupRecord"
			}
		}
	} 

    return $retCode
}

########################################################################
# Procedure:    getVlanInStream
#
# Description:  Generate commands for vlan or stacked vlan in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getVlanInStream { chassis card port } \
{
    variable generatePacketView

    set retCode $::TCL_OK

    set packet [list]
    if { $generatePacketView } {
        set packet  [stream cget -packetView]
    }
	sgPuts "" 

    if { [protocol cget -enable802dot1qTag] == $::vlanSingle } {
        getProtocolInStream vlan $chassis $card $port $packet

    } elseif {[protocol cget -enable802dot1qTag] == $::vlanStacked } {
		if {[port isValidFeature $chassis $card $port $::portFeatureStackedVlan]} {

			getProtocolInStream stackedVlan $chassis $card $port $packet 0 no

			set vlanPos 1
			sgPuts "set vlanPosition $vlanPos"
			if {![stackedVlan get $chassis $card $port] } {
				if {![stackedVlan getFirstVlan] } {
					generateCommand vlan
					sgPuts {stackedVlan setVlan $vlanPosition}
					sgPuts "" 
					sgPuts {incr vlanPosition}
				
					if {![stackedVlan getNextVlan] } {

						generateCommand vlan
						sgPuts {stackedVlan setVlan $vlanPosition}
						while {![stackedVlan getNextVlan] } {
							sgPuts ""
							generateCommand vlan
							sgPuts {stackedVlan addVlan}
						}

					}
				}
			}
		}
		sgPuts {stackedVlan set $chassis $card $port}
		sgPuts ""
	}
        

    return $retCode
}


########################################################################
# Procedure:    getMacSecInStream
#
# Description:  Generate commands for macSec in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getMacSecInStream { chassis card port } \
{
    variable generatePacketView

    set retCode $::TCL_OK

	if {[port isActiveFeature $chassis $card $port $::portFeatureMACSec]} {

		set packet [list]
		if { $generatePacketView } {
			set packet  [stream cget -packetView]
		}
		sgPuts "" 

		if { [protocol cget -enableMacSec]} {
			getProtocolInStream macSecTag $chassis $card $port $packet

		}
	}
	 
    return $retCode
}

########################################################################
# Procedure:    getProtocolPadInStream
#
# Description:  Generate commands for protcolPad in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getProtocolPadInStream { chassis card port } \
{
    variable generatePacketView

    set retCode $::TCL_OK

	if {![port isActiveFeature $chassis $card $port $::portFeatureFCPhy]} {

		set packet [list]
		if { $generatePacketView } {
			set packet  [stream cget -packetView]
		}
		sgPuts "" 

		if { [protocol cget -enableProtocolPad]} {
			getProtocolInStream protocolPad $chassis $card $port $packet

		}
	}
	 
    return $retCode
}

########################################################################
# Procedure:    getCmdInStream
#
# Description:  Generate commands for macSec in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getCmdInStream { chassis card port } \
{
    variable generatePacketView

    set retCode $::TCL_OK

	if {[port isValidFeature $chassis $card $port $::portFeatureCiscoMetaDataTag]} {

		set packet [list]
		if { $generatePacketView } {
			set packet  [stream cget -packetView]
		}

		if {[protocol cget -enableCMD]} {

			getProtocolInStream ciscoMetaData $chassis $card $port $packet 0 no

			sgPuts {ciscoMetaData clearAllOptions}
			sgPuts "" 

			if {![ciscoMetaData getFirstOption] } {
				ciscoMetaDataOption  

				while {![ciscoMetaData getNextOption] } {
					ciscoMetaDataOption 
				}
			}
	        sgPuts "ciscoMetaData set [format "$%s $%s $%s" chassis card port]"
		}
	}
	 
    return $retCode
}



########################################################################
# Procedure:    ciscoMetaDataOption
#
# Description:  Generate commands for ciscoMetaData Options in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::ciscoMetaDataOption {  } \
{
    set retCode $::TCL_OK

	set type [ciscoMetaData cget -currentOptionType]
	set cmdType ""
	set typeString ""

	switch $type "
		$::cmdSourceGroupTag {
			set typeString cmdSourceGroupTag
			set cmdType ciscoMetaDataSourceGroupTag
		}
		$::cmdCustomOption {
			set typeString cmdCustomOption
			set cmdType ciscoMetaDataCustomOption
		}
	"				

	if { $cmdType != "" } {
		generateCommand $cmdType
		sgPuts "ciscoMetaData addOption $typeString" 	
		sgPuts ""
	} else {
		set retCode $::TCL_ERROR
	}

    return $retCode
}

########################################################################
# Procedure:    getOamInStream
#
# Description:  Generate commands for OAM in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getOamInStream { chassis card port } \
{
    variable generatePacketView

    set retCode $::TCL_OK

	if {[port isValidFeature $chassis $card $port $::portFeatureEthernetOAM]} {

		if { [protocol cget -enableOAM]} {

			set packet [list]
			if { $generatePacketView } {
				set packet  [stream cget -packetView]
			}
			sgPuts "" 

			# We have to generate information for all the PDUs regardless of the
			# oamHeader mode, so that user can ge all the preserved information
			# as they can see in the gui while switching from one mode to another

			getProtocolInStream oamHeader $chassis $card $port $packet 0 no
			sgPuts "" 

			set oamPduWithTlvList [list oamInformation oamEventNotification oamVariableRequest oamVariableResponse ]

			foreach pduCmd $oamPduWithTlvList {

				catch { $pduCmd dummy } temp
				if {[string first "setDefault" $temp] != -1 } {
					sgPuts "$pduCmd setDefault"
				}
				sgPuts "$pduCmd clearAllTlvs"
				generateCommand $pduCmd no
				sgPuts "" 

				if {![$pduCmd getFirstTlv] } {
					getOamTlvsPerPdu $pduCmd 

					while {![$pduCmd getNextTlv] } {
						getOamTlvsPerPdu $pduCmd 
					}
				}
			}
								  
			generateCommand oamLoopbackControl
			sgPuts ""
			generateCommand oamOrganizationSpecific

			sgPuts {oamHeader set $chassis $card $port}
			sgPuts ""
		}
	}
	 
    return $retCode
}


########################################################################
# Procedure:    getOamTlvsPerPdu
#
# Description:  Generate commands for OAM in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getOamTlvsPerPdu { pduCmd } \
{
    set retCode $::TCL_OK

	set type [$pduCmd cget -currentTlvType]
	set tlvType ""

	switch $pduCmd {
		"oamInformation" {
			switch $type "
				$::oamInformationEndOfTlv {
					set tlvType oamInformationEndOfTlv
				}
				$::oamInformationLocalInfo {
					generateCommand  oamLocalInformationTlv
					set tlvType oamInformationLocalInfo
				}
				$::oamInformationRemoteInfo {
					generateCommand  oamRemoteInformationTlv
					set tlvType oamInformationRemoteInfo
				}  
				$::oamInformationOrgInfo {
					generateCommand  oamOrganizationSpecificTlv
					set tlvType oamInformationOrgInfo
				}  				
			"  		
		}

		"oamEventNotification" {
			switch $type "
				$::oamEventNotificationEndOfTlv {
					set tlvType oamEventNotificationEndOfTlv
				}
				$::oamEventNotificationSymbol {
					generateCommand  oamSymbolPeriodTlv
					set tlvType oamEventNotificationSymbol
				}
				$::oamEventNotificationFrame {
					generateCommand  oamFrameTlv
					set tlvType oamEventNotificationFrame
				}  
				$::oamEventNotificationFramePeriod {
					generateCommand  oamFramePeriodTlv
					set tlvType oamEventNotificationFramePeriod
				}
				$::oamEventNotificationSummary {
					generateCommand  oamSummaryTlv
					set tlvType oamEventNotificationSummary
				}
				$::oamEventNotificationOrgSpecific {
					generateCommand  oamEventOrgTlv
					set tlvType oamEventNotificationOrgSpecific
				}  				
			"
		}
		"oamVariableRequest" {
			switch $type "
				$::oamVariableRequestEndOfTlv {
					set tlvType oamVariableRequestEndOfTlv
				}
				$::oamVariableRequest {
					generateCommand  oamVariableRequestTlv
					set tlvType oamVariableRequest
				}			
			"
		}
		"oamVariableResponse" {
			switch $type "
				$::oamVariableResponseEndOfTlv {
					set tlvType oamVariableResponseEndOfTlv
				}
				$::oamVariableResponse {
					generateCommand  oamVariableResponseTlv
					set tlvType oamVariableResponse
				}			
			"
		} 
	} 
	if { $tlvType != "" } {

		sgPuts "$pduCmd addTlv $tlvType" 	
		sgPuts ""
	} else {
		set retCode $::TCL_ERROR
	}

    return $retCode
}


########################################################################
# Procedure:    getMplsInStream
#
# Description:  Generate commands for mpls in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getMplsInStream { chassis card port } \
{
    set retCode $::TCL_OK

    if { [protocol cget -enableMPLS] } {
        getCommand mpls  $chassis $card $port  
        set labelNo 1
        while { [mplsLabel get $labelNo] == 0 } { 
            generateCommand mplsLabel 
            sgPuts "mplsLabel set $labelNo" 
            incr labelNo
        }
        sgPuts {mpls set $chassis $card $port}  
    }

    return $retCode
}

########################################################################
# Procedure:    getDataCenterEncapsulationInStream
#
# Description:  Generate commands for DataCenterEncapsulation in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getDataCenterEncapsulationInStream { chassis card port } \
{
    set retCode $::TCL_OK

    if { [protocol cget -enableDataCenterEncapsulation] } {
		set dataCenterEncapsulationMainList			[list ethertypeDTag fTag ttl embeddedDa embeddedSa embeddedDaAddrMode \
		                                                  embeddedDaAddrChangeBy embeddedSaAddrMode embeddedSaAddrChangeBy]
		set dataCenterEncapsulationAddresBitList	[list localId switchId subSwitchId oooDl reserved iG uL endNodeId]
      if {![dataCenterEncapsulation get $chassis $card $port] } {
            partiallyGenerateCommand dataCenterEncapsulation $dataCenterEncapsulationMainList
            sgPuts ""
			dataCenterEncapsulation getDa
            partiallyGenerateCommand dataCenterEncapsulation $dataCenterEncapsulationAddresBitList no
			sgPuts "dataCenterEncapsulation setDa"
			dataCenterEncapsulation getSa
            partiallyGenerateCommand dataCenterEncapsulation $dataCenterEncapsulationAddresBitList no
			sgPuts "dataCenterEncapsulation setSa"        
			sgPuts {dataCenterEncapsulation set $chassis $card $port} 
		} 
    }

    return $retCode
}

########################################################################
# Procedure:    getIslInStream
#
# Description:  Generate commands for isl in the stream.
#
# Arguments(s): 
#
# Returns:      TCL_ERROR or TCL_OK
#
########################################################################
proc scriptGen::getIslInStream { chassis card port } \
{
    set retCode $::TCL_OK

    if { [protocol cget -enableISLtag] } {
        getCommand isl  $chassis $card $port
        sgPuts {isl set $chassis $card $port}
    } 

    return $retCode
}

########################################################################
# Procedure: getCircuitStreams
#
# This command gets and generates commands for stream for circuit
# Arguments(s):
#
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
########################################################################
proc scriptGen::getCircuitStreams { chassis card port} \
{
    set retCode $::TCL_OK

	if {![sonetCircuitList select $chassis $card $port]} {

		if {![sonetCircuitList getFirst] } {

			set circuitId [sonetCircuit cget -index]
			if {[generateCircuitStreams $chassis $card $port $circuitId]} { 
				errorMsg "Error generateCircuitStreams for $chassis $card $port on circuit $circuitId..."
				set retCode $::TCL_ERROR
			}
			while {![sonetCircuitList getNext] } {

				set circuitId [sonetCircuit cget -index]
				if {[generateCircuitStreams $chassis $card $port $circuitId]} { 
					errorMsg "Error generateCircuitStreams for $chassis $card $port on circuit $circuitId..."
					set retCode $::TCL_ERROR
				} 
			}
		}
	
	} else {
		errorMsg "Error selecting sonetCircuitList on $chassis $card $port"
		set retCode $::TCL_ERROR
	}

    return $retCode
}

########################################################################
# Procedure: generateCircuitStreams
#
# This command generates commands for stream for circuit
# Arguments(s):
#
# chassis : chassis Id
# card    : card Id
# port    : port Id
#
########################################################################
proc scriptGen::generateCircuitStreams { chassis card port circuitId } \
{
    set retCode $::TCL_OK

	sgPuts ""
	sgPuts "##### Circuit $circuitId"
	sgPuts "set circuitId $circuitId"
	sgPuts ""

	for {set streamId 1} {[stream getCircuit $chassis $card $port $circuitId $streamId ] != 1} {incr streamId} {
		sgPuts "#  Circuit $circuitId - Stream $streamId"
		sgPuts ""
		sgPuts "set streamId  $streamId"

		# This get is needed for the sonetCircuitProperties payload information
		if {[sonetCircuitProperties get $chassis $card $port $circuitId]} { 
			errorMsg "Error getting sonetCircuitProperties for $chassis $card $port on circuit $circuitId..."
			set retCode $::TCL_ERROR
		}

		generateCommonStreamConfig $chassis $card $port $streamId $circuitId

		if { [port isActiveFeature $chassis $card $port $::portFeatureCiscoCDL] } {
			if {[cdlPreamble get $chassis $card $port] == $::TCL_OK} {
            	generateCommand cdlPreamble
              	sgPuts {cdlPreamble set $chassis $card $port}
			} else {
				 errorMsg "Error getting cdlPreamble $chassis $card $port"
				 set retCode $::TCL_ERROR
			}                    
		}

		sgPuts {stream setCircuit $chassis $card $port $circuitId $streamId}
		sgPuts ""
		getInstrumentation  $chassis $card $port $streamId $circuitId
		sgPuts ""
		sgPuts "incr streamId"                            
	}
	sgPuts ""                 
	      
	return $retCode
}        
         

########################################################################
# Procedure: isVcatProtocol
#
# This command will return true for the command that require circuitId
# in their set commands
#
# Arguments(s):
# cmd       : command
#
# Returned Result: 1/0
########################################################################
proc scriptGen::isVcatProtocol {cmd } \
{
	set vcatProtocols	[list ppp frameRelay gfp hdlc ] 

	set isValid	$::false

	if {[lsearch $vcatProtocols $cmd] >= 0 } {
		set isValid	$::true
	}

    return $isValid
} 

