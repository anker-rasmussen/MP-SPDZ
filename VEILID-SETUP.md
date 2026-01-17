# Running MP-SPDZ Auction over Veilid Network

This guide explains how to run a 3-party MP-SPDZ auction with all traffic tunneled through the Veilid network for privacy and decentralization.

## Architecture Overview

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  MP-SPDZ    │         │  MP-SPDZ     │         │  MP-SPDZ    │
│  Party 0    │         │  Party 1     │         │  Party 2    │
│ :5000       │         │ :5001        │         │ :5002       │
└──────┬──────┘         └──────┬───────┘         └──────┬──────┘
       │                       │                        │
┌──────▼──────────────────────▼───────────────────────▼───────┐
│              Socat Port Forwarders                           │
│  5001→15001   5002→15002     5000→15000   5002→15002  etc   │
└──────┬──────────────────────┬───────────────────────┬───────┘
       │                       │                        │
┌──────▼──────┐         ┌──────▼───────┐         ┌─────▼──────┐
│ MpcSidecar  │         │ MpcSidecar   │         │ MpcSidecar │
│ Party 0     │         │ Party 1      │         │ Party 2    │
│ :15001:15002│         │ :15000:15002 │         │ :15000:15001│
└──────┬──────┘         └──────┬───────┘         └─────┬───────┘
       │                       │                        │
       └───────────────────────┼────────────────────────┘
                     ┌─────────▼────────┐
                     │  Veilid Network  │
                     │  (Private Routes)│
                     └──────────────────┘
```

## Prerequisites

### 0. Install socat (required for automatic port forwarding)
```bash
sudo pacman -S socat
```

### 1. Veilid Devnet Running
```bash
cd /home/broadcom/Repos/Dissertation/Repos/dissertationapp
docker compose up -d
```

### 2. Market Nodes Running
You need 3 market instances running (one on each of nodes 5, 6, 7):

```bash
# Terminal 1: Market Node 5 (Party 0)
cd /home/broadcom/Repos/Dissertation/Repos/dissertationapp/market
MARKET_NODE_OFFSET=5 cargo run

# Terminal 2: Market Node 6 (Party 1)
MARKET_NODE_OFFSET=6 cargo run

# Terminal 3: Market Node 7 (Party 2)
MARKET_NODE_OFFSET=7 cargo run
```

Wait for all market nodes to attach to the Veilid network and exchange routes. You should see log messages like:
```
INFO  Initializing MPC sidecar for Party 0 (node offset 5)
INFO  Created Veilid route for MPC Party 0: VLD0:...
INFO  Published MPC Party 0 route to DHT at VLD0:...
INFO  Attempt 1/20: Fetching party routes...
INFO  Successfully fetched routes for 2 parties
INFO  MPC sidecar initialized successfully for Party 0
```

### 3. MP-SPDZ Compiled
```bash
cd /home/broadcom/Repos/Dissertation/Repos/MP-SPDZ
make -j8 replicated-ring-party.x
```

### 4. Auction Program Compiled
```bash
./compile.py auction3
```

## Running the Auction

The MPC sidecar now **automatically** sets up port forwarding using socat when it initializes. No manual setup scripts needed!

### Step 1: Verify MPC sidecars are running

Check the market node logs for successful initialization:
```
INFO  Initializing MPC sidecar for Party 0 (node offset 5)
INFO  Created Veilid route for MPC Party 0: VLD0:...
INFO  Published MPC Party 0 route to DHT at VLD0:...
INFO  Successfully fetched routes for 2 parties
INFO  Setting up automatic port forwarding for Party 0
INFO    Forwarding port 5001 -> 15001 (for connecting to Party 1)
INFO    Forwarding port 5002 -> 15002 (for connecting to Party 2)
INFO  Port forwarding active for 2 connections
INFO  MPC sidecar initialized successfully for Party 0
```

### Step 2: Set up input values

On each market node, create the input file:

```bash
# Market node 5 (Party 0) - bid 2000
echo 2000 > Player-Data/Input-P0-0

# Market node 6 (Party 1) - bid 1800
echo 1800 > Player-Data/Input-P1-0

# Market node 7 (Party 2) - bid 2500
echo 2500 > Player-Data/Input-P2-0
```

### Step 3: Create HOSTS file for localhost

MP-SPDZ needs a HOSTS file with localhost entries (socat will forward to Veilid proxies):

```bash
cd /home/broadcom/Repos/Dissertation/Repos/MP-SPDZ
cat > HOSTS-localhost <<EOF
localhost
localhost
localhost
EOF
```

### Step 4: Run MP-SPDZ parties

Start all three parties approximately simultaneously using the helper script:

On market node 5 (Party 0):
```bash
./run-veilid-auction.sh 0 2000
```

On market node 6 (Party 1):
```bash
./run-veilid-auction.sh 1 1800
```

On market node 7 (Party 2):
```bash
./run-veilid-auction.sh 2 2500
```

Or run directly:
```bash
# Set input and run party manually
echo 2000 > Player-Data/Input-P0-0
./replicated-ring-party.x -p 0 -N 3 -h HOSTS-localhost auction3
```

### Expected Output

Each party should see:
```
Using security parameter 40
Trying to run 13 opening threads
Starting 3-party sealed-bid auction
Party 0: bid received
Party 1: bid received
Party 2: bid received
Auction complete!
Winner: Party 2
Winning bid: 2500
Time: 0.123 seconds
Data sent: 1.234 MB
```

## Troubleshooting

### "Connection refused" errors
- Ensure market nodes are running with MPC sidecars initialized
- Check that socat forwarders are running: `ps aux | grep socat`
- Verify MPC sidecar is listening: `netstat -tlnp | grep 150`

### "Failed to fetch party routes"
- Wait longer for DHT propagation (can take 30-60 seconds)
- Check that all 3 market nodes are attached to Veilid
- Verify nodes are connected as peers: check market UI "Peers" count

### MP-SPDZ hangs during execution
- Ensure all 3 parties started within a few seconds of each other
- Check for firewall issues blocking localhost connections
- Verify input files exist for all parties

## Cleanup

Stop market nodes (socat forwarders will be automatically cleaned up):
```bash
# Ctrl+C in each terminal, or:
pkill -f "MARKET_NODE_OFFSET"
```

If any orphaned socat processes remain:
```bash
pkill -f "socat.*TCP-LISTEN:500[012]"
```

Stop Veilid devnet:
```bash
cd /home/broadcom/Repos/Dissertation/Repos/dissertationapp
docker compose down
```

## Technical Details

### Port Assignments

**MP-SPDZ Base Ports:**
- Party 0: listens on 5000
- Party 1: listens on 5001
- Party 2: listens on 5002

**MPC Sidecar Proxy Ports:**
- Party 0 proxies: 15001 (to P1), 15002 (to P2)
- Party 1 proxies: 15000 (to P0), 15002 (to P2)
- Party 2 proxies: 15000 (to P0), 15001 (to P1)

**Socat Forwarders:**
- Forward MP-SPDZ's outgoing ports → MPC sidecar proxy ports
- Example for Party 0: 5001→15001, 5002→15002

### Security Properties

- All MPC traffic encrypted by Veilid private routes
- No direct TCP connections between parties
- Bid values never revealed to other parties
- Only winner and winning amount are revealed (MPC output)
