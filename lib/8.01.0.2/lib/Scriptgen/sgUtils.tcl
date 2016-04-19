#############################################################################################
#   Version 8.01
#   
#   File: sgUtils.tcl
#
#   Copyright ? IXIA.
#   All Rights Reserved.
#
#	Revision Log:
#	04-02-2001	EM	Genesis
#
#
#############################################################################################



########################################################################
# Procedure: setEnumValList
#
# This command gets the list of enum names and returns a list of enum 
# names and their vale. 
#
# Arguments(s):
# enumList      : List of enum names ( {enum1 enum2}
# enumValList   : List of enum names and their values. (out put list {{enum1 0} {enum2 1}})
#
########################################################################

proc scriptGen::setEnumValList { enumList EnumValList} \
{
    upvar $EnumValList enumValList
    set retCode 0
    set enumValList {}

    foreach item $enumList {
        global $item
        set value [set $item]
        lappend enumValList [list $item $value]
    }
    return $retCode  
}


########################################################################
# Procedure: getEnumString
#
# This command get the text for an enum
# Arguments(s):
# cmd       : command
# parameter : a parameter of the command
#
# Returned Result: Text for the enum
########################################################################

proc scriptGen::getEnumString {cmd parameter} \
{
    variable enumsArray
    variable oddParamsList
    variable boolList

    set value [$cmd cget $parameter]
    set searchParam [string trimleft $parameter -]
    set enumSearch [array names enumsArray $cmd,$searchParam]

    if { $enumSearch != {} } {
        # Take care of odd params
        if { ([lsearch [join $oddParamsList] $cmd] != -1 ) && ([lsearch [join $oddParamsList] $searchParam] != -1)} {
            set retString [handleOddParams $cmd $searchParam]
        } else {            
            set enumValList $enumsArray($cmd,$searchParam)
            set joinedList  [join $enumValList]
            set index       [lsearch $joinedList $value]
            set retString   [lindex $joinedList [expr $index-1]]
            if { $retString == ""} {
                set retString   $value
            }
        }

     } elseif {[isEnable $searchParam] || [lsearch $boolList $searchParam] != -1} {
        if {$value == 1} {
            set retString true
        } else {
            set retString false
        }
            
     } else {
        set retString   $value
     }

    return $retString    
}

########################################################################
# Procedure: handleOddParams
#
# This command takes care of odd parameters like port receiveMode
# Arguments(s):
# cmd       : command
#
# Returned Result: The enum text.
########################################################################
proc scriptGen::handleOddParams {cmd {parameter ""} } \
{
    set enumText ""
# I just check port because just one of the port params is odd   

    switch $cmd {
		"port"	{ 
			if {$parameter == "operationModeList"} {
				set enumText [getCombinationOptionList $cmd $parameter [$cmd cget -$parameter]] 
			} else {
				set enumText [getCombinationOptionString $cmd $parameter [$cmd cget -$parameter]] 
			}
		} 
		"oamHeader" -
		"ptp" { 
			set enumText [getCombinationOptionString $cmd $parameter [$cmd cget -$parameter]] 
		} 
		 default	{ 
			catch { set enumText [handleProtocolsOddParams $cmd $parameter]} 
		 }
	}
    return $enumText
}



########################################################################
# Procedure: generateCommand
#
# This command generates the parameter of the cammand and print the command
# Arguments(s):
# cmd   : command
# includeSetDefault : When it is "yes", $cmd setDefault is generated.
#
# Returned Result:
#
########################################################################

proc scriptGen::generateCommand {cmd {includeSetDefault yes} {excludedParmList ""} } \
{
    variable obsoleteParamsArray
    variable oddParamsList

	variable outputDataOption	
	
	set defaultValueArray [format "%sDefaultValueArray" $cmd]
	variable $defaultValueArray		
	
    set retCode 0
    
    set method config
    catch {$cmd $method} paramList

    if {$includeSetDefault == "yes"} {
        sgPuts "$cmd setDefault"
    }

    foreach param [join $paramList] { 
        set searchParam [string trimleft $param -]

		if {[llength $excludedParmList] >0 && [lsearch $excludedParmList $searchParam ] >= 0 } {
			continue
		}
        if {[array name obsoleteParamsArray $cmd] == {} || [lsearch $obsoleteParamsArray($cmd) $searchParam] < 0} {

            set value [$cmd cget $param]
#puts "outputDataOption:$outputDataOption == generateNonDefault - ${defaultValueArray}($param):[set ${defaultValueArray}($param)] == value:$value" 

			set commentFlag 0
			if { [string equal -nocase [set ${defaultValueArray}($param)] $value] } {
				if { $outputDataOption == "generateNonDefault" } { 
					continue
				}

				if { $outputDataOption == "generateCommented" } { 
					set commentFlag 1
				}
			}            
			
			if {[dataValidation::isDouble $value] || [isDigit $value]} {
                set cmdString "$cmd config $param [getEnumString $cmd $param]"
            } else {
				set newValue [list]
				
                if { ([lsearch [join $oddParamsList] $cmd] != -1 ) && ([lsearch [join $oddParamsList] $searchParam] != -1)} {
                    set newValue [handleOddParams $cmd $searchParam]
                    #Make sure to add "" or {} in handleOddParams
                    set cmdString "$cmd config $param  $newValue"
                } else {
                    set newValue $value
                    set cmdString "$cmd config $param  \"$newValue\""
                }                
            }
			if { $outputDataOption == "generateCommented" && $commentFlag} {
				sgPuts "#$cmdString"
			} else {
				sgPuts "$cmdString"
			}
        }     
    }

    return $retCode
}


########################################################################
# Procedure: partiallyGenerateCommand
#
# This command print the selected parameters of the command 
# Arguments(s):
# cmd   : command
# selectedItemList : a list of selected parameters of the command ( no dash 
#                    before the parameter in the list)
#
# Returned Result:
#
########################################################################
proc scriptGen::partiallyGenerateCommand { cmd selectedItemList {includeSetDefault yes} } \
{
    set retCode 0

	variable outputDataOption	
	variable obsoleteParamsArray

	set defaultValueArray [format "%sDefaultValueArray" $cmd]
	variable $defaultValueArray

    if {$includeSetDefault == "yes"} {
        sgPuts "$cmd setDefault"
    }

    foreach param [join $selectedItemList] {

        if {[array name obsoleteParamsArray $cmd] == {} || [lsearch $obsoleteParamsArray($cmd) $param] < 0} {

			set param [format "-%s" $param]
			set value [$cmd cget $param]

			set commentFlag 0
			if { [string equal -nocase [set ${defaultValueArray}($param)] $value] } {
				if { $outputDataOption == "generateNonDefault" } { 
					continue
				}

				if { $outputDataOption == "generateCommented" } { 
					set commentFlag 1
				}
			}

			if {[dataValidation::isDouble $value] || [isDigit $value]} {
				set cmdString "$cmd config $param [getEnumString $cmd $param]"
			} else {
				set cmdString "$cmd config $param  \{$value\}"
			}

			if { $outputDataOption == "generateCommented" && $commentFlag } {
				sgPuts "#$cmdString"
			} else {
				sgPuts "$cmdString"
			}
		}
    }

    return $retCode
}


########################################################################
# Procedure: getCommand
#
# This command get the selected command from server and calls generateCommand 
# Arguments(s):

# Returned Result:
########################################################################
proc scriptGen::getCommand { cmd chassis card port {levelString " " }} \
{
    set retCode 0

    if {($levelString == " ") || ($levelString == 0)} {
        if [$cmd get $chassis $card $port] {
            errorMsg "Error getting $cmd on $chassis $card $port"
            set retCode 1
        }
    } else {

        if [$cmd get $chassis $card $port $levelString] {
            errorMsg "Error getting $cmd on $chassis $card $port at level $levelString"
            set retCode 1
        }
    }        
    
    if {$retCode == 0} {
        generateCommand $cmd
    }   
    return $retCode 
}

########################################################################
# Procedure: createEnums
#
# This command calls all functions to create the enumsArray
# Arguments(s):
# 
# Returned Result:
########################################################################
proc scriptGen::createEnums { } \
{
    variable boolList
    set retCode 0

    set boolList [list continuousRetransmit random insertSignature captureTriggerFrameSizeEnable \
                        captureFilterFrameSizeEnable  userDefinedStat1FrameSizeEnable  asyncTrigger1FrameSizeEnable \
                        asyncTrigger2FrameSizeEnable captureTriggerEnable captureFilterEnable userDefinedStat1Enable \
                        userDefinedStat2Enable asyncTrigger1Enable asyncTrigger2Enable continuous \
                        lengthOverride connectToDut advertise100FullDuplex advertise100HalfDuplex advertise10FullDuplex \
                        advertise10HalfDuplex advertise1000FullDuplex flowControl loopback ignoreLink timeoutEnable \
                        useMagicNumber activeNegotiation dutStripTag pingServerEnable arpServerEnable logLoggingEnabled \
                        lineScrambling dataScrambling useRecoveredClock customK1K2 lineErrorHandling pathErrorHandling \
                        asyncIntEnable rxTriggerEnable finished synchronize resetConnection pushFunctionValid \
                        acknowledgeValid urgentPointerValid insertSequenceSignature allocateUdf ignoreSignature \
                        autonegotiate usePacketFlowImageFile fir useRecoveredClock clockTxRisingEdge clockRxRisingEdge \
						continuousCount disableAutoGenerateLinkLsa disableAutoGenerateRouterLsa includeRprPayloadFcsInCrc \
                        controlVersionOverride controlTypeOverride bottomOfStack forceBottomOfStack \
                        sksv valid fileMark eom ili userDefinedStat1PatternExpressionEnable \
                        userDefinedStat2PatternExpressionEnable captureTriggerPatternExpressionEnable\
                        captureFilterPatternExpressionEnable asyncTrigger1PatternExpressionEnable \
                        asyncTrigger2PatternExpressionEnable]
    createObsoleteParamsArray
    createArpEnums
    createDhcpEnums
    createIcmpEnums
    createIgmpEnums
    createIpEnums
    createIpV6Enums
    createIpxEnums
    createRipEnums
    createUdpEnums
    createStreamEnums
    createUdfEnums
    createMplsEnums
    createVlanEnums
    createFrameRelayEnums
    createIslEnums
    createProtocolEnums
    createPortEnums
	createPppEnums
    createSonetEnums
    createSonetErrorEnums
	createSonetCircuitEnums
    createStatModeEnums
    createPacketGroupEnums
	createInterfaceEntryEnums
    createBertEnums
    createCaptureEnums
    createCollisionBackoffEnums
    createQosEnums
    createDccEnums
    createFlexibleTimestampEnums
    createSrpEnums
    createRprEnums
    createAtmEnums
    createFilterPalletteEnums
	createGfpEnums
    createTxRxPreambleEnums
	createOpticalDigitalWrapperEnums
	createLinkFaultSignalingEnums
	createPoeEnums
	createArpServerEnums
	createInterfaceTableDhcpV6Enums
	createStreamExtractorFilterEnums
	createEthernetOamEnums
	createMacSecEnums
	createTcpEnums
	createFCoEEnums
	createPtpEnums
	createSfpPlusEnums	
	createDcbxEnums
	createPcsLaneErrorEnums
	createDceEnums
	createInterfaceTableEnums
    createCommonTransportEnums
    createFcBasicLinkServicesEnums
    createFcExtendedLinkServicesEnums
    createFcpEnums
    createFcSOFEnums
    createFcEOFEnums
    createFcNameServerQueryEnums    
    createFcpStatusCommandEnums
	catch {createRoutingProtocolEnums}

    return $retCode
}

########################################################################
# Procedure: createDceEnums
#
# This command creates DCE enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createDceEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list dceIdle dceIncrementBy      dceDecrementBy ]
    
    setEnumValList $enumList enumValList
    set enumsArray(dataCenterEncapsulation,embeddedDaAddrMode)  $enumValList
    set enumsArray(dataCenterEncapsulation,embeddedSaAddrMode)    $enumValList
  
    return $retCode
}


########################################################################
# Procedure: createFcSOFEnums
#
# This command creates FibreChannel SOF enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createFcSOFEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list fcSOFc1 fcSOFi1 fcSOFn1 fcSOFi2 fcSOFn2 \
                  fcSOFi3 fcSOFn3 fcSOFc4 fcSOFi4 fcSOFn4 fcSOFf]
    
    setEnumValList $enumList enumValList
    set enumsArray(fcSOF,startOfFrame)    $enumValList

    return $retCode
}


########################################################################
# Procedure: createFcEOFEnums
#
# This command creates FibreChannel EOF enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createFcEOFEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list fcEOFt fcEOFdt fcEOFa fcEOFn fcEOFni \
                  fcEOFdti fcEOFrt fcEOFrti]
    
    setEnumValList $enumList enumValList
    set enumsArray(fcEOF,endOfFrame)    $enumValList
  
    return $retCode
}

########################################################################
# Procedure: createFcCommonTransportEnums
#
# This command creates FibreChannel Common Transport enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createCommonTransportEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list ctGetAllNextRequest ctGetAllNextAccept ctGetPortNameRequest \
					   ctGetPortNameAccept ctGetNodeNameRequest ctGetNodeNameAccept \
                       ctGetFC4TypeRequest ctRegisterNodeNameRequest]
    setEnumValList $enumList enumValList
    set enumsArray(commonTransport,ctCommand)    $enumValList


    set enumList [list ctPreambleFcSw4 ctPreambleEventService ctPreambleKeyDistributionService \
                       ctPreambleAliasService ctPreambleManagementService ctPreambleTimeService \
                       ctPreambleDirectoryService]
    setEnumValList $enumList enumValList
    set enumsArray(ctPreamble,extendedPreambleStatus)    $enumValList
    
    set enumList [list ctPreambleInvalidCommandCode ctPreambleInvalidVersionLevel ctPreambleLogicalError \
                       ctPreambleInvalidCtIuSize ctPreambleLogicalBusy ctPreambleProtocolError \
                       ctPreambleUnableToPerformCommandRequest ctPreambleCommandNotSupported \
                       ctPreambleServerNotAvailable ctPreambleSessionCouldNotBeEstablished \
                       ctPreambleVendorSpecificError]
    setEnumValList $enumList enumValList
    set enumsArray(ctPreamble,reasonCode)    $enumValList
    set enumsArray(ctPreamble,vendorSpecificReasonCode)    $enumValList

    set enumList [list ctPreambleNoAdditionalExplanation ctPreambleAuthorizationException \
                       ctPreambleAuthenticationException ctPreambleDataBaseFull \
					   ctPreambleDataBaseEmpty ctPreambleProcessingRequest \
                       ctPreambleUnableToVerifyConnection ctPreambleDevicesNotInCommonZone]
    setEnumValList $enumList enumValList
    set enumsArray(ctPreamble,reasonCodeExplanation)    $enumValList

    return $retCode
}  

########################################################################
# Procedure: createFcBasicLinkServicesEnums
#
# This command creates FibreChannel Basic Link Services enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createFcBasicLinkServicesEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list blsNoOperationRCTL blsAbortSequenceRCTL blsRemoveConnectionRCTL \
                 blsBasicAcceptRCTL blsBasicRejectRCTL blsDedicatedConnectionPreemptedRCTL]
    setEnumValList $enumList enumValList
    set enumsArray(basicLinkServices,commandCode)    $enumValList


    set enumList [list blsAbortExchange blsAbortSequence]
    setEnumValList $enumList enumValList
    set enumsArray(basicLinkServices,abortSequenceOption)    $enumValList
    
    set enumList [list blsInvalidCommandCode blsLogicalError blsLogicalBusy \
                       blsProtocolError blsUnableToPerformCommandRequest blsVendorSpecificError]
    setEnumValList $enumList enumValList
    set enumsArray(basicLinkServices,reasonCode)    $enumValList

    set enumList [list blsNoAdditionalExplanation blsInvalidOxIdRxIdCombination \
                       blsSequenceAbortedOrNoSequenceInformationProvided]
    setEnumValList $enumList enumValList
    set enumsArray(basicLinkServices,reasonCodeExplanation)    $enumValList

    return $retCode
}  


