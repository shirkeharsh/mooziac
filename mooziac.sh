#!/bin/bash
# ==============================================================================
# Mooziac Unified CLI & Interactive Agent Wizard
# Usage:
#   ./mooziac.sh            # Launches interactive subsystem, mode, and prompt wizard
#   ./mooziac.sh build      # Runs release build pipeline (build_app.sh)
#   ./mooziac.sh prompt ... # Generates token-optimized prompt for agent
#   ./mooziac.sh brain ...  # Forwards command to ./brain
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ "$#" -eq 0 ]; then
    # No args: Launch interactive prompt and brain wizard
    python3 "$SCRIPT_DIR/brain" interactive
elif [ "$1" == "build" ]; then
    shift
    exec "$SCRIPT_DIR/build_app.sh" "$@"
elif [ "$1" == "prompt" ]; then
    shift
    python3 "$SCRIPT_DIR/brain" prompt "$@"
elif [ "$1" == "brain" ]; then
    shift
    python3 "$SCRIPT_DIR/brain" "$@"
else
    # Forward any custom build args to build_app.sh
    exec "$SCRIPT_DIR/build_app.sh" "$@"
fi
