
# Benchmark-operator
export METADATA_COLLECTION=true
export ES_SERVER=https://search-cloud-perf-lqrf3jjtaqo7727m7ynd2xyt4y.us-west-2.es.amazonaws.com
export ES_INDEX=ripsaw-fio-results
export TOLERATIONS='[{"key": "node-role.kubernetes.io/master", "effect": "NoSchedule", "operator": "Exists"}]'
export NODE_SELECTOR='{"node-role.kubernetes.io/master": ""}'
export CLOUD_NAME=test_cloud
export TEST_USER=test_cloud-etcd


# Workload 
export LOG_STREAMING=true
export FILE_SIZE=50MiB
export SAMPLES=5
export LATENCY_TH=10000000
