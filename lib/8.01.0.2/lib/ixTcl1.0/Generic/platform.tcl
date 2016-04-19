##################################################################################
#   Version 8.01
#   
#   File: platform.tcl
#
#   Copyright ©  IXIA
#   All Rights Reserved.
#
#       Revision Log:
#       09-29-2000       DS
#
# Description: This file contains platform-independent stuff
#
##################################################################################


############################################################
# Procedure  : isUNIX
# 
# Description: This proc tells if current OS is Windows.
# Output     : 1 if it is UNIX, 0 otherwise.
#
############################################################
proc isUNIX {} \
{
    global tcl_platform

    set retCode 0

    if {$tcl_platform(platform) == "unix"} {
        set retCode 1
    }

    return $retCode
}


############################################################
# Procedure  : isWindows
# 
# Description: This proc tells if current OS is Windows.
# Output     : 1 if it is UNIX, 0 otherwise.
#
############################################################

proc isWindows {} \
{
    global tcl_platform

    set retCode 0

    if {$tcl_platform(platform) == "windows"} {
        set retCode 1
    }

    return $retCode
}


