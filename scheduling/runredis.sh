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

export REDISPW="$(head -c 128 /dev/urandom | sha1sum -b - | cut -c -40)"

. "$MUC_R_HOME/scheduling/common.sh"

check_env REDISHOST REDISPORT REDISPW

echo "${REDISHOST}:${REDISPORT}:${REDISPW}" > REDISINFO.TMP || exit 1
mv REDISINFO.TMP REDISINFO || exit 1

mkdir -p REDISINSTANCE/REDISDIR

cd REDISINSTANCE/REDISDIR

cat <<EOF | Rscript - | redis-server -
cat(sprintf('
protected-mode no
save 6000 10

rdbcompression yes
tcp-backlog 511
tcp-backlog 7000
timeout 0
tcp-keepalive 300
daemonize no
supervised no
loglevel notice
logfile ""
databases 1
stop-writes-on-bgsave-error yes
rdbchecksum yes
dbfilename "dump.rdb"

appendonly yes
appendfilename "appendonly.aof"

appendfsync no

requirepass \'%s\'

port \'%s\'

', Sys.getenv("REDISPW"), Sys.getenv("REDISPORT")))
EOF

if ! [ -z "$SLURM_JOB_ID" ] ; then
    # if redis fails and runredis.sh was run in a SLURM job
    # (i.e. not launched via drainredis_manual.sh) we abort
    # the job.
    echo "Redis closed, killing job."
    scancel "$SLURM_JOB_ID"
fi
