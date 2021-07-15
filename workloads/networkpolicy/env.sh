
# Common
export OPERATOR_REPO=https://github.com/mohit-sheth/ripsaw.git
export OPERATOR_BRANCH=np-multitenant
export POD_READY_TIMEOUT=1200
export QPS=100
export BURST=100
export WORKLOAD_NODE='{"node-role.kubernetes.io/workload": ""}'
export METADATA_COLLECTION=false
export CLEANUP=false
export CLEANUP_WHEN_FINISH=false
export LOG_LEVEL=debug
export LOG_STREAMING=true

export WORKLOAD=
export NS_LABEL=
export DEPLOY_INFRA=true
export DEPLOY_CLIENT=true
export DEPLOY_ADDITIONAL_PODS=true
export TEST_JOB_ITERATIONS=5
