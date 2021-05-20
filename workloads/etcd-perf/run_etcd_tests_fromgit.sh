#!/usr/bin/bash -eu

set -eu

. common.sh

deploy_operator
deploy_workload
wait_for_benchmark
if [[ ${rc} == 1 ]] ; then
  log "Workload failed"
  exit ${rc}
fi
verify_fsync_latency
exit ${rc}
