##################################################################################
#   Version 8.01
#   
#   File: logCollector.tcl
#
#   Copyright ©  IXIA
#   All Rights Reserved.
#
#	Revision Log:
#	05-29-2007	DS
#
# Description: This file contains procs used to collect & send logs to support
#
##################################################################################


########################################################################
# Procedure: ixCollectAndSendLogs
#
# This command wraps the exe used to collect logs, zip them & send them to support
#	NOTE:  This command does NOT require a package req IxTclHal to run
#
# Arguments(s):
#	argList - options include:
#		-chassis <hostname><.card><.port>
#		-userEmail <my email, used to cc on support email>
#		-supportEmail <my favourite support person's email>
#		-stepsToReproduce <text describing how to reproduce the issue>
#		-zipFileName <myZipFile.zip>
#
########################################################################
proc ixCollectAndSendLogs {args} \
{
    set level	  [expr [info level]]
    set procName  "[lindex [info level $level] 0]"

	set optList {-chassis -userEmail -supportEmail -stepsToReproduce -zipFileName}

	if {[llength $args] == 0} {
		puts "Usage: $procName "
		foreach op $optList {
			puts "       $op  <[string trimleft $op "-"]>"
		}
		flush stdout
		return 1
	}

	# this has to change, but leaving it here for the moment...
	set exeString [list exec "../diagnostic/logcollectorclient.exe"]

	foreach {option parameter} $args {
		switch -glob -- $option {
			-chassis {
				set parameter [split $parameter .]
				set result [scan $parameter "%s %d %d" chassis card port]
				switch -- $result {
					1 {
						set exeString [concat $exeString "--chassis $chassis"]
					}
					2 {
						set exeString [concat $exeString "--chassis $chassis,$card"]
					}
					3 {
						set exeString [concat $exeString "--chassis $chassis,$card,$port"]
					}
					default {
						puts "$procName:  No chassis/hostname specified"
						return 1
					}
				}								
			}
			-userEmail {
				# just do some quickie checking looking for @ & .   The exe should do the rest.
				if {[llength $parameter] > 0} {
					if {[regexp -all {[@.]} $parameter] >= 2} {
						lappend exeString "--useremail=$parameter"
					} else {
						puts "$procName:  Invalid userEmail: $parameter"
						return 1
					}
				} else {
					puts "$procName:  No userEmail specified"
					return 1
				}
			}
			-supportEmail {
				# just do some quickie checking looking for @ & .   The exe should do the rest.
				if {[llength $parameter] > 0} {
					if {[regexp -all {[@.]} $parameter] >= 2} {
						lappend exeString "--supportemail=$parameter"
					} else {
						puts "$procName:  Invalid supportEmail: $parameter"
						return 1
					}
				} else {
					puts "$procName:  No supportEmail specified"
					return 1
				}
			}
			-stepsToReproduce {
				if {[llength $parameter] > 0} {
					set exeString [concat $exeString "--usertext $parameter"]
				} else {
					puts "Warning:  No steps to reproduce included with collection of log files"
				}
			}
			-zipFileName {
				if {[llength $parameter] > 0} {
					set exeString [concat $exeString "--zip $parameter"]
				}
			}
			default {
				puts "Usage: $procName "
				foreach op $optList {
					puts "       -$op  <value>"
				}
				flush stdout
				return
			}
		}
		catch {unset option}
		catch {unset parameter}
	}

	puts $exeString
	
	if [catch {eval $exeString} retCode] {
		puts "$procName: $exeString failed: $retCode"
		return 1
	}

	return 0
}