########################################################################
# Procedure: createFcExtendedLinkServicesEnums
#
# This command creates FibreChannel Extended Link Services enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createFcExtendedLinkServicesEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list elsScrReserved elsScrFabricDetectedRegistration \
                       elsScrNxPortDetectedRegistration elsScrFullRegistration \
                       elsScrClearRegistration]
    setEnumValList $enumList enumValList
    set enumsArray(elsScr,registrationFunction)    $enumValList


    set enumList [list elsRjtInvalidELSCommandcode elsRjtLogicalError elsRjtLogicalbusy\
                       elsRjtProtocolError elsRjtUnableToPerformCommand elsRjtCommandNotSupported \
                       elsRjtCommandAlreadyInProgress elsRjtVendorSpecificError]
    setEnumValList $enumList enumValList
    set enumsArray(elsLsRjt,reasonCode)    $enumValList
    
    set enumList [list elsNone elsLsRjt elsLsAcc elsPlogi \
                       elsFlogi elsLogo elsFdisc elsRscn \
                       elsScr]
    setEnumValList $enumList enumValList
    set enumsArray(extendedLinkServices,protocolType)    $enumValList
    return $retCode
}  


########################################################################
# Procedure: createFcpEnums
#
# This command creates FibreChannel Protocol enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createFcpEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list fcpValue00 fcpValue01 fcpValue10 fcpValue11]
    setEnumValList $enumList enumValList
    set enumsArray(fcpScsiRead,controlByteVendorSpecific)    $enumValList
    set enumsArray(fcpScsiWrite,controlByteVendorSpecific)    $enumValList
    set enumsArray(fcpScsiInquiry,controlByteVendorSpecific)    $enumValList

    set enumList [list fpcSimple fcpHeadOfQueue fcpOrdered fcpAutomaticContingentAllegiance]
    setEnumValList $enumList enumValList
    set enumsArray(fcpUnsolicitedCommand,taskAttribute)    $enumValList

    set enumList [list fcpNoData fcpReadData fcpWriteData]
    setEnumValList $enumList enumValList
    set enumsArray(fcpUnsolicitedCommand,dataMode)    $enumValList

    set enumList [list fcpScsiInquiry fcpScsiRead fcpScsiWrite]
    setEnumValList $enumList enumValList
    set enumsArray(fcpUnsolicitedCommand,cdbType)    $enumValList    

    set enumList [list fcpUnsolicitedCommand fcpCommandStatus fcpDataDescriptor]
    setEnumValList $enumList enumValList
    set enumsArray(fcp,selectedIU)    $enumValList
    return $retCode
}  


########################################################################
# Procedure: createFcNameServerQueryEnums
#
# This command creates FibreChannel Name Server Query enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createFcNameServerQueryEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

	set enumList [list commandGANxt commandGIDA commandGPNId commandGNNId \
                       commandGIDPn commandGIDPt]
	setEnumValList $enumList enumValList
	set enumsArray(fcNameServerQuery,fcNameServerQueryCommand) $enumValList  

	set enumList [list objectPortId objectPortName objectPortType objectNone]
	setEnumValList $enumList enumValList
	set enumsArray(fcNameServerQuery,fcNameServerQueryObject) $enumValList  

    return $retCode    
}

########################################################################
# Procedure: createFcpStatusCommandEnums
#
# This command creates FibreChannel StatusCommand enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createFcpStatusCommandEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

	set enumList [list taskManagementFunctionComplete fcpDataLengthDifferentThanFcpBurstLength \
                       fcpCommandFieldsInvalid fcpDataParameterMismatchWithFcpDataRo \
                       taskManagementFunctionRejected taskManagementFunctionFailed]
	setEnumValList $enumList enumValList
	set enumsArray(fcpCommandStatus,rspCode) $enumValList  

    return $retCode    
}

########################################################################
# Procedure: createPtpEnums
#
# This command creates Ptp enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createPtpEnums { } \
{

    variable enumsArray
	variable oddParamsList

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list ptpSyncMessage ptpDelayRequestMessage ptpFollowUpMessage \
					   ptpDelayResponseMessage	ptpAnnounceMessage]
    setEnumValList $enumList enumValList
    set enumsArray(ptp,messageType)    $enumValList


    set enumList [list ptpSync ptpDelayRequest ptpFollowUp ptpDelayResponse ptpManagement	ptpOther]
    setEnumValList $enumList enumValList
    set enumsArray(ptp,controlField)    $enumValList
    
    set enumList [list ptpFlagNone ptpLeap61 ptpLeap59 ptpUtcOffsetValid ptpPtpTimescale ptpTimeTraceable	ptpFrequencyTraceable \
					   ptpAlternateMaster ptpTwoStep ptpUnicast ptpProfile1 ptpProfile2]
    setEnumValList $enumList enumValList
    set enumsArray(ptp,flagField)    $enumValList
    lappend oddParamsList [list ptp flagField ]

    set enumList [list ptpAccuracy25ns ptpAccuracy100ns ptpAccuracy250ns ptpAccuracy1us		\
					   ptpAccuracy2p5us ptpAccuracy10us ptpAccuracy25us ptpAccuracy100us	\
					   ptpAccuracy250us ptpAccuracy1ms ptpAccuracy2p5ms ptpAccuracy10ms		\
					   ptpAccuracy25ms ptpAccuracy100ms ptpAccuracy250ms ptpAccuracy1s		\
					   ptpAccuracy10s ptpAccuracyGreater10s ptpAccuracyUnknown]
    setEnumValList $enumList enumValList
    set enumsArray(ptpAnnounce,clockAccuracy)    $enumValList
    set enumsArray(ptpProperties,clockAccuracy)  $enumValList

    set enumList [list ptpAtomicClock ptpGPS ptpTerrestrialRadio ptpPTP ptpNTP ptpHandSet ptpTimeSourceOther \
					   ptpInternalOscillator ptpAltPtpProfile0 ptpAltPtpProfile1 ptpAltPtpProfile2 ptpAltPtpProfile3 \
					   ptpAltPtpProfile4 ptpAltPtpProfile5 ptpAltPtpProfile6 ptpAltPtpProfile7 ptpAltPtpProfile8 \
					   ptpAltPtpProfile9 ptpAltPtpProfile10 ptpAltPtpProfile11 ptpAltPtpProfile12 ptpAltPtpProfile13 \
					   ptpAltPtpProfile14 ptpReserved]
    setEnumValList $enumList enumValList
    set enumsArray(ptpAnnounce,timeSource)    $enumValList

    return $retCode
}    



########################################################################
# Procedure: createFCoEEnums
#
# This command creates FCoE and Fibre Channel enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createFCoEEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

	# FCoE
    set enumList [list fcoeSofNormalClass1 fcoeSofInitiateClass2 fcoeSofNormalClass2 \
					   fcoeSofInitiateClass3 fcoeSofActivateClass4 fcoeSofNormalClass3 \
					   fcoeSofInitiateClass4 fcoeSofNormalClass4 fcoeSofFabric]                    
    setEnumValList $enumList enumValList
    set enumsArray(fcoe,eSofDelimiter)  $enumValList

    set enumList [list fcoeEofTerminate fcoeEofAbort fcoeEofNormal \
					   fcoeEofNormalInvalid fcoeEofRemoveTerminateClass4 fcoeEofRemoveTerminateInvalidClass4 ]
    setEnumValList $enumList enumValList
    set enumsArray(fcoe,eEofDelimiter)  $enumValList

	# Fibre Channel
    set enumList [list fibreChannelDeviceDataFrames fibreChannelExtendedLinkServices fibreChannelFc4LinkData \
					   fibreChannelVideoData fibreChannelExtenderHeaders fibreChannelBasicLinkServices \
					   fibreChannelLinkControlFrame fibreChannelExtendedRouting]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,routingControlType)  $enumValList

    set enumList [list fibreChannelIdle fibreChannelIncrement fibreChannelDecrement \
					   fibreChannelContIncr fibreChannelContDecr fibreChannelRandom ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,originatorExchangeCounter)  $enumValList

    set enumList [list fibreChannelOriginator fibreChannelResponder ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,exchangeContext)  $enumValList

    set enumList [list fibreChannelInitiator fibreChannelRecipient ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,sequenceContext)  $enumValList

    set enumList [list fibreChannelFirstSequenceOther fibreChannelFirstSequenceFirst ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,firstSequence)  $enumValList

    set enumList [list fibreChannelLastSequenceOther fibreChannelLastSequenceLast ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,lastSequence)  $enumValList

    set enumList [list fibreChannelEndSequenceOther fibreChannelEndSequenceLast ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,endSequence)  $enumValList

    set enumList [list fibreChannelConnectionAlive fibreChannelConnectionPending ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,endConnection)  $enumValList

    set enumList [list fibreChannelCsCtl fibreChannelPriority ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,csControlOrPriority)  $enumValList

    set enumList [list fibreChannelInitiativeHold fibreChannelInitiativeTransfer ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,sequenceInitiative)  $enumValList

    set enumList [list fibreChannelNoAssistanceProvided fibreChannelAck1Required fibreChannelReserved fibreChannelAck0Required]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,ackForm)  $enumValList

    set enumList [list fibreChannelOriginal fibreChannelRetransmission fibreChannelReserved fibreChannelAck0Required]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,ackForm)  $enumValList

    set enumList [list fibreChannelOriginal fibreChannelRetransmission ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,retransmittedSequence)  $enumValList

    set enumList [list fibreChannelBidirectional fibreChannelUnidirectional ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,unidirectionalTransmit)  $enumValList

    set enumList [list fibreChannelNoInformation fibreChannelFollowImmediately fibreChannelFollowSoon fibreChannelFollowDelayed]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,continueSequenceCondition)  $enumValList

    set enumList [list fibreChannelRelativeOffsetDefined fibreChannelRelativeOffsetPresent ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,relativeOffsetPresent)  $enumValList

    set enumList [list fibreChannelExchangeReassemblyOff fibreChannelExchangeReassemblyOn ]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,exchangeReassembly)  $enumValList

    set enumList [list fibreChannelZeroHexByteFill fibreChannelOneHexByteFill fibreChannelTwoHexByteFill fibreChannelThreeHexByteFill]
    setEnumValList $enumList enumValList
    set enumsArray(fibreChannel,fillBytes)  $enumValList
    
	# This needs to be moved with FCoE generation part
	#if (Sequence Context is Initiator (0)) {
	#	set enumList [list fibreChannelContinue fibreChannelPerformAbts fibreChannelStop fibreChannelRetransmissionRequested]
	#} else {
	#	set enumList [list fibreChannelDiscardMultiple fibreChannelDiscardSingle fibreChannelProcessPolicy fibreChannelDiscardMultipleWithRetransmission]
	#}
    #setEnumValList $enumList enumValList
    #set enumsArray(fibreChannel,abortSequenceCondition)  $enumValList
    
    set enumList [list fcoeFabricProvidedMacAddress fcoeServerProvidedMacAddress fcoeBoth]
    setEnumValList $enumList enumValList
    set enumsArray(fcoeProperties,fcoeAddressingMode)  $enumValList
    
    set enumList [list plogiDestinationId plogiWwpn]
    setEnumValList $enumList enumValList
    set enumsArray(fcoePlogi,destinationMode)  $enumValList

    return $retCode
}  


########################################################################
# Procedure: createMacSecEnums
#
# This command creates MacSec enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createMacSecEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list confidentialityOffset0 confidentialityOffset4 \
					   confidentialityOffset30 confidentialityOffset50 ]                    
 
    setEnumValList $enumList enumValList
    set enumsArray(macSec,confidentialityOffset)  $enumValList

    return $retCode
}


########################################################################
# Procedure: createEthernetOamEnums
#
# This command creates Ethernet OAM enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createEthernetOamEnums { } \
{
    variable enumsArray
	variable oddParamsList

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list oamParserActionForward oamParserActionLoopback oamParserActionDiscard oamParserActionInvalid]                      
    setEnumValList $enumList enumValList
    set enumsArray(oamLocalInformationTlv,parserAction)  $enumValList
    set enumsArray(oamRemoteInformationTlv,parserAction)  $enumValList

	set enumList [list oamMultiplexerActionForward oamMultiplexerActionDiscard ]                    
    setEnumValList $enumList enumValList
    set enumsArray(oamLocalInformationTlv,multiplexerAction)  $enumValList
    set enumsArray(oamRemoteInformationTlv,multiplexerAction)  $enumValList

	set enumList [list oamCodeInformation oamCodeEventNotification oamCodeVariableRequest \
					   oamCodeVariableResponse oamCodeLoopbackControl oamCodeOrgSpecific]
    setEnumValList $enumList enumValList
    set enumsArray(oamHeader,code)  $enumValList

	set enumList [list oamFlagNone oamFlagLinkFault oamFlagDyingGasp  oamFlagCriticalEvent \
					   oamFlagLocalEvaluating oamFlagLocalStable oamFlagRemoteEvaluation oamFlagRemoteStable]
    setEnumValList $enumList enumValList
    set enumsArray(oamHeader,flags)  $enumValList
    lappend oddParamsList [list oamHeader flags ]


    return $retCode
}

########################################################################
# Procedure: createEnumsPerPortType
#
# This command calls all functions to create the enumsArray for a specific
#	port Type.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################
proc scriptGen::createEnumsPerPortType {chassis card port } \
{

	createFilterEnums $chassis $card $port
}


########################################################################
# Procedure: createArpEnums
#
# This command creates ARP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createArpEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list arpGatewayOnly arpLearnOnly arpGatewayAndLearn ]                    
    
    setEnumValList $enumList enumValList
    set enumsArray(arpServer,mode)  $enumValList

    return $retCode
}
########################################################################
# Procedure: createArpEnums
#
# This command creates ARP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createArpServerEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list arpIdle arpIncrement      arpDecrement \
                       arpContinuousIncrement    arpContinuousDecrement]                    
    
    setEnumValList $enumList enumValList
    set enumsArray(arp,sourceProtocolAddrMode)  $enumValList
    set enumsArray(arp,destProtocolAddrMode)    $enumValList
    set enumsArray(arp,sourceHardwareAddrMode)  $enumValList
    set enumsArray(arp,destHardwareAddrMode)    $enumValList

    set enumList [list arpRequest arpReply rarpRequest rarpReply]
    
    setEnumValList $enumList enumValList
    set enumsArray(arp,operation)  $enumValList

    return $retCode
}


