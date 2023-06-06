#!/bin/bash

# NOTE: The script needs root credentials! By Questor
if [[ $EUID -ne 0 ]]; then
    echo " > ---------------------------------"
    echo " ERROR! You need to be root!"
    echo " < ---------------------------------"
    exit 1
fi

FIRST_INTERAC=1
TEST_URI="https://check.torproject.org"
CURL_MAX_TIME=160
CURL_CONNECT_TIMEOUT=80
FIRST_INTERAC_OR_RESTART_PROCESS=1
ERROR_TOLERANCE=20
TOR_LATENCY_TOLERANCE=6
ERROR_TOLERANCE_OCCURRENCES=0
KILL_9_CMD="ps axf | egrep -i \"*/usr/bin/tor*\" | egrep -v grep | awk '{print \"kill -9 \" $1 \" 2> /dev/null 1> /dev/null &\"}'"
START_TOR_CMD="sudo -u tor /usr/bin/tor 2> /dev/null 1> /dev/null &"
TOR_LATENCY=10
RESTARTS_SO_FAR=0
CURL_RESULT=""
START_TIME=0
ELAPSED_TIME_MEASURES=0
ELAPSED_TIME_MEASURES_MINUMUM=5
ELAPSED_TIME_MEASURES_TOTAL=0
ELAPSED_TIME=0
ELAPSED_TIME_TOTAL=0
ELAPSED_TIME_AVERAGE=0
ELAPSED_TIME_AVERAGE_MAXIMUM=25
FAILURE_CAUSE=""
eval $KILL_9_CMD
clear
echo "STARTING TOR..."
echo "TRYING ESTABLISH CONNECTION..."
eval $START_TOR_CMD
sleep $TOR_LATENCY
while : ; do
    while : ; do
        if [ ${ERROR_TOLERANCE_OCCURRENCES} -gt ${ERROR_TOLERANCE} ] ; then
            eval $KILL_9_CMD
            clear
            echo "SOMETHING IS WRONG. PROCESS TERMINATED! =[
TIP: A firewall may be blocking the Tor network. Try starting Tor on a network without a firewall (a mobile network, for example) so your Tor network parameters can be updated. This done, try to access again through the firewalled network."
            exit -1
        fi
        if [ ${FIRST_INTERAC_OR_RESTART_PROCESS} -eq 0 ] ; then
            echo "TESTING TOR CONNECTION..."
        fi
        if ! ( [ ${ELAPSED_TIME_MEASURES} -ge ${ELAPSED_TIME_MEASURES_MINUMUM} ] && [ ${ELAPSED_TIME_AVERAGE} -gt ${ELAPSED_TIME_AVERAGE_MAXIMUM} ] ) ; then
            START_TIME=$SECONDS
            CURL_RESULT=$(curl --connect-timeout $CURL_CONNECT_TIMEOUT --max-time $CURL_MAX_TIME --socks5 127.0.0.1:9050 --socks5-hostname 127.0.0.1:9050 -fsS $TEST_URI 2>&1 1>/dev/null)
            FAILURE_CAUSE="> HTTP TEST ERROR: \"$CURL_RESULT\""
        else
            FAILURE_CAUSE="> SLOW HTTP TRAFFIC: \"Average response time above the limit (TIME_AVERAGE: $ELAPSED_TIME_AVERAGE, TIME_AVERAGE_MAXIMUM: $ELAPSED_TIME_AVERAGE_MAXIMUM)!\""
        fi
        if ( [ ${ELAPSED_TIME_MEASURES} -ge ${ELAPSED_TIME_MEASURES_MINUMUM} ] && [ ${ELAPSED_TIME_AVERAGE} -gt ${ELAPSED_TIME_AVERAGE_MAXIMUM} ] ) || [ -n "$CURL_RESULT" ] ; then
            ELAPSED_TIME_MEASURES=0
            ELAPSED_TIME_TOTAL=0
            ELAPSED_TIME_MEASURES_TOTAL=0
            if [ ${FIRST_INTERAC_OR_RESTART_PROCESS} -eq 0 ] || [ ${ERROR_TOLERANCE_OCCURRENCES} -gt ${TOR_LATENCY_TOLERANCE} ] ; then
                eval $KILL_9_CMD
                clear
                if [ ${ERROR_TOLERANCE_OCCURRENCES} -le ${TOR_LATENCY_TOLERANCE} ] ; then
                    echo "SHIT! THEY GOT ME! =["
                    echo $FAILURE_CAUSE
                    echo "TRYING REESTABLISH CONNECTION..."
                else
                    echo $FAILURE_CAUSE
                fi
                FIRST_INTERAC_OR_RESTART_PROCESS=1
                ((ERROR_TOLERANCE_OCCURRENCES++))
                ((RESTARTS_SO_FAR++))
                break
            else
                ((ERROR_TOLERANCE_OCCURRENCES++))
                echo $FAILURE_CAUSE
            fi
        else
            if [ ${ELAPSED_TIME_MEASURES} -ge ${ELAPSED_TIME_MEASURES_MINUMUM} ] ; then
                ELAPSED_TIME_TOTAL=0
                ELAPSED_TIME_MEASURES=0
            fi
            ((ELAPSED_TIME_MEASURES++))
            ((ELAPSED_TIME_MEASURES_TOTAL++))
            ELAPSED_TIME=$(($SECONDS - $START_TIME))
            ELAPSED_TIME_TOTAL=$(($ELAPSED_TIME_TOTAL + $ELAPSED_TIME))
            ELAPSED_TIME_AVERAGE=$(($ELAPSED_TIME_TOTAL/$ELAPSED_TIME_MEASURES))
            echo "CONNECTION OK! =]
    RESTART(S):..... $RESTARTS_SO_FAR
    TIME: .......... $(date '+%H:%M:%S')
    RESPONSE TIME: . $ELAPSED_TIME sec(s)
    AVERAGE TIME: .. $ELAPSED_TIME_AVERAGE sec(s) ($ELAPSED_TIME_MEASURES measure(s) of $ELAPSED_TIME_MEASURES_MINUMUM, $ELAPSED_TIME_MEASURES_TOTAL in total)"
            FIRST_INTERAC_OR_RESTART_PROCESS=0
            ERROR_TOLERANCE_OCCURRENCES=0
        fi
    done
    eval $START_TOR_CMD
    sleep $TOR_LATENCY
done
