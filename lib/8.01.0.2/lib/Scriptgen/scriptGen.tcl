#############################################################################################
#   Version 8.01
#   
#   File: scriptGen.tcl
#
#   Copyright ©  IXIA.
#   All Rights Reserved.
#
#	Revision Log:
#	01-15-2004	Hasmik	Genesis
#
#
#	NOTE: package req Scriptgen will fail in UNIX 
#	      if we use enums like $::true before connecting to the tclServer
#   
#############################################################################################
set env(IXIA_SCRIPTGEN_LIBRARY) [file dirname [info script]]
catch {set env(IXIA_LEGACY_SCRIPTGEN_LIBRARY) [file join $::ixiaInstall::tclLegacyDir "TclScripts/lib/scriptgen"]}

package req IxTclHal
package provide Scriptgen 8.01

namespace eval ::scriptGen {

    # Define unexposed feature enums
    variable portFeaturePatternFilter1    71 

	proc getParmValueArray {cmd ParamArray {oddValueList ""} {method config}} \
	{
		upvar $ParamArray paramArray

		set parmValueList	[list]
		catch {$cmd $method} paramList
		foreach param [lsort [join $paramList]] {
			if {$param == "-this"} {
				continue
			}
			if {[string index $param 0] == "-"} {
				set temp [string trim $param "-"]
				if {[lsearch $temp $oddValueList ] < 0 } {
					set paramArray($param) "[$cmd cget $param]"
				}
			}
		}
	}

	# don't format for any of these commands
	variable noFormatCommandList [list package ixConnectToTclServer ixConnectToChassis ixLogin set ixWritePortsToHardware ixWriteConfigToHardware ixCheckLinkState lappend incr]

	# generate error checking code for each of these commands
	variable checkOnErrorCommandList [list set write select add addTx addRx setTx setCircuitTx setRx channelize writeOperationMode \
										   setBaseIp addOption setOption addTlv setCisco setPpp addGroupRecord addItem addInterface \
										   setInterface addExtensionHeader addChannel setChannel setTlv setTransmitMode writeTransmitMode \
										   setReceiveMode writeReceiveMode setPhyMode reset addMacBinding addVlan setVlan setQueue \
										   setCircuit setFilter addColumn addRow addRange addPair setSa setDa setLane addPlogi \
										   enableGenerateWarningList clearAllExtHeaders addExtHeader setOptHeader resetStreamProtocolStack ]

	set path [file join $env(IXIA_SCRIPTGEN_LIBRARY) ../..]
	variable fileName [file join $path generatedScript.tcl]

	variable fileHandle				0
	variable hostNameList			loopback
	variable oddParamsList			{}
	variable dhcpOptionDataList 
	variable obsoleteParamsArray
	variable boolList				{}
	variable generateHdlcPerStream	0
	variable portList				{}
	variable enumsArray	
	variable generatePacketView		0
	variable outputDataOption		generateAll
	variable outputDataOptionList	{ generateAll  generateNonDefault generateCommented }
	variable defaultsGenerated		0
	variable stopFlag				0
	variable masterChassis			0
	variable outputToConsoleOption	1
	variable enableErrorChecking	1
}

source [file join $env(IXIA_SCRIPTGEN_LIBRARY) sgUtils.tcl]
source [file join $env(IXIA_SCRIPTGEN_LIBRARY) sgCard.tcl]
source [file join $env(IXIA_SCRIPTGEN_LIBRARY) sgPort.tcl]
source [file join $env(IXIA_SCRIPTGEN_LIBRARY) sgStream.tcl]

