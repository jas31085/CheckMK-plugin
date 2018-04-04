#!/bin/bash
#set -x

# ttr@mh
# 1.0   2016     - initial
# 1.1   201703   - suppress WARN when age older 2d (ERR only)
# 1.2   201704   - now handles mccli error 10020
# 1.3   201706   - now handles older VDP (5.x)
#
# 1. install script in VDP appliance: /usr/lib/check_mk_agent/plugins
# 2. /etc/sudoers:
#    check_mk ALL = (root) NOPASSWD: /usr/local/avamar/bin/mccli
#
#
# for VDP appliance maintenance put all services "VDP" of affected VMs in check_mk Downtime
#
#
# - scripts generates one check per VM (all that are protected by jobs of this local appliance)
#
# - states:
#   OK:   - check age less than 5min
#         - and - errorcode for last VM backup is 0
#         - and - last backup not older 90000secs (25h)
#   WARN: - last backup older 90000secs (25h)
#   CRIT  - last backup older 176400sec (49h)
#         - or - errorcode for last VM backup is not 0
#   UNKN: - check age older 5min
#
# - perfstat:
#         - transferred bytes
#         - duration in seconds
#
# - example status detail:
#         OK - vSphere Data Protection Backup, VM: de-bx-srv-1009, Appliance: de-bx-srv-1027, last run: 2017-01-05 18:36 CET (status: Completed, transferred 1.4% of 73.5GB)
#
# - uses avamar cli:
# #: mccli activity show
#0,23000,CLI command completed successfully.
#ID               Status    Error Code Start Time           Elapsed     End Time             Type             Progress Bytes New Bytes Client         Domain
#
#

# detect version
MCCLIVERSION=`sudo /usr/local/avamar/bin/mccli --version | sed -n 's/^mccli \(.*\)$/\1/p'`
#MCCLIVERSION="6.1.82-57"

# get last activity, ignore table headers and uninteresting columns
# adjust output to:
# STATUS ERRORCODE DURATION ENDDATE ENDTIME ENDTZ SIZE UNIT CHANGEDPERCENTAGE CLIENT REST

case ${MCCLIVERSION} in

  # VDP 6.x
  7*)
    MCCLIOUT=`sudo /usr/local/avamar/bin/mccli activity show \
               | sed 's/[ ][ ]*/ /g; s/Completed w/Completed_w/g' \
               | awk '/^[0-9]* / { print $2" "$3" "$7" "$8" "$9" "$10" "$13" "$14" "$15" "$16 }' \
               | sed 's/<0.05%/0/g; s/%//g'`
  ;;

  # VDP 5: mccli version 6.x
  *)
    MCCLIOUT=`sudo /usr/local/avamar/bin/mccli activity show --verbose \
               | sed 's/[ ][ ]*/ /g; s/Completed w/Completed_w/g' \
               | awk '/^[0-9]* / { print $2" "$3" "$7" "$8" "$9" "$6" "$13" Bytes "$14" "$15 }' \
               | sed 's/<0.05%/0/g; s/%//g'`

  ;;

esac

# get list of VMs in activity log
VMLIST=`echo "${MCCLIOUT}" | awk '{print $10}' | sort -u`

# store current time for calculating backup age
NOWSECONDS=`date +%s`

echo "<<<vmvdp>>>"

# loop thru the list
echo "${VMLIST}" | while read VM
do

  # get the VM lines, extract the most recent one:
  # line format: "Completed 0 2016-12-17 17:01 CET 00h:02m:55s 8.0 GB 0 de-bx-srv-1001"
  echo "${MCCLIOUT}" \
  | egrep ' '${VM}'$' \
  | sort -k 4,5 \
  | tail -1 \
  | while read STATUS ERRORCODE DURATION ENDDATE ENDTIME ENDTZ SIZE UNIT CHANGEDPERCENTAGE REST
  do

    unset $ERR
    unset $WARN

    EXITCODE=0

    # check errorcode: ToDo adjust codes
    case ${ERRORCODE} in
      0)
        #
      ;;
      10020)
        WARN=", possibly inconsistent (!), mccli-errorcode="${ERRORCODE}" (!)"
      ;;
      *)
        ERR=", mccli-errorcode="${ERRORCODE}"(!!)"
      ;;
    esac

    # calculate age of last backup
    ENDSECONDS=`date +%s -d "${ENDDATE} ${ENDTIME} ${ENDTZ}"`
    let DELTA=$NOWSECONDS-$ENDSECONDS

    if [ ${DELTA} -gt 90000 ]
    then
      if [ ${DELTA} -gt 176400 ]
      then
         ERR=${ERR}", ERROR: Backup older 2d (!!)"
      else
         WARN=${WARN}", WARN: Backup older 1d (!)"
      fi
    fi

    # calculate duration in seconds for perfstat
    DURATIONSEC=`echo ${DURATION} | sed 's/h:/ * 3600 + /; s/m:/ * 60 + /; s/s//' | bc`

    [ -z "${WARN}" ] || EXITCODE=1
    [ -z "${ERR}" ] || EXITCODE=2

    # human readable
    if [ ${UNIT} == "Bytes" ]
    then
      SIZE=`echo $SIZE | sed 's/,//g'`
      let SIZE=$SIZE/1073741824
      UNIT=GB
    fi

    if [[ "$EXITCODE" == "0" ]]; then
      stats="OK"
    elif [[ "$EXITCODE" == "1" ]]; then
        stats="WARNING"
        else
        stats="ERROR"
    fi


  c# check_mk local check piggyback
  echo ${EXITCODE}" "${VM}" - "$stats": "${STATUS}" transferred "${CHANGEDPERCENTAGE}" % of "${SIZE} ${UNIT}" in "${DURATIONSEC}" s, last_run: "${ENDDATE}"-"${ENDTIME} ${ERR} ${WARN}



  done

done