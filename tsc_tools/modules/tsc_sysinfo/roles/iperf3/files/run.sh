#!/bin/bash
pkill -f /bin/iperf3
sleep 1

/bin/iperf3 $*

# if ! /bin/iperf3 $*; then
#     sleep 5
#     /bin/iperf3 $*
# fi

# sleep 3