########################################################################
# Procedure: createDhcpEnums
#
# This command creates DHCP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createDhcpEnums { } \
{
#DHCP
    variable enumsArray
    variable oddParamsList
    variable dhcpOptionDataList

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list dhcpNoBroadcast dhcpBroadcast]  
    setEnumValList $enumList enumValList
    set enumsArray(dhcp,flags)  $enumValList
    
    set enumList [list dhcpEthernet10Mb dhcpEthernet3Mb dhcpAmateur dhcpProteon     \
                       dhcpChaos dhcpIEEE dhcpARCNET dhcpHyperchannel dhcpLanstar   \
                       dhcpAutonet dhcpLocalTalk dhcpLocalNet dhcpUltraLink         \
                       dhcpSMDS dhcpFrameRelay dhcpATM1 dhcpHDLC  dhcpFibreChannel  \
                       dhcpATM2 dhcpSerialLine dhcpATM3]
    
    setEnumValList $enumList enumValList
    set enumsArray(dhcp,hwType)  $enumValList

    set enumList [list dhcpBootRequest dhcpBootReply]
    
    setEnumValList $enumList enumValList
    set enumsArray(dhcp,opCode)  $enumValList

    set dhcpOptionDataList [list dhcpPad dhcpSubnetMask dhcpTimeOffset dhcpRouter dhcpGateways \
                                 dhcpTimeServer dhcpNameServer dhcpDomainNameServer dhcpLogServer \
                                 dhcpCookieServer dhcpLPRServer dhcpImpressServer dhcpResourceLocationServer \
                                 dhcpHostName dhcpBootFileSize dhcpMeritDumpFile dhcpDomainName dhcpSwapServer \
                                 dhcpRootPath dhcpExtensionPath dhcpIpForwardingEnable dhcpNonLocalSrcRoutingEnable \
                                 dhcpPolicyFilter dhcpMaxDatagramReassemblySize dhcpDefaultIpTTL \
                                 dhcpPathMTUAgingTimeout dhcpPathMTUPlateauTable dhcpInterfaceMTU dhcpAllSubnetsAreLocal \
                                 dhcpBroadcastAddress dhcpPerformMaskDiscovery dhcpMaskSupplier \
                                 dhcpPerformRouterDiscovery dhcpRouterSolicitAddr \
                                 dhcpStaticRoute dhcpTrailerEncapsulation dhcpARPCacheTimeout dhcpEthernetEncapsulation \
                                 dhcpTCPDefaultTTL dhcpTCPKeepAliveInterval dhcpTCPKeepGarbage \
                                 dhcpNISDomain dhcpNISServer dhcpNTPServer dhcpVendorSpecificInfo \
                                 dhcpNetBIOSNameSvr dhcpNetBIOSDatagramDistSvr dhcpNetBIOSNodeType dhcpNetBIOSScope \
                                 dhcpXWinSysFontSvr dhcpXWinSysDisplayMgr dhcpRequestedIPAddr dhcpIPAddrLeaseTime \
                                 dhcpOptionOverload dhcpMessageType dhcpSvrIdentifier dhcpParamRequestList \
                                 dhcpMessage dhcpMaxMessageSize dhcpRenewalTimeValue dhcpRebindingTimeValue \
                                 dhcpVendorClassId dhcpClientId dhcpNetwareIpDomain dhcpNetwareIpOption dhcpNISplusDomain dhcpNISplusServer \
                                 dhcpTFTPSvrName dhcpBootFileName dhcpMobileIPHomeAgent \
                                 dhcpSMTPSvr dhcpPOP3Svr dhcpNNTPSvr dhcpWWWSvr dhcpDefaultFingerSvr dhcpDefaultIRCSvr \
                                 dhcpStreetTalkSvr dhcpSTDASvr dhcpAgentInformationOption \
                                 dhcpEnd]
    
    return $retCode
}


########################################################################
# Procedure: createIcmpEnums
#
# This command creates ICMP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createIcmpEnums { } \
{
#ICMP
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list echoReply destUnreachable sourceQuench redirect echoRequest     \
                       timeExceeded  parameterProblem timeStampRequest timeStampReply  \
                       infoRequest   maskReply]
    
    setEnumValList $enumList enumValList
    set enumsArray(icmp,type)  $enumValList
    return $retCode
}


########################################################################
# Procedure: createIgmpEnums
#
# This command creates IGMP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createIgmpEnums { } \
{
#IGMP
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list membershipQuery membershipReport1 dvmrpMessage membershipReport2 \
                       leaveGroup membershipReport3] 
    
    setEnumValList $enumList enumValList
    set enumsArray(igmp,type)  $enumValList

    set enumList [list igmpVersion1 igmpVersion2 igmpVersion3]
    
    setEnumValList $enumList enumValList
    set enumsArray(igmp,version)  $enumValList

    set enumList [list igmpIdle igmpIncrement   igmpDecrement \
                       igmpContIncrement  igmpContDecrement]      
    
    setEnumValList $enumList enumValList
    set enumsArray(igmp,mode)  $enumValList

	set enumList [list  igmpModeIsInclude igmpModeIsExclude igmpChangeToIncludeMode \
						igmpChangeToExcludeMode igmpAllowNewSources igmpBlockOldSources]     
    setEnumValList $enumList enumValList
    set enumsArray(igmpGroupRecord,type)  $enumValList

    return $retCode
}



########################################################################
# Procedure: createIpEnums
#
# This command creates IP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createIpEnums { } \
{
#IP
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list networkControl internetControl criticEcp flashOverride \
                       flash  immediate priority routine]
   
    setEnumValList $enumList enumValList
    set enumsArray(ip,precedence)  $enumValList


    set enumList [list normalDelay lowDelay]    
    setEnumValList $enumList enumValList
    set enumsArray(ip,delay)  $enumValList


    set enumList [list normalThruput highThruput]    
    setEnumValList $enumList enumValList
    set enumsArray(ip,throughput)  $enumValList


    set enumList [list normalReliability normalReliability]  
    setEnumValList $enumList enumValList
    set enumsArray(ip,reliability)  $enumValList


    set enumList [list may dont]   
    setEnumValList $enumList enumValList
    set enumsArray(ip,fragment)  $enumValList
 

    set enumList [list last more]   
    setEnumValList $enumList enumValList
    set enumsArray(ip,lastFragment)  $enumValList

	set enumList [list \
		ipV4ProtocolIpV6HopByHop ipV4ProtocolIcmp ipV4ProtocolIgmp ipV4ProtocolGgp ipV4ProtocolIpv4 ipV4ProtocolSt 		\
		ipV4ProtocolTcp ipV4ProtocolUcl ipV4ProtocolEgp ipV4ProtocolIgp ipV4ProtocolBbnRccMon ipV4ProtocolNvpIi 		\
		ipV4ProtocolPup ipV4ProtocolArgus ipV4ProtocolEmcon ipV4ProtocolXnet ipV4ProtocolChaos ipV4ProtocolUdp 			\
		ipV4ProtocolMux ipV4ProtocolDcnMeas ipV4ProtocolHmp ipV4ProtocolPrm ipV4ProtocolXnsIdp ipV4ProtocolTrunk1 		\
		ipV4ProtocolTrunk2 ipV4ProtocolLeaf1 ipV4ProtocolLeaf2 ipV4ProtocolRdp ipV4ProtocolIrtp ipV4ProtocolIsoTp4 		\
		ipV4ProtocolNetblt ipV4ProtocolMfeNsp ipV4ProtocolMeritInp ipV4ProtocolSep ipV4Protocol3Pc ipV4ProtocolIdpr 	\
		ipV4ProtocolXtp ipV4ProtocolDdr ipV4ProtocolIdprCmtp ipV4ProtocolTpPlusPlus ipV4ProtocolIlTransportProtocol 	\
		ipV4ProtocolIpv6 ipV4ProtocolSdrp ipV4ProtocolSipSr ipV4ProtocolSipFrag ipV4ProtocolIdrp ipV4ProtocolRsvp 		\
		ipV4ProtocolGre ipV4ProtocolMhrp ipV4ProtocolBna ipV4ProtocolSippEsp ipV4ProtocolSippAh ipV4ProtocolINlsp 		\
		ipV4ProtocolSwipe ipV4ProtocolNarp ipV4ProtocolMobile ipV4ProtocolTlsp ipV4ProtocolSkip ipV4ProtocolIpv6Icmp 	\
		ipV4ProtocolIpv6NoNext ipV4ProtocolIpv6Opts ipV4ProtocolHostInternalProtocol ipV4ProtocolCftp 					\
		ipV4ProtocolAnyLocalNetwork ipV4ProtocolSatExpak ipV4ProtocolKriptolan ipV4ProtocolRvd ipV4ProtocolIppc 		\
		ipV4ProtocolAnyDistFileSystem ipV4ProtocolSatMon ipV4ProtocolVisa ipV4ProtocolIpcv ipV4ProtocolCpnx 			\
		ipV4ProtocolCphb ipV4ProtocolWsn ipV4ProtocolPvp ipV4ProtocolBrSatMon ipV4ProtocolSunNd ipV4ProtocolWbMon 		\
		ipV4ProtocolWbExpak ipV4ProtocolIsoIp ipV4ProtocolVmtp ipV4ProtocolSequreVmtp ipV4ProtocolVines 				\
		ipV4ProtocolTtp ipV4ProtocolNsfnet ipV4ProtocolDgp ipV4ProtocolTcf ipV4ProtocolEigrp ipV4ProtocolOspf 			\
		ipV4ProtocolSpriteRpc ipV4ProtocolLarp ipV4ProtocolMtp ipV4ProtocolAx25 ipV4ProtocolIpip ipV4ProtocolMicp 		\
		ipV4ProtocolSccSp ipV4ProtocolEtherip ipV4ProtocolEncap ipV4ProtocolAnyPrivateEncrScheme ipV4ProtocolGmtp 		\
		ipV4ProtocolIfmp ipV4ProtocolPnni ipV4ProtocolPim ipV4ProtocolAris ipV4ProtocolScps ipV4ProtocolQnx 			\
		ipV4ProtocolActiveNetwork ipV4ProtocolIpComp ipV4ProtocolSnp ipV4ProtocolCompaqPeer ipV4ProtocolIpxInIp 		\
		ipV4ProtocolVrrp ipV4ProtocolPgm ipV4ProtocolAnyZeroHop ipV4ProtocolL2tp ipV4ProtocolDdx ipV4ProtocolIatp 		\
		ipV4ProtocolStp ipV4ProtocolSrp ipV4ProtocolUti ipV4ProtocolSmp ipV4ProtocolSm ipV4ProtocolPtp 					\
		ipV4ProtocolIsis ipV4ProtocolFire ipV4ProtocolCrtp ipV4ProtocolCrudp ipV4ProtocolSscopmce ipV4ProtocolIplt 		\
		ipV4ProtocolSps ipV4ProtocolPipe ipV4ProtocolSctp ipV4ProtocolFiberChannel ipV4ProtocolRsvpE2eIgnore 			\
		ipV4ProtocolMobilityHeader ipV4ProtocolUdpLite ipV4ProtocolMplsInIp ipV4ProtocolReserved255						]
		 
    
    setEnumValList $enumList enumValList
    set enumsArray(ip,ipProtocol)  $enumValList
 
    set enumList [list ipIdle ipIncrHost ipDecrHost ipContIncrHost ipContDecrHost \
                       ipIncrNetwork  ipDecrNetwork ipContIncrNetwork ipContDecrNetwork ipRandom]
    
    setEnumValList $enumList enumValList
    set enumsArray(ip,sourceIpAddrMode)     $enumValList
    set enumsArray(ip,destIpAddrMode)       $enumValList

    set enumList [list classA classB classC classD noClass]   
    setEnumValList $enumList enumValList
    set enumsArray(ip,destClass)    $enumValList
    set enumsArray(ip,sourceClass)  $enumValList

    set enumList [list ipV4ConfigTos ipV4ConfigDscp]  
    setEnumValList $enumList enumValList
    set enumsArray(ip,qosMode)  $enumValList

    set enumList [list ipV4DscpDefault ipV4DscpClassSelector ipV4DscpAssuredForwarding \
						ipV4DscpExpeditedForwarding ipV4DscpCustom ]  
    setEnumValList $enumList enumValList
    set enumsArray(ip,dscpMode)  $enumValList

    set enumList [list ipV4DscpClass1 ipV4DscpClass2 ipV4DscpClass3 ipV4DscpClass4 \
					   ipV4DscpClass5 ipV4DscpClass6 ipV4DscpClass7]  
    setEnumValList $enumList enumValList
    set enumsArray(ip,classSelector)  $enumValList

    set enumList [list ipV4DscpAssuredForwardingClass1 ipV4DscpAssuredForwardingClass2 \
					   ipV4DscpAssuredForwardingClass3 ipV4DscpAssuredForwardingClass4]  
    setEnumValList $enumList enumValList
    set enumsArray(ip,assuredForwardingClass)  $enumValList

    set enumList [list ipV4DscpPrecedenceLowDrop ipV4DscpPrecedenceMediumDrop ipV4DscpPrecedenceHighDrop ]  
    setEnumValList $enumList enumValList
    set enumsArray(ip,assuredForwardingPrecedence)  $enumValList
    
    set enumList [list ipV4InvalidChecksum ipV4ValidChecksum ipV4OverrideChecksum ]
    setEnumValList $enumList enumValList
	set enumsArray(ip,useValidChecksum)  $enumValList
	
    return $retCode
}


########################################################################
# Procedure: createTcpEnums
#
# This command creates TCP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createTcpEnums { } \
{
#TCP
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list tcpInvalidChecksum tcpValidChecksum tcpOverrideChecksum ]
    setEnumValList $enumList enumValList
	set enumsArray(tcp,useValidChecksum)  $enumValList
	
    
    return $retCode
}

########################################################################
# Procedure: createInterfaceTableEnums
#
# This command creates InterfaceTable enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createInterfaceTableEnums { } \
{
#InterfaceTable
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}    
		
	set enumList [list fipVersion0 fipVersion1 fipVersionAuto]
    setEnumValList $enumList enumValList
    set enumsArray(interfaceTable,fipVersion)  $enumValList
    return $retCode
}

########################################################################
# Procedure: createIpV6Enums
#
# This command creates IPV6 enums
# Arguments(s):
# Returned Result:
#
########################################################################
proc scriptGen::createIpV6Enums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list	ipV6Idle \
						ipV6IncrHost \
						ipV6DecrHost \
						ipV6IncrNetwork \
						ipV6DecrNetwork \
						ipV6IncrInterfaceId \
						ipV6DecrInterfaceId \
						ipV6IncrGlobalUnicastTopLevelAggrId \
						ipV6DecrGlobalUnicastTopLevelAggrId \
						ipV6IncrGlobalUnicastNextLevelAggrId \
						ipV6DecrGlobalUnicastNextLevelAggrId \
						ipV6IncrGlobalUnicastSiteLevelAggrId \
						ipV6DecrGlobalUnicastSiteLevelAggrId \
						ipV6IncrSiteLocalUnicastSubnetId \
						ipV6DecrSiteLocalUnicastSubnetId \
						ipV6IncrMulticastGroupId \
						ipV6DecrMulticastGroupId \
						ipV6IncrementGlobalUnicastGlobalRoutingPrefixId \
						ipV6DecrementGlobalUnicastGlobalRoutingPrefixId \
						ipV6IncrementSubnetId \
						ipV6DecrementSubnetId ]
		   
    setEnumValList $enumList enumValList
    set enumsArray(ipV6,sourceAddrMode)  $enumValList
    set enumsArray(ipV6,destAddrMode)  $enumValList

    set enumList [list ipV6HopByHopOptions ipV6Routing ipV6Fragment \
                       ipV6EncapsulatingSecurityPayload ipV6Authentication \
                       ipV6NoNextHeader ipV6DestinationOptions ipV4ProtocolIpv4 \
					   ipV4ProtocolTcp ipV4ProtocolUdp ipV4ProtocolGre ipV4ProtocolIpv6Icmp ] 
                          
    setEnumValList $enumList enumValList
    set enumsArray(ipV6,nextHeader)  $enumValList

    set enumList [list ipV6RouterAlertMLD ipV6RouterAlertRSVP ipV6RouterAlertActiveNet ]   
    setEnumValList $enumList enumValList
    set enumsArray(ipV6OptionRouterAlert,routerAlert)  $enumValList

    set enumList [list ipV6OptionPAD1 ipV6OptionPADN ipV6OptionJumbo ipV6OptionRouterAlert \
                       ipV6OptionBindingUpdate ipV6OptionBindingAck ipV6OptionHomeAddress \
                       ipV6OptionBindingRequest ipV6OptionMIpV6UniqueIdSub   \
                       ipV6OptionMIpV6AlternativeCoaSub ipV6OptionUserDefine ]
	
    setEnumValList $enumList enumValList
    foreach cmdOption $enumList {
        set enumsArray($cmdOption,optionType)  $enumValList
    }

    return $retCode
}


