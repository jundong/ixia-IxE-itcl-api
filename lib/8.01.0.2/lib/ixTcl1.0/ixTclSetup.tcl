##################################################################################
#   Version 8.01
#   
#   File: ixTclSetup.tcl
#
#   Copyright ©  IXIA
#   All Rights Reserved.
#
#	Revision Log:
#	10-29-2002      DHG     Initial Release
#
# Description: Package initialization file.
#              This file is executed when you use "package require IxTclHal" to
#              load the IxTclHal library package. It sets up the Tcl-only variables
#              and is called by the client and server side ixTclHal.tcl files.
#
# Copyright ©  IXIA.
# All Rights Reserved.
#
#############################################################################################

set env(IXTCLHAL_LIBRARY) [file dirname [info script]]

proc PromptIxia {} {
        puts -nonewline "[pwd]> "
}

# This flag will be set when anyone calls cleanUp proc
set cleanUpDone 0

#  Not REQUIRED --- this is taken care of below..... source [file join $env(IXTCLHAL_LIBRARY) ixiarc.tcl]

set genPath [file join $env(IXTCLHAL_LIBRARY) Generic]

lappend auto_path $env(IXTCLHAL_LIBRARY)

initializeDefineCommand
initializeDefineTest

set interfaceFile [file join $genPath interface.tcl]
source $interfaceFile

set constantsFile [file join $genPath constants.tcl]
source $constantsFile


# rename the system exit with our exit so that we can clean up before calling
# system exit for Windows only
if [isWindows] {
	if {[info commands exit] != ""} {
		if {[info commands exitOld] == ""} {
			rename exit exitOld
		}
	}	
	
	# NOTE: Need to redefine this exit here, AND NOT ANYWHERE ELSE, so that the system
	# exit gets called when exitOld is called.
	proc exit {{exitStat 0}} \
	{
		cleanUp
		exitOld $exitStat
	}
	# rename the system after with our after so that we can task switch for Windows only
    if {[info commands after] != ""} {
        if {[info commands originalAfter] == ""} {
            rename after originalAfter
        }
    }
}


if {[isWindows] && [info commands tk] != ""} {
    if {![regexp -nocase scriptmate [tk appname]]} {
        console show
    }
}


############################# GLOBAL VARIABLES #################################
#### NOTE: DON'T FORGET TO ADD NEW ONES
 
## these are the simple ones that don't have any ptr parameters...
set ixTclHal::noArgList    { version session chassisChain chassis card qos streamRegion streamQueue streamQueueList \
                             portGroup filter filterPallette statGroup statList capture captureBuffer \
                             splitPacketGroup dataIntegrity tcpRoundTripFlow autoDetectInstrumentation \
                             protocolServer igmpServer mii usb timeServer forcedCollisions collisionBackoff portCpu \
                             ppp pppStatus sonet sonetError sonetOverhead atmPort dcc srpUsage \
                             bert bertErrorGeneration bertUnframed xaui vsrError fecError opticalDigitalWrapper \
                             ipV6Address logFile remoteConnection licenseManagement \
							 atmStat atmFilter atmReassembly statWatch txRxPreamble streamExtractorFilter streamExtractorModifier \
                             flexibleTimestamp pcpuCommandService gfpOverhead streamTransmitStats xfp lasi sfpPlus \
                             poePoweredDevice poeSignalAcquisition poeAutoCalibration statAggregator \
							 sonetCircuitProperties lcas prbsCapture oamPort oamStatus \
							 pcsLaneStatistics fcPort cfpPort resourceGroupEx transceiver }

