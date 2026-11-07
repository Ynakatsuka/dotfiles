#!/usr/bin/env zsh
# Print the average interactive zsh startup time over N runs (default 10).
zmodload zsh/datetime
local -i runs=${1:-10} i
local -F start total=0
for (( i = 1; i <= runs; i++ )); do
  start=$EPOCHREALTIME
  zsh -i -c exit
  (( total += EPOCHREALTIME - start ))
done
printf 'Average over %d runs: %.1f ms\n' $runs $(( total / runs * 1000 ))
