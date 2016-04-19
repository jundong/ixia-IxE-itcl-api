##################################################################################
#   Version 8.01
#   
#   File: random.tcl
#
#   Copyright ©  IXIA
#   All Rights Reserved.
#
#	Revision Log:
#	02-03-2000	HSH
#
# Description: This file contains common procs used for generating random
#              numbers
#
##################################################################################


########################################################################
# Set the default randomSeed
# Now use a random number to be the randomSeed
########################################################################

global randomSeed

set randomSeed [expr int( [expr rand()] * 100 ) ]


########################################################################
# Procedure: RandomRange
# Should let range equal to "the total number of data" ( do not subtract 1 )!!
#
# range -  the range of random numbers 
#
########################################################################
proc RandomRange { range } \
{
 	
    return [ expr int( [ Random ] * $range ) ]
}

########################################################################
# Procedure: Random
# This gives a random decimal num.
# 
########################################################################

proc Random {} \
{
 	global randomSeed
 	set randomSeed [ expr ( $randomSeed * 9301 + 49297 ) %233280 ]
	return [ expr $randomSeed / double( 233280 ) ]
}

########################################################################
# Procedure: RandomInit
# 
# 
########################################################################
proc RandomInit {} \
{
    global randomSeed
    set randomSeed  [clock seconds]
}


########################################################################
# Procedure: RandomFromTo
# This gives a random num within the given range of numbers.
# 
########################################################################
proc RandomFromTo {from to} \
{
    global randomSeed

    set randomSeed [expr ($randomSeed*9301 + 49297) % 233280]
    set random     [expr $randomSeed/double(233280)]

    return [expr int($random * ($to - $from + 1)) + $from]
}

