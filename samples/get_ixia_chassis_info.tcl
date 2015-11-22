#--------------------------------------------------------------------------
# Title:  get_ixia_chassis_info.tcl
#
# Uses list of chassis IP addresses and writes the following to output file.
#
# Chassis IP address
# Chassis serial number (name)
# Chassis type
# IxServer version
# List of cards
#--------------------------------------------------------------------------

# List of chassis IP addresses to collect information from

set chassisList [list 172.16.174.137]

# Log File Name
set IxiaChassisFile "C:/Tmp/IxiaChassisScanOutput.txt"

set username IxiaScan


#--------------------------------------------------------------------------

global ixia_wish
global installed
set ixia_wish "TclScripts/bin/IxiaWish.tcl"

proc isWin64b {} {
	file exists "C:/Program Files (x86)" 
}

proc getInstalledIxOS { } {
	global installed
	set path ""
	set installed {}
	
	if {[isWin64b]} {
		set path "C:/Program Files (x86)" 
	} else {
		set path "C:/Program Files" 
	}
	
    foreach item  [glob -directory "$path\\Ixia\\IxOS" *] {
		if { [isCompleteInstall $item] } {
			lappend installed "$item"
		}
    }
	return $installed
 }
 
 proc isCompleteInstall { path } {
	global ixia_wish
	file exists "$path/$ixia_wish"
 }
 
 proc loadWish_latestVersion {} {
	global ixia_wish
	global installed
	set versions [ getInstalledIxOS ] 
	if { [llength versions] > 0} {
	
		set latest [join [lrange $versions end end] " "]
		puts "Sourcing the latest Ixia Wish: $latest"
		source "$latest/$ixia_wish"	
		return 1
	} else {
		puts "No IxOS installations were found"
		return 0
	}
	
 }


loadWish_latestVersion
package req IxTclHal

# Open output File
if {[catch {open $IxiaChassisFile w} agtFd_]} {
    puts "Problem opening $IxiaChassisFile: $agtFd_"
    set agtFd_ 0
}

foreach chassisIpAddress $chassisList {

	puts $agtFd_  "\nChassis IP: $chassisIpAddress"

	# connect to TclServer to get the Chassis Serial Number from the Env variables

        if {[ixConnectToTclServer $chassisIpAddress] != 0} {
                puts $agtFd_ "Unable to connect to Tcl Server $chassisIpAddress\n\n\n"
                continue
        }

        set chassisSerialNum [clientSend $ixTclSvrHandle {puts $env(chassisSN)}]

	# connect to Chassis

        if {[ixConnectToChassis $chassisIpAddress] != 0} {
                puts $agtFd_ "Unable to connect to Chassis $chassisIpAddress\n\n"
                continue
        }

	ixLogin $username

	set chassisId [chassis cget -id]
	set chassisType [chassis cget -typeName]
	set chassisSlots [chassis cget -maxCardCount]
	set chassisIxosVersion [chassis cget -ixServerVersion]

	puts $agtFd_  "\nSerial number: $chassisSerialNum"
	puts $agtFd_  "ID: $chassisId, Type: $chassisType, Slots: $chassisSlots, IxServer: $chassisIxosVersion"

	# get installed cards

	puts $agtFd_  "\n--Cards--"

	for {set i 1} {$i <= $chassisSlots} {incr i} { 
		if {[card get 1 $i] == 0} {
			# convert any , to .
			puts $agtFd_  "$i, [card cget -typeName], [card cget -portCount], [card cget -serialNumber]"
		}
	}

	puts $agtFd_ "\n\n"
}

puts "\nDone."

# Close output file
if { $agtFd_ != 0 } {
    close $agtFd_
}
