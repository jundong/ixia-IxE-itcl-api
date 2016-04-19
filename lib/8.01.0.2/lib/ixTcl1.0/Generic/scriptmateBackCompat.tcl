#############################################################################################
#   Version 8.01
#   
#   File: scriptmateBackCompat.tcl
#
#   This file is used to create backwards compatibility for sample scripts created prior to
#   IxOS 3.70.  Post of this version, a package require Scriptmate is needed.  This will handle
#   attempting to define the commands that used to be defined by IxTclHal and now are defined 
#   Scriptmate
#  
#   Copyright ©  IXIA
#   All Rights Reserved.
#
#############################################################################################

namespace eval scriptmateBackwardsCompatibility {}


proc scriptmateBackwardsCompatibility::createAllCommands { } {

    foreach cmd {addr back2back bcast cableModem congest dataVerify dtm errframe floss flow gapcheck imix \
            ipmulticast latency tunnel mesh qost randomFS tput tputerror tputjitter tputnat tputl2l3 tputlat \
            tputmfs tputvlan ttl wip results internalModem user bgpSuite dslats ospfSuite rsvpSuite ldpSuite \
            l2VpnSuite l3VpnSuite} {

        proc $cmd { args } {
            if {[catch {package require Scriptmate}]} {
                return "Command is not supported by IxTclHal, it is part of Scriptmate"
            } else {
                return [eval $cmd $args]
            }
        }
    }
}


