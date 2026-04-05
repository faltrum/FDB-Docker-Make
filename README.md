# fdb Docker Stack

This repository packages the [fbd](https://github.com/fistbump-org/fbd) node and its CLI tools into a Docker-based local environment. The goal is to make the project easy to reproduce on macOS, Linux, and Windows with the same workflow.

The stack builds a custom image, starts the node, exposes the public P2P port, and keeps chain data in a persistent Docker volume.

## Table of Contents

- [Project Layout](#project-layout)
- [Requirements](#requirements)
- [Setup](#setup)
- [Quick Start](#quick-start)
- [Running the Project](#running-the-project)
- [Blockchain and Wallet Commands](#blockchain-and-wallet-commands)
- [Environment Variables](#environment-variables)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Project Layout

```text
.
├── .env.example
├── Makefile
└── src/
   ├── compose.yaml
   ├── fdb/
   │   ├── Dockerfile
   │   └── script/
   │       └── start-fbd.sh
   ├── ubuswift/
   │   └── Dockerfile
   └── scripts/
      └── setup.sh
```

## Requirements

You need the following tools installed locally:

- Docker Engine or Docker Desktop
- Docker Compose v2
- GNU Make
- A shell that can run `make` commands

Recommended host setups:

- macOS: Docker Desktop + Homebrew + GNU Make
- Linux: Docker Engine/Compose + GNU Make
- Windows: Docker Desktop + GNU Make, ideally through WSL2, Git Bash, or another Unix-like shell

## Setup

1. Run the setup script first. It installs everything needed for your OS and prepares the environment:

   ```bash
   ./src/scripts/setup.sh
   ```

2. Copy the example environment file:

   ```bash
   cp .env.example .env
   ```

3. Edit `.env` and fill in the required values:

   - `MINER_ADDRESS`
   - `API_KEY`
   - `AGENT`

4. Check available commands:

   ```bash
   make help
   ```

## Quick Start

1. Start the stack:

   ```bash
   make up
   ```

2. Follow logs (optional):

   ```bash
   make logs
   ```

3. Stop the stack when finished:

   ```bash
   make down
   ```

4. Full repo cleanup (optional, for fresh reinstall/debug):

   ```bash
   make reset-docker
   ```

   This cleanup is repo-scoped: it removes this compose stack, its volumes, and local project images.

5. Global Docker cleanup:

   ```bash
   make prunator
   ```

   Perform a global Docker cleanup (all unused containers, images, networks, volumes, cache).

6. Full cleanup flow:

   ```bash
   make wipe-all
   ```

   Run the full cleanup flow: project teardown + repo cleanup + global prune.

[Back to top](#fdb-docker-stack)

## Running the Project

The default workflow is managed through `make`:

```bash
make up
make logs
make down
```

Useful lifecycle commands:

- `make up` starts the stack in detached mode and rebuilds the image.
- `make down` stops the stack.
- `make restart` restarts the stack.
- `make build-base` builds the reusable Swift/Ubuntu dependency image.
- `make build` rebuilds the image without starting the stack.
- `make logs` streams container logs.
- `make ps` shows the running services.
- `make config` prints the resolved Compose configuration.
- `make pull` pulls remote images when applicable.
- `make clean` removes the stack and its volume.
- `make reset-docker` performs a full repo-only cleanup (stack, volumes, local project images).

[Back to top](#fdb-docker-stack)

## Blockchain and Wallet Commands

The Makefile also exposes higher-level commands for `fbdctl`.

Blockchain examples:

```bash
make chaininfo
make blockcount
make bestblockhash
make blockhash HEIGHT=100
make blockheader BLOCK=0000000000000000000000000000000000000000000000000000000000000000
make block BLOCK=100 VERBOSE=true
make mempool
make network
make peers
make mining
make stop-node
```

Wallet examples:

```bash
make wallets
make wallet-info
make wallet-balance
make wallet-address
make wallet-change
make wallet-unspent
make wallet-addresses
make wallet-txs COUNT=20 OFFSET=0
make wallet-actions
```

Generic commands:

```bash
make ctl ARGS='getblockhash 100'
make rpc METHOD=getblockhash PARAMS='[100]'
```

[Back to top](#fdb-docker-stack)

## Environment Variables

The stack reads its runtime configuration from `.env`.

| Variable | Description |
| --- | --- |
| `NETWORK` | Network name used by the node, usually `main` |
| `HOST` | Bind host for the node inside the container |
| `RPC_HOST` | RPC host value used by the node and `make rpc` |
| `DATADIR` | Persistent data directory inside the container |
| `P2P_PORT` | Host port mapped to the node P2P port |
| `API_PORT` | Host port mapped to the API port |
| `API_BIND_IP` | Host IP used for the API port binding |
| `MINER_ADDRESS` | Miner payout address required by the node |
| `API_KEY` | API key used by `fbdctl` and RPC calls |
| `WALLET` | Wallet name used by wallet-related make targets |
| `AGENT` | Agent identifier passed to the node |
| `MINER_THREADS` | Number of mining threads to use |

If you only want a starting point, copy values from `.env.example` and then adjust them for your machine.

## How It Works

The main build and runtime files are located under `src/`:

- `src/ubuswift/Dockerfile` builds a reusable base image with Swift and native build dependencies.
- `src/fdb/Dockerfile` builds the image from the upstream `fbd` source.
- `src/compose.yaml` starts the container and wires the persistent volume and ports.

The node startup logic is defined in `src/fdb/script/start-fbd.sh` and copied into the image at build time to keep runtime behavior portable.

The lifecycle targets `make up` and `make build` automatically run `make build-base` first, so dependency layers can be reused across app rebuilds.

[Back to top](#fdb-docker-stack)

## Troubleshooting

- If `make up` fails because required variables are missing, verify your `.env` file.
- If Docker cannot read the `.env` file, make sure you are running the command from the repository root.
- If the container starts but the API is unreachable, confirm that `API_BIND_IP` and `API_PORT` are correct.
- If you want to reset local chain data, run `make clean`.
- If you need a fresh install/debug baseline for this repo only, run `make reset-docker` and then `make up`.

[Back to top](#fdb-docker-stack)

## License

This repository follows the license of the upstream project if one is provided there. Review the upstream `fbd` project for implementation details and licensing terms.

[Back to top](#fdb-docker-stack)
