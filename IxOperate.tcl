if {[info exists ::__IXOPERATE_TCL__]} {
    return
}

set ::__IXOPERATE_TCL__ 1

package provide IXIA 1.0
package require registry
#start:added by yuzhenpin 61733 2009-1-24 10:38:13
#获取IxOS的安装路径并加载IxOS
#作者：yuzhenpin 61733
#时间：2009-1-24 10:33:53
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
            #error "从注册表获取IxOS的路径失败！原因可能是IxOS没有正确安装！"
            catch {
                ::Utils::Log::debug IXIA "如果使用IXIA仪表，请安装IxOS！"
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
            #error "从注册表获取IxOS的路径失败！原因可能是IxOS没有正确安装！"
            catch {
                ::Utils::Log::debug IXIA "如果使用IXIA仪表，请安装IxAutomate！"
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
    
    #如果没有安装ixia那么直接返回
    #继续加载已经没有意义
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
#版权 (C) 2001-2002，华为技术有限公司 光网络测试部
#==================================================================
#文 件 名：    IxOperate.tcl
#文件说明：    对IXIA 400T仪表进行封装
#作    者：    杨卓
#编写日期：    2006-7-13 11:14:2
#修改纪录：    
#!+================================================================

namespace eval IXIA {
    variable m_debugflag 0X03       ;#内部变量，用于调试
    variable m_ChassisIP 127.0.0.1  ;#IXIA仪表IP地址
	variable m_trigger 0            ;#过滤报文标志
    
    variable m_portList [list]
    
    #从0-based转换成1-based
    #跟Smartbits一致
    proc _2_1base_ {_0_based_} {
        return [expr $_0_based_ + 1]
    }
    
    #!!================================================================
    #过 程 名：     SmbDebug
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     调试函数
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               args:   输出的调试信息 
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     杨卓
    #生成日期：     2006-7-13 15:8:36
    #修改纪录：     
    #!!================================================================
    proc SmbDebug {args} {
        set retVal [uplevel $args]
        if {$retVal > 0} {
            IxPuts -red "ERROR:$retVal RETURNED BY ==> $args"
        }
    }

    #!!================================================================
    #过 程 名：     SmbArpPacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     在端口上配置一条Arp流
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:      Ixia的hub号
    #               Card:      Ixia接口卡所在的槽号
    #               Port:      Ixia接口卡的端口号  
    #               DstMac:    目的Mac地址
    #               DstIP:     目的IP地址
    #               SrcMac:    源Mac地址
    #               SrcIP:     源IP地址
    #               args: (可选参数,请见下表)
    #                       -arptype   使用的时候填入数字即可.
    #                                 1: arpRequest (default) , 
    #                                 2: arpReply 2 ARP reply or response
    #                                 3: rarpRequest 3 RARP request
    #                                 4: rarpReply 4 RARP reply or response
    #                       -metric      流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
    #                       -length      报文总长度，缺省情况下使用随机包长
    #                       -vlan        报文的VLAN值，缺省情况下报文不带vlan
    #                       -change      修改数据包中的指定字段，此参数标识修改字段的字节偏移量
    #                       -value       修改数据的内容  
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 9:59:2
    #修改纪录：     
    #!!================================================================
    proc SmbArpPacketSet {Chas Card Port DstMac DstIP SrcMac SrcIP args} {
        set retVal     0

        #验证输入参数
        if {[IxParaCheck "-dstmac $DstMac -dstip $DstIP -srcmac $SrcMac -srcip $SrcIP $args"] == 1} {
            set retVal 1
            return $retVal
        }
        
        set tmpList    [lrange $args 0 end]
        set idxxx      0
        set tmpllength [llength $tmpList]
        #阳诺 edit 2006－07-20 mac地址转换 
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
    #过 程 名：     SmbCapPacketLengthGet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     获取捕获的包的长度
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:      Ixia的hub号
    #               Card:      Ixia接口卡所在的槽号
    #               Port:      Ixia接口卡的端口号   
    #               args:    
    #                        -index packet的序号,默认是0
    #返 回 值：     返回一个列表，包含两个元素
    #               1）函数执行结果
    #               0:函数执行成功
    #               1:函数执行失败
    #               1000:其它错误
    #               2）指定的被捕获报文的长度
    #作    者：     杨卓
    #生成日期：     2006-7-14 9:54:59
    #修改纪录：     
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
        #阳诺 edit 2006-07-27 对PktCnt做判断
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
    #过 程 名：     SmbCaptureClear
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     清除缓冲内捕获的报文
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:    Ixia的hub号
    #               Card:    Ixia接口卡所在的槽号
    #               Port:    Ixia接口卡的端口号
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 18:29:43
    #修改纪录：     
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
    #过 程 名：     SmbCapturePktCount
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     取得某一端口缓冲区包的数量
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:    Ixia的hub号
    #               Card:    Ixia接口卡所在的槽号
    #               Port:    Ixia接口卡的端口号
    #返 回 值：     返回一个列表包括俩项:1.0或者1,0表示成功，1表示失败
    #                                    2.包的数量
    #作    者：     杨卓
    #生成日期：     2006-7-13 18:39:21
    #修改纪录：     
    #!!================================================================
    proc SmbCapturePktCount {Chas Card Port} {
        set retVal 0
        set PktCnt 0

        #阳诺 edit 2006-07-27
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
    #过 程 名：     SmbCapturePktGet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     取得用户指定的捕获缓存内某个报文的指定字段
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:    Ixia的hub号
    #               Card:    Ixia接口卡所在的槽号
    #               Port:    Ixia接口卡的端口号
    #               args:    
    #                    -index:  捕获报文的索引，从0开始排序，缺省值为0
    #                    -offset: 返回字段的偏移量，缺省值为0
    #                    -len:    返回字段的字节长度，缺省值为0，表示返回从偏移位开始到报文结尾内容
    #返 回 值：     返回一个列表包括俩项:1.0或者1,0表示成功，1表示失败
    #                                    2.报文字段内容
    #作    者：     杨卓
    #生成日期：     2006-7-13 19:56:36
    #修改纪录：     
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
                #高娟反馈smartbits返回的是10进制的
                #而ixia返回的是16进制的
                #这里转换成十进制的
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
    #过 程 名：     SmbCapturePortsStart
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     端口开始抓包
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               PortList:   {{$Chas1 $Card1 $Port1} {$Chas2 $Card2 $Port2} ... {$ChasN $CardN $PortN}} 
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     杨卓
    #生成日期：     2006-7-13 15:14:53
    #修改纪录：     
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
    #过 程 名：     SmbCaptureStart
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     端口开始抓包
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:    Ixia的hub号
    #               Card:    Ixia接口卡所在的槽号
    #               Port:    Ixia接口卡的端口号
    #               args:     可选参数，设置报文捕获类型，缺省表示捕获所有报文
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     杨卓
    #生成日期：     2006-7-13 18:1:43
    #修改纪录：     modify by chenshibing 2009-05-21 增加对-trigger参数的处理
    #               2009-07-23 陈世兵 把写硬件的API由ixWritePortsToHardware改为ixWriteConfigToHardware,防止出现链路down的情况
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
        	#当不应用trigger抓包时，改变抓包模式，以防前面曾应用过trigger抓包影响   
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
    #过 程 名：     SmbCaptureStop
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     端口停止抓包
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:    Ixia的hub号
    #               Card:    Ixia接口卡所在的槽号
    #               Port:    Ixia接口卡的端口号
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 18:24:21
    #修改纪录：     
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
    #过 程 名：     SmbChecksumcalc
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     计算校验和
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               array1:               待计算的数组
    #               start, 缺省值：14:    数组的起始下标
    #               stop, 缺省值：33:     数组的终点下标
    #返 回 值：     计算出的16bit的checksum结果
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:7:24
    #修改纪录：     
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
     #过 程 名：     SmbClosePort
     #程 序 包：     IXIA
     #功能类别：     
     #过程描述：     关闭或者打开指定的端口
     #用法：         
     #示例：         
     #               
     #参数说明：     
     #               Chas:    Ixia的hub号
     #               Card:    Ixia接口卡所在的槽号
     #               Port:    Ixia接口卡的端口号
     #               isClose: 是否关闭仪表的端口,默认为 off 关闭   
     #返 回 值：     成功返回0,失败返回错误码
     #作    者：     杨卓
     #生成日期：     2006-7-13 20:9:43
     #修改纪录：     
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
    #过 程 名：     SmbFlowCtrlModeSet
    #程 序 包：     SmbCommon
    #功能类别：     
    #过程描述：     流控设置
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               hub:    IXIA的hub号
    #               slot:   IXIA接口卡所在的槽号
    #               port:   IXIA接口卡的端口号    
    #               args:
    #                   -pauseflow : pause 流控类型(仅适用于GE卡), 取值: disable, asym, sym, both 
    #                       "disable" = 不使能端口流控 (收发双向关闭流控功能，None)
    #                       "asym" = 使能非对称流控 (Asymmetric->Link Partner)
    #                       "sym"  = 使能对称流控 (Symmetric)
    #                       "both" = 使能非对称/对称流控 (Asymmetric->LocalDevice)
    #                   FlowCtrlMode: 流控方式; 取值:
    #                               enable    使能流控
    #                               disable   不使能流控   
    #                   PreambleLen, 缺省值：64:以太帧前导码的长度,可选参数,为本过程的附带功能,仅适合于FE    
    #返 回 值：     成功返回0,失败返回1
    #作    者：     唐美华
    #生成日期：     2007-4-23 16:15:10
    #修改纪录：     
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
                IxPuts -red "参数错误$FlowCtrlMode,参数只能是enable或disable"
                return 1
            }
        }
        # 使能流控
        port config -flowControl $FlowCtrlMode

        # 流控类型设置
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
    #过 程 名：     SmbCustomPacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     Ixia发送用户自定义报文设置(数据文件中的数据定义务必是tcl识别的有效数据)
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:     Ixia的hub号
    #               Card:     Ixia接口卡所在的槽号
    #               Port:     Ixia接口卡的端口号
    #               Len:      报文长度
    #               Lcon:     报文内容
    #                       -strtransmode   定义流发送的模式,可以0:连续发送 1:发送完指定包数目后停止 2:发送完本条流后继续发送下一条流.
    #                       -strframenum    定义本条流发送的包数目
    #                       -strrate        发包速率,线速的百分比. 100 代表线速的 100%, 1 代表线速的 1%
    #                       -strburstnum    定义本条流包含多少个burst,取值范围1~65535,默认为1
    #               streamID:    
    #返 回 值：     0:函数执行成功;1:函数执行失败;1000:其它错误
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:13:25
    #修改纪录：     2009-07-23 陈世兵 把写硬件的API由ixWritePortsToHardware改为ixWriteConfigToHardware,防止出现链路down的情况
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
    #过 程 名：     SmbDeleteStreams
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     根据流ID来清除端口上的流.
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:     Ixia的hub号
    #               Card:     Ixia接口卡所在的槽号
    #               Port:     Ixia接口卡的端口号    
    #               sList:    流ID列表,如 "1 2 3 4...",用户需要确定已经知道这些流存在于端口上.
    #                         如果列表为空"",则表示清除端口上所有的流.
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:20:47
    #修改纪录：     
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
       # modify by 陈世兵 2009-07-23增加了-noProtocolServer参数
       if {[ixWriteConfigToHardware portList -noProtocolServer]} {
           IxPuts -red "Unable to write config to hardware"
           set retVal 1
       }
       return $retVal
    }

    #!!================================================================
    #过 程 名：     IxErrorSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     设置端口错误包类型
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:      Ixia的hub号
    #               Card:      Ixia接口卡所在的槽号
    #               Port:      Ixia接口卡的端口号  
    #               args:     
    #                         -default        1:产生报文发送自动产生错误类型(默认值1) 0:不产生
    #                         -crc            1:产生 0:不产生    报文包含CRC错误,默认不产生
    #                         -nocrc            1:产生 0:不产生    报文不包含CRC,默认不产生
    #                         -align            1:产生 0:不产生    报文包含字节排列错误（Bits数不是8的整倍数）,默认不产生
    #                         -dribble        1:产生 0:不产生    报文包含多余字节（CRC位后有多余的Bits）,默认不产生
    #                        -streamid        整数,流ID,默认为1   
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 9:49:54
    #修改纪录：     yuzhenpin 61733 2009-1-24 9:10:30
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
    #过 程 名：     SmbEthFrameSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     设置2层的流
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:         Ixia的hub号
    #               Card:         Ixia接口卡所在的槽号
    #               Port:         Ixia接口卡的端口号  
    #               strDstMac:       目的MAC
    #               strSrcMac:       源MAC
    #               args: 可选参数
    #                       -frametype  1: tag的802.1Q帧； 2: ETH II帧(默认值2)；3: 802.3帧类型。缺省为1    帧类型; (目前支持2,3两种)
    #                       -length     帧长，缺省为64
    #                       -tag        0 非VLAN帧 1 带VLAN TAG的帧 2 带双层VLAN TAG的帧 3 带三层VLAN TAG的帧   是否为VLAN TAG模式，缺省为0, 
    #                       -pri            0～7，缺省为0   Vlan的优先级， 
    #                       -cfi        0～1，缺省为0   Vlan的配置字段， 
    #                       -vlan       1～4095，缺省为1    帧的VLAN值， 
    #                       -pri2       0～7，缺省为0   双层Vlan的优先级，
    #                       -cfi2       0～1，缺省为0   双层Vlan的配置字段，
    #                       -vlan2          1～4095，缺省为1    帧的双层VLAN值， 
    #                       -pri3       0～7，缺省为0   三层Vlan的优先级，
    #                       -cfi3       0～1，缺省为0   三层Vlan的配置字段，
    #                       -vlan3      1～4095，缺省为1    帧的三层VLAN值， 
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 11:39:30
    #修改纪录：     
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

        #阳诺 edit 2006－07-21 mac地址转换 
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
    #过 程 名：     SmbLanCardTypeGet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     取得卡得类型(注明:因为IXIA表只有千兆卡，所以不需要处理，直接返回0)
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号  
    #返 回 值：     返回一个列表,第一元素是字符串表示的当前卡的类型,第二个元素是卡的类型编号,整数.
    #作    者：     杨卓
    #生成日期：     2006-7-18 11:8:30
    #修改纪录：     
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
    #过 程 名：     SmbGetCardType
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     取得卡得类型(注明:因为IXIA表只有千兆卡，所以不需要处理，直接返回0)
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号  
    #返 回 值：     返回一个列表,第一元素是字符串表示的当前卡的类型,第二个元素是卡的类型编号,整数.
    #作    者：     杨卓
    #生成日期：     2006-7-18 11:8:30
    #修改纪录：     
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
    #过 程 名：     SmbLink
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     连接IXIA仪表
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               chassisIp:  仪表IP地址  
    #               linkPara, 缺省值：0:  连接参数，取RESERVE_ALL或RESERVE_NONE，
    #                                缺省为RESERVE_NONE:  
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     杨卓
    #生成日期：     2006-7-13 13:40:5
    #修改纪录：     
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
            0 {IxPuts -blue "成功连接IXIA仪表\n"}
            1 {IxPuts -blue "没有找到IXIA仪表......";set retVal 1}
            2 {IxPuts -red "IXIA仪表API版本不匹配";set retVal 2}
            3 {IxPuts -red "连接IXIA仪表超时";set retVal 3}
            default {set retVal 1}
       }
       
       return $retVal
    }

    #!!================================================================
    #过 程 名：     SmbIcmpPacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     ICMP流设置
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号 
    #               DstMac:        目的Mac地址
    #               DstIP:         目的IP地址
    #               SrcMac:        源Mac地址
    #               SrcIP:         源IP地址
    #               args: (可选参数,请见下表)
    #                       -streamid       流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
    #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
    #                       -vlan           Vlan tag,整数,默认0,就是没有VLAN Tag,大于0的值才插入VLAN tag.
    #                       -pri            Vlan的优先级，范围0～7，缺省为0
    #                       -cfi            Vlan的配置字段，范围0～1，缺省为0
    #                       -type           报文ETH协议类型，缺省值 "08 00"
    #                       -ver            报文IP版本，缺省值4
    #                       -iphlen         IP报文头长度，缺省值5
    #                       -tos            IP报文服务类型，缺省值0
    #                       -dscp           DSCP 值,缺省值0
    #                       -tot            IP净荷长度，缺省值根据报文长度计算
    #                       -id             报文标识号，缺省值1
    #                       -mayfrag        是否可分片标志, 0:可分片, 1:不分片
    #                       -lastfrag       否分片包的最后一片, 0: 最后一片(缺省值), 1:不是最后一片
    #                       -fragoffset     分片包偏移量，缺省值0
    #                       -ttl            报文生存时间值，缺省值255
    #                       -pro            报文IP协议类型，缺省值4
    #                       -change         修改数据包中的指定字段，此参数标识修改字段的字节偏移量,默认值,最后一个字节(CRC前).
    #                       -value          修改数据的内容, 默认值 {{00 }}, 16进制的值.
    #                       -enable         是否使本条流有效 true / false
    #                       -sname          定义流的名称,任意合法的字符串.默认为""
    #                       -strtransmode   定义流发送的模式,可以0:连续发送 1:发送完指定包数目后停止 2:发送完本条流后继续发送下一条流.
    #                       -strframenum    定义本条流发送的包数目
    #                       -strrate        发包速率,线速的百分比. 100 代表线速的 100%, 1 代表线速的 1%
    #                       -strburstnum    定义本条流包含多少个burst,取值范围1~65535,默认为1
    #                       -icmptype       ICMP操作类型，缺省值0
    #                       -icmpcode       ICMP操作代码，缺省值0
    #                       -icmpid         ICMP报文ID，缺省值0
    #                       -icmpseq        ICMP序列号，缺省值0
    #
    #                       -udf1           是否使用UDF1,  0:不使用,默认值  1:使用
    #                       -udf1offset     UDF偏移量
    #                       -udf1len        UDF长度,单位字节,取值范围1~4
    #                       -udf1initval    UDF起始值,默认 {00}
    #                       -udf1step       UDF变化步长,默认1
    #                       -udf1changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf1repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf2           是否使用UDF2,  0:不使用,默认值  1:使用
    #                       -udf2offset     UDF偏移量
    #                       -udf2len        UDF长度,单位字节,取值范围1~4
    #                       -udf2initval    UDF起始值,默认 {00}
    #                       -udf2step       UDF变化步长,默认1
    #                       -udf2changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf2repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf3           是否使用UDF3,  0:不使用,默认值  1:使用
    #                       -udf3offset     UDF偏移量
    #                       -udf3len        UDF长度,单位字节,取值范围1~4
    #                       -udf3initval    UDF起始值,默认 {00}
    #                       -udf3step       UDF变化步长,默认1
    #                       -udf3changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf3repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf4           是否使用UDF4,  0:不使用,默认值  1:使用
    #                       -udf4offset     UDF偏移量
    #                       -udf4len        UDF长度,单位字节,取值范围1~4
    #                       -udf4initval    UDF起始值,默认 {00}
    #                       -udf4step       UDF变化步长,默认1
    #                       -udf4changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf4repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf5           是否使用UDF5,  0:不使用,默认值  1:使用
    #                       -udf5offset     UDF偏移量
    #                       -udf5len        UDF长度,单位字节,取值范围1~4
    #                       -udf5initval    UDF起始值,默认 {00}
    #                       -udf5step       UDF变化步长,默认1
    #                       -udf5changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf5repeat     UDF递增/递减的次数, 1~n 整数
    #    
    #返 回 值：     成功返回0,失败1
    #作    者：     杨卓
    #生成日期：     2006-7-14 8:55:6
    #修改纪录：     
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

        #阳诺 edit 2006－07-20 mac地址转换 
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
    #过 程 名：     SmbIgmpPacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     IGMP流设置
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号  
    #               DstMac:        目的Mac地址
    #               DstIP:         目的IP地址
    #               SrcMac:        源Mac地址
    #               SrcIP:         源IP地址
    #               args: (可选参数,请见下表)
    #                       -streamid       流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
    #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
    #                       -vlan           Vlan tag,整数,默认0,就是没有VLAN Tag,大于0的值才插入VLAN tag.
    #                       -pri            Vlan的优先级，范围0～7，缺省为0
    #                       -cfi            Vlan的配置字段，范围0～1，缺省为0
    #                       -type           报文ETH协议类型，缺省值 "08 00"
    #                       -ver            报文IP版本，缺省值4
    #                       -iphlen         IP报文头长度，缺省值5
    #                       -tos            IP报文服务类型，缺省值0
    #                       -dscp           DSCP 值,缺省值0
    #                       -tot            IP净荷长度，缺省值根据报文长度计算
    #                       -id             报文标识号，缺省值1
    #                       -mayfrag        是否可分片标志, 0:可分片, 1:不分片
    #                       -lastfrag       否分片包的最后一片, 0: 最后一片(缺省值), 1:不是最后一片
    #                       -fragoffset     分片包偏移量，缺省值0
    #                       -ttl            报文生存时间值，缺省值255
    #                       -pro            报文IP协议类型，缺省值4
    #                       -change         修改数据包中的指定字段，此参数标识修改字段的字节偏移量,默认值,最后一个字节(CRC前).
    #                       -value          修改数据的内容, 默认值 {{00 }}, 16进制的值.
    #                       -enable         是否使本条流有效 true / false
    #                       -sname          定义流的名称,任意合法的字符串.默认为""
    #                       -strtransmode   定义流发送的模式,可以0:连续发送 1:发送完指定包数目后停止 2:发送完本条流后继续发送下一条流.
    #                       -strframenum    定义本条流发送的包数目
    #                       -strrate        发包速率,线速的百分比. 100 代表线速的 100%, 1 代表线速的 1%
    #                       -strburstnum    定义本条流包含多少个burst,取值范围1~65535,默认为1
    #
    #                       -igmpver        igmp协议版本，缺省值1
    #                       -igmptype       igmp报文类型，缺省值17,各个值的定义如下
    #                                       membershipQuery 17
    #                                       membershipReport1 18
    #                                       dvmrpMessage 19
    #                                       membershipReport2 22
    #                                       leaveGroup 23
    #                                       membershipReport3 34
    #
    #                       -rsvd           igmp响应等待时长0~127，单位0.1秒, 缺省值0, 
    #                       -groupip        目的组播地址，缺省值为224.1.1.1，输入参数类型为 "xx.xx.xx.xx"
    #
    #
    #                       -udf1           是否使用UDF1,  0:不使用,默认值  1:使用
    #                       -udf1offset     UDF偏移量
    #                       -udf1len        UDF长度,单位字节,取值范围1~4
    #                       -udf1initval    UDF起始值,默认 {00}
    #                       -udf1step       UDF变化步长,默认1
    #                       -udf1changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf1repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf2           是否使用UDF2,  0:不使用,默认值  1:使用
    #                       -udf2offset     UDF偏移量
    #                       -udf2len        UDF长度,单位字节,取值范围1~4
    #                       -udf2initval    UDF起始值,默认 {00}
    #                       -udf2step       UDF变化步长,默认1
    #                       -udf2changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf2repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf3           是否使用UDF3,  0:不使用,默认值  1:使用
    #                       -udf3offset     UDF偏移量
    #                       -udf3len        UDF长度,单位字节,取值范围1~4
    #                       -udf3initval    UDF起始值,默认 {00}
    #                       -udf3step       UDF变化步长,默认1
    #                       -udf3changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf3repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf4           是否使用UDF4,  0:不使用,默认值  1:使用
    #                       -udf4offset     UDF偏移量
    #                       -udf4len        UDF长度,单位字节,取值范围1~4
    #                       -udf4initval    UDF起始值,默认 {00}
    #                       -udf4step       UDF变化步长,默认1
    #                       -udf4changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf4repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf5           是否使用UDF5,  0:不使用,默认值  1:使用
    #                       -udf5offset     UDF偏移量
    #                       -udf5len        UDF长度,单位字节,取值范围1~4
    #                       -udf5initval    UDF起始值,默认 {00}
    #                       -udf5step       UDF变化步长,默认1
    #                       -udf5changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf5repeat     UDF递增/递减的次数, 1~n 整数
    #返 回 值：     成功返回0,失败返1
    #作    者：     杨卓
    #生成日期：     2006-7-14 9:31:0
    #修改纪录：     
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

        #阳诺 edit 2006－07-20 mac地址转换 
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
    #过 程 名：     SmbInputToStopTx
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     程序始终监听键盘输入,一旦接收到了用户指定的字符串,就停止端口的发包
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:      Ixia的hub号
    #               Card:      Ixia接口卡所在的槽号
    #               Port:      Ixia接口卡的端口号       
    #               input:    用户指定的输入串,一旦在测试的过程中用户输入这个串并敲回车,端口就停止发包!
    #                         参数形式: "1"
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 11:8:39
    #修改纪录：     
    #!!================================================================
    proc SmbInputToStopTx {Chas Card Port input} {   
        set retVal 0
        set RunFlag 1
        while {$RunFlag} {
            IxPuts -blue "如果您要停止$Chas $Card $Port发包,请输入字符串$input 并敲回车"
            gets stdin k
            if {$k == $input} {
                IxPuts -blue "已经接收到停止发送命令,正在停止端口$Chas $Card $Port发包!"
                set RunFlag 0
                if [ixStopPortTransmit $Chas $Card $Port] {
                    IxPuts -red "Can't Stop $Chas $Card $Port port transmit."
                    set retVal 1
                }
            } else {
                IxPuts -red "您输入的字符不是停止字符串,请检查,注意大写小!"
            }
        }
        return $retVal
    }

    #!!================================================================
    #过 程 名：     SmbIpPacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     IP流设置
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号    
    #               DstMac:        目的Mac地址
    #               DstIP:         目的IP地址
    #               SrcMac:        源Mac地址
    #               SrcIP:         源IP地址
    #               args: (可选参数,请见下表)
    #                       -streamid       流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
    #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
    #                       -vlan           Vlan tag,整数,默认0,就是没有VLAN Tag,大于0的值才插入VLAN tag.
    #                       -pri            Vlan的优先级，范围0～7，缺省为0
    #                       -cfi            Vlan的配置字段，范围0～1，缺省为0
    #                       -type           报文ETH协议类型，缺省值 "08 00"
    #                       -ver            报文IP版本，缺省值4
    #                       -iphlen         IP报文头长度，缺省值5
    #                       -tos            IP报文服务类型，缺省值0
    #                       -dscp           DSCP 值,缺省值0
    #                       -tot            IP净荷长度，缺省值根据报文长度计算
    #                       -id             报文标识号，缺省值1
    #                       -mayfrag        是否可分片标志, 0:可分片, 1:不分片
    #                       -lastfrag       否分片包的最后一片, 0: 最后一片(缺省值), 1:不是最后一片
    #                       -fragoffset     分片包偏移量，缺省值0
    #                       -ttl            报文生存时间值，缺省值255
    #                       -pro            报文IP协议类型，缺省值4
    #                       -change         修改数据包中的指定字段，此参数标识修改字段的字节偏移量,默认值,最后一个字节(CRC前).
    #                       -value          修改数据的内容, 默认值 {{00 }}, 16进制的值.
    #                       -enable         是否使本条流有效 true / false
    #                       -sname          定义流的名称,任意合法的字符串.默认为""
    #                       -strtransmode   定义流发送的模式,可以0:连续发送 1:发送完指定包数目后停止 2:发送完本条流后继续发送下一条流.
    #                       -strframenum    定义本条流发送的包数目
    #                       -strrate        发包速率,线速的百分比. 100 代表线速的 100%, 1 代表线速的 1%
    #                       -strburstnum    定义本条流包含多少个burst,取值范围1~65535,默认为1
    #
    #
    #                       -udf1           是否使用UDF1,  0:不使用,默认值  1:使用
    #                       -udf1offset     UDF偏移量
    #                       -udf1len        UDF长度,单位字节,取值范围1~4
    #                       -udf1initval    UDF起始值,默认 {00}
    #                       -udf1step       UDF变化步长,默认1
    #                       -udf1changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf1repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf2           是否使用UDF2,  0:不使用,默认值  1:使用
    #                       -udf2offset     UDF偏移量
    #                       -udf2len        UDF长度,单位字节,取值范围1~4
    #                       -udf2initval    UDF起始值,默认 {00}
    #                       -udf2step       UDF变化步长,默认1
    #                       -udf2changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf2repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf3           是否使用UDF3,  0:不使用,默认值  1:使用
    #                       -udf3offset     UDF偏移量
    #                       -udf3len        UDF长度,单位字节,取值范围1~4
    #                       -udf3initval    UDF起始值,默认 {00}
    #                       -udf3step       UDF变化步长,默认1
    #                       -udf3changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf3repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf4           是否使用UDF4,  0:不使用,默认值  1:使用
    #                       -udf4offset     UDF偏移量
    #                       -udf4len        UDF长度,单位字节,取值范围1~4
    #                       -udf4initval    UDF起始值,默认 {00}
    #                       -udf4step       UDF变化步长,默认1
    #                       -udf4changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf4repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf5           是否使用UDF5,  0:不使用,默认值  1:使用
    #                       -udf5offset     UDF偏移量
    #                       -udf5len        UDF长度,单位字节,取值范围1~4
    #                       -udf5initval    UDF起始值,默认 {00}
    #                       -udf5step       UDF变化步长,默认1
    #                       -udf5changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf5repeat     UDF递增/递减的次数, 1~n 整数

    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 21:7:34
    #修改纪录：     
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

        #阳诺 edit 2006－07-21 mac地址转换 
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
    #过 程 名：     SmbListPktSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     用户输入列表{1 2 3 4 5 6 7 8 9 10 11 13....},
    #               程序根据这个列表来构造一个流.数据内容就完全根据这个列表来构建.列表的长度就是包的长度.
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:         Ixia的hub号
    #               Card:         Ixia接口卡所在的槽号
    #               Port:         Ixia接口卡的端口号    
    #               lcon:  包内容列表,输入10进制的值即可,参数形式如下:
    #                      {1 2 3 4 5 6 7 8 9 10 11 13}  
    #               args:  -streamid  流编号,默认为1 
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 11:35:48
    #修改纪录：     
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
    #过 程 名：     SmbLogPortCountsShow
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     打印出端口收包数和发包数这两个值
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:         Ixia的hub号
    #               Card:         Ixia接口卡所在的槽号
    #               Port:         Ixia接口卡的端口号    
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 19:13:29
    #修改纪录：     
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
    #过 程 名：     SmbMetricModeSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     流设置
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:      Ixia的hub号
    #               Card:      Ixia接口卡所在的槽号
    #               Port:      Ixia接口卡的端口号      
    #               args: (可选参数,请见下表)
    #                       -dstmac     目的MAC, 默认值为 "00 00 00 00 00 00"
    #                       -dstip      目的IP地址, 默认值为 "1.1.1.1"
    #                       -srcmac     源MAC, 默认值为 "00 00 00 00 00 01"
    #                       -srcip      源IP地址, 默认值为 "3.3.3.3"
    #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
    #                       -type           custom / IP / TCP / UDP / ipx / ipv6,默认为CUSTOM即自定义流 
    #                       -vlan           Vlan tag,整数,默认0,就是没有VLAN Tag,大于0的值才插入VLAN tag.
    #                       -data       在CUSTOM模式下有效. 指定报文内容, 不指定时使用随机内容,参数格式 "FF 01 11 ..."
    #                       -vfd1           VFD1域的变化状态, 默认为OffState; 可以支持以下几种值;:
    #                                       OffState 关闭状态
    #                                       StaticState 固定状态
    #                                       IncreState 递增状态
    #                                       DecreState 递减状态
    #                                       RandomState 随机状态
    #                       -vfd1cycle  VFD1循环变化次数，缺省情况下不循环，连续变化
    #                       -vfd1step   VFD1域变化步长
    #                       -vfd1offset     VFD1变化域偏移量
    #                       -vfd1start      VFD1变化域起始值，不带0x的十六进制数,,参数形式为 {01 0f 0d 13},最长4个字节,最短1个字节,注意只有1位的前面补0,如1要写成01.
    #                       -vfd1len        VFD1变化长度,最长4个字节,最短1个字节
    #                       -vfd2           VFD2域的变化状态, 默认为OffState; 可以支持以下几种值;:
    #                                       OffState 关闭状态
    #                                       StaticState 固定状态
    #                                       IncreState 递增状态
    #                                       DecreState 递减状态
    #                                       RandomState 随机状态
    #                       -vfd2cycle  VFD2循环变化次数，缺省情况下不循环，连续变化
    #                       -vfd2step   VFD2域变化步长
    #                       -vfd2offset     VFD2变化域偏移量
    #                       -vfd2start      VFD2变化域起始值，不带0x的十六进制数,参数形式为 {01 0f 0d 13},最长4个字节,最短1个字节.注意只有1位的前面补0,如1要写成01   
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 10:11:30
    #修改纪录：     modify by chenshibing 64165 2009-05-19 修改流的发送模式，使多条流可以间隔发送报文(把原来的每条流contPacket模式改为最后一条return to id模式，其余advance模式)
    #               modify by chenshibing 64165 2009-05-20 修改每条流的packet per burst个数1，否则在速度较慢的时候就不能模拟多条流间隔发报文的情形
    #               modify by chenshibing 64165 2009-05-27 处理custom模式下的data数据下发,使其能够正确的下发
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
        set metricflag    0 ; #是否为第一条流
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

        #对流No进行处理
        if { [array exists ::ArrMetricCount] != 1 } {
            #数组不存在
            set metricflag 1
        } else {
            ##数组存在, 但该端口没有创建流
            if { [array get ::ArrMetricCount $Chas,$Card,$Port] == ""} {
                set metricflag 1
            } else {
                #该端口已经创建了流
                set ::ArrMetricCount($Chas,$Card,$Port) [expr $::ArrMetricCount($Chas,$Card,$Port) + 1]
            }
        }

        if  { $metricflag == 1 } {
            #流数组计数
            array set ::ArrMetricCount {}
            set ::ArrMetricCount($Chas,$Card,$Port) 1
        } else {
        	#commented by Eric Yu to fix the bug for changing the mode of every stream
            # add by chenshibing 2009-05-19 把前面一条流的模式改为advance模式
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
        	
        	#用户没有输入就用满速率
			if {($Pps == 0) && ($Strrate == 0) && ($Bps == 0)} {
			    stream config -rateMode usePercentRate
			    stream config -percentPacketRate 100    
			}
						        
			if { $Strrate != 0 } {
				#用户选择以百分比输入的情况
			    stream config -rateMode usePercentRate
			    stream config -percentPacketRate $Strrate
			} elseif { ($Pps != 0) && ($Strrate == 0) } {
				#用户选择用pps为单位的情况
				stream config -rateMode streamRateModeFps
			    stream config -fpsRate $Pps
			} elseif { ($Bps != 0) && ($Strrate == 0) && ($Pps == 0) } {
				#用户选择用bps为单位的情况
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
    #过 程 名：     SmbMplsPacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     设置MPLS流
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:      Ixia的hub号
    #               Card:      Ixia接口卡所在的槽号
    #               Port:      Ixia接口卡的端口号      
    #               strMplsDstMac:   MPLS目的MAC
    #               strDstMac:       目的MAC
    #               strMplsSrcMac:   MPLS源MAC
    #               strSrcMac:   源MAC 
    #               args: (可选参数,请见下表)
    #                       -streamid       流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
    #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
    #                       -encap      封装类型 martinioe ppp null
    #                       -lable1     第一层标签的值,缺省值为"",不加本层标签
    #                       -cos1       第一层标签的Cos(Class of Service)
    #                       -s1     第一层标签的栈底标识
    #                       -ttl1       第一层标签TTL
    #                       -lable2     第二层标签的值缺省值为"",不加本层标签
    #                       -cos2       第二层标签的Cos
    #                       -s2     第二层标签的栈底标识
    #                       -ttl2       第二层标签TTL  
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 19:31:55
    #修改纪录：     
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

        #阳诺 edit 2006－07-21 mac地址转换 
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
    #过 程 名：     SmbPacketCapture
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     开始抓包,然后等待time之后, 停止, 然后返回第Index的包里的具体内容.
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:         Ixia的hub号
    #               Card:         Ixia接口卡所在的槽号
    #               Port:         Ixia接口卡的端口号
    #               args:   
    #                       -Time   抓取时间,缺省为3秒
    #                       -Index: 被抓取的包的索引 缺省为0
    #                       -Offset 字段的偏移量 缺省为0
    #                       -Len    返回字段的字节长度 缺省为1
    #返 回 值：     函数返回一个列表,列表中的第一个元素是函数执行结果:
    #               0 - 表示函数执行正常
    #               1 - 表示函数执行异常
    #               列表的第二个元素是用户指定的报文字段内容.
    #作    者：     杨卓
    #生成日期：     2006-7-14 11:30:52
    #修改纪录：     
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
    #过 程 名：     SmbPacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     等待接收停止,用接收速率来判断,如果判断接收速率为0则认为接收停止.
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号    
    #               DstMac:        目的Mac地址
    #               DstIP:         目的IP地址
    #               SrcMac:        源Mac地址
    #               SrcIP:         源IP地址
    #               enumProType:   包的协议类型
    #                     ARP ARP协议类型
    #                     IP IP协议类型
    #                     TCP TCP协议类型
    #                     UDP UDP协议类型
    #                     ICMP ICMP协议类型
    #                     IGMP IGMP协议类型
    #                     PAUSE PAUSE协议类型
    #               FrameLen:      包长
    #               FrameNum:      包数
    #               RatePct:       发包速率,线速的百分比. 100 代表线速的 100%, 1 代表线速的 1%
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 21:1:55
    #修改纪录：     
    #         时间:2006-07-19 11:36:35
    #         作者:阳诺
    #         内容:将固定参数(FrameLen FrameNum RatePct)改为args参数 
    #         2009-07-23 陈世兵 把写硬件的API由ixWritePortsToHardware改为ixWriteConfigToHardware,防止出现链路down的情况
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

        #阳诺 edit 2006－07-23 mac地址转换 
        set DstMac [StrMacConvertList $DstMac]
        set SrcMac [StrMacConvertList $SrcMac]

        #阳诺 edit 2006-07-23 
        set FrameLen "64"
        set FrameNum "11"
        set RatePct "33"

        set args [string tolower $args]
        
        # 从args中取得IXIA仪表端口发包的参数
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
    #过 程 名：     SmbPausePacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     PAUSE流设置
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号    
    #               DstMac:        目的Mac地址
    #               DstIP:         目的IP地址
    #               SrcMac:        源Mac地址
    #               SrcIP:         源IP地址
    #               args: (可选参数,请见下表)
    #                       -streamid       流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
    #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
    #                       -vlan           Vlan tag,整数,默认0,就是没有VLAN Tag,大于0的值才插入VLAN tag.
    #                       -pri            Vlan的优先级，范围0～7，缺省为0
    #                       -cfi            Vlan的配置字段，范围0～1，缺省为0
    #                       -type           报文ETH协议类型，缺省值 "08 00"
 
    #                       -change         修改数据包中的指定字段，此参数标识修改字段的字节偏移量,默认值,最后一个字节(CRC前).
    #                       -value          修改数据的内容, 默认值 {{00 }}, 16进制的值.
    #                       -enable         是否使本条流有效 true / false
    #                       -sname          定义流的名称,任意合法的字符串.默认为""
    #                       -strtransmode   定义流发送的模式,可以0:连续发送 1:发送完指定包数目后停止 2:发送完本条流后继续发送下一条流.
    #                       -strframenum    定义本条流发送的包数目
    #                       -strrate        发包速率,线速的百分比. 100 代表线速的 100%, 1 代表线速的 1%
    #                       -strburstnum    定义本条流包含多少个burst,取值范围1~65535,默认为1
    #
    #                       -pause          时间,以Pause Quanta为单位0~65536,(1 Pause Quanta = 512 位时) 默认值为255
    #
    #                       -udf1           是否使用UDF1,  0:不使用,默认值  1:使用
    #                       -udf1offset     UDF偏移量
    #                       -udf1len        UDF长度,单位字节,取值范围1~4
    #                       -udf1initval    UDF起始值,默认 {00}
    #                       -udf1step       UDF变化步长,默认1
    #                       -udf1changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf1repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf2           是否使用UDF2,  0:不使用,默认值  1:使用
    #                       -udf2offset     UDF偏移量
    #                       -udf2len        UDF长度,单位字节,取值范围1~4
    #                       -udf2initval    UDF起始值,默认 {00}
    #                       -udf2step       UDF变化步长,默认1
    #                       -udf2changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf2repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf3           是否使用UDF3,  0:不使用,默认值  1:使用
    #                       -udf3offset     UDF偏移量
    #                       -udf3len        UDF长度,单位字节,取值范围1~4
    #                       -udf3initval    UDF起始值,默认 {00}
    #                       -udf3step       UDF变化步长,默认1
    #                       -udf3changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf3repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf4           是否使用UDF4,  0:不使用,默认值  1:使用
    #                       -udf4offset     UDF偏移量
    #                       -udf4len        UDF长度,单位字节,取值范围1~4
    #                       -udf4initval    UDF起始值,默认 {00}
    #                       -udf4step       UDF变化步长,默认1
    #                       -udf4changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf4repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf5           是否使用UDF5,  0:不使用,默认值  1:使用
    #                       -udf5offset     UDF偏移量
    #                       -udf5len        UDF长度,单位字节,取值范围1~4
    #                       -udf5initval    UDF起始值,默认 {00}
    #                       -udf5step       UDF变化步长,默认1
    #                       -udf5changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf5repeat     UDF递增/递减的次数, 1~n 整数
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 9:42:43
    #修改纪录：     
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
    #过 程 名：     SmbPktSendAndCapture
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     函数启动发送端口开始发送,然后在等待一段时间之后在接收端口开始捕获.
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:         Ixia的hub号
    #               Card:         Ixia接口卡所在的槽号
    #               Port:         Ixia接口卡的端口号      
    #               intCptHub:    接收端Ixia的hub号
    #               intCptSlot:   接收端Ixia接口卡所在的槽号
    #               intCptPort:   接收端Ixia接口卡的端口号   
    #               intTime, 缺省值：3000:    开始发送之后等待多长时间再开始接收端口的捕获,单位:微秒
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 11:16:17
    #修改纪录：     
    #!!================================================================
    proc SmbPktSendAndCapture { Chas Card Port intCptHub intCptSlot intCptPort {intTime 3000}} {
        set retVal 0
        IxPuts -blue "启动端口$Chas $Card $Port 发送"
        if [ixStartPortTransmit $Chas $Card $Port] {
            IxPuts -red "启动端口$Chas $Card $Port 发送有误!"
            set retVal 1
        }
        IxPuts -blue "$intTime 微秒之后开始在$intCptHub $intCptSlot $intCptPort 上捕获"
        after $intTime
        IxPuts -blue "启动端口$intCptHub $intCptSlot $intCptPort 捕获"
        if [ixStartPortCapture $intCptHub $intCptSlot $intCptPort] {
            IxPuts -red "启动端口$intCptHub $intCptSlot $intCptPort 捕获失败!"
            set retVal 1
        }
        return $retVal           
    }
    
    #!!================================================================
    #过 程 名：     SmbPortClear
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     清除端口的所有统计
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:     Ixia的hub号
    #               Card:     Ixia接口卡所在的槽号
    #               Port:     Ixia接口卡的端口号
    #               args:     Ixia接口卡的端口号，可变数目部分
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:17:9
    #修改纪录：     
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
    #过 程 名：     SmbPortsCaptureClear
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     清除抓包缓冲区，实际上不需要清除缓冲区，因为每次开始抓包会自动清空缓冲区
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               PortList:   {{$Chas1 $Card1 $Port1} {$Chas2 $Card2 $Port2} ... {$ChasN $CardN $PortN}} 
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 18:34:55
    #修改纪录：     
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
    #过 程 名：     SmbPortClearEx
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     复位端口，根据端口的类型设置,如果为FE则设置为百兆全双工如果为GE设置为千兆全双工
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:     Ixia的hub号
    #               Card:     Ixia接口卡所在的槽号
    #               Port:     Ixia接口卡的端口号    
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:19:14
    #修改纪录：     
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
    #过 程 名：     SmbPortInfoGet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     返回端口数据包统计信息
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号    
    #               CounterName:    
    #                              -framesSent 发送报文
    #                              -framesReceived 接收报文
    #               CounterType:   Count/Rate Count说明是个数, Rate说明是速率.
    #返 回 值：     指定捕获类型的统计数据
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:22:52
    #修改纪录：     
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
    #过 程 名：     SmbPortLinkStatusGet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     获取端口的link状态
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号     
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:27:59
    #修改纪录：     
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
    #过 程 名：     SmbPortModeSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     IX物理端口设定,如果没有输入可变参数则默认将端口重置为自适应状态.
    #               本例中加入了发送模式:TrasmitMode - PacketStreams(default) / AdvancedScheduler 
    #               即顺序发送模式和并发模式.这是属于Port参数中必须定义的,所以必须在Port这个级别同时定义. 
    #               包的发送模式在流中设置,不在这里设置.
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号
    #               args:
    #               
    #                     -speed:        10 or 100，缺省为100
    #                     -duplex:       FULLMODE or HALFMODE，缺省为FULLMODE
    #                     -nego:         AUTO or NOAUTO，缺省为AUTO
    #                     -transmitmode:  PacketStreams(default) / AdvancedScheduler 
    #                     -activemode:    copper_mode /  fiber_mode (Default)
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:34:1
    #修改纪录：     
    #         时间:2006-07-19 11:36:35
    #         作者:阳诺
    #         内容:将固定参数(duplexMode speed autoneg TransmitMode PhyMode)改为args参数 
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

        #阳诺 edit 2006-07-19 
        set duplexMode "FULL"
        set speed "ALL"
        set autoneg "TRUE"
        set TransmitMode "PacketStreams" 
        set PhyMode "portPhyModeFiber"

        set args [string tolower $args]
        
        # 从args中取得IXIA仪表端口参数
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
                        error "错误的Transmit Mode:$temp"
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
        # GE卡不需要设置速率、双工、协商等参数
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
	        #南京高娟反馈光口模式下会将协商模式改成非自协商导致端口状态为down
	        #from
	        #port config -speed $speed     
	        #to
	        if { $autoneg == "TRUE" } {
	        
	            #added by yuzhenpin 61733 2009-8-4 10:54:29
	            #在光口模式下，需要先切换到1000M全双工
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
    #过 程 名：     SmbPortsReserve
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     占用端口
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号    
    #               UserName:      登陆占用端口号的用户名
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:43:6
    #修改纪录：     
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
    #过 程 名：     SmbPortsReserve
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     占用端口
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号    
    #               UserName:      登陆占用端口号的用户名
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:43:6
    #修改纪录：     
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
    #过 程 名：     SmbPortRelease
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     释放端口
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号   
    #               Mode:          force (not friendly!)/ noForce(good way!)
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:39:2
    #修改纪录：     
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
    #过 程 名：     IxPortReset
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     复位Ixia卡端口
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号
    #               args:          Ixia接口卡的端口号，可变数目部分
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:29:45
    #修改纪录：     
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
    #过 程 名：     SmbPortRun
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     启动Ixia端口发送
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号
    #               runPara:       端口运行模式
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:30:44
    #修改纪录：     
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
    #过 程 名：     SmbPortStop
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     停止Ixia端口发送
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:31:42
    #修改纪录：     
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
    #过 程 名：     SmbPortTxStatusGet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     判断Ixia端口的状态，是否处于发送状态
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号   
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:32:34
    #修改纪录：     
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
    #过 程 名：     SmbRcvTrafficGet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     统计接收端口计数器数据
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:         Ixia的hub号
    #               Card:         Ixia接口卡所在的槽号
    #               Port:         Ixia接口卡的端口号  
    #               args: (可选参数,请见下表)
    #                       -frame      收到的总帧数
    #                       -packet
    #                       -framerate  收到的帧速率（个/S）
    #                       -byte       收到的总字节数
    #                       -byterate   收到的字节速率（bytes/S）
    #                       -trigger    收到的Trigger报文
    #                       -triggerrate    收到的Trigger报文速率（个/S）
    #                       -crc        收到的CRC错误报文数
    #                       -crcrate    收到的CRC错误报文速率（个/S）
    #                       -over       收到的过大报文计数
    #                       -overrate   收到的过大报文的速率（个/S）
    #                       -frag       收到的分片报文计数
    #                       -fragrate   收到的分片报文速率（个/S）  
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
    #返 回 值：     函数返回一个列表,列表中的第一个元素是函数执行结果:
    #                 0 - 表示函数执行正常
    #                 1 - 表示函数执行异常
    #                 从列表的第二个元素开始是用户定义的计数器类型.
    #作    者：     杨卓
    #生成日期：     2006-7-14 11:19:55
    #修改纪录：     
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
    #过 程 名：     SmbSendModeSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     设置Ixia流发送模式/参数
    #               注意:本函数必须在创建流之后才能使用,否则无效,因为这个函数是对特定端口上的特定
    #               的流进行修改, 所以,必须使用类似IxMetricModeSet这样的函数创建流之后才能使用这个函数.
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:      Ixia的hub号
    #               Card:      Ixia接口卡所在的槽号
    #               Port:      Ixia接口卡的端口号    
    #               enumSendMode:
    #                               CONT 连续发送模式
    #                               SINGLEBURST 一次突发模式
    #                               MULTIBURST 多次突发模式
    #                               CONTBURST 连续突发模式
    #                               ECHO Echo发送模式
    #               args: (可选参数,请见下表)
    #                       -pps    每秒钟发送的包数，缺省情况下为满速率
    #                       -rate   发送速率百分比，缺省情况下100％速率发送,默认100
    #                       -bps    每秒发送字节数，缺省情况下为满速率
    #                       -singleburst    SingleBurst的报文个数，缺省为100
    #                       -multiburst     Multi Burst的突发总次数，缺省为1
    #                       -perburst       每次Burst的报文数（仅对MultiBurst、ContBurst有效），缺省为100
    #                       -burstgap       每次突发之间的间隔，时间值的单位统一为us（仅对MultiBurst、ContBurst有效）
    #                       -gelen          报文长度(对GE/FE卡都有效),默认64
    #                       -felen          报文长度(对GE/FE卡都有效),默认64
    #                       -index          指定流的编号(对所有卡有效),默认为1  
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 10:59:17
    #修改纪录：     
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
			        #用户没有输入就用满速率
			        if {($Pps == 0) && ($Rate == 0) && ($Bps == 0)} {
			            stream config -rateMode usePercentRate
			            stream config -percentPacketRate $Rate    
			        }
			        			        
			        if { $Rate != 0 } {
			        	#用户选择以百分比输入的情况
			            stream config -rateMode usePercentRate
			            stream config -percentPacketRate $Rate
			        } elseif { ($Pps != 0) && ($Rate == 0) } {
			        	#用户选择用pps为单位的情况
			        	stream config -rateMode streamRateModeFps
			            stream config -fpsRate $Pps
			        } elseif { ($Bps != 0) && ($Rate == 0) && ($Pps == 0) } {
			        	#用户选择用bps为单位的情况
			        	stream config -rateMode streamRateModeBps
			            stream config -bpsRate $Bps
			        }
			       		        
			        
			                
			        #用户没有输入就用64
			        if {($Gelen == 64) && ($Felen == 64)} {
			            stream config -framesize 64    
			        }
			        
			        #用户选择Gelen为输入
			        if {($Gelen == 64) && ($Felen != 64)} {
			            #stream config -framesize $Felen
			            stream config -framesize [expr $Felen + 4]
			        }
			        #用户选择用Felen为输入
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
    #过 程 名：     SmbSendTrafficGet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     统计端口发送的数目和速率
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:         Ixia的hub号
    #               Card:         Ixia接口卡所在的槽号
    #               Port:         Ixia接口卡的端口号   
    #               args:    
    #                       -frame      收到的总帧数
    #                       -packet
    #                       -framerate  收到的帧速率（个/S）
    #                       -arprequest
    #                       -arpreply
    #			    -igmpframe
    #			    -byte
    #			    -pingrequest
    #			    -pingreply
    #返 回 值：     函数返回一个列表,列表中的第一个元素是函数执行结果:
    #               0 - 表示函数执行正常
    #               1 - 表示函数执行异常
    #               从列表的第二个元素开始是用户定义的计数器类型.
    #作    者：     杨卓
    #生成日期：     2006-7-14 11:26:42
    #修改纪录：     
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
    #过 程 名：     SmbSlotRelease
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     释放Ixia端口,注意,因为Ixia本身的特性,保留和释放端口都是以端口为单位的,
    #               所以这个函数虽然保留了原来的名字,但是意义有所不同,必须要有3个参数参能
    #               完成释放的功能,即 Chas Card Port
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号 
    #               Mode, 缺省值：noForce:    
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:41:4
    #修改纪录：     
    #!!================================================================
    proc SmbSlotRelease {Chas Card {Mode noForce}} {
        #added by yuzhenpin 61733 2009-4-7 19:05:51
        variable m_portList
        set m_portList [list]
        #end of added
        
        set retVal 0
        lappend portList [list $Chas $Card * ]
        
        #一张卡上的接口是可以被多个人占用
        #因此释放可能会“失败”
        #为了跟smartbits兼容
        #这里不返回错误
        if [ixClearOwnership $portList $Mode] {
            IxPuts -red "unable to release $Chas $Card *!"
            #set retVal 1
        }
        return $retVal         
    }

    #!!================================================================
    #过 程 名：     SmbSlotReserve
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     占用ixia仪表端口
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:    Ixia的hub号
    #               Card:    Ixia接口卡所在的槽号  
    #               args:    
    #                      -list:Ixia接口卡的端口号列表，如{1 2 3} 
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 14:5:22
    #修改纪录：     
    #!!================================================================
    proc SmbSlotReserve {Chas Card args} {
    
        #added by yuzhenpin 61733 2009-4-7 18:54:27
        #以 $Chas $Card * 的方式占用端口
        #会将这个卡上的所有端口都占用
        #改成精确的获取某个端口
        #这里直接返回
        #这样所有的端口都不以占用的方式使用
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
    #过 程 名：     SmbTcpPacketSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     TCP流设置
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号    
    #               DstMac:        目的Mac地址
    #               DstIP:         目的IP地址
    #               SrcMac:        源Mac地址
    #               SrcIP:         源IP地址
    #               args: (可选参数,请见下表)
    #                       -streamid       流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
    #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
    #                       -vlan           Vlan tag,整数,默认0,就是没有VLAN Tag,大于0的值才插入VLAN tag.
    #                       -pri            Vlan的优先级，范围0～7，缺省为0
    #                       -cfi            Vlan的配置字段，范围0～1，缺省为0
    #                       -type           报文ETH协议类型，缺省值 "08 00"
    #                       -ver            报文IP版本，缺省值4
    #                       -iphlen         IP报文头长度，缺省值5
    #                       -tos            IP报文服务类型，缺省值0
    #                       -dscp           DSCP 值,缺省值0
    #                       -tot            IP净荷长度，缺省值根据报文长度计算
    #                       -id             报文标识号，缺省值1
    #                       -mayfrag        是否可分片标志, 0:可分片, 1:不分片
    #                       -lastfrag       否分片包的最后一片, 0: 最后一片(缺省值), 1:不是最后一片
    #                       -fragoffset     分片包偏移量，缺省值0
    #                       -ttl            报文生存时间值，缺省值255
    #                       -pro            报文IP协议类型，缺省值4
    #                       -change         修改数据包中的指定字段，此参数标识修改字段的字节偏移量,默认值,最后一个字节(CRC前).
    #                       -value          修改数据的内容, 默认值 {{00 }}, 16进制的值.
    #                       -enable         是否使本条流有效 true / false
    #                       -sname          定义流的名称,任意合法的字符串.默认为""
    #                       -strtransmode   定义流发送的模式,可以0:连续发送 1:发送完指定包数目后停止 2:发送完本条流后继续发送下一条流.
    #                       -strframenum    定义本条流发送的包数目
    #                       -strrate        发包速率,线速的百分比. 100 代表线速的 100%, 1 代表线速的 1%
    #                       -strburstnum    定义本条流包含多少个burst,取值范围1~65535,默认为1
    #
    #                       -srcport        TCP源端口，缺省值0, 十进制数值
    #                       -dstport        TCP目的端口，缺省值0, 十进制数值
    #                       -seq         TCP序列号，缺省值0, 十进制数值
    #                       -ack         TCP确认号，缺省值0, 十进制数值
    #                       -tcpopt         TCP操作类型值，缺省值 ""
    #                       -window         窗口大小，缺省值0, 十进制数值
    #                       -urgent         紧急指针，缺省值0, 十进制数值
    #
    #                       -udf1           是否使用UDF1,  0:不使用,默认值  1:使用
    #                       -udf1offset     UDF偏移量
    #                       -udf1len        UDF长度,单位字节,取值范围1~4
    #                       -udf1initval    UDF起始值,默认 {00}
    #                       -udf1step       UDF变化步长,默认1
    #                       -udf1changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf1repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf2           是否使用UDF2,  0:不使用,默认值  1:使用
    #                       -udf2offset     UDF偏移量
    #                       -udf2len        UDF长度,单位字节,取值范围1~4
    #                       -udf2initval    UDF起始值,默认 {00}
    #                       -udf2step       UDF变化步长,默认1
    #                       -udf2changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf2repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf3           是否使用UDF3,  0:不使用,默认值  1:使用
    #                       -udf3offset     UDF偏移量
    #                       -udf3len        UDF长度,单位字节,取值范围1~4
    #                       -udf3initval    UDF起始值,默认 {00}
    #                       -udf3step       UDF变化步长,默认1
    #                       -udf3changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf3repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf4           是否使用UDF4,  0:不使用,默认值  1:使用
    #                       -udf4offset     UDF偏移量
    #                       -udf4len        UDF长度,单位字节,取值范围1~4
    #                       -udf4initval    UDF起始值,默认 {00}
    #                       -udf4step       UDF变化步长,默认1
    #                       -udf4changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf4repeat     UDF递增/递减的次数, 1~n 整数
    #
    #                       -udf5           是否使用UDF5,  0:不使用,默认值  1:使用
    #                       -udf5offset     UDF偏移量
    #                       -udf5len        UDF长度,单位字节,取值范围1~4
    #                       -udf5initval    UDF起始值,默认 {00}
    #                       -udf5step       UDF变化步长,默认1
    #                       -udf5changemode UDF变化规律, 0:递增, 1:递减
    #                       -udf5repeat     UDF递增/递减的次数, 1~n 整数    
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-14 9:12:5
    #修改纪录：     
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

        #阳诺 edit 2006－07-21 mac地址转换 
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
    #过 程 名：     SmbTriggerSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     Ixia端口接收报文Trigger(模式和内容)设置
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号   
    #               enumParttern:  trigger的模式
    #                                     ONLYTRI1 只匹配Trigger1，缺省值
    #                                     ONLYTRI2 只匹配Trigger2
    #                                     TRI1ANDTRI2 同时匹配Trigger1和Trigger2
    #               args:           -offset1 intOffset1 -   Trigger1的偏移量
    #                               -length1 intLength1 -   Trigger1的匹配字节长度
    #                               -value1 strValue1   -   Trigger1的匹配值
    #                               -offset2 intOffset2 -   Trigger2的偏移量
    #                               -length2 intLength2 -   Trigger2的匹配字节长度
    #                               -value2 strValue2   -   Trigger2的匹配值
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:46:32
    #修改纪录：     2009-05-17 陈世兵 对-value1/-value2参数值进行转换,使其输入格式与SMB一致(10进制空格分隔字符串)且能够生效
    #               2009-07-23 陈世兵 把写硬件的API由ixWritePortsToHardware改为ixWriteConfigToHardware,防止出现链路down的情况
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
   #过 程 名：     IxUdpPacketSet
   #程 序 包：     IXIA
   #功能类别：     
   #过程描述：     UDP流设置
   #用法：         
   #示例：         
   #               
   #参数说明：     
   #               Chas:          Ixia的hub号
   #               Card:          Ixia接口卡所在的槽号
   #               Port:          Ixia接口卡的端口号     
   #               DstMac:        目的Mac地址
   #               DstIP:         目的IP地址
   #               SrcMac:        源Mac地址
   #               SrcIP:         源IP地址
   #               args: (可选参数,请见下表)
   #                       -streamid       流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
   #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
   #                       -vlan           Vlan tag,整数,默认0,就是没有VLAN Tag,大于0的值才插入VLAN tag.
   #                       -pri            Vlan的优先级，范围0～7，缺省为0
   #                       -cfi            Vlan的配置字段，范围0～1，缺省为0
   #                       -type           报文ETH协议类型，缺省值 "08 00"
   #                       -ver            报文IP版本，缺省值4
   #                       -iphlen         IP报文头长度，缺省值5
   #                       -tos            IP报文服务类型，缺省值0
   #                       -dscp           DSCP 值,缺省值0
   #                       -tot            IP净荷长度，缺省值根据报文长度计算
   #                       -id             报文标识号，缺省值1
   #                       -mayfrag        是否可分片标志, 0:可分片, 1:不分片
   #                       -lastfrag       否分片包的最后一片, 0: 最后一片(缺省值), 1:不是最后一片
   #                       -fragoffset     分片包偏移量，缺省值0
   #                       -ttl            报文生存时间值，缺省值255
   #                       -pro            报文IP协议类型，缺省值4
   #                       -change         修改数据包中的指定字段，此参数标识修改字段的字节偏移量,默认值,最后一个字节(CRC前).
   #                       -5          修改数据的内容, 默认值 {{00 }}, 16进制的值.
   #                       -enable         是否使本条流有效 true / false
   #                       -sname          定义流的名称,任意合法的字符串.默认为""
   #                       -strtransmode   定义流发送的模式,可以0:连续发送 1:发送完指定包数目后停止 2:发送完本条流后继续发送下一条流.
   #                       -strframenum    定义本条流发送的包数目
   #                       -strrate        发包速率,线速的百分比. 100 代表线速的 100%, 1 代表线速的 1%
   #                       -strburstnum    定义本条流包含多少个burst,取值范围1~65535,默认为1
   #
   #                       -srcport        UDP源端口，缺省值0, 十进制数值
   #                       -dstport        UDP目的端口，缺省值0, 十进制数值
   #
   #                       -udf1           是否使用UDF1,  0:不使用,默认值  1:使用
   #                       -udf1offset     UDF偏移量
   #                       -udf1len        UDF长度,单位字节,取值范围1~4
   #                       -udf1initval    UDF起始值,默认 {00}
   #                       -udf1step       UDF变化步长,默认1
   #                       -udf1changemode UDF变化规律, 0:递增, 1:递减
   #                       -udf1repeat     UDF递增/递减的次数, 1~n 整数
   #
   #                       -udf2           是否使用UDF2,  0:不使用,默认值  1:使用
   #                       -udf2offset     UDF偏移量
   #                       -udf2len        UDF长度,单位字节,取值范围1~4
   #                       -udf2initval    UDF起始值,默认 {00}
   #                       -udf2step       UDF变化步长,默认1
   #                       -udf2changemode UDF变化规律, 0:递增, 1:递减
   #                       -udf2repeat     UDF递增/递减的次数, 1~n 整数
   #
   #                       -udf3           是否使用UDF3,  0:不使用,默认值  1:使用
   #                       -udf3offset     UDF偏移量
   #                       -udf3len        UDF长度,单位字节,取值范围1~4
   #                       -udf3initval    UDF起始值,默认 {00}
   #                       -udf3step       UDF变化步长,默认1
   #                       -udf3changemode UDF变化规律, 0:递增, 1:递减
   #                       -udf3repeat     UDF递增/递减的次数, 1~n 整数
   #
   #                       -udf4           是否使用UDF4,  0:不使用,默认值  1:使用
   #                       -udf4offset     UDF偏移量
   #                       -udf4len        UDF长度,单位字节,取值范围1~4
   #                       -udf4initval    UDF起始值,默认 {00}
   #                       -udf4step       UDF变化步长,默认1
   #                       -udf4changemode UDF变化规律, 0:递增, 1:递减
   #                       -udf4repeat     UDF递增/递减的次数, 1~n 整数
   #
   #                       -udf5           是否使用UDF5,  0:不使用,默认值  1:使用
   #                       -udf5offset     UDF偏移量
   #                       -udf5len        UDF长度,单位字节,取值范围1~4
   #                       -udf5initval    UDF起始值,默认 {00}
   #                       -udf5step       UDF变化步长,默认1
   #                       -udf5changemode UDF变化规律, 0:递增, 1:递减
   #                       -udf5repeat     UDF递增/递减的次数, 1~n 整数  
   #返 回 值：     成功返回0,失败返回错误码
   #作    者：     杨卓
   #生成日期：     2006-7-14 9:21:9
   #修改纪录：     
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

        #阳诺 edit 2006－07-21 mac地址转换 
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
    #过 程 名：     SmbUnLink
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     断开与仪表的连接
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 13:43:32
    #修改纪录：     
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
    #过 程 名：     SmbVfdSet
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     ###
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号     
    #               args:    
    #                       -dstmac        目的MAC, 默认值为 "00 00 00 00 00 00"
    #                       -dstip         目的IP地址, 默认值为 "1.1.1.1"
    #                       -srcmac         源MAC, 默认值为 "00 00 00 00 00 01"
    #                       -srcip         源IP地址, 默认值为 "3.3.3.3"
    #                       -clear         1:清除所有流 0:不清除任何流
    #                       -length         报文长度,默认为随机包长,如果这里填入0,意思是使用随机包长.
    #                       -streamid       流的编号,从1开始,如果端口上有相同ID的流将被覆盖.默认值1
    #                       -type            custom / IP / TCP / UDP / ipx / ipv6,默认为CUSTOM即自定义流 
    #                       -vlan           Vlan tag,整数,默认0,就是没有VLAN Tag,大于0的值才插入VLAN tag.
    #                       -data        在CUSTOM模式下有效. 指定报文内容, 不指定时使用随机内容,参数格式 "FF 01 11 ..."
    #                       -vfd1           VFD1域的变化状态, 默认为OffState; 可以支持以下几种值;:
    #                                       OffState 关闭状态
    #                                       StaticState 固定状态
    #                                       IncreState 递增状态
    #                                       DecreState 递减状态
    #                                       RandomState 随机状态
    #                       -vfd1cycle     VFD1循环变化次数，缺省情况下不循环，连续变化
    #                       -vfd1step    VFD1域变化步长
    #                       -vfd1offset     VFD1变化域偏移量
    #                       -vfd1start      VFD1变化域起始值，不带0x的十六进制数,,参数形式为 {01.0f.0d.13},最长4个字节,最短1个字节,注意只有1位的前面补0,如1要写成01.
    #                       -vfd1length     VFD1变化长度,最长4个字节,最短1个字节
    #                       -vfd2           VFD2域的变化状态, 默认为OffState; 可以支持以下几种值;:
    #                                       OffState 关闭状态
    #                                       StaticState 固定状态
    #                                       IncreState 递增状态
    #                                       DecreState 递减状态
    #                                       RandomState 随机状态
    #                       -vfd2cycle     VFD2循环变化次数，缺省情况下不循环，连续变化
    #                       -vfd2step    VFD2域变化步长
    #                       -vfd2offset     VFD2变化域偏移量
    #                       -vfd2start      VFD2变化域起始值，不带0x的十六进制数,参数形式为 {01.0f.0d.13},最长4个字节,最短1个字节.注意只有1位的前面补0,如1要写成01
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     杨卓
    #生成日期：     2006-8-14 11:54:54
    #修改纪录：     modify by chenshibing 2009-05-18 更改vfd1start/vfd2start的处理，使其输入格式与smb一致
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
    #过 程 名：     SmbWaitForRxStart
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     等待端口开始收包,一旦检测到接收端口速率>0,则马上停止检测
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号     
    #               maxCount:      表示最大等待的时间(单位:秒),超过这个时间还没有检测到有接收包就退出.
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:54:12
    #修改纪录：     
    #!!================================================================
    proc SmbWaitForRxStart {Chas Card Port maxCount} {
        set retVal 0
        set startTime [clock seconds]
        set i 1
        while {1} { 
            set nowTime [clock seconds]
            if {[expr $nowTime - $startTime] > $maxCount} {
                IxPuts -red "在指定时间内没有检测到端口开始接收包,停止检测!"
                set retVal 1
                break
            }
            IxPuts -blue "第$i\次检测..."
            stat getRate allStats $Chas $Card $Port
            set RxRate [stat cget -framesReceived]
            if {$RxRate >0} {
                IxPuts -blue "已经检测到端口开始接收包!"
                break
            }        
            after 1000
            incr i
        }
        return $retVal
    } 

    #!!================================================================
    #过 程 名：     SmbWaitForRxStop
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     等待接收停止,用接收速率来判断,如果判断接收速率为0则认为接收停止
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号     
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:57:15
    #修改纪录：     
    #!!================================================================
    proc SmbWaitForRxStop {Chas Card Port} {
        set retVal 0
        set i 1
        while {1} { 
            IxPuts -blue "第$i\次检测..."
            stat getRate allStats $Chas $Card $Port
            set RxRate [stat cget -framesReceived]
            if {$RxRate == 0} {
                IxPuts -blue "端口接收完毕!"
                break
            }        
            after 1000
            incr i
        }
        return $retVal
    }

    #!!================================================================
    #过 程 名：     SmbWaitForTxStop
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     等待发送停止,用发送速率来判断,如果判断发送速率为0则认为发送停止
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号    
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-13 20:58:51
    #修改纪录：     
    #!!================================================================
    proc SmbWaitForTxStop {Chas Card Port} {
        set retVal 0
        set i 1
        while {1} { 
            IxPuts -blue "第$i\次检测..."
            stat getRate allStats $Chas $Card $Port
            set TxRate [stat cget -framesSent]
            if {$TxRate == 0} {
                IxPuts -blue "端口发送停止!"
                break
            }        
            after 1000
            incr i
        }
        return $retVal
    }

    #!!================================================================
    #过 程 名：     IxPuts
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     输出过程
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               args:  
    #                    -red:出错信息为红色
    #                    -blue:调试信息为蓝色
    #                    -link:连接信息为黑色
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     阳诺
    #生成日期：     2006-7-13 12:42:45
    #修改纪录：     
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
    #过 程 名：     StrIpV6AddressCheck
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     IPV6地址合法性验证
    #用法：         
    #示例：         IxStrIpAddressCheck 1111.2222.3333.4444.5555.6666.7777.8888 
    #               
    #参数说明：     
    #               sIpAddress:    
    #返 回 值：     参数合法返回0,非法返回1
    #作    者：     阳诺
    #生成日期：     2006-7-31 9:51:7
    #修改纪录：     
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
    #过 程 名：     IxStrIpV6AddressConvers
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     IP地址转换，将以点号分割IP的转化为以分号分割IP
    #用法：         
    #示例：         IxStrIpV6AddressConvers 1111.2222.3333.4444.5555.6666.7777.8888
    #               
    #参数说明：     
    #               sIpAddress:  以点号分割的IP地址  
    #返 回 值：     以分号分割的IP地址，如:1111:2222:3333:4444:5555:6666:7777:8888
    #作    者：     阳诺
    #生成日期：     2006-7-31 16:53:0
    #修改纪录：     
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
    #过 程 名：     IxParaCheck
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     输入参数合法性验证
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               args: 输入参数
    #返 回 值：     成功返回0,失败返回1
    #作    者：     阳诺
    #生成日期：     2006-7-27 18:35:29
    #修改纪录：     
    #!!================================================================
    proc IxParaCheck {args} {
        set retVal 0
        set args [string tolower $args]

        #去掉传进来的最外面一层大括号
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
    #过 程 名：     SmbAppThroughputTest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     测试L2/L3的吞吐量(现在只测试L2层)
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               PortList:  测试使用的端口列表，如:{{1.1.1 1.1.2} {1.2.1 1.2.2}}
    #               args:  
    #                    -autonegotiate: 是否自适应 3: 是， 0: 不自适应(3为默认值)
    #                    -duplex:        双工模式 0:半双工 1:全双工(默认为全双工)
    #                    -singlerate:    速率(默认值100M), 取值: 10M, 100M, 1000M
    #                    -media          端口媒介, 默认为 fiber 即光口;  取值: copper, fiber
    #                    -traffictype    发送业务类型, 默认为 IP, 取值: IP, UDP, IPX
    #                    -duration:      每次发送的时长(持续时间):1~N integer(默认为10)
    #                    -trialnum:      测试套个数(默认为1)
    #                    -customflag:    包是否按着递增的数需增加(1:是，0:手工指定包的长度.默认为0)
    #                    -packetlength:  手工指定的数据包长度, 该参数需要指定一串数据包得长度以列表的形式提供 
    #                                    例如: -packetlength {64 128 256 512 1024 1518}
    #                    -learn:         是否发送学习包 1: 发送， 0: 不发送(默认值为1)
    #                    -learningretries:重发的次数 (默认值为3)
    #                    -stoperror:     遇到错误的时候停止 1: 是， 0: 否(1为默认值)
    #                    -bidirection:   是否支持流量的单/双向定义 1: 支持。 0: 不支持
    #                    -inilength:     初始化长度 只是在customflag为1的时候适用 (默认值64)
    #                    -stoplength:    最大长度 只是在customflag为1的时候适用 (默认值1518)
    #                    -stepsize:      数据包步增大小 只是在customflag为1的时候适用 (默认值64)
    #                    -inirate:       初始速度 (默认值100)
    #                    -maxrate:       最大速度 (默认值100) 
    #                    -minrate:       最小速度 (默认值0.1)
    #                    -tolrate:       速度增量 (默认值0.5)
    #                    -router:        是否使用router test 1为使用 0为不使用(默认为0)
    #                    -srcip:         源ip
    #                    -dstip:         目的ip
    #                    -srcMAC:        源MAC地址(默认的为hub.slot.port)
    #                    -dstMAC:        目的MAC地址(默认的为hub.slot.port)
    #                    -lossrate:      标识允许的包最大丢失率
    #                    -delay:         发送完一帧后的延时参数(默认为4),直通或者存储转发("cutThrough"/"storeAndForward")
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-28 15:43:15
    #修改纪录：     
    #!!================================================================
    proc SmbAppThroughputTest {PortList args} {
        set retVal 0
        variable m_ChassisIP
        set ChassisIP  $m_ChassisIP

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        #格式转换
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
        set SrcFile "temp/RFC 2544.resDir/Throughput.resDir/IXIA仪表测试用例_测试吞吐量性能.res/Run0001.res/results.csv"
        file copy -force $SrcFile  $ResultsPath
        IxPuts -blue  "Test over!"
        return 0 
    }

    #!!================================================================
    #过 程 名：     SmbAppLatencyTest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     测试L2/L3的延时性能(现在只测试L2层)
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               PortList:  测试使用的端口列表，如:{{1.1.1 1.1.2} {1.2.1 1.2.2}}
    #               args:  
    #                    -duration:      每次发送的时长(持续时间):1~N integer(默认为10)
    #                    -trialnum:      测试套个数(默认为1)
    #                    -customflag:    包是否按着递增的数需增加(1:是，0:手工指定包的长度.默认为0)
    #                    -packetlength:  手工指定的数据包长度, 该参数需要指定一串数据包得长度以列表的形式提供 
    #                                    例如: -packetlength {64 128 256 512 1024 1518}
    #                    -learn:         是否发送学习包 1: 发送， 0: 不发送(默认值为1)
    #                    -packetRetry:   重发的次数 (默认值为3)
    #                    -autonegotiate: 是否自适应 3: 是， 0: 不自适应(3为默认值)
    #                    -stoperror:     遇到错误的时候停止 1: 是， 0: 否(1为默认值)
    #                    -bidirection:   是否支持流量的单/双向定义 1: 支持。 0: 不支持
    #                    -inilength:     初始化长度 只是在customflag为1的时候适用 (默认值64)
    #                    -stoplength:    最大长度 只是在customflag为1的时候适用 (默认值1518)
    #                    -stepsize:      数据包步增大小 只是在customflag为1的时候适用 (默认值64)
    #                    -inirate:       初始速度 (默认值100)
    #                    -maxrate:       最大速度 (默认值100) 
    #                    -minrate:       最小速度 (默认值0.1)
    #                    -tolrate:       速度增量 (默认值0.5)
    #                    -router:        是否使用router test 1为使用 0为不使用(默认为0)
    #                    -srcip:         源ip
    #                    -dstip:         目的ip
    #                    -srcMAC:        源MAC地址(默认的为hub.slot.port)
    #                    -dstMAC:        目的MAC地址(默认的为hub.slot.port)
    #                    -duplex:        双工模式 0:半双工 1:全双工(默认为全双工)
    #                    -lossrate:      标识允许的包最大丢失率
    #                    -delay:         发送完一帧后的延时参数,默认为4，直通或者存储转发("cutThrough"/"storeAndForward")
    #                    -singlerate:    速率(默认值100M)  
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-28 16:38:55
    #修改纪录：     
    #!!================================================================
    proc SmbAppLatencyTest {PortList args} {
                 
        variable m_ChassisIP
        set ChassisIP  $m_ChassisIP

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }

        #格式转换
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
        user config -comments     "软件测试技术组"
    
    
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
    #过 程 名：     SmbAppPacketLossTest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     测试L2/L3的丢包性能
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               PortList:  测试使用的端口列表，如:{{1.1.1 1.1.2} {1.2.1 1.2.2}}
    #               args:  
    #                    -duration:      每次发送的时长(持续时间):1~N integer(默认为10)
    #                    -trialnum:      测试套个数(默认为1)
    #                    -customflag:    包是否按着递增的数需增加(1:是，0:手工指定包的长度.默认为0)
    #                    -packetlength:  手工指定的数据包长度, 该参数需要指定一串数据包得长度以列表的形式提供 
    #                                    例如: -packetlength {64 128 256 512 1024 1518}
    #                    -learn:         是否发送学习包 1: 发送， 0: 不发送(默认值为1)
    #                    -packetRetry:   重发的次数 (默认值为3)
    #                    -autonegotiate: 是否自适应 3: 是， 0: 不自适应(3为默认值)
    #                    -stoperror:     遇到错误的时候停止 1: 是， 0: 否(1为默认值)
    #                    -bidirection:   是否支持流量的单/双向定义 1: 支持。 0: 不支持
    #                    -inilength:     初始化长度 只是在customflag为1的时候适用 (默认值64)
    #                    -stoplength:    最大长度 只是在customflag为1的时候适用 (默认值1518)
    #                    -stepsize:      数据包步增大小 只是在customflag为1的时候适用 (默认值64)
    #                    -inirate:       初始速度 (默认值100)
    #                    -maxrate:       最大速度 (默认值100) 
    #                    -minrate:       最小速度 (默认值0.1)
    #                    -tolrate:       速度增量 (默认值0.5)
    #                    -router:        是否使用router test 1为使用 0为不使用(默认为0)
    #                    -srcip:         源ip
    #                    -dstip:         目的ip
    #                    -srcMAC:        源MAC地址(默认的为hub.slot.port)
    #                    -dstMAC:        目的MAC地址(默认的为hub.slot.port)
    #                    -duplex:        双工模式 0:半双工 1:全双工(默认为全双工)
    #                    -lossrate:      标识允许的包最大丢失率
    #                    -delay:         发送完一帧后的延时参数,直通或者存储转发("cutThrough"/"storeAndForward")
    #                    -singlerate:    速率(默认值100M) 
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-25 9:35:30
    #修改纪录：     
    #!!================================================================
    proc SmbAppPacketLossTest {PortList args} {   

        variable m_ChassisIP
        set ChassisIP  $m_ChassisIP

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }        

        #格式转换
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
        user config -comments     "软件测试技术组"
    
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
    #过 程 名：     SmbAppBackToBackTest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     测试L2/L3的背对背性能
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               PortList:  测试使用的端口列表，如:{{1.1.1 1.1.2} {1.2.1 1.2.2}}
    #               args:  
    #                    -duration:      每次发送的时长(持续时间):1~N integer(默认为10)
    #                    -trialnum:      测试套个数(默认为1)
    #                    -customflag:    包是否按着递增的数需增加(1:是，0:手工指定包的长度.默认为0)
    #                    -packetlength:  手工指定的数据包长度, 该参数需要指定一串数据包得长度以列表的形式提供 
    #                                    例如: -packetlength {64 128 256 512 1024 1518}
    #                    -learn:         是否发送学习包 1: 发送， 0: 不发送(默认值为1)
    #                    -packetRetry:   重发的次数 (默认值为3)
    #                    -autonegotiate: 是否自适应 3: 是， 0: 不自适应(3为默认值)
    #                    -stoperror:     遇到错误的时候停止 1: 是， 0: 否(1为默认值)
    #                    -bidirection:   是否支持流量的单/双向定义 1: 支持。 0: 不支持
    #                    -inilength:     初始化长度 只是在customflag为1的时候适用 (默认值64)
    #                    -stoplength:    最大长度 只是在customflag为1的时候适用 (默认值1518)
    #                    -stepsize:      数据包步增大小 只是在customflag为1的时候适用 (默认值64)
    #                    -inirate:       初始速度 (默认值100)
    #                    -maxrate:       最大速度 (默认值100) 
    #                    -minrate:       最小速度 (默认值0.1)
    #                    -tolrate:       速度增量 (默认值0.5)
    #                    -router:        是否使用router test 1为使用 0为不使用(默认为0)
    #                    -srcip:         源ip
    #                    -dstip:         目的ip
    #                    -srcMAC:        源MAC地址(默认的为hub.slot.port)
    #                    -dstMAC:        目的MAC地址(默认的为hub.slot.port)
    #                    -duplex:        双工模式 0:半双工 1:全双工(默认为全双工)
    #                    -lossrate:      标识允许的包最大丢失率
    #                    -delay:         发送完一帧后的延时参数,默认为4,直通或者存储转发("cutThrough"/"storeAndForward")
    #                    -singlerate:    速率(默认值100M) 
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-25 9:47:55
    #修改纪录：      
    #!!================================================================
    proc SmbAppBackToBackTest {PortList args} {
    
        variable m_ChassisIP
        set ChassisIP  $m_ChassisIP

        if {[IxParaCheck $args] == 1} {
            set retVal 1
            return $retVal
        }        

        #格式转换
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
        user config -comments     "软件测试技术组"
    
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
    #过 程 名：     DirDel
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     删除目录
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Dir: 目录名   
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     杨卓
    #生成日期：     2006-7-25 9:22:53
    #修改纪录：     
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
    #过 程 名：     SmbSetIpv4Stack
    #程 序 包：     SmbCommon
    #功能类别：     
    #过程描述：     设置端口配置参数
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               intHub:    SmartBits的hub号
    #               intSlot:   SmartBits接口卡所在的槽号
    #               intPort:   SmartBits接口卡的端口号
    #               args:
    #                   -mac : 设置 MAC 地址   0.0.0
    #                   -ip  : 设置 IP 地址    10.100.10.9
	#					-ip_mod : IP地址递增掩码 1-32 默认32
	#					-ip_step ：IP地址递增步长 默认1
	#					-ip_cnt：IP地址递增个数  默认1
	#					
    #                   -netmask : 设置子网掩码  255.255.255.0
    #                   -gateway : 设置网关地址  1.1.1.1
	#					-gateway_mod：网关地址递增掩码 1-32 默认32
	#					-gateway_step ：网关地址递增步长 默认1
	#					-gateway_cnt：网关地址递增个数  默认1
	#
    #                   -pingaddress : 设置ping的目的地址  0.0.0.0
    #                   -pingtimes   : 设置发ping包的时间间隔(每秒) 5
    #                   -arp_response  : 是否响应ARP请求(0/1)
    #                   -vlan          : VLAN ID
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     y61733
    #生成日期：     2009-4-7 16:59:37
    #修改纪录：     2009-07-23 陈世兵 把写硬件的API由ixWritePortsToHardware改为ixWriteConfigToHardware,防止出现链路down的情况,相应的就去掉了检查链路状态的步骤
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
                    
                    # 对于用户传递进来的 "xx xx xx xx xx xx"形式的MAC地址
                    if {[regexp {^\s*\w\w\s+\w\w\s+\w\w\s+\w\w\s+\w\w\s+\w\w\s*$} $tempcontent]} {
                        set tempcontent [join $tempcontent "-"]
                    }
                    
                    # modify by chenshibing 64165 2009-07-13 处理多个mac地址的情况
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
            
            # 将 255.255.0.0 格式转换成长度 16
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
    #过 程 名：     SmbSetIpv6Stack
    #程 序 包：     SmbCommon
    #功能类别：     
    #过程描述：     设置端口配置参数
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               intHub:    SmartBits的hub号
    #               intSlot:   SmartBits接口卡所在的槽号
    #               intPort:   SmartBits接口卡的端口号
    #               args:    #                   
    #                   -mac : 设置 MAC 地址   0.0.0
    #                   -ip  : 设置 IP 地址    ，IPV6格式，{0:0:0:0:0:0:0:2}
    #                   -netmask : 设置子网掩码  255.255.255.0
    #                   -gateway : 设置网关地址  （不支持)
    #                   -pingaddress : 设置ping的目的地址  0.0.0.0
    #                   -pingtimes   : 设置发ping包的时间间隔(每秒) 5
    #                   -arp_response  : 是否响应ARP请求(0/1)
    #                   -vlan          : VLAN ID
    #返 回 值：     成功返回0,失败返回错误码
    #作    者：     y61733
    #生成日期：     2009-4-7 16:59:37
    #修改纪录：     2009-07-23 陈世兵 把写硬件的API由ixWritePortsToHardware改为ixWriteConfigToHardware,防止出现链路down的情况,相应的就去掉了检查链路状态的步骤
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
                    # 对于用户传递进来的 "xx xx xx xx xx xx"形式的MAC地址
                    if {[regexp {^\s*\w\w\s+\w\w\s+\w\w\s+\w\w\s+\w\w\s+\w\w\s*$} $tempcontent]} {
                        set tempcontent [join $tempcontent "-"]
                    }
                    
                    # modify by chenshibing 64165 2009-07-13 处理多个mac地址的情况
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
            
            #修改开始：by liufangxia 2010-2-4 19:24
            #设置IPV6端口
            interfaceIpV6 setDefault 
			interfaceIpV6 config -maskWidth                           64
			interfaceIpV6 config -ipAddress                           $each_ip
			if {[interfaceEntry addItem addressTypeIpV6]} {
				errorMsg "Error calling interfaceEntry addItem addressTypeIpV6"
				set retCode $::TCL_ERROR
			}
            #修改结束：by liufangxia 2010-2-4 19:24
            
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
    #函数功能:这个函数的作用是返回当前运行脚本的名称,不包含.tcl
    #        如:当前运行的脚本是C:\test\ScriptMate API\RFC2544\temp.tcl
    #        那么就返回temp,转为Scriptmate所用,为了到相应的目录中提取测试结果
    #函数输入: argv0
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
    #过 程 名：     IxThroughputTest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     测试L2/L3的吞吐量(现在支持测试L2/L3层)
    #用法：         
    #示例：  IxThroughputTest  $ChassisIP $PortList $TrafficMap $MapDir $Speed $DuplexMode \
    #                  $AutoNeg $Framesizes $Duration $Trials $Tolerance $Resolution\
    #                  $MaxRatePct $MinRatePct $Protocol  $Filename      
    #               
    #参数说明：以下参数全部是是必选参数,而且必须按照顺序填写,如果是类似列表的参数,则必须先设置好
    #列表变量,再使用变量.如果直接是数值或者字符串,则直接填写即可.
    #
    # 1.ChassisIP: 测试仪IP地址
    # 2.PortList:  测试使用的端口列表，设置举例如下:
    #                        Chas  Card Port  IP        GateWay   Mask             类型/速率  
    #set PortList         { { 1     2    1     "1.1.1.2" "1.1.1.1" "255.255.255.0"  100 } \
    #                       { 1     2    2     "1.1.2.2" "1.1.2.1" "255.255.255.0"  100 } \
    #                     }
    # 在类型/速率中可选参数值有:
    # 电口:10/100/1000
    # 光口: Fiber1000
    # 10G以太: 10000
    # WAN口: ethOverSonet 或者 ethOverSdh
    #
    # 3.TrafficMap: 流量发送模型.    
    #    设置举例: set TrafficMap {{1 2 1  1 2 2} {1 2 2  1 2 1}}
    # 4.MapDir  :  单向/双向
    #    unidirectional
    # 这个参数取消 5.Speed : 端口速率   10/100/1000/10000(电口)  fiber1000(光口)
    # 6.DuplexMode: 双工状态,  full/half
    # 7.AutoNeg: 是否自协商, true/false
    # 8.Framesizes:包长的列表,  举例 set Framesizes [list 64 512 1518]
    # 9.Duration: 每次发送的时常,单位:秒
    # 10.Trials: 对于每种包长,进行测试的次数. 一般设置为1
    # 11. Tolerance: 容忍度, 一般设置为0
    # 12.Resolution:精度, 一般设置为0.01
    # 13.MaxPctRate: 最大速率的百分比, 一般设置为100, 即线速的100%.
    # 14.MinPctRate: 最小速率的百分比,一般设置为0.001
    # 15.Protocol: 协议类型, mac(二层) ip(三层,会进行ARP,需要注意设置Portlist中的地址信息)
    # 16.Filename: 当前执行的脚本名称,不要后缀. 如,当前运行脚本为main.tcl,那么这里输入main即可.
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-28 15:43:15
    #修改纪录：     2009.6.9
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
    #过 程 名：     IxLatencyTest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     测试L2/L3的延时性能
    #用法：         
    #示例：  IxLatencyTest  $ChassisIP $PortList $TrafficMap $MapDir $Speed $DuplexMode \
    #                  $AutoNeg $Framesizes $Duration $Trials $LatencyType \
    #                  $MaxRatePct $Protocol $Filename     
    #               
    #参数说明：以下参数全部是是必选参数,而且必须按照顺序填写,如果是类似列表的参数,则必须先设置好
    #列表变量,再使用变量.如果直接是数值或者字符串,则直接填写即可.
    #
    # 1.ChassisIP: 测试仪IP地址
    # 2.PortList:  测试使用的端口列表，设置举例如下:
    #                        Chas  Card Port  IP        GateWay   Mask             类型/速率  
    #set PortList         { { 1     2    1     "1.1.1.2" "1.1.1.1" "255.255.255.0"  100 } \
    #                       { 1     2    2     "1.1.2.2" "1.1.2.1" "255.255.255.0"  100 } \
    #                     }
    # 在类型/速率中可选参数值有:
    # 电口:10/100/1000
    # 光口: Fiber1000
    # 10G以太: 10000
    # WAN口: ethOverSonet 或者 ethOverSdh
    # 3.TrafficMap: 流量发送模型.    
    #    设置举例: set TrafficMap {{1 2 1  1 2 2} {1 2 2  1 2 1}}
    # 4.MapDir  :  单向/双向
    #    unidirectional
    # 这个参数取消 5.Speed : 端口速率   10/100/1000/10000(电口)  fiber1000(光口)
    # 6.DuplexMode: 双工状态,  full/half
    # 7.AutoNeg: 是否自协商, true/false
    # 8.Framesizes:包长的列表,  举例 set Framesizes [list 64 512 1518]
    # 9.Duration: 每次发送的时常,单位:秒
    # 10.Trials: 对于每种包长,进行测试的次数. 一般设置为1
    # 11.LatencyType: 延时类型, 一般设置为 "cutThrough"  备选值: "storeAndForward"/"cutThrough"
    # 12.MaxRatePct: 用来测试的端口速率. 为线速的百分比.
    # 13.Protocol: 协议类型, mac(二层) ip(三层,会进行ARP,需要注意设置Portlist中的地址信息)
    # 14.Filename: 当前执行的脚本名称,不要后缀. 如,当前运行脚本为main.tcl,那么这里输入main即可.
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-28 15:43:15
    #修改记录：     2009.6.9
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
    #过 程 名：     IxPacketLossTest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     测试L2/L3的丢包性能
    #用法：         
    #示例：  IxPacketLossTest  $ChassisIP $PortList $TrafficMap $MapDir $Speed $DuplexMode \
    #                    $AutoNeg $Framesizes $FrameNum  $Trials  \
    #                    $MaxRatePct $Protocol  $Filename     
    #               
    #参数说明：以下参数全部是是必选参数,而且必须按照顺序填写,如果是类似列表的参数,则必须先设置好
    #列表变量,再使用变量.如果直接是数值或者字符串,则直接填写即可.
    #
    # 1.ChassisIP: 测试仪IP地址
    # 2.PortList:  测试使用的端口列表，设置举例如下:
    #                        Chas  Card Port  IP        GateWay   Mask             类型/速率  
    #set PortList         { { 1     2    1     "1.1.1.2" "1.1.1.1" "255.255.255.0"  100 } \
    #                       { 1     2    2     "1.1.2.2" "1.1.2.1" "255.255.255.0"  100 } \
    #                     }
    # 在类型/速率中可选参数值有:
    # 电口:10/100/1000
    # 光口: Fiber1000
    # 10G以太: 10000
    # WAN口: ethOverSonet 或者 ethOverSdh
    # 3.TrafficMap: 流量发送模型.    
    #    设置举例: set TrafficMap {{1 2 1  1 2 2} {1 2 2  1 2 1}}
    # 4.MapDir  :  单向/双向
    #    unidirectional
    # 这个参数取消 5.Speed : 端口速率   10/100/1000/10000(电口)  fiber1000(光口)
    # 6.DuplexMode: 双工状态,  full/half
    # 7.AutoNeg: 是否自协商, true/false
    # 8.Framesizes:包长的列表,  举例 set Framesizes [list 64 512 1518]
    # 9.FrameNum: 每次发送的报文个数,单位:个包
    # 10.Trials: 对于每种包长,进行测试的次数. 一般设置为1
    # 11.MaxRatePct: 用来测试的端口速率. 为线速的百分比.
    # 12.Protocol: 协议类型, mac(二层) ip(三层,会进行ARP,需要注意设置Portlist中的地址信息)
    # 13.Filename: 当前执行的脚本名称,不要后缀. 如,当前运行脚本为main.tcl,那么这里输入main即可.
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-28 15:43:15
    #修改记录：     2009.6.9
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
    #过 程 名：     IxBackToBackTest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     测试DUT的L2/L3的背对背性能
    #用法：         
    #示例：  IxBackToBackTest  $ChassisIP $PortList $TrafficMap $MapDir $Speed  $DuplexMode \
    #                     $AutoNeg $Framesizes $Duration   $Trials $Tolerance \
    #                     $MaxRatePct $Protocol  $Filename    
    #               
    #参数说明：以下参数全部是是必选参数,而且必须按照顺序填写,如果是类似列表的参数,则必须先设置好
    #列表变量,再使用变量.如果直接是数值或者字符串,则直接填写即可.
    #
    # 1.ChassisIP: 测试仪IP地址
    # 2.PortList:  测试使用的端口列表，设置举例如下:
    #                        Chas  Card Port  IP        GateWay   Mask             类型/速率  
    #set PortList         { { 1     2    1     "1.1.1.2" "1.1.1.1" "255.255.255.0"  100 } \
    #                       { 1     2    2     "1.1.2.2" "1.1.2.1" "255.255.255.0"  100 } \
    #                     }
    # 在类型/速率中可选参数值有:
    # 电口:10/100/1000
    # 光口: Fiber1000
    # 10G以太: 10000
    # WAN口: ethOverSonet 或者 ethOverSdh
    # 3.TrafficMap: 流量发送模型.    
    #    设置举例: set TrafficMap {{1 2 1  1 2 2} {1 2 2  1 2 1}}
    # 4.MapDir  :  单向/双向
    #    unidirectional
    # 这个参数取消 5.Speed : 端口速率   10/100/1000/10000(电口)  fiber1000(光口)
    # 6.DuplexMode: 双工状态,  full/half
    # 7.AutoNeg: 是否自协商, true/false
    # 8.Framesizes:包长的列表,  举例 set Framesizes [list 64 512 1518]
    # 9.Duration: 每次发送的时常,单位:秒
    # 10.Trials: 对于每种包长,进行测试的次数. 一般设置为1
    # 11. Tolerance: 容忍度, 一般设置为0
    # 12.Resolution:精度, 一般设置为0.01
    # 13.MaxPctRate: 最大速率的百分比, 一般设置为100, 即线速的100%.
    # 14.MinPctRate: 最小速率的百分比,一般设置为0.001
    # 15.Protocol: 协议类型, mac(二层) ip(三层,会进行ARP,需要注意设置Portlist中的地址信息)
    # 16.Filename: 当前执行的脚本名称,不要后缀. 如,当前运行脚本为main.tcl,那么这里输入main即可.
    #返 回 值：     成功返回0,失败返回1
    #作    者：     杨卓
    #生成日期：     2006-7-28 15:43:15
    #修改记录：     2009.6.9
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
    #过 程 名：     SmbPortReboot
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     复位Ixia卡端口，重启CPU
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:          Ixia的hub号
    #               Card:          Ixia接口卡所在的槽号
    #               Port:          Ixia接口卡的端口号
    #返 回 值：     成功返回0,失败返回1
    #作    者：     虞乐
    #生成日期：     2010-11-8 9:09
    #修改纪录：     
    #!!================================================================
	proc SmbPortReboot { Chas Card Port } {
		return [ portCpu reset $Chas $Card $Port ]					
	}

    #!!================================================================
    #过 程 名：     SmbPortArpTableClear
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     清除端口ARP表
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:     Ixia的hub号
    #               Card:     Ixia接口卡所在的槽号
    #               Port:     Ixia接口卡的端口号
    #返 回 值：     成功返回0,失败返回1
    #作    者：     虞乐
    #生成日期：     2010-12-14 
    #修改纪录：     
    #!!================================================================
    proc SmbPortArpTableClear { Chas Card Port } {
    		return [ ixClearPortArpTable $Chas $Card $Port ]
    }
    
    #!!================================================================
    #过 程 名：     SmbPortArpRequest
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     端口发送ARP请求
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:     Ixia的hub号
    #               Card:     Ixia接口卡所在的槽号
    #               Port:     Ixia接口卡的端口号
    #返 回 值：     成功返回0,失败返回1
    #作    者：     虞乐
    #生成日期：     2010-12-14 
    #修改纪录：     
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
    #过 程 名：     SmbPortClearStream
    #程 序 包：     IXIA
    #功能类别：     
    #过程描述：     clear port streams
    #用法：         
    #示例：         
    #               
    #参数说明：     
    #               Chas:     Ixia的hub号
    #               Card:     Ixia接口卡所在的槽号
    #               Port:     Ixia接口卡的端口号
    #返 回 值：     成功返回0,失败返回1
    #作    者：     虞乐
    #生成日期：     2012-7-11
    #修改纪录：     
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


     