########################################################################
# Procedure: createIpxEnums
#
# This command creates IPX enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createIpxEnums { } \
{    
#IPX
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list ipxIdle ipxIncrement ipxDecrement ipxContIncrement \
                       ipxContDecrement ipxCtrRandom]
    
    setEnumValList $enumList enumValList
    set enumsArray(ipx,destNetworkCounterMode)      $enumValList
    set enumsArray(ipx,destNodeCounterMode)         $enumValList   
    set enumsArray(ipx,destSocketCounterMode)       $enumValList
    set enumsArray(ipx,sourceNetworkCounterMode)    $enumValList
    set enumsArray(ipx,sourceNodeCounterMode)       $enumValList
    set enumsArray(ipx,sourceSocketCounterMode)     $enumValList

    set enumList [list typeUnknown typeRoutingInfo typeEcho typeError typeIpx\
                       typeSpx typeNcp typeNetBios typeNdsNcp]   
    
    setEnumValList $enumList enumValList
    set enumsArray(ipx,packetType)    $enumValList


    set enumList [list socketNcp socketSap socketRipx socketNetBios  \
                       socketDiagnostics socketSerialization]
    
    setEnumValList $enumList enumValList
    set enumsArray(ipx,sourceSocket)    $enumValList
    set enumsArray(ipx,destNode)        $enumValList

    set enumList [list server client]    
    setEnumValList $enumList enumValList
    set enumsArray(ipx,svrClientType)    $enumValList
    return $retCode
}


########################################################################
# Procedure: createRipEnums
#
# This command creates RIP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createRipEnums { } \
{
#RIP
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list ripRequest ripResponse ripTraceOn ripTraceOff \
                       ripReserved]
    
    setEnumValList $enumList enumValList
    set enumsArray(rip,command)    $enumValList

    set enumList [list ripVersion1 ripVersion2]     
    setEnumValList $enumList enumValList
    set enumsArray(rip,version)    $enumValList
    return $retCode
}



########################################################################
# Procedure: createUdpEnums
#
# This command creates UDP enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createUdpEnums { } \
{
#UDP
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {} 

    set enumList [list echoServerPort discardPacketPort usersServerPort         \
                       dayAndTimeServerPort quoteOfTheDayServerPort             \
                       characterGeneratorPort timeServerPort whoIsServerPort    \
                       domainNameServerPort unassignedPort bootpServerPort      \
                       bootpClientPort tftpProtocolPort remoteWhoServerPort  ripPort\
					   ptpEventPort ptpGeneralPort]
    
    setEnumValList $enumList enumValList
    set enumsArray(udp,sourcePort)    $enumValList
    set enumsArray(udp,destPort)      $enumValList

    set enumList [list validChecksum invalidChecksum]    
    setEnumValList $enumList enumValList
    set enumsArray(udp,checksumMode)    $enumValList

    return $retCode
}



########################################################################
# Procedure: createStreamEnums
#
# This command creates stream enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createStreamEnums { } \
{
#Stream
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list gapFixed gapRandom]    
    setEnumValList $enumList enumValList
    set enumsArray(stream,ifgType)    $enumValList
    
    set enumList [list increment contIncrement decrement contDecrement  \
                       idle  ctrRandom daArp cpeMacAddress \
                       contJitterTestPattern contRandomTestPattern ]
    
    setEnumValList $enumList enumValList
    set enumsArray(stream,saRepeatCounter)    $enumValList
    set enumsArray(stream,daRepeatCounter)    $enumValList

    set enumList [list sizeFixed sizeRandom sizeIncr sizeAuto]   
    setEnumValList $enumList enumValList
    set enumsArray(stream,frameSizeType)    $enumValList


    set enumList [list good alignErr dribbleErr bad none]    
    setEnumValList $enumList enumValList
    set enumsArray(stream,fcs)    $enumValList


    set enumList [list incrByte incrWord decrByte decrWord patternTypeRandom repeat nonRepeat \
                       continuousJitterTestPattern continuousRandomTestPattern ]  
    setEnumValList $enumList enumValList
    set enumsArray(stream,patternType)    $enumValList

    set enumList [list dataPatternRandom allOnes allZeroes xAAAA x5555   \
                       x7777 xDDDD xF0F0 x0F0F xFF00FF00  x00FF00FF      \
                       xFFFF0000 x0000FFFF x00010203 x00010002 xFFFEFDFC \
                       xFFFFFFFE  userpattern]
    setEnumValList $enumList enumValList
    set enumsArray(stream,dataPattern)    $enumValList

    set enumList [list contPacket contBurst stopStream advance gotoFirst \
                       firstLoopCount]  
    setEnumValList $enumList enumValList
    set enumsArray(stream,dma)    $enumValList 

    set enumList [list gapNanoSeconds gapMicroSeconds gapMilliSeconds gapSeconds gapClockTicks gapBytes]    
    setEnumValList $enumList enumValList
    set enumsArray(stream,gapUnit)    $enumValList

    set enumList [list gapFixed gapRandom]    
    setEnumValList $enumList enumValList
    set enumsArray(stream,ifgType)    $enumValList

    set enumList [list streamRateModeGap streamRateModePercentRate streamRateModeFps streamRateModeBps]    
    setEnumValList $enumList enumValList
    set enumsArray(stream,rateMode)    $enumValList

    set enumList [list priorityGroup0 priorityGroup1 priorityGroup2 priorityGroup3]    
    setEnumValList $enumList enumValList
    set enumsArray(stream,priorityGroup)    $enumValList

    set enumList [list randomUniform randomWeightedPair  randomQuadGaussian \
                       randomCisco randomIMIX randomTolly \
                       randomRPRTrimodal randomRPRQuadmodal ]    
    setEnumValList $enumList enumValList
    set enumsArray(weightedRandomFramesize,randomType)    $enumValList

	set enumList [list usePercentRate streamQueueAalPduBitRate streamQueueAalCellBitRate]	    
    setEnumValList $enumList enumValList
    set enumsArray(streamQueue,rateMode)    $enumValList

    set enumList [list streamGapControlFixed streamGapControlAverage]    
    setEnumValList $enumList enumValList
    set enumsArray(streamRegion,gapControlMode)    $enumValList

    return $retCode
}
    
########################################################################
# Procedure: createMplsEnums
#
# This command creates MPLS enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createMplsEnums { } \
{
#MPLS
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list mplsUnicast mplsMulticast]  
    setEnumValList $enumList enumValList
    set enumsArray(mpls,type)    $enumValList
    return $retCode
}

########################################################################
# Procedure: createUdfEnums
#
# This command creates UDF enums
# Arguments(s):
# Returned Result:
#
########################################################################
proc scriptGen::createUdfEnums { } \
{
#UDF
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list udfCounterMode udfRandomMode udfValueListMode udfNestedCounterMode udfRangeListMode udfIPv4Mode]          
    setEnumValList $enumList enumValList
    set enumsArray(udf,counterMode)    $enumValList

	set enumList [list uuuu uuud uudu uudd uduu udud uddu uddd duuu duud dudu dudd dduu ddud dddu dddd]          
    setEnumValList $enumList enumValList
    set enumsArray(udf,updown)    $enumValList

	set enumList [list c8 c16 c8x8 c24 c16x8 c8x16 c8x8x8 c32 c24x8 c16x16 c16x8x8 c8x24 c8x16x8 c8x8x16 c8x8x8x8]          
    setEnumValList $enumList enumValList
    set enumsArray(udf,countertype)    $enumValList

    set enumList [list udfCascadeNone udfCascadeFromPrevious udfCascadeFromSelf]          
    setEnumValList $enumList enumValList
    set enumsArray(udf,cascadeType)    $enumValList

    set enumList [list formatTypeHex formatTypeAscii formatTypeBinary formatTypeDecimal	\
					   formatTypeMAC formatTypeIPv4 formatTypeIPv6 formatTypeCustom]          
    setEnumValList $enumList enumValList
    set enumsArray(tableUdfColumn,formatType)    $enumValList

    set enumList [list udfNone udf1 udf2 udf3 udf4 udf5]          
    setEnumValList $enumList enumValList
    set enumsArray(udf,chainFrom)    $enumValList


    return $retCode
}


########################################################################
# Procedure: createFrameRelayEnums
#
# This command creates Frame Relay enums
# Arguments(s):
# Returned Result:
#
########################################################################
proc scriptGen::createFrameRelayEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list twoByteAddress threeByteAddress fourByteAddress]  
    setEnumValList $enumList enumValList
    set enumsArray(frameRelay,addressSize)    $enumValList


    set enumList [list frameRelayIncrement	frameRelayContIncrement	frameRelayDecrement\
                       frameRelayContDecrement frameRelayIdle frameRelayRandom]  
    setEnumValList $enumList enumValList
    set enumsArray(frameRelay,counterMode)    $enumValList

    return $retCode
}

########################################################################
# Procedure: createVlanEnums
#
# This command creates vlan enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createVlanEnums { } \
{
#VLAN
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list vIdle vIncrement vDecrement vContIncrement vContIncrement    \
                       vContDecrement vCtrRandom vNestedIncrement vNestedDecrement]
    setEnumValList $enumList enumValList
    set enumsArray(vlan,mode)    $enumValList    

    set enumList [list resetCFI setCFI]
    setEnumValList $enumList enumValList
    set enumsArray(vlan,cfi)    $enumValList


    set enumList [list vlanProtocolTag8100 vlanProtocolTag9100 vlanProtocolTag9200]
    setEnumValList $enumList enumValList
    set enumsArray(vlan,protocolTagId)    $enumValList

    return $retCode
}    


########################################################################
# Procedure: createIslEnums
#
# This command creates ISI enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createIslEnums { } \
{
#ISL
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list islFrameEthernet islFrameTokenRing islFrameFDDI \
                       islFrameATM] 
    setEnumValList $enumList enumValList
    set enumsArray(isl,frameType)    $enumValList   
    return $retCode
}


########################################################################
# Procedure: createProtocolEnums
#
# This command creates protocol enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createProtocolEnums { } \
{
#Protocol
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list mac ipV4 ipx ipV6 pauseControl fcoe nativeFc ]
    setEnumValList $enumList enumValList
    set enumsArray(protocol,name)    $enumValList  

    set enumList [list Udp Arp Rip Dhcp SrpArp SrpIps SrpDiscovery RprTopology \
					   RprProtection RprOam noType Ptp]
    setEnumValList $enumList enumValList
    set enumsArray(protocol,appName)    $enumValList  

    set enumList [list noType ethernetII ieee8023snap ieee8023 ieee8022 protocolOffsetType]
    setEnumValList $enumList enumValList
    set enumsArray(protocol,ethernetType)    $enumValList

    set enumList [list vlanNone vlanSingle vlanStacked]
    setEnumValList $enumList enumValList
    set enumsArray(protocol,enable802dot1qTag)    $enumValList

	# Other protocols

	# Pause Control
    set enumList [list ieee8023x ieee8021Qbb ]
    setEnumValList $enumList enumValList
    set enumsArray(pauseControl,pauseControlType)    $enumValList

    return $retCode
}  

########################################################################
# Procedure: createPortEnums
#
# This command creates port enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createPortEnums { } \
{
#Port
    variable enumsArray
    variable oddParamsList

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list portAdvertiseNone portAdvertiseSend portAdvertiseSendAndReceive \
                       portAdvertiseSendAndOrReceive]                     
    setEnumValList $enumList enumValList
    set enumsArray(port,advertiseAbilities)    $enumValList      

    set enumList [list useGap usePercentRate]
    setEnumValList $enumList enumValList
    set enumsArray(port,rateMode)    $enumValList   
    
    set enumList [list portRxModeNone portCapture portPacketGroup portRxTcpSessions portRxTcpRoundTrip \
                       portRxDataIntegrity portRxFirstTimeStamp portRxSequenceChecking  \
                       portRxModeBert portRxModeBertChannelized portRxModeDcc portRxModeEcho \
					   portRxModeIsl portRxModeWidePacketGroup portRxModePrbs portRxModeRateMonitoring portRxModePerFlowErrorStats]
    setEnumValList $enumList enumValList
    set enumsArray(port,receiveMode)    $enumValList   

    set enumList [list portTxPacketStreams portTxPacketFlows portTxTcpSessions portTxTcpRoundTrip \
                       portTxModeAdvancedScheduler portTxModeBert portTxModeBertChannelized \
                       portTxModeDccStreams portTxModeDccAdvancedScheduler portTxModeDccFlowsSpeStreams \
                       portTxModeDccFlowsSpeAdvancedScheduler portTxModeEcho \
                       portTxModeAdvancedSchedulerCoarse portTxModePacketStreamsCoarse]
    setEnumValList $enumList enumValList
    set enumsArray(port,transmitMode)    $enumValList   
          
    lappend oddParamsList [list port receiveMode ]

    set enumList [list half full]
    setEnumValList $enumList enumValList
    set enumsArray(port,duplex)    $enumValList 

    set enumList [list preEmphasis0  preEmphasis18 preEmphasis10 preEmphasis20 \
					   preEmphasis25 preEmphasis33 preEmphasis38 preEmphasis75]
    setEnumValList $enumList enumValList
    set enumsArray(port,preEmphasis)    $enumValList 

    set enumList [list portMaster portSlave]
    setEnumValList $enumList enumValList
    set enumsArray(port,masterSlave)    $enumValList 
    
    set enumList [list gigNormal gigLoopback gigCableDisconnect]
    setEnumValList $enumList enumValList
    set enumsArray(port,rxTxMode)    $enumValList 

    set enumList [list portNormal portLoopback portLineLoopback]
    setEnumValList $enumList enumValList
    set enumsArray(port,loopback)    $enumValList 

    set enumList [list portPosMode	portEthernetMode portUsbMode port10GigLanMode portBertMode \
					   port10GigWanMode portAtmMode portPosChannelizedMode ]
    setEnumValList $enumList enumValList
    set enumsArray(port,portMode)       $enumValList 

    set enumList [list cardClockInternal cardClockExternal]
    setEnumValList $enumList enumValList
    set enumsArray(card,clockSelect)    $enumValList 

    set enumList [list xauiClockInternal xauiClockExternal]
    setEnumValList $enumList enumValList
    set enumsArray(xaui,clockType)    $enumValList 

    set enumList [list xauiPowerOff xauiPowerOn]
    setEnumValList $enumList enumValList
    set enumsArray(xaui,podPower)     $enumValList 
    set enumsArray(xaui,userPower)    $enumValList 

    set enumList [list xauiExtraClockOff xauiExtraClockOn]
    setEnumValList $enumList enumValList
    set enumsArray(xaui,extraClockExternal1)    $enumValList 
    set enumsArray(xaui,extraClockExternal2)    $enumValList 

    set enumList [list portPhyModeCopper portPhyModeFiber portPhyModeSgmii]
    setEnumValList $enumList enumValList
    set enumsArray(port,phyMode)    $enumValList 

    set enumList [list pmaClockAutoNegotiate pmaClockMaster pmaClockSlave]
    setEnumValList $enumList enumValList
    set enumsArray(port,pmaClock)    $enumValList 

    set enumList [list portAutoInstrumentationModeEndOfFrame portAutoInstrumentationModeFloating]
    setEnumValList $enumList enumValList
    set enumsArray(port,autoDetectInstrumentationMode)    $enumValList

    set enumList [list ieee8023x ieee8021Qbb]
    setEnumValList $enumList enumValList
    set enumsArray(port,flowControlType)    $enumValList

	set enumList [list portOperationModeStream portOperationModeRtp portOperationModeTsoLro portOperationModeL7 portOperationModeHWIPsec portOperationModeFCoEOffload]
	setEnumValList $enumList enumValList
	set enumsArray(port,operationModeList) $enumValList
	
	set enumList [list fourPriorityTrafficMapping eightPriorityTrafficMapping]
	setEnumValList $enumList enumValList
	set enumsArray(port,dataCenterMode) $enumValList

    set enumList [list portClockInternal portClockExternal]
    setEnumValList $enumList enumValList
    set enumsArray(port,transmitClockMode)    $enumValList 
    
    lappend oddParamsList [list port operationModeList ]
	
    lappend oddParamsList [list protocolServer enableBgp4CreateInterface enableIsisCreateInterface enableOspfCreateInterface \
                            enableRipCreateInterface enableRsvpCreateInterface enableIgmpCreateInterface]

    set enumList [list false]
    setEnumValList $enumList enumValList
    set enumsArray(protocolServer,enableBgp4CreateInterface)    $enumValList 
	set enumsArray(protocolServer,enableIsisCreateInterface)    $enumValList 
	set enumsArray(protocolServer,enableOspfCreateInterface)    $enumValList 
	set enumsArray(protocolServer,enableRipCreateInterface)     $enumValList 
	set enumsArray(protocolServer,enableRsvpCreateInterface)    $enumValList
	set enumsArray(protocolServer,enableIgmpCreateInterface)    $enumValList 


    return $retCode
}


