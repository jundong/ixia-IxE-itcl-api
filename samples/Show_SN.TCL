if { $tcl_platform(platform) == "windows" } {
    package require registry
    
    proc GetEnvTcl { product } {       
        set productKey     "HKEY_LOCAL_MACHINE\\SOFTWARE\\Ixia Communications\\$product"
        if { [ catch {
                set versionKey     [ registry keys $productKey ]
        } err ] } {
                return ""
        }        
        
        set latestKey      [ lindex $versionKey end ]
        set mutliVKeyIndex [ lsearch $versionKey "Multiversion" ]
        if { $mutliVKeyIndex > 0 } {
           set latestKey   [ lindex $versionKey [ expr $mutliVKeyIndex - 2 ] ]
        }
        set installInfo    [ append productKey \\ $latestKey \\ InstallInfo ]            
        return             "[ registry get $installInfo  HOMEDIR ]/TclScripts/bin/ixiawish.tcl"   
    }

    # IxOS is optional 
    set ixPath [ GetEnvTcl IxOS ]
    if { [file exists $ixPath] == 1 } {
        source [ GetEnvTcl IxOS ]
    }
}

package require IxTclHal

#set hostname 172.16.174.137
set hostname 10.210.100.12
set userName IxiaTclUser-Inventory
set retCode $::TCL_OK

ixLogin $userName
ixPuts "\nUser logged in as: $userName"
set recCode [ixConnectToChassis $hostname]
if {$retCode != $::TCL_OK} {
    return $retCode
}

chassis get $hostname
set chassis	  [chassis cget -id]

puts "Chassis Info: "
puts "=============================="
puts "Chassis IP: [chassis cget -name]"
puts "Chassis Type: [chassis cget -typeName]" 
puts "Chassis Serials Number: [chassis cget -serialNumber]" 
puts "Chassi Version: [chassis cget -ixServerVersion]"
puts "=============================="

set SN ""
set TYPE ""
set maxCards [chassis cget -maxCardCount]
for {set u 1} {$u<=$maxCards} {incr u} {
    card get $chassis $u
    set OUTPUT [card cget -serialNumber]
    set OUTPUT1 [lrange $OUTPUT 3 3]
    set OUTPUT2 [card cget -typeName]
    set OUTPUT3 [card cget -portCount]
    append list1 $SN $OUTPUT1 " "
    append list2 $TYPE $OUTPUT2 ">"
    append list3 $SN $OUTPUT3 " "
}
regsub -all { } $list2 "" list2
regsub -all > $list2 " " list2

set u 0
set v 1
set bay ""
for {set x 0} {$u<$maxCards} {incr x} {
    set KEY1 [lindex $list1 $u]
    set KEY2 [lindex $list1 $v]
    if {$KEY1 == $KEY2} {
    set list1 [lreplace $list1 $v $v]
    set list2 [lreplace $list2 $v $v]
    set list3 [lreplace $list3 $v $v]
    set maxCards [llength $list1]
    append bay " " $x
    continue
    }
    incr u
    incr v
}

set bay1 ""
foreach e $bay {
append bay1 [expr $e+2] " "
}

set u 0
set v 0
puts " "
puts "Your Chassis Type is: [chassis cget -typeName]"
puts " "
puts "You have $maxCards cards inserted: "
puts "=============================="
for {set x 0} {$x<$maxCards} {incr x} {
    if {[incr u]==[lindex $bay1 $v]} {
        incr v
        incr x -1
        continue
    }
    puts "Card inserted in slot: $u" 
    puts "Type: [lindex $list2 $x]"
    puts "SN: [lindex $list1 $x]"
    puts "Ports: [lindex $list3 $x]"
    puts "=============================="
}

unset list1
unset list2
unset list3
unset SN
unset TYPE
unset bay
unset bay1
unset hostname
unset userName
unset retCode
