#!/usr/bin/env bash

source ./common.sh

install_aws_ocs
run_ocs_fio_benchmark
wait_for_fio_benchmark
#run_comparsion TODO no comarison yet

log "OCS Fio benchmark complete"

delete_benchmark