########################################################################
# Procedure: createSonetEnums
#
# This command create sonet enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createSonetEnums { } \
{
#SONET
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list sonetNoClock sonetRecoveredClock sonetExternalClock]
    setEnumValList $enumList enumValList
    set enumsArray(sonet,useRecoveredClock)    $enumValList   
    
    set enumList [list oc3 oc12 stm1c stm4c oc48 stm16c oc192 stm64c ethOverSonet ethOverSdh]
    setEnumValList $enumList enumValList
    set enumsArray(sonet,interfaceType)    $enumValList               

    set enumList [list sonetCrc16 sonetCrc32]
    setEnumValList $enumList enumValList
    set enumsArray(sonet,rxCrc)    $enumValList 
    set enumsArray(sonet,txCrc)    $enumValList 

    set enumList [list sonetHdlcPppIp sonetCiscoHdlc sonetOther \
                       sonetFrameRelay2427  sonetFrameRelayCisco sonetSrp \
                       sonetCiscoHdlcIpv6 sonetHdlcPppIso sonetRpr sonetAtm sonetGfp]
    setEnumValList $enumList enumValList
    set enumsArray(sonet,header)    $enumValList 

    set enumList [list hecSeed0x0000 hecSeed0xffff]
    setEnumValList $enumList enumValList
    set enumsArray(sonet,rprHecSeed)   $enumValList               

    set enumList [list sonetMapSpe sonetMapDcc]
    setEnumValList $enumList enumValList
    set enumsArray(sonet,trafficMap)   $enumValList

    set enumList [list sonetNormal sonetLoopback sonetLineLoopback sonetFramerParallelDiagnosticLoopback \
                       sonetFramerDiagnosticLoopback sonetFecDiagnosticLoopback sonetFecLineLoopback ] 
    setEnumValList $enumList enumValList
    set enumsArray(sonet,operation)    $enumValList 
    return $retCode
}


########################################################################
# Procedure: createPppEnums
#
# This command create ppp enums
# Arguments(s):
# Returned Result:
#
########################################################################
proc scriptGen::createPppEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list pppIpV6LocalNegotiationLocalMay pppIpV6LocalNegotiationLocalMust \
				       pppIpV6LocalNegotiationPeerMust]
    setEnumValList $enumList enumValList
    set enumsArray(ppp,localIpV6NegotiationMode)    $enumValList   
    
    set enumList [list pppIpV6PeerNegotiationPeerMay pppIpV6PeerNegotiationPeerMust \
				       pppIpV6PeerNegotiationLocalMust]
    setEnumValList $enumList enumValList
    set enumsArray(ppp,peerIpV6NegotiationMode)    $enumValList   

    set enumList [list pppIpV6IdTypeLastNegotiated pppIpV6IdTypeMacBased \
				       pppIpV6IdTypeIpV6 pppIpV6IdTypeRandom]
    setEnumValList $enumList enumValList
    set enumsArray(ppp,localIpV6IdType) $enumValList   
    set enumsArray(ppp,peerIpV6IdType)	$enumValList   

    return $retCode
}

########################################################################
# Procedure: createFilterEnums
#
# This command creates filter enums
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
#
########################################################################

proc scriptGen::createFilterEnums {chassis card port } \
{
#Filter
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list anyAddr addr1 notAddr1 addr2 notAddr2]
    setEnumValList $enumList enumValList
    set enumsArray(filter,captureTriggerDA)         $enumValList       
    set enumsArray(filter,captureTriggerSA)         $enumValList 
    set enumsArray(filter,captureFilterDA)          $enumValList 
    set enumsArray(filter,captureFilterSA)          $enumValList 
    set enumsArray(filter,userDefinedStat1DA)       $enumValList 
    set enumsArray(filter,userDefinedStat1SA)       $enumValList 
    set enumsArray(filter,userDefinedStat2DA)       $enumValList 
    set enumsArray(filter,userDefinedStat2SA)       $enumValList 
    set enumsArray(filter,asyncTrigger1DA)          $enumValList 
    set enumsArray(filter,asyncTrigger1SA)          $enumValList 
    set enumsArray(filter,asyncTrigger2DA)          $enumValList 
    set enumsArray(filter,asyncTrigger2SA)          $enumValList 


    set enumList [list anyPattern pattern1 notPattern1 pattern2 \
                       notPattern2 pattern1AndPattern2] 
    setEnumValList $enumList enumValList
    set enumsArray(filter,captureTriggerPattern)    $enumValList       
    set enumsArray(filter,captureFilterPattern)     $enumValList 
    set enumsArray(filter,userDefinedStat1Pattern)  $enumValList 
    set enumsArray(filter,userDefinedStat2Pattern)  $enumValList 
    set enumsArray(filter,asyncTrigger1Pattern)     $enumValList 
    set enumsArray(filter,asyncTrigger2Pattern)     $enumValList 

    set enumList {}
	set  enumFilterErrorsCommon		[list errAnyFrame errGoodFrame errBadCRC errBadFrame]
	set  enumFilterErrors10_100		[list errAlign errDribble errBadCRCAlignDribble]
	set	 enumFilterErrorsGigabit	[list errAnyFrame errGoodFrame errBadCRC errBadFrame errLineError errLineAndBadCRC errLineAndGoodCRC]
	set  enumSequenceAndIntegrityErrors	 [list errAnySequenceError errSmallSequenceError errBigSequenceError errReverseSequenceError errDataIntegrityError]
	
	if {[IsGigabitPort  $chassis $card $port] && ![port isValidFeature $chassis $card $port $::portFeatureLocalCPU]} {
		set enumList $enumFilterErrorsGigabit
	
	} else {
		set enumList $enumFilterErrorsCommon
	
		if {[port isActiveFeature $chassis $card $port $::portFeatureRxSequenceChecking] || \
			[port isActiveFeature $chassis $card $port $::portFeatureRxDataIntegrity]} {
			set enumList [join [lappend enumList $enumSequenceAndIntegrityErrors]]
		} else {
			set enumList [join [lappend enumList $enumFilterErrors10_100]]
		}		
	
	}	
	if {[port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode]} {
		lappend enumList errFcoeInvalidFrame
	}

    setEnumValList $enumList enumValList
    set enumsArray(filter,captureTriggerError)    $enumValList       
    set enumsArray(filter,captureFilterError)     $enumValList 
    set enumsArray(filter,userDefinedStat1Error)  $enumValList 
    set enumsArray(filter,userDefinedStat2Error)  $enumValList 
    set enumsArray(filter,asyncTrigger1Error)     $enumValList 
    set enumsArray(filter,asyncTrigger2Error)     $enumValList 


    set enumList [list filterAnyCircuit filterCircuitList ]
    setEnumValList $enumList enumValList
    set enumsArray(filter,captureTriggerCircuit)	$enumValList       
    set enumsArray(filter,captureFilterCircuit)		$enumValList 
    set enumsArray(filter,userDefinedStat1Circuit)  $enumValList 
    set enumsArray(filter,userDefinedStat2Circuit)  $enumValList 
    set enumsArray(filter,asyncTrigger1Circuit)		$enumValList 
    set enumsArray(filter,asyncTrigger2Circuit)		$enumValList 

    return $retCode
}


########################################################################
# Procedure: createStatModeEnums
#
# This command creates stats mode enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createStatModeEnums { } \
{
#Stat Mode
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list statNormal statQos statStreamTrigger     \
                       statModeChecksumErrors statModeDataIntegrity]
    setEnumValList $enumList enumValList
    set enumsArray(stat,mode)    $enumValList 

    set enumList [list statFcoeInvalidDelimiter statFcoeInvalidFrames statFcoeInvalidSize     \
                       statFcoeNormalSizeBadFccRc statFcoeNormalSizeGoodFccRc \
					   statFcoeUndersizeBadFccRc statFcoeUndersizeGoodFccRc statFcoeValidFrames]
    setEnumValList $enumList enumValList
    set enumsArray(stat,fcoeRxSharedStatType1)    $enumValList
    set enumsArray(stat,fcoeRxSharedStatType2)    $enumValList

    return $retCode
}



########################################################################
# Procedure: createPacketGroupEnums
#
# This command creates packet group enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createPacketGroupEnums { } \
{
#Packet Group
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list cutThrough storeAndForward storeAndForwardPreamble interArrivalJitter firstInLastOut lastInLastOut]
    setEnumValList $enumList enumValList
    set enumsArray(packetGroup,latencyControl)    $enumValList 

    set enumList [list packetGroupModeLatency packetGroupModeInterArrivalTime packetGroupModeDelayVariation]
    setEnumValList $enumList enumValList
    set enumsArray(packetGroup,measurementMode)    $enumValList 

    set enumList [list delayVariationWithSequenceErrors delayVariationWithLatencyAvg delayVariationWithLatencyMinMax]
    setEnumValList $enumList enumValList
    set enumsArray(packetGroup,delayVariationMode)    $enumValList 

    set enumList [list packetGroupCustom packetGroupDscp packetGroupIpV6TrafficClass \
                       packetGroupMplsExp packetGroupSplit ]
    setEnumValList $enumList enumValList
    set enumsArray(packetGroup,groupIdMode)    $enumValList 

    set enumList [list seqThreshold seqMultiSwitchedPath seqAdvTracking]
    setEnumValList $enumList enumValList
    set enumsArray(packetGroup,sequenceCheckingMode)    $enumValList 

    set enumList [list seqSwitchedPathPGID seqSwitchedPathDuplication]
    setEnumValList $enumList enumValList
    set enumsArray(packetGroup,multiSwitchedPathMode)    $enumValList 

    set enumList [list splitPgidStartOfFrame splitPgidOffsetFromSignature]
    setEnumValList $enumList enumValList
    set enumsArray(splitPacketGroup,groupIdOffsetBaseType)    $enumValList 

    set enumList [list dataIntegrityNumberOfBytesFromEndOfFrame dataIntegrityPayloadLength]
    setEnumValList $enumList enumValList
    set enumsArray(dataIntegrity,floatingTimestampAndDataIntegrityMode)    $enumValList 

    return $retCode
}   

########################################################################
# Procedure: createInterfaceEntryEnums
#
# This command creates Interface Entry enums
# Arguments(s):
# Returned Result:
#
########################################################################
proc scriptGen::createInterfaceEntryEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList    [list atmEncapsulationNone \
						  atmEncapsulationVccMuxIPV4Routed \
						  atmEncapsulationVccMuxBridgedEthernetFCS \
						  atmEncapsulationVccMuxBridgedEthernetNoFCS \
				          atmEncapsulationVccMuxIPV6Routed \
				          atmEncapsulationVccMuxMPLSRouted \
				          atmEncapsulationLLCRoutedCLIP \
						  atmEncapsulationLLCBridgedEthernetFCS \
						  atmEncapsulationLLCBridgedEthernetNoFCS \
						  atmEncapsulationLLCPPPoA \
						  atmEncapsulationVccMuxPPPoA \
						  atmEncapsulationLLCNLPIDRouted]
    setEnumValList $enumList enumValList
    set enumsArray(interfaceEntry,atmEncapsulation)    $enumValList 
    set enumsArray(ipAddressTableItem,atmEncapsulation)    $enumValList 

    set enumList [list atmRouted atmBridged]   
    setEnumValList $enumList enumValList
    set enumsArray(interfaceEntry,atmMode)    $enumValList 
    #set enumsArray(ipAddressTableItem,atmMode)    $enumValList 


	set enumList [list interfaceTypeConnected \
					   interfaceTypeGre \
					   interfaceTypeRouted \
					   interfaceTypeNpiv ]
    setEnumValList $enumList enumValList
    set enumsArray(interfaceEntry,interfaceType)    $enumValList

    return $retCode
} 

########################################################################
# Procedure: createBertEnums
#
# This command creates Bert enums
# Arguments(s):
# Returned Result:
#
########################################################################

proc scriptGen::createBertEnums { } \
{
    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list bertPatternAllZero bertPatternAlternatingOneZero      bertPatternUserDefined \
                       bertPattern2_31    bertPattern2_11 bertPattern2_15 bertPattern2_20 \
                       bertPattern2_23 bertPatternAutoDetect bertPattern2_7 bertPattern2_9 bertPatternLaneDetect]                    
    
    setEnumValList $enumList enumValList
    set enumsArray(bert,txPatternIndex)  $enumValList
    set enumsArray(bert,rxPatternIndex)  $enumValList
    

    set enumList [list bertTxRxCoupled bertTxRxIndependent]
    
    setEnumValList $enumList enumValList
    set enumsArray(bert,txRxPatternMode)  $enumValList


    set enumList [list bert_1e2 bert_1e3 bert_1e4 bert_1e5 bert_1e6 bert_1e7 bert_1e8 bert_1e9 bert_1e10 \
                 bert_1e11 bertUserDefined]
                 
    
    setEnumValList $enumList enumValList
    set enumsArray(bertErrorGeneration,errorBitRate)  $enumValList

    set enumList [list bertUnframedOc3 bertUnframedOc12 bertUnframedOc48 bertUnframedOc3WithFec \
    bertUnframedOc12WithFec bertUnframedOc48WithFec bertUnframedGigEthernet bertUnframedFiberChannel1 \
    bertUnframedFiberChannel2 bertUnframed1x bertUnframed4x bertUnframed8x bertUnframed16x]
    
    setEnumValList $enumList enumValList
    set enumsArray(bertUnframed,dataRate)  $enumValList

    set enumList [list bertUnframedNormal bertUnframedDiagnosticLoopback bertUnframedLineLoopback]
    
    setEnumValList $enumList enumValList
    set enumsArray(bertUnframed,operation)  $enumValList


    return $retCode
}

