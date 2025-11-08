###
# Utilities and helpers to be used by main script
###

### CONSTANTS

# Colors for output
typeset -rA COLORS=(
	[RED]=31
	[GREEN]=32
	[YELLOW]=33
	[BLUE]=34
)
typeset -r NC="\033[0m"          ## Text Reset
for COLOR in ${!COLORS[@]}; do
	typeset -r $COLOR='\033[0;'${COLORS[$COLOR]}'m'  # Normal
	typeset -r B$COLOR='\033[1;'${COLORS[$COLOR]}'m' # Bold
	typeset -r I$COLOR='\033[3;'${COLORS[$COLOR]}'m' # Italic
	typeset -r U$COLOR='\033[4;'${COLORS[$COLOR]}'m' # Underline
done; unset COLOR


### FUNCTIONS

function is_termux {
	# FIXME: This is a blatantly stupid check. Develop a better (yet still lightweight) check.
	[[ -n "$TERMUX__PREFIX" ]] && [[ -d "$TERMUX__PREFIX" ]]
}

function to_lower {
	{ (( 0 < $# )) && echo "$*" || cat; } | tr '[:upper:]' '[:lower:]'
}
