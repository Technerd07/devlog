#!/bin/bash
append_logs (){
    echo "append logs to /var/log/devlog.log" file created 
    #TODO:
    local log_dir="/var/log/devlog"
    local log_file="/var/log/devlog/client.log"
            mkdir -vp "${log_dir}" || return 1
            touch -a "${log_file}" || return 1
        echo "Appending logs to ${log_file}"
        local message="$*"
        #append any incoming data to log file when the append func is called ($* or $@)can be used to get full input
        printf '%s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${message}" >> "${log_file}" 
}