########################################################################
# Procedure: createCaptureEnums
#
# Description: This command creates Capture enums
#
# Arguments(s):
#
# Result:   Always returns 0
#
########################################################################
proc scriptGen::createCaptureEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list captureContinuousMode captureTriggerMode]   
    setEnumValList $enumList enumValList
    set enumsArray(capture,captureMode)  $enumValList

    set enumList [list captureContinuousAll captureContinuousFilter]  
    setEnumValList $enumList enumValList
    set enumsArray(capture,continuousFiltter)  $enumValList

    set enumList [list captureBeforeTriggerAll captureBeforeTriggerNone captureBeforeTriggerFilter]   
    setEnumValList $enumList enumValList
    set enumsArray(capture,beforeTriggerFilter)  $enumValList

    set enumList [list captureAfterTriggerAll captureAfterTriggerFilter captureAfterTriggerConditionFilter]   
    setEnumValList $enumList enumValList
    set enumsArray(capture,afterTriggerFilter)  $enumValList

    set enumList [list lock wrap]   
    setEnumValList $enumList enumValList
    set enumsArray(capture,fullAction)  $enumValList
   
    return $retCode
}

########################################################################
# Procedure: createCollisionBackoffEnums
#
# Description: This command creates CollisionBackoff enums
#
# Arguments(s):
#
# Result:   Always returns 0
#
########################################################################
proc scriptGen::createCollisionBackoffEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list backoffConstant_0 backoffConstant_2 backoffConstant_4 backoffConstant_8 \
                    backoffConstant_16 backoffConstant_32 backoffConstant_64 backoffConstant_128 \
                    backoffConstant_256 backoffConstant_512 backoffConstant_1024 ]
    setEnumValList $enumList enumValList
    set enumsArray(collisionBackoff,random)  $enumValList

    return $retCode
}


########################################################################
# Procedure: createQosEnums
#
# Description: This command creates Qos enums
#
# Arguments(s):
#
# Result:   Always returns 0
#
########################################################################
proc scriptGen::createQosEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list ipEthernetII ip8023Snap vlan custom ipPpp ipCiscoHdlc] 
    setEnumValList $enumList enumValList
    set enumsArray(qos,packetType)  $enumValList

    set enumList [list qosOffsetStartOfFrame qosOffsetStartOfIp \
					   qosOffsetStartOfProtocol qosOffsetStartOfSonet] 
    setEnumValList $enumList enumValList
    set enumsArray(qos,patternOffsetType)  $enumValList

    return $retCode
}


########################################################################
# Procedure: createSonetErrorEnums
#
# Description: This command creates sonetError enums
#
# Arguments(s):
#
# Result:   Always returns 0
#
########################################################################
proc scriptGen::createSonetErrorEnums { } \
{

    variable enumsArray

    set retCode 0
    set enumValList {}
    set enumList    {}

    set enumList [list sonetGlobalErrorEnable sonetLofError sonetBip1Error sonetBip2Error \
                    sonetBip3Error sonetLineAis sonetLineRei sonetLineRdi sonetPathLop \
                    sonetPathAis sonetPathRei sonetPathRdi sonetLosError]
    setEnumValList $enumList enumValList
    set enumsArray(sonetError,sonetErrorType)  $enumValList

    set enumList [list sonetContinuous sonetPeriodic sonetOff]
    setEnumValList $enumList enumValList
    set enumsArray(sonetError,insertionMode)  $enumValList

    set enumList [list sonetFrames sonetSeconds]
    setEnumValList $enumList enumValList
    set enumsArray(sonetError,errorUnits)  $enumValList

#VsrError Enums
    set enumList [list vsrErrorSingleChannelMode vsrErrorMultiChannelMode]
    setEnumValList $enumList enumValList
    set enumsArray(vsrError,channelSkewMode)  $enumValList

    set enumList [list vsrErrorInsertNone vsrErrorInsertContinuously vsrErrorMomentarily]
    setEnumValList $enumList enumValList
    set enumsArray(vsrError,bipInsertionMode)               $enumValList
    set enumsArray(vsrError,crcInsertionMode)               $enumValList
    set enumsArray(vsrError,frameDelimiterInsertionMode)    $enumValList
    set enumsArray(vsrError,channelSkewInsertionMode)       $enumValList
    set enumsArray(vsrError,error8b10bInsertionMode)        $enumValList

#FecError enums

    set enumList [list fecSingleErrorInjection fecErrorRateInjection fecBurstErrorInjection]
    setEnumValList $enumList enumValList
    set enumsArray(fecError,injectionMode)  $enumValList

	set enumList [list  fecRate_0996_e02_correctable fecRate_1001_e03_correctable fecRate_1001_e04_correctable  \
		                fecRate_1001_e05_correctable fecRate_1000_e06_correctable fecRate_1000_e07_correctable  \
                        fecRate_1000_e08_correctable fecRate_1000_e09_correctable fecRate_1000_e10_correctable  \
		                fecRate_1000_e11_correctable fecRate_1000_e12_correctable fecRate_0960_e02_uncorrectable    \
		                fecRate_1000_e03_uncorrectable fecRate_1000_e04_uncorrectable fecRate_1000_e05_uncorrectable    \
		                fecRate_1000_e06_uncorrectable fecRate_1000_e07_uncorrectable fecRate_1000_e08_uncorrectable    \
		                fecRate_1000_e09_uncorrectable fecRate_1000_e10_uncorrectable ]
    setEnumValList $enumList enumValList
    set enumsArray(fecError,errorRate)  $enumValList

    return $retCode
}

########################################################################
# Procedure:    createSonetCircuitEnums
#
# Description:  Creates Sonet Circuit enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createSonetCircuitEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

	# lcas 
    #set enumList    [list lcasSourceIdle lcasSourceNorm lcasSourceDnu lcasSourceAdd lcasSourceRemove]
    #setEnumValList  $enumList enumValList
    #set enumsArray(lcas,sourceSideState) $enumValList

    #set enumList    [list lcasSinkOk lcasSinkFail]
    #setEnumValList  $enumList enumValList
    #set enumsArray(lcas,sinkSideState) $enumValList


	# sonetCircuit
    set enumList    [list circuitUnidirectionTx circuitUnidirectionRx circuitBidirectionSymmetrical\
					 circuitBidirectionAsymmetrical ]
    setEnumValList  $enumList enumValList
    set enumsArray(sonetCircuit,direction) $enumValList

    set enumList    [list circuitPayloadRateSTS1 circuitPayloadRateSTS3c  circuitPayloadRateSTS12c  circuitPayloadRateSTS48c \
						  circuitPayloadRateSTM_0 circuitPayloadRateSTM_1 circuitPayloadRateSTM_4 circuitPayloadRateSTM_16 \
						  circuitPayloadRateSTS1mv circuitPayloadRateSTS3cmv circuitPayloadRateVC3mv circuitPayloadRateVC4mv]
    setEnumValList  $enumList enumValList
    set enumsArray(sonetCircuit,txType) $enumValList
    set enumsArray(sonetCircuit,rxType) $enumValList
  

	# sonetCircuitProperties
    set enumList    [list circuitTxModePacketStreams circuitTxModeAdvancedScheduler ]
    setEnumValList  $enumList enumValList
    set enumsArray(sonetCircuitProperties,transmitMode) $enumValList

    set enumList    [list sonetHdlcPppIp sonetCiscoHdlc sonetOther sonetFrameRelay1490 sonetFrameRelayCisco sonetGfp sonetLaps ]
    setEnumValList  $enumList enumValList
    set enumsArray(sonetCircuitProperties,payloadType) $enumValList
	
    set enumList    [list sonetCrc16 sonetCrc32 ]
    setEnumValList  $enumList enumValList
    set enumsArray(sonetCircuitProperties,rxCrc) $enumValList
    set enumsArray(sonetCircuitProperties,txCrc) $enumValList


    return $retCode
}



########################################################################
# Procedure:    createSfpPlusEnums
#
# Description:  Creates SfpPlus enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createSfpPlusEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

    set enumList    [list sfpPlus10GBaseSrLr sfpPlus10GBaseLrm sfpPlusCu]
    setEnumValList  $enumList enumValList
    set enumsArray(sfpPlus,transceiverType) $enumValList

    return $retCode
}

########################################################################
# Procedure:    createDcbxEnums
#
# Description:  Creates DCBX enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createDcbxEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    
    set enumList    [list lldpPortIdMacAddress lldpPortIdInterfaceName]
    setEnumValList  $enumList enumValList
    set enumsArray(lldpPortId,subType) $enumValList
    
    set enumList    [list protocolIdFcoe protocolIdFip]
    setEnumValList  $enumList enumValList
    set enumsArray(dcbxFcoeFeature,applicationProtocolId) $enumValList

    set enumList    [list protocolIdIscsi]
    setEnumValList  $enumList enumValList
    set enumsArray(dcbxIscsiFeature,applicationProtocolId) $enumValList
    
    set enumList    [list logicalLinkDown logicalLinkUp]
    setEnumValList  $enumList enumValList
    set enumsArray(dcbxLogicalLinkFeature,logicalLinkStatus) $enumValList
    
    set enumList    [list dcbxSubTypeIntel10 dcbxSubTypeIeee101]
    setEnumValList  $enumList enumValList
    set enumsArray(dcbxProperties,dcbxSubType) $enumValList
    
    return $retCode
}


########################################################################
# Procedure:    createPcsLaneErrorEnums
#
# Description:  Creates PcsLaneError enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createPcsLaneErrorEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    
    set enumList    [list pcsLaneErrorPeriodTypeLaneMarkers	pcsLaneErrorPeriodTypeLaneMarkersAndPayload]
    setEnumValList  $enumList enumValList
    set enumsArray(pcsLaneError,periodType) $enumValList
        
    return $retCode
}


########################################################################
# Procedure:    createDccEnums
#
# Description:  Creates Dcc enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createDccEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

    set enumList    [list dccSoh dccLoh]
    setEnumValList  $enumList enumValList
    set enumsArray(dcc,overheadBytes) $enumValList

    set enumList    [list dccCrc16 dccCrc32]
    setEnumValList  $enumList enumValList
    set enumsArray(dcc,crc) $enumValList

    set enumList    [list dccTimeFillFlag7E dccTimeFillMarkIdle]
    setEnumValList  $enumList enumValList
    set enumsArray(dcc,timeFill) $enumValList

    return $retCode
}


########################################################################
# Procedure:    createOpticalDigitalWrapperEnums
#
# Description:  Creates Optical Digital Wrapper enums. (Part of Fec)
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createOpticalDigitalWrapperEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

    set enumList    [list optDigWrapperPayloadType02 optDigWrapperPayloadType03 \
						  optDigWrapperPayloadType04 optDigWrapperPayloadType05	\
						  optDigWrapperPayloadType10 optDigWrapperPayloadType11 \
						  optDigWrapperPayloadTypeFE ]

    setEnumValList  $enumList enumValList
    set enumsArray(opticalDigitalWrapper,payloadType) $enumValList

    return $retCode
}


########################################################################
# Procedure:    createFlexibleTimestampEnums
#
# Description:  Creates FlexibleTimestamp enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createFlexibleTimestampEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

    set enumList    [list timestampBeforeCrc timestampAtOffset]
    setEnumValList  $enumList enumValList
    set enumsArray(flexibleTimestamp,type) $enumValList

    return $retCode
}


########################################################################
# Procedure:    createSrpEnums
#
# Description:  Creates Srp enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createSrpEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

    set controlCommandList {srp srpArp srpDiscovery srpIps srpUsage}
    
    foreach commandItem $controlCommandList { 
        # Priority
        set enumList    [list srpPriority0 srpPriority1 srpPriority2 srpPriority3 \
                              srpPriority4 srpPriority5 srpPriority6 srpPriority7]
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,priority) $enumValList

        # Mode
        set enumList    [list srpModeReserved000 srpModeReserved001 srpModeReserved010 \
                              srpModeATMCell srpModeControlMessage1 srpModeControlMessage2 \
                              srpModeUsageMessage srpModePacketData]
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,mode) $enumValList

        # Ring Identifier
        set enumList    [list srpRingIdentifierOuter srpRingIdentifierInner]
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,ringIdentifier) $enumValList

        # Parity Bit <really, this is enable odd parity badly named>
        set enumList    [list srpParityBitEven srpParityBitOdd]
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,parityBit) $enumValList
    }

    # Mac Binding Wrapped Node
    set enumList    [list srpWrappedNode srpUnwrappedNode]
    setEnumValList  $enumList enumValList
    set enumsArray(srpMacBinding,wrappedNode) $enumValList

    # IPS Request Type
    set enumList    [list srpIpsRequestTypeNoRequest srpIpsRequestTypeWaitToRestore \
                          srpIpsRequestTypeManualSwitch srpIpsRequestTypeSignalDegrade \
                          srpIpsRequestTypeSignalFail	srpIpsRequestTypeForcedSwitch]
    setEnumValList  $enumList enumValList
    set enumsArray(srpIps,requestType) $enumValList

    # IPS Path Indicator
    set enumList    [list srpIpsPathIndicatorShort srpIpsPathIndicatorLong]
    setEnumValList  $enumList enumValList
    set enumsArray(srpIps,pathIndicator) $enumValList

    # IPS Status Code
    set enumList    [list srpIpsStatusCodeIdle srpIpsStatusCodeProtection]
    setEnumValList  $enumList enumValList
    set enumsArray(srpIps,statusCode) $enumValList

    # IPS Checksum mode
    set enumList    [list srpIpsCheckSumBad srpIpsCheckSumGood]
    setEnumValList  $enumList enumValList
    set enumsArray(srpIps,controlCheckSumMode) $enumValList

    return $retCode
}

########################################################################
# Procedure:    createRprEnums
#
# Description:  Creates Rpr enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createRprEnums { } \
{
     variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

    set controlCommandList {rprFairness rprRingControl}
    
    foreach commandItem $controlCommandList { 
        set enumList    [list rprRinglet0 rprRinglet1]
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,ringIdentifier) $enumValList

        set enumList    [list rprIdlePacket rprControlPacket rprFairnessPacket rprDataPacket]
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,packetType) $enumValList

        set enumList    [list rprServiceClassC rprServiceClassB rprServiceClassA1 rprServiceClassA0]
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,serviceClass) $enumValList

        set enumList    [list rprFfNoFlood rprFfUnidirectionalFlood rprFfBidirectionalFlood rprFfReserved ]  
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,floodingForm) $enumValList
    }


    # Fairness
    set enumList    [list rprSingleChoke rprMultiChoke]
    setEnumValList  $enumList enumValList
    set enumsArray(rprFairness,messageType) $enumValList

    # RPR Oam
    set enumList    [list rprOamFlush rprOamEchoRequest rprOamEchoResponse rprOamVendorSpecific]
    setEnumValList  $enumList enumValList
    set enumsArray(rprOam,typeCode) $enumValList

    set enumList    [list rprOamReplyOnDefault rprOamReplyOnRinglet0 rprOamReplyOnRinglet1 rprOamReplyReserved]
    setEnumValList  $enumList enumValList
    set enumsArray(rprOam,responseRinglet) $enumValList
    set enumsArray(rprOam,requestRinglet)  $enumValList

    set enumList    [list rprOamProtected rprOamUnProtected]
    setEnumValList  $enumList enumValList
    set enumsArray(rprOam,responseProtectionMode) $enumValList
    set enumsArray(rprOam,requestProtectionMode)  $enumValList


    # Protection 
    set enumList    [list rprNoRequest rprSignalDegrade rprManualSwitch rprWaitToRestore rprForcedSwitch rprSignalFail]
    setEnumValList  $enumList enumValList
    set enumsArray(rprProtection,protectionRequestEast) $enumValList
    set enumsArray(rprProtection,protectionRequestWest) $enumValList


    # TLVs
    set enumList [list rprWeight rprTotalBandwidth rprStationName rprNeighborAddress \
                       rprIndividualBandwidth rprVendorSpecific]
    set commandList  [list rprTlvWeight rprTlvTotalBandwidth rprTlvStationName rprTlvNeighborAddress \
                           rprTlvIndividualBandwidth rprTlvVendorSpecific]

    foreach commandItem $commandList {
        setEnumValList  $enumList enumValList
        set enumsArray($commandItem,type) $enumValList
    }

    return $retCode
}

