#############################################################################################
#   Version 8.01
#   
#   File: ixTclHal.tcl
#
#  Package initialization file
#
#  This file is executed when you use "package require IxTclHal" to
#  load the IxTclHal library package.  It sets up the IXTCLHAL_LIBRARY
#  environment variable to point to the directory where the package
#  resides.
#
#  If the package is being loaded from a multi-user template script, then continue
#  otherwise return rightaway
#
#   Copyright ©  IXIA.
#	All Rights Reserved.
#
#############################################################################################

## basically this is a keeping room for all the method pointer stuff + ixTclHal package req procs
namespace eval ixTclHal {
    variable noArgList
    variable pointerList
    variable protocolList
    variable commandList

    variable cleanUpDone    0
	variable nonDeprecatedCommands	[list]

    proc update {MyList} \
    {
        upvar $MyList myList

        variable noArgList
        variable pointerList
        variable protocolList
        variable commandList
        
        set myList [join [list $noArgList $pointerList $protocolList $commandList]]
    }

    proc createCommand {object command args} \
    {
        # make sure the command doesn't already exist so that we don't step on it!!
        if {[llength [info commands ::$command]] == 0} {
            validateArgs $args
            eval [format "proc ::%s {args}                                 \
                          {                                                \
                              if {\[%s %s [join $args]\] == \"\"} {        \
	                              puts \"Error instantiating %s object!\"; \
	                              return 1;                                \
                              };                                           \
                              return \[eval %s \$args];                    \
                          }"                                               \
                 $command $object $command $object $command] 
        }       
    }

    proc createCommandPtr {object command args} \
    {
        # make sure the command doesn't already exist so that we don't step on it!!
        if {[llength [info commands ::$command]] == 0} {
            set ptrCmd [format "$command%s" Ptr]
            validateArgs $args
            eval [format "proc ::%s {args}                                   \
                          {                                                \
                              set ::%s \[%s %s [join $args]\];             \
                              if {\$::%s == \"\"} {                        \
	                              puts \"Error instantiating %s object!\"; \
	                              return 1;                                \
                              };                                           \
                              return \[eval %s \$args];                    \
                          }"                                               \
                 $command $ptrCmd $object $command $ptrCmd $object $command $command]
        }
    }

    # this one is scary; it adds a line of code to the created proc right before the return
    # so that we can setup pointers in an ixTclHal object
    proc updateCommand {command args} \
    {
        set commandProc [string trim [info body $command]]
        set lastcmd     [string range $commandProc [string last return $commandProc] end]

        eval [format "proc ::%s {args}                                   \
                      {                                                \ 
                          %s                                           \
                      }"                                               \
             $command [concat [string range $commandProc 0 [expr [string last return $commandProc]-1]] [format "%s;" [join $args]] $lastcmd] ]
    }

    proc validateArgs {args} \
    {
        set args [join $args]
        if {$args != ""} {
            foreach cmdPtr $args {
                regsub -all {[$]} $cmdPtr "" cmdPtr
                if {![info exists $cmdPtr]} {
                    regsub -all {[;:"$']} $cmdPtr "" cmd
                    regsub "Ptr$" $cmd "" cmd
                    catch {$cmd}
                }
            }
        }
    }

    proc cleanUpDone   {} {variable cleanUpDone; set cleanUpDone 1}
    proc isCleanUpDone {} {variable cleanUpDone; return $cleanUpDone}
}


set currDir [file dirname [info script]]

source [file join $currDir ixTclSetup.tcl]
source [file join $currDir ixTclHalSetup.tcl]

package provide IxTclHal 8.01


#
# Source the user configuration file located in the following directory.
#
# IXIA_DIR/TclScripts/lib/ixTcl1.0
#
# IXIA_DIR is the name of the directory where IXIA software is installed.
# The directory UserFiles should be created while IXIA software is being
# installed.
#
# The name of the file has to be userProfile.tcl.
#
catch {
    source [file join $currDir userProfile.tcl]
}

if {[catch {source [file join $currDir ixScriptmatePackageControl.tcl]}] } {
    catch {package require Scriptmate}
}

# Recent IxNetwork Tcl pacakges allow the user to specify a version.  Try that first:
if {[info exists ::IxTclHal_LoadIxTclProtocolVersion]} {
    # If the user requests "none", simply do not load the package at all
    if {$::IxTclHal_LoadIxTclProtocolVersion != "none"} {
        # Attempt to require the specified version of IxTclProtocol package
        if {[catch {package require IxTclProtocol $::IxTclHal_LoadIxTclProtocolVersion} IxTclProtocol_result} {
            # Display a helpful message on failure
            set savInfo $::errorInfo
            if {[catch {package versions IxTclProtocol} versionList]} {
                set versionList [list]
            }
            set errMsg "Couldn't load IxTclProtocol version \"$::IxTclHal_LoadIxTclProtocolVersion\" ('set ::IxTclHal_LoadIxTclProtocolVersion \"none\"', or any of: $versionList, or unset it)"
            error $errMsg $savInfo
        }
    }
} else {
    # If the user did not specify a version, try to load the first IxTclProtocol we can find:
    if {[catch {package require IxTclProtocol}] } {
        # Finally, try the legacy location:
        catch {source [file join $currDir ixTclProtocolPackageControl.tcl] }
        # If nothing is found, that's ok, IxNetwork is just not installed
    }
}