# Recent IxNetwork Tcl pacakges allow the user to specify a version.  Try that first:
# (Note: the same variable is used for Protocols and scriptGen)
if {[info exists ::IxTclHal_LoadIxTclProtocolVersion]} {
    # If the user requests "none", simply do not load the package at all
    if {$::IxTclHal_LoadIxTclProtocolVersion != "none"} {
        # Attempt to require the specified version of scriptgen-protocols package
        if {[catch {package require scriptgen-protocols $::IxTclHal_LoadIxTclProtocolVersion} sgprotocols_result} {
            # Display a helpful message on failure
            set savInfo $::errorInfo
            if {[catch {package versions scriptgen-protocols} versionList]} {
                set versionList [list]
            }
            set errMsg "Couldn't load scriptgen-protocols version \"$::IxTclHal_LoadIxTclProtocolVersion\" ('set ::IxTclHal_LoadIxTclProtocolVersion \"none\"', or any of: $versionList, or unset it)"
            error $errMsg $savInfo
        }
    }
} else {
    # If the user did not specify a version, try to load the first scriptgen-protocols we can find:
    if { [catch {package require scriptgen-protocols} ] } {
        # Otherwise, try the legacy locations:
        if { [ catch {source [file join $env(IXIA_LEGACY_SCRIPTGEN_LIBRARY) sgProtocols.tcl]}]} {
            catch {source [file join $env(IXTCLNETWORK_LIBRARY) sgProtocols.tcl]}
            # If nothing is found, that's ok, IxNetwork is just not installed
        }
    }
} 

########################################################################
# Procedure: connectToChassis
#
# Description:	This command builds a port group & issues the specified 
#				command, then destroys the port group when it's done
#
# Argument(s):
#   chassisList		- list of the chassis names
#   args			options include:
#                   -chassisRefresh	 <turn on/off the chassis refresh, defaul= true>
#                   -ixTclServerName <provide unix tclServer name, otherwise use 
#									 the first chassis from the chassisList, 
#									 default is the first chassis in the chassisList>
#
########################################################################
proc scriptGen::connectToChassis { chassisList args } \
{
	set retCode 0

	if { [llength $chassisList] == 0 } {
		return 1
	}

    # default some vars here...
    set refreshFlag				1
    set serverName				[lindex $chassisList 0]
	set argOption				none

	# Parse the arguments
    foreach arg [join $args] {
        # just go ahead & remove the '-', makes things easier
        set dash [expr [regsub -all {^-} $arg "" arg]?"-":""]
	
		if { $dash == "-" } {
			switch $arg {
				chassisRefresh	{ set argOption  chassisRefresh }						
				ixTclServerName { set argOption  ixTclServerName }
			}
		} else {
			switch $argOption {
				chassisRefresh	{ set refreshFlag [scriptGen::getArgValue $arg] }
				ixTclServerName { set serverName   $arg }
				none { 
					ixPuts "No value specified for the Error in connecting to TCL Server on $serverName"
					return 1
				}					
			}
		}	
	}	
		
	set reconnectFlag		0

	if { [ isUNIX ] } {

		# Here check if we are disconnected from the TclServer,
		catch chassis tempValue
		set stringToBeCompared [string range $tempValue 0 6]

		if { $stringToBeCompared == "invalid" } {

			# Needed package req after disconnect from a chassis that has TCL Server running
			package req IxTclHal     

			if {[ixConnectToTclServer $serverName]} {
				ixPuts "Error in connecting to TCL Server on $serverName"
				return 1
			}
		}
	}  
			 
	# All the chassis has to be connected in the Chassis chain, otherwise disconnect and reconnect again 
	foreach chassisName $chassisList {
		if { [chassis get $chassisName ] } {
			set reconnectFlag 1
			chassisChain removeAll	;# Disconnect all the chassis in the chain
			break
		}
	}

	if { $reconnectFlag } {

        if {[ixConnectToChassis   $chassisList]} {
            ixPuts "Error in connecting to one of the following chassis - $chassisList"
            return 1
        }
	} else {
		if { $refreshFlag } {
			ixPuts "Refreshing chassis..."
			foreach chassisName $chassisList {
				chassis refresh $chassisName
			}
		}
	}

	ixPuts ""
}


########################################################################
# Procedure: generateScript
#
# Description:	This command builds a port group & issues the specified command, then
#				destroys the port group when it's done
#
# Argument(s):
#	portList		list of ports
#   args			options include:
#                   -outPutToFile			<turn on/off the output to file, true/false, default = true>
#                   -filePerPort			<turn on/off the output to file per port, true/false, default = false>
#					-fileOverwrite			<turn on/off the file overwrite, true/false, default = true>
#					-fileName				<the full path to the fileName>
#					-streamGenOption		<turn on/off the generatePacketView, true/false, default = false>
#					-outputToConsoleOption	<turn on/off the output to std out, true/false, default = true>
#					-outputOption			<select one of the following config options, 
#											(generateAll  generateNonDefault generateCommented) >
#					-tclServer				<the host where tcl server is running>
#
#	NOTE: You must be connected to all the chassis in the portList before calling this method
#
########################################################################
proc scriptGen::generateScript { userPortList args } \
{
	set retCode					0

    # default some vars here...
    set outputToFileFlag	$::true
    set filePerPortFlag		$::false
    set fileOverwriteFlag	$::true
	set argOption			none
	set hostNameList		[list]
	set tclServerName		""
	set ::scriptGen::fileHandle		stdout

	set path [file join $::env(IXIA_SCRIPTGEN_LIBRARY) ../..]
	set defaultFileName [file join $path generatedScript.tcl]
	set fileName		$defaultFileName
	
	if {![llength $userPortList] } {
		ixPuts "\nWARNING!!!!! No available ports for generating script(s)."
		return $::TCL_ERROR
	}

	if { !$::scriptGen::defaultsGenerated } {
		set ::scriptGen::defaultsGenerated 1
		foreach cmd $::halCommands {
			if { [lsearch [scriptGen::getObsoleteCmdList] $cmd] >= 0 } {
				continue
			}
			if { [catch {$cmd setDefault} catchedString] } {
				continue
			}
			set defaultValueArray [format "%sDefaultValueArray" $cmd]
			catch { unset ::scriptGen::$defaultValueArray}

			getParmValueArray $cmd ::scriptGen::$defaultValueArray
		}
	}

	scriptGen::createEnums
				
	# Parse the arguments
    foreach arg $args {
        # just go ahead & remove the '-', makes things easier
        set dash [expr [regsub -all {^-} $arg "" arg]?"-":""]
	
		if { $dash == "-" } {
			switch $arg {
				outPutToFile			{ set argOption  outPutToFile	}						
				filePerPort				{ set argOption  filePerPort	}
				fileOverwrite			{ set argOption  fileOverwrite	}
				fileName				{ set argOption	 fileName		}
				outputOption			{ set argOption	 outputOption	}
				tclServer				{ set argOption  tclServer		}
				streamGenOption			{ set argOption  streamGenOption}
				outputToConsoleOption	{ set argOption  outputToConsoleOption}
				default			{
					ixPuts "Invalid argument option:$arg "
					return $::TCL_ERROR
				}

			}
		} else {
			switch $argOption {
				outPutToFile			{ set outputToFileFlag	[scriptGen::getArgValue $arg]}					
				filePerPort				{ set filePerPortFlag	[scriptGen::getArgValue $arg]}
				fileOverwrite			{ set fileOverwriteFlag	[scriptGen::getArgValue $arg]}
				outputToConsoleOption	{ set ::scriptGen::outputToConsoleOption [scriptGen::getArgValue $arg]}
				streamGenOption			{ set ::scriptGen::generatePacketView	 [scriptGen::getArgValue $arg]}
				outputOption	{
					set ::scriptGen::outputDataOption $arg
					if { [lsearch $::scriptGen::outputDataOptionList $arg] < 0 } {
						set ::scriptGen::outputDataOption	generateAll
					}
				}
				tclServer		{ set tclServerName		$arg }
				fileName		{ 
					if { $arg != "" } {
						set fileName $arg
						if { ![ isUNIX ] } {
							regsub -all {\\} $fileName "/" fileName
						} 
					}
					set	extension	[file extension $fileName]
					if { $extension == "" } {
						set fileName [format "%s.tcl" $fileName]
					}
					set dirName [file dirname $fileName]
					if {![file isdirectory $dirName] } {
						file mkdir $dirName
					} 
				}
				none			{ 
					ixPuts "Invalid argument list, need to be in the following format: \"-outPutToFile false\" \"-filePerPort true\" "
					return $::TCL_ERROR
				}					
			}
			
		}	
	}

	set kFeaturePortReadOnly	269

    foreach portItem $userPortList {
        scan $portItem "%d %d %d" chassId cardId portId       
	    if {[canUse $chassId $cardId $portId]} {
			ixPuts "\n***** WARNING, no script is generated for port $chassId $cardId $portId, check availability."
			set indx [lsearch $userPortList [list $chassId $cardId $portId]]
            if {$indx != -1} {
                set userPortList [lreplace $userPortList $indx $indx]
            }
		} elseif {[port isValidFeature $chassId $cardId $portId $kFeaturePortReadOnly]} {
			ixPuts "\n***** WARNING, there is no configuration for this port $chassId $cardId $portId, no script is generated."
			set indx [lsearch $userPortList [list $chassId $cardId $portId]]
            if {$indx != -1} {
                set userPortList [lreplace $userPortList $indx $indx]
            }
		}
    }
	
	if {![llength $userPortList] } {
		ixPuts "\n***** WARNING, no available ports or configuration for generating script(s)."
		return $::TCL_ERROR
	}


	set portList {}
	set sortedPortList	[lnumsort $userPortList]

	# Note, if outputToFileFlag is not true, filePerPortFlag should not be available.
	if { !$outputToFileFlag } {
		set filePerPortFlag $::false
	}

	catch { unset fileNameArray }

    if { $outputToFileFlag } {

		if { $filePerPortFlag } {
			foreach portItem $sortedPortList {
				scan $portItem "%d %d %d" chassId cardId portId

				set baseFileName	[file rootname	$fileName]
				set perPortFileName	[format "%s_%d.%d.%d.tcl" $baseFileName $chassId $cardId $portId ]
				set fileNameArray($chassId,$cardId,$portId)	\"$perPortFileName\"	 
			}
		} 				

		# Verify if the files exist when the fileOverwrite is not checked, then if the files exist, stop
		# otherwise continue generation
		if { $fileOverwriteFlag == 0 } {
			if { [scriptGen::checkOnFile fileNameArray] } {
				if {[info exists fileNameArray] } {
					unset fileNameArray
				}
				return $::TCL_ERROR
			}
		}

		if { !$filePerPortFlag } {

			if { ($fileOverwriteFlag == 0) && [file exists $fileName] } {
				ixPuts "\n!!! There is an existing file with that name: $fileName "
				ixPuts "    Choose a different file name or select overwrite existing filename option."
				return $::TCL_ERROR
			} 

			if { [catch { open $fileName w } ::scriptGen::fileHandle] } {
				ixPuts "Error opening file: $fileName, $::scriptGen::fileHandle"
				catch { unset fileNameArray }
			    return $::TCL_ERROR
			} 
			if { $::scriptGen::fileHandle == 0 } {
				return $::TCL_ERROR
			} 
		}
	
	} 

	set previousChassis		-1
	set previousCard		0
	set printHeaderFlag		1

	catch { unset chassisNameArray }
	set chassisIdList [list]
	foreach  portItem $sortedPortList {
		scan $portItem "%d %d %d" c l p
		if { [lsearch  $chassisIdList $c] < 0 } {
			if {![chassis get $c] } {
				set chassisNameArray($c)	"[chassis cget -hostName]"
				if { $::scriptGen::masterChassis == 0 } {
					if {[chassis cget -master]} {
						set ::scriptGen::masterChassis [chassis cget -hostName]
					}
				}
				lappend hostNameList "[chassis cget -hostName]"
			}
			lappend chassisIdList $c
		}
	}

	if { $::scriptGen::masterChassis == 0 } {
		# Since we don't know which one is the master, we will get the first master in the chain
		# there is no master in the hostNameList 
		for {set chId 0 } { $chId <= 255 } { incr chId } {
			if {![chassis get $chId] } {
				if {[chassis cget -master]} {
					set ::scriptGen::masterChassis [chassis cget -hostName]
					break
				}
			}
		}
	}

	if { $::scriptGen::masterChassis == 0 } {
		ixPuts "Error: Invalid chassis chain - check for master chassis in the chain"
		return $::TCL_ERROR
	}

	if {[llength  $tclServerName] == 0 } {
		set tclServerName [lindex $hostNameList 0]
	} 
   	set nonPoeCount 0

      set howManyPorts [llength $sortedPortList]
      
	foreach portItem $sortedPortList {
		scan $portItem "%d %d %d" chassId cardId portId

		if {[port isActiveFeature $chassId $cardId $portId $::portFeature10GEAggregate]} {
			continue
		} else {		
			if { !$::scriptGen::outputToConsoleOption } {
				ixPuts "Generating code for port $chassId $cardId $portId ..."
			}
		}
		update idletasks
		if { $::scriptGen::stopFlag } {
			break;
		}
		if { $filePerPortFlag } {
			set fileNameItem [lindex $fileNameArray($chassId,$cardId,$portId) 0]
			if { [catch { open $fileNameItem w } ::scriptGen::fileHandle] } {
				ixPuts "Error opening file: $fileNameItem, $::scriptGen::fileHandle"
				set ::scriptGen::fileHandle stdout
			} 
		}

		# We need to do the port get before printLoginOwnerInfo, 
		# but generate port information after card

		if {[port get $chassId $cardId $portId]} {
			ixPuts "Error in getting port $chassId $cardId $portId"
			return $::TCL_ERROR
		}

		if { $filePerPortFlag } {

			scriptGen::printHeader
			scriptGen::printTclServer $tclServerName

			if {[scriptGen::printChassisInfo $chassId $filePerPortFlag] } {
				ixPuts "scriptGen::generateScript  Error printing chassis information for chassis id $chassId"
				return $::TCL_ERROR
			}
			scriptGen::printLoginOwnerInfo
			sgPuts "set card     $cardId"
			sgPuts "set port     $portId"
			sgPuts {set portList {}}

		} else {
			# We just need to print once if filePerPortFlag is false
			if { $printHeaderFlag } {

				scriptGen::printHeader
				scriptGen::printTclServer $tclServerName

				if {$::scriptGen::masterChassis != 0 } {
					mergeLists hostNameList $::scriptGen::masterChassis  $hostNameList
				}

				sgPuts "######### Chassis list - \{$hostNameList\} #########"
				sgPuts  
				sgPuts "ixConnectToChassis   \{$hostNameList\}"
				sgPuts  
				scriptGen::printLoginOwnerInfo
				sgPuts {set portList {}}
				sgPuts  
				sgPuts  
				if {[scriptGen::printChassisInfo $chassId $filePerPortFlag] } {
					ixPuts "scriptGen::generateScript  Error printing chassis information for chassis id $chassId"
					return $::TCL_ERROR
				}
				set printHeaderFlag 0
				set previousChassis $chassId

			} else {
				if { $previousChassis != $chassId } {
					if {[scriptGen::printChassisInfo $chassId $filePerPortFlag] } {
						ixPuts "scriptGen::generateScript  Error printing chassis information for chassis id $chassId"
						return $::TCL_ERROR
					}
					set previousChassis $chassId
				}
			}
		}

		if { $previousCard != $cardId } {
			if {[scriptGen::printCardInfo $chassId $cardId $portId $howManyPorts $filePerPortFlag] } {
				ixPuts "scriptGen::generateScript  Error printing card information on card $chassId $cardId"
				return $::TCL_ERROR
			}
			set previousCard $cardId
		}

		scriptGen::createEnumsPerPortType $chassId $cardId $portId

		sgPuts "" 
		sgPuts "######### Chassis-[chassis cget -hostName] Card-$cardId  Port-$portId #########" 
		sgPuts ""
		
		if { $filePerPortFlag == 0 } {
			sgPuts "set port     $portId"
			sgPuts ""
		}
	   	set notPoe 0

		if {![port isValidFeature $chassId $cardId $portId $::portFeaturePowerOverEthernet]} {
			incr nonPoeCount
			set notPoe 1
		}

		if {[scriptGen::getPortScript   $chassId $cardId $portId $howManyPorts]} {
			ixPuts "Error generating port configuration"
			return $::TCL_ERROR
		}

		sgPuts {lappend portList [list $chassis $card $port]}

		if { $filePerPortFlag } {
			sgPuts "" 
			sgPuts "ixWritePortsToHardware portList"
			if { $notPoe } {
				# Poe port doesn't need checklinkstate
				sgPuts "ixCheckLinkState portList" 
			}  
			ixPuts ""
			catch { close $::scriptGen::fileHandle }
		} 
	}

	update idletasks

	if { !$::scriptGen::stopFlag } {

		# Write only once for all the ports at once, when only one file is being generated
		# if we get here already, means that scriptGen::fileHandle is not 0
		if { !$filePerPortFlag } {
			ixPuts ""
			sgPuts "ixWritePortsToHardware portList"
			if {$nonPoeCount } {
				sgPuts "ixCheckLinkState portList"
			}   
			sgPuts ""
			sgPuts ""
			sgPuts ""
		}

		set previousChassis			-1
		set streamConfigCount		0
		set displayStreamSection	1

		foreach portItem $sortedPortList {
			scan $portItem "%d %d %d" chassId cardId portId

			if { !$::scriptGen::outputToConsoleOption } {
				ixPuts "Generating code for streams on port $chassId $cardId $portId ..."
			}

			update idletasks
			if { $::scriptGen::stopFlag } {
				break;
			}

			if { $outputToFileFlag && $filePerPortFlag } {
				set fileNameItem [lindex $fileNameArray($chassId,$cardId,$portId) 0]
				if { [catch { open $fileNameItem a } ::scriptGen::fileHandle] } {
					ixPuts "Error opening file: $fileNameItem, $::scriptGen::fileHandle"
					set ::scriptGen::fileHandle stdout
				} 
			}

			if {![port isActiveFeature $chassId $cardId $portId $::portFeatureVcat] } {
				# portFeaturePacketStreams returns false when the port is in channelized mode
				if {![port isValidFeature $chassId $cardId $portId $::portFeaturePacketStreams] && \
				    ![port isValidFeature $chassId $cardId $portId $::portFeatureAdvancedScheduler] || \
					([port cget -transmitMode] == $::portTxModeEcho) || ([port cget -receiveMode] == $::portRxModeEcho)} {
					if { $filePerPortFlag && $outputToFileFlag } {
						catch { close $::scriptGen::fileHandle }
					}
					# No streams for these port types
					continue
				}
			}

			# Write only once for all the ports at once, when only one file is being generated
			# if we get here already, means that scriptGen::fileHandle is not 0
			if { !$filePerPortFlag && $displayStreamSection } {
				sgPuts "###################################################################"
				sgPuts "######### Generating streams for all the ports from above #########"
				sgPuts "###################################################################"
				sgPuts ""
				set displayStreamSection 0
			}

			sgPuts ""
			sgPuts "######### Chassis-$chassisNameArray($chassId) Card-$cardId  Port-$portId #########" 
			sgPuts ""
			if {$filePerPortFlag == 0} {
				if { $previousChassis != $chassId } {

					# We need to do this, because when we generate script from IxExplorer the chassis Id maybe
					# different then the id that is assigned by ixConnectToChassis call
					if [chassis get $chassId] {
						ixPuts "Error in getting the chassis with id $chassId"
						return $::TCL_ERROR
					}
					sgPuts "chassis get \"[chassis cget -hostName]\""
					sgPuts {set chassis	  [chassis cget -id]}
					set previousChassis $chassId	
				}
				sgPuts "set card     $cardId"
				sgPuts "set port     $portId"
			}
			
			sgPuts [format {streamRegion get $chassis $card $port}]
			sgPuts [format {streamRegion enableGenerateWarningList  $chassis $card $port 0}]

			if {[port isActiveFeature $chassId $cardId $portId $::portFeatureAtm]} {
				if {[scriptGen::getAtmStreamQueueScript $chassId $cardId $portId]} {
					ixPuts "Error in generating ATM streams"
					return $::TCL_ERROR
				}

			} elseif {[port isActiveFeature $chassId $cardId $portId $::portFeatureVcat]} {
				if {[scriptGen::getCircuitStreams $chassId $cardId $portId]} {
					ixPuts "Error in generating streams for circuit(s) on $chassId $cardId $portId"
					return $::TCL_ERROR
				}
			} elseif {[scriptGen::getStreamScript $chassId $cardId $portId]} {
				ixPuts "Error in generating streams on $chassId $cardId $portId"
				return $::TCL_ERROR
			}
			incr streamConfigCount
			
			sgPuts [format {streamRegion generateWarningList $chassis $card $port}]

			if { $filePerPortFlag } {
				if { $streamConfigCount > 0 } {
					sgPuts "ixWriteConfigToHardware portList -noProtocolServer"
				}
				if { $outputToFileFlag } {
					catch { close $::scriptGen::fileHandle }
				}
			}
		}
	}

	update idletasks
	if { $::scriptGen::stopFlag } {
		if { $outputToFileFlag } {
			catch { close $::scriptGen::fileHandle }
			if { $filePerPortFlag } {
				foreach portItem $sortedPortList {
					scan $portItem "%d %d %d" chassId cardId portId

					set tempFileName [lindex $fileNameArray($chassId,$cardId,$portId) 0]
					catch { file delete -force $tempFileName }	
				}			
			} else {
				catch { file delete -force $fileName }
			}
		}
		ixPuts ""
		ixPuts " !!!!! Script generation was stopped by the user and all the intermediate files were deleted."
		set ::scriptGen::stopFlag 0
	} else {
		if { $filePerPortFlag == 0 } {
			if { $streamConfigCount > 0 } {
				sgPuts "ixWriteConfigToHardware portList -noProtocolServer"
			}
			if { $outputToFileFlag } {
				catch { close $::scriptGen::fileHandle }
			}
		} 
	}

	catch { unset fileNameArray }	

	ixPuts ""
	ixPuts "DONE"
	return $retCode

}


