#!/bin/bash
# Run MP-SPDZ auction party tunneled through Veilid
# Usage: ./run-veilid-auction.sh <party_id> <bid_value>
#
# Prerequisites:
# - Market node with MPC sidecar must be running (check logs for "MPC sidecar initialized successfully")
# - socat must be installed (sudo pacman -S socat)

set -e

PARTY_ID=${1}
BID_VALUE=${2}

if [ -z "$PARTY_ID" ] || [ -z "$BID_VALUE" ]; then
    echo "Usage: $0 <party_id> <bid_value>"
    echo "Example: $0 0 2000"
    exit 1
fi

if [ "$PARTY_ID" -lt 0 ] || [ "$PARTY_ID" -gt 2 ]; then
    echo "Error: Party ID must be 0, 1, or 2"
    exit 1
fi

echo "Starting MP-SPDZ Party $PARTY_ID with bid $BID_VALUE"
echo "Using Veilid tunneling (automatic port forwarding)"
echo

# Set up input file
echo "$BID_VALUE" > "Player-Data/Input-P${PARTY_ID}-0"
echo "Wrote bid to Player-Data/Input-P${PARTY_ID}-0"

# Verify socat forwarders are running
EXPECTED_FORWARDERS=$((2))  # Each party forwards to 2 others
ACTUAL_FORWARDERS=$(pgrep -f "socat.*TCP-LISTEN:500" | wc -l)

if [ "$ACTUAL_FORWARDERS" -lt "$EXPECTED_FORWARDERS" ]; then
    echo "WARNING: Expected $EXPECTED_FORWARDERS socat forwarders, found $ACTUAL_FORWARDERS"
    echo "Make sure the market node's MPC sidecar is running!"
    echo
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Running MP-SPDZ party..."
echo
./replicated-ring-party.x -p "$PARTY_ID" -N 3 -h HOSTS-localhost auction3
