#!/bin/bash

# get parent directory
path="${BASH_SOURCE[0]}"
while [ -h "$path" ] ; do
    linkpath="$(readlink "$path")"
    if [[ "$linkpath" != /* ]] ; then
	path="$(dirname "$path")/$linkpath"
    else
	path="$linkpath"
    fi
done
export MUC_R_HOME="$(cd -P "$(dirname "$path")/.." >/dev/null 2>&1 && pwd)"

export REDISHOST="${SLURMD_NODENAME}opa.sng.lrz.de"  # need to hardcode this :-/

. "$MUC_R_HOME/scheduling/common.sh"

check_env REDISHOST REDISPORT REDISPW SHARDS CURSHARD

echo "${REDISHOST}:${REDISPORT}:${REDISPW}" > "REDISINFO_${CURSHARD}.TMP" || exit 1
mv "REDISINFO_${CURSHARD}.TMP" "REDISINFO_${CURSHARD}" || exit 1

mkdir -p "REDIS/REDISINSTANCE_${CURSHARD}/REDISDIR"

cd "REDIS/REDISINSTANCE_${CURSHARD}/REDISDIR"

# need to sleep 60 here to make sure redis exists when `pidof` runs
( top -bu `whoami` >> TOPOUT.txt ) &

cat <<EOF | Rscript - | redis-server -
cat(sprintf('
protected-mode no
save ""

tcp-backlog 511
tcp-backlog 7000
timeout 0
tcp-keepalive 300
daemonize no
supervised no
loglevel notice
logfile ""
databases 1

maxclients 150000

appendonly no

appendfsync no

requirepass \'%s\'

port \'%s\'

', Sys.getenv("REDISPW"), Sys.getenv("REDISPORT")))
EOF

kill $(jobs -p)

if ! [ -z "$SLURM_JOB_ID" ] ; then
    # if redis fails and runredis.sh was run in a SLURM job
    # (i.e. not launched via drainredis_manual.sh) we abort
    # the job.
    echo "Redis closed, killing job."
    scancel "$SLURM_JOB_ID"
fi