########################################################################
# Procedure:    createFilterPalleteEnums
#
# Description:  Creates FilterPallete enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createFilterPalletteEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

    set enumList    [list   matchIpEthernetII matchIp8023Snap matchVlan matchUser matchIpPpp matchIpCiscoHdlc \
        matchIpSAEthernetII matchIpDAEthernetII matchIpSADAEthernetII matchIpSA8023Snap \
        matchIpDA8023Snap matchIpSADA8023Snap matchIpSAPos matchIpDAPos matchIpSADAPos \
        matchTcpSourcePortIpEthernetII matchTcpDestPortIpEthernetII matchUdpSourcePortIpEthernetII \
        matchUdpDestPortIpEthernetII matchTcpSourcePortIp8023Snap matchTcpDestPortIp8023Snap \
        matchUdpSourcePortIp8023Snap matchUdpDestPortIp8023Snap matchTcpSourcePortIpPos \
        matchTcpDestPortIpPos matchUdpSourcePortIpPos matchUdpDestPortIpPos matchSrpModeReserved000 \
        matchSrpModeReserved001 matchSrpModeReserved010 matchSrpModeAtmCell011 matchSrpControlMessagePassToHost100 \
        matchSrpControlMessageBufferForHost101 matchSrpUsageMessage110 matchSrpPacketData111 \
        matchSrpAllControlMessages10x matchSrpUsageMessageOrPacketData11x matchSrpControlUsageOrPacketData1xx \
        matchSrpInnerRing matchSrpOuterRing matchSrpPriority0 matchSrpPriority1 matchSrpPriority2 \
        matchSrpPriority3 matchSrpPriority4 matchSrpPriority5 matchSrpPriority6 matchSrpPriority7 \
        matchSrpParityOdd matchSrpParityEven matchSrpDiscoveryFrame matchSrpIpsFrame  \
        matchRprRingId0 matchRprRingId1 matchRprFairnessEligibility0 matchRprFairnessEligibility1   \
        matchRprIdlePacket matchRprControlPacket matchRprFairnessPacket matchRprDataPacket matchRprServiceClassC   \
        matchRprServiceClassB matchRprServiceClassA1 matchRprServiceClassA0 matchRprWrapEligibility0 \
        matchRprWrapEligibility1 matchRprParityBit0 matchRprParityBit1 matchIpv6SAEthernetII matchIpv6DAEthernetII  \
        matchIpv6SA8023Snap matchIpv6DA8023Snap matchIpv6SAPos matchIpv6DAPos matchIpv6TcpSourcePortEthernetII  \
        matchIpv6TcpDestPortEthernetII matchIpv6UdpSourcePortEthernetII matchIpv6UdpDestPortEthernetII  \
        matchIpv6TcpSourcePort8023Snap matchIpv6TcpDestPort8023Snap matchIpv6UdpSourcePort8023Snap  \
        matchIpv6UdpDestPort8023Snap matchIpv6TcpSourcePortPos matchIpv6TcpDestPortPos matchIpv6UdpSourcePortPos \
        matchIpv6UdpDestPortPos matchIpv6IpTcpSourcePortEthernetII matchIpv6IpTcpDestPortEthernetII \
        matchIpv6IpUdpSourcePortEthernetII matchIpv6IpUdpDestPortEthernetII matchIpv6IpTcpSourcePort8023Snap    \
        matchIpv6IpTcpDestPort8023Snap matchIpv6IpUdpSourcePort8023Snap matchIpv6IpUdpDestPort8023Snap  \
        matchIpv6IpTcpSourcePortPos matchIpv6IpTcpDestPortPos matchIpv6IpUdpSourcePortPos matchIpv6IpUdpDestPortPos \
        matchIpOverIpv6IpSAEthernetII matchIpOverIpv6IpDAEthernetII matchIpOverIpv6IpSA8023Snap matchIpOverIpv6IpDA8023Snap \
        matchIpOverIpv6IpSAPos matchIpOverIpv6IpDAPos matchIpv6OverIpIpv6SAEthernetII matchIpv6OverIpIpv6DAEthernetII   \
        matchIpv6OverIpIpv6SA8023Snap matchIpv6OverIpIpv6DA8023Snap matchIpv6OverIpIpv6SAPos matchIpv6OverIpIpv6DAPos   \
        matchIpv6Ppp matchIpv6CiscoHdlc \
		matchGfpDataFcsNullExtEthernet matchGfpDataNoFcsNullExtEthernet matchGfpDataFcsLinearExtEthernet \
		matchGfpDataNoFcsLinearExtEthernet matchGfpMgmtFcsNullExtEthernet matchGfpMgmtNoFcsNullExtEthernet \
		matchGfpMgmtFcsLinearExtEthernet matchGfpMgmtNoFcsLinearExtEthernet matchGfpDataFcsNullExtPpp		\
		matchGfpDataNoFcsNullExtPpp matchGfpDataFcsLinearExtPpp matchGfpDataNoFcsLinearExtPpp \
		matchGfpMgmtFcsNullExtPpp matchGfpMgmtNoFcsNullExtPpp matchGfpMgmtFcsLinearExtPpp matchGfpMgmtNoFcsLinearExtPpp]                                             

    setEnumValList  $enumList enumValList
    set enumsArray(filterPallette,matchType1) $enumValList
    set enumsArray(filterPallette,matchType2) $enumValList

	set enumList    [list gfpErrorsOr gfpErrorsAnd ]
    setEnumValList  $enumList enumValList
    set enumsArray(filterPallette,gfpErrorCondition) $enumValList

    set enumList [list filterPalletteOffsetStartOfFrame filterPalletteOffsetStartOfIp \
					   filterPalletteOffsetStartOfProtocol filterPalletteOffsetStartOfSonet] 
    setEnumValList $enumList enumValList
    set enumsArray(filterPallette,patternOffsetType1)  $enumValList
    set enumsArray(filterPallette,patternOffsetType2)  $enumValList

    return $retCode
}


########################################################################
# Procedure:    createStreamExtractorFilterEnums
#
# Description:  Creates StreamExtractorFilterEnums enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createStreamExtractorFilterEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumList [list streamExtractorFilterOffsetStartOfFrame streamExtractorFilterOffsetStartOfIp] 
    setEnumValList $enumList enumValList
    set enumsArray(streamExtractorFilter,offsetMode)	$enumValList
    set enumsArray(streamExtractorModifier,offsetMode)  $enumValList

    set enumList [list streamExtractorCustom streamExtractorMacDa streamExtractorMacSa streamExtractorIpDa \
					   streamExtractorIpSa streamExtractorIpV6Da streamExtractorIpSa streamExtractorIpV6Da \
					   streamExtractorIpV6Sa streamExtractorIpV4TcpDa streamExtractorIpV4TcpSa streamExtractorIpV6TcpDa \
					   streamExtractorIpV6TcpSa streamExtractorIpV4UdpDa streamExtractorIpV4UdpSa \
					   streamExtractorIpV6UdpDa streamExtractorIpV6UdpSa streamExtractorIpVersion streamExtractorLayer4ProtocolType]  
    setEnumValList $enumList enumValList
    set enumsArray(streamExtractorFilter,filterType)  $enumValList


    return $retCode
}

########################################################################
# Procedure:    createAtmEnums
#
# Description:  Creates Atm enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createAtmEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

    # atmHeader
	set enumList    [list aal5NoError aal5BadCrc]
    setEnumValList  $enumList enumValList
    set enumsArray(atmHeader,aal5Error) $enumValList

    set enumList    [list hecErrorNone hecError1bit hecError2bit hecError3bit hecError4bit\
						hecError5bit hecError6bit hecError7bit hecError8bit]
    setEnumValList  $enumList enumValList
    set enumsArray(atmHeader,hecErrors) $enumValList

    set enumList    [list atmEncapsulationNone \
						  atmEncapsulationVccMuxIPV4Routed \
						  atmEncapsulationVccMuxBridgedEthernetFCS \
						  atmEncapsulationVccMuxBridgedEthernetNoFCS \
				          atmEncapsulationVccMuxIPV6Routed \
				          atmEncapsulationVccMuxMPLSRouted \
				          atmEncapsulationLLCRoutedCLIP \
						  atmEncapsulationLLCBridgedEthernetFCS \
						  atmEncapsulationLLCBridgedEthernetNoFCS \
						  atmEncapsulationLLCPPPoA \
						  atmEncapsulationVccMuxPPPoA \
						  atmEncapsulationLLCNLPIDRouted]
	setEnumValList  $enumList enumValList
    set enumsArray(atmHeader,encapsulation) $enumValList

    # atmReassembly
    setEnumValList  $enumList enumValList
    set enumsArray(atmReassembly,encapsulation) $enumValList
 
    # atmPort
	set enumList    [list atmInterfaceUni atmInterfaceNni]
    setEnumValList  $enumList enumValList
    set enumsArray(atmPort,interfaceType) $enumValList

	set enumList    [list atmIdleCell atmUnassignedCell]
    setEnumValList  $enumList enumValList
    set enumsArray(atmPort,fillerCell) $enumValList

	set enumList    [list atmDecodeFrame atmDecodeCell] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmPort,packetDecodeMode) $enumValList

	set enumList    [list atmPerVPIVCIStats atmPerStreamStats] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmPort,transmitStatsMode) $enumValList

    # atmHeaderCounter
	set enumList    [list atmIdle atmCounter atmRandom atmTableMode]
    setEnumValList  $enumList enumValList
    set enumsArray(atmHeaderCounter,type) $enumValList

	set enumList    [list atmIncrement atmContinuousIncrement atmDecrement atmContinuousDecrement] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmHeaderCounter,mode) $enumValList

    # atmOam
	set enumList    [list atmOamF4 atmOamF5] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmOam,cellFlowType) $enumValList

	set enumList    [list atmOamEndToEnd atmOamSegment] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmOam,endPointType) $enumValList

	set enumList    [list atmOamAis atmOamRdi atmOamFaultMgmtCC atmOamFaultMgmtLB atmOamActDeactCC ] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmOam,functionType) $enumValList
    set enumsArray(atmOamTrace,functionType) $enumValList

	set enumList    [list atmOamReply atmOamRequest] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmOamFaultManagementLB,loopbackIndication) $enumValList

	set enumList    [list atmOamNone atmOamBA atmOamAB atmOamTwoWay] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmOamActDeact,action) $enumValList

	set enumList    [list atmOamActivate atmOamActConfirmed atmOamActRequestDenied atmOamDeactivate atmOamDeactConfirmed] 
    setEnumValList  $enumList enumValList
    set enumsArray(atmOamActDeact,messageId) $enumValList

    return $retCode
}

########################################################################
# Procedure:    createGfpEnums
#
# Description:  Creates GFP enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createGfpEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

	set enumList    [list gfpDataFcsNullExtensionEthernet gfpDataNoFcsNullExtensionEthernet		\
						gfpDataFcsLinearExtensionEthernet gfpDataNoFcsLinearExtensionEthernet	\
						gfpMgmtFcsNullExtensionEthernet gfpMgmtNoFcsNullExtensionEthernet		\
						gfpDataFcsNullExtensionPpp gfpDataNoFcsNullExtensionPpp					\
						gfpDataFcsLinearExtensionPpp gfpDataNoFcsLinearExtensionPpp				\
						gfpMgmtFcsNullExtensionPpp gfpMgmtNoFcsNullExtensionPpp					\
						gfpMgmtFcsLinearExtensionPpp gfpMgmtNoFcsLinearExtensionPpp]
    setEnumValList  $enumList enumValList
    set enumsArray(gfp,payloadType) $enumValList

	set enumList    [list gfpNoFcs gfpGoodFcs gfpBadFcs]
    setEnumValList  $enumList enumValList
    set enumsArray(gfp,fcs) $enumValList

	set enumList    [list gfpCHecNone gfpCHec1Bit gfpCHecMultipleBits]
    setEnumValList  $enumList enumValList
    set enumsArray(gfp,coreHecErrors) $enumValList

	set enumList    [list gfpHecErrorsNone   gfpHecErrors1Bit	gfpHecErrors2Bits	\
						  gfpHecErrors3Bits  gfpHecErrors4Bits	gfpHecErrors5Bits	\
						  gfpHecErrors6Bits  gfpHecErrors7Bits  gfpHecErrors8Bits	\
						  gfpHecErrors9Bits  gfpHecErrors10Bits gfpHecErrors11Bits	\
						  gfpHecErrors12Bits gfpHecErrors13Bits gfpHecErrors14Bits	\
						  gfpHecErrors15Bits gfpHecErrors16Bits ]

    setEnumValList  $enumList enumValList
    set enumsArray(gfp,typeHecErrors) $enumValList
    set enumsArray(gfp,extensionHecErrors) $enumValList

	set enumList    [list gfpSyncStateK1 gfpSyncStateK2 gfpSyncStateK3 gfpSyncStateK4	\
						  gfpSyncStateK7 gfpSyncStateK6 gfpSyncStateK7 gfpSyncStateK8]
    setEnumValList  $enumList enumValList
    set enumsArray(gfpOverhead,deltaSyncState) $enumValList

    return $retCode
}

########################################################################
# Procedure:    createGfpEnums
#
# Description:  Creates GFP enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createTxRxPreambleEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

	set enumList    [list preambleModeSFDDetect	preambleByteCount preambleSameAsTransmit]
    setEnumValList  $enumList enumValList
    set enumsArray(txRxPreamble,txMode) $enumValList
    set enumsArray(txRxPreamble,rxMode) $enumValList

    return $retCode
}


########################################################################
# Procedure:    createLinkFaultSignalingEnums
#
# Description:  Creates LinkFaultSignaling enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createLinkFaultSignalingEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}

	set enumList    [list linkFaultSendTypeA linkFaultSendTypeB linkFaultAlternateOrderedSets]
    setEnumValList  $enumList enumValList
    set enumsArray(linkFaultSignaling,sendSetsMode) $enumValList

	set enumList    [list linkFaultLocal linkFaultRemote linkFaultCustom]
    setEnumValList  $enumList enumValList
    set enumsArray(linkFaultSignaling,orderedSetTypeA) $enumValList
    set enumsArray(linkFaultSignaling,orderedSetTypeB) $enumValList


    return $retCode
}

