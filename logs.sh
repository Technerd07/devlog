#!/bin/bash
append_logs (){
    #stdout is the network socket in the server, so nothing here may print to stdout
    local log_dir="${LOG_DIR:-/var/log/devlog}"
    local log_file="${log_dir}/client.log"
    local message="$*"
    mkdir -p "${log_dir}" 2>/dev/null || { echo "append_logs: cannot create ${log_dir}" >&2; return 1; }
    #append any incoming data to log file when the append func is called ($* or $@)can be used to get full input
    printf '%s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${message}" >> "${log_file}" \
        || echo "append_logs: cannot write ${log_file}" >&2
}