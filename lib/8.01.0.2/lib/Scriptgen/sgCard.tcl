#############################################################################################
#   Version 8.01
#   
#   File: sgCard.tcl
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
# Procedure: getCardScript
#
# This command generates card commands
# Arguments(s):
# chassis : chassis Id
# card    : card Id
# Returned Result:
########################################################################

proc scriptGen::getCardScript { chassis card howManyPorts } \
{
    set retCode 0

# "card get" has been called in ixSgMain before calling this proc so I don't call it again
    set cardParamList {}  
    
    # no feature enum for this
    if {[card cget -type] == $::card10100RMii} {
        set cardParamList [list clockTxRisingEdge clockRxRisingEdge]
    }
     
	if {[card isValidFeature $chassis $card $::portFeatureBertUnframed] || [card isValidFeature $chassis $card $::cardFeatureClockMode]} {
		lappend cardParamList clockSelect
	} 
	
	if {[card isValidFeature $chassis $card $::cardFeatureFrequencyOffset]} {
		lappend cardParamList txFrequencyDeviation
	}

    
    # This code is used from port level as well as card level
    # script generation, card level generation will always
    # have more than one port
    if { $howManyPorts > 1 } {
        if {[card isValidFeature $chassis $card $::cardFeatureResourceGroup] } {
            set cfgRGLists [card getConfiguredResourceGroupList $chassis $card]
	      sgPuts "set curCfgRGLists \[card getConfiguredResourceGroupList \$chassis \$card\]"
	      sgPuts "set isSame \[string compare \$curCfgRGLists {$cfgRGLists}\]"
	      sgPuts -noFormat "if \{ \$isSame != 0 \} \{ "
	      sgPuts -noFormat "\tcard setFactoryDefaults \$chassis \$card"
	      sgPuts -noFormat "\}"
            if {$cfgRGLists != ""} {
                sgPuts "card set \$chassis \$card"
		    sgPuts "card write \$chassis \$card"
                sgPuts "card setConfiguredResourceGroupList \$chassis \$card {$cfgRGLists}"
            }
        } elseif {[card isValidFeature $chassis $card $::cardFeature1GEAggregate] || \
		    [card isValidFeature $chassis $card $::cardFeature10GEAggregate]} {
		    set opModeArray($::cardOperationModeNormal)			{$::cardOperationModeNormal}
		    set opModeArray($::cardOperationMode1geAggregated)	{$::cardOperationMode1geAggregated}
		    set opModeArray($::cardOperationMode10geAggregated)	{$::cardOperationMode10geAggregated}

		    set operationMode [card cget -operationMode]
                sgPuts [format {card writeOperationMode  %s $chassis $card } $opModeArray($operationMode)]
        }
    } 
    
    

    if {[llength $cardParamList] != 0} {
        partiallyGenerateCommand card $cardParamList
 		if {$scriptGen::enableErrorChecking} {
			sgPuts -noFormat "set retCode \[card set \$chassis \$card\]"
			sgPuts -noFormat "switch \$retCode \\"
			sgPuts -noFormat "\t\$::TCL_OK \{ \\"
			sgPuts -noFormat "\t\tif \{ \[card write \$chassis \$card\] != \$::TCL_OK \} \{ \\"
			sgPuts -noFormat "\t\t\terrorMsg \"Error calling card write \$chassis \$card\"\; \\"
			sgPuts -noFormat "\t\t\tset retCode \$::TCL_ERROR\; \\"
			sgPuts -noFormat "\t\t\} \\"
			sgPuts -noFormat "\t\} \\"
			sgPuts -noFormat "\t\$::ixTcl_notAvailable \{ \\"
			sgPuts -noFormat "\t\tlogMsg \"One or more of the ports on this card is unavailable, please check ownership. Card settings not applied.\"\; \\"
			sgPuts -noFormat "\t\} \\"
			sgPuts -noFormat "\tdefault \{ \\"
			sgPuts -noFormat "\t\terrorMsg \"Error calling card set \$chassis \$card\"\; \\"
			sgPuts -noFormat "\t\}"
		} else {
			sgPuts {card set $chassis $card}
			sgPuts {card write $chassis $card}
		}
    }

    return $retCode
}

