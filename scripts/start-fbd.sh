#!/bin/sh
# Exit on error (-e) and on undefined variable usage (-u).
set -eu

# Detect OS to normalize Windows-style paths when needed.
OS_NAME="$(uname -s 2>/dev/null || echo unknown)"

# Validate required environment variables before starting the node.
: "${NETWORK:?NETWORK is required}"
: "${DATADIR:?DATADIR is required}"
: "${HOST:?HOST is required}"
: "${RPC_HOST:?RPC_HOST is required}"
: "${MINER_ADDRESS:?MINER_ADDRESS is required}"
: "${MINER_THREADS:?MINER_THREADS is required}"
: "${API_KEY:?API_KEY is required}"
: "${AGENT:?AGENT is required}"

# On Windows shells (Git Bash/Cygwin/MINGW), convert backslashes to slashes
# so the daemon receives stable paths.
NORMALIZED_DATADIR="${DATADIR}"
case "${OS_NAME}" in
  CYGWIN*|MINGW*|MSYS*)
    NORMALIZED_DATADIR="$(printf '%s' "${DATADIR}" | sed 's#\\#/#g')"
    ;;
esac

# Build arguments without line-continuation backslashes for portability.
set -- \
  --network "${NETWORK}" \
  --datadir "${NORMALIZED_DATADIR}" \
  --host "${HOST}" \
  --rpc-host "${RPC_HOST}" \
  --miner-address "${MINER_ADDRESS}" \
  --miner-threads "${MINER_THREADS}" \
  --api-key "${API_KEY}" \
  --agent "${AGENT}"

# Replace the shell process with fbd so signals are delivered directly.
exec fbd "$@"
