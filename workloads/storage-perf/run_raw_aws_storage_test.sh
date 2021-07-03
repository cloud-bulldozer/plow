#!/usr/bin/env bash

source ./common.sh

create_raw_aws_storageclass
run_raw_fio_benchmark
wait_for_benchmark

log "Raw GP2 Fio benchmark complete"

delete_benchmark
