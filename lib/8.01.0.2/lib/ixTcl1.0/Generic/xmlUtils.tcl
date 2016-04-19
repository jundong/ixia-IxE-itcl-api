##################################################################################
#   Version 8.01
#   
#   File: xmlUtils.tcl
#
#   Copyright ©  IXIA
#   All Rights Reserved.
#
#	Revision Log:
#	3-7-2007	DS	Genesis
#
# Description: Simple XML parser.  
#
# credit to Keith Vetter, March 2004
# http://wiki.tcl.tk/11020
#
# Modified to work with both tcl8.3 & tcl8.4.
#
##################################################################################

 namespace eval ::ixXML { variable XML "" loc 0}

 proc ::ixXML::Init {xmlData} {
    variable XML
    variable loc

    set XML [string trim $xmlData];
    regsub -all {<!--.*?-->} $XML {} XML        ;# Remove all comments
    set loc 0
 }

 # Returns {XML|TXT|EOF|PI value attributes START|END|EMPTY}
 proc ::ixXML::NextToken {{peek 0}} {
    variable XML
    variable loc

    set n [regexp -start $loc -indices {(.*?)\s*?<(/?)(.*?)(/?)>} \
               $XML all txt stok tok etok]
    if {! $n} {return [list EOF]}
    foreach {all0 all1} $all {txt0 txt1} $txt \
        {stok0 stok1} $stok {tok0 tok1} $tok {etok0 etok1} $etok break

    if {$txt1 >= $txt0} {                       ;# Got text
        set txt [string range $XML $txt0 $txt1]
        if {! $peek} {set loc [expr {$txt1 + 1}]}
        return [list TXT $txt]
    }

    set token [string range $XML $tok0 $tok1]   ;# Got something in brackets
    if {! $peek} {set loc [expr {$all1 + 1}]}
    if {[regexp {^!\[CDATA\[(.*)\]\]} $token => txt]} { ;# Is it CDATA stuff?
        return [list TXT $txt]
    }

    # Check for Processing Instruction <?...?>
    set type XML
    if {[regexp {^\?(.*)\?$} $token => token]} {
        set type PI
    }
    set attr ""
    regexp {^(.*?)\s+(.*?)$} $token => token attr

    set etype START                             ;# Entity type
    if {$etok0 <= $etok1} {
        if {$stok0 <= $stok1} { set token "/$token"} ;# Bad XML
        set etype EMPTY
    } elseif {$stok0 <= $stok1} {
        set etype END
    }
    return [list $type $token $attr $etype]
 }
 # ::ixXML::IsWellFormed
 #  checks if the XML is well-formed )http://www.w3.org/TR/1998/REC-xml-19980210)
 #
 # Returns "" if well-formed, error message otherwise
 # missing:
 #  characters: doesn't check valid extended characters
 #  attributes: doesn't check anything: quotes, equals, unique, etc.
 #  text stuff: references, entities, parameters, etc.
 #  doctype internal stuff
 #
 proc ::ixXML::IsWellFormed {} {
    set result [::ixXML::_IsWellFormed]
    set ::ixXML::loc 0
    return $result
 }
 ;proc ::ixXML::_IsWellFormed {} {
    array set emsg {
        XMLDECLFIRST "The XML declaration must come first"
        MULTIDOCTYPE "Only one DOCTYPE is allowed"
        INVALID "Invalid document structure"
        MISMATCH "Ending tag '$val' doesn't match starting tag"
        BADELEMENT "Bad element name '$val'"
        EOD "Only processing instructions allowed at end of document"
        BADNAME "Bad name '$val'"
        BADPI "No processing instruction starts with 'xml'"
    }

    # [1] document ::= prolog element Misc*
    # [22] prolog ::= XMLDecl? Misc* (doctypedecl Misc*)?
    # [27] Misc ::= Comment | PI | S
    # [28] doctypedecl ::= <!DOCTYPE...>
    # [16] PI ::= <? Name ...?>
    set seen 0                                  ;# 1 xml, 2 pi, 4 doctype
    while {1} {
        foreach {type val attr etype} [::ixXML::NextToken] break
        if {[string equal $type "PI"]} {
            if {! [regexp {^[a-zA-Z_:][a-zA-Z0-9.-_:\xB7]+$} $val]} {
                return [subst $emsg(BADNAME)]
            }
            if {[string equal $val "xml"]} {                ;# XMLDecl
                if {$seen != 0} { return $emsg(XMLDECLFIRST) }
                # TODO: check version number exist and only encoding and
                # standalone attributes are allowed
                incr seen                       ;# Mark as seen XMLDecl
                continue
            }
            if {[string equal -nocase "xml" $val]} {return $emsg(BADPI)}
            set seen [expr {$seen | 2}]         ;# Mark as seen PI
            continue
        } elseif {[string equal $type "XML"] && [string equal $val "!DOCTYPE"]} { ;# Doctype
            if {$seen & 4} { return $emsg(MULTIDOCTYPE) }
            set seen [expr {$seen | 4}]
            continue
        }
        break
    }

    # [39] element ::= EmptyElemTag | STag content ETag
    # [40] STag ::= < Name (S Attribute)* S? >
    # [42] ETag ::= </ Name S? >
    # [43] content ::= CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
    # [44] EmptyElemTag ::= < Name (S Attribute)* S? />
    #

    set stack {}
    set first 1
    while {1} {
        if {! $first} {                         ;# Skip first time in
            foreach {type val attr etype} [::ixXML::NextToken] break
        } else {
            if {![string equal $type "XML"] && ![string equal $type "EOF"]} { return $emsg(INVALID) }
            set first 0
        }

        if {[string equal $type "EOF"]} break
        ;# TODO: check attributes: quotes, equals and unique

        if {[string equal $type "TXT"]} continue
        if {! [regexp {^[a-zA-Z_:][a-zA-Z0-9.-_:\xB7]+$} $val]} {
            return [subst $emsg(BADNAME)]
        }

        if {[string equal $type "PI"]} {
            if {[string equal -nocase xml $val]} { return $emsg(BADPI) }
            continue
        }
        if {[string equal $etype "START"]} {                ;# Starting tag
            lappend stack $val
        } elseif {[string equal $etype "END"]} {            ;# </tag>
            if {![string equal $val [lindex $stack end]]} { return [subst $emsg(MISMATCH)] }
            set stack [lrange $stack 0 end-1]
            if {[llength $stack] == 0} break    ;# Empty stack
        } elseif {[string equal $etype "EMPTY"]} {          ;# <tag/>
        }
    }

    # End-of-Document can only contain processing instructions
    while {1} {
        foreach {type val attr etype} [::ixXML::NextToken] break
        if {[string equal $type "EOF"]} break
        if {[string equal $type "PI"]} {
            if {[string equal -nocase xml $val]} { return $emsg(BADPI) }
            continue
        }
        return $emsg(EOD)
    }
    return ""
 }

 ################################################################
 #
 # Demo code
 #
 #set xml {<?xml version="1.0" encoding="ISO-8859-1"?>
 #   <loc version="1.0" src="Groundspeak">
 #   <waypoint>
 #   <name id="GCGPXK"><![CDATA[Playing Poker with the Squirrels by Rino 'n Rinette]]></name>
 #   <coord lat="40.1548166" lon="-82.5202833"/>
 #   <type>Geocache</type>
 #   <link text="Cache Details">http://www.geocaching.com/seek/cache_details.aspx?wp=GCGPXK</link>
 #   </waypoint><waypoint>
 #   <name id="GC19DF"><![CDATA[Great Playground Caper by Treasure Hunters Inc.]]></name>
 #   <coord lat="40.0667166666667" lon="-82.5358"/>
 #   <type>Geocache</type>
 #   <link text="Cache Details">http://www.geocaching.com/seek/cache_details.aspx?wp=GC19DF</link>
 #   </waypoint>
 #   </loc>
 #}
#
# ::ixXML::Init $xml
# set wellFormed [::ixXML::IsWellFormed]
# if {![string equal $wellFormed ""]} {
#    puts "The xml is not well-formed: $wellFormed"
# } else {
#    puts "The xml is well-formed"
#    while {1} {
#       foreach {type val attr etype} [::ixXML::NextToken] break
#       puts "looking at: $type '$val' '$attr' '$etype'"
#       if {$type == "EOF"} break
#    }
# }