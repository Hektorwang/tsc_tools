#!/usr/bin/env bash
set -o errexit    # Exit immediately if a command exits with a non-zero status
set -o nounset    # Treat unset variables and parameters as an error
set -o pipefail   # If any command in a pipeline fails, the pipeline returns an error code
set +o posix      # Disable POSIX mode, allowing Bash-specific extensions (less portable)
shopt -s nullglob # When no files match a glob pattern, expand to nothing instead of the pattern itself

IFNAME="$1"
INTERVAL="3"

if [[ -z "${IFNAME}" ]]; then
    echo ""
    echo "usage: $0 [network-interface]"
    echo ""
    echo "e.g. $0 eth0"
    echo ""
    exit 1
fi

line_count=0

while true; do
    if ((line_count % 20 == 0)); then
        printf "%-20s|%-12s|%-12s|%-12s|%-12s|%-12s|%-12s\n" \
            "Datetime" \
            "Interface" \
            "TX(Mb/s)" \
            "TX(Pkts/s)" \
            "RX(Mb/s)" \
            "RX(Pkts/s)" \
            "Total(Mb/s)"
    fi

    rxb_1="$(cat /sys/class/net/"${IFNAME}"/statistics/rx_bytes)" || {
        echo "Error: Could not read rx_bytes for ${IFNAME}. Does the interface exist?"
        exit 1
    }
    txb_1="$(cat /sys/class/net/"${IFNAME}"/statistics/tx_bytes)" || {
        echo "Error: Could not read tx_bytes for ${IFNAME}. Does the interface exist?"
        exit 1
    }
    rxp_1="$(cat /sys/class/net/"${IFNAME}"/statistics/rx_packets)" || {
        echo "Error: Could not read rx_packets for ${IFNAME}. Does the interface exist?"
        exit 1
    }
    txp_1="$(cat /sys/class/net/"${IFNAME}"/statistics/tx_packets)" || {
        echo "Error: Could not read tx_packets for ${IFNAME}. Does the interface exist?"
        exit 1
    }

    sleep "${INTERVAL}"

    rxb_2="$(cat /sys/class/net/"${IFNAME}"/statistics/rx_bytes)" || {
        echo "Error: Could not read rx_bytes for ${IFNAME}. Does the interface exist?"
        exit 1
    }
    txb_2="$(cat /sys/class/net/"${IFNAME}"/statistics/tx_bytes)" || {
        echo "Error: Could not read tx_bytes for ${IFNAME}. Does the interface exist?"
        exit 1
    }
    rxp_2="$(cat /sys/class/net/"${IFNAME}"/statistics/rx_packets)" || {
        echo "Error: Could not read rx_packets for ${IFNAME}. Does the interface exist?"
        exit 1
    }
    txp_2="$(cat /sys/class/net/"${IFNAME}"/statistics/tx_packets)" || {
        echo "Error: Could not read tx_packets for ${IFNAME}. Does the interface exist?"
        exit 1
    }

    tx_bytes_diff=$((txb_2 - txb_1))
    rx_bytes_diff=$((rxb_2 - rxb_1))
    tx_packets_diff=$((txp_2 - txp_1))
    rx_packets_diff=$((rxp_2 - rxp_1))

    tx_mbps=$(awk "BEGIN {printf \"%.2f\", $tx_bytes_diff / 1024 / 1024 / $INTERVAL}")
    rx_mbps=$(awk "BEGIN {printf \"%.2f\", $rx_bytes_diff / 1024 / 1024 / $INTERVAL}")

    tx_pps=$(awk "BEGIN {printf \"%.2f\", $tx_packets_diff / $INTERVAL}")
    rx_pps=$(awk "BEGIN {printf \"%.2f\", $rx_packets_diff / $INTERVAL}")

    total_mbps=$(awk "BEGIN {printf \"%.2f\", $rx_mbps + $tx_mbps}")

    printf "%-20s|%-12s|%12.2f|%12.2f|%12.2f|%12.2f|%12.2f\n" \
        "$(date '+%F %T')" \
        "${IFNAME}" \
        "$tx_mbps" "$tx_pps" \
        "$rx_mbps" "$rx_pps" \
        "$total_mbps"

    line_count=$((line_count + 1))
done
