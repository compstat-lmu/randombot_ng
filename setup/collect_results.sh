#!/bin/bash

rm fallout 2>/dev/null
rm incomplete 2>/dev/null

collect_file() {
  rm "fallout_${2}" 2>/dev/null
  rm "incomplete_${2}" 2>/dev/null
  grep eval_redis.R "$1" | cut -d ':' -f 1 | sort | uniq > threads
  ( echo "dataset learner workerno startdate starttime nodename stepid invocation shard seed t.getseed t.sample evaldate evaltime point pointno t.eval t.sendres wdkill iter timeout walltime kernelseconds userseconds cpupercent memkb exitstatus" ;
    cat threads | \
    while read t ; do
      grep -F "$t" "$1" | \
        cut -d ' ' -f 2- | \
        grep -v '.*runscript.sh started memory [0-9]*M cmdline ' | \
        grep -v '^----\[[^]]*\] eval_redis.R$' | \
        sed 's/^----\[\([-0-9]*\)_\([:0-9]*\),\([^,]*\),\([0-9]*\),\([0-9]*\)\] hash 0x[a-f0-9]* --> host index \([0-9]*\) out of [0-9]*$/#\1 \2 \3 \4 \5 \6/' | \
        grep -v '^----\[[^]]*\] Connecting to redis [-_0-9a-zA-Z.:]*$' | \
        sed 's/^----\[[^]]*\] [-0-9]* [:0-9]* Evaluating seed \([0-9]*\)$/#\1/' | \
        sed 's/^----\[[^]]*\] [-0-9]* [:0-9]* Timing (setup): seed retrieve \[s\]: \([-+e0-9.]*\), sample point \[s\]: \([-+e0-9.]*\)$/#\1 \2/' | \
        sed 's/^----\[[^]]*\] \([-0-9]* [:0-9]*\) Evaluating point \(.*\)/#\1 \2/' | \
        sed 's/^----\[[^]]*\] [-0-9]* [:0-9]* Timing (eval \([0-9]*\)): Evaluation \[s\]: \([-+e0-9.]*\), Sending result \[s\]: \([-+e0-9.]*\)$/#\1 \2 \3 FALSE NA NA/' | \
        grep -v '^----\[[^]]*\] [-0-9]* [:0-9]* Done evaluating seed [0-9]*$' | \
        sed "s|^KILLING [0-9]* WAU WAU ('iter: \\([0-9]*\\), t/o: \\([-+e.0-9]*\\)')\$|#NA NA NA TRUE \\1 \\2|" | \
        sed 's/^----\[[^]]*\] USAGE: E \([:0-9.]*\) K \([0-9.]*\) U \([0-9.]*\) P \([0-9.]*\)% M \([0-9.]*\) kB O [0-9.]*$/#\1 \2 \3 \4 \5/' | \
        sed 's/^----\[[^]]*\]  exited with status \([0-9]*\)$/#\1#/' | \
        grep -v '^!!--- \(BEGIN Evaluating Point:\|DONE Evaluating Point:\|EXITING eval function of point:\) ' | \
      tee >(grep -v '^#' | sed "s#^#$t #" >> "fallout_${2}") | \
      grep '^#' | sed 's/^#//' | \
      tr $'\n' ' ' | tr '#' $'\n' | sed 's/^ //' | \
      sed 's/\(\([^ ]\+ \)\{5\}\)137$/NA NA NA FALSE NA NA \1137/' | \
      sed 's/^\(\([^ ]\+ \)\{9\}\)\(\([^ ]\+ \)\{9\}\)\(\([^ ]\+ \)\{9\}\)\(\([^ ]\+ \)\{5\}[^ ]\+\)$/\1\3\7\n\1\5\7/' | \
      tee >(grep -v '^\([^ ]\+ \)\{23\}[^ ]\+$' | sed "s#^#$t #" >> "incomplete_${2}") | \
      grep '^\([^ ]\+ \)\{23\}[^ ]\+$' | \
      sed "s#^#$t #" | sed "s#\[\([^,]*\),\([^,]*\)\]\[\([0-9]*\)\]#\1 \2 \3#"
    done ) | awk '{ print $6,$7,$1,$2,$3,$8,$16,$4,$5,$13,$14,$11,$18,$12,$17,$22,$23,$24,$25,$26,$19,$20,$21,$9,$10,$15,$27 }'
} 

if ! [ -d OUTPUT ] ; then
  echo "Run in redis result dir"
fi

mkdir -p TABLE
cd TABLE
for f in ../OUTPUT/SLURMOUT/slurm-*.out ; do
  collect_file "$f" "${f##*/*-}" > "runtable_${f##*/*-}"
done

