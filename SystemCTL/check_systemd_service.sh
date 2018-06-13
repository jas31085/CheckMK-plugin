#! /bin/bash

# Crontab list for Check_mk or nagios 
#
# list of system crontab only in /var/spool
# 
# (c) 2018, Edoardo Marchetti <marchetti.edoardo@gmail.com>
# https://github.com/jas31085

# -----------------------------------------------------------------------
# -----------------------------------------------------------------------

File="/etc/check_mk/systemctl.conf"

# if [[ $# -ne 1 ]]; then
#     echo "Usage: ${0##*/} <service name>"
#     exit $STATE_UNKNOWN
# fi

echo "<<<systemctl>>>"

while read -r service; do

        Status=$(systemctl is-active ${service} 2>/dev/null)
        EXITCODE=$?
        if [[ -z "${Status}" ]]; then
            echo "1" systemctl-"${service}" - "ERROR: ${service} doesn't exist"
        elif [[ ${EXITCODE} -ne 0 ]]; then
            echo "2" systemctl-"${service}" - "ERROR: ${service} is ${Status}"  
        else
            Enable=$(systemctl is-enabled ${service} 2>/dev/null)
            EnableCode=$?
            if [[ ${EnableCode} -ne 0 ]]; then
                echo "1 systemctl-${service} - OK: ${service} is running - ${service} is ${Enable}" 
            else
                echo "${EXITCODE} systemctl-${service} - OK: ${service} is running - ${service} is ${Enable}" 
            fi
        fi

done <<< "$(cat ${File})"