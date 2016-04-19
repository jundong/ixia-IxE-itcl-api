#############################################################################################
#   Version 8.01
#   
#   File: sgPort.tcl
#
#   Copyright ? IXIA.
#   All Rights Reserved.
#
#	Revision Log:
#	04-03-2001	EM	Genesis
#
#
#############################################################################################


########################################################################
# Procedure: getPortScript
#
# This command generates port commands
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################


proc scriptGen::getPortScript { chassis card port {howManyPorts 1} } \
{
    set retCode 0
   
    # only if it is port level scriptGen
    # card level scriptgenn is taken care
    # in card script generation
    if { $howManyPorts == 1 } {
		if {[card isValidFeature $chassis $card $::cardFeatureResourceGroup]} {
			set cfgRGLists [card getConfiguredResourceGroupList $chassis $card]
		    if { $cfgRGLists != "" } {
				set rgPorts 0
				
				foreach rgList $cfgRGLists {
					set PortNo [lindex $rgList 0]
                    if { $PortNo == $port } {
						set rgPorts $rgList 
    				    break
					}
				}
                if { $rgPorts != 0 } {
				sgPuts  "card addResourceGroup $rgPorts"
				sgPuts "card createResourceGroups \$chassis \$card"
				}
			}
		}
	}

      if {[port isValidFeature $chassis $card $port $::portFeatureResourceGroupEx]} {
         resourceGroupEx get $chassis $card $port
         sgPuts {resourceGroupEx  get $chassis $card $port}
	     generateCommand resourceGroupEx no
	     sgPuts {resourceGroupEx  set $chassis $card $port}
         sgPuts {resourceGroupEx write $chassis $card $port}
	   
	}



	if {[port isValidFeature $chassis $card $port $::portFeaturePowerOverEthernet]} {

		if {![poePoweredDevice get $chassis $card $port]} {
			generateCommand poePoweredDevice
            sgPuts {poePoweredDevice set $chassis $card $port}
        } else {
            logMsg "Error getting poePoweredDevice"
            set retCode 1 
        }
        if {![poeSignalAcquisition get $chassis $card $port]} {
			generateCommand poeSignalAcquisition
            sgPuts {poeSignalAcquisition set $chassis $card $port}
        } else {
            logMsg "Error getting poeSignalAcquisition"
            set retCode 1 
        }
		return $retCode
	}
	
	if {[card isActiveFeature $chassis $card $::portFeature1GEAggregate] && \
	    ![port isActiveFeature $chassis $card $port $::portFeature1GEAggregate] } {
		return $retCode
	}

	set cardTypeEnum [card cget -type]
	if {($cardTypeEnum == $::cardASMXMV12X) && [card isValidFeature $chassis $card $::portFeature10GEAggregate] &&	\
		([card cget -operationMode] == $::cardOperationModeNormal)	&& ($port == [card cget -portCount]) } {
		# Because in normal mode isValid/isActive return false for port 13, the 10G LAN XFP - Aggregate port
		return $retCode
	}

    sgPuts {port setFactoryDefaults $chassis $card $port}

# "port get" has been called in the ixSgMain to get the owner.
    if [port isValidFeature $chassis $card $port $::portFeatureDualPhyMode] {
        sgPuts [format "port setPhyMode $\::%s \$chassis \$card \$port" [getEnumString port -phyMode]]
        sgPuts ""
    }

	set moreCheck 0
	
	if { [port isValidFeature $chassis $card $port $::portFeatureStreamExtractor] } {
		
		# We don't need to generate any port configurations for the second Inline port
		set inLinePortId	3
		if { $port != $inLinePortId } { 

			set portParmList	[list name speed duplex autonegotiate advertise100FullDuplex advertise100HalfDuplex \
									  advertise10FullDuplex advertise10HalfDuplex advertise1000FullDuplex ] 
		
			partiallyGenerateCommand port $portParmList no
			set moreCheck 1
		}
	} elseif {[port isActiveFeature $chassis $card $port $::portFeatureVcat]} {
# Check for more parms, so far I know about these
		set portParmList [list autoDetectInstrumentationMode enableAutoDetectInstrumentation enableSimulateCableDisconnect \
							   ignoreLink loopback name portMode receiveMode]
		partiallyGenerateCommand port $portParmList no
		set moreCheck 1
	} elseif {[port isActiveFeature $chassis $card $port $::portFeatureSonet]} {
# Check for more parms, so far I know about these
		set portParmList [list enableRepeatableLastRandomPattern enableSimulateCableDisconnect \
							   flowControl directedAddress multicastPauseAddress \
							   enableAutoDetectInstrumentation autoDetectInstrumentationMode ignoreLink \
						       loopback name portMode receiveMode transmitMode]
		if {[port isValidFeature $chassis $card $port $::portFeatureDataCenterMode]} {
			lappend portParmList enableDataCenterMode flowControlType pfcEnableValueList dataCenterMode
		}	
        if {[port isValidFeature $chassis $card $port $::portFeatureWanIFSStretch] } {
            lappend portParmList enableWanIFSStretch
        }
		partiallyGenerateCommand port $portParmList no
		set moreCheck 1
	} elseif {($cardTypeEnum == $::cardASMXMV12X) && ([port isActiveFeature $chassis $card $port $::portFeature1GEAggregate] ||\
		([card isActiveFeature $chassis $card $::portFeature10GEAggregate] && \
	    ![port isActiveFeature $chassis $card $port $::portFeature10GEAggregate])) } {
	    # 1GEAggregate and 10GEAggregate are two separate modes for Whistler card. 
	    # Under 10GEAggregate mode, ports 1-12 are not functioning, so portFeature1GEAggregate is not active.
		set portParmList [list name]
		if {![card isActiveFeature $chassis $card $::portFeature10GEAggregate]} {
			lappend portParmList speed duplex flowControl directedAddress multicastPauseAddress loopback \
								transmitMode autonegotiate advertise1000FullDuplex portMode rxTxMode 
		}
		# When the card is in 10GEAggregate mode, operationModeList is available for configuration
		if {[port isValidFeature $chassis $card $port $::portFeatureRtp] || [port isValidFeature $chassis $card $port $::portFeatureTsoLro] } {
			lappend portParmList operationModeList
		}
		partiallyGenerateCommand port $portParmList no
		sgPuts {port set $chassis $card $port}
		doInterfaceTable $chassis $card $port
		return $retCode
	} elseif {($cardTypeEnum == $::cardASMXMV12X) && [port isActiveFeature $chassis $card $port $::portFeature10GEAggregate]} {
		set portParmList [list enableSimulateCableDisconnect loopback portMode name ]
		if {[port isValidFeature $chassis $card $port $::portFeatureRtp] || [port isValidFeature $chassis $card $port $::portFeatureTsoLro] } {
			lappend portParmList operationModeList
		}
		partiallyGenerateCommand port $portParmList no
		set moreCheck 1
	} elseif {[port isActiveFeature $chassis $card $port $::::portFeatureFCPhy]} {
		set portParmList [list name speed loopback  enableSimulateCableDisconnect portMode autonegotiate \
				transmitMode  rxTxMode  enableAutoDetectInstrumentation autoDetectInstrumentationMode ignoreLink receiveMode \
				enableDynamicMPLSMode enableTransparentDynamicRateChange enableTxRxSyncStatsMode txRxSyncInterval operationModeList]
      	partiallyGenerateCommand port $portParmList no
		set moreCheck 1
     } else {
		generateCommand port no
		sgPuts {port set $chassis $card $port}
	}	

	if { $moreCheck == 1 } {
		if {[port isValidFeature $chassis $card $port $::portFeatureTransmitExtendedTimestamp] } {
			set portParmList [list transmitExtendedTimestamp]
			partiallyGenerateCommand port $portParmList no
		}

		sgPuts {port set $chassis $card $port}
	}
	
	# This is for Native FC additional port information (Flow Control / Timeout Values / Speeds)
	if {[port isActiveFeature $chassis $card $port $::portFeatureFCPhy]} {
		if {![fcPort get $chassis $card $port]} {
			generateCommand fcPort no
			sgPuts {fcPort set $chassis $card $port}
        } else {
            logMsg "Error getting fcPort"
            set retCode 1 
        }
	}

	# these three apply to k2	
	generatePcsLaneError $chassis $card $port	
    generateHse40GQsfp $chassis $card $port
    generateHseCfpQsfp $chassis $card $port
	getTxLane $chassis $card $port
	
	# The following two are applicable to K2
	generateBertLane $chassis $card $port
	generateBertLaneError $chassis $card $port

	generateCfpPort $chassis $card $port

		

	set activeBertListK2 [port isActiveFeature $chassis $card $port $::portFeatureBertList]
	
    if { $activeBertListK2 == 0 && ([port isActiveFeature $chassis $card $port $::portFeatureBert] || \
        [port isActiveFeature $chassis $card $port $::portFeatureBertChannelized] || \
        [port isValidFeature  $chassis $card $port $::portFeatureBertUnframed]) } {

		# We need the port transmitMode and receiveMode to be in correct mode so that 
		# the isActiveFeature portFeatureBertChannelized return correct value

		if {[port isActiveFeature $chassis $card $port $::portFeatureBertChannelized] } {
			if [port isActiveFeature $chassis $card $port $::portFeatureXaui] {
				set levelList { 1 2 3 4}
			} else {
				set levelList { 1.0 2.0 3.0 4.0 }
			}

			foreach levelItem $levelList {
				if [bert isChannelized $chassis $card $port $levelItem] {
					sgPuts "bert channelize \$chassis \$card \$port $levelItem"
					for {set index 1 } {$index <= 4} { incr index } {
						set nextLevel [format "%d.%d" [string range $levelItem 0 0] $index]
						if {![getCommand bert $chassis $card $port $nextLevel]} {
							sgPuts "bert set \$chassis \$card \$port $nextLevel"
						} else {
							logMsg "Error in getting bert on channel $nextLevel "
							set retCode 1 
						}
					}
				} else {
					if {![getCommand bert $chassis $card $port $levelItem]} {
						sgPuts "bert set \$chassis \$card \$port $levelItem"
					} else {
						logMsg "Error in getting bert on channel $levelItem "
						set retCode 1 
					}
				}
			}
		} else {
			if {![getCommand bert $chassis $card $port]} {
				sgPuts {bert set $chassis $card $port}
			} else {
				logMsg "Error in getting bert"
				set retCode 1 
			}
		}
	} else {

		if { [port isValidFeature $chassis $card $port $::portFeatureStreamExtractor]} {

			set statParamList [list mode enableTemperatureSensorsStats]

		} else {

			set statParamList [ list mode enableValidStats enableProtocolServerStats enableArpStats enablePosExtendedStats \
								    enableDhcpStats enableDhcpV6Stats ]

			if {[port isActiveFeature $chassis $card $port $::portFeatureRpr]} {
				lappend statParamList includeRprPayloadFcsInCrc
			}

			if {[port isActiveFeature $chassis $card $port $::portFeatureAtm]} {
				lappend statParamList enableAtmOamStats
			}

			if {[port isValidFeature $chassis $card $port $::portFeatureEthernetOAM]} {
				lappend statParamList enableEthernetOamStats
			}

			if {[port isValidFeature $chassis $card $port $::portFeatureDataCenterMode]} {
				lappend statParamList enableFcoeStats fcoeRxSharedStatType1 fcoeRxSharedStatType2 enableLldpDcbxStats
			}

			if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy]} {
				lappend statParamList enableFcoeStats fcoeRxSharedStatType1 fcoeRxSharedStatType2
			}

			if {[lsearch [package names] IxTclProtocol] != -1} {
				set statParamList [concat $statParamList [list enableBgpStats enableIcmpStats enableOspfStats enableIsisStats \
										   enableRsvpStats enableLdpStats enableIgmpStats enableOspfV3Stats \
										   enablePimsmStats enableMldStats enableStpStats enableEigrpStats \
										   enableBfdStats enableCfmStats enableLacpStats enableOamStats enableMplsTpStats enableElmiStats]]
			}
		}  

		if { !$activeBertListK2 } {
			if {![stat get statAllStats $chassis $card $port]} {
				partiallyGenerateCommand stat $statParamList
				sgPuts {stat set $chassis $card $port}
			} else {
				logMsg "Error in getting stat"
				set retCode 1 
			}
		}

		if { $retCode == 0 && [stat cget -mode] == $::statQos} {
			if {![qos get $chassis $card $port]} {
				sgPuts "qos setup [getEnumString qos -packetType]"
				generateCommand qos no
				sgPuts {qos set $chassis $card $port}
			} else {
				logMsg "Error getting qos"
				set retCode 1 
			}  
		}
	}

    set activeBertList [port isActiveFeature $chassis $card $port $::portFeatureBertList]
    
    if {[port isActiveFeature $chassis $card $port $::portFeatureBertErrorGeneration] && $activeBertList == 0} {

        if [port isActiveFeature $chassis $card $port $::portFeatureBertChannelized]  {
            if [port isActiveFeature $chassis $card $port $::portFeatureXaui] {
                set levelList { 1 2 3 4}
            } else {
                set levelList { 1.0 2.0 3.0 4.0 }
            }

            foreach levelItem $levelList {
                if [bert isChannelized $chassis $card $port $levelItem] {
                    for {set index 1 } {$index <= 4} { incr index } {
                        set nextLevel [format "%d.%d" [string range $levelItem 0 0] $index]
                        if {![getCommand bertErrorGeneration $chassis $card $port $nextLevel]} {
                            sgPuts "bertErrorGeneration set \$chassis \$card \$port $nextLevel"
                        } else {
                            logMsg "Error in getting bertErrorGeneration on channel $nextLevel "
                            set retCode 1 
                        }
                    }
                } else {
                    if {![getCommand bertErrorGeneration $chassis $card $port $levelItem]} {
                        sgPuts "bertErrorGeneration set \$chassis \$card \$port $levelItem"
                    } else {
                        logMsg "Error in getting bertErrorGeneration on channel $levelItem "
                        set retCode 1 
                    }
                }
            }

        } else {
            if {![getCommand bertErrorGeneration $chassis $card $port]} {          
                sgPuts {bertErrorGeneration set $chassis $card $port}
            } else {
                logMsg "Error in getting bertErrorGeneration"
                set retCode 1 
            }
        }  
    }
    
    if {[port isValidFeature $chassis $card $port $::portFeatureBertUnframed]} {

        if {![getCommand bertUnframed $chassis $card $port]} {          
            sgPuts {bertUnframed set $chassis $card $port}
        } else {
            logMsg "Error in getting bertUnframed"
            set retCode 1 
        }  
    }

    if {[port isValidFeature $chassis $card $port $::portFeatureForcedCollisions]} {

        if {![getCommand collisionBackoff $chassis $card $port]} {          
            sgPuts {collisionBackoff set $chassis $card $port}
        } else {
            logMsg "Error in getting collisionBackoff"
            set retCode 1 
        }  

        if {![getCommand forcedCollisions $chassis $card $port]} {          
            sgPuts {forcedCollisions set $chassis $card $port}
        } else {
            logMsg "Error in getting forcedCollisions"
            set retCode 1 
        }  
    }

    if {[port isActiveFeature $chassis $card $port $::portFeatureRxPacketGroups] || \
        [port isActiveFeature $chassis $card $port $::portFeatureRxSequenceChecking] || \
        [port isActiveFeature $chassis $card $port $::portFeatureRxWidePacketGroups]} {

        if {![packetGroup getRx $chassis $card $port]} { 
            set packetGroupCommandExcludeList ""
            if { ![port isValidFeature $chassis $card $port $::portFeatureDelayVariation]} { 
				lappend packetGroupCommandExcludeList delayVariationMode
			}
            generateCommand packetGroup yes $packetGroupCommandExcludeList
            
            # this object needs to come before the setRx
            if {[port isActiveFeature $chassis $card $port $::portFeatureRateMonitoring]} {
                getPacketGroupThresholdList $chassis $card $port
            }
            
            sgPuts {packetGroup setRx $chassis $card $port}
			sgPuts ""
			# The splitPacketGroup should be set after packetGroup configuration
            if {[port isActiveFeature $chassis $card $port $::portFeatureSplitPgid]} {
                getSplitPacketGroup $chassis $card $port
            }                    
        } else {
            logMsg "Error in getting packetGroup"
            set retCode 1 
        }  
    }

    if {[port isActiveFeature $chassis $card $port $::portFeatureRxDataIntegrity]} {

        if {![dataIntegrity getRx $chassis $card $port]} { 
            generateCommand  dataIntegrity         
            sgPuts {dataIntegrity setRx $chassis $card $port}
        } else {
            logMsg "Error in getting dataIntegrity"
            set retCode 1 
        }  
    }

    if {[port isActiveFeature $chassis $card $port $::portFeatureAutoDetectRx]} {

        if {![autoDetectInstrumentation getRx $chassis $card $port]} { 
			set autoDetectInstrCommandList [list startOfScan signature enableSignatureMask signatureMask]
			if {[port isActiveFeature $chassis $card $port $::portFeatureMisdirectedPacket]} {
			lappend autoDetectInstrCommandList enableMisdirectedPacketMask misdirectedPacketMask
		}
			partiallyGenerateCommand autoDetectInstrumentation $autoDetectInstrCommandList
            sgPuts {autoDetectInstrumentation setRx $chassis $card $port}
        } else {
            logMsg "Error in getting autoDetectInstrumentation"
            set retCode 1 
        }  
    }

    if {[port isActiveFeature $chassis $card $port $::portFeatureRxRoundTripFlows]} {

        if {![getCommand tcpRoundTripFlow  $chassis $card $port]} {          
            sgPuts {tcpRoundTripFlow set $chassis $card $port}
        } else {
            logMsg "Error in getting tcpRoundTripFlow"
            set retCode 1 
        }
    }

    #We need to do a port get in order to get portMode. So I put the following part after port command.
	generateSonetCommands $chassis $card $port

	if {[port isActiveFeature $chassis $card $port $::portFeatureXFP]} {

        if {![getCommand xfp $chassis $card $port]} {
            sgPuts {xfp set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting xfp"
            set retCode 1 
        }  
    }

    if {[port isActiveFeature $chassis $card $port $::portFeatureSfpPlus] || [port isActiveFeature $chassis $card $port $::portFeatureFCPhy]} {

        if {![getCommand sfpPlus $chassis $card $port]} {
            sgPuts {sfpPlus set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting sfpPlus"
            set retCode 1 
        }  
    }
    
    if {[port isActiveFeature $chassis $card $port $::portFeatureLinkFault]} {

        if {![getCommand  linkFaultSignaling $chassis $card $port]} {
			if {[generateCustomOrderedSet] } {
				logMsg "Error in generateCustomOrderedSet"
				set retCode 1
			}
            sgPuts {linkFaultSignaling set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting linkFaultSignaling"
            set retCode 1 
        }  
    }

    if {[port isValidFeature $chassis $card $port $::portFeatureXaui]} {

        if {![getCommand xaui $chassis $card $port]} {
            sgPuts {xaui set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting xaui"
            set retCode 1 
        }  
    } elseif {[port cget -type] == $::port10GELSM} {
		# Currently there is no object that allows to config clock for Denali
		# temporarily it has been added to xaui object, only clockType applies
        if {![xaui get $chassis $card $port]} {
			partiallyGenerateCommand xaui clockType
			sgPuts {xaui set $chassis $card $port}
			sgPuts ""
		} else {
            logMsg "Error in getting xaui"
            set retCode 1 
        }  
	}

    if {[port isActiveFeature $chassis $card $port $::portFeatureLasi]} {

        if {![getCommand lasi $chassis $card $port]} {
            sgPuts {lasi set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting lasi"
            set retCode 1 
        }  
    }

    if {[port isValidFeature $chassis $card $port $::portFeatureVsr]} {

        if {![getCommand vsrError $chassis $card $port]} {
            sgPuts {vsrError set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting vsrError"
            set retCode 1 
        }  
    }

    if {[port isValidFeature $chassis $card $port $::portFeatureFec]} {

		if {![getCommand opticalDigitalWrapper $chassis $card $port]} {
            sgPuts {opticalDigitalWrapper set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting opticalDigitalWrapper"
            set retCode 1 
        }

        if {![getCommand fecError $chassis $card $port]} {
            sgPuts {fecError set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting fecError"
            set retCode 1 
        }  
    }

    if {[port isActiveFeature $chassis $card $port $::portFeatureDccProperties]} {

        if {![getCommand dcc $chassis $card $port]} {
            sgPuts {dcc set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting dcc"
            set retCode 1 
        }  
    }
    
    if {[port isValidFeature $chassis $card $port $::portFeatureFlexibleTimestamp]} {
        if {![getCommand flexibleTimestamp $chassis $card $port]} {
            sgPuts {flexibleTimestamp set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting flexibleTimestamp"
            set retCode 1 
        }  
    }

	generateAtmConfig  $chassis $card $port

	if {[getCaptureAndFilters $chassis $card $port]} {
		logMsg "Error in getting getFilters"
		set retCode 1 
	}
    
    generateTxRxPreamble $chassis $card $port

	# Since currently only gapControlMode is the only config streamRegion parm, therefore
	# we will check for the feature
    if { [port isValidFeature $chassis $card $port $::portFeatureGapControlMode] } {
		if {![getCommand streamRegion $chassis $card $port]} {
            sgPuts {streamRegion set $chassis $card $port}
        } else {
            logMsg "Error in getting streamRegion"
            set retCode 1 
        }  
    }

	generateProtocolServer $chassis $card $port
	generateMacSec $chassis $card $port

    if { [port isValidFeature $chassis $card $port $::portFeatureEthernetOAM] } {
		if {![getCommand oamPort $chassis $card $port]} {
            sgPuts {oamPort set $chassis $card $port}
        } else {
            logMsg "Error in getting oamPort"
            set retCode 1 
        }  
    }

	set portFeatureIntrinsicLatency 290

    if {[port isValidFeature $chassis $card $port $portFeatureIntrinsicLatency] } { 
		if {[port isActiveFeature $chassis $card $port $portFeatureIntrinsicLatency] } {
			sgPuts {ixEnablePortIntrinsicLatencyAdjustment $chassis $card $port true}
		} else {
			sgPuts {ixEnablePortIntrinsicLatencyAdjustment $chassis $card $port false}
		}
	}

    if { [ port isValidFeature $chassis $card $port $::portFeatureCapturePlayback ] } {
        if {![getCommand capturePlayback $chassis $card $port]} {
            sgPuts {capturePlayback set $chassis $card $port}
            sgPuts ""
        } else {
            logMsg "Error in getting capturePlayback"
            set retCode 1 
        }
    }
	

    return $retCode
}


########################################################################
# Procedure: generatePcsLaneError
#
# This command gets PcsLaneError configuration parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::generatePcsLaneError { chassis card port} \
{
    set retCode $::TCL_OK
	
	if {[port isActiveFeature $chassis $card $port $::portFeaturePcsLaneErrorGeneration]} {
		if {![getCommand pcsLaneError $chassis $card $port]} {
			sgPuts ""
			sgPuts {pcsLaneError set $chassis $card $port}
			sgPuts ""
		} else {
			logMsg "Error in getting pcsLaneError"
			set retCode $::TCL_ERROR 
		}
	}

	return $retCode
}

########################################################################
# Procedure: generateHse40GQsfp
#
# This command gets K2 Hse40GQsfp pre-emphasis and equalization configuration 
# parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::generateHse40GQsfp { chassis card port} \
{
    set retCode $::TCL_OK
	
	if {[port isValidFeature $chassis $card $port $::portFeatureTransceiverHse40GQsfp]} {

        if {![getCommand hse40GQsfp $chassis $card $port]} {
            sgPuts ""
            set laneCount [hse40GQsfp getLaneCount]
            for {set lane 0} {$lane < $laneCount } {incr lane} {
                hse40GQsfp getLane $lane
                generateCommand hse40GQsfpLane 
                sgPuts "hse40GQsfp setLane $lane"
            }
            sgPuts {hse40GQsfp set $chassis $card $port}
            sgPuts ""
		} else {
			logMsg "Error in getting hse40GQsfp"
			set retCode $::TCL_ERROR 
		}
	}

	return $retCode
}

########################################################################
# Procedure: generateHseCfpQsfp
#
# This command gets K2 HseCfpQsfp pre-emphasis and equalization configuration 
# parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::generateHseCfpQsfp { chassis card port} \
{
    set retCode $::TCL_OK
	
	if {[port isActiveFeature $chassis $card $port $::portFeatureTransceiverCfpQsfp]} {

        if {![getCommand hseCfpQsfp $chassis $card $port]} {
            sgPuts ""
            set laneCount [hseCfpQsfp getLaneCount]
            for {set lane 0} {$lane < $laneCount } {incr lane} {
                hseCfpQsfp getLane $lane
                generateCommand hseCfpQsfpLane 
                sgPuts "hseCfpQsfp setLane $lane"
            }
            sgPuts {hseCfpQsfp set $chassis $card $port}
            sgPuts ""
		} else {
			logMsg "Error in getting hseCfpQsfp"
			set retCode $::TCL_ERROR 
		}
	}

	return $retCode
}


########################################################################
# Procedure: generateCfpPort
#
# This command gets MK CfpPort configuration 
# parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::generateCfpPort { chassis card port} \
{
    set retCode $::TCL_OK

	if {[cfpPort get $chassis $card $port] == $::TCL_OK} {

        if {![getCommand cfpPort $chassis $card $port]} {
            sgPuts ""
            sgPuts {cfpPort set $chassis $card $port}
            sgPuts {cfpPort write $chassis $card $port}
            sgPuts ""
		} else {
			logMsg "Error in getting cfpPort"
			set retCode $::TCL_ERROR 
		}
	}

	return $retCode
}


########################################################################
# Procedure: generateMacSec
#
# This command gets Tx and Rx MacSec channel configuration parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::generateMacSec { chassis card port} \
{
    set retCode $::TCL_OK
	
	if {[port isActiveFeature $chassis $card $port $::portFeatureMACSec]} {

		set macSecCmdList	[list macSecTx macSecRx]

		foreach macSecCmd	$macSecCmdList {

			if {![$macSecCmd select $chassis $card $port]} {

				sgPuts ""
				sgPuts "$macSecCmd select [format "$%s $%s $%s" chassis card port]"
				sgPuts "$macSecCmd clearAllChannels"

				if {![$macSecCmd get] } {
					generateCommand  $macSecCmd  

					if {![$macSecCmd getFirstChannel] } {

						if {[generateMacSecChannels $macSecCmd $chassis $card $port ]} { 
							errorMsg "Error generateMacSecChannels for $chassis $card $port on circuit ..."
							set retCode $::TCL_ERROR
						}
					
						while {![$macSecCmd getNextChannel] } {
							if {[generateMacSecChannels $macSecCmd $chassis $card $port]} { 
								errorMsg "Error generateMacSecChannels for $chassis $card $port on circuit ..."
								set retCode $::TCL_ERROR
							} 
						}
					}
					sgPuts "$macSecCmd set"
					sgPuts ""
				} else {
					errorMsg "Error getting $macSecCmd on $chassis $card $port"
					set retCode $::TCL_ERROR
				}
			} else {
				errorMsg "Error selecting $macSecCmd on $chassis $card $port"
				set retCode $::TCL_ERROR
			}
		}
	}

	return $retCode
}


########################################################################
# Procedure: generateMacSecChannels
#
# This command gets MacSec channel configuration parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::generateMacSecChannels { macSecCmd chassis card port} \
{
	set retCode $::TCL_OK
	sgPuts ""

	set associationList [list secureAN0 secureAN1 secureAN2 secureAN3 ]

	set macSecGeneralList [list channelName macAddress portIdentifier]
	partiallyGenerateCommand macSecChannel $macSecGeneralList
	sgPuts ""
	set macSecPerAssocList [list enableAssociation associationKey]

	foreach type $associationList {
		macSecChannel getAssociation $type
		partiallyGenerateCommand macSecChannel $macSecPerAssocList no
		sgPuts "macSecChannel setAssociation $type"
	}

	sgPuts "$macSecCmd addChannel"

	return $retCode
}

########################################################################
# Procedure: doFilterProperties
#
# This command gets the RX Filter properties
# Arguments(s): chassis, card, and port numbers (1-based)
# Returned Result: 0 on success; 1 otherwise
########################################################################

proc scriptGen::doFilterProperties { chassis card port } \
{
    set retCode 0
    
    set SYMBOL($::AND)     "\$AND"
    set SYMBOL($::NAND)    "\$NAND"
    set SYMBOL($::OR)      "\$OR"
    set SYMBOL($::NOR)     "\$NOR"
    set SYMBOL($::XOR)     "\$XOR"
    set SYMBOL($::DA1)     "\$DA1"
    set SYMBOL($::SA1)     "\$SA1"
    set SYMBOL($::PAT1)    "\$PAT1"
    set SYMBOL($::PAT2)    "\$PAT2"
    set SYMBOL($::NOTDA1)  "\$NOTDA1"
    set SYMBOL($::NOTSA1)  "\$NOTSA1"
    set SYMBOL($::NOTPAT1) "\$NOTPAT1"
    set SYMBOL($::NOTPAT2) "\$NOTPAT2"

    set excludedParmList [list userDefinedStat1PatternExpression userDefinedStat2PatternExpression \
                               captureTriggerPatternExpression captureFilterPatternExpression \
                               asyncTrigger1PatternExpression asyncTrigger2PatternExpression]

    if {![filter get $chassis $card $port]} {
        sgPuts "filter setDefault"
        generateCommand filter no $excludedParmList
        foreach excludedParam $excludedParmList {
            set exprStr [filter cget -$excludedParam]
            if {$exprStr != ""} {
                set exprList [split $exprStr]
                set tokenList [list]
                foreach token $exprList {
                    lappend tokenList $SYMBOL($token)
                }
                set exprStr [join $tokenList " "]
            }
            sgPuts "filter config -$excludedParam \"$exprStr\""
        }
        sgPuts "filter set \$chassis \$card \$port"
        sgPuts ""
    } else {
        set retCode 1
    }
    return $retCode 
}


########################################################################
# Procedure: getCaptureAndFilters
#
# This command gets capture and filter parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::getCaptureAndFilters { chassis card port} \
{
    set retCode 0

    set cardTypeEnum [card cget -type]

	 
	if {($cardTypeEnum == $::cardASMXMV12X) &&([card isActiveFeature $chassis $card $::portFeature1GEAggregate] || \
		[card isActiveFeature $chassis $card $::portFeature10GEAggregate])} {
		# Don't need to generate capture/filter information
		return $retCode
	}

    if {![port isActiveFeature $chassis $card $port $::portFeatureBert] && \
        ![port isActiveFeature $chassis $card $port $::portFeatureBertChannelized] && \
        ![port isValidFeature  $chassis $card $port $::portFeatureBertUnframed]} {  

		if { [port isValidFeature $chassis $card $port $::portFeatureStreamExtractor]} {

			if { [port isValidFeature $chassis $card $port $::portFeatureStreamExtractorMonitor]} {

				set inlinePortList	 [list 2 3]
				set modifierTypeList [list streamExtractorDestMac streamExtractorDestIpV4 streamExtractorDestUdp]

				sgPuts
				set commonParmList	[list logicControl]
				set filterParmList  [list offset filterType offsetMode pattern ]

				foreach inlinePort	$inlinePortList {

					sgPuts "# Filter configuration for inline port: $inlinePort" 
					sgPuts "set inlinePortId $inlinePort"

					if {[streamExtractorFilter get $chassis $card $port $inlinePort]} {
						errorMsg "Error in getting streamExtractorFilter for inline port $inlinePort on $chassis $card $port"
						set retCode 1	
					}

					set filterId 1
					while {![streamExtractorFilter getFilter $filterId]} {

						set filterParmList  [list offset filterType offsetMode pattern ]
						switch [streamExtractorFilter cget -filterType] "
							$::streamExtractorCustom -
							$::streamExtractorMacDa -
							$::streamExtractorMacSa -
							$::streamExtractorIpDa -
							$::streamExtractorIpSa -
							$::streamExtractorIpVersion -
							$::streamExtractorLayer4ProtocolType {  
								lappend filterParmList mask
							} 							
						"

						if {[streamExtractorFilter cget -filterType] <= $::streamExtractorIpSa } {
							lappend filterParmList mask
						}
						partiallyGenerateCommand streamExtractorFilter $filterParmList no
						sgPuts "streamExtractorFilter setFilter $filterId"
						sgPuts
						incr filterId
					}

					partiallyGenerateCommand streamExtractorFilter $commonParmList no
					sgPuts "streamExtractorFilter set \$chassis \$card \$port \$inlinePortId "
					sgPuts

					foreach modifierType $modifierTypeList {
						if {[streamExtractorModifier get $chassis $card $port $inlinePort $modifierType]} {
							errorMsg "Error in getting streamExtractorModifier for inline port $inlinePort ($modifierType) on $chassis $card $port"
							set retCode 1 
						}
						sgPuts "streamExtractorModifier setDefault"
						generateCommand streamExtractorModifier no
						sgPuts "streamExtractorModifier set \$chassis \$card \$port \$inlinePortId $modifierType"
						sgPuts
					}
				}
			}

		} else {

            if {[port isValidFeature  $chassis $card $port $::scriptGen::portFeaturePatternFilter1 ]} {  

            	if {[doFilterProperties $chassis $card $port]} {
            		logMsg "Error in getting filter on $chassis $card $port"
            		set retCode 1
            	} 
                                   
			    if {![filterPallette get $chassis $card $port]} {
				    generateCommand filterPallette 
				    sgPuts {filterPallette set $chassis $card $port}
			    } else {
				    logMsg "Error in getting filterPallette"
				    set retCode 1 
			    }

				if {($cardTypeEnum == $::cardEthernetVM) || ($cardTypeEnum == $::cardEthernetVMS)} {
					#dont generate the capture/filter information for VMS port
					return $retCode
				}

			    if {![getCommand capture $chassis $card $port]} {
				    sgPuts {capture set $chassis $card $port}
			    } else {
				    logMsg "Error in getting capture"
				    set retCode 1 
			    }
            }
		}
	}
    
    return $retCode 
}

########################################################################
# Procedure: generateSonetCommands
#
# This command gets and generates sonet and other sonet command parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::generateSonetCommands { chassis card port {circuitId 0} } \
{
    set retCode $::TCL_OK

	if {![port isActiveFeature $chassis $card $port $::portFeatureVcat]} 	{

		if { ([port isActiveFeature $chassis $card $port $::portFeaturePos]		|| \
			  [port isActiveFeature $chassis $card $port $::portFeatureAtm])	|| \
			 ([port isValidFeature $chassis $card $port $::portFeature10GigWan] || \
			   ( [port isActiveFeature $chassis $card $port $::portFeatureBert] && \
			   ![port isValidFeature $chassis $card $port $::portFeatureBertUnframed]))} {

			if {![getCommand sonet $chassis $card $port]} {
				sgPuts {sonet set $chassis $card $port}
				sgPuts ""
			} else {
				logMsg "Error in getting sonet"
				set retCode $::TCL_ERROR 
			}
		}
		if {([port isActiveFeature $chassis $card $port $::portFeaturePos] || \
			[port isActiveFeature $chassis $card $port $::portFeatureAtm]) } {

			getSonetCommands $chassis $card $port
		}

	} else {
		# Generate sonet and other related configurations per port and per circuit as well
		#
		 
		# Port level configurations  
		if {![sonet get $chassis $card $port]} {
			set sonetParmList [list interfaceType useRecoveredClock operation]
			partiallyGenerateCommand sonet $sonetParmList
			sgPuts {sonet set $chassis $card $port}
			sgPuts ""
		} else {
			logMsg "Error in getting sonet"
			set retCode $::TCL_ERROR 
		}

		if {![sonetCircuitList select $chassis $card $port]} {
			sgPuts {sonetCircuitList select $chassis $card $port}
			sgPuts {sonetCircuitList clearAllCircuits}

			if {![sonetCircuitList getFirst] } {
				if {[generateSonetCircuit $chassis $card $port ]} { 
					errorMsg "Error generateSonetCircuit for $chassis $card $port on circuit ..."
					set retCode $::TCL_ERROR
				}
			
				while {![sonetCircuitList getNext] } {
					if {[generateSonetCircuit $chassis $card $port ]} { 
						errorMsg "Error generateSonetCircuit for $chassis $card $port on circuit ..."
						set retCode $::TCL_ERROR
					} 
				}
			}
			sgPuts ""
		} else {
			errorMsg "Error selecting port for sonetCircuitList..."
			set retCode $::TCL_ERROR
			return $retCode
		}
	}

    return $retCode 
}

#####################################################################################
# Procedure: generateSonetCircuit
#
# This command gets and generates sonet circuit and other sonet command parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
#####################################################################################

proc scriptGen::generateSonetCircuit { chassis card port } \
{
    set retCode $::TCL_OK

	sgPuts ""
	generateCommand sonetCircuit
	sgPuts {sonetCircuitList add}
	sgPuts ""

	# The id is assigned when we do the add
	set circuitId [sonetCircuit cget -index]

	sgPuts ""
	sgPuts "set circuitId $circuitId"
	sgPuts ""

	if {![sonetCircuitProperties get $chassis $card $port $circuitId]} {
		generateCommand sonetCircuitProperties 
		sgPuts {sonetCircuitProperties set $chassis $card $port $circuitId}
	} else {
		 errorMsg "Error getting sonetCircuitProperties on $chassis $card $port circuit $circuitId"
		 set retCode $::TCL_ERROR
	}
	sgPuts ""

	# For nonvirtual circuits lcas get should fail, therefore we don't need to generate
	# Lcas information
	if {[lcas get $chassis $card $port $circuitId] == $::TCL_OK} {
		generateCommand lcas 
		sgPuts {lcas set $chassis $card $port $circuitId}
	} 
	sgPuts ""

	getSonetCommands $chassis $card $port $circuitId

    return $retCode 
}


########################################################################
# Procedure: getSonetCommands
#
# This command gets sonet and other sonet command parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::getSonetCommands { chassis card port {circuitId 0} } \
{
    variable generateHdlcPerStream

    set retCode 0

	set	sonetHeader($::sonetHdlcPppIp)				sonetHdlcPppIp
	set	sonetHeader($::sonetCiscoHdlc)				sonetCiscoHdlc
	set	sonetHeader($::sonetOther)					sonetOther
	set	sonetHeader($::sonetFrameRelay1490)			sonetFrameRelay1490
	set	sonetHeader($::sonetFrameRelayCisco)		sonetFrameRelayCisco
	set	sonetHeader($::sonetSrp)					sonetSrp
	set	sonetHeader($::sonetCiscoHdlcIpv6)			sonetCiscoHdlcIpv6
	set	sonetHeader($::sonetHdlcPppIso)				sonetHdlcPppIso
	set	sonetHeader($::sonetRpr)					sonetRpr
	set	sonetHeader($::sonetAtm)					sonetAtm
	set	sonetHeader($::sonetGfp)					sonetGfp
	set sonetHeader($::sonetLaps)					sonetLaps
		
	if { $circuitId } {
		set headerType [sonetCircuitProperties cget -payloadType]
	} else {			
		set headerType [sonet cget -header]
	}

	set generateHdlcPerStream 0
	sgPuts ""	

    switch $sonetHeader($headerType) {
        "sonetSrp" { 
			########## SRP and RPR are not supported for VCAT

			# hdlc is configured here because of the address/control parameters
			# in reality, hdlc for this header type shouldn't be enabled
			if {![getCommand hdlc $chassis $card $port ]} {               
				sgPuts {hdlc set $chassis $card $port }                 
			} 
			
			# This is not per circuit, so it won't get generated
			if {[port isActiveFeature $chassis $card $port $::portFeatureSrpFullFeatured]} {

				if {![getCommand srpUsage $chassis $card $port]} {               
					sgPuts {srpUsage set $chassis $card $port}                 
				} else {
					logMsg "Error in getting srpUsage"
					set retCode 1 
				}
			}        
		} 
        "sonetRpr" {  
			########## SRP and RPR are not supported for VCAT
			if {[port isActiveFeature $chassis $card $port $::portFeatureRpr]} {
				if {![getCommand rprFairness $chassis $card $port]} {
					sgPuts {rprFairness set $chassis $card $port}                 
				} else {
					logMsg "Error in getting rprFairness"
					set retCode 1 
				}
			}
        } 
        "sonetGfp" { 

			if { $circuitId > 0 } {
				if { ![gfpOverhead get $chassis $card $port $circuitId]} {
					set gfpOverheadCommandList [list enableSingleBitErrorCorrection enablePayloadScrambling expectedUPI]
					partiallyGenerateCommand gfpOverhead $gfpOverheadCommandList
					sgPuts {gfpOverhead set $chassis $card $port $circuitId}
				}
			} else {
				if {![getCommand gfpOverhead $chassis $card $port]} {
					sgPuts {gfpOverhead set $chassis $card $port}
				} else {
					sgPuts "Error in getting gfpOverhead"
					set retCode 1 
				}
			}        
		}
        "sonetHdlcPppIp" {  
			if {![getCommand ppp $chassis $card $port $circuitId]} {
				if { $circuitId } {
					sgPuts {ppp set $chassis $card $port $circuitId}
				} else {
					sgPuts {ppp set $chassis $card $port}
				}
			} else {
				logMsg "Error in getting ppp"
				set retCode 1 
			}        
		} 
        "sonetOther" { 
			if { ![hdlc get $chassis $card $port $circuitId]} {
				set hdlcCommandList [list address control]
				partiallyGenerateCommand hdlc $hdlcCommandList
				if { $circuitId } {
					sgPuts {hdlc set $chassis $card $port $circuitId}
				} else {
					sgPuts {hdlc set $chassis $card $port}
				}

			} 
			set generateHdlcPerStream 1
        }
	}

	getSonetErrorCommands $chassis $card $port $circuitId

    return $retCode 
}

########################################################################
# Procedure: getSonetErrorCommands
#
# This command gets sonet error command parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::getSonetErrorCommands { chassis card port {circuitId 0} } \
{
    set retCode 0

	if {[port isActiveFeature $chassis $card $port $::portFeatureVcat]} 	{

		# VCAT port

		sgPuts "\n# Configuring sonet errors for port"
		set portErrorList [list sonetLofError sonetBip1Error sonetBip2Error sonetLineAis sonetLineRei sonetLineRdi]

		if {![sonetError get $chassis $card $port]} {
			foreach errType $portErrorList {
				sgPuts "sonetError setDefault"
				if {![sonetError getError $errType]} {
					generateCommand sonetError no
					sgPuts "sonetError setError [getEnumString sonetError -sonetErrorType]"
				}
			}
			sgPuts {sonetError set $chassis $card $port}
			sgPuts ""
		} else {
			logMsg "Error in getting sonetError"
			set retCode 1 
		}

		# VCAT Circuit
		set circuiErrorList [list sonetBip3Error sonetPathLop sonetPathAis sonetPathRei sonetPathRdi]
		set timeSlotList [concat [sonetCircuit cget -txActiveTimeslotList] [sonetCircuit cget -txIdleTimeslotList]]
		
		if {[llength $timeSlotList]} {
			sgPuts "# Configuring sonet errors per cicuit"
		}

		# We have no way to figure out which slot is selected for the error type, therefore we will
		# generate all errors for the given slot
		foreach timeSlot $timeSlotList {	
			if {![sonetError get $chassis $card $port $circuitId $timeSlot]} {

				sgPuts "set timeSlot $timeSlot"
				foreach errType $circuiErrorList {
					sgPuts "sonetError setDefault"
					if {![sonetError getError $errType]} {
						generateCommand sonetError no
						sgPuts "sonetError setError [getEnumString sonetError -sonetErrorType]"
					}
				}
				sgPuts {sonetError set $chassis $card $port $circuitId $timeSlot}
				sgPuts ""
			} else {
				logMsg "Error in getting sonetError for $chassis $card $port $circuitId timeslot $timeSlot"
				set retCode 1 
			}
		}
	} else {

		if {[port isValidFeature $chassis $card $port $::portFeaturePos] || \
				[port isValidFeature $chassis $card $port $::portFeature10GigWan]  } {

			if {![sonetError get $chassis $card $port]} {
				 sgPuts "sonetError setDefault"
				for {set errType $::sonetLofError} {$errType < $::sonetMaxSonetErrorStat} {incr errType} {
					if {![sonetError getError $errType]} {
						generateCommand sonetError no
						sgPuts "sonetError setError [getEnumString sonetError -sonetErrorType]"
					}
				}
				sgPuts {sonetError set $chassis $card $port}
				sgPuts ""
			} else {
				logMsg "Error in getting sonetError"
				set retCode 1 
			}
		}
	}

    return $retCode 
}

########################################################################
# Procedure: getSplitPacketGroup
#
# This command gets the SplitPacketGroup parameters.
#
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################
proc scriptGen::getSplitPacketGroup { chassis card port } \
{
    set retCode 0

    set groupIdList { 0 1 2 }

    foreach groupIdIndex $groupIdList {
        splitPacketGroup get $chassis $card $port $groupIdIndex
        generateCommand splitPacketGroup
        sgPuts "splitPacketGroup set \$chassis \$card \$port $groupIdIndex"
    }
     
    return $retCode 
}


########################################################################
# Procedure: getPacketGroupThresholdList
#
# This command gets the getPacketGroupThresholdList parameters.
#
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################
proc scriptGen::getPacketGroupThresholdList { chassis card port } \
{
    set retCode 0

	sgPuts ""
	sgPuts "packetGroupThresholdList clear"
	sgPuts ""
	if {[packetGroupThresholdList getFirst] == $::TCL_OK} {
		generateCommand packetGroupThresholdList
		sgPuts "packetGroupThresholdList add"
		
		while {[packetGroupThresholdList getNext] == $::TCL_OK} {
			generateCommand packetGroupThresholdList
			sgPuts "packetGroupThresholdList add"
		}
	}
     
    return $retCode 
}

########################################################################
# Procedure: generateBertLane
#
# This command gets the Bert lane for K2 
#
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################
proc generateBertLane { chassis card port } \
{
    set retCode $::TCL_OK
    
   	if {[port isActiveFeature $chassis $card $port $::portFeatureBertList]} {

		if {[txLane select $chassis $card $port]} {
			errorMsg "Error selecting txLane port"
			set retCode $::TCL_ERROR
			return $retCode
		}       
		
		set laneNumber 0
		
		foreach lane [txLane getLaneList $chassis $card $port] {    
			if {[txLane getLane $lane]} {
				errorMsg "Error getting lane $lane"
				set retCode $::TCL_ERROR
				continue	;# note; this is highly unlikely to ever fail, it's just sort of a cya to help us w/debugging.
			}
			sgPuts "############  BERT Lane $lane ############"
			if {![scriptGen::getCommand bert $chassis $card $port $laneNumber]} {
			    sgPuts "bert set \$chassis \$card \$port $laneNumber"
			} else {
				logMsg "Error in getting bert on Lane $lane "
				set retCode 1 
			}
			incr laneNumber
		}
		sgPuts
	}
	   
    return $retCode 

}

########################################################################
# Procedure: generateBertLaneError
#
# This command gets the Bert Error insertion lane for K2 
#
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################
proc generateBertLaneError { chassis card port } \
{
    set retCode $::TCL_OK
    
   	if {[port isActiveFeature $chassis $card $port $::portFeatureBertList]} {

		if {[txLane select $chassis $card $port]} {
			errorMsg "Error selecting txLane port"
			set retCode $::TCL_ERROR
			return $retCode
		}        
		
		set laneNumber 0
		
		foreach lane [txLane getLaneList $chassis $card $port] {    
			if {[txLane getLane $lane]} {
				errorMsg "Error getting lane $lane"
				set retCode $::TCL_ERROR
				continue	;# note; this is highly unlikely to ever fail, it's just sort of a cya to help us w/debugging.
			}
			sgPuts "############  BERT Lane Error Generation $lane ############"
			if {![scriptGen::getCommand bertErrorGeneration $chassis $card $port $laneNumber]} {
			    sgPuts "bertErrorGeneration set \$chassis \$card \$port $laneNumber"
			} else {
				logMsg "Error in getting bertErrorGeneration on Lane $lane "
				set retCode 1 
			}
			incr laneNumber
		}
		sgPuts
	}
	   
    return $retCode 

}

########################################################################
# Procedure: getTxLane
#
# This command gets the data lane K2 for lane skew parameters.
#
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################
proc scriptGen::getTxLane { chassis card port } \
{
    set retCode $::TCL_OK
    
   	if {[port isActiveFeature $chassis $card $port $::portFeatureDataLanes]} {

		if {[txLane select $chassis $card $port]} {
			errorMsg "Error selecting txLane port"
			set retCode $::TCL_ERROR
			return $retCode
		}
		sgPuts {txLane select $chassis $card $port}        
		
		foreach lane [txLane getLaneList $chassis $card $port] {    
			if {[txLane getLane $lane]} {
				errorMsg "Error getting lane $lane"
				set retCode $::TCL_ERROR
				continue	;# note; this is highly unlikely to ever fail, it's just sort of a cya to help us w/debugging.
			}
			sgPuts "############  Lane $lane ############"
			generateCommand txLane
			sgPuts [list txLane setLane $lane]
		}
		sgPuts
	}
	   
    return $retCode 
}


########################################################################
# Procedure: getIpProtocol
#
# This command gets Ip protocol parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::getIpProtocol { chassis card port} \
{
    set retCode 0

    getCommand ipAddressTable $chassis $card $port
    
    if {![ipAddressTable getFirstItem]} {
		generateCommand ipAddressTableItem
        sgPuts "ipAddressTable addItem"  
        while {![ipAddressTable getNextItem]} {
			generateCommand ipAddressTableItem
            sgPuts "ipAddressTable addItem"       
        }
    }   
    sgPuts {ipAddressTable set $chassis $card $port}
    
    return $retCode 
}


########################################################################
# Procedure: removeSpaces
#
# This command removes spaces. It is a helper proc for doPortReceiveMode.
# Arguments(s):
# inputStr : a string 
# Returned Result: String with no spaces
########################################################################

proc scriptGen::removeSpaces { inputStr } \
{
    set outStr ""
    set sLeng [string length $inputStr]
    for {set a 0} {$a <= $sLeng } {incr a } {
        string range $inputStr $a 1
        if { [string range $inputStr $a $a] != " " } {
            append outStr [string range $inputStr $a $a]
        }
    }
    return $outStr
}

########################################################################
# Procedure: generateProtocolServer
#
# This command gets  protocol server and interface table configuration parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
#  
########################################################################
proc scriptGen::generateProtocolServer { chassis card port } \
{
    set retCode $::TCL_OK

    if {![protocolServer get $chassis $card $port] && [port isValidFeature $chassis $card $port $::portFeatureProtocols]} {

		sgPuts ""
        if {![ipAddressTable get $chassis $card $port]} {
            getIpProtocol $chassis $card $port
        } else {
            logMsg "Error in getting ipAddressTable"
            set retCode 1 
        }
        
        if [protocolServer cget -enableArpResponse] {
            if {![getCommand arpServer $chassis $card $port] } {
                sgPuts {arpServer set $chassis $card $port}
            } else {
                logMsg "Error in getting arpServer"
                set retCode 1 
            }
        }
		doInterfaceTable $chassis $card $port

		if {[catch {doProtocols $chassis $card $port}]} {
			set lsaParamList [list enableArpResponse enablePingResponse]
			partiallyGenerateCommand protocolServer $lsaParamList
		} else {
			generateCommand protocolServer 
		}
        sgPuts {protocolServer set $chassis $card $port}
        sgPuts ""

    }

    return $retCode 
}

########################################################################
# Procedure: generateTxRxPreamble
#
# This command gets txRxPreamble configuration parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
#  
########################################################################
proc scriptGen::generateTxRxPreamble { chassis card port } \
{
    set retCode $::TCL_OK

	# note:  this is a unique object, because each of the class members have their own 
	#		 isValidFeature enum.  No one feature enum can determine if you can use this object,
	#		 so we will just get the object - if the get fails, just return w/out
	#		 producing any code, otherwise produce the code.
	#		 Potentially we could preface each config w/an isValidFeature, but that's not really req'd here.
	if {[txRxPreamble get $chassis $card $port] == $::TCL_OK} {
        generateCommand txRxPreamble
		sgPuts {txRxPreamble set $chassis $card $port}
    }
    return $retCode 
}

########################################################################
# Procedure: doInterfaceTable
#
# This command gets  protocol interface table parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result: Always return OK
########################################################################

proc scriptGen::doInterfaceTable { chassis card port} \
{
    set retCode 0

	sgPuts ""

    if {![interfaceTable select $chassis $card $port]} {
        sgPuts {interfaceTable select $chassis $card $port}
		interfaceTable get
		generateCommand interfaceTable
        sgPuts {interfaceTable set}
        sgPuts {interfaceTable clearAllInterfaces}
		
		set paramList [list $::interfaceTypeConnected  $::interfaceTypeRouted $::interfaceTypeGre $::interfaceTypeNpiv]
		foreach param $paramList {
			if {![interfaceTable getFirstInterface $param]} {
				doInterfaceEntry  $chassis $card $port
				while {![interfaceTable getNextInterface $param]} {
					sgPuts ""
				    doInterfaceEntry $chassis $card $port
     
				}
			}
		}
		sgPuts {interfaceTable write}
    }      
    return $retCode 
}



########################################################################
# Procedure: doInterfaceEntry
#
# This command gets  protocol interface table entry parameters.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doInterfaceEntry { chassis card port} \
{
    set retCode 0
    
	set interfaceType [interfaceEntry cget -interfaceType]

	sgPuts ""
    sgPuts "#### Interface entry type - [getEnumString interfaceEntry -interfaceType]"
	
    sgPuts "interfaceEntry clearAllItems addressTypeIpV6"
    sgPuts "interfaceEntry clearAllItems addressTypeIpV4"
	sgPuts "interfaceEntry setDefault"
	sgPuts ""

	if {$interfaceType == $::interfaceTypeConnected } {
        set interfaceParamList [list enable description macAddress eui64Id mtu \
									 enableDhcp enableVlan vlanId vlanPriority vlanTPID enableDhcpV6 ipV6Gateway ]

		if {[port isActiveFeature $chassis $card $port $::portFeatureAtm] } {
			lappend interfaceParamList atmEncapsulation atmMode atmVpi atmVci
		}

		if {[port isActiveFeature $chassis $card $port $::portFeatureVcat] } {
			lappend interfaceParamList vcatCircuit
		}

		if {[port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode] } {
			lappend interfaceParamList enableFlogi enableDcbx enableLldp
		}
		if {[port isActiveFeature $chassis $card $port $::portFeatureFCPhy] } {
			lappend interfaceParamList enableFlogi
		}
		if {[port isValidFeature $chassis $card $port $::portFeaturePtp] } {
			lappend interfaceParamList enablePtp
		}
		set interfaceEntryParamList [list gatewayIpAddress maskWidth ipAddress ]
    
	} elseif {$interfaceType == $::interfaceTypeGre } {
        set interfaceParamList [list enable description greSourceIpAddress greDestIpAddress enableGreChecksum enableGreSequence enableGreKey greInKey greOutKey]
		set interfaceEntryParamList [list maskWidth ipAddress ]
	} elseif {$interfaceType == $::interfaceTypeNpiv } {
        set interfaceParamList [list enable description connectedVia]
		set interfaceEntryParamList {}
 		doNpivProperties $chassis $card $port
   } elseif {$interfaceType == $::interfaceTypeRouted } {
        set interfaceParamList [list enable enableDhcp enableDhcpV6 description connectedVia eui64Id ]
		set interfaceEntryParamList [list maskWidth ipAddress ]

    } else {
        set interfaceParamList {}
		set interfaceEntryParamList {}
	}

	if {$interfaceType != $::interfaceTypeNpiv } {
		if {![interfaceEntry getFirstItem $::addressTypeIpV6]} {
			doInterfaceIpV6
			while {![interfaceEntry getNextItem  $::addressTypeIpV6]} {
				doInterfaceIpV6      
			}
		}

		#IpV4 is not a list now. 
   
		if {![interfaceEntry getFirstItem $::addressTypeIpV4]} {
			partiallyGenerateCommand interfaceIpV4 $interfaceEntryParamList
			sgPuts {interfaceEntry addItem addressTypeIpV4}
			sgPuts ""
		}

		doDhcpV4Properties $chassis $card $port
		doDhcpV6Properties $chassis $card $port
        if {[port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode] } {
    		doFcoeProperties   $chassis $card $port
        }
        if {[port isValidFeature $chassis $card $port $::portFeatureFCPhy] } {
    		doFcProperties     $chassis $card $port
        }
		doPtpProperties    $chassis $card $port
		doDcbxProperties   $chassis $card $port
	} elseif {![port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode] && \
              ![port isActiveFeature $chassis $card $port $::portFeatureFCPhy]} {
		return $retCode
	}    
     
    partiallyGenerateCommand interfaceEntry $interfaceParamList	no
	if { ([getEnumString interfaceEntry -interfaceType] == "interfaceTypeRouted" ) && \
		  ([interfaceEntry cget -connectedVia] == "" ) } {
            sgPuts ""
			sgPuts "#****** WARNING: \"interfaceTable addInterface\" will fail, if connectedVia is empty for interfaceTypeRouted." 
			sgPuts ""
	}
	

	sgPuts "interfaceTable addInterface [getEnumString interfaceEntry -interfaceType]"
	sgPuts ""     
   
    return $retCode 
}



########################################################################
# Procedure: doInterfaceIpV6
#
# This command gets  protocol interface iPv6 parameters.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doInterfaceIpV6 {} \
{
    set retCode 0
      
    generateCommand interfaceIpV6
    sgPuts {interfaceEntry addItem addressTypeIpV6}
    sgPuts ""
       
    return $retCode 
}

########################################################################
# Procedure: doDhcpV4Properties
#
# This command gets  protocol interface for Dhcp V4 properties.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doDhcpV4Properties { chassis card port } \
{
    set retCode 0

	if {[port isValidFeature $chassis $card $port $::portFeatureProtocolDHCP] } {

		sgPuts "dhcpV4Properties removeAllTlvs"
		generateCommand dhcpV4Properties


		if {![dhcpV4Properties getFirstTlv]} {
			generateCommand dhcpV4Tlv
			sgPuts "dhcpV4Properties addTlv"
			while {![dhcpV4Properties getNextTlv]} {
				generateCommand dhcpV4Tlv
				sgPuts "dhcpV4Properties addTlv"
			}
		}
		sgPuts ""      
	}
	       
    return $retCode 
}


########################################################################
# Procedure: doDhcpV6Properties
#
# This command gets  protocol interface for Dhcp V6 properties.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doDhcpV6Properties { chassis card port } \
{
    set retCode 0

	if {[port isValidFeature $chassis $card $port $::portFeatureProtocolDHCPv6] } {

		sgPuts "dhcpV6Properties removeAllTlvs"
		generateCommand dhcpV6Properties


		if {![dhcpV6Properties getFirstTlv]} {
			generateCommand dhcpV6Tlv
			sgPuts "dhcpV6Properties addTlv"
			while {![dhcpV6Properties getNextTlv]} {
				generateCommand dhcpV6Tlv
				sgPuts "dhcpV6Properties addTlv"
			}
		}
		sgPuts ""      
	}
	       
    return $retCode 
}


########################################################################
# Procedure: doPtpProperties
#
# This command gets  protocol interface for PTP properties.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doPtpProperties { chassis card port } \
{
    set retCode 0
	if {[port isValidFeature $chassis $card $port $::portFeaturePtp] } {
		generateCommand ptpProperties
		sgPuts ""      
	}
	       
    return $retCode 
}

proc scriptGen::doFcNameServerQueryProperties { chassis card port } \
{
    set retCode 0

    variable enumsArray

	set enumList [list commandGANxt commandGIDA commandGPNId commandGNNId \
                       commandGIDPn commandGIDPt]
	setEnumValList $enumList enumValList
	set enumsArray(fcNameServerQuery,fcNameServerQueryCommand) $enumValList

	set enumList [list objectPortId objectPortName objectPortType objectNone]
	setEnumValList $enumList enumValList
	set enumsArray(fcNameServerQuery,fcNameServerQueryObject) $enumValList 

    generateCommand fcNameServerQuery
    sgPuts ""
    return $retCode
}


########################################################################
# Procedure: doFcoeProperties
#
# This command gets  protocol interface for FCoE properties.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doFcoeProperties { chassis card port } \
{
    set retCode 0
	if {[port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode]} {
	
		generateCommand fcoeNameServer
		sgPuts ""
		generateCommand fcNameServerQuery
		sgPuts ""
        sgPuts "fcoeProperties removeAllPlogis"
		sgPuts "fcoeProperties removeAllTlvs"
		generateCommand fcoeProperties
		sgPuts ""
		
		if {![fcoeProperties getFirstTlv]} {
			generateCommand fipTlv
			sgPuts "fcoeProperties addTlv"
			while {![fcoeProperties getNextTlv]} {
				generateCommand fipTlv
				sgPuts "fcoeProperties addTlv"
			}
		}
		
		if {![fcoeProperties getFirstPlogi]} {
			generateCommand fcoePlogi
			sgPuts "fcoeProperties addPlogi"
			while {![fcoeProperties getNextPlogi]} {
				generateCommand fcoePlogi
				sgPuts "fcoeProperties addPlogi"
			}
		}

		sgPuts ""      
	}
	       
    return $retCode 
}

########################################################################
# Procedure: doFcProperties
#
# This command gets  protocol interface for Fc properties.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doFcProperties { chassis card port } \
{
    set retCode 0
	if {[port isActiveFeature $chassis $card $port $::portFeatureFCPhy] } {
	
		generateCommand fcNameServer
		sgPuts ""
		generateCommand fcNameServerQuery
		sgPuts ""
		sgPuts "fcProperties removeAllPlogis"
		generateCommand fcProperties
		sgPuts ""
		
		if {![fcProperties getFirstPlogi]} {
			generateCommand fcPlogi
			sgPuts "fcProperties addPlogi"
			while {![fcProperties getNextPlogi]} {
				generateCommand fcPlogi
				sgPuts "fcProperties addPlogi"
			}
		}

		sgPuts ""      
	}
	       
    return $retCode 
}


########################################################################
# Procedure: doNpivProperties
#
# This command gets  protocol interface for Npiv properties.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doNpivProperties { chassis card port } \
{
    set retCode 0

	if {[port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode] ||\
		[port isActiveFeature $chassis $card $port $::portFeatureFCPhy] } {
        
        if {[port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode]} {
            generateCommand fcoeNameServer
            sgPuts ""
            generateCommand fcNameServerQuery
            sgPuts ""            
        }
        if {[port isActiveFeature $chassis $card $port $::portFeatureFCPhy] } {
		    generateCommand fcNameServer
		    sgPuts ""
		    generateCommand fcNameServerQuery
		    sgPuts ""
        }

		generateCommand npivProperties
		sgPuts ""
		
		if {![npivProperties getFirstPlogi]} {
			generateCommand fcoePlogi
			sgPuts "npivProperties addPlogi"
			while {![npivProperties getNextPlogi]} {
				generateCommand fcoePlogi
				sgPuts "npivProperties addPlogi"
			}
		}
		
		sgPuts ""      
	}
	       
    return $retCode 
}

########################################################################
# Procedure: doDcbxProperties
#
# This command gets  protocol interface for DCBX properties.
# Arguments(s):
# Returned Result: Always return OK
########################################################################

proc scriptGen::doDcbxProperties { chassis card port } \
{
    set retCode 0
	if {[port isActiveFeature $chassis $card $port $::portFeatureDataCenterMode] } {
	
		generateCommand lldpPortId
		sgPuts ""
		sgPuts "dcbxProperties removeAllTlvs"		
		generateCommand dcbxProperties
		set DcbxSpecType [dcbxProperties cget -dcbxSubType]
		generateDcbxSubType $DcbxSpecType
		sgPuts ""
		
		set FeatureTlv [dcbxProperties getFirstTlv]
		set FeatureCounter 0
		
		if {$FeatureTlv != "NULL" } {
		
			set FeatureType [$FeatureTlv cget -type]
			set FeatureCounter [expr $FeatureCounter + 1 ]
			generateDcbxFeatureTlv $FeatureType $DcbxSpecType $FeatureCounter
			
			set FeatureTlv [dcbxProperties getNextTlv]
			while {$FeatureTlv != "NULL"} {
			
				set FeatureType [$FeatureTlv cget -type]
				set FeatureCounter [expr $FeatureCounter + 1 ]
				generateDcbxFeatureTlv $FeatureType $DcbxSpecType $FeatureCounter
				
				set FeatureTlv [dcbxProperties getNextTlv]
			}
		}		      
	}
	       
    return $retCode 
}

########################################################################
# Procedure: generateDcbxFeatureTlv
#
# This command generates Dcbx Feature Tlv
# Arguments(s):
#
# FeatureType: FeatureType, DcbxSpecType
#
# Returned Result:
########################################################################      
proc scriptGen::generateDcbxFeatureTlv {FeatureType DcbxSpecType FeatureCounter} \
{  
    set retCode 0
    set PriorityGroupFeature "dcbxPriorityGroupFeature"
    
    if {$DcbxSpecType == $::dcbxSubTypeIeee101} {
		set TlvType "dcbxIeeeFeatureTypePriorityGroup"
		
		switch $FeatureType "
			$::dcbxIeeeFeatureTypePriorityGroup { 
				createTlvDefaultValues $DcbxSpecType $PriorityGroupFeature $FeatureCounter
				generateCommand dcbxPriorityGroupFeature
				set TlvType dcbxIeeeFeatureTypePriorityGroup
			} 
			$::dcbxIeeeFeatureTypePfc {  
				generateCommand dcbxPfcFeature
				set TlvType dcbxIeeeFeatureTypePfc
			} 
			$::dcbxIeeeFeatureTypeFcoe { 
				generateCommand dcbxFcoeFeature
				set TlvType dcbxIeeeFeatureTypeFcoe				
			}
			$::dcbxIeeeFeatureTypeIscsi { 
				generateCommand dcbxIscsiFeature
				set TlvType dcbxIeeeFeatureTypeIscsi				
			}

			default {  
				generateCommand dcbxCustomFeature
				set TlvType $FeatureType
			}				
		"
		
	} else {
		set TlvType "dcbxIntelFeatureTypePriorityGroup"        
		
		switch $FeatureType "
			$::dcbxIntelFeatureTypePriorityGroup {				
				createTlvDefaultValues $DcbxSpecType $PriorityGroupFeature $FeatureCounter
				generateCommand dcbxPriorityGroupFeature
				set TlvType dcbxIntelFeatureTypePriorityGroup
			} 
			$::dcbxIntelFeatureTypePfc {  
				generateCommand dcbxPfcFeature
				set TlvType dcbxIntelFeatureTypePfc
			} 
			$::dcbxIntelFeatureTypeFcoe { 
				generateCommand dcbxFcoeFeature
				set TlvType dcbxIntelFeatureTypeFcoe							
			}	
			$::dcbxIntelFeatureTypeLogicalLink { 
				generateCommand dcbxLogicalLinkFeature
				set TlvType dcbxIntelFeatureTypeLogicalLink				
			}
			default {  
				generateCommand dcbxCustomFeature
				set TlvType $FeatureType
			}				
		"
	}
    
	sgPuts ""
	sgPuts "dcbxProperties addTlv $TlvType "
    return $retCode
}
########################################################################
# Procedure: generateDcbxSubType
#
# This command generates Dcbx Feature Tlv
# Arguments(s):
#
# FeatureType: Feature Type
#
# Returned Result:
########################################################################      
proc scriptGen::generateDcbxSubType {DcbxSpecType} \
{  
    set retCode 0
    set SubType "dcbxSubTypeIeee101"
    
    if {$DcbxSpecType == $::dcbxSubTypeIntel10} {
		set SubType "dcbxSubTypeIntel10"
	}
    
	sgPuts "dcbxProperties setDcbxSubType $SubType"
    return $retCode
}

########################################################################
# Procedure: createTlvDefaultValues
#
# This command generates Dcbx Feature Tlv
# Arguments(s):
#
# FeatureType: Feature Type
#
# Returned Result:
########################################################################
proc scriptGen::createTlvDefaultValues {DcbxSpecType cmd FeatureCounter} \
{ 
	set retCode 0
	
	# The below if condition is creating the default value array
	# because the available parameter list will change based on the message type
    set defaultValueArray [format "%sDefaultValueArray" $cmd]
	variable $defaultValueArray		
	catch { unset ::scriptGen::$defaultValueArray}
	dcbxProperties setDcbxSubType $DcbxSpecType
	getParmValueArray $cmd ::scriptGen::$defaultValueArray
	
	# Get the actual parameter values
	dcbxProperties getTlv $FeatureCounter

	return $retCode
}
########################################################################
# Procedure: doAtmFilter
#
# This command gets  atm Filter parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################

proc scriptGen::doAtmFilter {chassis card port vpi vci} \
{
    set retCode 0
    
	if {![atmFilter get $chassis $card $port $vpi $vci]} {
		generateCommand atmFilter
		sgPuts "atmFilter set \$chassis \$card \$port $vpi $vci"
		sgPuts ""
	} else {
		set retCode 1
	}
       
    return $retCode 
}

########################################################################
# Procedure: generateCustomOrderedSet
#
# This command gets customOrderedSet parameters.
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# port    : port Id
# Returned Result:
########################################################################
proc scriptGen::generateCustomOrderedSet {} \
{
    set retCode 0
    
	if {[linkFaultSignaling cget -orderedSetTypeA] == $::linkFaultCustom || \
		[linkFaultSignaling cget -orderedSetTypeB] == $::linkFaultCustom} {
		sgPuts ""			
		sgPuts "customOrderedSet setDefault"
	}

	if { [linkFaultSignaling cget -orderedSetTypeA] == $::linkFaultCustom } {
		if {![customOrderedSet get linkFaultOrderedSetTypeA]} {
			generateCommand customOrderedSet no
			sgPuts "customOrderedSet set linkFaultOrderedSetTypeA "
			sgPuts ""
		} else {
			logMsg "Error in getting customOrderedSet"
			set retCode 1 
		}
	}	
	
	if { [linkFaultSignaling cget -orderedSetTypeB] == $::linkFaultCustom} {
		if {![customOrderedSet get linkFaultOrderedSetTypeB]} {
			sgPuts ""
			generateCommand customOrderedSet no
			sgPuts "customOrderedSet set linkFaultOrderedSetTypeB "
			sgPuts ""
		} else {
			logMsg "Error in getting customOrderedSet "
			set retCode 1 
		}
	} 
       
    return $retCode 
}


proc scriptGen::generateAtmConfig { chassis card port } \
{
    set retCode 0


	if {[port isActiveFeature $chassis $card $port $::portFeatureAtm]} {
		if {![getCommand atmPort $chassis $card $port]} {
			sgPuts {atmPort set $chassis $card $port}
		} else {
			logMsg "Error in getting atmPort"
			set retCode 1 
		} 
		sgPuts ""
		if {![atmReassembly getFirstPair $chassis $card $port]} {
            generateCommand atmReassembly
			sgPuts "atmReassembly add \$chassis \$card \$port [atmReassembly cget -vpi] [atmReassembly cget -vci]"
			sgPuts ""
            if {[port isValidFeature $chassis $card $port $::portFeatureAtmPatternMatcher]} {
			    doAtmFilter	$chassis $card $port [atmReassembly cget -vpi] [atmReassembly cget -vci]
            }
			while {![atmReassembly getNextPair $chassis $card $port]} {
                generateCommand atmReassembly
				sgPuts "atmReassembly add \$chassis \$card \$port [atmReassembly cget -vpi] [atmReassembly cget -vci]"
				sgPuts ""
                if {[port isValidFeature $chassis $card $port $::portFeatureAtmPatternMatcher]} {
				    doAtmFilter	$chassis $card $port [atmReassembly cget -vpi] [atmReassembly cget -vci]
                }

		  }
		}
		sgPuts ""
		if {![atmStat getFirstTxPair $chassis $card $port]} {
			sgPuts "atmStat addTx \$chassis \$card \$port [atmStat cget -vpi] [atmStat cget -vci]"
			while {![atmStat getNextTxPair $chassis $card $port]} {
				sgPuts "atmStat addTx \$chassis \$card \$port [atmStat cget -vpi] [atmStat cget -vci]"
		  }
		}
		
		if {![atmStat getFirstRxPair $chassis $card $port]} {
			sgPuts "atmStat addRx \$chassis \$card \$port [atmStat cget -vpi] [atmStat cget -vci]"
			while {![atmStat getNextRxPair $chassis $card $port]} {
				sgPuts "atmStat addRx \$chassis \$card \$port [atmStat cget -vpi] [atmStat cget -vci]"
		  }
		}
		
		sgPuts ""
		generateAtmOam	$chassis $card $port
		sgPuts ""
		 
	}
    return $retCode 
}


proc scriptGen::generateAtmOam { chassis card port } \
{
    set retCode 0

	if {![atmOam select $chassis $card $port]} {
		sgPuts {atmOam select $chassis $card $port}
		sgPuts {atmOam removeAll}
		if {![atmOam getFirstPair]} {
			generateAtmOamCell
			while {![atmOam getNextPair]} {
				generateAtmOamCell
		  }
		}		
	}

    return $retCode 
}

proc scriptGen::generateAtmOamCell {} \
{
	generateCommand atmOam

	set functionType [atmOam cget -functionType]

    switch $functionType "
        $::atmOamAis { 
            generateCommand  atmOamAis 
        } 
        $::atmOamRdi {  
            generateCommand atmOamRdi 
        } 
        $::atmOamFaultMgmtCC { 
            generateCommand atmOamFaultManagementCC 
        }
        $::atmOamFaultMgmtLB {  
            generateCommand atmOamFaultManagementLB 
        } 
        $::atmOamActDeactCC { 
            generateCommand atmOamActDeact 
        }
	"
	sgPuts "atmOam add  [atmOam cget -vpi] [atmOam cget -vci]"
	sgPuts ""

}









