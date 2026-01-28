#!/usr/bin/env bash

# for delta
declare current=()
declare previous=()

# define color for cpu bar and mem usage
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

# copy data from the current array into the previous array
copy-data() {
	previous=()

	local key value
	for key in "${!current[@]}"; do
		value=${current[$key]}
		previous[$key]=$value
	done
}
# reads data about cpu
read-proc() {
	local key user nice system idle iowait
	local irq softirq steal guest guest_nice


	local busy value
	while read -r key user nice system idle iowait \
		irq softirq steal guest guest_nice ; do
			#cores  only
			if [[ $key != cpu* ]]; then
				continue
			elif [[ $key == 'cpu' ]]; then
				continue
			fi
			num=${key#cpu}
			busy=$((user + nice + system + irq + softirq + steal + guest + nice))
			idle=$((idle + iowait))

			value="$busy $idle"

			current[$num]=$value
	done < /proc/stat
}
# convert kylobytes to gigabytes
kb_to_gb() {
	local kb=$1
	local gb10=$(( kb * 10 / 1000000 ))

	printf "%d.%d" $((gb10 / 10)) $((gb10 % 10))
}

# reads data about memory
read-mem() {
	read mem_total mem_available < <(
		awk ' 	/MemTotal/ { total=$2 }
			/MemAvailable/ { avail=$2 }
			END { print total, avail }
			' /proc/meminfo
	)
	mem_used=$((mem_total - mem_available))
}

print-bar() {
	local key=$1

	local busy1 idle1 busy2 idle2
	read -r busy1 idle1 <<< "${previous[$key]}"
	read -r busy2 idle2 <<< "${current[$key]}"

	local busy=$((busy2 - busy1))
	local idle=$((idle2 - idle1))
	local total=$((busy + idle))

	local usage=$((1000 * busy / total))

	local color
	# assigns color to the bar
	if (( usage < 500)); then
		color=$GREEN
	elif (( usage < 750 )); then
		color=$YELLOW
	else
		color=$RED
	fi


	local int=$(($usage /10))
	local frac=$((usage % 10))
	
	local perc=$int.$frac

	local bar_char='|'
	local empty_char=' '
	local length=60

	local num_bars=$((usage * length / 1000))

	local i
	local s='['
	for ((i = 0; i  < num_bars; i++)); do
		s+=$bar_char
	# due to bash not having flaot connect int and the fraction
	done
	for ((i = num_bars; i < length; i++)); do
		s+=$empty_char
	done
	s+=']'

	echo -e "${color}${s}${RESET} cpu$key $perc%"
}
# visualizes data of cpu usage
visualize-data() {
	for key in "${!current[@]}"; do
		print-bar "$key"
	done
	echo
}

# visualizes data of memory usage
visualize_data_mem() {
	local color percent
	# in case mem_total hasn't been collected yet
	(( mem_total > 0 )) || {
		printf "Memory: colleting data...\n"
		return
	}

	percent=$((mem_used * 100 / mem_total ))
	# assigns color to used memory text
	if (( percent < 50 )); then
		color=$GREEN
	elif (( percent < 75 )); then
		color=$YELLOW
	else
		 color=$RED
	fi

	printf "Total:	    %s GB\n" "$(kb_to_gb "$mem_total")"
	printf "Available:   %s GB\n" "$(kb_to_gb "$mem_available")"
	printf "Used:        %s%s%s GB\n" "$color" "$(kb_to_gb "$mem_used")" "$RESET"
}
# removes the TUI after stopping
cleanup() {
	printf '\e[?1049l' # disable alternate buffer
	printf '\e[?25h' # show the cursor
}

main() {
	read-proc # reads cpu data
	read-mem # reads memory data
	echo 'waiting for data...'
	#timeout
	sleep 1

	trap cleanup EXIT
	# makes it so the data doesn't just print but changes in one place
	printf '\e[?1049h' # enable alternate buffer
	printf '\e[?25l' # hide the cursor
	printf '\e[H' # move the cursor home

	local s
	local m

	while true; do
		copy-data
		read-proc
		read-mem
		s=$(visualize-data)
		m=$(visualize_data_mem)
		printf '\e[2J' # clear the entire screen
		printf '\e[H' # move the cursor home
		printf "%s\n\n%s\n" "$s" "$m" #prints cpu bars, 2 \n and memory info 
		sleep 1
	done
}

main "$@"
