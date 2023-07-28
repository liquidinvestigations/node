#!/bin/bash -e
(
echo "Thread count, per container for machine `hostname`:"
docker ps --format 'table {{.Names}}' | tail -n +2 | sort |  xargs -P1 -I{} bash -c 'echo $(docker top {} -eLf | wc -l) {} ;' | sort -nr > /tmp/proc.txt
echo
cat /tmp/proc.txt | head -n 15
echo

TOTAL="$(cat /tmp/proc.txt | cut -f1 -d' ' |  paste -sd+ | bc)"
COUNT="$(cat /tmp/proc.txt | wc -l)"
echo "Thread count, All $COUNT Docker Containers: $TOTAL"
echo "Thread count, Entire Machine: $(ps -eLf | wc -l)"
)
