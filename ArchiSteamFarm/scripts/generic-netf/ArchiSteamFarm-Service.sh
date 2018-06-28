#!/bin/bash
set -eu

CONFIG_PATH="config/ASF.json"

cd "$(dirname "$(readlink -f "$0")")"

SCRIPT_DIR="$(pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/${0}"

BINARY="${SCRIPT_DIR}/ArchiSteamFarm.exe"
BINARY_ARGS=()

PATH_NEXT=0

PARSE_ARG() {
	BINARY_ARGS+=("$1")

	case "$1" in
		--path) PATH_NEXT=1 ;;
		--path=*) cd "$(echo "$1" | cut -d '=' -f 2-)" ;;
		*)
			if [[ "$PATH_NEXT" -eq 1 ]]; then
				PATH_NEXT=0
				cd "$1"
			fi
	esac
}

if [[ -n "${ASF_ARGS-}" ]]; then
	for ARG in $ASF_ARGS; do
		if [[ -n "$ARG" ]]; then
			PARSE_ARG "$ARG"
		fi
	done
fi

for ARG in "$@"; do
	if [[ -n "$ARG" ]]; then
		PARSE_ARG "$ARG"
	fi
done

CONFIG_PATH="$(pwd)/${CONFIG_PATH}"

# Kill underlying ASF process on shell process exit
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM

if ! hash mono 2>/dev/null; then
	echo "ERROR: mono is not installed!"
	exit 1
fi

mono --version

while :; do
	if [[ -f "$CONFIG_PATH" ]] && grep -Eq '"Headless":\s+?true' "$CONFIG_PATH"; then
		# We're running ASF in headless mode so we don't need STDIN
		mono "${MONO_ARGS[@]-}" "$BINARY" "${BINARY_ARGS[@]-}" & # Start ASF in the background, trap will work properly due to non-blocking call
		wait $! # This will forward mono error code, set -e will abort the script if it's non-zero
	else
		# We're running ASF in non-headless mode, so we need STDIN to be operative
		mono "${MONO_ARGS[@]-}" "$BINARY" "${BINARY_ARGS[@]-}" # Start ASF in the foreground, trap sadly won't work until process exit
	fi

	chmod +x "$SCRIPT_PATH" # If ASF exited by itself, we need to ensure that our script is still set to +x after auto-update
	sleep 1
done
