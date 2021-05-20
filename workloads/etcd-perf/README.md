# Etcd e2e benchmark

The purpose of this benchmark is to run a FIO workload to verify the host's disk meets the I/O latency requirements to run etcd safely.
This test uses FIO to trigger an i/o benchmark that emulates an etcd workload, this is done by running several FIO samples using sync as ioengine, fdatasync and a block size of 2300 bytes.

By default the FIO server pod is executed in one of the master nodes thanks to the nodeSelector and tolerations parameters, in addition, the this pod mounts a *hostPath* volume avoid the *overlayfs* layer. 

Once the benchmark is finished, the highest latency obtained from the executed FIO samples is compared with the latency threshold configured by *LATENCY_TH* (10 ms by default), exiting with RC=1 if higher.
 
## Environment variables

All scripts can be tweaked with the following environment variables:

| Variable             | Description                         | Default |
|----------------------|-------------------------------------|---------|
| **ES_SERVER**        | Elastic search endpoint         | https://search-cloud-perf-lqrf3jjtaqo7727m7ynd2xyt4y.us-west-2.es.amazonaws.com|
| **ES_INDEX**         | Elastic search index            | ripsaw-fio-results |
| **METADATA_COLLECTION**    | Enable metadata collection | true |
| **LOG_STREAMING**    | Enable log streaming of FIO client pod | true |
| **TOLERATIONS**      | FIO server pod tolerations | `[{"key": "node-role.kubernetes.io/master", "effect": "NoSchedule", "operator": "Exists"}]` |
| **NODE_SELECTOR**    | FIO server pod node selector | `{"node-role.kubernetes.io/master": ""}` |
| **CLOUD_NAME**       | cloud_name field | test_cloud |
| **TEST_USER**        | test_user field | test_cloud-etcd |
| **FILE_SIZE**        | FIO File size | 50MiB |
| **SAMPLES**          | FIO samples | 5 |
| **LATENCY_TH**       | Latency threshold in ns | 10000000 |
| **OPERATOR_REPO**    | benchmark-operator repo   | https://github.com/cloud-bulldozer/benchmark-operator.git |
| **OPERATOR_BRANCH**  | benchmark-operator branch                     | master  |

**Note**: You can use basic authentication when indexing in ES using the notation `http(s)://[username]:[password]@[address]` in **ES_SERVER**.

## Configuration file

An [env.sh](env.sh) file is provided with all the available configuration parameters.