## these are the ones that we need simple pointers returned for other stuff...
set ixTclHal::pointerList   { port protocol arpAddressTableEntry ipAddressTableItem igmpAddressTableItem \
                              interfaceIpV4 interfaceIpV6 discoveredAddress atmHeaderCounter \
                              customOrderedSet srpMacBinding mmdRegister latencyBin \
                              ipV6Authentication ipV6Routing ipV6Fragment \
                              rprTlvBandwidthPair rprTlvWeight rprTlvVendorSpecific \
                              rprTlvTotalBandwidth rprTlvNeighborAddress rprTlvStationName \
                              tableUdfColumn igmpGroupRecord dhcpV4Tlv \
							  atmOamAis atmOamRdi atmOamFaultManagementCC atmOamFaultManagementLB atmOamActDeact \
							  ipV6OptionPAD1 ipV6OptionPADN ipV6OptionJumbo ipV6OptionRouterAlert ipV6OptionBindingUpdate \
                              ipV6OptionBindingAck ipV6OptionHomeAddress ipV6OptionBindingRequest ipV6OptionMIpV6UniqueIdSub \
                              ipV6OptionMIpV6AlternativeCoaSub ipV6OptionUserDefine sonetCircuit macSecChannel \
							  oamLocalInformationTlv oamRemoteInformationTlv oamOrganizationSpecificTlv oamSymbolPeriodTlv \
							  oamFrameTlv oamFramePeriodTlv oamSummaryTlv oamEventOrgTlv \
							  oamVariableRequestTlv oamVariableResponseTlv oamLoopbackControl oamOrganizationSpecific	\
							  ciscoMetaDataSourceGroupTag ciscoMetaDataCustomOption conditionalTable \
							  fcoeDiscoveredInfo fcoePlogi fcoeNameServer fcNameServerQuery ptpProperties ptpDiscoveredInfo\
							  ptpAnnounce ptpDelayRequest ptpSync ptpFollowUp ptpDelayResponse packetGroupThresholdList \
							  icmpV6OptionLinkLayerSource icmpV6OptionLinkLayerDestination icmpV6OptionPrefixInformation \
							  icmpV6OptionRedirectedHeader icmpV6OptionMaxTransmissionUnit icmpV6OptionUserDefine \
							  icmpV6Error icmpV6Informational icmpV6MulticastListener icmpV6UserDefine lldpPortId \
							  dcbxPriorityGroupFeature dcbxPfcFeature dcbxFcoeFeature dcbxIscsiFeature dcbxLogicalLinkFeature \
                              dcbxCustomFeature dcbxControlTlv ctPreamble ctGetAllNextRequest ctGetAllNextAccept \
                              ctGetPortNameRequest ctGetPortNameAccept ctGetNodeNameRequest ctGetNodeNameAccept \
                              ctGetFC4TypeRequest ctRegisterNodeNameRequest elsFlogi elsPlogi elsFdisc elsLsAcc elsLogo \
                              elsScr elsLsRjt elsRscn fcpUnsolicitedCommand fcpDataDescriptor \
                              fcpScsiRead fcpScsiWrite fcpScsiInquiry fcpSnsInfo \
							  iEEE48BitAddressSrc iEEEExtendedSrc locallyAssignedSrc iEEERegisteredSrc iEEERegisteredExtendedSrc eUI64MappedSrc \
  							  iEEE48BitAddressDest iEEEExtendedDest locallyAssignedDest iEEERegisteredDest iEEERegisteredExtendedDest eUI64MappedDest \
							  vftHeader ifrHeader encHeader espHeader associationHeader \
							  fcPlogi fcNameServer hse40GQsfpLane hseCfpQsfpLane pcsLaneError txLane}
																					
## these are basically all the protocols that require a portPtr parameter for instantiation
set ixTclHal::protocolList { ip udp tcp ipx icmp arp dhcp gre macSecTag fcoe  \
                             srpArp srpIps frameRelay hdlc isl pauseControl weightedRandomFramesize \
                             rprArp rprProtection rprFairness rprOam cdlPreamble dataCenterEncapsulation \
                             basicLinkServices fcSOF fcEOF }

