
# Common
export OPERATOR_REPO=${OPERATOR_REPO:-https://github.com/cloud-bulldozer/benchmark-operator.git}
export OPERATOR_BRANCH=${OPERATOR_BRANCH:-master}
export QPS=${QPS:-20}
export BURST=${BURST:-20}
export POD_READY_TIMEOUT=${POD_READY_TIMEOUT:-1200}
export WORKLOAD_NODE=${WORKLOAD_NODE:-'{"node-role.kubernetes.io/worker": ""}'}
export CERBERUS_URL=${CERBERUS_URL}
export STEP_SIZE=${STEP_SIZE:-30s}
export ES_SERVER=${ES_SERVER:-https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443}
export ES_INDEX=${ES_INDEX:-ripsaw-kube-burner}
export PROM_URL=${PROM_URL:-https://prometheus-k8s.openshift-monitoring.svc.cluster.local:9091}
export METADATA_COLLECTION=${METADATA_COLLECTION:-true}
export JOB_TIMEOUT=${JOB_TIMEOUT:-14400}
export LOG_STREAMING=${LOG_STREAMING:-true}
export CLEANUP=${CLEANUP:-true}
export CLEANUP_WHEN_FINISH=${CLEANUP_WHEN_FINISH:-false}
export LOG_LEVEL=${LOG_LEVEL:-info}

# Remote configuration
export REMOTE_CONFIG=""
export REMOTE_METRIC_PROFILE=""
export REMOTE_ALERT_PROFILE=""

export APP_SUBNAME=""
export APP=""

# Concurrent Build Specific
export BUILD_IMAGE_STREAM=""
export SOURCE_STRAT_ENV=""
export SOURCE_STRAT_FROM=""
export POST_COMMIT_SCRIPT=""
export SOURCE_STRAT_FROM_VERSION=""

export BUILD_IMAGE=""
export GIT_URL=""