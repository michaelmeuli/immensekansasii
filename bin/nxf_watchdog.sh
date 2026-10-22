#!/bin/bash
#
# Stall watchdog for the Nextflow coordinator, sourced by submit_to_cluster.sh.
#
# On S3IT the coordinator sometimes goes idle with work left: no worker jobs, no task
# submitted or finished for hours, but the process never ends. The batch then holds the
# run dir (and the whole afterany chain) until the 24 h Slurm limit kills it, which also
# corrupts .nextflow/cache.
#
# nxf_watchdog <nextflow_pid> <launch_dir>   (run in the background)
#   every NXF_WATCH_INTERVAL s (default 600) check that
#     - the newest trace-*.txt (written whenever a task ends) is older than
#       NXF_STALL_MINUTES (default 180; longest normal task is ~2 h unicycler), and
#     - no Slurm job of this user has its work dir below <launch_dir>/work.
#   If both hold: write <launch_dir>/pipeline.stalled, SIGTERM nextflow (graceful, closes
#   the cache), SIGKILL after NXF_KILL_GRACE s (default 600) if it is still alive.
nxf_watchdog() {
    local pid=$1 dir=$2
    local interval=${NXF_WATCH_INTERVAL:-600}
    local stall_s=$(( ${NXF_STALL_MINUTES:-180} * 60 ))
    local grace=${NXF_KILL_GRACE:-600}
    local started now last newest workers

    started=$(date +%s)
    while kill -0 "$pid" 2>/dev/null; do
        sleep "$interval"
        kill -0 "$pid" 2>/dev/null || return 0
        now=$(date +%s)
        newest=$(ls -t "$dir"/trace-*.txt 2>/dev/null | head -1)
        last=$started
        [ -n "$newest" ] && [ "$(stat -c %Y "$newest")" -gt "$last" ] && last=$(stat -c %Y "$newest")
        [ $(( now - last )) -ge "$stall_s" ] || continue
        workers=$(squeue -h -u "$USER" -o %Z 2>/dev/null | grep -c "^$dir/work" || true)
        [ "$workers" -eq 0 ] || continue
        echo "WATCHDOG: no task activity for $(( (now - last) / 60 )) min and no worker jobs, stopping nextflow (pid $pid)"
        date > "$dir/pipeline.stalled"
        kill -TERM "$pid" 2>/dev/null
        local waited=0
        while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$grace" ]; do
            sleep 10; waited=$(( waited + 10 ))
        done
        if kill -0 "$pid" 2>/dev/null; then
            echo "WATCHDOG: nextflow still alive after ${grace}s, SIGKILL (cache may be corrupted, move .nextflow/cache aside before resuming)"
            kill -KILL "$pid" 2>/dev/null
        fi
        return 0
    done
}
