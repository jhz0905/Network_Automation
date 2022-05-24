::cisco::eem::event_register_timer cron name crontimer cron_entry $_cron_fabric_entry maxrun_sec 600 

namespace import ::cisco::eem::*
namespace import ::cisco::lib::*

set errorInfo ""
set _fab_max 6
set last_sum 0
array set _arr_xbar_crc {}
array set first_error_sum {} 
array set second_error_sum {}
action_syslog priority info msg "-------------------------------------------"
action_syslog priority info msg "EEM script was triggered"

proc check_crc {result _fab_cnt} {
        set _show_xbar_crc [ split $result \n ]                                                     
        set _show_xbar_crc_length [ expr [llength $_show_xbar_crc ] - 1 ]
        set _xbar_str2 ""
        set _fab_no $_fab_cnt
        set _xbar_port_id_rd 0
        set _xbar_port_id 0
        set _xbar_port_id_cnt 0
        set _xbar_crc_cnt 0

        set mc_error_value 0
        set uc_error_value 0
        set port_error_sum 0
        set mc_uc_sum 0

        for { set _lineCount 0 } { [ expr $_show_xbar_crc_length - $_lineCount ] } { incr _lineCount 1} {
                set _xbar_str1 [ lindex $_show_xbar_crc $_lineCount ] 
                regexp -nocase {^(\S+| *\S+)} [ lindex $_show_xbar_crc $_lineCount ] _xbar_str2
                if { $_xbar_str2 == "Port"} {
                        regexp -nocase {port.([0-9]+)} $_xbar_str1 _match _xbar_port_id_rd
                        continue
                }

                ##########################################################################################
                if { $_xbar_str2 == "Hi"} {
                        set _xbar_port_id [ expr $_xbar_port_id_rd * 2 ]
                        set _arr_xbar_crc($_xbar_port_id) 0
                        #action_syslog priority info msg "xbar port $_xbar_port_id_rd uc CRC is $_arr_xbar_crc($_xbar_port_id)"
                        continue

                } 
                if { $_xbar_str2 == "Low"} {
                        incr _xbar_port_id 1
                        set _arr_xbar_crc($_xbar_port_id) 0
                        #action_syslog priority info msg "xbar port $_xbar_port_id_rd mc CRC is $_arr_xbar_crc($_xbar_port_id)"
                        continue
                } 
                ##########################################################################################

                if { $_xbar_str2 == "    Packet"} {
                        regexp -nocase {Count +: ([0-9]+)} $_xbar_str1 _match _xbar_crc_cnt
                        set _arr_xbar_crc($_xbar_port_id) $_xbar_crc_cnt
                        set _even_odd [ expr { $_xbar_port_id % 2 } ]

                ##########################################################################################
                        if { $_even_odd == 0 } {
                                #action_syslog priority info msg "xbar port $_xbar_port_id_rd uc CRC is $_arr_xbar_crc($_xbar_port_id)"
                                set uc_error_value $_arr_xbar_crc($_xbar_port_id)
                                set mc_error_value 0
                        }
                        if { $_even_odd == 1 } {
                                #action_syslog priority info msg "xbar port $_xbar_port_id_rd mc CRC is $_arr_xbar_crc($_xbar_port_id)"
                                set mc_error_value $_arr_xbar_crc($_xbar_port_id)
                                set uc_error_value 0
                        }
                ##########################################################################################
                        set port_error_sum [expr $port_error_sum + $mc_error_value + $uc_error_value]
                        continue
                }
                 
        }
        return $port_error_sum
}

if [catch {cli_open} result] {
    error $result $errorInfo
} else {
    array set cli1 $result
}

for { set repeat_cnt 0 } { $repeat_cnt < 2 } { incr repeat_cnt 1} {
    for { set _fab_cnt 0 } { [ expr $_fab_max - $_fab_cnt ] } { incr _fab_cnt 1} {
            if [catch {cli_exec $cli1(fd) "show controllers fabric crossbar statistics instance 0 spine $_fab_cnt | include \"xbar|uni|mul|CRC\""} result_1] {
                error $result_1 $errorInfo
            }
                set ar_1st_xbar_crc [check_crc $result_1 $_fab_cnt]
                

                if { $repeat_cnt == 0 } {
                    set first_error_sum($_fab_cnt) $ar_1st_xbar_crc
                    set ar_1st_xbar_crc 0
                    if {$first_error_sum($_fab_cnt) != 0} {
                    action_syslog priority info msg "First) Fabric_Error_Sum($_fab_cnt): $first_error_sum($_fab_cnt)"
                    }
                    continue
                } else {
                    set second_error_sum($_fab_cnt) $ar_1st_xbar_crc
                    set ar_1st_xbar_crc 0
                    if {$first_error_sum($_fab_cnt) != 0} {
                    action_syslog priority info msg "Second) Fabric_Error_Sum($_fab_cnt): $second_error_sum($_fab_cnt)"
                    }
                } 
                
        }
        if { $repeat_cnt == 0 } {
        action_syslog priority info msg "wait 30 sec.... Second Check will start soon"        
        after 30000
        continue
        } else {
               for { set _fab_cnt 0 } { [ expr $_fab_max - $_fab_cnt ] } { incr _fab_cnt 1} {
                       set last_sum [ expr $second_error_sum($_fab_cnt) - $first_error_sum($_fab_cnt) ]
                       if { $last_sum > 50 } {
                               action_syslog priority info msg "increase Error : $last_sum"
                       }
               }
        }

}

action_syslog priority info msg "-------------------------------------------"

if [catch {cli_close $cli1(fd) $cli1(tty_id)} result] {
    error $result $errorInfo
}
############################################################################################################################################

