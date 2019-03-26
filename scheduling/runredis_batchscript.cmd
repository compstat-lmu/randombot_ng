#!/bin/bash
#SBATCH --mail-type=end
#SBATCH --mem=MaxMemPerNode
#SBATCH --export=ALL
#SBATCH --mail-user=martin.binder@stat.uni-muenchen.de
#SBATCH --time=48:00:00
#SBATCH --ntasks=1
#SBATCH --nodes=1


if ! [ -d "$MUC_R_HOME" ] ; then
    echo "MUC_R_HOME Not a directory: $MUC_R_HOME"
    exit 101
fi

export REDISHOST="${HOST}"

export REDISPW="$(head -c 128 /dev/urandom | sha1sum -b - | cut -c -40)"

. "$MUC_R_HOME/scheduling/common.sh"

check_env REDISHOST REDISPORT REDISPW

echo "${REDISHOST}:${REDISPORT}:${REDISPW}" > REDISINFO || exit 1

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