## this initial list is all the complicated ones
set ixTclHal::commandList  { stat stream udf mplsLabel mpls rip ripRoute  ipAddressTable igmpAddressTable arpServer\
                             interfaceTable interfaceEntry discoveredList discoveredNeighbor discoveredAddress  \
							 packetGroupStats tableUdf sequenceNumberUdf igmp atmOam atmOamTrace vlan stackedVlan protocolOffset \
							 ipV6 ipV6HopByHop ipV6Destination rprRingControl rprTopology rprTlvIndividualBandwidth  \
                             miiae mmd srpHeader srpDiscovery atmHeader ixUtils linkFaultSignaling gfp	\
							 dhcpV4Properties dhcpV4DiscoveredInfo dhcpV6Properties dhcpV6DiscoveredInfo \
							 sonetCircuitList packetGroup macSecTx macSecRx oamHeader ciscoMetaData ptp \
							 oamInformation oamEventNotification oamVariableRequest oamVariableResponse conditionalStats \
							 fcoeProperties npivProperties icmpV6 icmpV6NeighborDiscovery dcbxProperties dcbxDiscoveredInfo \
                             fibreChannel networkHeader commonTransport extendedLinkServices fcpCommandStatus fcp fcProperties protocolPad \
                             hse40GQsfp packetLengthInsertion hseCfpQsfp pcsLaneErrorGroup txLaneGroup capturePlayback }
          
ixTclHal::update ::halCommands
## These commands needs redefinition of the body during connecting to TCL server							 

set ixTclHal::redefineCommandList [list chassis card port stream captureBuffer tableUdf ]

set ::halRedefineCommands [join [list $ixTclHal::redefineCommandList]]
## We need to append dhcpV6Tlv to halCommands, since it is instantiated as an TCLDhcpV4Tlv and can't be added to ixTclHal::pointerList
lappend ::halCommands	dhcpV6Tlv

## We need to append fipTlv to halCommands, since it is instantiated as an TCLDhcpV4Tlv and can't be added to ixTclHal::pointerList
lappend ::halCommands	fipTlv

set halFuncs     { enableEvents clearAllMyOwnership }

set globalArrays { ixgTrialArray ixgTrialCongArray ixgTrialUncongArray \
                   one2oneArray one2manyArray many2oneArray many2manyArray }

set ixProtocolList {ip udp ptp tcp ipx igmp icmp arp vlan dhcp mpls mplsLabel qos rip ripRoute \
                    isl frameRelay ipV6 fcoe fibreChannel commonTransport fcp basicLinkServices extendedLinkServices fcSOF fcEOF }

set ixStopTest      0
set ixStopAction    0

############################ TCL FILES/DIR INITIALIZATION ##########################

if [info exists env(IXIA_RESULTS_DIR)] {
    #set RESULTS_DIR [file join $env(IXIA_RESULTS_DIR) Results]
    set RESULTS_DIR $env(IXIA_RESULTS_DIR)
} else {
    set RESULTS_DIR [file join [file dirname [file dirname $env(IXTCLHAL_LIBRARY)]] Results]
    set env(IXIA_RESULTS_DIR) $RESULTS_DIR
}
if {![file exists $RESULTS_DIR]} {
        file mkdir $RESULTS_DIR
}

if [info exists env(IXIA_LOGS_DIR)] {
    #set LOGS_DIR [file join $env(IXIA_LOGS_DIR) Logs]
    set LOGS_DIR $env(IXIA_LOGS_DIR)
} else {
    set LOGS_DIR [file join [file dirname [file dirname $env(IXTCLHAL_LIBRARY)]] Logs]
    set env(IXIA_LOGS_DIR) $LOGS_DIR
}
if {![file exists $LOGS_DIR]} {
        file mkdir $LOGS_DIR
}

if {![info exists env(IXIA_SAMPLES_DIR)]} {
    set env(IXIA_SAMPLES_DIR) [file dirname [file dirname $env(IXTCLHAL_LIBRARY)]]
}

foreach initProc [info commands initCommand_zz_*] {
    # puts $initProc
    ${initProc}
}

# Create dummy calls to the commands that were moved to the scriptmate package.  This is for
# backwards compatibility but it not guaranteed to work unless the Scriptmate package is installed.
scriptmateBackwardsCompatibility::createAllCommands

############### sample script environment initialization ############################
global ixgJitterIndex 
set ixgJitterIndex(averageLatency)     0
set ixgJitterIndex(standardDeviation)  1
set ixgJitterIndex(averageDeviation)   2
set ixgJitterIndex(minLatency)         3
set ixgJitterIndex(maxLatency)         4


