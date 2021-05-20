OPERATOR_REPO=${OPERATOR_REPO:=https://github.com/cloud-bulldozer/benchmark-operator.git}
OPERATOR_BRANCH=${OPERATOR_BRANCH:=master}
CURL_BODY='{"_source": false, "aggs": {"max-fsync-lat-99th": {"max": {"field": "fio.sync.lat_ns.percentile.99.000000"}}}}'

export TERM=screen-256color
export METADATA_COLLECTION=${METADATA_COLLECTION:-true}
export ES_SERVER=${ES_SERVER:-https://search-cloud-perf-lqrf3jjtaqo7727m7ynd2xyt4y.us-west-2.es.amazonaws.com}
export ES_INDEX=${ES_INDEX:-ripsaw-fio-results}
export TOLERATIONS='[{"key": "node-role.kubernetes.io/master", "effect": "NoSchedule", "operator": "Exists"}]'
export NODE_SELECTOR='{"node-role.kubernetes.io/master": ""}'
export LOG_STREAMING=${LOG_STREAMING:-true}
export CLOUD_NAME=${CLOUD_NAME:-test_cloud}
export TEST_USER=${TEST_USER:-test_cloud-etcd}
export FILE_SIZE=${FILE_SIZE:-50MiB}
export SAMPLES=${SAMPLES:-5}
export LATENCY_TH=${LATENCY_TH:-10000000}

bold=$(tput bold)
normal=$(tput sgr0)

log() {
  echo ${bold}$(date "+%d-%m-%YT%H:%M:%S") ${@}${normal}
}

deploy_operator() {
  log "Cloning benchmark-operator from ${OPERATOR_REPO}"
  rm -rf benchmark-operator
  git clone --single-branch --branch ${OPERATOR_BRANCH} ${OPERATOR_REPO} --depth 1
  log "Deploying benchmark-operator"
  oc apply -f benchmark-operator/resources/crds/ripsaw_v1alpha1_ripsaw_crd.yaml
  oc apply -f benchmark-operator/resources/namespace.yaml
  oc apply -f benchmark-operator/resources/backpack_role.yaml
  oc apply -f benchmark-operator/deploy
  oc adm policy add-scc-to-user -n my-ripsaw privileged -z benchmark-operator
  oc adm policy add-scc-to-user -n my-ripsaw privileged -z backpack-view
  oc apply -f benchmark-operator/resources/operator.yaml
  log "Waiting for benchmark-operator to be available"
  oc wait --for=condition=available -n my-ripsaw deployment/benchmark-operator --timeout=180s
}

deploy_workload() {
  oc delete benchmark -n my-ripsaw etcd-fio --ignore-not-found
  log "Deploying FIO benchmark"
  envsubst < fio-etcd-crd.yaml | oc apply -f -
}

wait_for_benchmark() {
  rc=0
  log "Waiting for FIO job to be created"
  until oc get benchmark -n my-ripsaw etcd-fio -o jsonpath="{.status.state}" | grep -q Running; do
    sleep 1
  done
  log "Waiting for etcd-fio job to start"
  suuid=$(oc get benchmark -n my-ripsaw etcd-fio  -o jsonpath="{.status.suuid}")
  until oc get pod -n my-ripsaw -l job-name=fio-client-${suuid} --ignore-not-found -o jsonpath="{.items[*].status.phase}" | grep -q Running; do
    sleep 1
  done
  log "Benchmark in progress"
  until oc get benchmark -n my-ripsaw etcd-fio -o jsonpath="{.status.state}" | grep -Eq "Complete|Failed"; do
    if [[ ${LOG_STREAMING} == "true" ]]; then
      oc logs -n my-ripsaw -f -l job-name=fio-client-${suuid}
      sleep 20
    fi
    sleep 1
  done
  uuid=$(oc get benchmark -n my-ripsaw etcd-fio -o jsonpath="{.status.uuid}")
}


verify_fsync_latency() {
  log "Verifying max fsync latency < ${LATENCY_TH} ns"
  fsync_lat=$(curl -Ss ${ES_SERVER}/${ES_INDEX}/_search?q=uuid:${uuid} -H "Content-Type: application/json" -d "${CURL_BODY}" | python -c 'import sys,json;print(int(json.loads(sys.stdin.read())["aggregations"]["max-fsync-lat-99th"]["value"]))')
  log "Max observed latency across ${SAMPLES} samples: ${fsync_lat} ns"
  if [[ ${fsync_lat} -gt ${LATENCY_TH} ]]; then
    log "FSync latency greater than the configured threshold: ${latency_th} ns"
    rc=1
  fi
}
