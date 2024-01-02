#!/usr/bin/env zsh
N=${1:-10}
SUM=0
for n in {1..$N}; do
echo Running zsh $n
(time zsh -i -c exit) 2>&1 | awk '{print $11}' | read ttl
SUM=$(echo "${SUM} + ${ttl}" | bc)
done
echo
AVG=$(echo "scale=3; ${SUM}/${N}" | bc)
echo "Average: ${AVG}seconds"