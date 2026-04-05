# ============================================================================
# VARIABLES
# ============================================================================

COMPOSE := docker compose --env-file .env -f src/compose.yaml
SERVICE := fbd
SHELL_CMD := sh -lc
EXEC := $(COMPOSE) exec $(SERVICE) $(SHELL_CMD)
FBDCTL_BASE := fbdctl --api-key "$$API_KEY"
BUILDER_BASE_IMAGE := fbd-builder-base:swift6.2.3-jammy

WALLET_FROM_ENV := $(shell sed -n 's/^WALLET=//p' .env | tail -n 1)
WALLET ?= $(if $(WALLET_FROM_ENV),$(WALLET_FROM_ENV),main)

RPC_HOST ?= 127.0.0.1
RPC_PORT ?= 32869
HEIGHT ?= 0
BLOCK ?= 0
VERBOSE ?= true
COUNT ?= 10
OFFSET ?= 0
FROM_HEIGHT ?=
METHOD ?= getblockcount
PARAMS ?= []
ARGS ?= getblockcount
MNEMONIC ?=
RECOVER_NAME ?= recovered
BACKUP_PATH ?= /root/recovered-wallet.json

# ============================================================================
# FUNCTIONS
# ============================================================================

define run-fbdctl
	$(EXEC) '$(FBDCTL_BASE) $(1)'
endef

define run-wallet
	$(EXEC) '$(FBDCTL_BASE) --wallet "$(WALLET)" $(1)'
endef


# ============================================================================
# TARGETS: INFRASTRUCTURE / LIFECYCLE
# ============================================================================

# Build (if needed) and start the stack in detached mode.
up: build-base
	$(COMPOSE) up -d --build

# Stop and remove containers, keeping named volumes by default.
down:
	$(COMPOSE) down

# Recreate the stack by running a full stop/start cycle.
restart: down up

# Build or rebuild service images without starting containers.
build: build-base
	$(COMPOSE) build

# Build the reusable Swift builder base image once for faster rebuilds.
build-base:
	docker build -f src/ubuswift/Dockerfile -t $(BUILDER_BASE_IMAGE) .

# Follow runtime logs for the main service.
logs:
	$(COMPOSE) logs -f $(SERVICE)

# Show current status of compose services.
ps:
	$(COMPOSE) ps

# Render the fully resolved compose configuration.
config:
	$(COMPOSE) config

# Pull referenced remote images (when applicable).
pull:
	$(COMPOSE) pull

# Internal: remove stack resources (containers, networks, volumes).
downv:
	$(COMPOSE) down -v --remove-orphans

# Internal: remove stack resources and local compose-built images.
downvi:
	$(COMPOSE) down -v --remove-orphans --rmi local || true

# Backward-compatible aliases.
down-stack-volumes: downv

down-stack-volumes-images: downvi

# Remove containers and project volumes, including orphaned services.
clean:
	$(MAKE) downv

# Remove local image tagged for this repo (ignore when absent).
rmimg:
	docker image rm -f fbd-miner:latest 2>/dev/null || true

# Backward-compatible alias.
remove-project-image: rmimg

# Perform a repo-scoped reset: remove stack resources and local project image.
reset-docker:
	@echo "Repo-only cleanup: removing this compose stack, its volumes, and local images built for this project."
	$(MAKE) downvi
	$(MAKE) rmimg

# Perform a global Docker cleanup (all unused containers, images, networks, volumes, cache).
prunator:
	@echo "Global Docker prune: removing all unused Docker resources on this host."
	docker system prune -a --volumes -f

# Run the full cleanup flow: project teardown + repo cleanup + global prune.
wipe-all:
	@echo "Full cleanup flow: running repo cleanup (reset-docker) and then global prunator."
	$(MAKE) reset-docker
	$(MAKE) prunator


# ============================================================================
# TARGETS: HELP
# ============================================================================

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Lifecycle"
	@echo "  up, down, restart, build, build-base, logs, ps, config, pull, clean, reset-docker, prunator, wipe-all"
	@echo "  build-base            - build reusable Swift/Ubuntu dependency image from src/ubuswift"
	@echo "  reset-docker          - repo-only cleanup (stack, volumes, local project images)"
	@echo "  prunator              - global Docker prune on this host"
	@echo "  wipe-all              - full flow: down + repo cleanup + prunator"
	@echo ""
	@echo "Blockchain (fbdctl with API key from container env)"
	@echo "  chaininfo             - getblockchaininfo"
	@echo "  blockcount            - getblockcount"
	@echo "  bestblockhash         - getbestblockhash"
	@echo "  blockhash             - getblockhash HEIGHT=<n>"
	@echo "  blockheader           - getblockheader BLOCK=<height|hash>"
	@echo "  block                 - getblock BLOCK=<height|hash> VERBOSE=<true|false>"
	@echo "  mempool               - getmempoolinfo"
	@echo "  network               - getnetworkinfo"
	@echo "  peers                 - getpeerinfo"
	@echo "  mining                - getmininginfo"
	@echo "  stop-node             - stop"
	@echo "  ctl                   - fbdctl --api-key $$API_KEY <ARGS>"
	@echo "                          Example: make ctl ARGS='getblockhash 100'"
	@echo ""
	@echo "Wallet (wallet taken from .env: WALLET=$(WALLET))"
	@echo "  wallets               - listwallets"
	@echo "  wallet-info           - --wallet $(WALLET) getwalletinfo"
	@echo "  wallet-balance        - --wallet $(WALLET) getbalance"
	@echo "  wallet-address        - --wallet $(WALLET) getnewaddress"
	@echo "  wallet-change         - --wallet $(WALLET) getchangeaddress"
	@echo "  wallet-unspent        - --wallet $(WALLET) listunspent"
	@echo "  wallet-addresses      - --wallet $(WALLET) listaddresses"
	@echo "  wallet-txs            - --wallet $(WALLET) listtransactions COUNT=<n> OFFSET=<n>"
	@echo "  wallet-actions        - --wallet $(WALLET) getwalletactions"
	@echo "  wallet-rescan         - --wallet $(WALLET) rescanwallet [FROM_HEIGHT=<n>]"
	@echo "  rescan-progress       - --wallet $(WALLET) getrescanprogress"
	@echo "  import-wallet         - interactive createwallet (asks for wallet name and 24 words)"
	@echo "  recover-wallet        - restorewallet RECOVER_NAME=<name> BACKUP_PATH=<path.json>"
	@echo "  recover               - alias of recover-wallet"
	@echo ""
	@echo "Raw JSON-RPC (curl inside container)"
	@echo "  rpc METHOD=<name> PARAMS=<json-array>"
	@echo "  Example: make rpc METHOD=getblockhash PARAMS='[100]'"