########################################################################
# Procedure:    createPoeEnums
#
# Description:  Creates Poe related enums.
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createPoeEnums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

    set enumValList {}
    set enumList    {}
	set enumList    [list poeRelayControlNoMode poeRelayControlAlternativeA poeRelayControlAlternativeB poeRelayControlBothAandB ]
    setEnumValList  $enumList enumValList
    set enumsArray(poePoweredDevice,relayControl) $enumValList

	set enumList    [list poeLoadControlConstantCurrent poeLoadControlControlledPower poeLoadControlIdle poeLoadControlShutdown ]
    setEnumValList  $enumList enumValList
    set enumsArray(poePoweredDevice,steadyStateLoadControl) $enumValList

	set enumList    [list poeLoadControlSinglePulse poeLoadControlContinuousPulse ]
    setEnumValList  $enumList enumValList
    set enumsArray(poePoweredDevice,transientLoadControl) $enumValList

	set enumList    [list poeRpdRangeZac1 poeRpdRangeZac2 ]
    setEnumValList  $enumList enumValList
    set enumsArray(poePoweredDevice,rpdRangeControl) $enumValList

	set enumList    [list poeTriggerDCVolts poeTriggerDCAmps ]
    setEnumValList  $enumList enumValList
    set enumsArray(poeSignalAcquisition,startTriggerSource) $enumValList
    set enumsArray(poeSignalAcquisition,stopTriggerSource) $enumValList

	set enumList    [list poeTriggerSlopePositive poeTriggerSlopeNegative ]
    setEnumValList  $enumList enumValList
    set enumsArray(poeSignalAcquisition,startTriggerSlope) $enumValList
    set enumsArray(poeSignalAcquisition,stopTriggerSlope) $enumValList


    return $retCode
}


########################################################################
# Procedure:    createInterfaceTableDhcpV6Enums
#
# Description:  Creates DHCPv6 enums used in Interface Table
#
# Arguments(s): None
#
# Result:       TCL_OK
#
########################################################################
proc scriptGen::createInterfaceTableDhcpV6Enums { } \
{
    variable enumsArray

    set retCode $::TCL_OK

	set enumList    [list dhcpV6IaTypeTemporary dhcpV6IaTypePermanent dhcpV6IaTypePrefixDelegation]
    setEnumValList  $enumList enumValList
    set enumsArray(dhcpV6Properties,iaType) $enumValList

	return $retCode
}


########################################################################
# Procedure: isEnable
#
# Description: This command checks if the param starts with "enable"
#
# Arguments(s):
# param  : input parameter.
#
# Result:   returns 1 if param starts with "enable"
#
########################################################################
proc scriptGen::isEnable { param } \
{
    set retCode 0
    if {[string length $param] >= [string length enable]} {
        set startWord [string range $param 0 [expr [string length enable] - 1]]
        if {![string compare $startWord enable]} {
            set retCode 1
        }
    }
    return $retCode 
}



########################################################################
# Procedure: createObsoleteParamsArray
#
# Description: This command creates obsolete params array
#
# Arguments(s):
#
# Result:   Always returns 0
#
########################################################################
proc scriptGen::createObsoleteParamsArray { } \
{
    variable obsoleteParamsArray 
    set retCode 0

    set filterPalletteParamList [list type1 typeMask1 type2 typeMask2]  
    set obsoleteParamsArray(filterPallette) $filterPalletteParamList

    set protocolParamList [list arpServerEnable pingServerEnable repeatCount \
                                rate MacAddress IpAddress count mapType]
    set obsoleteParamsArray(protocolServer) $protocolParamList

    # This dhcp option isn't really deprecated, it's just handled as a special case somewhere else.
    set selectedParamsList [list optionData]
    set obsoleteParamsArray(dhcp) $selectedParamsList

    set portParamList [list sonetInterface lineScrambling dataScrambling useRecoveredClock \
                            sonetOperation rateMode usePacketFlowImageFile packetFlowFileName pfcEnableValueList ]
    set obsoleteParamsArray(port) $portParamList

    set interfaceEntryParamList [list atmMode]
    set obsoleteParamsArray(interfaceEntry) $interfaceEntryParamList

    set protocolOffsetParamList [list enable]
    set obsoleteParamsArray(protocolOffset) $protocolOffsetParamList

    set protocolParamList [list dutStripTag]
    set obsoleteParamsArray(protocol) $protocolParamList

    set protocolParamList [list filter trigger]
    set obsoleteParamsArray(capture) $protocolParamList

    set streamParamList [list fir]
    set obsoleteParamsArray(stream) $streamParamList

    set udfParamList [list countertype]
    set obsoleteParamsArray(udf) $udfParamList

    set statParamList [list enableUsbExtendedStats]
    set obsoleteParamsArray(stat) $statParamList

    set sonetParamList [list  insertBipErrors B1 B2 B3 lossOfSignal \
                                lossOfFrame periodicB1 periodicB2 periodicB3 \
                                periodicLossOfSignal periodicLossOfFrame errorDuration]
    set obsoleteParamsArray(sonet) $sonetParamList
    
    set fcoePropertiesParamList [list  enableKeepAlives]
    set obsoleteParamsArray(fcoeProperties) $fcoePropertiesParamList
	
	set udpParamList [list enableChecksum]
	set obsoleteParamsArray(udp) $udpParamList
	
	catch {createProtocolsObsoleteParamsArray}
	
    return $retCode
}

########################################################################
# Procedure: sgPuts
#
# This command prints the string both into the file and on the screen
# Arguments(s):
# str : Text
# Returned Result:
#
########################################################################

proc sgPuts {args} \
{   
    variable scriptGen::FileHandle
	variable scriptGen::enableErrorChecking
	variable scriptGen::checkOnErrorCommandList
	variable scriptGen::noFormatCommandList

    set retCode 0

    set formatLine    1
    set str           ""

    if {[lindex $args 0] == "-noFormat"} {
        set str [join [lrange $args 1 end]]
        set formatLine 0
    } else {
        set str [join $args]
    }

	catch {
		if {$scriptGen::enableErrorChecking} {
			# Exclude the comments that contain the Error Commands from checkOnErrorCommandList
			if { ([string first "#" $str] < 0) && ([string first [lindex $str 1] $scriptGen::checkOnErrorCommandList] >= 0) } {

				set formatLine 0

				# now add back in the tabs if we removed them.. 
				set prestring ""
				if {[string length $str] != [string length [string trim $str]]} {
					set prestring "\t"
				}
				set line [string trim $str]
				set str [format "%sif \{\[$line\]\} \{\n%s\terrorMsg \"Error calling $line\"\n%s\tset retCode \$::TCL_ERROR\n%s\}\n" $prestring $prestring $prestring $prestring]
			}
		}

		# don't format these guys
		if {[string first [lindex $str 0] $scriptGen::noFormatCommandList] >= 0} {
			set formatLine 0
		}
	}

    set keyWord ""
    set line $str
    if {$formatLine && [string length $str] > 0} {
        scan $str "%s %s %s" a keyWord c
        if {[string range $a 0 0] != "#"} {
            if {$keyWord == "config"} {
                set args [string trim [string range $str [expr [string length $c] + [string first $c $str]] end]]
                set line [format "%s %s %-35s %s" $a $keyWord $c $args]
            } else {
                set tempKeyWord [format " %s" $keyWord] 
                set args [string trim [string range $str [expr [string length $tempKeyWord] + [string first $tempKeyWord $str]] end]]
                set line [format "%s %s %s" $a $keyWord $args]
            }
         }
    }

	if { $::scriptGen::outputToConsoleOption } {
		ixPuts $line
	}

    if {$::scriptGen::fileHandle != 0} {
      puts $::scriptGen::fileHandle $line
    }
    return $retCode
}

########################################################################
# Procedure: printHeader
#
# This command prints the header of the generated scipt 
#
# Arguments(s):
#
########################################################################

proc scriptGen::printHeader { } \
{
	variable outputDataOption	

    version get
    set displayVersion [version cget -installVersion]
	if { $displayVersion == "" } {
		set displayVersion	[version cget -ixTclHALVersion]
	}	 
	sgPuts ""    
	sgPuts "##############################################################"
	sgPuts "# This Script has been generated by Ixia ScriptGen"
	sgPuts "#      Software Version : $displayVersion         "
	sgPuts "##############################################################"
	sgPuts ""    
	sgPuts ""
	sgPuts "package req IxTclHal"  
	sgPuts ""

	set optionString "# Command Option Mode - Full (generate full configuration)"
	
	if { $outputDataOption == "generateCommented" } {
		set optionString "# Command Option Mode - Comment (generate commented commands for default values)"
	}

	if { $outputDataOption == "generateNonDefault" } {
		set optionString "# Command Option Mode - Non-default (do not generate commands for options with default values)"
	}

	sgPuts $optionString
	sgPuts ""

}


########################################################################
# Procedure: printTclServer
#
# This command prints the code to connect to tclServer 
#
# Arguments(s):
#
########################################################################
proc scriptGen::printTclServer { tclServerName } \
{
	sgPuts
	sgPuts -noFormat "if \{\[isUNIX\]\} \{"
	sgPuts -noFormat "	if \{\[ixConnectToTclServer $tclServerName\]\} \{"
	sgPuts -noFormat "		errorMsg \"Error connecting to Tcl Server $tclServerName \""
	sgPuts -noFormat "		return \$::TCL_ERROR"
	sgPuts -noFormat "	\}"
	sgPuts -noFormat "\}"
	sgPuts
}


########################################################################
# Procedure: printLoginOwnerInfo
#
# Description:	This command prints the ixLogin owner name, and gets it 
#				from the specified port 
#
# Arguments(s):
#
########################################################################
proc scriptGen::printLoginOwnerInfo { } \
{
	set loginUserName [session cget -userName] 
	if [string length $loginUserName ] {
		sgPuts "set owner \"$loginUserName\"" 
		sgPuts {ixLogin $owner}
		sgPuts ""
	}
}

########################################################################
# Procedure: printChassisInfo
#
# Description: This command prints the chassis related configuration 
#
# Arguments(s):
#	chassId		- chassis id
#
########################################################################

proc scriptGen::printChassisInfo { chassId  {filePerPortFlag $::false} } \
{
	set retCode $::TCL_OK

	if [chassis get $chassId] {
		ixPuts "Error in getting the chassis with id $chassId"
		set retCode TCL_ERROR
	}
	
	if { $retCode == $::TCL_OK } {

		if { $filePerPortFlag == $::true } {
			sgPuts 
			sgPuts "######### Chassis- [chassis cget -hostName] #########"
			sgPuts  
			if { [chassis cget -master] || ($::scriptGen::masterChassis == 0) } {  
				sgPuts "ixConnectToChassis   \{[chassis cget -hostName]\}"
			} else {
				sgPuts "set masterChassis \"$::scriptGen::masterChassis\""
				sgPuts "set slaveChassis \"[chassis cget -hostName]\""
				sgPuts {ixConnectToChassis   "$masterChassis $slaveChassis"}
			}
			sgPuts
		} else {
			sgPuts 
			sgPuts "######### Chassis-[chassis cget -hostName] #########"
			sgPuts  
		}
		sgPuts "chassis get \"[chassis cget -hostName]\""
		sgPuts {set chassis	  [chassis cget -id]}
	}

	return $retCode  
}

########################################################################
# Procedure: printCardInfo
#
# Description: This command prints the card related configuration 
#
# Arguments(s):
#
########################################################################
proc scriptGen::printCardInfo { chassId cardId portId howManyPorts {filePerPortFlag $::false} } \
{
	set retCode $::TCL_OK

	if {[card get $chassId $cardId]} {
		ixPuts "Error in getting card $chassId $cardId"
		set retCode TCL_ERROR
	}

	if { $retCode == $::TCL_OK } {
		sgPuts ""
		sgPuts "######### Card Type : [card cget -typeName] ############"
		sgPuts ""

		if { $filePerPortFlag == 0 } {
			sgPuts "set card     $cardId"
		}
		
           
		if {[scriptGen::getCardScript   $chassId $cardId $howManyPorts]} {
		    ixPuts "Error generating card configuration"
		    return TCL_ERROR
            }
		
	}

	return $retCode  
}


########################################################################
# Procedure: checkOnFile
#	
# Description:	This procedure will check for an existing filename and
#				display a message to the user with a TK box
#
########################################################################
proc scriptGen::checkOnFile { FileNameArray } {

	upvar $FileNameArray fileNameArray

	set retCode			0	
	set fileExistCount	0

	foreach fileNameItem [array names fileNameArray] {
		set tempFileName $fileNameArray($fileNameItem)
			
		regsub -all {\"} $tempFileName "" tempFileName

		if { [file exists $tempFileName] } {
			incr fileExistCount	        
		}
	}

	if { $fileExistCount } {
		ixPuts "\n\n"
		set warningMsg "One or more files with the same name already exist."
		append warningMsg "\nCheck the file generate options or change the file name."
		ixPuts $warningMsg
		set retCode 1
	}
	  
	return $retCode
}


########################################################################
# Procedure: getArgValue
#	
# Description:	Returns the decimal value based on the entry
#				
#
########################################################################
proc scriptGen::getArgValue { value } \
{
	set newValue	1
	set tempValue	[string tolower $value]

	switch $tempValue {
		true	-
		yes		-
		1 	 { set newValue  1 }
		false	-
		no		-
		0	 { set newValue  0 }
	}
	
	return $newValue
}


########################################################################
# Procedure: getObsoleteCmdList
#
# Description: This command returns the obsolete Command List
#
# Arguments(s):
#
# Result:   Always returns 0
#
########################################################################
proc scriptGen::getObsoleteCmdList { } \
{
    set obsoleteCmdList [list usb licenseManagement]  
	
    return $obsoleteCmdList
}


########################################################################
# Procedure: getCombinationOptionString
#
# Description: This command returns "OR"-ed configuration options
#
# Arguments(s):
#
# Result:   Always returns 0
#
########################################################################
proc scriptGen::getCombinationOptionString {cmd parm value} \
{
    variable enumsArray
    set retString	{} 
 
    set enumValList $enumsArray($cmd,$parm)
    set joinedList  [join $enumValList]

	if { $value == 0 } {
        set index		[lsearch $joinedList $value]
        set retString	[format "%s%s"  {$::} [lindex $joinedList [expr $index-1]] ]
	} else {
		foreach enumNameValue $enumsArray($cmd,$parm) {
			set enumValue [lindex $enumNameValue 1]
			if {[mpexpr $value & $enumValue]} {
				lappend retString	[format "%s%s%s"  {$::} [lindex $enumNameValue 0] "|"]
			}       
		}

		set retString [string trim [removeSpaces [join $retString]] "|"]
		set retString [format "%cexpr %s%c" 91 $retString 93]	;# the values of open/close brackets is use (91/93)
	}

	return $retString 
}


########################################################################
# Procedure: getCombinationOptionList
#
# Description: This command returns "OR"-ed configuration options
#
# Arguments(s):
#
# Result:   Always returns 0
#
########################################################################
proc scriptGen::getCombinationOptionList {cmd parm value} \
{
    variable enumsArray
    set retString	{} 
 
    set enumValList $enumsArray($cmd,$parm)
    set joinedList  [join $enumValList]

	if { [llength $value] != 0 } {
		foreach item $value {			
			set index [lsearch $joinedList $item]
			lappend retString [format "%s%s%s"  {$::} [lindex $joinedList [expr $index-1]] " "]
		}

		set retString [string trim [removeSpaces [join $retString]]]
		set retString [format "%clist %s%c" 91 $retString 93]	;# the values of open/close brackets is use (91/93)
	} else {
		set retString [format "%clist%c" 91 93]	;# the values of open/close brackets is use (91/93)
	}	

	return $retString 
}










