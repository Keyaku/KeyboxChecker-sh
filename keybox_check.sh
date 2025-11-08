#!/usr/bin/env bash

set -euo pipefail

# General configuration
typeset -r THIS="$(readlink -f "$0")"
typeset -r THIS_SCRIPT="${THIS//*\/}"
typeset -r THIS_NAME="${THIS_SCRIPT%%.sh}"
typeset -r THIS_DIR="$(dirname "$THIS")"
typeset -r DIR_pwd="$PWD"
typeset -r CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.local/cache}"/$THIS_NAME

. utils.sh

### CONSTANTS
typeset -ri NUMARGS=1
typeset -r STATUS_JSON="${CACHE_DIR}"/status.json

### VARIABLES

verbosity=0
file_keybox=""

### FUNCTIONS

function usage {
	local -r USAGE=(
		"Usage: $0 [OPTION] FILE"
		"Checks given keybox if it was revoked by Google"
		""
		"\t[-h|--help] : Print this help message"
		"\t[-v] / [-q] : Increase / Decrease verbosity"
	)

	>&2 print -l $USAGE
	exit ${1:-0}
}

function check_env {
	local -rA REQ_CMDS=(
		[openssl]=openssl
		[sed]=sed
		[xmllint]="libxml2-utils"
	)
	local missing=()
	local cmd
	for cmd in ${!REQ_CMDS[@]}; do
		if ! command -v $cmd &>/dev/null; then
			# if using Termux, install required packages
			if is_termux; then
				echo "Installing dependencies..."
				apt update
				apt install --auto-remove -y ${REQ_CMDS[@]}
				break
			else
				missing+=("$cmd")
			fi
		fi
	done

	if (( 0 < ${#missing} )); then
		printf '%s\n' "The following packages are missing:"
		printf '\t- %s\n' ${missing[@]}
	fi
	(( 0 == ${#missing} ))
}

function parse_args {
	(( 0 < $# )) || {
		echo "At least 1 argument required, $# given"
		exit 1
	}

	while (( $# )); do
		# FIXME: Bash sucks. I must find a way to parse arguments better than this ugly, amateur-ish disaster.
		case "$1" in
		-h|--help) usage ;;
		-v) ((verbosity++)) ;;
		*)
			if [[ -f "$1" ]]; then
				if [[ "$file_keybox" ]]; then
					echo "Overriding keybox to analyze: $1"
				fi
				file_keybox="$1"
			else
				echo "Invalid argument: '$1'"
				return 1
			fi
		;;
		esac

		shift
	done
}

function check_args {
	if [[ -z "$file_keybox" ]]; then
		echo "Argument required: keybox to analyze (e.g. keybox.xml)"
		return 1
	fi
}

function check_cert {
	(( 2 == $# )) || exit 64
	local -i cert_idx=$1
	local cert_file="$2"
	# xmllint --xpath "string((//CertificateChain/Certificate)[$cert_idx])" "$cert_file" | sed -E 's/^\s+//g' >/dev/null || exit 64
	local cert="$(xmllint --xpath "string((//CertificateChain/Certificate)[$cert_idx])" "$cert_file" | sed -E 's/^\s+//g')"
	# echo "$cert" | openssl x509 -noout -serial >/dev/null || exit 64
	local serial="$(echo "$cert" | openssl x509 -noout -serial | sed 's/serial=//' | to_lower)"
	(( 0 < $verbosity )) && echo "serial: $serial"
	! grep -o "\b$serial\b" "$STATUS_JSON"
}

### MAIN

parse_args $@ || exit 1
set --
check_args || exit 1

[[ -d "${CACHE_DIR}" ]] || mkdir -p "${CACHE_DIR}"
# TODO: Download either if requested by user, or if file is too old
if [[ ! -f "$STATUS_JSON" ]]; then
	(( 0 < $verbosity )) && echo "Fetching latest status.json from Google APIs..."
	curl -H 'Cache-Control: no-cache' https://android.googleapis.com/attestation/status -o "$STATUS_JSON" || exit 1
fi

typeset -i num_certs=$(xmllint --xpath "string(//CertificateChain/NumberOfCertificates)" "$file_keybox")
(( 0 < $num_certs )) || {
	echo "Problem while getting number of certificates"
	exit 1
}

for ((idx=1; idx <= num_certs; idx++)); do
	(( 0 < $verbosity )) && echo "Checking certificate #$idx from keybox..."
	check_cert $idx "$file_keybox" || {
		echo "Certificate #$idx from keybox is revoked!"
		exit 1
	}
done
echo "Keybox is unrevoked! Keep it secret. Keep it safe."