# ============================================================================
# TARGETS: BLOCKCHAIN (FBDCTL)
# ============================================================================

chaininfo:
	$(call run-fbdctl,getblockchaininfo)

blockcount:
	$(call run-fbdctl,getblockcount)

bestblockhash:
	$(call run-fbdctl,getbestblockhash)

blockhash:
	$(call run-fbdctl,getblockhash $(HEIGHT))

blockheader:
	$(call run-fbdctl,getblockheader $(BLOCK))

block:
	$(call run-fbdctl,getblock $(BLOCK) $(VERBOSE))

mempool:
	$(call run-fbdctl,getmempoolinfo)

network:
	$(call run-fbdctl,getnetworkinfo)

peers:
	$(call run-fbdctl,getpeerinfo)

mining:
	$(call run-fbdctl,getmininginfo)

stop-node:
	$(call run-fbdctl,stop)


# ============================================================================
# TARGETS: WALLET (FBDCTL --wallet)
# ============================================================================

wallets:
	$(call run-fbdctl,listwallets)

wallet-info:
	$(call run-wallet,getwalletinfo)

wallet-balance:
	$(call run-wallet,getbalance)

wallet-address:
	$(call run-wallet,getnewaddress)

wallet-change:
	$(call run-wallet,getchangeaddress)

wallet-unspent:
	$(call run-wallet,listunspent)

wallet-addresses:
	$(call run-wallet,listaddresses)

wallet-txs:
	$(call run-wallet,listtransactions $(COUNT) $(OFFSET))

wallet-actions:
	$(call run-wallet,getwalletactions)

wallet-rescan:
	@if [ -n "$(strip $(FROM_HEIGHT))" ]; then \
		$(call run-wallet,rescanwallet $(FROM_HEIGHT)); \
	else \
		$(call run-wallet,rescanwallet); \
	fi

rescan-progress:
	$(call run-wallet,getrescanprogress)

import-wallet:
	@set -eu; \
	printf "Wallet name: "; \
	IFS= read -r wallet_name; \
	printf "24-word mnemonic: "; \
	IFS= read -r mnemonic; \
	if [ -z "$$wallet_name" ] || [ -z "$$mnemonic" ]; then \
		echo "Wallet name and mnemonic are required."; \
		exit 1; \
	fi; \
	word_count=$$(printf '%s\n' "$$mnemonic" | wc -w | tr -d '[:space:]'); \
	if [ "$$word_count" -ne 24 ]; then \
		echo "MNEMONIC must contain exactly 24 words (got $$word_count)."; \
		exit 1; \
	fi; \
	$(COMPOSE) exec \
		-e WALLET_NAME="$$wallet_name" \
		-e WALLET_MNEMONIC="$$mnemonic" \
		$(SERVICE) $(SHELL_CMD) '$(FBDCTL_BASE) createwallet "$$WALLET_NAME" "$$WALLET_MNEMONIC"'

recover-wallet:
	@if [ -z "$(strip $(RECOVER_NAME))" ] || [ -z "$(strip $(BACKUP_PATH))" ]; then \
		echo "RECOVER_NAME and BACKUP_PATH are required. Example:"; \
		echo "  make recover-wallet RECOVER_NAME=recovered BACKUP_PATH=/root/backup.json"; \
		exit 1; \
	fi
	$(call run-fbdctl,restorewallet "$(RECOVER_NAME)" "$(BACKUP_PATH)")

recover: recover-wallet


# ============================================================================
# TARGETS: GENERIC COMMANDS
# ============================================================================

ctl:
	$(call run-fbdctl,$(ARGS))

rpc:
	$(EXEC) 'curl -s "http://$(RPC_HOST):$(RPC_PORT)/" -X POST -u "x:$$API_KEY" -H "content-type: application/json" -d "{\"method\":\"$(METHOD)\",\"params\":$(PARAMS),\"id\":1}"'


# ============================================================================
# SPECIAL TARGETS
# ============================================================================

.PHONY: up down restart build build-base logs ps config pull downv downvi down-stack-volumes down-stack-volumes-images clean rmimg remove-project-image reset-docker prunator wipe-all help chaininfo blockcount bestblockhash blockhash blockheader block mempool network peers mining stop-node wallets wallet-info wallet-balance wallet-address wallet-change wallet-unspent wallet-addresses wallet-txs wallet-actions wallet-rescan rescan-progress import-wallet recover-wallet recover ctl rpc