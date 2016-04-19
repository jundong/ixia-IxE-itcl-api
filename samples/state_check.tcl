##============================================================================================
## 函数名称: state_check
## 函数描述: 获取Ixia设备信息及端口占用状态
## 输入参数: ip -必选，指明Ixia机框的IP地址
## 返回值:   成功，以列表形式返回”IP地址,机框型号,机框序列号,版本号,槽位号,板卡型号,板卡序列号,
##					端口数量,占用状态,用户占用数量"；失败，返回0
## 用法示例: state_check -ip "192.168.0.100" 
## 修改记录: 2015-11-22,Ixia, Judo Xu
##============================================================================================
proc state_check {args} {
    if {[string first "-ip" $args]!=0 || [llength $args]!=2} {
        puts "参数错误，正确的参数形式：-ip \"xxx.xxx.xxx.xxx xxx.xxx.xxx.xxx\""
        return 0
    } else {
        array set ipArr $args
        set ip_list $ipArr(-ip) 
    }
    
    if { $::tcl_platform(platform) == "windows" } {
        package require registry
        
        proc GetEnvTcl { product } {       
            set productKey     "HKEY_LOCAL_MACHINE\\SOFTWARE\\Ixia Communications\\$product"
            if { [ catch {
                    set versionKey     [ registry keys $productKey ]
            } err ] } {
                    return ""
            }        
            
            set latestKey      [ lindex $versionKey end ]
            if { $latestKey == "InstallInfo" } {
                set latestKey      [ lindex $versionKey [expr [llength $versionKey] - 2]]
            }
            set mutliVKeyIndex [ lsearch $versionKey "Multiversion" ]
            if { $mutliVKeyIndex > 0 } {
               set latestKey   [ lindex $versionKey [ expr $mutliVKeyIndex - 2 ] ]
            }
            set installInfo    [ append productKey \\ $latestKey \\ InstallInfo ]            
            return             "[ registry get $installInfo  HOMEDIR ]/TclScripts/bin/ixiawish.tcl"   
        }
    
        if [catch {
            set ixPath [ GetEnvTcl IxOS ]
            if { [file exists $ixPath] == 1 } {
                source $ixPath
            }
		} errMsg ] {
			puts "加载Ixia IxOS安装路径失败，请确认是否已安装对应版本的Ixia Application."
			return 0
		}
    }
    
    proc CheckIsValidIPv4 { ipaddr } {
        set byteList [split $ipaddr .]
        if { [llength $byteList] != 4 } {
            return 0
        }
        foreach i $byteList {
            if { ![string is integer $i] || $i < 0 || $i > 255 } {
                return 0
            }
        }
        return 1
    }
    
    package require IxTclHal
    
    set tableHeader "IP地址,机框型号,机框序列号,版本号,槽位号,板卡型号,板卡序列号,端口数量,占用状态,用户占用数量"
    set userName IxiaTclUser-Inventory
    set retCode $::TCL_OK
    
    set retList [list]
    foreach ip $ip_list {
        if ![CheckIsValidIPv4 $ip] {
            puts "IP地址'$ip'不合法，请输入合法IP地址。" 
            return 0
        }
        if { [ixConnectToTclServer $ip] != $retCode } {
            puts "连接Ixia Tcl Server '$ip':4555失败，请检查网络连接。"
            return 0
        }
        ixLogin $userName
        if { [ixConnectToChassis $ip] != $retCode } {
            puts "连接Ixia机框'$ip'失败，请检查网络连接。"
            return 0
        }

        chassis setDefault
        chassis get $ip
        set chassisId	[chassis cget -id]
        set chassisType [chassis cget -typeName]
        if { [ catch {
            set chassisSN   [chassis cget -serialNumber]
        } err ] } {
            set chassisSN   "N/A"
        }   
        set version     [chassis cget -ixServerVersion]
                
        set maxCards [chassis cget -maxCardCount]
        set sn ""
        for {set cardIndex 1} {$cardIndex<=$maxCards} {incr cardIndex} {
            card setDefault
            card get $chassisId $cardIndex
            set cardIndex $cardIndex
            set cardType [card cget -typeName]
            set cardSN [card cget -serialNumber]
            if { $cardSN != "" } {
                set cardSN [lrange $cardSN 3 3]
            }
            set portCount [card cget -portCount]

            set portStatus ""
            set portUserStatus ""
            
            set flag false
            if { $sn != $cardSN && $cardSN != "" } {
                set flag true
            } elseif { $cardType == "Ixia Virtual Load Module" } {
                set flag true
            }
            
            if { $flag } {				
                array unset userStatus
                for {set portIndex 1} {$portIndex<=$portCount} {incr portIndex} {
                    port setDefault
                    port get $chassisId $cardIndex $portIndex
                    set owner [port cget -owner]
                    if { $owner != "" } {
                        set portStatus ${portStatus}1
                        if { [info exists userStatus($owner)] } {
                            set userStatus($owner) [expr $userStatus($owner) + 1]
                        } else {
                            set userStatus($owner) 1
                        }
                    } else {
                        set portStatus ${portStatus}0
                    }
                }
                if { [array exists userStatus] } {
                    set arrnames [array names userStatus]
					foreach arrname $arrnames {
                        append portUserStatus $arrname<$userStatus($arrname)>
                    }
				} else {
                    set portUserStatus "N/A"
                }
                lappend retList "$ip,$chassisType,$chassisSN,$version,$cardIndex,$cardType,$cardSN,$portCount,$portStatus,$portUserStatus"
                set sn $cardSN
            }		
        }
        #Logout the system
        ixLogout
        ixDisconnectFromChassis
    }
    puts $tableHeader
    foreach row $retList {
        puts $row\r
    }
    return $retList
}

#state_check -ip "10.210.100.12"
#state_check -ip "172.16.174.137"
#state_check -ip "172.18.2.12"
state_check -ip "172.18.2.8"