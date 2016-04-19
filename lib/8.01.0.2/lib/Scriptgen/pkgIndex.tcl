##################################################################################
#   Version 8.01
#   
#   File: pkgIndex.tcl
#
#   Copyright ©  IXIA
#   All Rights Reserved.
#
#	Revision Log:
#	01-24-2004	Hasmik
#
##################################################################################

if {![package vsatisfies [package provide Tcl] 8.3]} {return}

# if this package is already loaded, then don't load it again
if {[lsearch [package names] Scriptgen] != -1} {
    return
}

package ifneeded Scriptgen 8.01 [list source [file join $dir scriptGen.tcl]]


