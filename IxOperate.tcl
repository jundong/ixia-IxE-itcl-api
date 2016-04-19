if {[info exists ::__IXOPERATE_TCL__]} {
    return
}

set ::__IXOPERATE_TCL__ 1

package provide IXIA 1.0
package require registry
#start:added by yuzhenpin 61733 2009-1-24 10:38:13
#��ȡIxOS�İ�װ·��������IxOS
#���ߣ�yuzhenpin 61733
#ʱ�䣺2009-1-24 10:33:53
namespace eval ::ixiaInstall:: {
    proc getIxosHomeDir {} {
        package require registry
    
        set homeDir ""
        
        set listPath [list]
        foreach {reg_path} [list \
        {HKEY_LOCAL_MACHINE\SOFTWARE\Ixia Communications\IxOS} \
        {HKEY_CURRENT_USER\SOFTWARE\Ixia Communications\IxOS}] {
            set listTemp [list]
            catch {set listTemp [registry keys $reg_path *]} errMsg
            foreach each $listTemp {
                lappend listPath "$reg_path\\$each"
            }
        }
        
        if {![llength $listPath]} {
            #error "��ע����ȡIxOS��·��ʧ�ܣ�ԭ�������IxOSû����ȷ��װ��"
            catch {
                ::Utils::Log::debug IXIA "���ʹ��IXIA�Ǳ��밲װIxOS��"
            }
            return
        }
        
        set path [lindex [lsort -decreasing $listPath] 0]
        
        set homeDir ""
        if { [ catch {set homeDir [registry get "$path\\InstallInfo" "HOMEDIR"]} errMsg] } {
            error "$errMsg"
        }
        
        return [file join $homeDir]
    }
    
    proc getIxAutomateHomeDir {} {
        package require registry
    
        set homeDir ""
        
        set listPath [list]
        foreach {reg_path} [list \
        {HKEY_LOCAL_MACHINE\SOFTWARE\Ixia Communications\IxAutomate} \
        {HKEY_CURRENT_USER\SOFTWARE\Ixia Communications\IxAutomate}] {
            set listTemp [list]
            catch {set listTemp [registry keys $reg_path *]} errMsg
            foreach each $listTemp {
                lappend listPath "$reg_path\\$each"
            }
        }
        
        if {![llength $listPath]} {
            #error "��ע����ȡIxOS��·��ʧ�ܣ�ԭ�������IxOSû����ȷ��װ��"
            catch {
                ::Utils::Log::debug IXIA "���ʹ��IXIA�Ǳ��밲װIxAutomate��"
            }
            return
        }
        
        set path [lindex [lsort -decreasing $listPath] 0]
        
        set homeDir ""
        if { [ catch {set homeDir [registry get "$path\\InstallInfo" "HOMEDIR"]} errMsg] } {
            error "$errMsg"
        }
        
        set homeDir [file join $homeDir]
        
        set ::env(IXAUTOMATE_PATH) $homeDir
        lappend ::auto_path $homeDir
        lappend ::auto_path $homeDir/TclScripts
        lappend ::auto_path $homeDir/TclScripts/lib
        
#        puts "Load ScriptMate: [package require Scriptmate]"
        
        return $homeDir
    }
}

# IxiaWish.tcl sets up the Tcl environment to use the correct multiversion-compatible 
# applications, as specified by Application Selector.

# Note: this file must remain compatible with tcl 8.3, because it will be sourced by scriptgen
namespace eval ::ixiaInstall:: {
    # For debugging, you can point this to an alternate location.  It should
    # point to a directory that contains the "TclScripts" subdirectory.
    set tclDir      [getIxosHomeDir]
    
    #���û�а�װixia��ôֱ�ӷ���
    #���������Ѿ�û������
    if {0 >= [llength $tclDir]} {
        return
    }

    # For debugging, you can point this to an alternate location.  It should
    # point to a directory that contains the IxTclHal.dll
    #set ixosTclDir [getIxosHomeDir]
    set ixosTclDir  $tclDir

    set tclLegacyDir [file join $tclDir "../.."]

    # Calls appinfo to add paths to IxOS dependencies (such as IxLoad or IxNetwork).
    proc ixAddPathsFromAppinfo {installdir} {
        package require registry
        
        set installInfoFound false
        foreach {reg_path} [list "HKEY_LOCAL_MACHINE\\SOFTWARE\\Ixia Communications\\AppInfo\\InstallInfo" "HKEY_CURRENT_USER\\SOFTWARE\\Ixia Communications\\AppInfo\\InstallInfo"] {
            if { [ catch {registry get $reg_path "HOMEDIR"} r] == 0 } {
                set appinfo_path $r
                set installInfoFound true
                break
            }
        }
        # If the registy information was not found in either place, warn the user
        if { [string equal $installInfoFound false ]} {
            return -code error "Could not find AppInfo registry entry"
        }   
         
        # Call appinfo to get the list of all dependencies:
        regsub -all "\\\\" $appinfo_path "/" appinfo_path      
        set appinfo_executable [file attributes "$appinfo_path/Appinfo.exe" -shortname]
        set appinfo_command "|$appinfo_executable --app-path \"$installdir\" --get-dependencies"
        set appinfo_handle [open $appinfo_command r+ ]
        set appinfo_session {}

        while { [gets $appinfo_handle line] >= 0 } {
            # Keep track of the output to report in the error message below
            set appinfo_session "$appinfo_session $line\n"
            
            regsub -all "\\\\" $line "/" line
            regexp "^(.+):\ (.*)$" $line all app_name app_path
            # If there is a dependency listed, add the path.
            if {![string equal $app_path ""] } {
                # Only add it if it's not already present:
                if { -1 == [lsearch -exact $::auto_path $app_path ] } {
                    lappend ::auto_path $app_path
                    lappend ::auto_path [file join $app_path "TclScripts/lib"]
                    append ::env(PATH) [format ";%s" $app_path]                    
                }
            }
        }
        
        # If appinfo returned a non-zero result, this catch block will trigger.
        # In that case, show what we tried to do, and the resulting response.
        if { [catch {close $appinfo_handle} r] != 0} {
            return -code error "Appinfo error, \"$appinfo_command\" returned: $appinfo_session"
        }        
    }

    # Adds all needed Ixia paths
    proc ixAddPaths {installdir} {
        set ::env(IXTCLHAL_LIBRARY) [file join $installdir "TclScripts/lib/IxTcl1.0"]
        set ::_IXLOAD_INSTALL_ROOT [file dirname $installdir]
        lappend ::auto_path $installdir
        lappend ::auto_path [file join $installdir "TclScripts/lib"]
        lappend ::auto_path [file join $installdir "TclScripts/lib/IxTcl1.0"]
        if { [catch {::ixiaInstall::ixAddPathsFromAppinfo $installdir} result] } {
            # Not necessarily fatal
            puts [format "WARNING!!! Unable to add paths from Appinfo: %s" $result]
        }
        append ::env(PATH) ";${installdir}"
        
        # Fall back to the old locations, in case a non-multiversion-aware 
        # IxLoad or IxNetwork is installed.
        lappend ::auto_path [file join $installdir "../../TclScripts/lib"]
        append ::env(PATH) [format ";%s" [file join $installdir "../.."]]

        if {![string equal $::ixiaInstall::tclDir $::ixiaInstall::ixosTclDir]} {
            append ::env(PATH) [format ";%s" $::ixiaInstall::ixosTclDir]
        }           
    }
}
::ixiaInstall::ixAddPaths $::ixiaInstall::tclDir


#catch {
#    # Try to set things up for Wish.  
#    # This section will not run in IxExplorer or IxTclInterpreter, hence the catch block.
#    if {[lsearch [package names] "Tk"] >= 0} {
#        console show
#        wm iconbitmap . [file join $::ixiaInstall::tclDir "ixos.ico"]
#        
#        # It is not easy to tell ActiveState wish from the Ixia-compiled wish.
#        # The tcl_platform variable shows one difference: ActiveState implements threading
#        if {![info exists ::tcl_platform(threaded)]} {           
#            # Activestate prints this on its own, otherwise, we add it here:
#            puts -nonewline "(TclScripts) 1 % "
#        }        
#    }
#}
#
#end:added by yuzhenpin 61733 2009-1-24 10:38:13

puts "Load IxOS [package req IxTclHal]"
::ixiaInstall::getIxAutomateHomeDir
catch {console hide} err

#!+================================================================
#��Ȩ (C) 2001-2002����Ϊ�������޹�˾ ��������Բ�
#==================================================================
#�� �� ����    IxOperate.tcl
#�ļ�˵����    ��IXIA 400T�Ǳ���з�װ
#��    �ߣ�    ��׿
#��д���ڣ�    2006-7-13 11:14:2
#�޸ļ�¼��    
#!+================================================================

namespace eval IXIA {
    variable m_debugflag 0X03       ;#�ڲ����������ڵ���
    variable m_ChassisIP 127.0.0.1  ;#IXIA�Ǳ�IP��ַ
	variable m_trigger 0            ;#���˱��ı�־
    
    variable m_portList [list]
    
    #��0-basedת����1-based
    #��Smartbitsһ��
    proc _2_1base_ {_0_based_} {
        return [expr $_0_based_ + 1]
    }
    
    #!!================================================================
    #�� �� ����     SmbDebug
    #�� �� ����     IXIA
    #�������     
    #����������     ���Ժ���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               args:   ����ĵ�����Ϣ 
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 15:8:36
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbDebug {args} {
        set retVal [uplevel $args]
        if {$retVal > 0} {
            IxPuts -red "ERROR:$retVal RETURNED BY ==> $args"
        }
    }

    #!!================================================================
    #�� �� ����     SmbArpPacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     �ڶ˿�������һ��Arp��
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:      Ixia��hub��
    #               Card:      Ixia�ӿڿ����ڵĲۺ�
    #               Port:      Ixia�ӿڿ��Ķ˿ں�  
    #               DstMac:    Ŀ��Mac��ַ
    #               DstIP:     Ŀ��IP��ַ
    #               SrcMac:    ԴMac��ַ
    #               SrcIP:     ԴIP��ַ
    #               args: (��ѡ����,����±�)
    #                       -arptype   ʹ�õ�ʱ���������ּ���.
    #                                 1: arpRequest (default) , 
    #                                 2: arpReply 2 ARP reply or response
    #                                 3: rarpRequest 3 RARP request
    #                                 4: rarpReply 4 RARP reply or response
    #                       -metric      ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
    #                       -length      �����ܳ��ȣ�ȱʡ�����ʹ���������
    #                       -vlan        ���ĵ�VLANֵ��ȱʡ����±��Ĳ���vlan
    #                       -change      �޸����ݰ��е�ָ���ֶΣ��˲�����ʶ�޸��ֶε��ֽ�ƫ����
    #                       -value       �޸����ݵ�����  
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 9:59:2
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbArpPacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP args} {
        set retVal     0

        #��֤�������
        if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP $args"] == 1} {
            set retVal 1
            return $retVal
        }
        
        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        #��ŵ edit 2006��07-20 mac��ַת�� 
        set DstMac [StrMacConvertList $DstMac]
        set SrcMac [StrMacConvertList $SrcMac]
        
        #  Set the defaults
        set Arptype    1
        set Metric     1
        set Length     64
        set Vlan       0
        set Type       "08 00"
        set Change     0
        set Value      {{00 }}          
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
            case $cmdx      {
                -arptype    {set Arptype $argx}
                -metric     {set Metric $argx}
                -length     {set Length $argx}
                -vlan       {set Vlan $argx}
                -change     {set Change $argx}
                -value      {set Value $argx}
                default     {
                    IxPuts -red "Error : cmd option $cmdx  does not exist"
                    set retVal 1
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }
            
        #Define Stream parameters.
        stream setDefault        
        stream config -enable true
        stream config -sa $SrcMac
        stream config -da $DstMac
        
        if {$Length != 0} {
            #stream config -framesize $Length
            stream config -framesize [expr $Length + 4]
            stream config -frameSizeType sizeFixed
        } else {
            stream config -framesize 318
            stream config -frameSizeType sizeRandom
            stream config -frameSizeMIN 64
            stream config -frameSizeMAX 1518       
        }
        stream config -frameType $Type
            
        #Define protocol parameters 
        protocol setDefault        
        #protocol config -name mac
        protocol config -appName Arp
        protocol config -ethernetType ethernetII
        arp setDefault
        arp config -sourceProtocolAddr $SrcIP
        arp config -destProtocolAddr $DstIP
        arp config -sourceHardwareAddr $SrcMac
        arp config -destHardwareAddr $DstMac
        arp config -operation $Arptype
            
        if [arp set $Chas $Card $Port] {
            IxPuts -red "Unable to set ARP configs to IxHal"
            catch { ixputs $::ixErrorInfo} err
            set retVal 1
        }
                    
        if {$Vlan != 0} {
            protocol config -enable802dot1qTag vlanSingle
            vlan setDefault        
            vlan config -vlanID $Vlan
            vlan config -userPriority 0
            if [vlan set $Chas $Card $Port] {
                IxPuts -red "Unable to set Vlan configs to IxHal!"
                catch { ixputs $::ixErrorInfo} err
                set retVal 1
            }
        }
           
        #Table UDF Config        
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        if {$Change == 0} {
            tableUdfColumn config -offset [expr $Length -5]} else {
            tableUdfColumn config -offset $Change
        }
        tableUdfColumn config -size 1
        tableUdf addColumn         
        set rowValueList $Value
        tableUdf addRow $rowValueList
        if [tableUdf set $Chas $Card $Port] {
            IxPuts -red "Unable to set TableUdf to IxHal!"
            catch { ixputs $::ixErrorInfo} err
            set retVal 1
        }

        #Final writting....        
        if [stream set $Chas $Card $Port $Metric] {
            IxPuts -red "Unable to set streams to IxHal!"
            set retVal 1
        }
        lappend portList [list $Chas $Card $Port]
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            catch { ixputs $::ixErrorInfo} err
            set retVal 1
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbCapPacketLengthGet
    #�� �� ����     IXIA
    #�������     
    #����������     ��ȡ����İ��ĳ���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:      Ixia��hub��
    #               Card:      Ixia�ӿڿ����ڵĲۺ�
    #               Port:      Ixia�ӿڿ��Ķ˿ں�   
    #               args:    
    #                        -index packet�����,Ĭ����0
    #�� �� ֵ��     ����һ���б���������Ԫ��
    #               1������ִ�н��
    #               0:����ִ�гɹ�
    #               1:����ִ��ʧ��
    #               1000:��������
    #               2��ָ���ı������ĵĳ���
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 9:54:59
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbCapPacketLengthGet {Chas Card Port args} {
        set retVal     0
        
        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set tmpllength [llength $tmpList]
        set idxxx      0
        
        set PktCnt 0
        set retList {}
        
        #  Set the defaults
        set Index     0

        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]

            case $cmdx      {
                -index      {
                    set Index $argx
                }
                default     {
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    set retVal 1
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }

        if {$retVal == 1} {
            lappend retList $retVal
            lappend retList $PktCnt
            return $retList
        }
        
        if {[capture get $Chas $Card $Port]} {
            set retVal 1
            IxPuts -red "get capture from $Chas,$Card,$Port failed..."
            catch { ixputs $::ixErrorInfo} err
        } else {
            set PktCnt [capture cget -nPackets]
            IxPuts -blue "total $PktCnt packets captured"
        }
      
        #Get all the packet from Chassis to pc.
        #��ŵ edit 2006-07-27 ��PktCnt���ж�
        if {$PktCnt > 0} {
            if {[captureBuffer get $Chas $Card $Port 1 $PktCnt]} {
                set retVal 1
                IxPuts -red "retrieve packets failed..."
                catch { ixputs $::ixErrorInfo} err
            }
                
            #Notice: Ixia buffer index starts with 1. 
            if [captureBuffer getframe [expr $Index + 1]] {
                set retVal 1
                IxPuts -red "read Index = $Index packet failed..."
                catch { ixputs $::ixErrorInfo} err
            }
            
            set data  [captureBuffer cget -frame]
            set Len [llength $data]
            
            #puts "Offset:$Offset, Index:$Index, Len:$Len"
            lappend retList $retVal
            lappend retList $Len
        } elseif {$PktCnt == 0} {
            lappend retList $retVal
            lappend retList $PktCnt
        }       
        return $retList
    }
   
    #!!================================================================
    #�� �� ����     SmbCaptureClear
    #�� �� ����     IXIA
    #�������     
    #����������     ��������ڲ���ı���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:    Ixia��hub��
    #               Card:    Ixia�ӿڿ����ڵĲۺ�
    #               Port:    Ixia�ӿڿ��Ķ˿ں�
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 18:29:43
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbCaptureClear {Chas Card Port} {
        set retVal 0
        if {[ixStartPortCapture $Chas $Card $Port] != 0} {
            IxPuts -red "Could not start capture on $PortList"
            catch { ixputs $::ixErrorInfo} err
            set retVal 1
        }
        if {[ixStopPortCapture $Chas $Card $Port] != 0} {
            IxPuts -red "Could not start capture on $PortList"
            catch { ixputs $::ixErrorInfo} err
            set retVal 1
        }    
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbCapturePktCount
    #�� �� ����     IXIA
    #�������     
    #����������     ȡ��ĳһ�˿ڻ�������������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:    Ixia��hub��
    #               Card:    Ixia�ӿڿ����ڵĲۺ�
    #               Port:    Ixia�ӿڿ��Ķ˿ں�
    #�� �� ֵ��     ����һ���б��������:1.0����1,0��ʾ�ɹ���1��ʾʧ��
    #                                    2.��������
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 18:39:21
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbCapturePktCount {Chas Card Port} {
        set retVal 0
        set PktCnt 0

        #��ŵ edit 2006-07-27
        if {[capture get $Chas $Card $Port]} {
            set retVal 1
            IxPuts -red "get capture from $Chas,$Card,$Port failed..."
        } else {  
		    puts "m_trigger================$IXIA::m_trigger"
            if {$IXIA::m_trigger==1} {
				stat get statAllStats $Chas $Card $Port
				puts "stat get statAllStats $Chas $Card $Port"
					#=============
					# Modified by Eric Yu
                    # set TempVal  [stat cget -captureFilter]
				set PktCnt [stat cget -userDefinedStat1]
				IxPuts -blue "total $PktCnt packets captured"
			} else {
				set PktCnt [capture cget -nPackets]
                IxPuts -blue "total $PktCnt packets captured"
			}		
            
        }
        lappend retList $retVal
        lappend retList $PktCnt
        return $retList
    }

    #!!================================================================
    #�� �� ����     SmbCapturePktGet
    #�� �� ����     IXIA
    #�������     
    #����������     ȡ���û�ָ���Ĳ��񻺴���ĳ�����ĵ�ָ���ֶ�
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:    Ixia��hub��
    #               Card:    Ixia�ӿڿ����ڵĲۺ�
    #               Port:    Ixia�ӿڿ��Ķ˿ں�
    #               args:    
    #                    -index:  �����ĵ���������0��ʼ����ȱʡֵΪ0
    #                    -offset: �����ֶε�ƫ������ȱʡֵΪ0
    #                    -len:    �����ֶε��ֽڳ��ȣ�ȱʡֵΪ0����ʾ���ش�ƫ��λ��ʼ�����Ľ�β����
    #�� �� ֵ��     ����һ���б��������:1.0����1,0��ʾ�ɹ���1��ʾʧ��
    #                                    2.�����ֶ�����
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 19:56:36
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbCapturePktGet {Chas Card Port args} {     
        set retVal     0
        
        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        set args [string tolower $args]
        set tmpList    [lrange $args 0 end]
        set tmpllength [llength $tmpList]
        set idxxx      0
            
        #  Set the defaults
        set Index      0
        set Offset     0
        set Len        0
        set PktCnt     0
        set retList    {}
        
        while {$tmpllength > 0} {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]

            case $cmdx      {
                 -index     {set Index $argx}
                 -offset    {set Offset $argx}
                 -len       {set Len $argx}
                 default     { 
                     set retVal 1
                     IxPuts -red "Error : cmd option $cmdx does not exist"
                     return $retVal
                 }
            }
            incr idxxx  +2
            incr tmpllength -2
        }

        if {$retVal == 1} {
            lappend retList $retVal
            lappend retList $PktCnt
            return $retList
        }
     
        if {[capture get $Chas $Card $Port]} {
            set retVal 1
            IxPuts -blue "get capture from $Chas,$Card,$Port failed..."
        } else {
            set PktCnt [capture cget -nPackets]
            IxPuts -blue "total $PktCnt packets captured"
        }
            
        #Get all the packet from Chassis to pc.
        if {($PktCnt > 0) && ($Index < $PktCnt)} {            
            #if {[captureBuffer get $Chas $Card $Port [expr $Index +1] [expr $Index +1]]} {
            #    set retVal 1
            #    IxPuts -red "retrieve packets failed..."
            #} else {
            #    #Notice: Ixia buffer index starts with 1. 
            #    if {[captureBuffer getframe [expr $Index + 1]]} {
            #        set retVal 1
            #        IxPuts -red "read Index = $Index packet failed..."
            #    }
            #}     
            if {[captureBuffer get $Chas $Card $Port 1 $PktCnt]} {
                set retVal 1
                IxPuts -red "retrieve packets failed..."
            } else {
                #Notice: Ixia buffer index starts with 1. 
                if {[captureBuffer getframe [expr $Index + 1]]} {
                    set retVal 1
                    IxPuts -red "read Index = $Index packet failed..."
                }
            }            
            
            set data  [captureBuffer cget -frame]
            
            if {$Len == 0} {
                set Len [llength $data]
            }
            
            set byteList [list]
            for {set i $Offset} {$i < $Len} {incr i} {
                #modified by yuzhenpin 61733
                #�߾귴��smartbits���ص���10���Ƶ�
                #��ixia���ص���16���Ƶ�
                #����ת����ʮ���Ƶ�
                #lappend byteList "0x[lindex $data $i]"
                lappend byteList [expr "0x[lindex $data $i]"]
                #end
            }
            
            lappend retList $retVal
            lappend retList $byteList
        } elseif {$PktCnt == 0} {
            lappend retList $retVal
            lappend retList $PktCnt
        } else {
             #index >= PktCnt
           lappend retList  1
            lappend retList 0
        }
        return $retList
    }

    #!!================================================================
    #�� �� ����     SmbCapturePortsStart
    #�� �� ����     IXIA
    #�������     
    #����������     �˿ڿ�ʼץ��
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               PortList:   {{$Chas1 $Card1 $Port1} {$Chas2 $Card2 $Port2} ... {$ChasN $CardN $PortN}} 
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 15:14:53
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbCapturePortsStart {PortList} {
        set retVal 0
        if {[ixStartCapture PortList] != 0} {
            set retVal 1
            IxPuts -red "Could not start capture on $PortList"
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbCaptureStart
    #�� �� ����     IXIA
    #�������     
    #����������     �˿ڿ�ʼץ��
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:    Ixia��hub��
    #               Card:    Ixia�ӿڿ����ڵĲۺ�
    #               Port:    Ixia�ӿڿ��Ķ˿ں�
    #               args:     ��ѡ���������ñ��Ĳ������ͣ�ȱʡ��ʾ�������б���
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 18:1:43
    #�޸ļ�¼��     modify by chenshibing 2009-05-21 ���Ӷ�-trigger�����Ĵ���
    #               2009-07-23 ������ ��дӲ����API��ixWritePortsToHardware��ΪixWriteConfigToHardware,��ֹ������·down�����
    #!!================================================================
    proc SmbCaptureStart {Chas Card Port args} {
        set retVal 0
        IxPuts -blue "start capture on $Chas $Card $Port"
        
        # add by chenshibing 2009-05-21 
        set index [lsearch -exact $args "-trigger"]
        if { $index >=0 } {
            set trigger [lindex $args [expr $index + 1]]  
           if { $trigger == 1 } { 
		       set IXIA::m_trigger 1
               capture config -afterTriggerFilter captureAfterTriggerConditionFilter
               capture set $Chas $Card $Port
               lappend portList [list $Chas $Card $Port]
               #modify by chenshibing 2009-07-23 from ixWritePortsToHardware to ixWriteConfigToHardware
               if [ixWriteConfigToHardware portList -noProtocolServer ] {
                   IxPuts -red "Unable to write configs to hardware!"
                   set retVal 1
               }
               #ixCheckLinkState portList
           }
        } else {     
        	#����Ӧ��triggerץ��ʱ���ı�ץ��ģʽ���Է�ǰ����Ӧ�ù�triggerץ��Ӱ��   
        	capture config -continuousFilter captureContinuousAll
        	capture set $Chas $Card $Port
                lappend portList [list $Chas $Card $Port]
                #modify by chenshibing 2009-07-23 from ixWritePortsToHardware to ixWriteConfigToHardware
                if [ixWriteConfigToHardware portList -noProtocolServer ] {
                   IxPuts -red "Unable to write configs to hardware!"
                   set retVal 1
                }
        }
        # add end
        if {[ixStartPortCapture $Chas $Card $Port] != 0} {
            IxPuts -red "Could not start capture on $Chas $Card $Port"
            set retVal 1
        }
        return $retVal
    }


    #!!================================================================
    #�� �� ����     SmbCaptureStop
    #�� �� ����     IXIA
    #�������     
    #����������     �˿�ֹͣץ��
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:    Ixia��hub��
    #               Card:    Ixia�ӿڿ����ڵĲۺ�
    #               Port:    Ixia�ӿڿ��Ķ˿ں�
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 18:24:21
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbCaptureStop {Chas Card Port} {
        set retVal 0
        if {[ixStopPortCapture $Chas $Card $Port] != 0} {
            IxPuts -red "Could not start capture on $Chas $Card $Port"
            set retVal 1
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbChecksumcalc
    #�� �� ����     IXIA
    #�������     
    #����������     ����У���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               array1:               �����������
    #               start, ȱʡֵ��14:    �������ʼ�±�
    #               stop, ȱʡֵ��33:     ������յ��±�
    #�� �� ֵ��     �������16bit��checksum���
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:7:24
    #�޸ļ�¼��     
    #!!================================================================
    proc IxChecksumcalc {array1 {start 14} {stop 33} } {
       upvar $array1 data
       set data(24) 0x00
       set data(25) 0x00
       set sum 0
       for {set k $start; set j [expr $start + 1]} {$k < $stop} {incr k 2; incr j 2} {
           set next_short [expr  (($data($k) << 8) & 0x0000ff00) | ($data($j) & 0x000000ff)]
           set sum [expr $sum + $next_short]
          
       }
       set carry [expr ($sum >> 16) & 0x0000ffff]  
       set sum [expr ($sum & 0x0000ffff) + $carry] 
       set carry [expr ($sum >> 16) & 0x0000ffff]  
       set sum [expr $sum + $carry]           
       return [expr (~$sum) & 0x0000ffff]
    }
    
     #!!================================================================
     #�� �� ����     SmbClosePort
     #�� �� ����     IXIA
     #�������     
     #����������     �رջ��ߴ�ָ���Ķ˿�
     #�÷���         
     #ʾ����         
     #               
     #����˵����     
     #               Chas:    Ixia��hub��
     #               Card:    Ixia�ӿڿ����ڵĲۺ�
     #               Port:    Ixia�ӿڿ��Ķ˿ں�
     #               isClose: �Ƿ�ر��Ǳ�Ķ˿�,Ĭ��Ϊ off �ر�   
     #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
     #��    �ߣ�     ��׿
     #�������ڣ�     2006-7-13 20:9:43
     #�޸ļ�¼��     
     #!!================================================================
     proc SmbClosePort {Chas Card Port isClose} {
         set retVal 0
    
         switch $isClose {
             off {
                     port config -enableSimulateCableDisconnect false
             }
             on  {
                     port config -enableSimulateCableDisconnect true
             }
             default {
                 set retVal 1 
                 IxPuts -red "Error : cmd option $isClose does not exist"
                 return $retVal
             }
         }
         
         if {[port set $Chas $Card $Port]} {
             set retVal 1
             IxPuts -red "failed to set port configuration on port $Chas $Card $Port"
         } else {
             if {[port write $Chas $Card $Port]} {
                 set retVal 1
                 IxPuts -red "failed to write port configuration on port $Chas $Card $Port to hardware"
             }
         }
         return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbFlowCtrlModeSet
    #�� �� ����     SmbCommon
    #�������     
    #����������     ��������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               hub:    IXIA��hub��
    #               slot:   IXIA�ӿڿ����ڵĲۺ�
    #               port:   IXIA�ӿڿ��Ķ˿ں�    
    #               args:
    #                   -pauseflow : pause ��������(��������GE��), ȡֵ: disable, asym, sym, both 
    #                       "disable" = ��ʹ�ܶ˿����� (�շ�˫��ر����ع��ܣ�None)
    #                       "asym" = ʹ�ܷǶԳ����� (Asymmetric->Link Partner)
    #                       "sym"  = ʹ�ܶԳ����� (Symmetric)
    #                       "both" = ʹ�ܷǶԳ�/�Գ����� (Asymmetric->LocalDevice)
    #                   FlowCtrlMode: ���ط�ʽ; ȡֵ:
    #                               enable    ʹ������
    #                               disable   ��ʹ������   
    #                   PreambleLen, ȱʡֵ��64:��̫֡ǰ����ĳ���,��ѡ����,Ϊ�����̵ĸ�������,���ʺ���FE    
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ������
    #�������ڣ�     2007-4-23 16:15:10
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbFlowCtrlModeSet {Chas Card Port args} {
        set args [string tolower $args]
        set ret 0
        set type ""
        set PreambleLen 64

        set pos [lsearch $args "-pauseflow"]
        if { $pos > -1 } {
            set type [lindex $args [expr $pos + 1]]
            set args [lreplace $args $pos [expr $pos + 1]]
        } 

        if { [llength $args] > 1 } {
            set PreambleLen [lindex $args 1]
        } 
        set FlowCtrlMode [lindex $args 0]
        
        switch -exact -- $FlowCtrlMode { 
            "enable" { 
                set FlowCtrlMode "true"
            }
            "disable" {
                set FlowCtrlMode "false"
            }
            default {
                IxPuts -red "��������$FlowCtrlMode,����ֻ����enable��disable"
                return 1
            }
        }
        # ʹ������
        port config -flowControl $FlowCtrlMode

        # ������������
        if  { $type != "" } {
            port config -autonegotiate  true
            set type [string map {disable portAdvertiseNone asym portAdvertiseSend\
                sym portAdvertiseSendAndReceive both portAdvertiseSendAndOrReceive} $type]
            port config -advertiseAbilities $type
        } 
        
        if { [port set $Chas $Card $Port] } {
            IxPuts -red "failed to set port configuration on port $Chas $Card $Port"
            set ret 1
        }

        lappend portList [list $Chas $Card $Port]
        if [ixWritePortsToHardware portList -noProtocolServer] {
            IxPuts -red "Can't write config to $Chas $Card $Port"
            set ret 1   
        }    
        return $ret
    }

    #!!================================================================
    #�� �� ����     SmbCustomPacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     Ixia�����û��Զ��屨������(�����ļ��е����ݶ��������tclʶ�����Ч����)
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:     Ixia��hub��
    #               Card:     Ixia�ӿڿ����ڵĲۺ�
    #               Port:     Ixia�ӿڿ��Ķ˿ں�
    #               Len:      ���ĳ���
    #               Lcon:     ��������
    #                       -strtransmode   ���������͵�ģʽ,����0:�������� 1:������ָ������Ŀ��ֹͣ 2:�����걾���������������һ����.
    #                       -strframenum    ���屾�������͵İ���Ŀ
    #                       -strrate        ��������,���ٵİٷֱ�. 100 �������ٵ� 100%, 1 �������ٵ� 1%
    #                       -strburstnum    ���屾�����������ٸ�burst,ȡֵ��Χ1~65535,Ĭ��Ϊ1
    #               streamID:    
    #�� �� ֵ��     0:����ִ�гɹ�;1:����ִ��ʧ��;1000:��������
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:13:25
    #�޸ļ�¼��     2009-07-23 ������ ��дӲ����API��ixWritePortsToHardware��ΪixWriteConfigToHardware,��ֹ������·down�����
    #!!================================================================
    proc SmbCustomPacketSet  {Chas Card Port Len Lcon args}  {


        set retVal 0
        set streamID 1

        set Dstmac {00 00 00 00 00 00}
        set Srcmac {00 00 00 00 00 01}
        set Strtransmode 0
        set Strframenum    100
        set Strrate    100
        set Strburstnum  1
        
        set args [string tolower $args]    
        while { [llength $args] > 0  } {
            set cmdx [lindex $args 0]
            set argx [lindex $args 1]
            set args [lreplace $args 0 1]
            case $cmdx      {        				
                -strtransmode { set Strtransmode $argx}
                -strframenum {set Strframenum $argx}
                -strrate     {set Strrate $argx}
                -strburstnum {set Strburstnum $argx}
                default {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
           }
        }

        stream setDefault        
        stream config -name Custom_Stream
        #stream config -numBursts 1    
        #stream config -numFrames 100
        #stream config -percentPacketRate 100
        stream config -numBursts $Strburstnum        
        stream config -numFrames $Strframenum
        stream config -percentPacketRate $Strrate
        
        stream config -rateMode usePercentRate
        stream config -sa $Srcmac
        stream config -da $Dstmac
        #stream config -dma contPacket

        puts "stream transmit mode:$Strtransmode"        
        switch $Strtransmode {
            0 {stream config -dma contPacket}
            1 {stream config -dma stopStream}
            2 {
            		#modified by Eric Yu
            		#stream config -dma advance
            		stream config -dma contBurst
            }
            default {
                set retVal 1
                IxPuts -red "No such stream transmit mode, please check -strtransmode parameter."
                return $retVal
            }
        }

        #stream config -framesize $Len
        stream config -framesize [expr $Len + 4]
        stream config -frameSizeType sizeFixed

        set ls {}
        foreach sub $Lcon {
            lappend ls  [format %02x $sub]
        }

        if { [llength $ls] >= 12} {
            stream config -da [lrange $ls 0 5]
            stream config -sa [lrange $ls 6 11]
        } elseif { [llength $ls] > 6 } {
            stream config -da [lrange $ls 0 5]
            for {set i 0} {$i < [llength $ls] - 7} {incr i} {
                set Dstmac [lreplace $Dstmac $i $i [lindex $ls $i]]
            }
            stream config -sa $Dstmac
        } else {
            for {set i 0} { $i < [llength $ls]} {incr i} {
                set Srcmac [lreplace $Srcmac $i $i [lindex $ls $i]]
            }
            stream config -da $Srcmac
        }
        
        stream config -patternType repeat
        stream config -dataPattern userpattern
        stream config -frameType "86 DD"
        if { [llength $ls] >= 12 } {
            stream config -pattern [lrange $ls 12 end]
        } 

        if {[stream set $Chas $Card $Port $streamID]} {
            IxPuts -red "Can't set stream $Chas $Card $Port $streamID"
            set retVal 1
        }

        lappend portList [list $Chas $Card $Port]
        #-- Edited by Eric Yu to make a fix that 
        # executing ixWriteConfigToHardware will stop the capture and other action associated with hardware
        #modify by chenshibing 2009-07-23 from ixWritePortsToHardware to ixWriteConfigToHardware
        #if {[ixWriteConfigToHardware portList -noProtocolServer]} {
        #    IxPuts -red "Can't write stream to  $Chas $Card $Port"
        #    set retVal 1
        #}    
        #ixCheckLinkState portList
        if { [ stream write $Chas $Card $Port $streamID ] } {
            IxPuts -red "Can't write stream $Chas $Card $Port $streamID"
            set retVal 1
        }
        return $retVal      
    }

    #!!================================================================
    #�� �� ����     SmbDeleteStreams
    #�� �� ����     IXIA
    #�������     
    #����������     ������ID������˿��ϵ���.
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:     Ixia��hub��
    #               Card:     Ixia�ӿڿ����ڵĲۺ�
    #               Port:     Ixia�ӿڿ��Ķ˿ں�    
    #               sList:    ��ID�б�,�� "1 2 3 4...",�û���Ҫȷ���Ѿ�֪����Щ�������ڶ˿���.
    #                         ����б�Ϊ��"",���ʾ����˿������е���.
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:20:47
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbDeleteStreams {Chas Card Port sList } {
       set retVal 0
       if {[llength $sList] == 0} {
           IxPuts -blue "Deleting all the streams in $Chas $Card $Port"
           port reset $Chas $Card $Port
       } else {
           IxPuts -blue "Deleting ID=$sList streams in $Chas $Card $Port" 
           set saveStrm {}
           set strm 1
           while {![stream get $Chas $Card $Port $strm] } {
               if {[lsearch -exact $sList $strm] != -1} {
                   incr strm
                   continue;
               }
               set filename "stream_$strm"
               stream export $filename $Chas $Card $Port $strm $strm
               lappend saveStrm $filename
               incr strm
           }
           port reset $Chas $Card $Port
           set strm 1
           foreach filename $saveStrm {
               stream import $filename $Chas $Card $Port
               file delete $filename
               incr strm
           }
       }
       
       lappend portList [list $Chas $Card $Port]
       # modify by ������ 2009-07-23������-noProtocolServer����
       if {[ixWriteConfigToHardware portList -noProtocolServer]} {
           IxPuts -red "Unable to write config to hardware"
           set retVal 1
       }
       return $retVal
    }

    #!!================================================================
    #�� �� ����     IxErrorSet
    #�� �� ����     IXIA
    #�������     
    #����������     ���ö˿ڴ��������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:      Ixia��hub��
    #               Card:      Ixia�ӿڿ����ڵĲۺ�
    #               Port:      Ixia�ӿڿ��Ķ˿ں�  
    #               args:     
    #                         -default        1:�������ķ����Զ�������������(Ĭ��ֵ1) 0:������
    #                         -crc            1:���� 0:������    ���İ���CRC����,Ĭ�ϲ�����
    #                         -nocrc            1:���� 0:������    ���Ĳ�����CRC,Ĭ�ϲ�����
    #                         -align            1:���� 0:������    ���İ����ֽ����д���Bits������8����������,Ĭ�ϲ�����
    #                         -dribble        1:���� 0:������    ���İ��������ֽڣ�CRCλ���ж����Bits��,Ĭ�ϲ�����
    #                        -streamid        ����,��ID,Ĭ��Ϊ1   
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 9:49:54
    #�޸ļ�¼��     yuzhenpin 61733 2009-1-24 9:10:30
    #               add "-default"
    #!!================================================================
    proc SmbErrorSet {Chas Card Port args} {
        set retVal 0
        
        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList     [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]

        #  Set the defaults
        set Default    1
        set Crc        0
        set Nocrc      0
        set Dribble    0
        set Align      0
        set Streamid   1

        # puts $tmpllength
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
           
            case $cmdx   {
               -crc      { set Crc $argx}
               -nocrc    {set Nocrc $argx}
               -dribble  {set Dribble $argx}
               -align    {set Align $argx}
               -streamid {set Streamid $argx}
               -default {
                    #added by yuzhenpin 61733 2009-1-24 9:10:58
                    break
                }
               default   {
                   set retVal 1
                   IxPuts -red "Error : cmd option $cmdx does not exist"
                   return $retVal
               }
            }
            incr idxxx  +2
            incr tmpllength -2
        }

        if {[stream get $Chas $Card $Port $Streamid]} {
            set retVal 1
            IxPuts -red "Unable to retrive config of No.$Streamid stream from $Chas $Card $Port!"
        }
        if {$Default == 1} {
            if {$Crc == 1} {
                stream config -fcs 3
            }
            if {$Nocrc == 1} {
                stream config -fcs 4
            }
            if {$Dribble == 1} {
                stream config -fcs 2
            }
            if {$Align == 1} {
                stream config -fcs 1
            }      
        }
        if {$Default == 0} {
            stream config -fcs 0
        }
        
        if [stream set $Chas $Card $Port $Streamid] {
            IxPuts -red "Unable to set streams to IxHal!"
            set retVal 1
        }
        
        #-- Edit by Eric Yu to fix the bug that ixWriteConfigToHardware will stop the capture
        #lappend portList [list $Chas $Card $Port]
        #if [ixWriteConfigToHardware portList -noProtocolServer ] {
        #    IxPuts -red "Unable to write configs to hardware!"
        #    set retVal 1
        #}
        if [stream write $Chas $Card $Port $Streamid] {
            IxPuts -red "Unable to write streams to IxHal!"
            set retVal 1
        }
        
        return $retVal
    }  

    #!!================================================================
    #�� �� ����     SmbEthFrameSet
    #�� �� ����     IXIA
    #�������     
    #����������     ����2�����
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:         Ixia��hub��
    #               Card:         Ixia�ӿڿ����ڵĲۺ�
    #               Port:         Ixia�ӿڿ��Ķ˿ں�  
    #               strDstMac:       Ŀ��MAC
    #               strSrcMac:       ԴMAC
    #               args: ��ѡ����
    #                       -frametype  1: tag��802.1Q֡�� 2: ETH II֡(Ĭ��ֵ2)��3: 802.3֡���͡�ȱʡΪ1    ֡����; (Ŀǰ֧��2,3����)
    #                       -length     ֡����ȱʡΪ64
    #                       -tag        0 ��VLAN֡ 1 ��VLAN TAG��֡ 2 ��˫��VLAN TAG��֡ 3 ������VLAN TAG��֡   �Ƿ�ΪVLAN TAGģʽ��ȱʡΪ0, 
    #                       -pri            0��7��ȱʡΪ0   Vlan�����ȼ��� 
    #                       -cfi        0��1��ȱʡΪ0   Vlan�������ֶΣ� 
    #                       -vlan       1��4095��ȱʡΪ1    ֡��VLANֵ�� 
    #                       -pri2       0��7��ȱʡΪ0   ˫��Vlan�����ȼ���
    #                       -cfi2       0��1��ȱʡΪ0   ˫��Vlan�������ֶΣ�
    #                       -vlan2          1��4095��ȱʡΪ1    ֡��˫��VLANֵ�� 
    #                       -pri3       0��7��ȱʡΪ0   ����Vlan�����ȼ���
    #                       -cfi3       0��1��ȱʡΪ0   ����Vlan�������ֶΣ�
    #                       -vlan3      1��4095��ȱʡΪ1    ֡������VLANֵ�� 
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 11:39:30
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbEthFrameSet {Chas Card Port strDstMac strSrcMac args} {
        set retVal 0

        if {[IxParaCheck "-dstmac $strDstMac -srcmac $strSrcMac $args"] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]

        #��ŵ edit 2006��07-21 mac��ַת�� 
        set strDstMac [StrMacConvertList $strDstMac]
        set strSrcMac [StrMacConvertList $strSrcMac]
        
        #  Set the defaults
        set Streamid        1
        set Frametype       2
        set Length          64
        set Tag             0
        set Pri             0
        set Cfi             0
        set Vlan            1
        set Pri2            0
        set Cfi2            0
        set Vlan2           1
        set Pri3            0
        set Cfi3            0
        set Vlan3           1        
        set args [string tolower $args]
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -streamid   {set Streamid $argx}
                -frametype  {set Frametype $argx }
                -length     { set Length $argx}
                -tag        {set Tag $argx}
                -pri        {set Pri $argx }
                -cfi        {set Cfi $argx}
                -vlan       {set Vlan $argx}
                -pri2       { set Pri2 $argx}
                -cfi2       {set Cfi2 $argx}
                -vlan2      {set Vlan2 $argx}
                -pri3       {set Pri3 $argx}
                -cfi3       {set Cfi3 $argx}
                -vlan3      {set Vlan3 $argx}
                default     {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx $argx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }     
            
        stream setDefault        
        stream config -name "Layer2Stream"
        stream config -sa $strSrcMac
        stream config -da $strDstMac
        #stream config -framesize $Length
        stream config -framesize [expr $Length + 4]
        stream config -frameType "FF FF"
        protocol setDefault
        switch $Frametype {
            2 {protocol config -ethernetType ethernetII}
            3 {protocol config -ethernetType ieee8023}
            default {
                set retVal 1
                IxPuts -red  "No such layer2 type, please check -frametype input."
                return $retVal
            }
        }
                
        switch $Tag {
            0 {}
            1 {
                protocol config -enable802dot1qTag vlanSingle
                vlan setDefault        
                vlan config -vlanID $Vlan
                vlan config -userPriority $Pri
                switch $Cfi {
                    0 {vlan config -cfi resetCFI}
                    1 {vlan config -cfi setCFI}
                    default {
                        set retVal 1
                    }
                }
                if {[vlan set $Chas $Card $Port]} {
                    set retVal 1
                    IxPuts -red "Unable to set Vlan configs to IxHal!"
                    return $retVal
                }                
            }
            2 {
                protocol config -enable802dot1qTag vlanStacked
                stackedVlan setDefault        
                set vlanPosition 1
                vlan setDefault        
                vlan config -vlanID $Vlan
                vlan config -userPriority $Pri
                switch $Cfi {
                    0 {vlan config -cfi resetCFI}
                    1 {vlan config -cfi setCFI}
                    default {
                        set retVal 1
                    }
                }                                
                stackedVlan setVlan $vlanPosition                
                incr vlanPosition      
                vlan setDefault        
                vlan config -vlanID $Vlan2
                vlan config -userPriority $Pri2
                switch $Cfi2 {
                    0 {vlan config -cfi resetCFI}
                    1 {vlan config -cfi setCFI}
                    default {
                        set retVal 1
                    }
                }               
                stackedVlan setVlan $vlanPosition
                if {[stackedVlan set $Chas $Card $Port]} {
                    set retVal 1
                    IxPuts -red "Unable to set Stack Vlan configs to IxHal!"
                    return $retVal
                }                                        
            }
            3 {
                protocol config -enable802dot1qTag vlanStacked
                stackedVlan setDefault        
                set vlanPosition 1
                vlan setDefault        
                vlan config -vlanID $Vlan
                vlan config -userPriority $Pri
                switch $Cfi {
                    0 {vlan config -cfi resetCFI}
                    1 {vlan config -cfi setCFI}
                    default {
                        set retVal 1
                    }
                }                                
                stackedVlan setVlan $vlanPosition                
                incr vlanPosition      
                vlan setDefault        
                vlan config -vlanID $Vlan2
                vlan config -userPriority $Pri2
                switch $Cfi2 {
                    0 {vlan config -cfi resetCFI}
                    1 {vlan config -cfi setCFI}
                    default {
                        set retVal 1
                    }
                }               
                stackedVlan setVlan $vlanPosition
                incr vlanPosition      
                vlan setDefault        
                vlan config -vlanID $Vlan3
                vlan config -userPriority $Pri3
                switch $Cfi3 {
                    0 {vlan config -cfi resetCFI}
                    1 {vlan config -cfi setCFI}
                    default {
                        set retVal 1
                    }
                }               
                stackedVlan addVlan                        
                if {[stackedVlan set $Chas $Card $Port]} {
                    set retVal 1
                    IxPuts -red "Unable to set Stack Vlan configs to IxHal!"
                    return $retVal
                }                           
            }
            default {
            }
        }
        if {[stream set $Chas $Card $Port $Streamid]} {
            set retVal 1
            IxPuts -red "Unable to set Stack Vlan configs to IxHal!"
            return $retVal
        } 
        lappend portList "$Chas $Card $Port"        
        if {[ixWriteConfigToHardware portList -noProtocolServer]} {
            set retVal 1
            IxPuts -red "Can't write config to port"
            return $retVal
        }
        return $retVal       
    }
    
    #!!================================================================
    #�� �� ����     SmbLanCardTypeGet
    #�� �� ����     IXIA
    #�������     
    #����������     ȡ�ÿ�������(ע��:��ΪIXIA��ֻ��ǧ�׿������Բ���Ҫ����ֱ�ӷ���0)
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�  
    #�� �� ֵ��     ����һ���б�,��һԪ�����ַ�����ʾ�ĵ�ǰ��������,�ڶ���Ԫ���ǿ������ͱ��,����.
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-18 11:8:30
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbLanCardTypeGet {Chas Card Port} {
        set retVal 0
        if {[card get $Chas $Card]} {
            IxPuts -red "get card info error!"
            set retVal 1
        }        
        set type [card cget -type]
        set typeName [card cget -typeName]
        lappend FinalList $typeName
        lappend FinalList $type
        return $FinalList
    }

    #!!================================================================
    #�� �� ����     SmbGetCardType
    #�� �� ����     IXIA
    #�������     
    #����������     ȡ�ÿ�������(ע��:��ΪIXIA��ֻ��ǧ�׿������Բ���Ҫ����ֱ�ӷ���0)
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�  
    #�� �� ֵ��     ����һ���б�,��һԪ�����ַ�����ʾ�ĵ�ǰ��������,�ڶ���Ԫ���ǿ������ͱ��,����.
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-18 11:8:30
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbGetCardType {Chas Card Port} {
        set retVal 0
        if {[card get $Chas $Card]} {
            IxPuts -red "get card info error!"
            set retVal 1
        }        
        set type [card cget -type]
        set typeName [card cget -typeName]
        lappend FinalList $typeName
        lappend FinalList $type
        return $FinalList
    }
    
    #!!================================================================
    #�� �� ����     SmbLink
    #�� �� ����     IXIA
    #�������     
    #����������     ����IXIA�Ǳ�
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               chassisIp:  �Ǳ�IP��ַ  
    #               linkPara, ȱʡֵ��0:  ���Ӳ�����ȡRESERVE_ALL��RESERVE_NONE��
    #                                ȱʡΪRESERVE_NONE:  
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 13:40:5
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbLink {ChassisIp {linkPara 0}} {

        set retVal 0
        if {[isUNIX]} {
           if {[ixConnectToTclServer $ChassisIp]} {
               IxPuts -red "Error connecting to Tcl Server $ChassisIp"
               set retVal 1
               return $retVal
           }
        }   
        set connectingresult [ixConnectToChassis $ChassisIp]
        variable m_ChassisIP
        set m_ChassisIP $ChassisIp
        
        switch $connectingresult {
            0 {IxPuts -blue "�ɹ�����IXIA�Ǳ�\n"}
            1 {IxPuts -blue "û���ҵ�IXIA�Ǳ�......";set retVal 1}
            2 {IxPuts -red "IXIA�Ǳ�API�汾��ƥ��";set retVal 2}
            3 {IxPuts -red "����IXIA�Ǳ�ʱ";set retVal 3}
            default {set retVal 1}
       }
       
       return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbIcmpPacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     ICMP������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں� 
    #               DstMac:        Ŀ��Mac��ַ
    #               DstIP:         Ŀ��IP��ַ
    #               SrcMac:        ԴMac��ַ
    #               SrcIP:         ԴIP��ַ
    #               args: (��ѡ����,����±�)
    #                       -streamid       ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
    #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
    #                       -vlan           Vlan tag,����,Ĭ��0,����û��VLAN Tag,����0��ֵ�Ų���VLAN tag.
    #                       -pri            Vlan�����ȼ�����Χ0��7��ȱʡΪ0
    #                       -cfi            Vlan�������ֶΣ���Χ0��1��ȱʡΪ0
    #                       -type           ����ETHЭ�����ͣ�ȱʡֵ "08 00"
    #                       -ver            ����IP�汾��ȱʡֵ4
    #                       -iphlen         IP����ͷ���ȣ�ȱʡֵ5
    #                       -tos            IP���ķ������ͣ�ȱʡֵ0
    #                       -dscp           DSCP ֵ,ȱʡֵ0
    #                       -tot            IP���ɳ��ȣ�ȱʡֵ���ݱ��ĳ��ȼ���
    #                       -id             ���ı�ʶ�ţ�ȱʡֵ1
    #                       -mayfrag        �Ƿ�ɷ�Ƭ��־, 0:�ɷ�Ƭ, 1:����Ƭ
    #                       -lastfrag       ���Ƭ�������һƬ, 0: ���һƬ(ȱʡֵ), 1:�������һƬ
    #                       -fragoffset     ��Ƭ��ƫ������ȱʡֵ0
    #                       -ttl            ��������ʱ��ֵ��ȱʡֵ255
    #                       -pro            ����IPЭ�����ͣ�ȱʡֵ4
    #                       -change         �޸����ݰ��е�ָ���ֶΣ��˲�����ʶ�޸��ֶε��ֽ�ƫ����,Ĭ��ֵ,���һ���ֽ�(CRCǰ).
    #                       -value          �޸����ݵ�����, Ĭ��ֵ {{00 }}, 16���Ƶ�ֵ.
    #                       -enable         �Ƿ�ʹ��������Ч true / false
    #                       -sname          ������������,����Ϸ����ַ���.Ĭ��Ϊ""
    #                       -strtransmode   ���������͵�ģʽ,����0:�������� 1:������ָ������Ŀ��ֹͣ 2:�����걾���������������һ����.
    #                       -strframenum    ���屾�������͵İ���Ŀ
    #                       -strrate        ��������,���ٵİٷֱ�. 100 �������ٵ� 100%, 1 �������ٵ� 1%
    #                       -strburstnum    ���屾�����������ٸ�burst,ȡֵ��Χ1~65535,Ĭ��Ϊ1
    #                       -icmptype       ICMP�������ͣ�ȱʡֵ0
    #                       -icmpcode       ICMP�������룬ȱʡֵ0
    #                       -icmpid         ICMP����ID��ȱʡֵ0
    #                       -icmpseq        ICMP���кţ�ȱʡֵ0
    #
    #                       -udf1           �Ƿ�ʹ��UDF1,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf1offset     UDFƫ����
    #                       -udf1len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf1initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf1step       UDF�仯����,Ĭ��1
    #                       -udf1changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf1repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf2           �Ƿ�ʹ��UDF2,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf2offset     UDFƫ����
    #                       -udf2len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf2initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf2step       UDF�仯����,Ĭ��1
    #                       -udf2changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf2repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf3           �Ƿ�ʹ��UDF3,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf3offset     UDFƫ����
    #                       -udf3len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf3initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf3step       UDF�仯����,Ĭ��1
    #                       -udf3changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf3repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf4           �Ƿ�ʹ��UDF4,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf4offset     UDFƫ����
    #                       -udf4len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf4initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf4step       UDF�仯����,Ĭ��1
    #                       -udf4changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf4repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf5           �Ƿ�ʹ��UDF5,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf5offset     UDFƫ����
    #                       -udf5len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf5initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf5step       UDF�仯����,Ĭ��1
    #                       -udf5changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf5repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #    
    #�� �� ֵ��     �ɹ�����0,ʧ��1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 8:55:6
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbIcmpPacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP args} {
        set retVal     0

        if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP $args"] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]

        #��ŵ edit 2006��07-20 mac��ַת�� 
        set DstMac [StrMacConvertList $DstMac]
        set SrcMac [StrMacConvertList $SrcMac]
        
        #  Set the defaults
        set streamId   1
        set Sname      ""
        set Length     64
        set Vlan       0
        set Pri        0
        set Cfi        0
        set Type       "08 00"
        set Ver        4
        set Iphlen     5
        set Tos        0
        set Dscp       0
        set Tot        0
        set Id         1
        set Mayfrag    0
        set Lastfrag   0
        set Fragoffset 0
        set Ttl        255        
        set Pro        4
        set Change     0
        set Enable     true
        set Value      {{00 }}
        set Strtransmode 0
        set Strframenum    100
        set Strrate    100
        set Strburstnum  1
        set Icmptype   0
        set Icmpcode   0
        set Icmpid     0
        set Icmpseq    0        
        
        set Udf1       0
        set Udf1offset 0
        set Udf1len    1
        set Udf1initval {00}
        set Udf1step    1
        set Udf1changemode 0
        set Udf1repeat  1
            
        set Udf2       0
        set Udf2offset 0
        set Udf2len    1
        set Udf2initval {00}
        set Udf2step    1
        set Udf2changemode 0
        set Udf2repeat  1
        
        set Udf3       0
        set Udf3offset 0
        set Udf3len    1
        set Udf3initval {00}
        set Udf3step    1
        set Udf3changemode 0
        set Udf3repeat  1
        
        set Udf4       0
        set Udf4offset 0
        set Udf4len    1
        set Udf4initval {00}
        set Udf4step    1
        set Udf4changemode 0
        set Udf4repeat  1        
        
        set Udf5       0
        set Udf5offset 0
        set Udf5len    1
        set Udf5initval {00}
        set Udf5step    1
        set Udf5changemode 0
        set Udf5repeat  1

        set args [string tolower $args]
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -streamid   {set streamId $argx}
                -sname      {set Sname $argx}
                -length     {set Length $argx}
                -vlan       {set Vlan $argx}
                -pri        {set Pri $argx}
                -cfi        {set Cfi $argx}
                -type       {set Type $argx}
                -ver        {set Ver $argx}
                -iphlen     {set Iphlen $argx}
                -tos        {set Tos $argx}
                -dscp       {set Dscp $argx}
                -tot        {set Tot  $argx}
                -mayfrag    {set Mayfrag $argx}
                -lastfrag   {set Lastfrag $argx}
                -fragoffset {set Fragoffset $argx}
                -ttl        {set Ttl $argx}
                -id         {set Id $argx}
                -pro        {set Pro $argx}
                -change     {set Change $argx}
                -value      {set Value $argx}
                -enable     {set Enable $argx}
                -strtransmode { set Strtransmode $argx}
                -strframenum {set Strframenum $argx}
                -strrate     {set Strrate $argx}
                -strburstnum {set Strburstnum $argx}
                -icmptype   {set Icmptype $argx}
                -icmpcode   {set Icmpcode $argx}
                -icmpid     {set Icmpid $argx}
                -icmpseq    {set Icmpseq $argx}
                            
                -udf1           {set Udf1 $argx}
                -udf1offset     {set Udf1offset $argx}
                -udf1len        {set Udf1len $argx}
                -udf1initval    {set Udf1initval $argx}  
                -udf1step       {set Udf1step $argx}
                -udf1changemode {set Udf1changemode $argx}
                -udf1repeat     {set Udf1repeat $argx}
                
                -udf2           {set Udf2 $argx}
                -udf2offset     {set Udf2offset $argx}
                -udf2len        {set Udf2len $argx}
                -udf2initval    {set Udf2initval $argx}  
                -udf2step       {set Udf2step $argx}
                -udf2changemode {set Udf2changemode $argx}
                -udf2repeat     {set Udf2repeat $argx}
                            
                -udf3           {set Udf3 $argx}
                -udf3offset     {set Udf3offset $argx}
                -udf3len        {set Udf3len $argx}
                -udf3initval    {set Udf3initval $argx}  
                -udf3step       {set Udf3step $argx}
                -udf3changemode {set Udf3changemode $argx}
                -udf3repeat     {set Udf3repeat $argx}
                
                -udf4           {set Udf4 $argx}
                -udf4offset     {set Udf4offset $argx}
                -udf4len        {set Udf4len $argx}
                -udf4initval    {set Udf4initval $argx}  
                -udf4step       {set Udf4step $argx}
                -udf4changemode {set Udf4changemode $argx}
                -udf4repeat     {set Udf4repeat $argx}
                
                -udf5           {set Udf5 $argx}
                -udf5offset     {set Udf5offset $argx}
                -udf5len        {set Udf5len $argx}
                -udf5initval    {set Udf5initval $argx}  
                -udf5step       {set Udf5step $argx}
                -udf5changemode {set Udf5changemode $argx}
                -udf5repeat     {set Udf5repeat $argx}
                         
                default {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }                    
            incr idxxx  +2
            incr tmpllength -2
        }

        if {$retVal == 1} {
            return $retVal
        }
        
        #Define Stream parameters.
        stream setDefault        
        stream config -enable $Enable
        stream config -name $Sname
        stream config -numBursts $Strburstnum        
        stream config -numFrames $Strframenum
        stream config -percentPacketRate $Strrate
        stream config -rateMode usePercentRate
        stream config -sa $SrcMac
        stream config -da $DstMac
        switch $Strtransmode {
            0 {stream config -dma contPacket}
            1 {stream config -dma stopStream}
            2 {stream config -dma advance}
            default {
                set retVal 1
                IxPuts -red "No such stream transmit mode, please check -strtransmode parameter."
                return $retVal
            }
        }
            
        if {$Length != 0} {
            #stream config -framesize $Length
            stream config -framesize [expr $Length + 4]
            stream config -frameSizeType sizeFixed
        } else {
            stream config -framesize 318
            stream config -frameSizeType sizeRandom
            stream config -frameSizeMIN 64
            stream config -frameSizeMAX 1518       
        }
                  
        stream config -frameType $Type
        
        #Define protocol parameters 
        protocol setDefault        
        protocol config -name ipV4        
        protocol config -ethernetType ethernetII
        
        ip setDefault        
        ip config -ipProtocol ipV4ProtocolIcmp
        ip config -identifier   $Id
        #ip config -totalLength 46
        switch $Mayfrag {
            0 {ip config -fragment may}
            1 {ip config -fragment dont}
        }       
        switch $Lastfrag {
            0 {ip config -fragment last}
            1 {ip config -fragment more}
        }       

        ip config -fragmentOffset 1
        ip config -ttl $Ttl        
        ip config -sourceIpAddr $SrcIP
        ip config -destIpAddr   $DstIP
        if [ip set $Chas $Card $Port] {
            IxPuts -red "Unable to set IP configs to IxHal!"
            set retVal 1
        }
        #Dinfine ICMP protocol        
        icmp setDefault        
        icmp config -type $Icmptype
        icmp config -code $Icmpcode
        icmp config -id $Icmpid
        icmp config -sequence $Icmpseq
        if [icmp set $Chas $Card $Port] {
            IxPuts -red "Unable to set ICMP config to IxHal!"
            set retVal 1
        }
                  
        if {$Vlan != 0} {
            protocol config -enable802dot1qTag vlanSingle
            vlan setDefault        
            vlan config -vlanID $Vlan
            vlan config -userPriority $Pri
            if [vlan set $Chas $Card $Port] {
                IxPuts -red "Unable to set Vlan configs to IxHal!"
                set retVal 1
            }
        }
        switch $Cfi {
            0 {vlan config -cfi resetCFI}
            1 {vlan config -cfi setCFI}
        }
        
        #UDF Config
        if {$Udf1 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf1offset
            switch $Udf1len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf1changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf1initval
            udf config -repeat  $Udf1repeat              
            udf config -step    $Udf1step
            udf set 1
        }
        if {$Udf2 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf2offset
            switch $Udf2len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf2changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf2initval
            udf config -repeat  $Udf2repeat              
            udf config -step    $Udf2step
            udf set 2
        }
        if {$Udf3 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf3offset
            switch $Udf3len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf3changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf3initval
            udf config -repeat  $Udf3repeat              
            udf config -step    $Udf3step
            udf set 3
        }
        if {$Udf4 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf4offset
            switch $Udf4len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf4changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf4initval
            udf config -repeat  $Udf4repeat              
            udf config -step    $Udf4step
            udf set 4
        }
        if {$Udf5 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf5offset
            switch $Udf5len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf5changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf5initval
            udf config -repeat  $Udf5repeat              
            udf config -step    $Udf5step
            udf set 5
        }        
                    
        #Table UDF Config        
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        if {$Change == 0} {
            tableUdfColumn config -offset [expr $Length -5]} else {
            tableUdfColumn config -offset $Change
        }
        tableUdfColumn config -size 1
        tableUdf addColumn         
        set rowValueList $Value
        tableUdf addRow $rowValueList
        if [tableUdf set $Chas $Card $Port] {
            IxPuts -red "Unable to set TableUdf to IxHal!"
            set retVal 1
        }

        #Final writting....        
        if [stream set $Chas $Card $Port $streamId] {
            IxPuts -red "Unable to set streams to IxHal!"
            set retVal 1
        }
        
        incr streamId
        lappend portList [list $Chas $Card $Port]
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            set retVal 1
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbIgmpPacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     IGMP������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�  
    #               DstMac:        Ŀ��Mac��ַ
    #               DstIP:         Ŀ��IP��ַ
    #               SrcMac:        ԴMac��ַ
    #               SrcIP:         ԴIP��ַ
    #               args: (��ѡ����,����±�)
    #                       -streamid       ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
    #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
    #                       -vlan           Vlan tag,����,Ĭ��0,����û��VLAN Tag,����0��ֵ�Ų���VLAN tag.
    #                       -pri            Vlan�����ȼ�����Χ0��7��ȱʡΪ0
    #                       -cfi            Vlan�������ֶΣ���Χ0��1��ȱʡΪ0
    #                       -type           ����ETHЭ�����ͣ�ȱʡֵ "08 00"
    #                       -ver            ����IP�汾��ȱʡֵ4
    #                       -iphlen         IP����ͷ���ȣ�ȱʡֵ5
    #                       -tos            IP���ķ������ͣ�ȱʡֵ0
    #                       -dscp           DSCP ֵ,ȱʡֵ0
    #                       -tot            IP���ɳ��ȣ�ȱʡֵ���ݱ��ĳ��ȼ���
    #                       -id             ���ı�ʶ�ţ�ȱʡֵ1
    #                       -mayfrag        �Ƿ�ɷ�Ƭ��־, 0:�ɷ�Ƭ, 1:����Ƭ
    #                       -lastfrag       ���Ƭ�������һƬ, 0: ���һƬ(ȱʡֵ), 1:�������һƬ
    #                       -fragoffset     ��Ƭ��ƫ������ȱʡֵ0
    #                       -ttl            ��������ʱ��ֵ��ȱʡֵ255
    #                       -pro            ����IPЭ�����ͣ�ȱʡֵ4
    #                       -change         �޸����ݰ��е�ָ���ֶΣ��˲�����ʶ�޸��ֶε��ֽ�ƫ����,Ĭ��ֵ,���һ���ֽ�(CRCǰ).
    #                       -value          �޸����ݵ�����, Ĭ��ֵ {{00 }}, 16���Ƶ�ֵ.
    #                       -enable         �Ƿ�ʹ��������Ч true / false
    #                       -sname          ������������,����Ϸ����ַ���.Ĭ��Ϊ""
    #                       -strtransmode   ���������͵�ģʽ,����0:�������� 1:������ָ������Ŀ��ֹͣ 2:�����걾���������������һ����.
    #                       -strframenum    ���屾�������͵İ���Ŀ
    #                       -strrate        ��������,���ٵİٷֱ�. 100 �������ٵ� 100%, 1 �������ٵ� 1%
    #                       -strburstnum    ���屾�����������ٸ�burst,ȡֵ��Χ1~65535,Ĭ��Ϊ1
    #
    #                       -igmpver        igmpЭ��汾��ȱʡֵ1
    #                       -igmptype       igmp�������ͣ�ȱʡֵ17,����ֵ�Ķ�������
    #                                       membershipQuery 17
    #                                       membershipReport1 18
    #                                       dvmrpMessage 19
    #                                       membershipReport2 22
    #                                       leaveGroup 23
    #                                       membershipReport3 34
    #
    #                       -rsvd           igmp��Ӧ�ȴ�ʱ��0~127����λ0.1��, ȱʡֵ0, 
    #                       -groupip        Ŀ���鲥��ַ��ȱʡֵΪ224.1.1.1�������������Ϊ "xx.xx.xx.xx"
    #
    #
    #                       -udf1           �Ƿ�ʹ��UDF1,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf1offset     UDFƫ����
    #                       -udf1len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf1initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf1step       UDF�仯����,Ĭ��1
    #                       -udf1changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf1repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf2           �Ƿ�ʹ��UDF2,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf2offset     UDFƫ����
    #                       -udf2len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf2initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf2step       UDF�仯����,Ĭ��1
    #                       -udf2changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf2repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf3           �Ƿ�ʹ��UDF3,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf3offset     UDFƫ����
    #                       -udf3len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf3initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf3step       UDF�仯����,Ĭ��1
    #                       -udf3changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf3repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf4           �Ƿ�ʹ��UDF4,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf4offset     UDFƫ����
    #                       -udf4len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf4initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf4step       UDF�仯����,Ĭ��1
    #                       -udf4changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf4repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf5           �Ƿ�ʹ��UDF5,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf5offset     UDFƫ����
    #                       -udf5len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf5initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf5step       UDF�仯����,Ĭ��1
    #                       -udf5changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf5repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ�1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 9:31:0
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbIgmpPacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP args} {
        set retVal     0

        if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP $args"] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]

        #��ŵ edit 2006��07-20 mac��ַת�� 
        set DstMac [StrMacConvertList $DstMac]
        set SrcMac [StrMacConvertList $SrcMac]
        
        #  Set the defaults
        set streamId   1
        set Sname      ""
        set Length     64
        set Vlan       0
        set Pri        0
        set Cfi        0
        set Type       "08 00"
        set Ver        4
        set Iphlen     5
        set Tos        0
        set Dscp       0
        set Tot        0
        set Id         1
        set Mayfrag    0
        set Lastfrag   0
        set Fragoffset 0
        set Ttl        255        
        set Pro        4
        set Change     0
        set Enable     true
        set Value      {{00 }}
        set Strtransmode 0
        set Strframenum  100
        set Strrate      100
        set Strburstnum  1
        
        set Igmpver     1
        set Igmptype    17
        set Rsvd        0
        set Groupip     "224.1.1.1"
            
        set Udf1       0
        set Udf1offset 0
        set Udf1len    1
        set Udf1initval {00}
        set Udf1step    1
        set Udf1changemode 0
        set Udf1repeat  1
        
        set Udf2       0
        set Udf2offset 0
        set Udf2len    1
        set Udf2initval {00}
        set Udf2step    1
        set Udf2changemode 0
        set Udf2repeat  1
        
        set Udf3       0
        set Udf3offset 0
        set Udf3len    1
        set Udf3initval {00}
        set Udf3step    1
        set Udf3changemode 0
        set Udf3repeat  1
        
        set Udf4       0
        set Udf4offset 0
        set Udf4len    1
        set Udf4initval {00}
        set Udf4step    1
        set Udf4changemode 0
        set Udf4repeat  1        
        
        set Udf5       0
        set Udf5offset 0
        set Udf5len    1
        set Udf5initval {00}
        set Udf5step    1
        set Udf5changemode 0
        set Udf5repeat  1
                
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -streamid   {set streamId $argx}
                -sname      {set Sname $argx}
                -length     {set Length $argx}
                -vlan       {set Vlan $argx}
                -pri        {set Pri $argx}
                -cfi        {set Cfi $argx}
                -type       {set Type $argx}
                -ver        {set Ver $argx}
                -iphlen     {set Iphlen $argx}
                -tos        {set Tos $argx}
                -dscp       {set Dscp $argx}
                -tot        {set Tot  $argx}
                -mayfrag    {set Mayfrag $argx}
                -lastfrag   {set Lastfrag $argx}
                -fragoffset {set Fragoffset $argx}
                -ttl        {set Ttl $argx}
                -id         {set Id $argx}
                -pro        {set Pro $argx}
                -change     {set Change $argx}
                -value      {set Value $argx}
                -enable     {set Enable $argx}
                -strtransmode { set Strtransmode $argx}
                -strframenum {set Strframenum $argx}
                -strrate     {set Strrate $argx}
                -strburstnum {set Strburstnum $argx}
                
                -igmpver    {set Igmpver $argx}
                -igmptype   {set Igmptype $argx}
                -rsvd       {set Rsvd $argx}
                -groupip    {set Groupip $argx}

                -udf1           {set Udf1 $argx}
                -udf1offset     {set Udf1offset $argx}
                -udf1len        {set Udf1len $argx}
                -udf1initval    {set Udf1initval $argx}  
                -udf1step       {set Udf1step $argx}
                -udf1changemode {set Udf1changemode $argx}
                -udf1repeat     {set Udf1repeat $argx}
                
                -udf2           {set Udf2 $argx}
                -udf2offset     {set Udf2offset $argx}
                -udf2len        {set Udf2len $argx}
                -udf2initval    {set Udf2initval $argx}  
                -udf2step       {set Udf2step $argx}
                -udf2changemode {set Udf2changemode $argx}
                -udf2repeat     {set Udf2repeat $argx}
                
                -udf3           {set Udf3 $argx}
                -udf3offset     {set Udf3offset $argx}
                -udf3len        {set Udf3len $argx}
                -udf3initval    {set Udf3initval $argx}  
                -udf3step       {set Udf3step $argx}
                -udf3changemode {set Udf3changemode $argx}
                -udf3repeat     {set Udf3repeat $argx}
                
                -udf4           {set Udf4 $argx}
                -udf4offset     {set Udf4offset $argx}
                -udf4len        {set Udf4len $argx}
                -udf4initval    {set Udf4initval $argx}  
                -udf4step       {set Udf4step $argx}
                -udf4changemode {set Udf4changemode $argx}
                -udf4repeat     {set Udf4repeat $argx}
                
                -udf5           {set Udf5 $argx}
                -udf5offset     {set Udf5offset $argx}
                -udf5len        {set Udf5len $argx}
                -udf5initval    {set Udf5initval $argx}  
                -udf5step       {set Udf5step $argx}
                -udf5changemode {set Udf5changemode $argx}
                -udf5repeat     {set Udf5repeat $argx}
             
                default {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }
            
        #Define Stream parameters.
        stream setDefault        
        stream config -enable $Enable
        stream config -name $Sname
        stream config -numBursts $Strburstnum        
        stream config -numFrames $Strframenum
        stream config -percentPacketRate $Strrate
        stream config -rateMode usePercentRate
        stream config -sa $SrcMac
        stream config -da $DstMac
        switch $Strtransmode {
            0 {stream config -dma contPacket}
            1 {stream config -dma stopStream}
            2 {stream config -dma advance}
            default {
                set retVal 1
                IxPuts -red "No such stream transmit mode, please check -strtransmode parameter."
                return $retVal
            }
        }
            
        if {$Length != 0} {
            #stream config -framesize $Length
            stream config -framesize [expr $Length + 4]
            stream config -frameSizeType sizeFixed
        } else {
            stream config -framesize 318
            stream config -frameSizeType sizeRandom
            stream config -frameSizeMIN 64
            stream config -frameSizeMAX 1518       
        }
            
           
        stream config -frameType $Type
            
        #Define protocol parameters 
        protocol setDefault        
        protocol config -name ipV4        
        protocol config -ethernetType ethernetII
        
       
        ip setDefault        
        ip config -ipProtocol ipV4ProtocolIgmp
        ip config -identifier   $Id
        #ip config -totalLength 46
        switch $Mayfrag {
            0 {ip config -fragment may}
            1 {ip config -fragment dont}
        }       
        switch $Lastfrag {
            0 {ip config -fragment last}
            1 {ip config -fragment more}
        }       

        ip config -fragmentOffset 1
        ip config -ttl $Ttl        
        ip config -sourceIpAddr $SrcIP
        ip config -destIpAddr   $DstIP
        if [ip set $Chas $Card $Port] {
            IxPuts -red "Unable to set IP configs to IxHal!"
            set retVal 1
        }
        #Dinfine IGMP protocol
           
         igmp setDefault        
         igmp config -type $Igmptype
         switch $Igmpver {
             1 {igmp config -version igmpVersion1}
             2 {igmp config -version igmpVersion2}
             3 {igmp config -version igmpVersion3}
             default {
                 set retVal 1
                 IxPuts -red "Error IGMP version input! check -igmptype parameter."
                 return $retVal
             }
         }
         igmp config -groupIpAddress  $Groupip
         igmp config -maxResponseTime $Rsvd
         if [igmp set $Chas $Card $Port] {
             IxPuts -red "Unable to set igmp configs to IxHal!"
             set retVal 1
         }
        
        
        if {$Vlan != 0} {
            protocol config -enable802dot1qTag vlanSingle
            vlan setDefault        
            vlan config -vlanID $Vlan
            vlan config -userPriority $Pri
            if [vlan set $Chas $Card $Port] {
                IxPuts -red "Unable to set Vlan configs to IxHal!"
                set retVal 1
            }
        }
        switch $Cfi {
            0 {vlan config -cfi resetCFI}
            1 {vlan config -cfi setCFI}
        }
            
        #UDF Config
            
        if {$Udf1 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf1offset
            switch $Udf1len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf1changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf1initval
            udf config -repeat  $Udf1repeat              
            udf config -step    $Udf1step
            udf set 1
        }
        if {$Udf2 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf2offset
            switch $Udf2len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf2changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf2initval
            udf config -repeat  $Udf2repeat              
            udf config -step    $Udf2step
            udf set 2
        }
        if {$Udf3 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf3offset
            switch $Udf3len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf3changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf3initval
            udf config -repeat  $Udf3repeat              
            udf config -step    $Udf3step
            udf set 3
        }
        if {$Udf4 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf4offset
            switch $Udf4len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf4changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf4initval
            udf config -repeat  $Udf4repeat              
            udf config -step    $Udf4step
            udf set 4
        }
        if {$Udf5 == 1} {
                udf setDefault        
                udf config -enable true
                udf config -offset $Udf5offset
                switch $Udf5len {
                    1 { udf config -countertype c8  }                
                    2 { udf config -countertype c16 }               
                    3 { udf config -countertype c24 }                
                    4 { udf config -countertype c32 }
                }
                switch $Udf5changemode {
                    0 {udf config -updown uuuu}
                    1 {udf config -updown dddd}
                }
                udf config -initval $Udf5initval
                udf config -repeat  $Udf5repeat              
                udf config -step    $Udf5step
                udf set 5
        }        
            
            
        #Table UDF Config        
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        if {$Change == 0} {
            tableUdfColumn config -offset [expr $Length -5]} else {
            tableUdfColumn config -offset $Change
        }
        tableUdfColumn config -size 1
        tableUdf addColumn         
        set rowValueList $Value
        tableUdf addRow $rowValueList
        if [tableUdf set $Chas $Card $Port] {
            IxPuts -red "Unable to set TableUdf to IxHal!"
            set retVal 1
        }

        #Final writting....        
        if [stream set $Chas $Card $Port $streamId] {
            IxPuts -red "Unable to set streams to IxHal!"
            set retVal 1
        }
        
        incr streamId
        lappend portList [list $Chas $Card $Port]
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            set retVal 1
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbInputToStopTx
    #�� �� ����     IXIA
    #�������     
    #����������     ����ʼ�ռ�����������,һ�����յ����û�ָ�����ַ���,��ֹͣ�˿ڵķ���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:      Ixia��hub��
    #               Card:      Ixia�ӿڿ����ڵĲۺ�
    #               Port:      Ixia�ӿڿ��Ķ˿ں�       
    #               input:    �û�ָ�������봮,һ���ڲ��ԵĹ������û�������������ûس�,�˿ھ�ֹͣ����!
    #                         ������ʽ: "1"
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 11:8:39
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbInputToStopTx {Chas Card Port input} {   
        set retVal 0
        set RunFlag 1
        while {$RunFlag} {
            IxPuts -blue "�����Ҫֹͣ$Chas $Card $Port����,�������ַ���$input ���ûس�"
            gets stdin k
            if {$k == $input} {
                IxPuts -blue "�Ѿ����յ�ֹͣ��������,����ֹͣ�˿�$Chas $Card $Port����!"
                set RunFlag 0
                if [ixStopPortTransmit $Chas $Card $Port] {
                    IxPuts -red "Can't Stop $Chas $Card $Port port transmit."
                    set retVal 1
                }
            } else {
                IxPuts -red "��������ַ�����ֹͣ�ַ���,����,ע���дС!"
            }
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbIpPacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     IP������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�    
    #               DstMac:        Ŀ��Mac��ַ
    #               DstIP:         Ŀ��IP��ַ
    #               SrcMac:        ԴMac��ַ
    #               SrcIP:         ԴIP��ַ
    #               args: (��ѡ����,����±�)
    #                       -streamid       ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
    #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
    #                       -vlan           Vlan tag,����,Ĭ��0,����û��VLAN Tag,����0��ֵ�Ų���VLAN tag.
    #                       -pri            Vlan�����ȼ�����Χ0��7��ȱʡΪ0
    #                       -cfi            Vlan�������ֶΣ���Χ0��1��ȱʡΪ0
    #                       -type           ����ETHЭ�����ͣ�ȱʡֵ "08 00"
    #                       -ver            ����IP�汾��ȱʡֵ4
    #                       -iphlen         IP����ͷ���ȣ�ȱʡֵ5
    #                       -tos            IP���ķ������ͣ�ȱʡֵ0
    #                       -dscp           DSCP ֵ,ȱʡֵ0
    #                       -tot            IP���ɳ��ȣ�ȱʡֵ���ݱ��ĳ��ȼ���
    #                       -id             ���ı�ʶ�ţ�ȱʡֵ1
    #                       -mayfrag        �Ƿ�ɷ�Ƭ��־, 0:�ɷ�Ƭ, 1:����Ƭ
    #                       -lastfrag       ���Ƭ�������һƬ, 0: ���һƬ(ȱʡֵ), 1:�������һƬ
    #                       -fragoffset     ��Ƭ��ƫ������ȱʡֵ0
    #                       -ttl            ��������ʱ��ֵ��ȱʡֵ255
    #                       -pro            ����IPЭ�����ͣ�ȱʡֵ4
    #                       -change         �޸����ݰ��е�ָ���ֶΣ��˲�����ʶ�޸��ֶε��ֽ�ƫ����,Ĭ��ֵ,���һ���ֽ�(CRCǰ).
    #                       -value          �޸����ݵ�����, Ĭ��ֵ {{00 }}, 16���Ƶ�ֵ.
    #                       -enable         �Ƿ�ʹ��������Ч true / false
    #                       -sname          ������������,����Ϸ����ַ���.Ĭ��Ϊ""
    #                       -strtransmode   ���������͵�ģʽ,����0:�������� 1:������ָ������Ŀ��ֹͣ 2:�����걾���������������һ����.
    #                       -strframenum    ���屾�������͵İ���Ŀ
    #                       -strrate        ��������,���ٵİٷֱ�. 100 �������ٵ� 100%, 1 �������ٵ� 1%
    #                       -strburstnum    ���屾�����������ٸ�burst,ȡֵ��Χ1~65535,Ĭ��Ϊ1
    #
    #
    #                       -udf1           �Ƿ�ʹ��UDF1,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf1offset     UDFƫ����
    #                       -udf1len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf1initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf1step       UDF�仯����,Ĭ��1
    #                       -udf1changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf1repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf2           �Ƿ�ʹ��UDF2,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf2offset     UDFƫ����
    #                       -udf2len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf2initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf2step       UDF�仯����,Ĭ��1
    #                       -udf2changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf2repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf3           �Ƿ�ʹ��UDF3,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf3offset     UDFƫ����
    #                       -udf3len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf3initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf3step       UDF�仯����,Ĭ��1
    #                       -udf3changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf3repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf4           �Ƿ�ʹ��UDF4,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf4offset     UDFƫ����
    #                       -udf4len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf4initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf4step       UDF�仯����,Ĭ��1
    #                       -udf4changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf4repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf5           �Ƿ�ʹ��UDF5,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf5offset     UDFƫ����
    #                       -udf5len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf5initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf5step       UDF�仯����,Ĭ��1
    #                       -udf5changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf5repeat     UDF����/�ݼ��Ĵ���, 1~n ����

    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 21:7:34
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbIpPacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP args} {   
        set retVal     0

        if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP $args"] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]

        #��ŵ edit 2006��07-21 mac��ַת�� 
        set DstMac [StrMacConvertList $DstMac]
        set SrcMac [StrMacConvertList $SrcMac]
        
        #  Set the defaults
        set streamId   1
        set Sname      ""
        set Length     64
        set Vlan       0
        set Pri        0
        set Cfi        0
        set Type       "08 00"
        set Ver        4
        set Iphlen     5
        set Tos        0
        set Dscp       0
        set Tot        0
        set Id         1
        set Mayfrag    0
        set Lastfrag   0
        set Fragoffset 0
        set Ttl        255        
        set Pro        4
        set Change     0
        set Enable     true
        set Value      {{00 }}
        set Strtransmode 0
        set Strframenum    100
        set Strrate    100
        set Strburstnum  1
        
        set Udf1       0
        set Udf1offset 0
        set Udf1len    1
        set Udf1initval {00}
        set Udf1step    1
        set Udf1changemode 0
        set Udf1repeat  1
        
        set Udf2       0
        set Udf2offset 0
        set Udf2len    1
        set Udf2initval {00}
        set Udf2step    1
        set Udf2changemode 0
        set Udf2repeat  1
            
        set Udf3       0
        set Udf3offset 0
        set Udf3len    1
        set Udf3initval {00}
        set Udf3step    1
        set Udf3changemode 0
        set Udf3repeat  1
            
        set Udf4       0
        set Udf4offset 0
        set Udf4len    1
        set Udf4initval {00}
        set Udf4step    1
        set Udf4changemode 0
        set Udf4repeat  1        
        
        set Udf5       0
        set Udf5offset 0
        set Udf5len    1
        set Udf5initval {00}
        set Udf5step    1
        set Udf5changemode 0
        set Udf5repeat  1
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -streamid   {set streamId $argx}
                -sname      {set Sname $argx}
                -length     {set Length $argx}
                -vlan       {set Vlan $argx}
                -pri        {set Pri $argx}
                -cfi        {set Cfi $argx}
                -type       {set Type $argx}
                -ver        {set Ver $argx}
                -iphlen     {set Iphlen $argx}
                -tos        {set Tos $argx}
                -dscp       {set Dscp $argx}
                -tot        {set Tot  $argx}
                -mayfrag    {set Mayfrag $argx}
                -lastfrag   {set Lastfrag $argx}
                -fragoffset {set Fragoffset $argx}
                -ttl        {set Ttl $argx}
                -id         {set Id $argx}
                -pro        {set Pro $argx}
                -change     {set Change $argx}
                -value      {set Value $argx}
                -enable     {set Enable $argx}
                -strtransmode { set Strtransmode $argx}
                -strframenum {set Strframenum $argx}
                -strrate     {set Strrate $argx}
                -strburstnum {set Strburstnum $argx}
                
                -udf1           {set Udf1 $argx}
                -udf1offset     {set Udf1offset $argx}
                -udf1len        {set Udf1len $argx}
                -udf1initval    {set Udf1initval $argx}  
                -udf1step       {set Udf1step $argx}
                -udf1changemode {set Udf1changemode $argx}
                -udf1repeat     {set Udf1repeat $argx}
                
                -udf2           {set Udf2 $argx}
                -udf2offset     {set Udf2offset $argx}
                -udf2len        {set Udf2len $argx}
                -udf2initval    {set Udf2initval $argx}  
                -udf2step       {set Udf2step $argx}
                -udf2changemode {set Udf2changemode $argx}
                -udf2repeat     {set Udf2repeat $argx}
                
                -udf3           {set Udf3 $argx}
                -udf3offset     {set Udf3offset $argx}
                -udf3len        {set Udf3len $argx}
                -udf3initval    {set Udf3initval $argx}  
                -udf3step       {set Udf3step $argx}
                -udf3changemode {set Udf3changemode $argx}
                -udf3repeat     {set Udf3repeat $argx}
                
                -udf4           {set Udf4 $argx}
                -udf4offset     {set Udf4offset $argx}
                -udf4len        {set Udf4len $argx}
                -udf4initval    {set Udf4initval $argx}  
                -udf4step       {set Udf4step $argx}
                -udf4changemode {set Udf4changemode $argx}
                -udf4repeat     {set Udf4repeat $argx}
                
                -udf5           {set Udf5 $argx}
                -udf5offset     {set Udf5offset $argx}
                -udf5len        {set Udf5len $argx}
                -udf5initval    {set Udf5initval $argx}  
                -udf5step       {set Udf5step $argx}
                -udf5changemode {set Udf5changemode $argx}
                -udf5repeat     {set Udf5repeat $argx}
                         
                default     {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }
            
        #Define Stream parameters.
        stream setDefault        
        stream config -enable $Enable
        stream config -name $Sname
        stream config -numBursts $Strburstnum        
        stream config -numFrames $Strframenum
        stream config -percentPacketRate $Strrate
        stream config -rateMode usePercentRate
        stream config -sa $SrcMac
        stream config -da $DstMac
        puts "stream transmode:$Strtransmode"
        switch $Strtransmode {
            0 {stream config -dma contPacket}
            1 {stream config -dma stopStream}
            2 {
            		#modified by Eric Yu
            		#stream config -dma advance
            		stream config -dma contBurst
            }
            default {
                set retVal 1
                IxPuts -red "No such stream transmit mode, please check -strtransmode parameter."
                return $retVal
            }
        }
            
        if {$Length != 0} {
            #stream config -framesize $Length
            stream config -framesize [expr $Length + 4]
            stream config -frameSizeType sizeFixed
        } else {
            stream config -framesize 318
            stream config -frameSizeType sizeRandom
            stream config -frameSizeMIN 64
            stream config -frameSizeMAX 1518       
        }
           
        stream config -frameType $Type
            
        #Define protocol parameters 
        protocol setDefault        
        protocol config -name ipV4
        protocol config -ethernetType ethernetII
        
        ip setDefault        
        ip config -ipProtocol   $Pro
        ip config -identifier   $Id

        #ip config -totalLength 46
        switch $Mayfrag {
            0 {ip config -fragment may}
            1 {ip config -fragment dont}
        }       
        switch $Lastfrag {
            0 {ip config -fragment last}
            1 {ip config -fragment more}
        }       

        ip config -fragmentOffset 1
        ip config -ttl $Ttl        
        ip config -sourceIpAddr $SrcIP
        ip config -destIpAddr   $DstIP
        if [ip set $Chas $Card $Port] {
            IxPuts -red "Unable to set IP configs to IxHal!"
            set retVal 1
        }
            
        if {$Vlan != 0} {
            protocol config -enable802dot1qTag vlanSingle
            vlan setDefault        
            vlan config -vlanID $Vlan
            vlan config -userPriority $Pri
            if [vlan set $Chas $Card $Port] {
                IxPuts -red "Unable to set Vlan configs to IxHal!"
                set retVal 1
            }
        }
        switch $Cfi {
            0 {vlan config -cfi resetCFI}
            1 {vlan config -cfi setCFI}
        }
            
        #UDF Config
            
        if {$Udf1 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf1offset
            switch $Udf1len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf1changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf1initval
            udf config -repeat  $Udf1repeat              
            udf config -step    $Udf1step
            udf set 1
        }
        if {$Udf2 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf2offset
            switch $Udf2len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf2changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf2initval
            udf config -repeat  $Udf2repeat              
            udf config -step    $Udf2step
            udf set 2
        }
        if {$Udf3 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf3offset
            switch $Udf3len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf3changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf3initval
            udf config -repeat  $Udf3repeat              
            udf config -step    $Udf3step
            udf set 3
        }
        if {$Udf4 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf4offset
            switch $Udf4len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf4changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf4initval
            udf config -repeat  $Udf4repeat              
            udf config -step    $Udf4step
            udf set 4
        }
        if {$Udf5 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf5offset
            switch $Udf5len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf5changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf5initval
            udf config -repeat  $Udf5repeat              
            udf config -step    $Udf5step
            udf set 5
        }        
            
            
        #Table UDF Config        
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        if {$Change == 0} {
            tableUdfColumn config -offset [expr $Length -5]} else {
            tableUdfColumn config -offset $Change
        }
        tableUdfColumn config -size 1
        tableUdf addColumn         
        set rowValueList $Value
        tableUdf addRow $rowValueList
        if [tableUdf set $Chas $Card $Port] {
            IxPuts -red "Unable to set TableUdf to IxHal!"
            set retVal 1
        }

        #Final writting....        
        if [stream set $Chas $Card $Port $streamId] {
            IxPuts -red "Unable to set streams to IxHal!"
            set retVal 1
        }
        
        incr streamId
        lappend portList [list $Chas $Card $Port]
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            set retVal 1
        }
        return $retVal       
    }

    #!!================================================================
    #�� �� ����     SmbListPktSet
    #�� �� ����     IXIA
    #�������     
    #����������     �û������б�{1 2 3 4 5 6 7 8 9 10 11 13....},
    #               �����������б�������һ����.�������ݾ���ȫ��������б�������.�б�ĳ��Ⱦ��ǰ��ĳ���.
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:         Ixia��hub��
    #               Card:         Ixia�ӿڿ����ڵĲۺ�
    #               Port:         Ixia�ӿڿ��Ķ˿ں�    
    #               lcon:  �������б�,����10���Ƶ�ֵ����,������ʽ����:
    #                      {1 2 3 4 5 6 7 8 9 10 11 13}  
    #               args:  -streamid  �����,Ĭ��Ϊ1 
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 11:35:48
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbListPktSet {Chas Card Port lcon} {
        set retVal 0
        set Streamid 1
        
        set Pktlen [llength $lcon]
        for {set i 0} {$i< $Pktlen} {incr i} {
            set k [format "%02x" [lindex $lcon $i]]
            lappend TempList $k
        }
        lappend lsList $TempList
            
        stream setDefault        
        stream config -name "CustomStream"
        stream config -dma advance
        #stream config -framesize $Pktlen
        stream config -framesize [expr $Pktlen + 4]
        stream config -frameSizeType sizeFixed
        protocol setDefault                
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        tableUdfColumn config -offset 0
        tableUdfColumn config -size $Pktlen
        tableUdf addColumn         
        set rowValueList $lsList
        tableUdf addRow $rowValueList
        if [tableUdf set $Chas $Card $Port] {
            IxPuts -red "Can't set tableUdf"
            set retVal 1
        }
        if [stream set $Chas $Card $Port $Streamid] {
            IxPuts -red "Can't set Stream"
            set retVal 1
        }
        stream set $Chas $Card $Port $Streamid
        lappend portList "$Chas $Card $Port"
        if [ixWriteConfigToHardware portList -noProtocolServer] {
            IxPuts -red  "Can't write config to port"
            set retVal 1
        }
        return $retVal
    }


    #!!================================================================
    #�� �� ����     SmbLogPortCountsShow
    #�� �� ����     IXIA
    #�������     
    #����������     ��ӡ���˿��հ����ͷ�����������ֵ
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:         Ixia��hub��
    #               Card:         Ixia�ӿڿ����ڵĲۺ�
    #               Port:         Ixia�ӿڿ��Ķ˿ں�    
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 19:13:29
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbLogPortCountsShow {Chas Card Port } {    
        set retVal 0
        if [stat get statAllStats $Chas $Card $Port] {
            IxPuts -red "Get all Event counters Error"
            set retVal 1
        }
        set Tx [stat cget -framesSent]
        set Rx [stat cget -framesReceived]
        #IxPuts -blue "Transmitted: $Tx frames"
        #IxPuts -blue "Received: $Rx frames"   
        return $retVal           
    }
    
    #!!================================================================
    #�� �� ����     SmbMetricModeSet
    #�� �� ����     IXIA
    #�������     
    #����������     ������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:      Ixia��hub��
    #               Card:      Ixia�ӿڿ����ڵĲۺ�
    #               Port:      Ixia�ӿڿ��Ķ˿ں�      
    #               args: (��ѡ����,����±�)
    #                       -dstmac     Ŀ��MAC, Ĭ��ֵΪ "00 00 00 00 00 00"
    #                       -dstip      Ŀ��IP��ַ, Ĭ��ֵΪ "1.1.1.1"
    #                       -srcmac     ԴMAC, Ĭ��ֵΪ "00 00 00 00 00 01"
    #                       -srcip      ԴIP��ַ, Ĭ��ֵΪ "3.3.3.3"
    #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
    #                       -type           custom / IP / TCP / UDP / ipx / ipv6,Ĭ��ΪCUSTOM���Զ����� 
    #                       -vlan           Vlan tag,����,Ĭ��0,����û��VLAN Tag,����0��ֵ�Ų���VLAN tag.
    #                       -data       ��CUSTOMģʽ����Ч. ָ����������, ��ָ��ʱʹ���������,������ʽ "FF 01 11 ..."
    #                       -vfd1           VFD1��ı仯״̬, Ĭ��ΪOffState; ����֧�����¼���ֵ;:
    #                                       OffState �ر�״̬
    #                                       StaticState �̶�״̬
    #                                       IncreState ����״̬
    #                                       DecreState �ݼ�״̬
    #                                       RandomState ���״̬
    #                       -vfd1cycle  VFD1ѭ���仯������ȱʡ����²�ѭ���������仯
    #                       -vfd1step   VFD1��仯����
    #                       -vfd1offset     VFD1�仯��ƫ����
    #                       -vfd1start      VFD1�仯����ʼֵ������0x��ʮ��������,,������ʽΪ {01 0f 0d 13},�4���ֽ�,���1���ֽ�,ע��ֻ��1λ��ǰ�油0,��1Ҫд��01.
    #                       -vfd1len        VFD1�仯����,�4���ֽ�,���1���ֽ�
    #                       -vfd2           VFD2��ı仯״̬, Ĭ��ΪOffState; ����֧�����¼���ֵ;:
    #                                       OffState �ر�״̬
    #                                       StaticState �̶�״̬
    #                                       IncreState ����״̬
    #                                       DecreState �ݼ�״̬
    #                                       RandomState ���״̬
    #                       -vfd2cycle  VFD2ѭ���仯������ȱʡ����²�ѭ���������仯
    #                       -vfd2step   VFD2��仯����
    #                       -vfd2offset     VFD2�仯��ƫ����
    #                       -vfd2start      VFD2�仯����ʼֵ������0x��ʮ��������,������ʽΪ {01 0f 0d 13},�4���ֽ�,���1���ֽ�.ע��ֻ��1λ��ǰ�油0,��1Ҫд��01   
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 10:11:30
    #�޸ļ�¼��     modify by chenshibing 64165 2009-05-19 �޸����ķ���ģʽ��ʹ���������Լ�����ͱ���(��ԭ����ÿ����contPacketģʽ��Ϊ���һ��return to idģʽ������advanceģʽ)
    #               modify by chenshibing 64165 2009-05-20 �޸�ÿ������packet per burst����1���������ٶȽ�����ʱ��Ͳ���ģ���������������ĵ�����
    #               modify by chenshibing 64165 2009-05-27 ����customģʽ�µ�data�����·�,ʹ���ܹ���ȷ���·�
    #!!================================================================
    proc SmbMetricModeSet {Chas Card Port args} {
        set retVal     0

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        #  Set the defaults
        set Dstmac     "00 00 00 00 00 00"
        set Srcmac     "00 00 00 00 00 01"
        set Dstip      "1.1.1.1"
        set Srcip      "3.3.3.3"
        set Clear      0
        set Length     0
        set Type       custom
        set Vlan       0
        set Data       ""
        set Vfd1       OffState
        set Vfd1cycle  1
        set Vfd1step   1
        set Vfd1offset 12
        set Vfd1start  {00}
        set Vfd1len    4
        set Vfd2       OffState
        set Vfd2cycle  1
        set Vfd2step   1
        set Vfd2offset 12
        set Vfd2start  {00}
        set Vfd2len    4      
        set metricflag    0 ; #�Ƿ�Ϊ��һ����
        set rate 100
        set flag 0
        
        set Strtransmode 0
        set Strframenum    1
        set Strrate    0
        set Strburstnum  1
        set Bps 0
        set Pps 0
        set crc 0        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]

            if { $cmdx == "-clear"} {
                set  Clear 1
                break
            } 
    
            case $cmdx      {
            	  -length				  {set Length $argx}
                -dstmac         {set Dstmac $argx; set Dstmac [StrMacConvertList $Dstmac]}
                -srcmac         {set Srcmac $argx; set Srcmac [StrMacConvertList $Srcmac]}
                -dstip          {set Dstip  $argx}
                -srcip          {set Srcip  $argx}
                -type           {set Type   $argx;if {[string tolower $Type] == "ipv6"} {set Dstip [IxStrIpV6AddressConvert $Dstip];set Srcip [IxStrIpV6AddressConvert $Srcip]}}
                -vlan           {set Vlan   $argx}
                -data           {set Data   $argx}
                -vfd1           {set Vfd1   $argx}
                -vfd1cycle      {set Vfd1cycle $argx}
                -vfd1step       {set Vfd1step $argx}
                -vfd1offset     {set Vfd1offset $argx}
                -vfd1start      {
			set Vfd1start $argx; 
			# Edit by Eric Yu 2012.6.7
			#set Vfd1start [StrIpConvertList $Vfd1start]
			set Vfd1start [string map {. " "} $Vfd1start]
                }
                -vfd2           {set Vfd2   $argx}
                -vfd2cycle      {set Vfd2cycle $argx}
                -vfd2step       {set Vfd2step $argx}
                -vfd2offset     {set Vfd2offset $argx}
                -vfd2start      {
			set Vfd2start $argx; 
			# Edit by Eric Yu 2012.6.7
			#set Vfd2start [StrIpConvertList $Vfd2start];
			set Vfd2start [string map {. " "} $Vfd2start]
                }
                -vfd1length     {set Vfd1len $argx}
                -vfd2length     {set Vfd2len $argx}
                -strtransmode 	{ set Strtransmode $argx; set flag 1}
                -strframenum 		{set Strframenum $argx}
                -strrate -
                -rate    				{set Strrate $argx}
                -strburstnum {set Strburstnum $argx}
                -pps         {set Pps $argx}
                -bps         {set Bps $argx}
                -error {set crc 1}
                default     {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }

        #����No���д���
        if { [array exists ::ArrMetricCount] != 1 } {
            #���鲻����
            set metricflag 1
        } else {
            ##�������, ���ö˿�û�д�����
            if { [array get ::ArrMetricCount $Chas,$Card,$Port] == ""} {
                set metricflag 1
            } else {
                #�ö˿��Ѿ���������
                set ::ArrMetricCount($Chas,$Card,$Port) [expr $::ArrMetricCount($Chas,$Card,$Port) + 1]
            }
        }

        if  { $metricflag == 1 } {
            #���������
            array set ::ArrMetricCount {}
            set ::ArrMetricCount($Chas,$Card,$Port) 1
        } else {
        	#commented by Eric Yu to fix the bug for changing the mode of every stream
            # add by chenshibing 2009-05-19 ��ǰ��һ������ģʽ��Ϊadvanceģʽ
            if {$flag == 0} {
	            set lastStreamId [expr $::ArrMetricCount($Chas,$Card,$Port) - 1]
	            if {![stream get $Chas $Card $Port $lastStreamId]} {
	                stream config -dma advance
	                if [stream set $Chas $Card $Port $lastStreamId] {
	                    IxPuts -red "Error setting stream on port $Chas $Card $Port $lastStreamId"
	                    set retVal 1
	                }
	                lappend tmpPortList [list $Chas $Card $Port]
	                if [ixWriteConfigToHardware tmpPortList -noProtocolServer ] {
	                    IxPuts -red "Unable to write configs to hardware!"
	                    set retVal 1
	                }
	            }
	            # gotoFirst
	            set Strtransmode 4
            }
            # add end
        }
        set Streamid $::ArrMetricCount($Chas,$Card,$Port)
                
        if {$Clear == 1} {
            SmbPortClearStream $Chas $Card $Port
            #port write $Chas $Card $Port
            catch {unset ::ArrMetricCount} err
        } else {
            #Define Stream parameters.
            stream setDefault        
            stream config -name $Type\_Stream


            stream config -numBursts $Strburstnum        
        		stream config -numFrames $Strframenum
        	
        	#�û�û���������������
			if {($Pps == 0) && ($Strrate == 0) && ($Bps == 0)} {
			    stream config -rateMode usePercentRate
			    stream config -percentPacketRate 100    
			}
						        
			if { $Strrate != 0 } {
				#�û�ѡ���԰ٷֱ���������
			    stream config -rateMode usePercentRate
			    stream config -percentPacketRate $Strrate
			} elseif { ($Pps != 0) && ($Strrate == 0) } {
				#�û�ѡ����ppsΪ��λ�����
				stream config -rateMode streamRateModeFps
			    stream config -fpsRate $Pps
			} elseif { ($Bps != 0) && ($Strrate == 0) && ($Pps == 0) } {
				#�û�ѡ����bpsΪ��λ�����
				stream config -rateMode streamRateModeBps
			    stream config -bpsRate $Bps
			}
            
            stream config -sa $Srcmac
            stream config -da $Dstmac


            switch $Strtransmode {
	            0 {stream config -dma contPacket}
	            1 {stream config -dma contBurst}
	            2 {
	            	#stream config -dma stopStream
	            	stream config -dma 2
	            }
	            3 {stream config -dma advance}
	            4 {stream config -dma gotoFirst}
	            5 {stream config -dma firstLoopCount}
	            default {
	                set retVal 1
	                IxPuts -red "No such stream transmit mode, please check -strtransmode parameter."
	                return $retVal
	            }
        		}	
        
            # modify end
            
            if {$Length != 0} {
                #stream config -framesize $Length
                stream config -framesize [expr $Length + 4]
                stream config -frameSizeType sizeFixed
            } else {
                stream config -framesize 318
                stream config -frameSizeType sizeRandom
                stream config -frameSizeMIN 64
                stream config -frameSizeMAX 1518       
            }               
            
            if {$crc == 1} {
                stream config -fcs 3
                puts "stream config -fcs 3"
            } else {
                stream config -fcs 0
                puts "stream config -fcs 0"
            }
            switch $Type {
                custom {
                    if {$Data == ""} {
                        stream config -patternType patternTypeRandom
                        stream config -dataPattern allOnes
                        stream config -pattern "FF FF"
                        stream config -frameType "86 DD"        
                    } else {
                        set ls {}
                        foreach sub $Data {
                            lappend ls  [format %02x $sub]
                        }

                        if { [llength $ls] >= 12} {
                            stream config -da [lrange $ls 0 5]
                            stream config -sa [lrange $ls 6 11]
                        } elseif { [llength $ls] > 6 } {
                            stream config -da [lrange $ls 0 5]
                            for {set i 0} {$i < [llength $ls] - 7} {incr i} {
                                set Dstmac [lreplace $Dstmac $i $i [lindex $ls $i]]
                            }
                            stream config -sa $Dstmac
                        } else {
                            for {set i 0} { $i < [llength $ls]} {incr i} {
                                set Srcmac [lreplace $Srcmac $i $i [lindex $ls $i]]
                            }
                            stream config -da $Srcmac
                        }
                        
                        stream config -patternType repeat
                        stream config -dataPattern userpattern
                        stream config -frameType "86 DD"
                        if { [llength $ls] >= 12 } {
                            # modify by chenshibing 2009-05-27
                            # stream config -pattern $Data
                            stream config -pattern [lrange $ls 12 end]
                            # modify end
                        } 
                    }
                }
                IP {
                    protocol setDefault        
                    protocol config -name ipV4
                    protocol config -ethernetType ethernetII
                    ip setDefault  
                    ip config -sourceIpAddr $Srcip
                    ip config -destIpAddr   $Dstip
                    if [ip set $Chas $Card $Port] {
                        IxPuts -red "Unable to set IP configs to IxHal!"
                        set retVal 1
                    }
                }
                TCP {
                    protocol setDefault        
                    protocol config -name ipV4
                    protocol config -ethernetType ethernetII
                    
                    ip setDefault
                    ip config -ipProtocol ipV4ProtocolTcp
                    ip config -sourceIpAddr $Srcip
                    ip config -destIpAddr $Dstip
                    if [ip set $Chas $Card $Port] {
                        IxPuts -red "Unable to set IP configs to IxHal!"
                        set retVal 1
                    }
                    tcp setDefault        
                    if [tcp set $Chas $Card $Port] {
                        IxPuts -red "Unable to set TCP configs to IxHal!"
                        set retVal 1
                    }                    
                }
                UDP {
                    protocol setDefault        
                    protocol config -name ipV4
                    protocol config -ethernetType ethernetII
                    
                    ip setDefault
                    ip config -ipProtocol ipV4ProtocolUdp
                    ip config -sourceIpAddr $Srcip
                    ip config -destIpAddr $Dstip
                    if [ip set $Chas $Card $Port] {
                        IxPuts -red "Unable to set IP configs to IxHal!"
                        set retVal 1
                    }   
                    udp setDefault        
                    if [udp set $Chas $Card $Port] {
                        IxPuts -red "Unable to set UDP configs to IxHal!"
                        set retVal 1
                    }                     
                }
                ipx {
                    protocol setDefault        
                    protocol config -name ipx
                    protocol config -ethernetType ethernetII
                    ipx setDefault        
                    if [ipx set $Chas $Card $Port] {
                        IxPuts -red "Unable to set ipx configs to IxHal!"
                        set retVal 1
                    }
                    if {$Vlan == 1} {
                        protocol config -enable802dot1qTag vlanSingle
                        vlan setDefault        
                        vlan config -vlanID $Vlan
                        if [vlan set $Chas $Card $Port] {
                            IxPuts -red "Unable to set Vlan configs to IxHal!"
                            set retVal 1
                        }
                    }                        
                }
                ipv6 {
                    protocol setDefault        
                    protocol config -name ipV6
                    protocol config -ethernetType ethernetII
                    ipV6 setDefault 
                    ipV6 config -sourceAddr $Srcip
                    ipV6 config -destAddr $Dstip
                    if [ipV6 set $Chas $Card $Port] {
                        IxPuts -red "Unable to set ipV6 configs to IxHal!"
                        set retVal 1
                    }                     
                }
                default {
                    set retVal 1
                    IxPuts -red "No Such Type, please check input -type parameter!"
                    return $retVal
                }
            } 
                
            if {$Vlan == 1} {
                protocol config -enable802dot1qTag vlanSingle
                vlan setDefault        
                vlan config -vlanID $Vlan
                if [vlan set $Chas $Card $Port] {
                    IxPuts -red "Unable to set Vlan configs to IxHal!"
                    set retVal 1
                }
            }           
            #UDF1 config
            if {$Vfd1 != "OffState"} {
                udf setDefault        
                udf config -enable true
                switch $Vfd1 {
                    "RandomState" {
                         udf config -counterMode udfRandomMode
                     }
                     "StaticState" -
                     "IncreState"  -
                     "DecreState" {
                         udf config -counterMode udfCounterMode        
                     }
                        
                }
                set Vfd2len [llength $Vfd2start]
                if  { $Vfd1len > 4} {
                    set Vfd1len 4
                } 
                switch $Vfd1len  {
                    1 { udf config -countertype c8  }                
                    2 { udf config -countertype c16 }               
                    3 { udf config -countertype c24 }                
                    4 { udf config -countertype c32 }
                    default {
                        set retVal 1
                        IxPuts -red "-vfd2start only support 1-4 bytes, for example: {11 11 11 11}"
                        return $retVal
                    }
                }
                switch $Vfd1 {
                    "IncreState" {udf config -updown uuuu}
                    "DecreState" {udf config -updown dddd}
                }
                udf config -offset  $Vfd1offset
                udf config -initval $Vfd1start
		udf config -continuousCount false
                udf config -repeat  $Vfd1cycle              
                udf config -step    $Vfd1step
                udf set 1
            } elseif {$Vfd1 == "OffState"} {
                udf setDefault        
                udf config -enable false
                udf set 2
            }
                
            #UDF2 config
            if {$Vfd2 != "OffState"} {
                udf setDefault        
                udf config -enable true
                switch $Vfd2 {
                    "RandomState" {
                         udf config -counterMode udfRandomMode
                     }
                     "StaticState" -
                     "IncreState"  -
                     "DecreState" {
                         udf config -counterMode udfCounterMode        
                     }         
                }
                set Vfd2len [llength $Vfd2start]
                switch $Vfd2len  {
                    1 { udf config -countertype c8  }                
                    2 { udf config -countertype c16 }               
                    3 { udf config -countertype c24 }                
                    4 { udf config -countertype c32 }
                    default {
                        set retVal
                        IxPuts -red "-vfd2start only support 1-4 bytes, for example: {11 11 11 11}"
                        return $retVal
                    }
                }
                switch $Vfd2 {
                    "IncreState" {udf config -updown uuuu}
                    "DecreState" {udf config -updown dddd}
                }
                udf config -offset  $Vfd2offset
                udf config -initval $Vfd2start
                udf config -repeat  $Vfd2cycle              
                udf config -step    $Vfd2step
                udf set 2
            } elseif {$Vfd2 == "OffState"} {
                udf setDefault        
                udf config -enable false
                udf set 2
            }
            #Final writting....        
IxPuts -red "Set stream to $Streamid."
	    set applyStrResult [stream set $Chas $Card $Port $Streamid]
            if { $applyStrResult } {
IxPuts -red $applyStrResult
                IxPuts -red "Unable to set streams to IxHal! Error code: $applyStrResult"
                set retVal 1
            }
        
            
            
        } ;#end else 
        
        lappend portList [list $Chas $Card $Port]
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            set retVal 1
        }
        return $retVal          
    }

    #!!================================================================
    #�� �� ����     SmbMplsPacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     ����MPLS��
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:      Ixia��hub��
    #               Card:      Ixia�ӿڿ����ڵĲۺ�
    #               Port:      Ixia�ӿڿ��Ķ˿ں�      
    #               strMplsDstMac:   MPLSĿ��MAC
    #               strDstMac:       Ŀ��MAC
    #               strMplsSrcMac:   MPLSԴMAC
    #               strSrcMac:   ԴMAC 
    #               args: (��ѡ����,����±�)
    #                       -streamid       ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
    #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
    #                       -encap      ��װ���� martinioe ppp null
    #                       -lable1     ��һ���ǩ��ֵ,ȱʡֵΪ"",���ӱ����ǩ
    #                       -cos1       ��һ���ǩ��Cos(Class of Service)
    #                       -s1     ��һ���ǩ��ջ�ױ�ʶ
    #                       -ttl1       ��һ���ǩTTL
    #                       -lable2     �ڶ����ǩ��ֵȱʡֵΪ"",���ӱ����ǩ
    #                       -cos2       �ڶ����ǩ��Cos
    #                       -s2     �ڶ����ǩ��ջ�ױ�ʶ
    #                       -ttl2       �ڶ����ǩTTL  
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 19:31:55
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbMplsPacketSet {Chas Card Port strMplsDstMac strDstMac strMplsSrcMac strSrcMac args} { 
        set retVal     0

        if {[IxParaCheck "-dstmac $strDstMac -strMplsDstMac $strMplsDstMac -srcmac $strSrcMac -strMplsSrcMac $strMplsSrcMac $args"] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]

        #��ŵ edit 2006��07-21 mac��ַת�� 
        set strMplsDstMac [StrMacConvertList $strMplsDstMac]
        set strDstMac [StrMacConvertList $strDstMac]
        set strMplsSrcMac [StrMacConvertList $strMplsSrcMac]
        set strSrcMac [StrMacConvertList $strSrcMac]
        
        #  Set the defaults
        set Streamid   1
        set Length     64 
        set Encap      0
        set Lable1     ""
        set Cos1       0
        set S1         0
        set Ttl1       64
        set Lable2     ""
        set Cos2       0
        set S2         1
        set Ttl2       64
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -streamid   {set Streamid $argx}
                -length     {set Length $argx}
                -encap      {set Encap $argx}
                -lable1     {set Lable1 $argx}
                -cos1       {set Cos1 $argx}
                -s1         {set  S1 $argx}
                -ttl1       {set Ttl1 $argx}
                -lable2     {set Lable2 $argx}
                -cos2       {set Cos2 $argx}
                -s2         {set S2 $argx}
                -ttl2       {set Ttl2 $argx}
             
                default     {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }        
        stream setDefault
        stream config -name "Stream_MPLS"
        stream config -sa $strSrcMac
        stream config -da $strDstMac
        protocol setDefault        
        protocol config -ethernetType ethernetII
        protocol config -enableMPLS true
        mpls setDefault        
        mpls config -forceBottomOfStack 0
        if {$Lable1 != ""} {
            mplsLabel setDefault        
            mplsLabel config -label $Lable1
            mplsLabel config -experimentalUse $Cos1
            mplsLabel config -timeToLive $Ttl1
            mplsLabel config -bottomOfStack $S1
            mplsLabel set 1
        }
        if {$Lable2 != ""} {
            mplsLabel setDefault        
            mplsLabel config -label $Lable2
            mplsLabel config -experimentalUse $Cos2
            mplsLabel config -timeToLive $Ttl2
            mplsLabel config -bottomOfStack $S2
            mplsLabel set 2
        }        
        
        if [mpls set $Chas $Card $Port] {
            IxPuts -red  "Unable to set MPLS configs to IxHal!"
            set retVal 1
        }
        
        #Final writting....        
        if [stream set $Chas $Card $Port $Streamid] {
            IxPuts -red "Unable to set streams to IxHal!"
            set retVal 1
        }

        lappend portList [list $Chas $Card $Port]
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            set retVal 1
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbPacketCapture
    #�� �� ����     IXIA
    #�������     
    #����������     ��ʼץ��,Ȼ��ȴ�time֮��, ֹͣ, Ȼ�󷵻ص�Index�İ���ľ�������.
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:         Ixia��hub��
    #               Card:         Ixia�ӿڿ����ڵĲۺ�
    #               Port:         Ixia�ӿڿ��Ķ˿ں�
    #               args:   
    #                       -Time   ץȡʱ��,ȱʡΪ3��
    #                       -Index: ��ץȡ�İ������� ȱʡΪ0
    #                       -Offset �ֶε�ƫ���� ȱʡΪ0
    #                       -Len    �����ֶε��ֽڳ��� ȱʡΪ1
    #�� �� ֵ��     ��������һ���б�,�б��еĵ�һ��Ԫ���Ǻ���ִ�н��:
    #               0 - ��ʾ����ִ������
    #               1 - ��ʾ����ִ���쳣
    #               �б�ĵڶ���Ԫ�����û�ָ���ı����ֶ�����.
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 11:30:52
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPacketCapture  {Chas Card Port args} {
        set retVal     0

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        #  Set the defaults
        set time        3
        set index       0
        set offset      0
        set len         1
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]

            case $cmdx      {
                -Time   {set time $argx}
                -Index  {set index $argx}
                -Offset {set offset $argx}
                -Len    {set len $argx}
                default     {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }        
                
        if [SmbCaptureStart $Chas $Card $Port] {
            set retVal 1
        }
        IxPuts -blue "Capturing....Waiting $time seconds "
        after [expr $time * 1000]
            
        set lsTemp [SmbCapturePktGet $Chas $Card $Port -index $index -offset $offset -len $len]
        if [lindex $lsTemp 0] {
            set retVal 1
        }
        lappend FinalList $retVal
        lappend FinalList [lindex $lsTemp 1]
        return $FinalList          
    }

    #!!================================================================
    #�� �� ����     SmbPacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     �ȴ�����ֹͣ,�ý����������ж�,����жϽ�������Ϊ0����Ϊ����ֹͣ.
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�    
    #               DstMac:        Ŀ��Mac��ַ
    #               DstIP:         Ŀ��IP��ַ
    #               SrcMac:        ԴMac��ַ
    #               SrcIP:         ԴIP��ַ
    #               enumProType:   ����Э������
    #                     ARP ARPЭ������
    #                     IP IPЭ������
    #                     TCP TCPЭ������
    #                     UDP UDPЭ������
    #                     ICMP ICMPЭ������
    #                     IGMP IGMPЭ������
    #                     PAUSE PAUSEЭ������
    #               FrameLen:      ����
    #               FrameNum:      ����
    #               RatePct:       ��������,���ٵİٷֱ�. 100 �������ٵ� 100%, 1 �������ٵ� 1%
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 21:1:55
    #�޸ļ�¼��     
    #         ʱ��:2006-07-19 11:36:35
    #         ����:��ŵ
    #         ����:���̶�����(FrameLen FrameNum RatePct)��Ϊargs���� 
    #         2009-07-23 ������ ��дӲ����API��ixWritePortsToHardware��ΪixWriteConfigToHardware,��ֹ������·down�����
    #!!================================================================
    proc SmbPacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP enumProType args} {
        set retVal 0


        if {$enumProType == ""} {
            IxPuts -red "Error : cmd option enumProType $enumProType is null"
            set retVal 1
        } elseif { $enumProType != "ARP" && $enumProType !="IP"  && $enumProType!= "TCP" && $enumProType != "PAUSE" && $enumProType != "UDP" && $enumProType != "ICMP" && $enumProType != "IGMP" } {
            IxPuts -red "Error : cmd option enumProType $enumProType is wrong"
            set retVal 1
        }
        
        if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP  $args"] == 1} {
            set retVal 1
        }

        if {$retVal == 1} {
            return $retVal
        }

        set streamID 1

        stream setDefault

        #��ŵ edit 2006��07-23 mac��ַת�� 
        set DstMac [StrMacConvertList $DstMac]
        set SrcMac [StrMacConvertList $SrcMac]

        #��ŵ edit 2006-07-23 
        set FrameLen "64"
        set FrameNum "11"
        set RatePct "33"

        set args [string tolower $args]
        
        # ��args��ȡ��IXIA�Ǳ�˿ڷ����Ĳ���
        foreach {IxiaPortFrameSetflag temp} $args {
            switch -- $IxiaPortFrameSetflag {
                -framelen {
                    set FrameLen $temp
                }
                
                -framenum {
                    set FrameNum $temp
                }
                
                -ratepct {
                    set RatePct $temp
                }
                
                default {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
        }
       
       stream config -dma advance
       stream config -numFrames $FrameNum
       stream config -numBursts 1
       stream config -rateMode usePercentRate
       stream config -percentPacketRate $RatePct
       stream config -ifgType gapFixed
       stream config -patternType nonRepeat 
       stream config -frameSizeType sizeFixed
       #stream config -framesize $FrameLen
       stream config -framesize [expr $FrameLen + 4]
       stream config -da $DstMac
       stream config -sa $SrcMac
       
       switch $enumProType {
           ARP {
               protocol setDefault        
               protocol config -appName Arp
               protocol config -ethernetType ethernetII
               arp setDefault        
               arp set $Chas $Card $Port
           }
           IP {
               protocol setDefault 
               protocol config -name ipV4
               protocol config -ethernetType ethernetII
               ip setDefault        
               ip config -sourceIpAddr $SrcIP
               ip config -destIpAddr   $DstIP
               ip set $Chas $Card $Port
           }
           TCP {
               protocol setDefault        
               protocol config -name ipV4
               protocol config -ethernetType ethernetII
               ip setDefault
               ip config -ipProtocol ipV4ProtocolTcp
               ip config -sourceIpAddr $SrcIP
               ip config -destIpAddr   $DstIP
               ip set $Chas $Card $Port
               tcp setDefault 
               tcp set $Chas $Card $Port
           }
           UDP {
               protocol setDefault        
               protocol config -name ipV4
               protocol config -ethernetType ethernetII
               ip setDefault        
               ip config -ipProtocol ipV4ProtocolUdp
               ip config -sourceIpAddr $SrcIP
               ip config -destIpAddr   $DstIP
               ip set $Chas $Card $Port
               udp setDefault        
               udp set $Chas $Card $Port
           }
           ICMP {
               protocol setDefault        
               protocol config -name ipV4
               protocol config -ethernetType ethernetII
               ip setDefault        
               ip config -ipProtocol ipV4ProtocolIcmp
               ip config -sourceIpAddr $SrcIP
               ip config -destIpAddr   $DstIP
               ip set $Chas $Card $Port
               icmp setDefault        
               icmp set $Chas $Card $Port       
            }
            IGMP { 
               protocol setDefault        
               protocol config -name ipV4
               protocol config -ethernetType ethernetII
               ip setDefault        
               ip config -ipProtocol ipV4ProtocolIgmp
               ip config -sourceIpAddr $SrcIP
               ip config -destIpAddr   $DstIP
               ip set $Chas $Card $Port
               igmp setDefault        
               igmp config -type membershipQuery
               igmp set $Chas $Card $Port
            }
            PAUSE {
                protocol setDefault        
                protocol config -name pauseControl
                protocol config -ethernetType ethernetII
                pauseControl setDefault        
                pauseControl set $Chas $Card $Port
            }
           
           
       }
       
       IxPuts -blue "write config to $Chas $Card $Port"
       if [stream set  $Chas $Card $Port 1] {
           IxPuts -red "Can't stream set  $Chas $Card $Port 1"
           set retVal 1
       }
       lappend portList [list $Chas $Card $Port]
       #modify by chenshibing 2009-07-23 from ixWritePortsToHardware to ixWriteConfigToHardware
       if [ixWriteConfigToHardware portList -noProtocolServer] {
           IxPuts -red "Can't write stream to  $Chas $Card $Port"
           set retVal 1
       }    
       ixCheckLinkState             portList
       return $retVal        
   }

    #!!================================================================
    #�� �� ����     SmbPausePacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     PAUSE������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�    
    #               DstMac:        Ŀ��Mac��ַ
    #               DstIP:         Ŀ��IP��ַ
    #               SrcMac:        ԴMac��ַ
    #               SrcIP:         ԴIP��ַ
    #               args: (��ѡ����,����±�)
    #                       -streamid       ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
    #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
    #                       -vlan           Vlan tag,����,Ĭ��0,����û��VLAN Tag,����0��ֵ�Ų���VLAN tag.
    #                       -pri            Vlan�����ȼ�����Χ0��7��ȱʡΪ0
    #                       -cfi            Vlan�������ֶΣ���Χ0��1��ȱʡΪ0
    #                       -type           ����ETHЭ�����ͣ�ȱʡֵ "08 00"
 
    #                       -change         �޸����ݰ��е�ָ���ֶΣ��˲�����ʶ�޸��ֶε��ֽ�ƫ����,Ĭ��ֵ,���һ���ֽ�(CRCǰ).
    #                       -value          �޸����ݵ�����, Ĭ��ֵ {{00 }}, 16���Ƶ�ֵ.
    #                       -enable         �Ƿ�ʹ��������Ч true / false
    #                       -sname          ������������,����Ϸ����ַ���.Ĭ��Ϊ""
    #                       -strtransmode   ���������͵�ģʽ,����0:�������� 1:������ָ������Ŀ��ֹͣ 2:�����걾���������������һ����.
    #                       -strframenum    ���屾�������͵İ���Ŀ
    #                       -strrate        ��������,���ٵİٷֱ�. 100 �������ٵ� 100%, 1 �������ٵ� 1%
    #                       -strburstnum    ���屾�����������ٸ�burst,ȡֵ��Χ1~65535,Ĭ��Ϊ1
    #
    #                       -pause          ʱ��,��Pause QuantaΪ��λ0~65536,(1 Pause Quanta = 512 λʱ) Ĭ��ֵΪ255
    #
    #                       -udf1           �Ƿ�ʹ��UDF1,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf1offset     UDFƫ����
    #                       -udf1len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf1initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf1step       UDF�仯����,Ĭ��1
    #                       -udf1changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf1repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf2           �Ƿ�ʹ��UDF2,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf2offset     UDFƫ����
    #                       -udf2len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf2initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf2step       UDF�仯����,Ĭ��1
    #                       -udf2changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf2repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf3           �Ƿ�ʹ��UDF3,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf3offset     UDFƫ����
    #                       -udf3len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf3initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf3step       UDF�仯����,Ĭ��1
    #                       -udf3changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf3repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf4           �Ƿ�ʹ��UDF4,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf4offset     UDFƫ����
    #                       -udf4len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf4initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf4step       UDF�仯����,Ĭ��1
    #                       -udf4changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf4repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf5           �Ƿ�ʹ��UDF5,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf5offset     UDFƫ����
    #                       -udf5len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf5initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf5step       UDF�仯����,Ĭ��1
    #                       -udf5changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf5repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 9:42:43
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPausePacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP args} {
        set retVal     0

        if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP $args"] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        #  Set the defaults
        set streamId   1
        set Sname      ""
        set Length     64
        set Vlan       0
        set Pri        0
        set Cfi        0
        set Type       "08 00"
        set Change     0
        set Enable     true
        set Value      {{00 }}
        set Strtransmode 0
        set Strframenum    100
        set Strrate    100
        set Strburstnum  1
        set Pause       255
        
        
        set Udf1       0
        set Udf1offset 0
        set Udf1len    1
        set Udf1initval {00}
        set Udf1step    1
        set Udf1changemode 0
        set Udf1repeat  1
        
        set Udf2       0
        set Udf2offset 0
        set Udf2len    1
        set Udf2initval {00}
        set Udf2step    1
        set Udf2changemode 0
        set Udf2repeat  1
        
        set Udf3       0
        set Udf3offset 0
        set Udf3len    1
        set Udf3initval {00}
        set Udf3step    1
        set Udf3changemode 0
        set Udf3repeat  1
        
        set Udf4       0
        set Udf4offset 0
        set Udf4len    1
        set Udf4initval {00}
        set Udf4step    1
        set Udf4changemode 0
        set Udf4repeat  1        
            
        set Udf5       0
        set Udf5offset 0
        set Udf5len    1
        set Udf5initval {00}
        set Udf5step    1
        set Udf5changemode 0
        set Udf5repeat  1
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -streamid   {set streamId $argx}
                -sname      {set Sname $argx}
                -length     {set Length $argx}
                -vlan       {set Vlan $argx}
                -pri        {set Pri $argx}
                -cfi        {set Cfi $argx}
                -type       {set Type $argx}                        
                -change     {set Change $argx}
                -value      {set Value $argx}
                -enable     {set Enable $argx}
                -strtransmode { set Strtransmode $argx}
                -strframenum {set Strframenum $argx}
                -strrate     {set Strrate $argx}
                -strburstnum {set Strburstnum $argx}
                -pause       {set Pause $argx}
                
                -udf1           {set Udf1 $argx}
                -udf1offset     {set Udf1offset $argx}
                -udf1len        {set Udf1len $argx}
                -udf1initval    {set Udf1initval $argx}  
                -udf1step       {set Udf1step $argx}
                -udf1changemode {set Udf1changemode $argx}
                -udf1repeat     {set Udf1repeat $argx}
                
                -udf2           {set Udf2 $argx}
                -udf2offset     {set Udf2offset $argx}
                -udf2len        {set Udf2len $argx}
                -udf2initval    {set Udf2initval $argx}  
                -udf2step       {set Udf2step $argx}
                -udf2changemode {set Udf2changemode $argx}
                -udf2repeat     {set Udf2repeat $argx}
                
                -udf3           {set Udf3 $argx}
                -udf3offset     {set Udf3offset $argx}
                -udf3len        {set Udf3len $argx}
                -udf3initval    {set Udf3initval $argx}  
                -udf3step       {set Udf3step $argx}
                -udf3changemode {set Udf3changemode $argx}
                -udf3repeat     {set Udf3repeat $argx}
                
                -udf4           {set Udf4 $argx}
                -udf4offset     {set Udf4offset $argx}
                -udf4len        {set Udf4len $argx}
                -udf4initval    {set Udf4initval $argx}  
                -udf4step       {set Udf4step $argx}
                -udf4changemode {set Udf4changemode $argx}
                -udf4repeat     {set Udf4repeat $argx}
                
                -udf5           {set Udf5 $argx}
                -udf5offset     {set Udf5offset $argx}
                -udf5len        {set Udf5len $argx}
                -udf5initval    {set Udf5initval $argx}  
                -udf5step       {set Udf5step $argx}
                -udf5changemode {set Udf5changemode $argx}
                -udf5repeat     {set Udf5repeat $argx}
                         
                default {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }
            
        #Define Stream parameters.
        stream setDefault        
        stream config -enable $Enable
        stream config -name $Sname
        stream config -numBursts $Strburstnum        
        stream config -numFrames $Strframenum
        stream config -percentPacketRate $Strrate
        stream config -rateMode usePercentRate
        stream config -sa $SrcMac
        stream config -da $DstMac
        switch $Strtransmode {
            0 {stream config -dma contPacket}
            1 {stream config -dma stopStream}
            2 {stream config -dma advance}
            default {
                set retVal 1
                IxPuts -red "No such stream transmit mode, please check -strtransmode parameter."
                return $retVal
            }
        }
        
        if {$Length != 0} {
            #stream config -framesize $Length
            stream config -framesize [expr $Length + 4]
            stream config -frameSizeType sizeFixed
        } else {
            stream config -framesize 318
            stream config -frameSizeType sizeRandom
            stream config -frameSizeMIN 64
            stream config -frameSizeMAX 1518       
        }
        
       
        stream config -frameType $Type
        
        #Define protocol parameters 
        protocol setDefault        
        protocol config -name pauseControl
        protocol config -ethernetType ethernetII
        pauseControl setDefault        
        pauseControl config -pauseTime   $Pause
         
        if [pauseControl set $Chas $Card $Port] {
            IxPuts -red "Unable to set Pause configs to IxHal!"
            set retVal 1
        }
        
        if {$Vlan != 0} {
            protocol config -enable802dot1qTag vlanSingle
            vlan setDefault        
            vlan config -vlanID $Vlan
            vlan config -userPriority $Pri
            if [vlan set $Chas $Card $Port] {
                IxPuts -red "Unable to set Vlan configs to IxHal!"
                set retVal 1
            }
        }
        switch $Cfi {
            0 {vlan config -cfi resetCFI}
            1 {vlan config -cfi setCFI}
        }
        
        #UDF Config
        if {$Udf1 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf1offset
            switch $Udf1len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf1changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf1initval
            udf config -repeat  $Udf1repeat              
            udf config -step    $Udf1step
            udf set 1
        }
        if {$Udf2 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf2offset
            switch $Udf2len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf2changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf2initval
            udf config -repeat  $Udf2repeat              
            udf config -step    $Udf2step
            udf set 2
        }
        if {$Udf3 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf3offset
            switch $Udf3len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf3changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf3initval
            udf config -repeat  $Udf3repeat              
            udf config -step    $Udf3step
            udf set 3
        }
        if {$Udf4 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf4offset
            switch $Udf4len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf4changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf4initval
            udf config -repeat  $Udf4repeat              
            udf config -step    $Udf4step
            udf set 4
        }
        if {$Udf5 == 1} {
            udf setDefault        
            udf config -enable true
            udf config -offset $Udf5offset
            switch $Udf5len {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
            }
            switch $Udf5changemode {
                0 {udf config -updown uuuu}
                1 {udf config -updown dddd}
            }
            udf config -initval $Udf5initval
            udf config -repeat  $Udf5repeat              
            udf config -step    $Udf5step
            udf set 5
        }        
        
        
        #Table UDF Config        
        tableUdf setDefault        
        tableUdf clearColumns      
        tableUdf config -enable 1
        tableUdfColumn setDefault        
        tableUdfColumn config -formatType formatTypeHex
        if {$Change == 0} {
            tableUdfColumn config -offset [expr $Length -5]} else {
            tableUdfColumn config -offset $Change
        }
        tableUdfColumn config -size 1
        tableUdf addColumn         
        set rowValueList $Value
        tableUdf addRow $rowValueList
        if [tableUdf set $Chas $Card $Port] {
            IxPuts -red "Unable to set TableUdf to IxHal!"
            set retVal 1
        }
 
        #Final writting....        
        if [stream set $Chas $Card $Port $streamId] {
            IxPuts -red "Unable to set streams to IxHal!"
            set retVal 1
        }
        
        incr streamId
        lappend portList [list $Chas $Card $Port]
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            set retVal 1
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbPktSendAndCapture
    #�� �� ����     IXIA
    #�������     
    #����������     �����������Ͷ˿ڿ�ʼ����,Ȼ���ڵȴ�һ��ʱ��֮���ڽ��ն˿ڿ�ʼ����.
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:         Ixia��hub��
    #               Card:         Ixia�ӿڿ����ڵĲۺ�
    #               Port:         Ixia�ӿڿ��Ķ˿ں�      
    #               intCptHub:    ���ն�Ixia��hub��
    #               intCptSlot:   ���ն�Ixia�ӿڿ����ڵĲۺ�
    #               intCptPort:   ���ն�Ixia�ӿڿ��Ķ˿ں�   
    #               intTime, ȱʡֵ��3000:    ��ʼ����֮��ȴ��೤ʱ���ٿ�ʼ���ն˿ڵĲ���,��λ:΢��
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 11:16:17
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPktSendAndCapture { Chas Card Port intCptHub intCptSlot intCptPort {intTime 3000}} {
        set retVal 0
        IxPuts -blue "�����˿�$Chas $Card $Port ����"
        if [ixStartPortTransmit $Chas $Card $Port] {
            IxPuts -red "�����˿�$Chas $Card $Port ��������!"
            set retVal 1
        }
        IxPuts -blue "$intTime ΢��֮��ʼ��$intCptHub $intCptSlot $intCptPort �ϲ���"
        after $intTime
        IxPuts -blue "�����˿�$intCptHub $intCptSlot $intCptPort ����"
        if [ixStartPortCapture $intCptHub $intCptSlot $intCptPort] {
            IxPuts -red "�����˿�$intCptHub $intCptSlot $intCptPort ����ʧ��!"
            set retVal 1
        }
        return $retVal           
    }
    
    #!!================================================================
    #�� �� ����     SmbPortClear
    #�� �� ����     IXIA
    #�������     
    #����������     ����˿ڵ�����ͳ��
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:     Ixia��hub��
    #               Card:     Ixia�ӿڿ����ڵĲۺ�
    #               Port:     Ixia�ӿڿ��Ķ˿ں�
    #               args:     Ixia�ӿڿ��Ķ˿ںţ��ɱ���Ŀ����
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:17:9
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortClear {Chas Card Port args} {
        #added by yuzhenpin 61733 2009-4-7 19:21:28
        SmbPortReserve $Chas $Card $Port
        #end of added
        
        set retVal 0
        if {[ixClearPortStats $Chas $Card $Port]} {
            IxPuts -red "Can't Clear $Chas $Card $Port counters"
            set retVal 1
        }
       # lappend portList [list $Chas $Card $Port]
          #-- Eric modified to speed up
       # ixCheckLinkState portList
        return $retVal         
    }

    #!!================================================================
    #�� �� ����     SmbPortsCaptureClear
    #�� �� ����     IXIA
    #�������     
    #����������     ���ץ����������ʵ���ϲ���Ҫ�������������Ϊÿ�ο�ʼץ�����Զ���ջ�����
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               PortList:   {{$Chas1 $Card1 $Port1} {$Chas2 $Card2 $Port2} ... {$ChasN $CardN $PortN}} 
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 18:34:55
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortsCaptureClear {PortList} {
        set retVal 0
        if {[ixStartCapture PortList] != 0} {
            IxPuts -red "Could not start capture on $PortList"
            set retVal 1
        }
        if {[ixStopCapture PortList] != 0} {
            IxPuts -red "Could not stop capture on $PortList"
            set retVal 1
        }    
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbPortClearEx
    #�� �� ����     IXIA
    #�������     
    #����������     ��λ�˿ڣ����ݶ˿ڵ���������,���ΪFE������Ϊ����ȫ˫�����ΪGE����Ϊǧ��ȫ˫��
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:     Ixia��hub��
    #               Card:     Ixia�ӿڿ����ڵĲۺ�
    #               Port:     Ixia�ӿڿ��Ķ˿ں�    
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:19:14
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortClearEx {Chas Card Port} {
          set retVal 0
          #-- Eric modified to speed up
#          if {[SmbPortClear $Chas $Card $Port]} {
#             set retVal 1  
#          }        
          if {[port setFactoryDefaults $Chas $Card $Port]} {
              errorMsg "Error setting factory defaults on port $Chas,$Card,$Port."
              set retVal 1
          }
          lappend portList [list $Chas $Card $Port]
          if {[ixWritePortsToHardware portList]} {
              IxPuts -red "Can't write config to $Chas $Card $Port"
              set retVal 1   
          }    
          #-- Eric modified to speed up
        #  ixCheckLinkState portList
          return $retVal         
    }

    #!!================================================================
    #�� �� ����     SmbPortInfoGet
    #�� �� ����     IXIA
    #�������     
    #����������     ���ض˿����ݰ�ͳ����Ϣ
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�    
    #               CounterName:    
    #                              -framesSent ���ͱ���
    #                              -framesReceived ���ձ���
    #               CounterType:   Count/Rate Count˵���Ǹ���, Rate˵��������.
    #�� �� ֵ��     ָ���������͵�ͳ������
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:22:52
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortInfoGet {Chas Card Port gIn } {
        set Val 0
        switch $gIn {
            "TmtPkt" {
                stat get statAllStats $Chas $Card $Port
                set Val [stat cget -framesSent]
            }
      
            "RcvPkt" {
                stat get statAllStats $Chas $Card $Port
                set Val [stat cget -framesReceived]
            }
            
            "TmtPktRate"  {
                stat getRate allStats $Chas $Card $Port
                set Val [stat cget -framesSent]
            }
            "RcvPktRate"  {
                stat getRate allStats $Chas $Card $Port
                set Val [stat cget -framesReceived]
            }
            default {set retVal 1}
        }
        IxPuts -blue "$gIn : $Val"
    }

    #!!================================================================
    #�� �� ����     SmbPortLinkStatusGet
    #�� �� ����     IXIA
    #�������     
    #����������     ��ȡ�˿ڵ�link״̬
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�     
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:27:59
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortLinkStatusGet {Chas Card Port } {
        set retVal 0
        lappend portList [list $Chas $Card $Port]
        if {[ixCheckLinkState portList]} {
            IxPuts -blue "$Chas $Card $Port Link is Down"
            set retVal 1   
          }
        return $retVal  
    }

    #!!================================================================
    #�� �� ����     SmbPortModeSet
    #�� �� ����     IXIA
    #�������     
    #����������     IX����˿��趨,���û������ɱ������Ĭ�Ͻ��˿�����Ϊ����Ӧ״̬.
    #               �����м����˷���ģʽ:TrasmitMode - PacketStreams(default) / AdvancedScheduler 
    #               ��˳����ģʽ�Ͳ���ģʽ.��������Port�����б��붨���,���Ա�����Port�������ͬʱ����. 
    #               ���ķ���ģʽ����������,������������.
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�
    #               args:
    #               
    #                     -speed:        10 or 100��ȱʡΪ100
    #                     -duplex:       FULLMODE or HALFMODE��ȱʡΪFULLMODE
    #                     -nego:         AUTO or NOAUTO��ȱʡΪAUTO
    #                     -transmitmode:  PacketStreams(default) / AdvancedScheduler 
    #                     -activemode:    copper_mode /  fiber_mode (Default)
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:34:1
    #�޸ļ�¼��     
    #         ʱ��:2006-07-19 11:36:35
    #         ����:��ŵ
    #         ����:���̶�����(duplexMode speed autoneg TransmitMode PhyMode)��Ϊargs���� 
    #!!================================================================
    proc SmbPortModeSet { Chas Card Port args} {
        #added by yuzhenpin 61733 2009-4-7 19:21:28
        SmbPortReserve $Chas $Card $Port
        #end of added
        
        set retVal 0
        
        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        #��ŵ edit 2006-07-19 
        set duplexMode "FULL"
        set speed "ALL"
        set autoneg "TRUE"
        set TransmitMode "PacketStreams" 
        set PhyMode "portPhyModeFiber"

        set args [string tolower $args]
        
        # ��args��ȡ��IXIA�Ǳ�˿ڲ���
        foreach {IxiaPortModeSetflag temp} $args {
            switch -- $IxiaPortModeSetflag {
                -duplex {
                    if { $temp == "fullmode"} {
                        set duplexMode "FULL"
                    } elseif {$temp == "halfmode"} {
                        set duplexMode "HALF"
                    } else {
                        set duplexMode "ALL"
                    }
                }
                
                -speed {
                    if {$temp == "10m"} {
                        set speed "10"
                    } elseif {$temp == "100m"} { 
                        set speed "100"
                    } elseif {$temp == "1000m"}  {
                        set speed "1000"
                    } else {
                        set speed "ALL"
                    }
                }
                
                -nego {
                    if { $temp == "auto" } {
                        set autoneg "TRUE"
                    } else {
                        set autoneg "FALSE"
                    }
                }
                
                -transmitmode {
                    if {[string equal -nocase $temp "portPhyModeCopper"]        \
                    ||  [string equal -nocase $temp "PacketStreams"]} {
                        set TransmitMode "PacketStreams"
                    } elseif {[string equal -nocase $temp "AdvancedScheduler"]  \
                    ||  [string equal -nocase $temp "Advanced"]} {
                         set TransmitMode "AdvancedScheduler"
                    } else {
                        error "�����Transmit Mode:$temp"
                    }
                }
                
                -activemode {
                    if {$temp == "copper_mode"} {
                        set PhyMode "portPhyModeCopper"
                    } elseif {$temp == "fiber_mode"} {
                        set PhyMode "portPhyModeFiber"
                    }
                }
                default {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
        }

        # check for errord parameters
        #-----------------------------
        if { ($speed != "10")&&($speed != "100")&&($speed != "1000")&&($speed != "ALL") } {
            IxPuts -red "illegal speed defined ($speed)"
            set retVal 1 
        }
        if { ($duplexMode != "FULL")&&($duplexMode != "HALF")&&($duplexMode != "ALL") } {
            IxPuts -red "illegal duplex mode defined ($duplexMode)"
            set retVal 1 
        }
        if { ($autoneg != "TRUE")&&($autoneg != "FALSE") } {
            IxPuts -red "illegal auto negotiate mode defined ($autoneg)"
            set retVal 1 
        }
       
        # initialize
        #------------
        if { [port setFactoryDefaults $Chas $Card $Port] } {
            IxPuts -red "error setting port $Chas $Card $Port to factory defaults"
            catch { ixputs $::ixErrorInfo} err
            set retVal 1 
        }

#        port       setDefault
#        if { [port reset $Chas $Card $Port] } {
#            IxPuts -red "error resetting port $Chas $Card $Port"
#            set retVal 1 
#        }
				
		# check whether it is a 10GLAN card
	    port get $Chas $Card $Port
		set portMode [ port cget -portMode ]
		set flag10GLAN 0
		if { $portMode == "4" } {
		    set flag10GLAN 1
		}

        #Config Port Phy Mode
        # GE������Ҫ�������ʡ�˫����Э�̵Ȳ���
        if { $flag10GLAN == 0 } {
	        port setPhyMode $PhyMode $Chas $Card $Port
	
	        if {$PhyMode == "portPhyModeCopper"} {
	            if { $autoneg == "TRUE" } {
	                port config -autonegotiate  true
	                if { $speed == "ALL" } {
	                    if { $duplexMode == "ALL" } {
	                    port config -advertise1000FullDuplex  true  
	                    port config -advertise100FullDuplex   true
	                    port config -advertise100HalfDuplex   true
	                    port config -advertise10FullDuplex   true
	                    port config -advertise10HalfDuplex   true
	                } elseif { $duplexMode == "FULL" } {
	                    port config -advertise1000FullDuplex  true    
	                    port config -advertise100FullDuplex   true
	                    port config -advertise100HalfDuplex   false
	                    port config -advertise10FullDuplex   true
	                    port config -advertise10HalfDuplex   false
	                } elseif { $duplexMode == "HALF" } {
	                    port config -advertise1000FullDuplex  false    
	                    port config -advertise100FullDuplex   false
	                    port config -advertise100HalfDuplex   true
	                    port config -advertise10FullDuplex   false
	                    port config -advertise10HalfDuplex   true
	                }
	            } elseif { $speed == "1000" } {
	                if { $duplexMode == "ALL" } {
	                     port config -advertise1000FullDuplex  true  
	                     port config -advertise100FullDuplex   false
	                     port config -advertise100HalfDuplex   false
	                     port config -advertise10FullDuplex   false
	                     port config -advertise10HalfDuplex   false
	                } elseif { $duplexMode == "FULL" } {
	                    port config -advertise1000FullDuplex  true    
	                    port config -advertise100FullDuplex   false
	                    port config -advertise100HalfDuplex   false
	                    port config -advertise10FullDuplex   false
	                    port config -advertise10HalfDuplex   false
	                } elseif { $duplexMode == "HALF" } {
	                   IxPuts -red "No 1000M Half this mode"
	                }
	            } elseif { $speed == "100" } {
	                if { $duplexMode == "ALL" } {
	                    port config -advertise100FullDuplex   true
	                    port config -advertise100HalfDuplex   true
	                    port config -advertise10FullDuplex   false
	                    port config -advertise10HalfDuplex   false
	                } elseif { $duplexMode == "FULL" } {
	                    port config -advertise100FullDuplex   true
	                    port config -advertise100HalfDuplex   false
	                    port config -advertise10FullDuplex   false
	                    port config -advertise10HalfDuplex   false
	                } elseif { $duplexMode == "HALF" } {
	                    port config -advertise100FullDuplex   false
	                    port config -advertise100HalfDuplex   true
	                    port config -advertise10FullDuplex   false
	                    port config -advertise10HalfDuplex   false
	                }
	            } elseif { $speed == "10" } {
	                if { $duplexMode == "ALL" } {
	                    port config -advertise100FullDuplex   false
	                    port config -advertise100HalfDuplex   false
	                    port config -advertise10FullDuplex   true
	                    port config -advertise10HalfDuplex   true
	                } elseif { $duplexMode == "FULL" } {
	                    port config -advertise100FullDuplex   false
	                    port config -advertise100HalfDuplex   false
	                    port config -advertise10FullDuplex   true
	                    port config -advertise10HalfDuplex   false
	                } elseif { $duplexMode == "HALF" } {
	                    port config -advertise100FullDuplex   false
	                    port config -advertise100HalfDuplex   false
	                    port config -advertise10FullDuplex   false
	                    port config -advertise10HalfDuplex   true
	                }
	            }
	        } else {
	            # no autonegotiate
	            #-------------------
	            port config -autonegotiate  false
	
	            if { $duplexMode == "FULL" } {
	                port config -duplex full
	            } elseif { $duplexMode == "HALF" } {
	                port config -duplex half
	            } else {
	                IxPuts -red "illegal duplex mode inconjunction with auto negotiate settings ($duplexMode)"
	                set retVal 1 
	            }
	            port config -speed $speed
	        }
	    } elseif { $PhyMode == "portPhyModeFiber" } {   
	        
	        #fixed by yuzhenpin 61733 2009-7-17 14:20:35
	        #�Ͼ��߾귴�����ģʽ�»ὫЭ��ģʽ�ĳɷ���Э�̵��¶˿�״̬Ϊdown
	        #from
	        #port config -speed $speed     
	        #to
	        if { $autoneg == "TRUE" } {
	        
	            #added by yuzhenpin 61733 2009-8-4 10:54:29
	            #�ڹ��ģʽ�£���Ҫ���л���1000Mȫ˫��
	            port config -advertise1000FullDuplex  true
	            port config -speed 1000
	            #end of added
	            
	            port config -autonegotiate  true
	        } else {
		    if {$speed == 0 || $speed =="ALL"} {
                        set speed 1000
                    }
	            port config -autonegotiate  false
	            port config -speed $speed
	        }
	        #end of fixed
	        
	    }
    } 

    #Config Port Transmit Mode
    switch  $TransmitMode {
        PacketStreams {
            port config -transmitMode   portTxPacketStreams 
        }
        AdvancedScheduler {
            port config -transmitMode   portTxModeAdvancedScheduler
        }
    }

    # Write config to Hardware    
    if { [port set $Chas $Card $Port] } {
        IxPuts -red "failed to set port configuration on port $Chas $Card $Port"
        catch { ixputs $::ixErrorInfo} err
        set retVal 1
    }
       
    lappend portList [list $Chas $Card $Port ]
    if [ixWritePortsToHardware portList -noProtocolServer] {
        IxPuts -red "Can't write config to $Chas $Card $Port"
        catch { ixputs $::ixErrorInfo} err
        set retVal 1   
    }    
    ixCheckLinkState portList   
    return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbPortsReserve
    #�� �� ����     IXIA
    #�������     
    #����������     ռ�ö˿�
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�    
    #               UserName:      ��½ռ�ö˿ںŵ��û���
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:43:6
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortReserve {Chas Card Port} {
    
        #added by yuzhenpin 61733 2009-4-7 19:05:51
        variable m_portList
        if {0 <= [lsearch $m_portList [list $Chas $Card $Port]]} {
            return 0
        }
        lappend m_portList [list $Chas $Card $Port]
        #end of added

        set retVal 0
        set UserName [info hostname]
        ixLogin $UserName
        
#        puts "ixTakeOwnership $Chas $Card $Port $UserName"
        lappend portList [list $Chas $Card $Port ]
        if [ixTakeOwnership $portList "force"] {
            IxPuts -red "unable to reserve $Chas $Card $Port!"
            set retVal 1
        }
      
        return $retVal         
    }  

    #!!================================================================
    #�� �� ����     SmbPortsReserve
    #�� �� ����     IXIA
    #�������     
    #����������     ռ�ö˿�
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�    
    #               UserName:      ��½ռ�ö˿ںŵ��û���
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:43:6
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortsReserve {Chas Card Port} {

        set retVal 0
        set UserName [info hostname]
        ixLogin $UserName
        lappend portList [list $Chas $Card $Port ]
        if [ixTakeOwnership $portList] {
            IxPuts -red "unable to reserve $Chas $Card $Port!"
            set retVal 1
       }

       return $retVal         
    }   
    
    #!!================================================================
    #�� �� ����     SmbPortRelease
    #�� �� ����     IXIA
    #�������     
    #����������     �ͷŶ˿�
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�   
    #               Mode:          force (not friendly!)/ noForce(good way!)
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:39:2
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortRelease {Chas Card Port {Mode force}} {
        
        #added by yuzhenpin 61733 2009-4-7 19:05:51
        variable m_portList
        set index [lsearch $m_portList [list $Chas $Card $Port]]
        if {0 <= $index} {
            set m_portList [lreplace $m_portList $index $index]
        }
        #end of added
    
        set retVal 0
        lappend portList [list $Chas $Card $Port ]
        if [ixClearOwnership $portList $Mode] {
            IxPuts -red "unable to release $Chas $Card $Port!"
            set retVal 1
        }
        return $retVal         
    }   

    #!!================================================================
    #�� �� ����     IxPortReset
    #�� �� ����     IXIA
    #�������     
    #����������     ��λIxia���˿�
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�
    #               args:          Ixia�ӿڿ��Ķ˿ںţ��ɱ���Ŀ����
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:29:45
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortReset {Chas Card Port args} {
        #added by yuzhenpin 61733 2009-4-7 19:21:28
        SmbPortReserve $Chas $Card $Port
        #end of added
        
         set retVal 0
	      #-- Eric modified to speed up
          if {[SmbPortClear $Chas $Card $Port]} {
              puts "SmbPortReset:call SmbPortClear failed!"
              #set retVal 1  
          }        
          if {[port setFactoryDefaults $Chas $Card $Port]} {
              errorMsg "Error setting factory defaults on port $Chas,$Card,$Port."
              set retVal 1
          }
          lappend portList [list $Chas $Card $Port]
          if {[ixWritePortsToHardware portList]} {
              IxPuts -red "Can't write config to $Chas $Card $Port"
              set retVal 1   
          }    
	  
	  #-- Eric modified to speed up
          #ixCheckLinkState portList
          
          #-- Eric modified to clear metric count
          if { [ info exists ::ArrMetricCount ] } {
              catch {unset ::ArrMetricCount} err
          }
          
          return $retVal         
    }

    #!!================================================================
    #�� �� ����     SmbPortRun
    #�� �� ����     IXIA
    #�������     
    #����������     ����Ixia�˿ڷ���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�
    #               runPara:       �˿�����ģʽ
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:30:44
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortRun {Chas Card Port {runPara 2}} {
        #added by yuzhenpin 61733 2009-4-7 19:21:28
        SmbPortReserve $Chas $Card $Port
        #end of added
        
         set retVal 0
         lappend portList [list $Chas $Card $Port]
         if {[ixStartTransmit portList]} {
             set retVal 1
         }
         return $retVal    
    }

    #!!================================================================
    #�� �� ����     SmbPortStop
    #�� �� ����     IXIA
    #�������     
    #����������     ֹͣIxia�˿ڷ���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:31:42
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortStop {Chas Card Port} {
         set retVal 0
         lappend portList [list $Chas $Card $Port]
         if [ixStopTransmit portList] {
             set retVal 1
          }
         return $retVal    
    }


    #!!================================================================
    #�� �� ����     SmbPortTxStatusGet
    #�� �� ����     IXIA
    #�������     
    #����������     �ж�Ixia�˿ڵ�״̬���Ƿ��ڷ���״̬
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�   
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:32:34
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortTxStatusGet {Chas Card Port } {
         set retVal 0
        # lappend portList [list $Chas $Card $Port]
         
         if [ixCheckPortTransmitDone $Chas $Card $Port] {
             set retVal 1
         }
         return $retVal  
    } 

    #!!================================================================
    #�� �� ����     SmbRcvTrafficGet
    #�� �� ����     IXIA
    #�������     
    #����������     ͳ�ƽ��ն˿ڼ���������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:         Ixia��hub��
    #               Card:         Ixia�ӿڿ����ڵĲۺ�
    #               Port:         Ixia�ӿڿ��Ķ˿ں�  
    #               args: (��ѡ����,����±�)
    #                       -frame      �յ�����֡��
    #                       -packet
    #                       -framerate  �յ���֡���ʣ���/S��
    #                       -byte       �յ������ֽ���
    #                       -byterate   �յ����ֽ����ʣ�bytes/S��
    #                       -trigger    �յ���Trigger����
    #                       -triggerrate    �յ���Trigger�������ʣ���/S��
    #                       -crc        �յ���CRC��������
    #                       -crcrate    �յ���CRC���������ʣ���/S��
    #                       -over       �յ��Ĺ����ļ���
    #                       -overrate   �յ��Ĺ����ĵ����ʣ���/S��
    #                       -frag       �յ��ķ�Ƭ���ļ���
    #                       -fragrate   �յ��ķ�Ƭ�������ʣ���/S��  
    #                       -arprequest
    #                       -arpreply
    #                       -igmpframe
    #                       -undersize
    #			    -collision
    #			    -pingrequest
    #			    -pingreply
    #			    -ipchecksumerror
    #			    -ipv4frame
    #			    -vlanframe
    #			    -flowcontrol
    #			    -qos0
    #			    -qos1
    #			    -qos2
    #			    -qos3
    #			    -qos4
    #			    -qos5
    #			    -qos6
    #			    -qos7
    #			    -udppacket
    #			    -tcppacket
    #			    -tcpchecksumerror
    #			    -udpchecksumerror
    #�� �� ֵ��     ��������һ���б�,�б��еĵ�һ��Ԫ���Ǻ���ִ�н��:
    #                 0 - ��ʾ����ִ������
    #                 1 - ��ʾ����ִ���쳣
    #                 ���б�ĵڶ���Ԫ�ؿ�ʼ���û�����ļ���������.
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 11:19:55
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbRcvTrafficGet { Chas Card Port args} {
        set retVal     0
        
        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        set FinalList ""
        
        if [stat get statAllStats $Chas $Card $Port] {
            IxPuts -red "Get all Event counters Error"
            set retVal 1
        }
        if [stat getRate allStats $Chas $Card $Port] {
            IxPuts -red "Get all Rate counters Error"
            set retVal 1
        }
        lappend FinalList $retVal
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -frame    {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -framesReceived]
                    lappend FinalList $TempVal
                }
                
                -packet    {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -framesReceived]
                    lappend FinalList $TempVal
                }
                
                -framerate      {
                    stat getRate allStats $Chas $Card $Port
                    set TempVal [stat cget -framesReceived]
                    lappend FinalList $TempVal
                }
                -byte           {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -bytesReceived]
                    lappend FinalList $TempVal
                }
                -byterate   {
                    stat getRate allStats $Chas $Card $Port
                    set TempVal  [stat cget -bytesReceived]
                    lappend FinalList $TempVal
                }
                -collision {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -collisions]
                    lappend FinalList $TempVal
                }
                -undersize {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -undersize]
                    lappend FinalList $TempVal
                }
                -trigger    {
                    stat get statAllStats $Chas $Card $Port
					#=============
					# Modified by Eric Yu
                    # set TempVal  [stat cget -captureFilter]
					set TempVal [stat cget -userDefinedStat1]
					#=============
                    lappend FinalList $TempVal                                
                }
                -triggerrate    {
                    stat getRate allStats $Chas $Card $Port
					#=============
					# Modified by Eric Yu
                    # set TempVal  [stat cget -captureTrigger]
                    set TempVal  [stat cget -userDefinedStat1]
					#=============
                    lappend FinalList $TempVal  
                }
                -crc        {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -fcsErrors]
                    lappend FinalList $TempVal
                }
                -crcrate    {
                    stat getRate allStats $Chas $Card $Port
                    set TempVal  [stat cget -fcsErrors]
                    lappend FinalList $TempVal 
                }
                -over       {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -oversize]
                    lappend FinalList $TempVal
                }
                -overrate   {
                    stat getRate allStats $Chas $Card $Port
                    set TempVal  [stat cget -oversize]
                    lappend FinalList $TempVal 
                }
                -frag       {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -fragments]
                    lappend FinalList $TempVal
                }
                -fragrate   {
                    stat getRate allStats $Chas $Card $Port
                    set TempVal  [stat cget -fragments]
                    lappend FinalList $TempVal
                }
                -pingrequest {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -rxPingRequest]
                    lappend FinalList $TempVal
                }
                -pingreply {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -rxPingReply]
                    lappend FinalList $TempVal
                }
                -ipchecksumerror {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -ipChecksumErrors]
                    lappend FinalList $TempVal
                }
                -ipv4frame {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -ipPackets]
                    lappend FinalList $TempVal
                }
                -arpreply   {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -rxArpReply]
                    lappend FinalList $TempVal
                }
                -arprequest {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -rxArpRequest]
                    lappend FinalList $TempVal
                }
                -igmpframe -
                -igmprxframe {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -rxIgmpFrames]
                    lappend FinalList $TempVal
                }
                -vlanframe {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -vlanTaggedFramesRx]
                    lappend FinalList $TempVal
                }
                -flowcontrol {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -flowControlFrames]
                    lappend FinalList $TempVal
                }
                -qos0 {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -qualityOfService0]
                    lappend FinalList $TempVal
                }
                -qos1 {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -qualityOfService1]
                    lappend FinalList $TempVal
                }
                -qos2 {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -qualityOfService2]
                    lappend FinalList $TempVal
                }
                -qos3 {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -qualityOfService3]
                    lappend FinalList $TempVal
                }
                -qos4 {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -qualityOfService4]
                    lappend FinalList $TempVal
                }
                -qos5 {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -qualityOfService5]
                    lappend FinalList $TempVal
                }
                -qos6 {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -qualityOfService6]
                    lappend FinalList $TempVal
                }
                -qos7 {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -qualityOfService7]
                    lappend FinalList $TempVal
                }
                -udppacket {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -udpPackets]
                    lappend FinalList $TempVal
                }
                -tcppacket {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -tcpPackets]
                    lappend FinalList $TempVal
                }
                -tcpchecksumerror {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -tcpChecksumErrors]
                    lappend FinalList $TempVal
                }
                -udpchecksumerror {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -udpChecksumErrors]
                    lappend FinalList $TempVal
                }
                default     {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +1
            incr tmpllength -1
        }
        return $FinalList
    }

    #!!================================================================
    #�� �� ����     SmbSendModeSet
    #�� �� ����     IXIA
    #�������     
    #����������     ����Ixia������ģʽ/����
    #               ע��:�����������ڴ�����֮�����ʹ��,������Ч,��Ϊ��������Ƕ��ض��˿��ϵ��ض�
    #               ���������޸�, ����,����ʹ������IxMetricModeSet�����ĺ���������֮�����ʹ���������.
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:      Ixia��hub��
    #               Card:      Ixia�ӿڿ����ڵĲۺ�
    #               Port:      Ixia�ӿڿ��Ķ˿ں�    
    #               enumSendMode:
    #                               CONT ��������ģʽ
    #                               SINGLEBURST һ��ͻ��ģʽ
    #                               MULTIBURST ���ͻ��ģʽ
    #                               CONTBURST ����ͻ��ģʽ
    #                               ECHO Echo����ģʽ
    #               args: (��ѡ����,����±�)
    #                       -pps    ÿ���ӷ��͵İ�����ȱʡ�����Ϊ������
    #                       -rate   �������ʰٷֱȣ�ȱʡ�����100�����ʷ���,Ĭ��100
    #                       -bps    ÿ�뷢���ֽ�����ȱʡ�����Ϊ������
    #                       -singleburst    SingleBurst�ı��ĸ�����ȱʡΪ100
    #                       -multiburst     Multi Burst��ͻ���ܴ�����ȱʡΪ1
    #                       -perburst       ÿ��Burst�ı�����������MultiBurst��ContBurst��Ч����ȱʡΪ100
    #                       -burstgap       ÿ��ͻ��֮��ļ����ʱ��ֵ�ĵ�λͳһΪus������MultiBurst��ContBurst��Ч��
    #                       -gelen          ���ĳ���(��GE/FE������Ч),Ĭ��64
    #                       -felen          ���ĳ���(��GE/FE������Ч),Ĭ��64
    #                       -index          ָ�����ı��(�����п���Ч),Ĭ��Ϊ1  
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 10:59:17
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbSendModeSet  {Chas Card Port enumSendMode args} {
        #added by yuzhenpin 61733 2009-4-7 19:21:28
        SmbPortReserve $Chas $Card $Port
        #end of added
        
        set args [string tolower $args]
        set retVal     0

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        #  Set the defaults
        set Pps         0
        set Rate        0
        set Bps         0
        set Singleburst 100
        set Multiburst  1
        set Perburst    100
        set Gelen       64
        set Felen       $Gelen
                        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -pps        {set Pps $argx}
                -rate       {set Rate $argx}
                -bps        {set Bps $argx}
                -singleburst {set Singleburst $argx}
                -multiburst {set Multiburst $argx}
                -burstgap   {set  Burstgap $argx}
                -perburst   {set Perburst $argx}
                -gelen      {set Gelen $argx}
                -felen      {set Felen $argx}
                -index      {set Index $argx}
                default     {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }        
            
        set streamCnt	[ port getStreamCount $Chas $Card $Port ]
        
        for { set Index 1 } { $Index <= $streamCnt } { incr Index } {
            
			        if [stream get $Chas $Card $Port $Index] {
			            IxPuts -red "Unable to retrive No.$Index Stream's config from Port$Chas $Card $Port!"
			            set retVal 1
			        }
			        
			        #####Modify Stream
			        set enumSendMode [string toupper $enumSendMode]
puts "port transmit mode: $enumSendMode"
			        switch  $enumSendMode {
			            CONT        {
			                    stream config -dma contPacket
			            }
			            SINGLEBURST {
			                    stream config -dma stopStream
			                    stream config -numBursts 1
			                    stream config -numFrames $Singleburst
			            }
			            MULTIBURST  {
			                    stream config -dma advance
			                    stream config -enableIbg true
			                    stream config -numBursts $Multiburst
			                    stream config -numFrames $Perburst
			                    stream config -ibg [expr $Burstgap / 1000.00]
			            }
			            CONTBURST    {
			                    stream config -dma contBurst
			                    stream config -enableIbg true
			                    stream config -numFrames $Perburst
			                    stream config -ibg [expr $Burstgap / 1000.00]
			            }
			            ECHO        {
			                port config -transmitMode portTxModeEcho
			                port set $Chas $Card $Port
			                if [port write $Chas $Card $Port] {
			                    IxPuts -red "set port to ECHO mode failed!"        
			                }
			            }
			            default {
			#                set retVal 1
			#                IxPuts -red "No such Transmit mode, please check 'enumSendMode' "
			#                return $retVal
			            }
			        }
			        #�û�û���������������
			        if {($Pps == 0) && ($Rate == 0) && ($Bps == 0)} {
			            stream config -rateMode usePercentRate
			            stream config -percentPacketRate $Rate    
			        }
			        			        
			        if { $Rate != 0 } {
			        	#�û�ѡ���԰ٷֱ���������
			            stream config -rateMode usePercentRate
			            stream config -percentPacketRate $Rate
			        } elseif { ($Pps != 0) && ($Rate == 0) } {
			        	#�û�ѡ����ppsΪ��λ�����
			        	stream config -rateMode streamRateModeFps
			            stream config -fpsRate $Pps
			        } elseif { ($Bps != 0) && ($Rate == 0) && ($Pps == 0) } {
			        	#�û�ѡ����bpsΪ��λ�����
			        	stream config -rateMode streamRateModeBps
			            stream config -bpsRate $Bps
			        }
			       		        
			        
			                
			        #�û�û���������64
			        if {($Gelen == 64) && ($Felen == 64)} {
			            stream config -framesize 64    
			        }
			        
			        #�û�ѡ��GelenΪ����
			        if {($Gelen == 64) && ($Felen != 64)} {
			            #stream config -framesize $Felen
			            stream config -framesize [expr $Felen + 4]
			        }
			        #�û�ѡ����FelenΪ����
			        if {($Gelen == 64) && ($Felen == 64)} {     
			            #stream config -framesize $Gelen
			            stream config -framesize [expr $Gelen + 4]
			        }    
			              
			        if [stream set $Chas $Card $Port $Index] {
			            IxPuts -red "Unable to set No.$Index Stream's config to IxHal!"
			            set retVal 1
			        }
			        
			        #-- Edit by Eric Yu to fix the bug that ixWriteConfigToHardware will stop capture
			        #lappend portList [list $Chas $Card $Port]
			        #if [ixWriteConfigToHardware portList -noProtocolServer ] {
			        #    IxPuts -red "Unable to write No.$Index Stream's configs to hardware!"
			        #    set retVal 1
			        #} 
			        
			        if [stream write $Chas $Card $Port $Index] {
			            IxPuts -red "Unable to write No.$Index Stream's config to IxHal!"
			            catch { ixputs $::ixErrorInfo} err
			            set retVal 1
			        }
        
        }
        
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbSendTrafficGet
    #�� �� ����     IXIA
    #�������     
    #����������     ͳ�ƶ˿ڷ��͵���Ŀ������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:         Ixia��hub��
    #               Card:         Ixia�ӿڿ����ڵĲۺ�
    #               Port:         Ixia�ӿڿ��Ķ˿ں�   
    #               args:    
    #                       -frame      �յ�����֡��
    #                       -packet
    #                       -framerate  �յ���֡���ʣ���/S��
    #                       -arprequest
    #                       -arpreply
    #			    -igmpframe
    #			    -byte
    #			    -pingrequest
    #			    -pingreply
    #�� �� ֵ��     ��������һ���б�,�б��еĵ�һ��Ԫ���Ǻ���ִ�н��:
    #               0 - ��ʾ����ִ������
    #               1 - ��ʾ����ִ���쳣
    #               ���б�ĵڶ���Ԫ�ؿ�ʼ���û�����ļ���������.
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 11:26:42
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbSendTrafficGet {Chas Card Port args} {
        set retVal     0

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        set FinalList ""
        
        if [stat get statAllStats $Chas $Card $Port] {
            IxPuts -red "Get all Event counters Error"
            set retVal 1
        }
        if [stat getRate allStats $Chas $Card $Port] {
            IxPuts -red "Get all Rate counters Error"
            set retVal 1
        }
        lappend FinalList $retVal
            
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]

            case $cmdx      {
                -frame    {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -framesSent]
                    lappend FinalList $TempVal
                }
                -packet   {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -framesSent]
                    lappend FinalList $TempVal
                }
                -byte   {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -bytesSent]
                    lappend FinalList $TempVal
                }
                -framerate      {
                    stat getRate allStats $Chas $Card $Port
                    set TempVal [stat cget -framesSent]
                    lappend FinalList $TempVal
                }
                -jumborate      {
                    lappend FinalList -1
                } 
                
                -arpreply   {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -txArpReply]
                    lappend FinalList $TempVal
                }
                -arprequest {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -txArpRequest]
                    lappend FinalList $TempVal
                }
                -igmpframe  {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -txIgmpFrames]
                    lappend FinalList $TempVal
                }
                -pingreply {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -txPingReply]
                    lappend FinalList $TempVal
                }
                -pingrequest {
                    stat get statAllStats $Chas $Card $Port
                    set TempVal  [stat cget -txPingRequest]
                    lappend FinalList $TempVal
                }
                default     {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +1
            incr tmpllength -1
        }
        return $FinalList            
    }

    #!!================================================================
    #�� �� ����     SmbSlotRelease
    #�� �� ����     IXIA
    #�������     
    #����������     �ͷ�Ixia�˿�,ע��,��ΪIxia���������,�������ͷŶ˿ڶ����Զ˿�Ϊ��λ��,
    #               �������������Ȼ������ԭ��������,��������������ͬ,����Ҫ��3����������
    #               ����ͷŵĹ���,�� Chas Card Port
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں� 
    #               Mode, ȱʡֵ��noForce:    
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:41:4
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbSlotRelease {Chas Card {Mode noForce}} {
        #added by yuzhenpin 61733 2009-4-7 19:05:51
        variable m_portList
        set m_portList [list]
        #end of added
        
        set retVal 0
        lappend portList [list $Chas $Card * ]
        
        #һ�ſ��ϵĽӿ��ǿ��Ա������ռ��
        #����ͷſ��ܻᡰʧ�ܡ�
        #Ϊ�˸�smartbits����
        #���ﲻ���ش���
        if [ixClearOwnership $portList $Mode] {
            IxPuts -red "unable to release $Chas $Card *!"
            #set retVal 1
        }
        return $retVal         
    }

    #!!================================================================
    #�� �� ����     SmbSlotReserve
    #�� �� ����     IXIA
    #�������     
    #����������     ռ��ixia�Ǳ�˿�
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:    Ixia��hub��
    #               Card:    Ixia�ӿڿ����ڵĲۺ�  
    #               args:    
    #                      -list:Ixia�ӿڿ��Ķ˿ں��б���{1 2 3} 
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 14:5:22
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbSlotReserve {Chas Card args} {
    
        #added by yuzhenpin 61733 2009-4-7 18:54:27
        #�� $Chas $Card * �ķ�ʽռ�ö˿�
        #�Ὣ������ϵ����ж˿ڶ�ռ��
        #�ĳɾ�ȷ�Ļ�ȡĳ���˿�
        #����ֱ�ӷ���
        #�������еĶ˿ڶ�����ռ�õķ�ʽʹ��
        return 0
        #end of added
    
       set retVal 0
       set length [llength $args]
       if {$length == 0} {
           lappend PortList [list $Chas $Card *]
       } else {
           lappend args $Card
           set args [Common::ListUnique $args]
           foreach pId $args {
               lappend PortList [list $Chas $pId]
           }
       }
       
       set UserName [info hostname]
       ixLogin $UserName
       if {[ixTakeOwnership $PortList]} {
           IxPuts -red "unable to reserve $PortList"
           set retVal 1
      }
      
      return $retVal
    }
    
    #!!================================================================
    #�� �� ����     SmbTcpPacketSet
    #�� �� ����     IXIA
    #�������     
    #����������     TCP������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�    
    #               DstMac:        Ŀ��Mac��ַ
    #               DstIP:         Ŀ��IP��ַ
    #               SrcMac:        ԴMac��ַ
    #               SrcIP:         ԴIP��ַ
    #               args: (��ѡ����,����±�)
    #                       -streamid       ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
    #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
    #                       -vlan           Vlan tag,����,Ĭ��0,����û��VLAN Tag,����0��ֵ�Ų���VLAN tag.
    #                       -pri            Vlan�����ȼ�����Χ0��7��ȱʡΪ0
    #                       -cfi            Vlan�������ֶΣ���Χ0��1��ȱʡΪ0
    #                       -type           ����ETHЭ�����ͣ�ȱʡֵ "08 00"
    #                       -ver            ����IP�汾��ȱʡֵ4
    #                       -iphlen         IP����ͷ���ȣ�ȱʡֵ5
    #                       -tos            IP���ķ������ͣ�ȱʡֵ0
    #                       -dscp           DSCP ֵ,ȱʡֵ0
    #                       -tot            IP���ɳ��ȣ�ȱʡֵ���ݱ��ĳ��ȼ���
    #                       -id             ���ı�ʶ�ţ�ȱʡֵ1
    #                       -mayfrag        �Ƿ�ɷ�Ƭ��־, 0:�ɷ�Ƭ, 1:����Ƭ
    #                       -lastfrag       ���Ƭ�������һƬ, 0: ���һƬ(ȱʡֵ), 1:�������һƬ
    #                       -fragoffset     ��Ƭ��ƫ������ȱʡֵ0
    #                       -ttl            ��������ʱ��ֵ��ȱʡֵ255
    #                       -pro            ����IPЭ�����ͣ�ȱʡֵ4
    #                       -change         �޸����ݰ��е�ָ���ֶΣ��˲�����ʶ�޸��ֶε��ֽ�ƫ����,Ĭ��ֵ,���һ���ֽ�(CRCǰ).
    #                       -value          �޸����ݵ�����, Ĭ��ֵ {{00 }}, 16���Ƶ�ֵ.
    #                       -enable         �Ƿ�ʹ��������Ч true / false
    #                       -sname          ������������,����Ϸ����ַ���.Ĭ��Ϊ""
    #                       -strtransmode   ���������͵�ģʽ,����0:�������� 1:������ָ������Ŀ��ֹͣ 2:�����걾���������������һ����.
    #                       -strframenum    ���屾�������͵İ���Ŀ
    #                       -strrate        ��������,���ٵİٷֱ�. 100 �������ٵ� 100%, 1 �������ٵ� 1%
    #                       -strburstnum    ���屾�����������ٸ�burst,ȡֵ��Χ1~65535,Ĭ��Ϊ1
    #
    #                       -srcport        TCPԴ�˿ڣ�ȱʡֵ0, ʮ������ֵ
    #                       -dstport        TCPĿ�Ķ˿ڣ�ȱʡֵ0, ʮ������ֵ
    #                       -seq         TCP���кţ�ȱʡֵ0, ʮ������ֵ
    #                       -ack         TCPȷ�Ϻţ�ȱʡֵ0, ʮ������ֵ
    #                       -tcpopt         TCP��������ֵ��ȱʡֵ ""
    #                       -window         ���ڴ�С��ȱʡֵ0, ʮ������ֵ
    #                       -urgent         ����ָ�룬ȱʡֵ0, ʮ������ֵ
    #
    #                       -udf1           �Ƿ�ʹ��UDF1,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf1offset     UDFƫ����
    #                       -udf1len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf1initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf1step       UDF�仯����,Ĭ��1
    #                       -udf1changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf1repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf2           �Ƿ�ʹ��UDF2,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf2offset     UDFƫ����
    #                       -udf2len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf2initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf2step       UDF�仯����,Ĭ��1
    #                       -udf2changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf2repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf3           �Ƿ�ʹ��UDF3,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf3offset     UDFƫ����
    #                       -udf3len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf3initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf3step       UDF�仯����,Ĭ��1
    #                       -udf3changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf3repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf4           �Ƿ�ʹ��UDF4,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf4offset     UDFƫ����
    #                       -udf4len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf4initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf4step       UDF�仯����,Ĭ��1
    #                       -udf4changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf4repeat     UDF����/�ݼ��Ĵ���, 1~n ����
    #
    #                       -udf5           �Ƿ�ʹ��UDF5,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
    #                       -udf5offset     UDFƫ����
    #                       -udf5len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
    #                       -udf5initval    UDF��ʼֵ,Ĭ�� {00}
    #                       -udf5step       UDF�仯����,Ĭ��1
    #                       -udf5changemode UDF�仯����, 0:����, 1:�ݼ�
    #                       -udf5repeat     UDF����/�ݼ��Ĵ���, 1~n ����    
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-14 9:12:5
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbTcpPacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP args} {  
        set retVal     0

        if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP $args"] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]

        #��ŵ edit 2006��07-21 mac��ַת�� 
        set DstMac [StrMacConvertList $DstMac]
        set SrcMac [StrMacConvertList $SrcMac]
        
        #  Set the defaults
        set streamId   1
        set Sname      ""
        set Length     64
        set Vlan       0
        set Pri        0
        set Cfi        0
        set Type       "08 00"
        set Ver        4
        set Iphlen     5
        set Tos        0
        set Dscp       0
        set Tot        0
        set Id         1
        set Mayfrag    0
        set Lastfrag   0
        set Fragoffset 0
        set Ttl        255        
        set Pro        4
        set Change     0
        set Enable     true
        set Value      {{00 }}
        set Strtransmode 0
        set Strframenum  100
        set Strrate      100
        set Strburstnum  1
        set Srcport    0
        set Dstport    0 
        set Seq        0
        set Ack        0
        set Tcpopt     ""
        set Window     0
        set Urgent     0    
        
        set Udf1       0
        set Udf1offset 0
        set Udf1len    1
        set Udf1initval {00}
        set Udf1step    1
        set Udf1changemode 0
        set Udf1repeat  1
            
        set Udf2       0
        set Udf2offset 0
        set Udf2len    1
        set Udf2initval {00}
        set Udf2step    1
        set Udf2changemode 0
        set Udf2repeat  1
            
        set Udf3       0
        set Udf3offset 0
        set Udf3len    1
        set Udf3initval {00}
        set Udf3step    1
        set Udf3changemode 0
        set Udf3repeat  1
            
        set Udf4       0
        set Udf4offset 0
        set Udf4len    1
        set Udf4initval {00}
        set Udf4step    1
        set Udf4changemode 0
        set Udf4repeat  1        
        
        set Udf5       0
        set Udf5offset 0
        set Udf5len    1
        set Udf5initval {00}
        set Udf5step    1
        set Udf5changemode 0
        set Udf5repeat  1
                        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -streamid   {set streamId $argx}
                -sname      {set Sname $argx}
                -length     {set Length $argx}
                -vlan       {set Vlan $argx}
                -pri        {set Pri $argx}
                -cfi        {set Cfi $argx}
                -type       {set Type $argx}
                -ver        {set Ver $argx}
                -iphlen     {set Iphlen $argx}
                -tos        {set Tos $argx}
                -dscp       {set Dscp $argx}
                -tot        {set Tot  $argx}
                -mayfrag    {set Mayfrag $argx}
                -lastfrag   {set Lastfrag $argx}
                -fragoffset {set Fragoffset $argx}
                -ttl        {set Ttl $argx}
                -id         {set Id $argx}
                -pro        {set Pro $argx}
                -change     {set Change $argx}
                -value      {set Value $argx}
                -enable     {set Enable $argx}
                -strtransmode { set Strtransmode $argx}
                -strframenum {set Strframenum $argx}
                -strrate     {set Strrate $argx}
                -strburstnum {set Strburstnum $argx}
                -srcport     {set Srcport $argx}
                -dstport     {set Dstport $argx}
                -seq         {set Seq $argx}
                -ack         {set Ack $argx}
                -tcpopt      {set Tcpopt $argx}
                -window      {set Window $argx}
                -urgent      {set Urgent $argx}
                
                -udf1           {set Udf1 $argx}
                -udf1offset     {set Udf1offset $argx}
                -udf1len        {set Udf1len $argx}
                -udf1initval    {set Udf1initval $argx}  
                -udf1step       {set Udf1step $argx}
                -udf1changemode {set Udf1changemode $argx}
                -udf1repeat     {set Udf1repeat $argx}
                
                -udf2           {set Udf2 $argx}
                -udf2offset     {set Udf2offset $argx}
                -udf2len        {set Udf2len $argx}
                -udf2initval    {set Udf2initval $argx}  
                -udf2step       {set Udf2step $argx}
                -udf2changemode {set Udf2changemode $argx}
                -udf2repeat     {set Udf2repeat $argx}
                            
                -udf3           {set Udf3 $argx}
                -udf3offset     {set Udf3offset $argx}
                -udf3len        {set Udf3len $argx}
                -udf3initval    {set Udf3initval $argx}  
                -udf3step       {set Udf3step $argx}
                -udf3changemode {set Udf3changemode $argx}
                -udf3repeat     {set Udf3repeat $argx}
                
                -udf4           {set Udf4 $argx}
                -udf4offset     {set Udf4offset $argx}
                -udf4len        {set Udf4len $argx}
                -udf4initval    {set Udf4initval $argx}  
                -udf4step       {set Udf4step $argx}
                -udf4changemode {set Udf4changemode $argx}
                -udf4repeat     {set Udf4repeat $argx}
                
                -udf5           {set Udf5 $argx}
                -udf5offset     {set Udf5offset $argx}
                -udf5len        {set Udf5len $argx}
                -udf5initval    {set Udf5initval $argx}  
                -udf5step       {set Udf5step $argx}
                -udf5changemode {set Udf5changemode $argx}
                -udf5repeat     {set Udf5repeat $argx}
                         
                default {
                    set retVal 1
                    IxPuts -red "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
                incr idxxx  +2
                incr tmpllength -2
            }
            
            #Define Stream parameters.
            stream setDefault        
            stream config -enable $Enable
            stream config -name $Sname
            stream config -numBursts $Strburstnum        
            stream config -numFrames $Strframenum
            stream config -percentPacketRate $Strrate
            stream config -rateMode usePercentRate
            stream config -sa $SrcMac
            stream config -da $DstMac
            switch $Strtransmode {
                0 {stream config -dma contPacket}
                1 {stream config -dma stopStream}
                2 {stream config -dma advance}
                default {
                    set retVal 1
                    IxPuts -red "No such stream transmit mode, please check -strtransmode parameter."
                    return $retVal
                }
            }
            
            if {$Length != 0} {
                #stream config -framesize $Length
                stream config -framesize [expr $Length + 4]
                stream config -frameSizeType sizeFixed
            } else {
                stream config -framesize 318
                stream config -frameSizeType sizeRandom
                stream config -frameSizeMIN 64
                stream config -frameSizeMAX 1518       
            }
            
            stream config -frameType $Type
            
            #Define protocol parameters 
            protocol setDefault        
            protocol config -name ipV4        
            protocol config -ethernetType ethernetII
            
            ip setDefault        
            ip config -ipProtocol ipV4ProtocolTcp
            ip config -identifier   $Id
            #ip config -totalLength 46
            switch $Mayfrag {
                0 {ip config -fragment may}
                1 {ip config -fragment dont}
            }       
            switch $Lastfrag {
                0 {ip config -fragment last}
                1 {ip config -fragment more}
            }       

            ip config -fragmentOffset 1
            ip config -ttl $Ttl        
            ip config -sourceIpAddr $SrcIP
            ip config -destIpAddr   $DstIP
            if [ip set $Chas $Card $Port] {
                IxPuts -red "Unable to set IP configs to IxHal!"
                set retVal 1
            }
            #Dinfine TCP protocol
            tcp setDefault        
            #tcp config -offset 5
            tcp config -sourcePort $Srcport
            tcp config -destPort $Dstport
            tcp config -sequenceNumber $Seq
            tcp config -acknowledgementNumber $Ack
            tcp config -window $Window
            tcp config -urgentPointer $Urgent
            tcp config -options  $Tcpopt
            #tcp config -urgentPointerValid false
            #tcp config -acknowledgeValid false
            #tcp config -pushFunctionValid false
            #tcp config -resetConnection false
            #tcp config -synchronize false
            #tcp config -finished false
            #tcp config -useValidChecksum true
            if [tcp set $Chas $Card $Port] {
                IxPuts -red "Unable to set Tcp configs to IxHal!"
                set retVal 1
            }
            
            if {$Vlan != 0} {
                protocol config -enable802dot1qTag vlanSingle
                vlan setDefault        
                vlan config -vlanID $Vlan
                vlan config -userPriority $Pri
                if [vlan set $Chas $Card $Port] {
                    IxPuts -red "Unable to set Vlan configs to IxHal!"
                    set retVal 1
                }
            }
            switch $Cfi {
                0 {vlan config -cfi resetCFI}
                1 {vlan config -cfi setCFI}
            }
            
            #UDF Config
            
            if {$Udf1 == 1} {
                udf setDefault        
                udf config -enable true
                udf config -offset $Udf1offset
                switch $Udf1len {
                    1 { udf config -countertype c8  }                
                    2 { udf config -countertype c16 }               
                    3 { udf config -countertype c24 }                
                    4 { udf config -countertype c32 }
                }
                switch $Udf1changemode {
                    0 {udf config -updown uuuu}
                    1 {udf config -updown dddd}
                }
                udf config -initval $Udf1initval
                udf config -repeat  $Udf1repeat              
                udf config -step    $Udf1step
                udf set 1
            }
            if {$Udf2 == 1} {
                udf setDefault        
                udf config -enable true
                udf config -offset $Udf2offset
                switch $Udf2len {
                    1 { udf config -countertype c8  }                
                    2 { udf config -countertype c16 }               
                    3 { udf config -countertype c24 }                
                    4 { udf config -countertype c32 }
                }
                switch $Udf2changemode {
                    0 {udf config -updown uuuu}
                    1 {udf config -updown dddd}
                }
                udf config -initval $Udf2initval
                udf config -repeat  $Udf2repeat              
                udf config -step    $Udf2step
                    udf set 2
            }
            if {$Udf3 == 1} {
                udf setDefault        
                udf config -enable true
                udf config -offset $Udf3offset
                switch $Udf3len {
                    1 { udf config -countertype c8  }                
                    2 { udf config -countertype c16 }               
                    3 { udf config -countertype c24 }                
                    4 { udf config -countertype c32 }
                }
                switch $Udf3changemode {
                    0 {udf config -updown uuuu}
                    1 {udf config -updown dddd}
                }
                udf config -initval $Udf3initval
                udf config -repeat  $Udf3repeat              
                udf config -step    $Udf3step
                udf set 3
            }
            if {$Udf4 == 1} {
                udf setDefault        
                udf config -enable true
                udf config -offset $Udf4offset
                switch $Udf4len {
                    1 { udf config -countertype c8  }                
                    2 { udf config -countertype c16 }               
                    3 { udf config -countertype c24 }                
                    4 { udf config -countertype c32 }
                }
                switch $Udf4changemode {
                    0 {udf config -updown uuuu}
                    1 {udf config -updown dddd}
                }
                udf config -initval $Udf4initval
                udf config -repeat  $Udf4repeat              
                udf config -step    $Udf4step
                udf set 4
            }
            if {$Udf5 == 1} {
                udf setDefault        
                udf config -enable true
                udf config -offset $Udf5offset
                switch $Udf5len {
                    1 { udf config -countertype c8  }                
                    2 { udf config -countertype c16 }               
                    3 { udf config -countertype c24 }                
                    4 { udf config -countertype c32 }
                }
                switch $Udf5changemode {
                    0 {udf config -updown uuuu}
                    1 {udf config -updown dddd}
                }
                udf config -initval $Udf5initval
                udf config -repeat  $Udf5repeat              
                udf config -step    $Udf5step
                udf set 5
            }        
            
            
            #Table UDF Config        
            tableUdf setDefault        
            tableUdf clearColumns      
            tableUdf config -enable 1
            tableUdfColumn setDefault        
            tableUdfColumn config -formatType formatTypeHex
            if {$Change == 0} {
                tableUdfColumn config -offset [expr $Length -5]} else {
                tableUdfColumn config -offset $Change
            }
            tableUdfColumn config -size 1
            tableUdf addColumn         
            set rowValueList $Value
            tableUdf addRow $rowValueList
            if [tableUdf set $Chas $Card $Port] {
                IxPuts -red "Unable to set TableUdf to IxHal!"
                set retVal 1
            }

            #Final writting....        
            if [stream set $Chas $Card $Port $streamId] {
                IxPuts -red "Unable to set streams to IxHal!"
                set retVal 1
            }
            
            incr streamId
            lappend portList [list $Chas $Card $Port]
            if [ixWriteConfigToHardware portList -noProtocolServer ] {
                IxPuts -red "Unable to write configs to hardware!"
                set retVal 1
            }          
            return $retVal          
    }

    #!!================================================================
    #�� �� ����     SmbTriggerSet
    #�� �� ����     IXIA
    #�������     
    #����������     Ixia�˿ڽ��ձ���Trigger(ģʽ������)����
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�   
    #               enumParttern:  trigger��ģʽ
    #                                     ONLYTRI1 ֻƥ��Trigger1��ȱʡֵ
    #                                     ONLYTRI2 ֻƥ��Trigger2
    #                                     TRI1ANDTRI2 ͬʱƥ��Trigger1��Trigger2
    #               args:           -offset1 intOffset1 -   Trigger1��ƫ����
    #                               -length1 intLength1 -   Trigger1��ƥ���ֽڳ���
    #                               -value1 strValue1   -   Trigger1��ƥ��ֵ
    #                               -offset2 intOffset2 -   Trigger2��ƫ����
    #                               -length2 intLength2 -   Trigger2��ƥ���ֽڳ���
    #                               -value2 strValue2   -   Trigger2��ƥ��ֵ
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:46:32
    #�޸ļ�¼��     2009-05-17 ������ ��-value1/-value2����ֵ����ת��,ʹ�������ʽ��SMBһ��(10���ƿո�ָ��ַ���)���ܹ���Ч
    #               2009-07-23 ������ ��дӲ����API��ixWritePortsToHardware��ΪixWriteConfigToHardware,��ֹ������·down�����
    #!!================================================================
    proc SmbTriggerSet {Chas Card Port enumParttern args} {
        set args [string tolower $args]
        set retVal     0

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        #  Set the defaults
        set Offset1      0
        set Length1      0
        set Value1       0
        set Offset2      0
        set Length2      0
        set Value2       0
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                 -offset1      {set Offset1 $argx}
                 -length1      {set Length1 $argx}
                 -value1       {set Value1 $argx}
                 -offset2      {set Offset2 $argx}
                 -length2      {set Length2 $argx}
                 -value2       {set Value2 $argx}
                 default     {
                     set  retVal 1
                     IxPuts -red "Error : cmd option $cmdx does not exist"
                     return $retVal
                 }
            }
            incr idxxx  +2
            incr tmpllength -2
        }        
        # add by chenshibing 2009-05-17
        set tmpValue1 ""
		set tmpMask1 ""
        foreach key $Value1 {
            append tmpValue1 [format "%02X " $key]
            append tmpMask1 [format "%02X " 0]
        }
        set Value1 [string trim $tmpValue1]
        set Mask1  [string trim $tmpMask1 ]
        set tmpValue2 ""
		set tmpMask2 ""
        foreach key $Value2 {
            append tmpValue2 [format "%02X " $key]
            append tmpMask2 [format "%02X " 0]
        }
        set Value2 [string trim $tmpValue2]
        set Mask2  [string trim $tmpMask2 ]
        # add end
        set enumParttern [string toupper $enumParttern]
        switch $enumParttern {
            "ONLYTRI1" {
                set TriggerMode pattern1 
            }
            "ONLYTRI2" {
                set TriggerMode pattern2
            }
            "TRI1ANDTRI2" {
                set TriggerMode pattern1AndPattern2
            }
            "TRI1ORTRI2" {
                set TriggerMode 6
            }
            
        }
        capture                      setDefault        
        capture                      set               $Chas $Card $Port
        filter                       setDefault        
		#====================
		# Modify by Eric Yu
        # #filter                       config            -captureTriggerPattern              pattern1AndPattern2
        # filter                       config            -captureTriggerPattern              $TriggerMode
        # #filter                       config            -captureFilterEnable                false
        # filter                       config            -captureFilterEnable                true
		filter config -userDefinedStat1Pattern $TriggerMode
		filter config -userDefinedStat1Enable true
		filter config -captureFilterPattern $TriggerMode
		filter config -captureFilterEnable true
		filter config -captureTriggerPattern $TriggerMode
		filter config -captureTriggerEnable true
        filter                       set               $Chas $Card $Port
        filterPallette setDefault        
        filterPallette config -pattern1 $Value1
        filterPallette config -pattern2 $Value2
        filterPallette config -patternOffset1 $Offset1
        filterPallette config -patternOffset2 $Offset2
 		filterPallette config -patternMask1 $Mask1
		filterPallette config -patternMask2 $Mask2
		#====================
        filterPallette set $Chas $Card $Port
        lappend portList [list $Chas $Card $Port]
        #modify by chenshibing 2009-07-23 from ixWritePortsToHardware to ixWriteConfigToHardware
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            set retVal 1
        }
#        if [ixCheckLinkState portList] {
#            IxPuts -red "Unable to write trigger configs to $Chas $Card $Port!"
#            set retVal 1
#        }
        return $retVal       
    }

    #!!================================================================
   #�� �� ����     IxUdpPacketSet
   #�� �� ����     IXIA
   #�������     
   #����������     UDP������
   #�÷���         
   #ʾ����         
   #               
   #����˵����     
   #               Chas:          Ixia��hub��
   #               Card:          Ixia�ӿڿ����ڵĲۺ�
   #               Port:          Ixia�ӿڿ��Ķ˿ں�     
   #               DstMac:        Ŀ��Mac��ַ
   #               DstIP:         Ŀ��IP��ַ
   #               SrcMac:        ԴMac��ַ
   #               SrcIP:         ԴIP��ַ
   #               args: (��ѡ����,����±�)
   #                       -streamid       ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
   #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
   #                       -vlan           Vlan tag,����,Ĭ��0,����û��VLAN Tag,����0��ֵ�Ų���VLAN tag.
   #                       -pri            Vlan�����ȼ�����Χ0��7��ȱʡΪ0
   #                       -cfi            Vlan�������ֶΣ���Χ0��1��ȱʡΪ0
   #                       -type           ����ETHЭ�����ͣ�ȱʡֵ "08 00"
   #                       -ver            ����IP�汾��ȱʡֵ4
   #                       -iphlen         IP����ͷ���ȣ�ȱʡֵ5
   #                       -tos            IP���ķ������ͣ�ȱʡֵ0
   #                       -dscp           DSCP ֵ,ȱʡֵ0
   #                       -tot            IP���ɳ��ȣ�ȱʡֵ���ݱ��ĳ��ȼ���
   #                       -id             ���ı�ʶ�ţ�ȱʡֵ1
   #                       -mayfrag        �Ƿ�ɷ�Ƭ��־, 0:�ɷ�Ƭ, 1:����Ƭ
   #                       -lastfrag       ���Ƭ�������һƬ, 0: ���һƬ(ȱʡֵ), 1:�������һƬ
   #                       -fragoffset     ��Ƭ��ƫ������ȱʡֵ0
   #                       -ttl            ��������ʱ��ֵ��ȱʡֵ255
   #                       -pro            ����IPЭ�����ͣ�ȱʡֵ4
   #                       -change         �޸����ݰ��е�ָ���ֶΣ��˲�����ʶ�޸��ֶε��ֽ�ƫ����,Ĭ��ֵ,���һ���ֽ�(CRCǰ).
   #                       -5          �޸����ݵ�����, Ĭ��ֵ {{00 }}, 16���Ƶ�ֵ.
   #                       -enable         �Ƿ�ʹ��������Ч true / false
   #                       -sname          ������������,����Ϸ����ַ���.Ĭ��Ϊ""
   #                       -strtransmode   ���������͵�ģʽ,����0:�������� 1:������ָ������Ŀ��ֹͣ 2:�����걾���������������һ����.
   #                       -strframenum    ���屾�������͵İ���Ŀ
   #                       -strrate        ��������,���ٵİٷֱ�. 100 �������ٵ� 100%, 1 �������ٵ� 1%
   #                       -strburstnum    ���屾�����������ٸ�burst,ȡֵ��Χ1~65535,Ĭ��Ϊ1
   #
   #                       -srcport        UDPԴ�˿ڣ�ȱʡֵ0, ʮ������ֵ
   #                       -dstport        UDPĿ�Ķ˿ڣ�ȱʡֵ0, ʮ������ֵ
   #
   #                       -udf1           �Ƿ�ʹ��UDF1,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
   #                       -udf1offset     UDFƫ����
   #                       -udf1len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
   #                       -udf1initval    UDF��ʼֵ,Ĭ�� {00}
   #                       -udf1step       UDF�仯����,Ĭ��1
   #                       -udf1changemode UDF�仯����, 0:����, 1:�ݼ�
   #                       -udf1repeat     UDF����/�ݼ��Ĵ���, 1~n ����
   #
   #                       -udf2           �Ƿ�ʹ��UDF2,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
   #                       -udf2offset     UDFƫ����
   #                       -udf2len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
   #                       -udf2initval    UDF��ʼֵ,Ĭ�� {00}
   #                       -udf2step       UDF�仯����,Ĭ��1
   #                       -udf2changemode UDF�仯����, 0:����, 1:�ݼ�
   #                       -udf2repeat     UDF����/�ݼ��Ĵ���, 1~n ����
   #
   #                       -udf3           �Ƿ�ʹ��UDF3,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
   #                       -udf3offset     UDFƫ����
   #                       -udf3len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
   #                       -udf3initval    UDF��ʼֵ,Ĭ�� {00}
   #                       -udf3step       UDF�仯����,Ĭ��1
   #                       -udf3changemode UDF�仯����, 0:����, 1:�ݼ�
   #                       -udf3repeat     UDF����/�ݼ��Ĵ���, 1~n ����
   #
   #                       -udf4           �Ƿ�ʹ��UDF4,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
   #                       -udf4offset     UDFƫ����
   #                       -udf4len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
   #                       -udf4initval    UDF��ʼֵ,Ĭ�� {00}
   #                       -udf4step       UDF�仯����,Ĭ��1
   #                       -udf4changemode UDF�仯����, 0:����, 1:�ݼ�
   #                       -udf4repeat     UDF����/�ݼ��Ĵ���, 1~n ����
   #
   #                       -udf5           �Ƿ�ʹ��UDF5,  0:��ʹ��,Ĭ��ֵ  1:ʹ��
   #                       -udf5offset     UDFƫ����
   #                       -udf5len        UDF����,��λ�ֽ�,ȡֵ��Χ1~4
   #                       -udf5initval    UDF��ʼֵ,Ĭ�� {00}
   #                       -udf5step       UDF�仯����,Ĭ��1
   #                       -udf5changemode UDF�仯����, 0:����, 1:�ݼ�
   #                       -udf5repeat     UDF����/�ݼ��Ĵ���, 1~n ����  
   #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
   #��    �ߣ�     ��׿
   #�������ڣ�     2006-7-14 9:21:9
   #�޸ļ�¼��     
   #!!================================================================
   proc SmbUdpPacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP args} {
       set retVal     0

       if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP $args"] == 1} {
           set retVal 1
           return $retVal
       }

       set tmpList    [lrange $args 0 end]
       set idxxx      0
       set tmpllength [llength $tmpList]

        #��ŵ edit 2006��07-21 mac��ַת�� 
        set DstMac [StrMacConvertList $DstMac]
        set SrcMac [StrMacConvertList $SrcMac]
       
       #  Set the defaults
       set streamId   1
       set Sname      ""
       set Length     64
       set Vlan       0
       set Pri        0
       set Cfi        0
       set Type       "08 00"
       set Ver        4
       set Iphlen     5
       set Tos        0
       set Dscp       0
       set Tot        0
       set Id         1
       set Mayfrag    0
       set Lastfrag   0
       set Fragoffset 0
       set Ttl        255        
       set Pro        4
       set Change     0
       set Enable     true
       set Value      {{00 }}
       set Strtransmode 0
       set Strframenum  100
       set Strrate      100
       set Strburstnum  1
       set Srcport      0
       set Dstport      0
           
       set Udf1       0
       set Udf1offset 0
       set Udf1len    1
       set Udf1initval {00}
       set Udf1step    1
       set Udf1changemode 0
       set Udf1repeat  1
       
       set Udf2       0
       set Udf2offset 0
       set Udf2len    1
       set Udf2initval {00}
       set Udf2step    1
       set Udf2changemode 0
       set Udf2repeat  1
       
       set Udf3       0
       set Udf3offset 0
       set Udf3len    1
       set Udf3initval {00}
       set Udf3step    1
       set Udf3changemode 0
       set Udf3repeat  1
       
       set Udf4       0
       set Udf4offset 0
       set Udf4len    1
       set Udf4initval {00}
       set Udf4step    1
       set Udf4changemode 0
       set Udf4repeat  1        
       
       set Udf5       0
       set Udf5offset 0
       set Udf5len    1
       set Udf5initval {00}
       set Udf5step    1
       set Udf5changemode 0
       set Udf5repeat  1
           
       while { $tmpllength > 0  } {
           set cmdx [lindex $args $idxxx]
           set argx [lindex $args [expr $idxxx + 1]]

           case $cmdx      {
               -streamid   {set streamId $argx}
               -sname      {set Sname $argx}
               -length     {set Length $argx}
               -vlan       {set Vlan $argx}
               -pri        {set Pri $argx}
               -cfi        {set Cfi $argx}
               -type       {set Type $argx}
               -ver        {set Ver $argx}
               -iphlen     {set Iphlen $argx}
               -tos        {set Tos $argx}
               -dscp       {set Dscp $argx}
               -tot        {set Tot  $argx}
               -mayfrag    {set Mayfrag $argx}
               -lastfrag   {set Lastfrag $argx}
               -fragoffset {set Fragoffset $argx}
               -ttl        {set Ttl $argx}
               -id         {set Id $argx}
               -pro        {set Pro $argx}
               -change     {set Change $argx}
               -value      {set Value $argx}
               -enable     {set Enable $argx}
               -strtransmode { set Strtransmode $argx}
               -strframenum {set Strframenum $argx}
               -strrate     {set Strrate $argx}
               -strburstnum {set Strburstnum $argx}
               -srcport     {set Srcport $argx}
               -dstport     {set Dstport $argx}
               
               -udf1           {set Udf1 $argx}
               -udf1offset     {set Udf1offset $argx}
               -udf1len        {set Udf1len $argx}
               -udf1initval    {set Udf1initval $argx}  
               -udf1step       {set Udf1step $argx}
               -udf1changemode {set Udf1changemode $argx}
               -udf1repeat     {set Udf1repeat $argx}
               
               -udf2           {set Udf2 $argx}
               -udf2offset     {set Udf2offset $argx}
               -udf2len        {set Udf2len $argx}
               -udf2initval    {set Udf2initval $argx}  
               -udf2step       {set Udf2step $argx}
               -udf2changemode {set Udf2changemode $argx}
               -udf2repeat     {set Udf2repeat $argx}
                           
               -udf3           {set Udf3 $argx}
               -udf3offset     {set Udf3offset $argx}
               -udf3len        {set Udf3len $argx}
               -udf3initval    {set Udf3initval $argx}  
               -udf3step       {set Udf3step $argx}
               -udf3changemode {set Udf3changemode $argx}
               -udf3repeat     {set Udf3repeat $argx}
               
               -udf4           {set Udf4 $argx}
               -udf4offset     {set Udf4offset $argx}
               -udf4len        {set Udf4len $argx}
               -udf4initval    {set Udf4initval $argx}  
               -udf4step       {set Udf4step $argx}
               -udf4changemode {set Udf4changemode $argx}
               -udf4repeat     {set Udf4repeat $argx}
               
               -udf5           {set Udf5 $argx}
               -udf5offset     {set Udf5offset $argx}
               -udf5len        {set Udf5len $argx}
               -udf5initval    {set Udf5initval $argx}  
               -udf5step       {set Udf5step $argx}
               -udf5changemode {set Udf5changemode $argx}
               -udf5repeat     {set Udf5repeat $argx}
            
               default {
                   set retVal 1
                   IxPuts -red "Error : cmd option $cmdx does not exist"
                   return $retVal
               }
           }
           incr idxxx  +2
           incr tmpllength -2
       }
           
       #Define Stream parameters.
       stream setDefault        
       stream config -enable $Enable
       stream config -name $Sname
       stream config -numBursts $Strburstnum        
       stream config -numFrames $Strframenum
       stream config -percentPacketRate $Strrate
       stream config -rateMode usePercentRate
       stream config -sa $SrcMac
       stream config -da $DstMac
       switch $Strtransmode {
           0 {stream config -dma contPacket}
           1 {stream config -dma stopStream}
           2 {stream config -dma advance}
           default {IxPuts -red "No such stream transmit mode, please check -strtransmode parameter."}
       }
           
       if {$Length != 0} {
           #stream config -framesize $Length
           stream config -framesize [expr $Length + 4]
           stream config -frameSizeType sizeFixed
       } else {
           stream config -framesize 318
           stream config -frameSizeType sizeRandom
           stream config -frameSizeMIN 64
           stream config -frameSizeMAX 1518       
       }
           
          
       stream config -frameType $Type
           
       #Define protocol parameters 
       protocol setDefault        
       protocol config -name ipV4        
       protocol config -ethernetType ethernetII
       
      
       ip setDefault        
       ip config -ipProtocol ipV4ProtocolUdp
       ip config -identifier   $Id
       #ip config -totalLength 46
       switch $Mayfrag {
           0 {ip config -fragment may}
           1 {ip config -fragment dont}
       }       
       switch $Lastfrag {
           0 {ip config -fragment last}
           1 {ip config -fragment more}
       }       

       ip config -fragmentOffset 1
       ip config -ttl $Ttl        
       ip config -sourceIpAddr $SrcIP
       ip config -destIpAddr   $DstIP
       if [ip set $Chas $Card $Port] {
           IxPuts -red "Unable to set IP configs to IxHal!"
           set retVal 1
       }
       #Dinfine UDP protocol
        udp setDefault        
        #tcp config -offset 5
        udp config -sourcePort $Srcport
        udp config -destPort $Dstport
        if [udp set $Chas $Card $Port] {
            IxPuts -red "Unable to set UDP configs to IxHal!"
            set retVal 1
        }
           
       if {$Vlan != 0} {
           protocol config -enable802dot1qTag vlanSingle
           vlan setDefault        
           vlan config -vlanID $Vlan
           vlan config -userPriority $Pri
           if [vlan set $Chas $Card $Port] {
               IxPuts -red "Unable to set Vlan configs to IxHal!"
               set retVal 1
           }
       }
       switch $Cfi {
               0 {vlan config -cfi resetCFI}
               1 {vlan config -cfi setCFI}
       }
           
       #UDF Config
       
       if {$Udf1 == 1} {
           udf setDefault        
           udf config -enable true
           udf config -offset $Udf1offset
           switch $Udf1len {
               1 { udf config -countertype c8  }                
               2 { udf config -countertype c16 }               
               3 { udf config -countertype c24 }                
               4 { udf config -countertype c32 }
           }
           switch $Udf1changemode {
               0 {udf config -updown uuuu}
               1 {udf config -updown dddd}
           }
           udf config -initval $Udf1initval
           udf config -repeat  $Udf1repeat              
           udf config -step    $Udf1step
           udf set 1
       }
       if {$Udf2 == 1} {
           udf setDefault        
           udf config -enable true
           udf config -offset $Udf2offset
           switch $Udf2len {
               1 { udf config -countertype c8  }                
               2 { udf config -countertype c16 }               
               3 { udf config -countertype c24 }                
               4 { udf config -countertype c32 }
           }
           switch $Udf2changemode {
               0 {udf config -updown uuuu}
               1 {udf config -updown dddd}
           }
           udf config -initval $Udf2initval
           udf config -repeat  $Udf2repeat              
           udf config -step    $Udf2step
           udf set 2
       }
       if {$Udf3 == 1} {
           udf setDefault        
           udf config -enable true
           udf config -offset $Udf3offset
           switch $Udf3len {
               1 { udf config -countertype c8  }                
               2 { udf config -countertype c16 }               
               3 { udf config -countertype c24 }                
               4 { udf config -countertype c32 }
           }
           switch $Udf3changemode {
               0 {udf config -updown uuuu}
               1 {udf config -updown dddd}
           }
           udf config -initval $Udf3initval
           udf config -repeat  $Udf3repeat              
           udf config -step    $Udf3step
           udf set 3
       }
       if {$Udf4 == 1} {
           udf setDefault        
           udf config -enable true
           udf config -offset $Udf4offset
           switch $Udf4len {
               1 { udf config -countertype c8  }                
               2 { udf config -countertype c16 }               
               3 { udf config -countertype c24 }                
               4 { udf config -countertype c32 }
           }
           switch $Udf4changemode {
               0 {udf config -updown uuuu}
               1 {udf config -updown dddd}
           }
           udf config -initval $Udf4initval
           udf config -repeat  $Udf4repeat              
           udf config -step    $Udf4step
           udf set 4
       }
       if {$Udf5 == 1} {
           udf setDefault        
           udf config -enable true
           udf config -offset $Udf5offset
           switch $Udf5len {
               1 { udf config -countertype c8  }                
               2 { udf config -countertype c16 }               
               3 { udf config -countertype c24 }                
               4 { udf config -countertype c32 }
           }
           switch $Udf5changemode {
               0 {udf config -updown uuuu}
               1 {udf config -updown dddd}
           }
           udf config -initval $Udf5initval
           udf config -repeat  $Udf5repeat              
           udf config -step    $Udf5step
           udf set 5
       }        
           
       #Table UDF Config        
       tableUdf setDefault        
       tableUdf clearColumns      
       tableUdf config -enable 1
       tableUdfColumn setDefault        
       tableUdfColumn config -formatType formatTypeHex
       if {$Change == 0} {
           tableUdfColumn config -offset [expr $Length -5]} else {
           tableUdfColumn config -offset $Change
       }
       tableUdfColumn config -size 1
       tableUdf addColumn         
       set rowValueList $Value
       tableUdf addRow $rowValueList
       if [tableUdf set $Chas $Card $Port] {
           IxPuts -red "Unable to set TableUdf to IxHal!"
           set retVal 1
       }

       #Final writting....        
       if [stream set $Chas $Card $Port $streamId] {
           IxPuts -red "Unable to set streams to IxHal!"
           set retVal 1
       }
       
       incr streamId
       lappend portList [list $Chas $Card $Port]
       if [ixWriteConfigToHardware portList -noProtocolServer ] {
           IxPuts -red "Unable to write configs to hardware!"
           set retVal 1
       }
       return $retVal          
    }

    #!!================================================================
    #�� �� ����     SmbUnLink
    #�� �� ����     IXIA
    #�������     
    #����������     �Ͽ����Ǳ������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 13:43:32
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbUnLink {} {
        variable m_ChassisIP
        set retVal 0 
        if {[isUNIX]} {
           if {[ixDisconnectTclServer $m_ChassisIP]} {
               IxPuts -red "Error connecting to Tcl Server $m_ChassisIP"
               return 1
           }
        }   
        set retVal [ixDisconnectFromChassis $m_ChassisIP]
        return $retVal
    }
    
    #!!================================================================
    #�� �� ����     SmbVfdSet
    #�� �� ����     IXIA
    #�������     
    #����������     ###
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�     
    #               args:    
    #                       -dstmac        Ŀ��MAC, Ĭ��ֵΪ "00 00 00 00 00 00"
    #                       -dstip         Ŀ��IP��ַ, Ĭ��ֵΪ "1.1.1.1"
    #                       -srcmac         ԴMAC, Ĭ��ֵΪ "00 00 00 00 00 01"
    #                       -srcip         ԴIP��ַ, Ĭ��ֵΪ "3.3.3.3"
    #                       -clear         1:��������� 0:������κ���
    #                       -length         ���ĳ���,Ĭ��Ϊ�������,�����������0,��˼��ʹ���������.
    #                       -streamid       ���ı��,��1��ʼ,����˿�������ͬID������������.Ĭ��ֵ1
    #                       -type            custom / IP / TCP / UDP / ipx / ipv6,Ĭ��ΪCUSTOM���Զ����� 
    #                       -vlan           Vlan tag,����,Ĭ��0,����û��VLAN Tag,����0��ֵ�Ų���VLAN tag.
    #                       -data        ��CUSTOMģʽ����Ч. ָ����������, ��ָ��ʱʹ���������,������ʽ "FF 01 11 ..."
    #                       -vfd1           VFD1��ı仯״̬, Ĭ��ΪOffState; ����֧�����¼���ֵ;:
    #                                       OffState �ر�״̬
    #                                       StaticState �̶�״̬
    #                                       IncreState ����״̬
    #                                       DecreState �ݼ�״̬
    #                                       RandomState ���״̬
    #                       -vfd1cycle     VFD1ѭ���仯������ȱʡ����²�ѭ���������仯
    #                       -vfd1step    VFD1��仯����
    #                       -vfd1offset     VFD1�仯��ƫ����
    #                       -vfd1start      VFD1�仯����ʼֵ������0x��ʮ��������,,������ʽΪ {01.0f.0d.13},�4���ֽ�,���1���ֽ�,ע��ֻ��1λ��ǰ�油0,��1Ҫд��01.
    #                       -vfd1length     VFD1�仯����,�4���ֽ�,���1���ֽ�
    #                       -vfd2           VFD2��ı仯״̬, Ĭ��ΪOffState; ����֧�����¼���ֵ;:
    #                                       OffState �ر�״̬
    #                                       StaticState �̶�״̬
    #                                       IncreState ����״̬
    #                                       DecreState �ݼ�״̬
    #                                       RandomState ���״̬
    #                       -vfd2cycle     VFD2ѭ���仯������ȱʡ����²�ѭ���������仯
    #                       -vfd2step    VFD2��仯����
    #                       -vfd2offset     VFD2�仯��ƫ����
    #                       -vfd2start      VFD2�仯����ʼֵ������0x��ʮ��������,������ʽΪ {01.0f.0d.13},�4���ֽ�,���1���ֽ�.ע��ֻ��1λ��ǰ�油0,��1Ҫд��01
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-8-14 11:54:54
    #�޸ļ�¼��     modify by chenshibing 2009-05-18 ����vfd1start/vfd2start�Ĵ���ʹ�������ʽ��smbһ��
    #!!================================================================
    proc SmbVfdSet {Chas Card Port args} {
        set retVal     0
        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        set Streamid   1
        set Vfd1       OffState
        set Vfd1cycle  1
        set Vfd1step   1
        set Vfd1offset 12
        set Vfd1start  {00}
        set Vfd1len    4
        set Vfd2       OffState
        set Vfd2cycle  1
        set Vfd2step   1
        set Vfd2offset 12
        set Vfd2start  {00}
        set Vfd2len    4        
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
    
            case $cmdx      {
                -streamid       {set Streamid $argx}

                -vfd1           {set Vfd1   $argx}
                -vfd1cycle      {set Vfd1cycle $argx}
                -vfd1step       {set Vfd1step $argx}
                -vfd1offset     {set Vfd1offset $argx}
                -vfd1start      {set Vfd1start $argx}
                -vfd2           {set Vfd2   $argx}
                -vfd2cycle      {set Vfd2cycle $argx}
                -vfd2step       {set Vfd2step $argx}
                -vfd2offset     {set Vfd2offset $argx}
                -vfd2start      {set Vfd2start $argx}
                -vfd1length     {set Vfd1len $argx}
                -vfd2length     {set Vfd2len $argx}
                default     {
                    IxPuts -red  "Error : cmd option $cmdx does not exist"
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }

        # add by chenshibing 2009-05-18
        set Vfd1start [string map {. " "} $Vfd1start]
        set Vfd2start [string map {. " "} $Vfd2start]
        # add end
 
        if [stream get $Chas $Card $Port $Streamid] {
             IxPuts -red  "Unable to retrive config of No.$Streamid stream from $Chas $Card $Port!"
             set retVal 1
        }
        
        #UDF1 config
        if {$Vfd1 != "OffState"} {
            udf setDefault        
            udf config -enable true
            switch $Vfd1 {
                "RandomState" {
                     udf config -counterMode udfRandomMode
                 }
                 "StaticState" -
                 "IncreState"  -
                 "DecreState" {
                     udf config -counterMode udfCounterMode        
                 }                    
            }
            #set Vfd1len [llength $Vfd1start]
            if { $Vfd1len > 4 } {
                # edited by Eric to fix the bug when Vfd length > 4
                incr Vfd1offset [expr $Vfd1len - 4]
                set Vfd1start [ lrange $Vfd1start [expr [llength $Vfd1start]-4] end ]
                
                set Vfd1len 4
            }
            switch $Vfd1len  {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
                default {IxPuts -red  "-vfd2start only support 1-4 bytes, for example: {11 11 11 11}"}
            }
            switch $Vfd1 {
                "IncreState" {udf config -updown uuuu}
                "DecreState" {udf config -updown dddd}
            }
            udf config -offset  $Vfd1offset
            udf config -initval $Vfd1start
            udf config -repeat  $Vfd1cycle              
            udf config -step    $Vfd1step
            udf set 1
        } elseif {$Vfd1 == "OffState"} {
            udf setDefault        
            udf config -enable false
            
            #fixed by yuzhenpin 61733
            #from
            #udf set 2
            #to
            udf set 1
        }
        
        #UDF2 config
        if {$Vfd2 != "OffState"} {
            udf setDefault        
            udf config -enable true
            switch $Vfd2 {
                "RandomState" {
                     udf config -counterMode udfRandomMode
                 }
                 "StaticState" -
                 "IncreState"  -
                 "DecreState" {
                     udf config -counterMode udfCounterMode        
                 }
                    
            }
            #set Vfd2len [llength $Vfd2start]
            if { $Vfd2len > 4 } {
                # edited by Eric to fix the bug when Vfd length > 4
                incr Vfd2offset [expr $Vfd2len - 4]
                set Vfd2start [ lrange $Vfd2start [expr [llength $Vfd2start]-4] end ]

                set Vfd2len 4
            }
            switch $Vfd2len  {
                1 { udf config -countertype c8  }                
                2 { udf config -countertype c16 }               
                3 { udf config -countertype c24 }                
                4 { udf config -countertype c32 }
                default {IxPuts -red "-vfd2start only support 1-4 bytes, for example: {11 11 11 11}"}
            }
            switch $Vfd2 {
                    "IncreState" {udf config -updown uuuu}
                    "DecreState" {udf config -updown dddd}
            }
            udf config -offset  $Vfd2offset
            udf config -initval $Vfd2start
            udf config -repeat  $Vfd2cycle              
            udf config -step    $Vfd2step
            udf set 2
        } elseif {$Vfd2 == "OffState"} {
            udf setDefault        
            udf config -enable false
            udf set 2
        }
                
        #Final writting....        
        if [stream set $Chas $Card $Port $Streamid] {
            IxPuts -red "Unable to set streams to IxHal!"
            set retVal 1
        }

        lappend portList [list $Chas $Card $Port]
        if [ixWriteConfigToHardware portList -noProtocolServer ] {
            IxPuts -red "Unable to write configs to hardware!"
            set retVal 1
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbWaitForRxStart
    #�� �� ����     IXIA
    #�������     
    #����������     �ȴ��˿ڿ�ʼ�հ�,һ����⵽���ն˿�����>0,������ֹͣ���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�     
    #               maxCount:      ��ʾ���ȴ���ʱ��(��λ:��),�������ʱ�仹û�м�⵽�н��հ����˳�.
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:54:12
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbWaitForRxStart {Chas Card Port maxCount} {
        set retVal 0
        set startTime [clock seconds]
        set i 1
        while {1} { 
            set nowTime [clock seconds]
            if {[expr $nowTime - $startTime] > $maxCount} {
                IxPuts -red "��ָ��ʱ����û�м�⵽�˿ڿ�ʼ���հ�,ֹͣ���!"
                set retVal 1
                break
            }
            IxPuts -blue "��$i\�μ��..."
            stat getRate allStats $Chas $Card $Port
            set RxRate [stat cget -framesReceived]
            if {$RxRate >0} {
                IxPuts -blue "�Ѿ���⵽�˿ڿ�ʼ���հ�!"
                break
            }        
            after 1000
            incr i
        }
        return $retVal
    } 

    #!!================================================================
    #�� �� ����     SmbWaitForRxStop
    #�� �� ����     IXIA
    #�������     
    #����������     �ȴ�����ֹͣ,�ý����������ж�,����жϽ�������Ϊ0����Ϊ����ֹͣ
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�     
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:57:15
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbWaitForRxStop {Chas Card Port} {
        set retVal 0
        set i 1
        while {1} { 
            IxPuts -blue "��$i\�μ��..."
            stat getRate allStats $Chas $Card $Port
            set RxRate [stat cget -framesReceived]
            if {$RxRate == 0} {
                IxPuts -blue "�˿ڽ������!"
                break
            }        
            after 1000
            incr i
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     SmbWaitForTxStop
    #�� �� ����     IXIA
    #�������     
    #����������     �ȴ�����ֹͣ,�÷����������ж�,����жϷ�������Ϊ0����Ϊ����ֹͣ
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�    
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-13 20:58:51
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbWaitForTxStop {Chas Card Port} {
        set retVal 0
        set i 1
        while {1} { 
            IxPuts -blue "��$i\�μ��..."
            stat getRate allStats $Chas $Card $Port
            set TxRate [stat cget -framesSent]
            if {$TxRate == 0} {
                IxPuts -blue "�˿ڷ���ֹͣ!"
                break
            }        
            after 1000
            incr i
        }
        return $retVal
    }

    #!!================================================================
    #�� �� ����     IxPuts
    #�� �� ����     IXIA
    #�������     
    #����������     �������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               args:  
    #                    -red:������ϢΪ��ɫ
    #                    -blue:������ϢΪ��ɫ
    #                    -link:������ϢΪ��ɫ
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     ��ŵ
    #�������ڣ�     2006-7-13 12:42:45
    #�޸ļ�¼��     
    #!!================================================================
    proc IxPuts {args} {
        set fontcolor   "black"
        while {[string match -* [lindex $args 0]]} {
            switch -glob -- [lindex $args 0] {
                -red    { set fontcolor "red";  set args [lreplace $args 0 0] }
                -blue   { set fontcolor "blue"; set args [lreplace $args 0 0] }
                -link   { set args [lreplace $args 0 0] }
                default {return -code error "unknown option \"[lindex $args 0]\""}
            }
        }
        #variable m_debugflag
        #if {$m_debugflag & 0x01} {
        #    eval LOG $args $fontcolor
        #} 
        #return [expr $m_debugflag & 0x01]
        
        puts [lindex $args 0]
    }

    #!!================================================================
    #�� �� ����     StrIpV6AddressCheck
    #�� �� ����     IXIA
    #�������     
    #����������     IPV6��ַ�Ϸ�����֤
    #�÷���         
    #ʾ����         IxStrIpAddressCheck 1111.2222.3333.4444.5555.6666.7777.8888 
    #               
    #����˵����     
    #               sIpAddress:    
    #�� �� ֵ��     �����Ϸ�����0,�Ƿ�����1
    #��    �ߣ�     ��ŵ
    #�������ڣ�     2006-7-31 9:51:7
    #�޸ļ�¼��     
    #!!================================================================
    proc IxStrIpV6AddressCheck {sIpAddress} {
        set retVal 0
        set lIpAddress [split $sIpAddress .]
        set llengthIP [llength $lIpAddress]

        if { $llengthIP > 8 || $llengthIP < 1} {
            set retVal 1
            return $retVal
        }
        
        for {set i 0} {$i < $llengthIP} {incr i} {
            set address [lindex $lIpAddress $i]
            if {[StrHexStringCheck $address] == 1 && [string length $address] == 4} {
               set retVal 0
            } else {
               set retVal 1
               break
            }
        }
        return $retVal
    }
    #!!================================================================
    #�� �� ����     IxStrIpV6AddressConvers
    #�� �� ����     IXIA
    #�������     
    #����������     IP��ַת�������Ե�ŷָ�IP��ת��Ϊ�Էֺŷָ�IP
    #�÷���         
    #ʾ����         IxStrIpV6AddressConvers 1111.2222.3333.4444.5555.6666.7777.8888
    #               
    #����˵����     
    #               sIpAddress:  �Ե�ŷָ��IP��ַ  
    #�� �� ֵ��     �Էֺŷָ��IP��ַ����:1111:2222:3333:4444:5555:6666:7777:8888
    #��    �ߣ�     ��ŵ
    #�������ڣ�     2006-7-31 16:53:0
    #�޸ļ�¼��     
    #!!================================================================
    proc IxStrIpV6AddressConvert {IpAddress} {
        set datalist ""
        set temp [split $IpAddress .]
        set iplen [llength $temp]
        for {set i 0} {$i < $iplen} {incr i} {
            if {$i != [expr $iplen-1]} {
                set datalist "$datalist[lindex $temp $i]:"
            } else {
                set datalist "$datalist[lindex $temp $i]"
            }
        }
        return $datalist
    }
    
    #!!================================================================
    #�� �� ����     IxParaCheck
    #�� �� ����     IXIA
    #�������     
    #����������     ��������Ϸ�����֤
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               args: �������
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��ŵ
    #�������ڣ�     2006-7-27 18:35:29
    #�޸ļ�¼��     
    #!!================================================================
    proc IxParaCheck {args} {
        set retVal 0
        set args [string tolower $args]

        #ȥ����������������һ�������
        set args [string range $args [expr [string first "{" $args]+1] [ expr [string last "}" $args]-1]]

        foreach {cmdx val} $args {
            switch -glob -- $cmdx {
                -groupip -
                -dstip   - 
                -srcip   {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[StrIpAddressCheck  $val] != 0 && [IxStrIpV6AddressCheck $val] != 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be ipv4 or ipv6  address"
                        set retVal 1
                    }
                }
                
                -dstmac        -                
                -srcmac        -
                -strmplsdstmac -
                -strmplssrcmac {
                    if { [regexp {\.} $val] == 0} {
                        continue
                    }
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[StrJudgeMac $val] == 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,mac address should be Hex"
                        set retVal 1
                    }
                }
                
                -arptype   {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 1 && $val != 2 && $val != 3 && $val != 4} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 1 or 2 or 3 or 4"
                        set retVal 1
                    }
                }
                
                -align      -
                -crc        -
                -cfi        -
                -cfi2       -                 
                -cfi3       {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 0 && $val != 1} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1"
                        set retVal 1  
                    }
                }

                -change     {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1  
                    }
                 }

                -dribble    {
                     if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                     } elseif {$val != 0 && $val != 1} {
                         IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1"
                         set retVal 1
                     }
                }
                
                -dscp       {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                         IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                         set retVal 1
                    }
                }

                -enable     {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != "true" && $val != "false"} {
                         IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be true or false"
                         set retVal 1
                    }
                }
               
                -fragoffset {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                         IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                         set retVal 1
                    }
                }
                
                -frametype  {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 1 && $val != 2 && $val != 3} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 1 or 2 or 3"
                        set retVal 1
                    }
                }
                 
                -icmpcode   -
                -icmptype   -
                -icmpid     -
                -icmpseq    -
                -id         -
                -index      {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -igmpver {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -igmptype   {                    
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 17 && $val != 18 && $val != 19 && $val != 22 && $val != 23 && $val != 34} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                
                }
                
                -iphlen     {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 5} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer and > 5"
                        set retVal 1
                    }
                }
                                
                -lastfrag   {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 0 && $val != 1} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1"
                        set retVal 1
                    }
                }
                
                -length      -
                -length1     - 
                -length2     {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
               
                -len        {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -mayfrag    {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 0 && $val != 1} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1"
                        set retVal 1
                    }
                }
                 
                -metric {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -nocrc {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 0 && $val != 1} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1"
                        set retVal 1
                    }
                }
                
                 -offset           -
                 -offset1          -
                 -offset2          {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                         IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                         set retVal 1
                    }
                }

                -pri        -
                -pri2       -
                -pri3       {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val ] == 0 || $val < 0 || $val > 7} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1 or 2 or 3 or 4 or 5 or 6 or 7"
                        set retVal 1 
                    }
                }
                
                -pro        {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || ($val != 4 && $val != 6)} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 4 or 6"
                        set retVal 1
                    }


                }
                
                -rsvd {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is double $val] == 0 || $val < 0 || $val > 127} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer and less than 65536 "
                        set retVal 1
                    }
                }
                
                -strburstnum {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif { [string is integer $val ] == 0 || $val < 0 || $val > 65535} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer and less than 65536 "
                        set retVal 1
                    }
                }
                
                -strtransmode {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif { $val != 0 && $val != 1 && $val != 2} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1 or 2"
                        set retVal 1
                    }
                }
                
                -strframenum  -
                -streamid     {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -strrate {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0 ||$val > 100} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer and less than 100"
                        set retVal 1
                    }
                }
                
                -tag        {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 0 && $val != 1 && $val != 2 && $val != 3} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1 or 2 or 3"
                        set retVal 1
                    }
                }

                -type       {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[StrHexStringCheck $val] == -1 && $val != "custom" && $val != "ip" && $val != "tcp" && $val != "udp" && $val != "ipx" && $val != "ipv6"} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong"
                        set retVal 1
                    }
                }
                                
                -tos        {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -tot        {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -ttl        {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 255} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer >255"
                        set retVal 1
                    }
                }
                
                -ver        {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || ($val != 4 && $val != 6) } {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 4 or 6 "
                        set retVal 1
                    }

                }
                
                -value       -
                -value1      -
                -value2      {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } else {
                        for {set i 0} {$i < [llength $val]} {incr i} {
                            if {[StrHexStringCheck [lindex $val $i]] == -1} {
                                IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be Hex"
                                set retVal 1
                                break
                            }
                        }
                    }
                }
                
                -vlan       -
                -vlan2      -
                -vlan3      {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0 || $val > 4095} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer and less than 4095"
                        set retVal 1
                    }
                }
                
                -udf1           -
                -udf2           -
                -udf3           -
                -udf4           -
                -udf5           {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 0 && $val != 1} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1"
                        set retVal 1
                    }

                }
                
                -udf1offset     -
                -udf2offset     -
                -udf3offset     -
                -udf4offset     -
                -udf5offset     {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -udf1len        -
                -udf2len        -
                -udf3len        -
                -udf4len        -
                -udf5len        {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 1 && $val != 2 && $val != 3 && $val != 4} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 1 or 2 or 3 or 4"
                        set retVal 1
                    }

                }
                
                -udf1initval    -
                -udf2initval    -
                -udf3initval    -
                -udf4initval    -
                -udf5initval    {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[StrHexStringCheck $val] == -1} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be Hex"
                        set retVal 1
                    }
                }  
                
                -udf1step       -
                -udf2step       -
                -udf3step       -
                -udf4step       -
                -udf5step       {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 1} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                
                -udf1changemode  -
                -udf2changemode  -
                -udf3changemode  -
                -udf4changemode  -
                -udf5changemode  {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {$val != 0 && $val != 1} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be 0 or 1"
                        set retVal 1
                    }
                }
                
                -udf1repeat     -
                -udf2repeat     -
                -udf3repeat     -
                -udf4repeat     -
                -udf5repeat     {
                    if {$val == ""} {
                        IxPuts -red "Error : cmd option $cmdx $val is null"
                        set retVal 1
                    } elseif {[string is integer $val] == 0 || $val < 0} {
                        IxPuts -red "Error : cmd option $cmdx $val is wrong,it should be positive integer"
                        set retVal 1
                    }
                }
                default {
                }
            }
        }
        return $retVal
    }
    
    #!!================================================================
    #�� �� ����     SmbAppThroughputTest
    #�� �� ����     IXIA
    #�������     
    #����������     ����L2/L3��������(����ֻ����L2��)
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               PortList:  ����ʹ�õĶ˿��б���:{{1.1.1 1.1.2} {1.2.1 1.2.2}}
    #               args:  
    #                    -autonegotiate: �Ƿ�����Ӧ 3: �ǣ� 0: ������Ӧ(3ΪĬ��ֵ)
    #                    -duplex:        ˫��ģʽ 0:��˫�� 1:ȫ˫��(Ĭ��Ϊȫ˫��)
    #                    -singlerate:    ����(Ĭ��ֵ100M), ȡֵ: 10M, 100M, 1000M
    #                    -media          �˿�ý��, Ĭ��Ϊ fiber �����;  ȡֵ: copper, fiber
    #                    -traffictype    ����ҵ������, Ĭ��Ϊ IP, ȡֵ: IP, UDP, IPX
    #                    -duration:      ÿ�η��͵�ʱ��(����ʱ��):1~N integer(Ĭ��Ϊ10)
    #                    -trialnum:      �����׸���(Ĭ��Ϊ1)
    #                    -customflag:    ���Ƿ��ŵ�������������(1:�ǣ�0:�ֹ�ָ�����ĳ���.Ĭ��Ϊ0)
    #                    -packetlength:  �ֹ�ָ�������ݰ�����, �ò�����Ҫָ��һ�����ݰ��ó������б����ʽ�ṩ 
    #                                    ����: -packetlength {64 128 256 512 1024 1518}
    #                    -learn:         �Ƿ���ѧϰ�� 1: ���ͣ� 0: ������(Ĭ��ֵΪ1)
    #                    -learningretries:�ط��Ĵ��� (Ĭ��ֵΪ3)
    #                    -stoperror:     ���������ʱ��ֹͣ 1: �ǣ� 0: ��(1ΪĬ��ֵ)
    #                    -bidirection:   �Ƿ�֧�������ĵ�/˫���� 1: ֧�֡� 0: ��֧��
    #                    -inilength:     ��ʼ������ ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ64)
    #                    -stoplength:    ��󳤶� ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ1518)
    #                    -stepsize:      ���ݰ�������С ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ64)
    #                    -inirate:       ��ʼ�ٶ� (Ĭ��ֵ100)
    #                    -maxrate:       ����ٶ� (Ĭ��ֵ100) 
    #                    -minrate:       ��С�ٶ� (Ĭ��ֵ0.1)
    #                    -tolrate:       �ٶ����� (Ĭ��ֵ0.5)
    #                    -router:        �Ƿ�ʹ��router test 1Ϊʹ�� 0Ϊ��ʹ��(Ĭ��Ϊ0)
    #                    -srcip:         Դip
    #                    -dstip:         Ŀ��ip
    #                    -srcMAC:        ԴMAC��ַ(Ĭ�ϵ�Ϊhub.slot.port)
    #                    -dstMAC:        Ŀ��MAC��ַ(Ĭ�ϵ�Ϊhub.slot.port)
    #                    -lossrate:      ��ʶ����İ����ʧ��
    #                    -delay:         ������һ֡�����ʱ����(Ĭ��Ϊ4),ֱͨ���ߴ洢ת��("cutThrough"/"storeAndForward")
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-28 15:43:15
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbAppThroughputTest {PortList args} {
        set retVal 0
        variable m_ChassisIP
        set ChassisIP  $m_ChassisIP

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        #��ʽת��
        for {set i 0} {$i < [llength $PortList]} {incr i } {
            set temp1 [lindex [lindex $PortList $i] 0]
            set temp1 [split $temp1 .]
            set temp2 [lindex [lindex $PortList $i] 1]
            set temp2 [split $temp2 .]
            set temp "$temp1 $temp2"
            lappend finalls1 $temp
            lappend finalls2 $temp1
            lappend finalls2 $temp2
        }
        set TrafficMap $finalls1
        set PortList $finalls2
        
        set retVal 0
        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        set Duration  10
        set Trialnum  1
        set Customflag 1        
        set Packetlength {64 128}    
        set Learn    1
        set PacketRetry    3
        set Autonegotiate 3
        set Stoperror    1
        set Bidirection    1
        set Inilength    64
        set Stoplength    1518
        set Stepsize    64
        set Inirate    100
        set Maxrate    100
        set Minrate    0.1
        set Tolrate    0.5
        set Router    0
        set Srcip    1.1.1.2
        set Dstip    1.1.2.2
        set SrcMAC    "00 00 00 00 00 01"
        set DstMAC    "00 00 00 00 00 02"
        set Duplex    1
        set Lossrate    0
        set Delay    ""
        set Singlerate  100M
        set media "fiber"
        set Protocol "ip"
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
        
            case $cmdx      {
                -duration   {set Duration $argx}
                -trialnum  {set Trialnum $argx}
                -customflag {set Customflag $argx}
                -packetlength {set Packetlength $argx}    
                -learn {set Learn $argx}
                -learningretries {set PacketRetry    $argx}
                -autonegotiate {set Autonegotiate $argx}
                -stoperror  {set Stoperror    $argx}
                -bidirection {set Bidirection    $argx}
                -inilength {set Inilength    $argx}
                -stoplength  {set Stoplength    $argx}
                -stepsize {set Stepsize    $argx}
                -inirate {set Inirate    $argx}
                -maxrate {set Maxrate    $argx}
                -minrate {set Minrate    $argx}
                -tolrate {set Tolrate    $argx}
                -router {set Router    $argx}
                -srcip {set Srcip    $argx}
                -dstip {set Dstip    $argx}
                -srcmac {set SrcMAC    $argx}
                -dstmac {set DstMAC    $argx}
                -duplex {set Duplex    $argx}
                -lossrate {set Lossrate    $argx}
                -delay {set Delay    $argx}
                -singlerate {set Singlerate  $argx}
                -media      {set media  $argx}
                -traffictype {set Protocol $argx}
                -inipps {set inipps $argx}
                -maxpps {set maxpps $argx}
                -minpps {set minpps $argx}
                -flowcontrol {set flowcontrol $argx}
                -learningpackets {set learningpackets $argx}
                default     {
                    set retVal 1
                    IxPuts -red  "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }
        
        set Framesizes $Packetlength

        switch $Bidirection {
            0 {set MapDir unidirectional}
            1 {set MapDir bidirectional}
            default {
                set retVal 1
                IxPuts -red "No such MapDir type, please check -bidirection parameter."
                return $retVal
            }
        }
        
        switch $Router {
            1 {set Protocol "ip"}
            0 {set Protocol "mac"}
            default {
                set retVal 1
                IxPuts -red "No such protocol type, please check -router parameter."
                return $retVal
            }
        }

        if { $media == "fiber" } { 
            set media ""
        } else {
            set media "Copper"
        }
        
        switch $Singlerate {
            "10m" -
            "10M" {set Speed ${media}10}
            "100m" -
            "100M" {set Speed ${media}100}
            "1000M" -
            "1000m" -
            "1G" {set Speed ${media}1000}
            default {
                set retVal 1
                IxPuts -red "No such speed mode, please check -singlerate"
                return $retVal
            }
        }
   
        switch $Autonegotiate  {
            3 {set AutoNeg true}
            0 {set AutoNeg false}
            default {
                set retVal 1
                IxPuts -red  "No such autonegotiate parameter, please check -autonegotiate"
                return $retVal
            }
        }

        set Trials $Trialnum
        set Tolerance $Tolrate
        set MaxRatePct $Inirate
        set ResultsPath "results/RFC2544_Thruput_results.csv"
        switch $Duplex {
            0 {set DuplexMode half}
            1 {set DuplexMode full}
            default {
                set retVal 1
                IxPuts -red "No such Duplex mode, please check -duplex parameter"
                return $retVal
            }
        }
        
        DirDel "temp/RFC 2544.resDir"
        logger config -directory "temp"
        logger config -fileBackup true
        results config -directory "temp"
        results config -fileBackup true
        results config -logDutConfig true
    
        global testConf SrcIpAddress DestDUTIpAddress SrcIpV6Address \
               DestDUTIpV6Address IPXSourceSocket VlanID NumVlans
    
        logOn "thruput.log"
        
        logMsg "\n\n  RFC2544 Throughput test"  
        logMsg "  ............................................\n"
        results config -resultFile "tput.results"
        results config -generateCSVFile false
        
        user config -productname  "Ixia DUT"
        user config -version      "V1.0"
        user config -serial#      "2007"
        user config -username     "SWTT"
    
        set testConf(hostname)                      $ChassisIP
        set testConf(chassisID)                     1
        set testConf(chassisSequence)               1
        set testConf(cableLength)                   cable3feet
    
        for {set i 0} {$i< [llength $PortList]} {incr i} {
            set Chas [lindex [lindex $PortList $i] 0]
            set Card [lindex [lindex $PortList $i] 1]
            set Port [lindex [lindex $PortList $i] 2] 
            set testConf(autonegotiate,$Chas,$Card,$Port)  $AutoNeg
            set testConf(duplex,$Chas,$Card,$Port)         $DuplexMode
            set testConf(speed,$Chas,$Card,$Port)          $Speed
        }
        
        set testConf(mapFromPort)                   {1 1 1}
        set testConf(mapToPort)                     {1 16 4}
        switch $Protocol {
            "mac" {
                set testConf(protocolName)               mac
                set testConf(ethernetType)               ethernetII   
            }
            "ip"  {
                set testConf(protocolName)            ip
                for {set i 0} {$i< [llength $PortList]} {incr i} {
                    set Chas [lindex [lindex $PortList $i] 0]
                    set Card [lindex [lindex $PortList $i] 1]
                    set Port [lindex [lindex $PortList $i] 2] 
                    set POIp [lindex [lindex $PortList $i] 3]
                    set GWIp [lindex [lindex $PortList $i] 4]
                    set Mask [lindex [lindex $PortList $i] 5]
                    
                    set SrcIpAddress($Chas,$Card,$Port)      $POIp
                    set DestDUTIpAddress($Chas,$Card,$Port)  $GWIp
                    set testConf($Chas,$Card,$Port)          $Mask
                    set testConf(maskWidthEnabled)           1
                } 
            } 
            default {
                set retVal 1
                IxPuts -red "you select wrong protocol, test end."
                return $retVal
            }
        }
    
        set testConf(autoMapGeneration)             no
        set testConf(autoAddressForManual)          no
        set testConf(mapDirection)                  $MapDir 
        map new    -type one2one
        map config -type one2one
        
        set k $TrafficMap
        for {set i 0} {$i<[llength $k]} {incr i} {
            map add [lindex [lindex $k $i] 0] [lindex [lindex $k $i] 1] [lindex [lindex $k $i] 2] \
                    [lindex [lindex $k $i] 3] [lindex [lindex $k $i] 4] [lindex [lindex $k $i] 5]
        }
        
        map config -echo false
        set testConf(generatePdfEnable) false
        global tputMultipleVlans
        set tputMultipleVlans 1
        set testConf(vlansPerPort) 1
        set testConf(displayResults) true
        set testConf(displayAggResults) true
        set testConf(displayIterations) true
        
        learn config -when        oncePerTest
        learn config -type        default
        learn config -numframes   10
        learn config -retries     10
        learn config -rate        100
        learn config -waitTime    1000
        learn config -framesize   256
        
        tput config -framesizeList $Framesizes
        tput config -duration      $Duration
        tput config -numtrials     $Trials
        tput config -tolerance     $Tolerance
        tput config -percentMaxRate $MaxRatePct
        tput config -minimumFPS 10
        
        advancedTestParameter config -l2DataProtocol native
        fastpath config -enable false
        
        if [configureTest [map cget -type]] {
            cleanUp
            return 1
        }
        
        if [catch {tput start} result] {
            logMsg "ERROR: $::errorInfo"
            cleanUp
            return 1
        }
        #teardown 
        IxPuts  -blue "Writting result file..."
        set SrcFile "temp/RFC 2544.resDir/Throughput.resDir/IXIA�Ǳ��������_��������������.res/Run0001.res/results.csv"
        file copy -force $SrcFile  $ResultsPath
        IxPuts -blue  "Test over!"
        return 0 
    }

    #!!================================================================
    #�� �� ����     SmbAppLatencyTest
    #�� �� ����     IXIA
    #�������     
    #����������     ����L2/L3����ʱ����(����ֻ����L2��)
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               PortList:  ����ʹ�õĶ˿��б���:{{1.1.1 1.1.2} {1.2.1 1.2.2}}
    #               args:  
    #                    -duration:      ÿ�η��͵�ʱ��(����ʱ��):1~N integer(Ĭ��Ϊ10)
    #                    -trialnum:      �����׸���(Ĭ��Ϊ1)
    #                    -customflag:    ���Ƿ��ŵ�������������(1:�ǣ�0:�ֹ�ָ�����ĳ���.Ĭ��Ϊ0)
    #                    -packetlength:  �ֹ�ָ�������ݰ�����, �ò�����Ҫָ��һ�����ݰ��ó������б����ʽ�ṩ 
    #                                    ����: -packetlength {64 128 256 512 1024 1518}
    #                    -learn:         �Ƿ���ѧϰ�� 1: ���ͣ� 0: ������(Ĭ��ֵΪ1)
    #                    -packetRetry:   �ط��Ĵ��� (Ĭ��ֵΪ3)
    #                    -autonegotiate: �Ƿ�����Ӧ 3: �ǣ� 0: ������Ӧ(3ΪĬ��ֵ)
    #                    -stoperror:     ���������ʱ��ֹͣ 1: �ǣ� 0: ��(1ΪĬ��ֵ)
    #                    -bidirection:   �Ƿ�֧�������ĵ�/˫���� 1: ֧�֡� 0: ��֧��
    #                    -inilength:     ��ʼ������ ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ64)
    #                    -stoplength:    ��󳤶� ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ1518)
    #                    -stepsize:      ���ݰ�������С ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ64)
    #                    -inirate:       ��ʼ�ٶ� (Ĭ��ֵ100)
    #                    -maxrate:       ����ٶ� (Ĭ��ֵ100) 
    #                    -minrate:       ��С�ٶ� (Ĭ��ֵ0.1)
    #                    -tolrate:       �ٶ����� (Ĭ��ֵ0.5)
    #                    -router:        �Ƿ�ʹ��router test 1Ϊʹ�� 0Ϊ��ʹ��(Ĭ��Ϊ0)
    #                    -srcip:         Դip
    #                    -dstip:         Ŀ��ip
    #                    -srcMAC:        ԴMAC��ַ(Ĭ�ϵ�Ϊhub.slot.port)
    #                    -dstMAC:        Ŀ��MAC��ַ(Ĭ�ϵ�Ϊhub.slot.port)
    #                    -duplex:        ˫��ģʽ 0:��˫�� 1:ȫ˫��(Ĭ��Ϊȫ˫��)
    #                    -lossrate:      ��ʶ����İ����ʧ��
    #                    -delay:         ������һ֡�����ʱ����,Ĭ��Ϊ4��ֱͨ���ߴ洢ת��("cutThrough"/"storeAndForward")
    #                    -singlerate:    ����(Ĭ��ֵ100M)  
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-28 16:38:55
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbAppLatencyTest {PortList args} {
                 
        variable m_ChassisIP
        set ChassisIP  $m_ChassisIP

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        #��ʽת��
        for {set i 0} {$i < [llength $PortList]} {incr i } {
            set temp1 [lindex [lindex $PortList $i] 0]
            set temp1 [split $temp1 .]
            set temp2 [lindex [lindex $PortList $i] 1]
            set temp2 [split $temp2 .]
            set temp "$temp1 $temp2"
            lappend finalls1 $temp
            lappend finalls2 $temp1
            lappend finalls2 $temp2
        }
        
        set TrafficMap $finalls1
        set PortList $finalls2  
        
        set retVal 0
        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        set Duration  10
        set Trialnum  1
        set Customflag 1        
        set Packetlength {64 128}   
        set Learn   1
        set PacketRetry 3
        set Autonegotiate 3
        set Stoperror   1
        set Bidirection 1
        set Inilength   64
        set Stoplength  1518
        set Stepsize    64
        set Inirate 100
        set Maxrate 100
        set Minrate 0.1
        set Tolrate 0.5
        set Router  0
        set Srcip   1.1.1.2
        set Dstip   1.1.2.2
        set SrcMAC  "00 00 00 00 00 01"
        set DstMAC  "00 00 00 00 00 02"
        set Duplex  1
        set Lossrate    0
        set Delay   ""
        set Singlerate  100M    
        set media "fiber"
        set Protocol "ip"
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
        
            case $cmdx      {
                -duration   {set Duration $argx}
                -trialnum  {set Trialnum $argx}
                -customflag {set Customflag $argx}
                -packetlength {set Packetlength $argx}  
                -learn {set Learn $argx}
                -learningretries {set PacketRetry   $argx}
                -autonegotiate {set Autonegotiate $argx}
                -stoperror  {set Stoperror  $argx}
                -bidirection {set Bidirection   $argx}
                -inilength {set Inilength   $argx}
                -stoplength  {set Stoplength    $argx}
                -stepsize {set Stepsize $argx}
                -inirate {set Inirate   $argx}
                -maxrate {set Maxrate   $argx}
                -minrate {set Minrate   $argx}
                -tolrate {set Tolrate   $argx}
                -router {set Router $argx}
                -srcip {set Srcip   $argx}
                -dstip {set Dstip   $argx}
                -srcmac {set SrcMAC $argx}
                -dstmac {set DstMAC $argx}
                -duplex {set Duplex $argx}
                -lossrate {set Lossrate $argx}
                -delay {set Delay   $argx}
                -singlerate {set Singlerate  $argx}
                -media      {set media  $argx}
                -traffictype {set Protocol $argx}
                -inipps {set inipps $argx}
                -maxpps {set maxpps $argx}
                -minpps {set minpps $argx}
                -flowcontrol {set flowcontrol $argx}
                -learningpackets {set learningpackets $argx}
                default     {
                    set retVal 1
                    IxPuts -red  "Error : cmd option $cmdx does not exist"
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }
        
        set Framesizes $Packetlength
        
        if {$Bidirection == 1} {
            set MpDir bidirectional
         }
         
        if {$Bidirection == 0} {
            set MapDir unidirectional
        }

        switch $Router {
            1 {set Protocol "ip"}
            0 {set Protocol "mac"}
            default {
                set retVal 1
                IxPuts -red "No such protocol type, please check -router parameter."
                return $retVal
            }
        }
   
        if { $media == "fiber" } { 
            set media ""
        } else {
            set media "Copper"
        }
        
        switch $Singlerate {
            "10m" -
            "10M" {set Speed ${media}10}
            "100m" -
            "100M" {set Speed ${media}100}
            "1000M" -
            "1000m" -
            "1G" {set Speed ${media}1000}
            default {
                set retVal 1
                IxPuts -red "No such speed mode, please check -singlerate"
                return $retVal
            }
        }
   
        switch $Autonegotiate  {
            3 {set AutoNeg true}
            0 {set AutoNeg false}
            default {
                set retVal 1
                IxPuts -red  "No such autonegotiate parameter, please check -autonegotiate"
                return $retVal
            }
        }
        
        set Trials $Trialnum
        set Tolerance $Tolrate
        set MaxRatePct $Inirate
        set ResultsPath "results/RFC2544_Thruput_results.csv"

        switch $Delay {
            4 {set LatencyType cutThrough}
            5 {set LatencyType storeAndForward}
            default {
                set retVal 1
                IxPuts -red "No such Latency Type, please check -delay parameter"
                return $retVal
            }
        }
        switch $Duplex {
            0 {set DuplexMode half}
            1 {set DuplexMode full}
            default {
                set retVal 1
                IxPuts -red "No such Duplex mode, please check -duplex parameter"
                return $retVal
            }
        }

        DirDel "temp/RFC 2544.resDir"
        logger config -directory "temp"
        logger config -fileBackup true
        results config -directory "temp"
        results config -fileBackup true
        results config -logDutConfig true
        
        global testConf SrcIpAddress DestDUTIpAddress SrcIpV6Address \
                DestDUTIpV6Address IPXSourceSocket VlanID NumVlans
        
        
        logOn "latency.log"
        
        logMsg "\n\n  RFC2544 Latency test"  
        logMsg "  ............................................\n"
        results config -resultFile "Latency.results"
        results config -generateCSVFile false

        user config -productname  "Ixia DUT"
        user config -version      "V1.0"
        user config -serial#      "2007"
        user config -username     "SWTT"
        user config -comments     "������Լ�����"
    
    
        set testConf(hostname) $ChassisIP
        set testConf(chassisID) 1
        set testConf(chassisSequence) 1
        set testConf(cableLength) cable3feet
        
        for {set i 0} {$i< [llength $PortList]} {incr i} {
            set Chas [lindex [lindex $PortList $i] 0]
            set Card [lindex [lindex $PortList $i] 1]
            set Port [lindex [lindex $PortList $i] 2] 
            set testConf(autonegotiate,$Chas,$Card,$Port)  $AutoNeg
            set testConf(duplex,$Chas,$Card,$Port)         $DuplexMode
            set testConf(speed,$Chas,$Card,$Port)          $Speed
        
        }
    
        set testConf(mapFromPort) {1 1 1}
        set testConf(mapToPort) {1 16 4}
        switch $Protocol {
            "mac" {
                set testConf(protocolName) mac
                set testConf(ethernetType) ethernetII   
            }
            
            "ip"  {
                set testConf(protocolName) ip
                for {set i 0} {$i< [llength $PortList]} {incr i} {
                    set Chas [lindex [lindex $PortList $i] 0]
                    set Card [lindex [lindex $PortList $i] 1]
                    set Port [lindex [lindex $PortList $i] 2] 
                    set POIp [lindex [lindex $PortList $i] 3]
                    set GWIp [lindex [lindex $PortList $i] 4]
                    set Mask [lindex [lindex $PortList $i] 5]
                    
                    set SrcIpAddress($Chas,$Card,$Port)      $POIp
                    set DestDUTIpAddress($Chas,$Card,$Port)  $GWIp
                    set testConf($Chas,$Card,$Port)          $Mask
                    set testConf(maskWidthEnabled)           1
                } 
            }
            default {
                set retVal 
                IxPuts -red  "you select wrong protocol, test end."
                return $retVal
            }
        }
    
        set testConf(autoMapGeneration)             no
        set testConf(autoAddressForManual)          no
        set testConf(mapDirection)                  $MapDir
        map new    -type one2one
        map config -type one2one
    
        set k $TrafficMap
        for {set i 0} {$i<[llength $k]} {incr i} {
            map add [lindex [lindex $k $i] 0] [lindex [lindex $k $i] 1] [lindex [lindex $k $i] 2] \
                [lindex [lindex $k $i] 3] [lindex [lindex $k $i] 4] [lindex [lindex $k $i] 5]
        }
    
        map config -echo false
        set testConf(generatePdfEnable) false
        global tputMultipleVlans
        set tputMultipleVlans 1
        set testConf(vlansPerPort) 1
        set testConf(displayResults) true
        set testConf(displayAggResults) true
        set testConf(displayIterations) true
        
        learn config -when        oncePerTest
        learn config -type        default
        learn config -numframes   10
        learn config -retries     10
        learn config -rate        100
        learn config -waitTime    1000
        learn config -framesize   256
     
        latency config -calculateLatency yes
        #latency config -tagDuration 10
        latency config -latencyType $LatencyType
        latency config -framesizeList $Framesizes
        latency config -percentMaxRate $MaxRatePct
        latency config -numtrials $Trials
        latency config -duration  $Duration
              
        advancedTestParameter config -l2DataProtocol native
        fastpath config -enable false
        
    
        if [configureTest [map cget -type]] {
            cleanUp
            return 1
        }
    
        if [catch {latency start} result] {
            logMsg "ERROR: $::errorInfo"
            cleanUp
            return 1
        }

        IxPuts -blue "Writting result file..."
        set SrcFile "temp/RFC 2544.resDir/Latency.resDir/Latency.res/Run0001.res/results.csv"
        file copy -force $SrcFile  $ResultsPath
        IxPuts -blue "Test over!"
        return 0    
    }
    
    #!!================================================================
    #�� �� ����     SmbAppPacketLossTest
    #�� �� ����     IXIA
    #�������     
    #����������     ����L2/L3�Ķ�������
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               PortList:  ����ʹ�õĶ˿��б���:{{1.1.1 1.1.2} {1.2.1 1.2.2}}
    #               args:  
    #                    -duration:      ÿ�η��͵�ʱ��(����ʱ��):1~N integer(Ĭ��Ϊ10)
    #                    -trialnum:      �����׸���(Ĭ��Ϊ1)
    #                    -customflag:    ���Ƿ��ŵ�������������(1:�ǣ�0:�ֹ�ָ�����ĳ���.Ĭ��Ϊ0)
    #                    -packetlength:  �ֹ�ָ�������ݰ�����, �ò�����Ҫָ��һ�����ݰ��ó������б����ʽ�ṩ 
    #                                    ����: -packetlength {64 128 256 512 1024 1518}
    #                    -learn:         �Ƿ���ѧϰ�� 1: ���ͣ� 0: ������(Ĭ��ֵΪ1)
    #                    -packetRetry:   �ط��Ĵ��� (Ĭ��ֵΪ3)
    #                    -autonegotiate: �Ƿ�����Ӧ 3: �ǣ� 0: ������Ӧ(3ΪĬ��ֵ)
    #                    -stoperror:     ���������ʱ��ֹͣ 1: �ǣ� 0: ��(1ΪĬ��ֵ)
    #                    -bidirection:   �Ƿ�֧�������ĵ�/˫���� 1: ֧�֡� 0: ��֧��
    #                    -inilength:     ��ʼ������ ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ64)
    #                    -stoplength:    ��󳤶� ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ1518)
    #                    -stepsize:      ���ݰ�������С ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ64)
    #                    -inirate:       ��ʼ�ٶ� (Ĭ��ֵ100)
    #                    -maxrate:       ����ٶ� (Ĭ��ֵ100) 
    #                    -minrate:       ��С�ٶ� (Ĭ��ֵ0.1)
    #                    -tolrate:       �ٶ����� (Ĭ��ֵ0.5)
    #                    -router:        �Ƿ�ʹ��router test 1Ϊʹ�� 0Ϊ��ʹ��(Ĭ��Ϊ0)
    #                    -srcip:         Դip
    #                    -dstip:         Ŀ��ip
    #                    -srcMAC:        ԴMAC��ַ(Ĭ�ϵ�Ϊhub.slot.port)
    #                    -dstMAC:        Ŀ��MAC��ַ(Ĭ�ϵ�Ϊhub.slot.port)
    #                    -duplex:        ˫��ģʽ 0:��˫�� 1:ȫ˫��(Ĭ��Ϊȫ˫��)
    #                    -lossrate:      ��ʶ����İ����ʧ��
    #                    -delay:         ������һ֡�����ʱ����,ֱͨ���ߴ洢ת��("cutThrough"/"storeAndForward")
    #                    -singlerate:    ����(Ĭ��ֵ100M) 
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-25 9:35:30
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbAppPacketLossTest {PortList args} {   

        variable m_ChassisIP
        set ChassisIP  $m_ChassisIP

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }        

        #��ʽת��
        for {set i 0} {$i < [llength $PortList]} {incr i } {
            set temp1 [lindex [lindex $PortList $i] 0]
            set temp1 [split $temp1 .]
            set temp2 [lindex [lindex $PortList $i] 1]
            set temp2 [split $temp2 .]
            set temp "$temp1 $temp2"
            lappend finalls1 $temp
            lappend finalls2 $temp1
            lappend finalls2 $temp2
        }
        set TrafficMap $finalls1
        set PortList $finalls2  

        set retVal 0
        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        set Duration  10
        set Trialnum  1
        set Customflag 1        
        set Packetlength {64 128}    
        set Learn    1
        set PacketRetry    3
        set Autonegotiate 3
        set Stoperror    1
        set Bidirection    1
        set Inilength    64
        set Stoplength    1518
        set Stepsize    64
        set Inirate    100
        set Maxrate    100
        set Minrate    0.1
        set Tolrate    0.5
        set Router    0
        set Srcip    1.1.1.2
        set Dstip    1.1.2.2
        set SrcMAC    "00 00 00 00 00 01"
        set DstMAC    "00 00 00 00 00 02"
        set Duplex    1
        set Lossrate    0
        set Delay    ""
        set Singlerate  100M
        set media "fiber"
        set Protocol "ip"
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
        
            case $cmdx      {
                -duration   {set Duration $argx}
                -trialnum  {set Trialnum $argx}
                -customflag {set Customflag $argx}
                -packetlength {set Packetlength $argx}    
                -learn {set Learn $argx}
                -learningretries {set PacketRetry    $argx}
                -autonegotiate {set Autonegotiate $argx}
                -stoperror  {set Stoperror    $argx}
                -bidirection {set Bidirection    $argx}
                -inilength {set Inilength    $argx}
                -stoplength  {set Stoplength    $argx}
                -stepsize {set Stepsize    $argx}
                -inirate {set Inirate    $argx}
                -maxrate {set Maxrate    $argx}
                -minrate {set Minrate    $argx}
                -tolrate {set Tolrate    $argx}
                -router {set Router    $argx}
                -srcip {set Srcip    $argx}
                -dstip {set Dstip    $argx}
                -srcmac {set SrcMAC    $argx}
                -dstmac {set DstMAC    $argx}
                -duplex {set Duplex    $argx}
                -lossrate {set Lossrate    $argx}
                -delay {set Delay    $argx}
                -singlerate {set Singlerate  $argx}
                -media      {set media  $argx}
                -traffictype {set Protocol $argx}
                -inipps {set inipps $argx}
                -maxpps {set maxpps $argx}
                -minpps {set minpps $argx}
                -flowcontrol {set flowcontrol $argx}
                -learningpackets {set learningpackets $argx}
                default     {
                    IxPuts -red  "Error : cmd option $cmdx does not exist"
                    set retVal 1
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }
        
        set Framesizes $Packetlength
        
        if {$Bidirection == 1} {
            set MapDir bidirectional
         }
         
        if {$Bidirection == 0} {
            set MapDir unidirectional
        }

        switch $Router {
            1 {set Protocol "ip"}
            0 {set Protocol "mac"}
            default {
                IxPuts -red "No such protocol type, please check -router parameter."
                set retVal 1
                return $retVal
            }
        }
   
        if { $media == "fiber" } { 
            set media ""
        } else {
            set media "Copper"
        }
        
        switch $Singlerate {
            "10m" -
            "10M" {set Speed ${media}10}
            "100m" -
            "100M" {set Speed ${media}100}
            "1000M" -
            "1000m" -
            "1G" {set Speed ${media}1000}
            default {
                set retVal 1
                IxPuts -red "No such speed mode, please check -singlerate"
                return $retVal
            }
        }
   
        switch $Autonegotiate  {
            3 {set AutoNeg true}
            0 {set AutoNeg false}
            default {
                IxPuts -red  "No such autonegotiate parameter, please check -autonegotiate"
                 set retVal 1
                return $retVal
            }
        }
        set FrameNum [llength $Packetlength]
        set Trials $Trialnum
        set Tolerance $Tolrate
        set MaxRatePct $Inirate
        set ResultsPath "results/RFC2544_Thruput_results.csv"
        switch $Duplex {
            0 {set DuplexMode half}
            1 {set DuplexMode full}
            default {
                IxPuts -red "No such Duplex mode, please check -duplex parameter"
                 set retVal 1
                return $retVal
            }
        }
        DirDel "temp/RFC 2544.resDir"
        logger config -directory "temp"
        logger config -fileBackup true
        results config -directory "temp"
        results config -fileBackup true
        results config -logDutConfig true
        
        global testConf SrcIpAddress DestDUTIpAddress SrcIpV6Address \
               DestDUTIpV6Address IPXSourceSocket VlanID NumVlans
        
        
        logOn "frameloss.log"
        
        logMsg "\n\n  RFC2544 Frame Loss test"  
        logMsg "  ............................................\n"
        
        results config -resultFile "Frameloss.results"
        results config -generateCSVFile false
        
        user config -productname  "Ixia DUT"
        user config -version      "V1.0"
        user config -serial#      "2007"
        user config -username     "SWTT"
        user config -comments     "������Լ�����"
    
        set testConf(hostname)                      $ChassisIP
        set testConf(chassisID)                     1
        set testConf(chassisSequence)               1
        set testConf(cableLength)                   cable3feet
        
        for {set i 0} {$i< [llength $PortList]} {incr i} {
            set Chas [lindex [lindex $PortList $i] 0]
            set Card [lindex [lindex $PortList $i] 1]
            set Port [lindex [lindex $PortList $i] 2] 
            set testConf(autonegotiate,$Chas,$Card,$Port)  $AutoNeg
            set testConf(duplex,$Chas,$Card,$Port)         $DuplexMode
            set testConf(speed,$Chas,$Card,$Port)          $Speed
        
        }
    
        set testConf(mapFromPort)                   {1 1 1}
        set testConf(mapToPort)                     {1 16 4}
        switch $Protocol {
            "mac" {
                set testConf(protocolName) mac
                set testConf(ethernetType) ethernetII   
            }
                
            "ip"  {
                set testConf(protocolName) ip
                for {set i 0} {$i< [llength $PortList]} {incr i} {
                    set Chas [lindex [lindex $PortList $i] 0]
                    set Card [lindex [lindex $PortList $i] 1]
                    set Port [lindex [lindex $PortList $i] 2] 
                    set POIp [lindex [lindex $PortList $i] 3]
                    set GWIp [lindex [lindex $PortList $i] 4]
                    set Mask [lindex [lindex $PortList $i] 5]
                    
                    set SrcIpAddress($Chas,$Card,$Port)      $POIp
                    set DestDUTIpAddress($Chas,$Card,$Port)  $GWIp
                    set testConf($Chas,$Card,$Port)          $Mask
                    set testConf(maskWidthEnabled)           1
                } 
            } 
            default {
                IxPuts -red "you select wrong protocol, test end."
                set retVal 1
                return $retVal
            }
        }  
    
        set testConf(autoMapGeneration)             no
        set testConf(autoAddressForManual)          no
        set testConf(mapDirection)                  $MapDir
        map new    -type one2one
        map config -type one2one
        
        set k $TrafficMap
        for {set i 0} {$i<[llength $k]} {incr i} {
            map add [lindex [lindex $k $i] 0] [lindex [lindex $k $i] 1] [lindex [lindex $k $i] 2] \
                    [lindex [lindex $k $i] 3] [lindex [lindex $k $i] 4] [lindex [lindex $k $i] 5]
        }
            
        map config -echo false
        set testConf(generatePdfEnable) false
        global tputMultipleVlans
        set tputMultipleVlans 1
        set testConf(vlansPerPort) 1
        set testConf(displayResults) true
        set testConf(displayAggResults) true
        set testConf(displayIterations) true
    
        learn config -when        oncePerTest
        learn config -type        default
        learn config -numframes   10
        learn config -retries     10
        learn config -rate        100
        learn config -waitTime    1000
        learn config -framesize   256
              
        floss config -rateSelect "percentMaxRate"
        floss config -numFrames $FrameNum
        floss config -percentMaxRate $MaxRatePct
        floss config -framesizeList $Framesizes
        floss config -numtrials $Trials
    
        advancedTestParameter config -l2DataProtocol native
        fastpath config -enable false
    
        if [configureTest [map cget -type]] {
            cleanUp
            return 1
        }
        
        if [catch {floss start} result] {
            logMsg "ERROR: $::errorInfo"
            cleanUp
            return 1
        }

        IxPuts -blue "Writting result file..."
        set SrcFile "temp/RFC 2544.resDir/Frame Loss.resDir/Frameloss.res/Run0001.res/results.csv"
        file copy -force $SrcFile  $ResultsPath
        IxPuts -blue "Test over!"
        return 0
     
    }

    #!!================================================================
    #�� �� ����     SmbAppBackToBackTest
    #�� �� ����     IXIA
    #�������     
    #����������     ����L2/L3�ı��Ա�����
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               PortList:  ����ʹ�õĶ˿��б���:{{1.1.1 1.1.2} {1.2.1 1.2.2}}
    #               args:  
    #                    -duration:      ÿ�η��͵�ʱ��(����ʱ��):1~N integer(Ĭ��Ϊ10)
    #                    -trialnum:      �����׸���(Ĭ��Ϊ1)
    #                    -customflag:    ���Ƿ��ŵ�������������(1:�ǣ�0:�ֹ�ָ�����ĳ���.Ĭ��Ϊ0)
    #                    -packetlength:  �ֹ�ָ�������ݰ�����, �ò�����Ҫָ��һ�����ݰ��ó������б����ʽ�ṩ 
    #                                    ����: -packetlength {64 128 256 512 1024 1518}
    #                    -learn:         �Ƿ���ѧϰ�� 1: ���ͣ� 0: ������(Ĭ��ֵΪ1)
    #                    -packetRetry:   �ط��Ĵ��� (Ĭ��ֵΪ3)
    #                    -autonegotiate: �Ƿ�����Ӧ 3: �ǣ� 0: ������Ӧ(3ΪĬ��ֵ)
    #                    -stoperror:     ���������ʱ��ֹͣ 1: �ǣ� 0: ��(1ΪĬ��ֵ)
    #                    -bidirection:   �Ƿ�֧�������ĵ�/˫���� 1: ֧�֡� 0: ��֧��
    #                    -inilength:     ��ʼ������ ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ64)
    #                    -stoplength:    ��󳤶� ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ1518)
    #                    -stepsize:      ���ݰ�������С ֻ����customflagΪ1��ʱ������ (Ĭ��ֵ64)
    #                    -inirate:       ��ʼ�ٶ� (Ĭ��ֵ100)
    #                    -maxrate:       ����ٶ� (Ĭ��ֵ100) 
    #                    -minrate:       ��С�ٶ� (Ĭ��ֵ0.1)
    #                    -tolrate:       �ٶ����� (Ĭ��ֵ0.5)
    #                    -router:        �Ƿ�ʹ��router test 1Ϊʹ�� 0Ϊ��ʹ��(Ĭ��Ϊ0)
    #                    -srcip:         Դip
    #                    -dstip:         Ŀ��ip
    #                    -srcMAC:        ԴMAC��ַ(Ĭ�ϵ�Ϊhub.slot.port)
    #                    -dstMAC:        Ŀ��MAC��ַ(Ĭ�ϵ�Ϊhub.slot.port)
    #                    -duplex:        ˫��ģʽ 0:��˫�� 1:ȫ˫��(Ĭ��Ϊȫ˫��)
    #                    -lossrate:      ��ʶ����İ����ʧ��
    #                    -delay:         ������һ֡�����ʱ����,Ĭ��Ϊ4,ֱͨ���ߴ洢ת��("cutThrough"/"storeAndForward")
    #                    -singlerate:    ����(Ĭ��ֵ100M) 
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-25 9:47:55
    #�޸ļ�¼��      
    #!!================================================================
    proc SmbAppBackToBackTest {PortList args} {
    
        variable m_ChassisIP
        set ChassisIP  $m_ChassisIP

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }        

        #��ʽת��
        for {set i 0} {$i < [llength $PortList]} {incr i } {
            set temp1 [lindex [lindex $PortList $i] 0]
            set temp1 [split $temp1 .]
            set temp2 [lindex [lindex $PortList $i] 1]
            set temp2 [split $temp2 .]
            set temp "$temp1 $temp2"
            lappend finalls1 $temp
            lappend finalls2 $temp1
            lappend finalls2 $temp2
        }
        set TrafficMap $finalls1
        set PortList $finalls2  

        set retVal 0
        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        
        set Duration  10
        set Trialnum  1
        set Customflag 1        
        set Packetlength {64 128}   
        set Learn   1
        set Packetetry 3
        set Autonegotiate 3
        set Stoperror   1
        set Bidirection 1
        set Inilength   64
        set Stoplength  1518
        set Stepsize    64
        set Inirate 100
        set Maxrate 100
        set Minrate 0.1
        set Tolrate 0.5
        set Router  0
        set Srcip   1.1.1.2
        set Dstip   1.1.2.2
        set SrcMAC  "00 00 00 00 00 01"
        set DstMAC  "00 00 00 00 00 02"
        set Duplex  1
        set Lossrate    0
        set Delay   ""
        set Singlerate  100M
        set media "fiber"
        set Protocol "ip"
        
        while { $tmpllength > 0  } {
            set cmdx [lindex $args $idxxx]
            set argx [lindex $args [expr $idxxx + 1]]
        
            case $cmdx      {
                -duration   {set Duration $argx}
                -trialnum  {set Trialnum $argx}
                -customflag {set Customflag $argx}
                -packetlength {set Packetlength $argx}  
                -learn {set Learn $argx}
                -learningretries {set PacketRetry   $argx}
                -autonegotiate {set Autonegotiate $argx}
                -stoperror  {set Stoperror  $argx}
                -bidirection {set Bidirection   $argx}
                -inilength {set Inilength   $argx}
                -stoplength  {set Stoplength    $argx}
                -stepsize {set Stepsize $argx}
                -inirate {set Inirate   $argx}
                -maxrate {set Maxrate   $argx}
                -minrate {set Minrate   $argx}
                -tolrate {set Tolrate   $argx}
                -router {set Router $argx}
                -srcip {set Srcip   $argx}
                -dstip {set Dstip   $argx}
                -srcmac {set SrcMAC $argx;set SrcMAC [StrMacConvertList $SrcMAC]}
                -dstmac {set DstMAC $argx;set DstMAC [StrMacConvertList $DstMAC]}
                -duplex {set Duplex $argx}
                -lossrate {set Lossrate $argx}
                -delay {set Delay   $argx}
                -singlerate {set Singlerate  $argx}
                -media      {set media  $argx}
                -traffictype {set Protocol $argx}
                -inipps {set inipps $argx}
                -maxpps {set maxpps $argx}
                -minpps {set minpps $argx}
                -flowcontrol {set flowcontrol $argx}
                -learningpackets {set learningpackets $argx}
                default     {
                    IxPuts -red  "Error : cmd option $cmdx does not exist"
                    set retVal 1
                    return $retVal
                }
            }
            incr idxxx  +2
            incr tmpllength -2
        }
        
        set Framesizes $Packetlength
        
        if {$Bidirection == 1} {
            set MapDir bidirectional
         }
         
        if {$Bidirection == 0} {
            set MapDir unidirectional
        }
        
        switch $Router {
            1 {set Protocol "ip"}
            0 {set Protocol "mac"}
            default {
                IxPuts -red "No such protocol type, please check -router parameter."
                set retVal 1
                return $retVal
            }
        }
        
        if { $media == "fiber" } { 
            set media ""
        } else {
            set media "Copper"
        }
        
        switch $Singlerate {
            "10m" -
            "10M" {set Speed ${media}10}
            "100m" -
            "100M" {set Speed ${media}100}
            "1000M" -
            "1000m" -
            "1G" {set Speed ${media}1000}
            default {
                set retVal 1
                IxPuts -red "No such speed mode, please check -singlerate"
                return $retVal
            }
        }
        
        switch $Autonegotiate  {
            3 {set AutoNeg true}
            0 {set AutoNeg false}
            default {
                IxPuts -red  "No such autonegotiate parameter, please check -autonegotiate"
                set retVal 1
                return $retVal
            }
        }
        
        set Trials $Trialnum
        set Tolerance $Tolrate
        set MaxRatePct $Inirate
        set ResultsPath "results/RFC2544_Thruput_results.csv"
        switch $Duplex {
            0 {set DuplexMode half}
            1 {set DuplexMode full}
            default {
                IxPuts -red "No such Duplex mode, please check -duplex parameter"
                set retVal 1
                return $retVal
            }
        }

        DirDel "temp/RFC 2544.resDir"
        logger config -directory "temp"
        logger config -fileBackup true
        results config -directory "temp"
        results config -fileBackup true
        results config -logDutConfig true
        
        global testConf SrcIpAddress DestDUTIpAddress SrcIpV6Address \
                DestDUTIpV6Address IPXSourceSocket VlanID NumVlans
        
        logOn "back2back.log"
        
        logMsg "\n\n  RFC2544 Back to Back test"  
        logMsg "  ............................................\n"
        
        results config -resultFile "back2back.results"
        results config -generateCSVFile false

        user config -productname  "Ixia DUT"
        user config -version      "V1.0"
        user config -serial#      "2007"
        user config -username     "SWTT"
        user config -comments     "������Լ�����"
    
        set testConf(hostname)                      $ChassisIP
        set testConf(chassisID)                     1
        set testConf(chassisSequence)               1
        set testConf(cableLength)                   cable3feet
        
        for {set i 0} {$i< [llength $PortList]} {incr i} {
            set Chas [lindex [lindex $PortList $i] 0]
            set Card [lindex [lindex $PortList $i] 1]
            set Port [lindex [lindex $PortList $i] 2] 
            set testConf(autonegotiate,$Chas,$Card,$Port)  $AutoNeg
            set testConf(duplex,$Chas,$Card,$Port)         $DuplexMode
            set testConf(speed,$Chas,$Card,$Port)          $Speed  
        }
        
        set testConf(mapFromPort)                   {1 1 1}
        set testConf(mapToPort)                     {1 16 4}
        
        switch $Protocol {
            "mac" {
                set testConf(protocolName)               mac
                set testConf(ethernetType)               ethernetII   
            }
            "ip"  {
                set testConf(protocolName)            ip
                for {set i 0} {$i< [llength $PortList]} {incr i} {
                    set Chas [lindex [lindex $PortList $i] 0]
                    set Card [lindex [lindex $PortList $i] 1]
                    set Port [lindex [lindex $PortList $i] 2] 
                    set POIp [lindex [lindex $PortList $i] 3]
                    set GWIp [lindex [lindex $PortList $i] 4]
                    set Mask [lindex [lindex $PortList $i] 5]
                
                    set SrcIpAddress($Chas,$Card,$Port)      $POIp
                    set DestDUTIpAddress($Chas,$Card,$Port)  $GWIp
                    set testConf($Chas,$Card,$Port)          $Mask
                    set testConf(maskWidthEnabled)           1
                } 
            } 
            default {
                IxPuts -red "you select wrong protocol, test end."
                set retVal 1
                return $retVal
            }
        }
    
        set testConf(autoMapGeneration)             no
        set testConf(autoAddressForManual)          no
        set testConf(mapDirection)                  $MapDir
        map new    -type one2one
        map config -type one2one
        
        set k $TrafficMap
        for {set i 0} {$i<[llength $k]} {incr i} {
            map add [lindex [lindex $k $i] 0] [lindex [lindex $k $i] 1] [lindex [lindex $k $i] 2] \
                    [lindex [lindex $k $i] 3] [lindex [lindex $k $i] 4] [lindex [lindex $k $i] 5]
        }
        
        map config -echo false
        set testConf(generatePdfEnable) false
        global tputMultipleVlans
        set tputMultipleVlans 1
        set testConf(vlansPerPort) 1
        set testConf(displayResults) true
        set testConf(displayAggResults) true
        set testConf(displayIterations) true
        
        learn config -when        oncePerTest
        learn config -type        default
        learn config -numframes   10
        learn config -retries     10
        learn config -rate        100
        learn config -waitTime    1000
        learn config -framesize   256
      
        back2back config -duration $Duration
        back2back config -numtrials $Trials
        back2back config -framesizeList $Framesizes
        back2back config -tolerance $Tolerance
        back2back config -rateSelect "percentMaxRate"
        back2back config -percentMaxRate $MaxRatePct
       
        advancedTestParameter config -l2DataProtocol native
        fastpath config -enable false
        
        if [configureTest [map cget -type]] {
            cleanUp
            return 1
        }
        
        if [catch {back2back start} result] {
            logMsg "ERROR: $::errorInfo"
            cleanUp
            return 1
        }
        
        IxPuts -blue "Writting result file..."
        set SrcFile "temp/RFC 2544.resDir/Back to Back.resDir/BackToBack.res/Run0001.res/results.csv"
        file copy -force $SrcFile  $ResultsPath
        IxPuts -blue "Test over!"
        return 0       
    }
    
    #!!================================================================
    #�� �� ����     DirDel
    #�� �� ����     IXIA
    #�������     
    #����������     ɾ��Ŀ¼
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Dir: Ŀ¼��   
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-25 9:22:53
    #�޸ļ�¼��     
    #!!================================================================
    proc DirDel {Dir} {
        set dir $Dir
        if [file isdirectory $dir] {
            foreach f [glob -nocomplain [file join $dir *]] {
                file delete -force $f    
            }
        }
    }
    
    #!!================================================================
    #�� �� ����     SmbSetIpv4Stack
    #�� �� ����     SmbCommon
    #�������     
    #����������     ���ö˿����ò���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               intHub:    SmartBits��hub��
    #               intSlot:   SmartBits�ӿڿ����ڵĲۺ�
    #               intPort:   SmartBits�ӿڿ��Ķ˿ں�
    #               args:
    #                   -mac : ���� MAC ��ַ   0.0.0
    #                   -ip  : ���� IP ��ַ    10.100.10.9
	#					-ip_mod : IP��ַ�������� 1-32 Ĭ��32
	#					-ip_step ��IP��ַ�������� Ĭ��1
	#					-ip_cnt��IP��ַ��������  Ĭ��1
	#					
    #                   -netmask : ������������  255.255.255.0
    #                   -gateway : �������ص�ַ  1.1.1.1
	#					-gateway_mod�����ص�ַ�������� 1-32 Ĭ��32
	#					-gateway_step �����ص�ַ�������� Ĭ��1
	#					-gateway_cnt�����ص�ַ��������  Ĭ��1
	#
    #                   -pingaddress : ����ping��Ŀ�ĵ�ַ  0.0.0.0
    #                   -pingtimes   : ���÷�ping����ʱ����(ÿ��) 5
    #                   -arp_response  : �Ƿ���ӦARP����(0/1)
    #                   -vlan          : VLAN ID
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     y61733
    #�������ڣ�     2009-4-7 16:59:37
    #�޸ļ�¼��     2009-07-23 ������ ��дӲ����API��ixWritePortsToHardware��ΪixWriteConfigToHardware,��ֹ������·down�����,��Ӧ�ľ�ȥ���˼����·״̬�Ĳ���
    #
    #!!================================================================
    proc SmbSetIpv4Stack {chassis card port args} {

        lappend mac      "00 00 39 0B A9 D7"
        set ip           "0.0.0.0"
        set netmask      "24"
        set gateway      "1.1.1.1"
        set pingaddress  "0.0.0.0"
        set pingtimes    5
        set arp_response 0
        set vlan         0
        
		set ip_mod 32
		set ip_step 1
		set ip_cnt 1
		set gateway_mod 32
		set gateway_step 1
		set gateway_cnt 1
		
        set args [string tolower $args]
        
        foreach {paraname tempcontent} $args {
            switch -- $paraname {
                -mac  {
                    
                    # �����û����ݽ����� "xx xx xx xx xx xx"��ʽ��MAC��ַ
                    if {[regexp {^\s*\w\w\s+\w\w\s+\w\w\s+\w\w\s+\w\w\s+\w\w\s*$} $tempcontent]} {
                        set tempcontent [join $tempcontent "-"]
                    }
                    
                    # modify by chenshibing 64165 2009-07-13 ������mac��ַ�����
                    set mac {}
                    foreach one_mac $tempcontent {
                        set one_mac [join $one_mac "-"]
                        set tmp_mac [Common::StrMacConvertList $one_mac]
                        regsub -all {0x} $tmp_mac "" tmp_mac
                        lappend mac $tmp_mac
                    }
                    # modify end
                }
                -ip {
                    set ip $tempcontent
                }
				-ip_mod {
					set ip_mod  $tempcontent
				}
				-ip_step {
					set ip_step $tempcontent
				}
				-ip_cnt {
					set ip_cnt $tempcontent
				}
                -netmask {
                    set netmask $tempcontent
                }
                -gateway  {
                    set gateway $tempcontent
                }
				-gateway_mod {
                    set gateway_mod $tempcontent
				}
				-gateway_step {
                    set gateway_step $tempcontent
				}
				-gateway_cnt {
                    set gateway_cnt $tempcontent
				}
                -pingaddress {
                    set pingaddress $tempcontent
                }
                -pingtimes {
                    set pingtimes $tempcontent
                }
                -arp_response {
                    set arp_response $tempcontent
                }
                -vlan {
                    set vlan $tempcontent
                }
                
                default  {
                }                      
            }
        }
        
        ipAddressTable setDefault 
        ipAddressTable config -defaultGateway     [lindex $gateway 0]
        
        # add by chenshibing 2009-07-31
        #foreach {each_gateway} $gateway {each_ip} $ip {each_mac} $mac {each_vlan} $vlan {
        #    if {[string equal $each_gateway ""]} {
        #        set each_gateway [lindex $gateway end]
        #    }
        #    if {[string equal $each_ip ""]} {
        #        set each_ip [lindex $ip end]
        #    }
        #    if {[string equal $each_mac ""]} {
        #        set each_mac [lindex $mac end]
        #    }
        #    if {[string equal $each_vlan ""]} {
        #        set each_vlan [lindex $vlan end]
        #    }
        #    ipAddressTableItem setDefault
        #    ipAddressTableItem config -fromIpAddress  $each_ip
        #    ipAddressTableItem config -fromMacAddress $each_mac
        #    ipAddressTableItem config -numAddresses 1
        #    ipAddressTableItem set
        #    ipAddressTable addItem
        #}
        # add end
        
        if {[ipAddressTable set $chassis $card $port]} {
            errorMsg "Error calling ipAddressTable set $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        arpServer setDefault 
        arpServer config -retries                            $pingtimes
        arpServer config -mode                               arpGatewayAndLearn
        arpServer config -rate                               2083333
        arpServer config -requestRepeatCount                 $pingtimes
        if {[arpServer set $chassis $card $port]} {
            errorMsg "Error calling arpServer set $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        
        if {[interfaceTable select $chassis $card $port]} {
            errorMsg "Error calling interfaceTable select $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        interfaceTable setDefault 
        interfaceTable config -dhcpV4RequestRate                  0
        interfaceTable config -dhcpV6RequestRate                  0
        interfaceTable config -dhcpV4MaximumOutstandingRequests   100
        interfaceTable config -dhcpV6MaximumOutstandingRequests   100
        if {[interfaceTable set]} {
            errorMsg "Error calling interfaceTable set"
            set retCode $::TCL_ERROR
        }
        
        interfaceTable clearAllInterfaces 
        
		set ipL $ip
		for { set index 1 } { $index < $ip_cnt } { incr index } {
			set ip [ IncrementIPAddr $ip $ip_mod $ip_step ]
			lappend ipL $ip
		}
		set ip $ipL

		set gwL $gateway
		for { set index 1 } { $index < $gateway_cnt } { incr index } {
			set gateway [ IncrementIPAddr $gateway $gateway_mod $gateway_step ]
			lappend gwL $gateway
		}
		set gateway $gwL
		
        foreach {each_gateway} $gateway {each_ip} $ip {each_netmask} $netmask {each_mac} $mac {each_vlan} $vlan {
            if {[string equal $each_gateway ""]} {
                set each_gateway [lindex $gateway end]
            }
            if {[string equal $each_ip ""]} {
                set each_ip [lindex $ip end]
            }
            if {[string equal $each_mac ""]} {
                set each_mac [lindex $mac end]
            }
            if {[string equal $each_vlan ""]} {
                set each_vlan [lindex $vlan end]
            }
            if {[string equal $each_netmask ""]} {
                set each_netmask [lindex $netmask end]
            }
            
            # �� 255.255.0.0 ��ʽת���ɳ��� 16
            if {[regexp -- {\d+\.\d+\.\d+\.\d+} $each_netmask]} {
                set each_netmask [StrIpAddrMaskLengthGet $each_netmask]
            }
            
            interfaceEntry clearAllItems addressTypeIpV6
            interfaceEntry clearAllItems addressTypeIpV4
            interfaceEntry setDefault 
            
            interfaceIpV4 setDefault 
            interfaceIpV4 config -gatewayIpAddress                   $each_gateway
            interfaceIpV4 config -maskWidth                          $each_netmask
            interfaceIpV4 config -ipAddress                          $each_ip
            if {[interfaceEntry addItem addressTypeIpV4]} {
                errorMsg "Error calling interfaceEntry addItem addressTypeIpV4"
                set retCode $::TCL_ERROR
            }
            
            
            dhcpV4Properties removeAllTlvs 
            dhcpV4Properties setDefault 
            dhcpV4Properties config -clientId                           ""
            dhcpV4Properties config -serverId                           "0.0.0.0"
            dhcpV4Properties config -vendorId                           ""
            dhcpV4Properties config -renewTimer                         0
            dhcpV4Properties config -relayAgentAddress                  "0.0.0.0"
            dhcpV4Properties config -relayDestinationAddress            "255.255.255.255"
            
            dhcpV6Properties removeAllTlvs 
            dhcpV6Properties setDefault 
            dhcpV6Properties config -iaType                             dhcpV6IaTypePermanent
            #dhcpV6Properties config -iaId                               957065687
            dhcpV6Properties config -iaId                               [join [split $each_ip "."] ""]
            
            dhcpV6Properties config -renewTimer                         0
            dhcpV6Properties config -relayLinkAddress                   "0:0:0:0:0:0:0:0"
            dhcpV6Properties config -relayDestinationAddress            "FF05:0:0:0:0:0:1:3"
            
            interfaceEntry config -enable                             true
            interfaceEntry config -description                        {ProtocolInterface - 02:05 - 1}
            interfaceEntry config -macAddress                         $each_mac
            interfaceEntry config -eui64Id                            {02 00 39 FF FE 0B A9 D7}
            interfaceEntry config -atmEncapsulation                   atmEncapsulationLLCBridgedEthernetFCS
            interfaceEntry config -mtu                                1500
            interfaceEntry config -enableDhcp                         false
            
            #fixed by yuzhenpin 61733 2009-7-21 15:23:06
            #from
            #interfaceEntry config -enableVlan                        false
            #interfaceEntry config -vlanId                            0
            #to
            if {[string equal $each_vlan "0"]} {
                interfaceEntry config -enableVlan                     false
                interfaceEntry config -vlanId                         0
            } else {
                interfaceEntry config -enableVlan                     true
                interfaceEntry config -vlanId                         $each_vlan
            }
            #end of fixed
            
            interfaceEntry config -vlanPriority                       0
            interfaceEntry config -enableDhcpV6                       false
            interfaceEntry config -ipV6Gateway                        {0:0:0:0:0:0:0:0}
            if {[interfaceTable addInterface interfaceTypeConnected]} {
                errorMsg "Error calling interfaceTable addInterface interfaceTypeConnected"
                set retCode $::TCL_ERROR
            }
        }
        
        protocolServer setDefault 
        if {[string equal "0" $arp_response]} {
            protocolServer config -enableArpResponse              false
        } else {
            protocolServer config -enableArpResponse              true
        }
        protocolServer config -enablePingResponse                 true
        if {[protocolServer set $chassis $card $port]} {
            errorMsg "Error calling protocolServer set $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        
        oamPort setDefault 
        oamPort config -enable                             false
        oamPort config -macAddress                         "00 00 AB BA DE AD"
        oamPort config -enableLoopback                     false
        oamPort config -enableLinkEvents                   false
        oamPort config -maxOamPduSize                      1518
        oamPort config -oui                                "00 00 00"
        oamPort config -vendorSpecificInformation          "00 00 00 00"
        oamPort config -idleTimer                          5
        oamPort config -enableOptionalTlv                  false
        oamPort config -optionalTlvType                    254
        oamPort config -optionalTlvValue                   ""
        if {[oamPort set $chassis $card $port]} {
            errorMsg "Error calling oamPort set $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        lappend portList [list $chassis $card $port]
        
        #modify by chenshibing 2009-07-23 
        #from ixWritePortsToHardware 
        #to ixWriteConfigToHardware and commet link check step
        if [ixWriteConfigToHardware portList] {
               IxPuts -red "Unable to write configs to hardware!"
               catch { ixputs $::ixErrorInfo} err
               set retVal 1
        }
        ixCheckLinkState portList
    }
    
    #!!================================================================
    #�� �� ����     SmbSetIpv6Stack
    #�� �� ����     SmbCommon
    #�������     
    #����������     ���ö˿����ò���
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               intHub:    SmartBits��hub��
    #               intSlot:   SmartBits�ӿڿ����ڵĲۺ�
    #               intPort:   SmartBits�ӿڿ��Ķ˿ں�
    #               args:    #                   
    #                   -mac : ���� MAC ��ַ   0.0.0
    #                   -ip  : ���� IP ��ַ    ��IPV6��ʽ��{0:0:0:0:0:0:0:2}
    #                   -netmask : ������������  255.255.255.0
    #                   -gateway : �������ص�ַ  ����֧��)
    #                   -pingaddress : ����ping��Ŀ�ĵ�ַ  0.0.0.0
    #                   -pingtimes   : ���÷�ping����ʱ����(ÿ��) 5
    #                   -arp_response  : �Ƿ���ӦARP����(0/1)
    #                   -vlan          : VLAN ID
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ��ش�����
    #��    �ߣ�     y61733
    #�������ڣ�     2009-4-7 16:59:37
    #�޸ļ�¼��     2009-07-23 ������ ��дӲ����API��ixWritePortsToHardware��ΪixWriteConfigToHardware,��ֹ������·down�����,��Ӧ�ľ�ȥ���˼����·״̬�Ĳ���
    #
    #!!================================================================
    proc SmbSetIpv6Stack {chassis card port args} {
    
        lappend mac      "00 00 39 0B A9 D7"
        set ip           "0.0.0.0"
        set netmask      {64}
        set gateway      "0:0:0:0:0:0:0:0"
        set pingaddress  "0.0.0.0"
        set pingtimes    5
        set arp_response 0
        set vlan         0
        
        set args [string tolower $args]
        
        foreach {paraname tempcontent} $args {
            switch -- $paraname {
                -mac  {
                    # �����û����ݽ����� "xx xx xx xx xx xx"��ʽ��MAC��ַ
                    if {[regexp {^\s*\w\w\s+\w\w\s+\w\w\s+\w\w\s+\w\w\s+\w\w\s*$} $tempcontent]} {
                        set tempcontent [join $tempcontent "-"]
                    }
                    
                    # modify by chenshibing 64165 2009-07-13 ������mac��ַ�����
                    set mac {}
                    foreach one_mac $tempcontent {
                        set one_mac [join $one_mac "-"]
                        set tmp_mac [Common::StrMacConvertList $one_mac]
                        regsub -all {0x} $tmp_mac "" tmp_mac
                        lappend mac $tmp_mac
                    }
                    # modify end
                }
                -ip {
                    set ip $tempcontent
                    set ip [::IXIA::IxStrIpV6AddressConvert $ip]
                }
                -netmask {
                    set netmask $tempcontent
                }
                -gateway  {
                    set gateway $tempcontent
                }
                -pingaddress {
                    set pingaddress $tempcontent
                }
                -pingtimes {
                    set pingtimes $tempcontent
                }
                -arp_response {
                    set arp_response $tempcontent
                }
                -vlan {
                    set vlan $tempcontent
                }
                
                default  {
                }                      
            }
        }
        
        #ipAddressTable setDefault 
        #ipAddressTable config -defaultGateway     [lindex $gateway 0]
        #
        #if {[ipAddressTable set $chassis $card $port]} {
        #    errorMsg "Error calling ipAddressTable set $chassis $card $port"
        #    set retCode $::TCL_ERROR
        #}
        
        arpServer setDefault 
        arpServer config -retries                            $pingtimes
        arpServer config -mode                               arpGatewayAndLearn
        arpServer config -rate                               2083333
        arpServer config -requestRepeatCount                 $pingtimes
        if {[arpServer set $chassis $card $port]} {
            errorMsg "Error calling arpServer set $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        
        if {[interfaceTable select $chassis $card $port]} {
            errorMsg "Error calling interfaceTable select $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        interfaceTable setDefault 
        interfaceTable config -dhcpV4RequestRate                  0
        interfaceTable config -dhcpV6RequestRate                  0
        interfaceTable config -dhcpV4MaximumOutstandingRequests   100
        interfaceTable config -dhcpV6MaximumOutstandingRequests   100
        if {[interfaceTable set]} {
            errorMsg "Error calling interfaceTable set"
            set retCode $::TCL_ERROR
        }
        
        interfaceTable clearAllInterfaces 
        
        foreach {each_gateway} $gateway {each_ip} $ip {each_mac} $mac {each_vlan} $vlan {
            if {[string equal $each_gateway ""]} {
                set each_gateway [lindex $gateway end]
            }
            if {[string equal $each_ip ""]} {
                set each_ip [lindex $ip end]
            }
            if {[string equal $each_mac ""]} {
                set each_mac [lindex $mac end]
            }
            if {[string equal $each_vlan ""]} {
                set each_vlan [lindex $vlan end]
            }
            
            interfaceEntry clearAllItems addressTypeIpV6
            interfaceEntry clearAllItems addressTypeIpV4
            interfaceEntry setDefault 
            
            #interfaceIpV4 setDefault 
            #interfaceIpV4 config -gatewayIpAddress                   $each_gateway
            #interfaceIpV4 config -maskWidth                          24
            #interfaceIpV4 config -ipAddress                          $each_ip
            #if {[interfaceEntry addItem addressTypeIpV4]} {
            #   errorMsg "Error calling interfaceEntry addItem addressTypeIpV4"
            #   set retCode $::TCL_ERROR
            #}
            
            #�޸Ŀ�ʼ��by liufangxia 2010-2-4 19:24
            #����IPV6�˿�
            interfaceIpV6 setDefault 
			interfaceIpV6 config -maskWidth                           64
			interfaceIpV6 config -ipAddress                           $each_ip
			if {[interfaceEntry addItem addressTypeIpV6]} {
				errorMsg "Error calling interfaceEntry addItem addressTypeIpV6"
				set retCode $::TCL_ERROR
			}
            #�޸Ľ�����by liufangxia 2010-2-4 19:24
            
            dhcpV4Properties removeAllTlvs 
            dhcpV4Properties setDefault 
            dhcpV4Properties config -clientId                           ""
            dhcpV4Properties config -serverId                           "0.0.0.0"
            dhcpV4Properties config -vendorId                           ""
            dhcpV4Properties config -renewTimer                         0
            dhcpV4Properties config -relayAgentAddress                  "0.0.0.0"
            dhcpV4Properties config -relayDestinationAddress            "255.255.255.255"
            
            dhcpV6Properties removeAllTlvs 
            dhcpV6Properties setDefault 
            dhcpV6Properties config -iaType                             dhcpV6IaTypePermanent
            #dhcpV6Properties config -iaId                               957065687
            dhcpV6Properties config -iaId                               [join [split $each_ip "."] ""]
            
            dhcpV6Properties config -renewTimer                         0
            dhcpV6Properties config -relayLinkAddress                   "0:0:0:0:0:0:0:0"
            dhcpV6Properties config -relayDestinationAddress            "FF05:0:0:0:0:0:1:3"
            
            interfaceEntry config -enable                             true
            interfaceEntry config -description                        {ProtocolInterface - 02:05 - 1}
            interfaceEntry config -macAddress                         $each_mac
            interfaceEntry config -eui64Id                            {02 00 39 FF FE 0B A9 D7}
            interfaceEntry config -atmEncapsulation                   atmEncapsulationLLCBridgedEthernetFCS
            interfaceEntry config -mtu                                1500
            interfaceEntry config -enableDhcp                         false
            
            #fixed by yuzhenpin 61733 2009-7-21 15:23:06
            #from
            #interfaceEntry config -enableVlan                        false
            #interfaceEntry config -vlanId                            0
            #to
            if {[string equal $each_vlan "0"]} {
                interfaceEntry config -enableVlan                     false
                interfaceEntry config -vlanId                         0
            } else {
                interfaceEntry config -enableVlan                     true
                interfaceEntry config -vlanId                         $each_vlan
            }
            #end of fixed
            
            interfaceEntry config -vlanPriority                       0
            interfaceEntry config -enableDhcpV6                       false
            
            if {[llength $each_gateway]} {
                interfaceEntry config -ipV6Gateway                    $each_gateway
            } else {
                interfaceEntry config -ipV6Gateway                    {0:0:0:0:0:0:0:0}
            }
            
            if {[interfaceTable addInterface interfaceTypeConnected]} {
                errorMsg "Error calling interfaceTable addInterface interfaceTypeConnected"
                set retCode $::TCL_ERROR
            }
        }
        
        protocolServer setDefault 
        if {[string equal "0" $arp_response]} {
            protocolServer config -enableArpResponse              false
        } else {
            protocolServer config -enableArpResponse              true
        }
        protocolServer config -enablePingResponse                 true
        if {[protocolServer set $chassis $card $port]} {
            errorMsg "Error calling protocolServer set $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        
        oamPort setDefault 
        oamPort config -enable                             false
        oamPort config -macAddress                         "00 00 AB BA DE AD"
        oamPort config -enableLoopback                     false
        oamPort config -enableLinkEvents                   false
        oamPort config -maxOamPduSize                      1518
        oamPort config -oui                                "00 00 00"
        oamPort config -vendorSpecificInformation          "00 00 00 00"
        oamPort config -idleTimer                          5
        oamPort config -enableOptionalTlv                  false
        oamPort config -optionalTlvType                    254
        oamPort config -optionalTlvValue                   ""
        if {[oamPort set $chassis $card $port]} {
            errorMsg "Error calling oamPort set $chassis $card $port"
            set retCode $::TCL_ERROR
        }
        
        lappend portList [list $chassis $card $port]
        #modify by chenshibing 2009-07-23 from ixWritePortsToHardware to ixWriteConfigToHardware and commet link check step
        if [ixWriteConfigToHardware portList] {
               IxPuts -red "Unable to write configs to hardware!"
               set retVal 1
        }
        ixCheckLinkState portList
    }
    #------------------------------------------------------------------------
    
    #return 0
    
    #added by yuzhenpin 61733
    #for ixautomate 6.6
        
        
    ##############################################################
    #��������:��������������Ƿ��ص�ǰ���нű�������,������.tcl
    #        ��:��ǰ���еĽű���C:\test\ScriptMate API\RFC2544\temp.tcl
    #        ��ô�ͷ���temp,תΪScriptmate����,Ϊ�˵���Ӧ��Ŀ¼����ȡ���Խ��
    #��������: argv0
    ##############################################################
    proc GetCurrentFileName  {argv0} {
       set line $argv0
#       puts $line
       set fullname [lindex [split $line \\] 4]
       set partname [file rootname $fullname]
       #puts $partname   
       return $partname
    }
    
    
    
    
    #!!================================================================
    #�� �� ����     IxThroughputTest
    #�� �� ����     IXIA
    #�������     
    #����������     ����L2/L3��������(����֧�ֲ���L2/L3��)
    #�÷���         
    #ʾ����  IxThroughputTest  $ChassisIP $PortList $TrafficMap $MapDir $Speed $DuplexMode \
    #                  $AutoNeg $Framesizes $Duration $Trials $Tolerance $Resolution\
    #                  $MaxRatePct $MinRatePct $Protocol  $Filename      
    #               
    #����˵�������²���ȫ�����Ǳ�ѡ����,���ұ��밴��˳����д,����������б�Ĳ���,����������ú�
    #�б����,��ʹ�ñ���.���ֱ������ֵ�����ַ���,��ֱ����д����.
    #
    # 1.ChassisIP: ������IP��ַ
    # 2.PortList:  ����ʹ�õĶ˿��б����þ�������:
    #                        Chas  Card Port  IP        GateWay   Mask             ����/����  
    #set PortList         { { 1     2    1     "1.1.1.2" "1.1.1.1" "255.255.255.0"  100 } \
    #                       { 1     2    2     "1.1.2.2" "1.1.2.1" "255.255.255.0"  100 } \
    #                     }
    # ������/�����п�ѡ����ֵ��:
    # ���:10/100/1000
    # ���: Fiber1000
    # 10G��̫: 10000
    # WAN��: ethOverSonet ���� ethOverSdh
    #
    # 3.TrafficMap: ��������ģ��.    
    #    ���þ���: set TrafficMap {{1 2 1  1 2 2} {1 2 2  1 2 1}}
    # 4.MapDir  :  ����/˫��
    #    unidirectional
    # �������ȡ�� 5.Speed : �˿�����   10/100/1000/10000(���)  fiber1000(���)
    # 6.DuplexMode: ˫��״̬,  full/half
    # 7.AutoNeg: �Ƿ���Э��, true/false
    # 8.Framesizes:�������б�,  ���� set Framesizes [list 64 512 1518]
    # 9.Duration: ÿ�η��͵�ʱ��,��λ:��
    # 10.Trials: ����ÿ�ְ���,���в��ԵĴ���. һ������Ϊ1
    # 11. Tolerance: ���̶�, һ������Ϊ0
    # 12.Resolution:����, һ������Ϊ0.01
    # 13.MaxPctRate: ������ʵİٷֱ�, һ������Ϊ100, �����ٵ�100%.
    # 14.MinPctRate: ��С���ʵİٷֱ�,һ������Ϊ0.001
    # 15.Protocol: Э������, mac(����) ip(����,�����ARP,��Ҫע������Portlist�еĵ�ַ��Ϣ)
    # 16.Filename: ��ǰִ�еĽű�����,��Ҫ��׺. ��,��ǰ���нű�Ϊmain.tcl,��ô��������main����.
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-28 15:43:15
    #�޸ļ�¼��     2009.6.9
    #!!================================================================
    proc IxThroughputTest {ChassisIP PortList TrafficMap MapDir DuplexMode \
                      AutoNeg Framesizes Duration Trials Tolerance Resolution\
                      MaxRatePct MinRatePct Protocol  Filename  } {
       
       
       if {[file exists results] == 0} {
          file mkdir results   
       }
       if {[file exists temp] == 0} {
          file mkdir temp   
       }   
       set Time [clock format [clock seconds] -format day(20%y-%m-%d)_time(%H-%M-%S)]
       set ResultsPath "results/Throughput_results_$Time"
       
       source templibthruput.tcl
       ixRfc2544_Thruput $ChassisIP $PortList $TrafficMap $MapDir $DuplexMode \
                      $AutoNeg $Framesizes $Duration $Trials $Tolerance $Resolution\
                      $MaxRatePct $MinRatePct $Protocol $ResultsPath  $Filename    
    }
    
    
    
    
    
    #!!================================================================
    #�� �� ����     IxLatencyTest
    #�� �� ����     IXIA
    #�������     
    #����������     ����L2/L3����ʱ����
    #�÷���         
    #ʾ����  IxLatencyTest  $ChassisIP $PortList $TrafficMap $MapDir $Speed $DuplexMode \
    #                  $AutoNeg $Framesizes $Duration $Trials $LatencyType \
    #                  $MaxRatePct $Protocol $Filename     
    #               
    #����˵�������²���ȫ�����Ǳ�ѡ����,���ұ��밴��˳����д,����������б�Ĳ���,����������ú�
    #�б����,��ʹ�ñ���.���ֱ������ֵ�����ַ���,��ֱ����д����.
    #
    # 1.ChassisIP: ������IP��ַ
    # 2.PortList:  ����ʹ�õĶ˿��б����þ�������:
    #                        Chas  Card Port  IP        GateWay   Mask             ����/����  
    #set PortList         { { 1     2    1     "1.1.1.2" "1.1.1.1" "255.255.255.0"  100 } \
    #                       { 1     2    2     "1.1.2.2" "1.1.2.1" "255.255.255.0"  100 } \
    #                     }
    # ������/�����п�ѡ����ֵ��:
    # ���:10/100/1000
    # ���: Fiber1000
    # 10G��̫: 10000
    # WAN��: ethOverSonet ���� ethOverSdh
    # 3.TrafficMap: ��������ģ��.    
    #    ���þ���: set TrafficMap {{1 2 1  1 2 2} {1 2 2  1 2 1}}
    # 4.MapDir  :  ����/˫��
    #    unidirectional
    # �������ȡ�� 5.Speed : �˿�����   10/100/1000/10000(���)  fiber1000(���)
    # 6.DuplexMode: ˫��״̬,  full/half
    # 7.AutoNeg: �Ƿ���Э��, true/false
    # 8.Framesizes:�������б�,  ���� set Framesizes [list 64 512 1518]
    # 9.Duration: ÿ�η��͵�ʱ��,��λ:��
    # 10.Trials: ����ÿ�ְ���,���в��ԵĴ���. һ������Ϊ1
    # 11.LatencyType: ��ʱ����, һ������Ϊ "cutThrough"  ��ѡֵ: "storeAndForward"/"cutThrough"
    # 12.MaxRatePct: �������ԵĶ˿�����. Ϊ���ٵİٷֱ�.
    # 13.Protocol: Э������, mac(����) ip(����,�����ARP,��Ҫע������Portlist�еĵ�ַ��Ϣ)
    # 14.Filename: ��ǰִ�еĽű�����,��Ҫ��׺. ��,��ǰ���нű�Ϊmain.tcl,��ô��������main����.
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-28 15:43:15
    #�޸ļ�¼��     2009.6.9
    #!!================================================================
    proc IxLatencyTest { ChassisIP PortList TrafficMap MapDir DuplexMode \
                            AutoNeg Framesizes Duration Trials LatencyType \
                            MaxRatePct Protocol Filename  } {
       if {[file exists results] == 0} {
          file mkdir results   
       }
       if {[file exists temp] == 0} {
          file mkdir temp   
       }      
       set Time [clock format [clock seconds] -format day(20%y-%m-%d)_time(%H-%M-%S)]
       set ResultsPath "results/Latency_results_$Time"
       source templiblatency.tcl
       ixRfc2544_Latency $ChassisIP $PortList $TrafficMap $MapDir $DuplexMode \
                      $AutoNeg $Framesizes $Duration   $Trials $LatencyType \
                      $MaxRatePct $Protocol $ResultsPath $Filename
       
    }
    
    
    
    #!!================================================================
    #�� �� ����     IxPacketLossTest
    #�� �� ����     IXIA
    #�������     
    #����������     ����L2/L3�Ķ�������
    #�÷���         
    #ʾ����  IxPacketLossTest  $ChassisIP $PortList $TrafficMap $MapDir $Speed $DuplexMode \
    #                    $AutoNeg $Framesizes $FrameNum  $Trials  \
    #                    $MaxRatePct $Protocol  $Filename     
    #               
    #����˵�������²���ȫ�����Ǳ�ѡ����,���ұ��밴��˳����д,����������б�Ĳ���,����������ú�
    #�б����,��ʹ�ñ���.���ֱ������ֵ�����ַ���,��ֱ����д����.
    #
    # 1.ChassisIP: ������IP��ַ
    # 2.PortList:  ����ʹ�õĶ˿��б����þ�������:
    #                        Chas  Card Port  IP        GateWay   Mask             ����/����  
    #set PortList         { { 1     2    1     "1.1.1.2" "1.1.1.1" "255.255.255.0"  100 } \
    #                       { 1     2    2     "1.1.2.2" "1.1.2.1" "255.255.255.0"  100 } \
    #                     }
    # ������/�����п�ѡ����ֵ��:
    # ���:10/100/1000
    # ���: Fiber1000
    # 10G��̫: 10000
    # WAN��: ethOverSonet ���� ethOverSdh
    # 3.TrafficMap: ��������ģ��.    
    #    ���þ���: set TrafficMap {{1 2 1  1 2 2} {1 2 2  1 2 1}}
    # 4.MapDir  :  ����/˫��
    #    unidirectional
    # �������ȡ�� 5.Speed : �˿�����   10/100/1000/10000(���)  fiber1000(���)
    # 6.DuplexMode: ˫��״̬,  full/half
    # 7.AutoNeg: �Ƿ���Э��, true/false
    # 8.Framesizes:�������б�,  ���� set Framesizes [list 64 512 1518]
    # 9.FrameNum: ÿ�η��͵ı��ĸ���,��λ:����
    # 10.Trials: ����ÿ�ְ���,���в��ԵĴ���. һ������Ϊ1
    # 11.MaxRatePct: �������ԵĶ˿�����. Ϊ���ٵİٷֱ�.
    # 12.Protocol: Э������, mac(����) ip(����,�����ARP,��Ҫע������Portlist�еĵ�ַ��Ϣ)
    # 13.Filename: ��ǰִ�еĽű�����,��Ҫ��׺. ��,��ǰ���нű�Ϊmain.tcl,��ô��������main����.
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-28 15:43:15
    #�޸ļ�¼��     2009.6.9
    #!!================================================================
    proc IxPacketLossTest { ChassisIP PortList TrafficMap MapDir DuplexMode \
                            AutoNeg Framesizes FrameNum Trials \
                            MaxRatePct Protocol Filename  } {
       if {[file exists results] == 0} {
          file mkdir results   
       }
       if {[file exists temp] == 0} {
          file mkdir temp   
       }      
       set Time [clock format [clock seconds] -format day(20%y-%m-%d)_time(%H-%M-%S)]
       set ResultsPath "results/Frameloss_results_$Time"
       source templibframeloss.tcl
       ixRFC2544_Frameloss $ChassisIP $PortList $TrafficMap $MapDir $DuplexMode \
                         $AutoNeg $Framesizes $FrameNum  $Trials  \
                         $MaxRatePct $Protocol $ResultsPath $Filename     
    }
    
    
    
    
    #!!================================================================
    #�� �� ����     IxBackToBackTest
    #�� �� ����     IXIA
    #�������     
    #����������     ����DUT��L2/L3�ı��Ա�����
    #�÷���         
    #ʾ����  IxBackToBackTest  $ChassisIP $PortList $TrafficMap $MapDir $Speed  $DuplexMode \
    #                     $AutoNeg $Framesizes $Duration   $Trials $Tolerance \
    #                     $MaxRatePct $Protocol  $Filename    
    #               
    #����˵�������²���ȫ�����Ǳ�ѡ����,���ұ��밴��˳����д,����������б�Ĳ���,����������ú�
    #�б����,��ʹ�ñ���.���ֱ������ֵ�����ַ���,��ֱ����д����.
    #
    # 1.ChassisIP: ������IP��ַ
    # 2.PortList:  ����ʹ�õĶ˿��б����þ�������:
    #                        Chas  Card Port  IP        GateWay   Mask             ����/����  
    #set PortList         { { 1     2    1     "1.1.1.2" "1.1.1.1" "255.255.255.0"  100 } \
    #                       { 1     2    2     "1.1.2.2" "1.1.2.1" "255.255.255.0"  100 } \
    #                     }
    # ������/�����п�ѡ����ֵ��:
    # ���:10/100/1000
    # ���: Fiber1000
    # 10G��̫: 10000
    # WAN��: ethOverSonet ���� ethOverSdh
    # 3.TrafficMap: ��������ģ��.    
    #    ���þ���: set TrafficMap {{1 2 1  1 2 2} {1 2 2  1 2 1}}
    # 4.MapDir  :  ����/˫��
    #    unidirectional
    # �������ȡ�� 5.Speed : �˿�����   10/100/1000/10000(���)  fiber1000(���)
    # 6.DuplexMode: ˫��״̬,  full/half
    # 7.AutoNeg: �Ƿ���Э��, true/false
    # 8.Framesizes:�������б�,  ���� set Framesizes [list 64 512 1518]
    # 9.Duration: ÿ�η��͵�ʱ��,��λ:��
    # 10.Trials: ����ÿ�ְ���,���в��ԵĴ���. һ������Ϊ1
    # 11. Tolerance: ���̶�, һ������Ϊ0
    # 12.Resolution:����, һ������Ϊ0.01
    # 13.MaxPctRate: ������ʵİٷֱ�, һ������Ϊ100, �����ٵ�100%.
    # 14.MinPctRate: ��С���ʵİٷֱ�,һ������Ϊ0.001
    # 15.Protocol: Э������, mac(����) ip(����,�����ARP,��Ҫע������Portlist�еĵ�ַ��Ϣ)
    # 16.Filename: ��ǰִ�еĽű�����,��Ҫ��׺. ��,��ǰ���нű�Ϊmain.tcl,��ô��������main����.
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ��׿
    #�������ڣ�     2006-7-28 15:43:15
    #�޸ļ�¼��     2009.6.9
    #!!================================================================
    proc IxBackToBackTest {ChassisIP PortList TrafficMap MapDir DuplexMode \
                      AutoNeg Framesizes Duration Trials Tolerance \
                      MaxRatePct Protocol  Filename  } {
       if {[file exists results] == 0} {
          file mkdir results   
       }
       if {[file exists temp] == 0} {
          file mkdir temp   
       }      
       set Time [clock format [clock seconds] -format day(20%y-%m-%d)_time(%H-%M-%S)]
       set ResultsPath "results/backtoback_results_$Time"

       source templibbacktoback.tcl
       ixRFC2544_BackToBack $ChassisIP $PortList $TrafficMap $MapDir  $DuplexMode \
                         $AutoNeg $Framesizes $Duration   $Trials $Tolerance \
                         $MaxRatePct $Protocol $ResultsPath $Filename  
    }    
    #!!================================================================
    #�� �� ����     SmbPortReboot
    #�� �� ����     IXIA
    #�������     
    #����������     ��λIxia���˿ڣ�����CPU
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:          Ixia��hub��
    #               Card:          Ixia�ӿڿ����ڵĲۺ�
    #               Port:          Ixia�ӿڿ��Ķ˿ں�
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ����
    #�������ڣ�     2010-11-8 9:09
    #�޸ļ�¼��     
    #!!================================================================
	proc SmbPortReboot { Chas Card Port } {
		return [ portCpu reset $Chas $Card $Port ]					
	}

    #!!================================================================
    #�� �� ����     SmbPortArpTableClear
    #�� �� ����     IXIA
    #�������     
    #����������     ����˿�ARP��
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:     Ixia��hub��
    #               Card:     Ixia�ӿڿ����ڵĲۺ�
    #               Port:     Ixia�ӿڿ��Ķ˿ں�
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ����
    #�������ڣ�     2010-12-14 
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortArpTableClear { Chas Card Port } {
    		return [ ixClearPortArpTable $Chas $Card $Port ]
    }
    
    #!!================================================================
    #�� �� ����     SmbPortArpRequest
    #�� �� ����     IXIA
    #�������     
    #����������     �˿ڷ���ARP����
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:     Ixia��hub��
    #               Card:     Ixia�ӿڿ����ڵĲۺ�
    #               Port:     Ixia�ӿڿ��Ķ˿ں�
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ����
    #�������ڣ�     2010-12-14 
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortArpRequest { Chas Card Port } {
    		return [ ixTransmitPortArpRequest $Chas $Card $Port ]
    }

	# -- Transfer the ip address to hex
	#   -- prefix should be the valid length of result string like the length of
	#       1c231223 is 1c23 when prefix is 16
	#       the enumation of prefix should be one of 8 16 32
	proc IP2Hex { ipv4 { prefix 32 } } {
		if { [ regexp {(\d+)\.(\d+)\.(\d+)\.(\d+)} $ipv4 match A B C D ] } {
			set ipHex [ Int2Hex $A ][ Int2Hex $B ][ Int2Hex $C ][ Int2Hex $D ]
			return [ string range $ipHex 0 [ expr $prefix / 4 - 1 ] ]
		} else {
			return 00000000
		}
	}

	proc Mac2Hex { mac } {
		set value $mac
		set len [ string length $value ]
		for { set index 0 } { $index < $len } { incr index } {
			if { [ string index $value $index ] == " " || \
				[ string index $value $index ] == "-" ||
				[ string index $value $index ] == "." ||
				[ string index $value $index ] == ":" } {

				set value [ string replace $value $index $index " " ] 

			}
		}

		return $value
		
	}

	# -- Transfer the integer to hex
	#   -- len should be the length of result string like the length of 'abcd' is 4
	proc Int2Hex { byte { len 2 } } {
		set hex [ format %x $byte ]
		set hexlen [ string length $hex ]
		if { $hexlen < $len } {
			set hex [ string repeat 0 [ expr $len - $hexlen ] ]$hex
		} elseif { $hexlen > $len } {
			set hex [ string range $hex [ expr $hexlen - $len ] end ]
		}
		return $hex
	}
	proc IncrementIPAddr { IP prefixLen { num 1 } } {
		set Increament_len [ expr 32 - $prefixLen ]
		set Increament_pow [ expr pow(2,$Increament_len) ]
		set Increament_int [ expr round($Increament_pow*$num) ]
		set IP_hex       0x[ IP2Hex $IP ]
		set IP_next_int    [ expr $IP_hex + $Increament_int ]
		if { $IP_next_int > [ format %u 0xffffffff ] } {
			error "Out of address bound"
		}
		set IP_next_hex    [ format %x $IP_next_int ]
		if { [ string length $IP_next_hex ] < 8 } {
			set IP_next_hex [ string repeat 0 [ expr 8 - [ string length $IP_next_hex ] ] ]$IP_next_hex
		} elseif { [ string length $IP_next_hex ] > 8 } {
			#...
			#error ""
		}
		set index_end  0
		set A [ string range $IP_next_hex $index_end [ expr $index_end + 1 ] ]
		incr index_end 2
		set B [ string range $IP_next_hex $index_end [ expr $index_end + 1 ] ]
		incr index_end 2
		set C [ string range $IP_next_hex $index_end [ expr $index_end + 1 ] ]
		incr index_end 2
		set D [ string range $IP_next_hex $index_end [ expr $index_end + 1 ] ]
		return [format %u 0x$A].[format %u 0x$B].[format %u 0x$C].[format %u 0x$D]
	}
	proc IncrementIPv6Addr { IP prefixLen { num 1 } } {
	Deputs "pfx len:$prefixLen IP:$IP num:$num"
		set segList [ split $IP ":" ]
		set seg [ expr $prefixLen / 16 - 1 ]
	Deputs "set:$seg"
		set offset [ expr fmod($prefixLen,16) ]
	Deputs "offset:$offset"
		if { $offset  > 0 } {
			incr seg
		}
	Deputs "set:$seg"
		set segValue [ lindex $segList $seg ]
	Deputs "segValue:$segValue"
		set segInt 	 [ format %i 0x$segValue ]
	Deputs "segInt:$segInt"
		if { $offset } {
			incr segInt  [ expr round(pow(2, 16 - $offset)*$num )]
		} else {
			incr segInt $num
		}
	Deputs "segInt:$segInt"
		if { $segInt > 65535 } {
			incr segInt -65536
			set segHex [format %x $segInt]
	Deputs "segHex:$segHex"
			set segList [lreplace $segList $seg $seg $segHex]
			set newIp ""
			foreach segment $segList {
				set newIp ${newIp}:$segment
			}
			set IP [ string range $newIp 1 end ]
	Deputs "IP:$IP"
			return [ IncrementIPv6Addr $IP [ expr $seg * 16 ] ]
		} else {
			set segHex [format %x $segInt]
			set segList [lreplace $segList $seg $seg $segHex]
			set newIp ""
			foreach segment $segList {
				set newIp ${newIp}:$segment
			}
			set IP [ string range $newIp 1 end ]
			return [ string tolower $IP ]

		}
	}
    #!!================================================================
    #�� �� ����     SmbPortClearStream
    #�� �� ����     IXIA
    #�������     
    #����������     clear port streams
    #�÷���         
    #ʾ����         
    #               
    #����˵����     
    #               Chas:     Ixia��hub��
    #               Card:     Ixia�ӿڿ����ڵĲۺ�
    #               Port:     Ixia�ӿڿ��Ķ˿ں�
    #�� �� ֵ��     �ɹ�����0,ʧ�ܷ���1
    #��    �ߣ�     ����
    #�������ڣ�     2012-7-11
    #�޸ļ�¼��     
    #!!================================================================
    proc SmbPortClearStream { Chas Card Port } {
	
	port get $Chas $Card $Port
	
	set attrList [ list -speed -duplex -flowControl -directedAddress -multicastPauseAddress -loopback -transmitMode -receiveMode -autonegotiate -advertise100FullDuplex -advertise100HalfDuplex -advertise10FullDuplex -advertise10HalfDuplex -advertise1000FullDuplex -usePacketFlowImageFile -packetFlowFileName -portMode -enableDataCenterMode -dataCenterMode -flowControlType -pfcEnableValueListBitMatrix -pfcEnableValueList -pfcResponseDelayEnabled -pfcResponseDelayQuanta -rxTxMode -ignoreLink -advertiseAbilities -timeoutEnable -negotiateMasterSlave -masterSlave -pmaClock -sonetInterface -lineScrambling -dataScrambling -useRecoveredClock -sonetOperation -enableSimulateCableDisconnect -enableAutoDetectInstrumentation -autoDetectInstrumentationMode -enableRepeatableLastRandomPattern -transmitClockDeviation -transmitClockMode -preEmphasis -transmitExtendedTimestamp -operationModeList -owner -typeName -linkState -type -gigVersion -txFpgaVersion -rxFpgaVersion -managerIp -phyMode -lastRandomSeedValue -portState -stateDuration -MacAddress -DestMacAddress -name -numAddresses -rateMode -enableManualAutoNegotiate -enablePhyPolling -enableTxRxSyncStatsMode -txRxSyncInterval -enableTransparentDynamicRateChange -enableDynamicMPLSMode -enablePortCpuFlowControl -portCpuFlowControlDestAddr -portCpuFlowControlSrcAddr -portCpuFlowControlPriority -portCpuFlowControlType -enableWanIFSStretch ]
	
	array set attrVal [list]
	
	foreach attr $attrList {
	
		set tempVal [ port cget $attr ]
		set attrVal($attr) $tempVal
puts "$attr:$attrVal($attr)"		
	}
	
	port reset $Chas $Card $Port
	port set   $Chas $Card $Port
	
	#set portList [ list $Chas $Card $Port ]
	#ixWritePortsToHardware portList
	
	port get $Chas $Card $Port
	
    	foreach attr $attrList {
puts "attr:$attr"
	    catch {
    		port configure $attr $attrVal($attr)
    	    }
    	}
    	port set $Chas $Card $Port
    }

}


     
