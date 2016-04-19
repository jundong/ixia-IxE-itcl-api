#############################################################################################
#   Version 8.01
#   
#   File: ixInit.tcl
#
#   NOTE: This file should be sourced from the ixTclServices directory structure
#
#   Copyright ©  IXIA
#   All Rights Reserved.
#
#############################################################################################

# Set the initial pattern to nothing
set newPatterns {}

# Get the current directory
set dir [pwd]

# Get all items in the directory
foreach fileItem1 [glob -nocomplain *] {

    # We only are concerned with directories
    if {[file isdirectory $fileItem1]} {
        lappend newPatterns [file join $fileItem1 "*.tcl"]

        foreach fileItem2 [glob -nocomplain $fileItem1/*] {
            if {[file isdirectory $fileItem2]} {
                lappend newPatterns [file join $fileItem2 "*.tcl"]
            } 
        }
    } 
}

eval auto_mkindex . $newPatterns


