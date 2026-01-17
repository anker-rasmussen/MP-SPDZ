#!/bin/bash
# Manual MPC Auction Runner
# Usage: ./run-auction.sh <bid5> <bid6> <bid7>
#   bid5 = Node 5's bid (Party 0)
#   bid6 = Node 6's bid (Party 1)
#   bid7 = Node 7's bid (Party 2)

BID5=${1:-1000}
BID6=${2:-1500}
BID7=${3:-1200}

echo "Setting up auction with bids:"
echo "  Node 5 (Party 0): $BID5"
echo "  Node 6 (Party 1): $BID6"
echo "  Node 7 (Party 2): $BID7"
echo

# Create input files
echo $BID5 > Player-Data/Input-P0-0
echo $BID6 > Player-Data/Input-P1-0
echo $BID7 > Player-Data/Input-P2-0

# Run the auction
echo "Running MPC computation..."
Scripts/compile-run.py -E replicated-ring auction3 2>&1 | tail -20
