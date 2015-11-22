##============================================================================================
## ��������: state_check
## ��������: ��ȡIxia�豸��Ϣ���˿�ռ��״̬
## �������: ip -��ѡ��ָ��Ixia�����IP��ַ
## ����ֵ:   �ɹ������б���ʽ���ء�IP��ַ,�����ͺ�,�������к�,�汾��,��λ��,�忨�ͺ�,�忨���к�,
##					�˿�����,ռ��״̬,�û�ռ������"��ʧ�ܣ�����0
## �÷�ʾ��: state_check -ip "192.168.0.100" 
## �޸ļ�¼: 2015-11-22,Ixia, Judo Xu
##============================================================================================
proc state_check {args} {
    if {[string first "-ip" $args]!=0 || [llength $args]!=2} {
        puts "����������ȷ�Ĳ�����ʽ��-ip \"xxx.xxx.xxx.xxx xxx.xxx.xxx.xxx\""
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
                source [ GetEnvTcl IxOS ]
            }
		} errMsg ] {
			puts "����STC��װ·��ʧ�ܣ���ȷ���Ƿ��Ѱ�װ��Ӧ�汾��STC application."
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
    
    set tableHeader "IP��ַ,�����ͺ�,�������к�,�汾��,��λ��,�忨�ͺ�,�忨���к�,�˿�����,ռ��״̬,�û�ռ������"
    set userName IxiaTclUser-Inventory
    set retCode $::TCL_OK
    
    foreach ip $ip_list {
        if ![CheckIsValidIPv4 $ip] {
            puts "IP��ַ'$ip'���Ϸ���������Ϸ�IP��ַ��" 
            return 0
        }
        
        ixLogin $userName      
        if { [ixConnectToChassis $ip] != $retCode } {
            puts "����Ixia����'$ip'ʧ�ܣ������������ӡ�"
            return 0
        }

        set retList [list]
        chassis get $ip
        set chassisId	[chassis cget -id]
        set chassisType [chassis cget -typeName]
        set chassisSN   [chassis cget -serialNumber]
        set version     [chassis cget -ixServerVersion]
                
        set maxCards [chassis cget -maxCardCount]
        set sn ""
        for {set cardIndex 1} {$cardIndex<=$maxCards} {incr cardIndex} {
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
            if { $sn != $cardSN } {				
                array unset userStatus
                for {set portIndex 1} {$portIndex<=$portCount} {incr portIndex} {
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
    }
    puts $tableHeader
    foreach row $retList {
        puts $row\r
    }
    return $retList
}

state_check -ip "10.210.100.12"