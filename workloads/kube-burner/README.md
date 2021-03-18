# Kube-burner e2e benchmarks

The purpose of these scripts is to run a kube-burner workload steered by ripsaw. There are 3 types of workloads at the moment:

- **`cluster-density`**
- **`node-density`**
- **`node-density-heavy`**
- **`max-namespaces`**
- **`max-services`**
- **`pod-density`**
- **`concurrent-builds`**

## Environment variables

All scripts can be tweaked with the following environment variables:

| Variable         | Description                         | Default |
|------------------|-------------------------------------|---------|
| **OPERATOR_REPO**              | benchmark-operator repo                     | https://github.com/cloud-bulldozer/benchmark-operator.git      |
| **OPERATOR_BRANCH**              | benchmark-operator branch                     | master      |
| **QPS**              | Queries/sec                     | 20      |
| **BURST**            | Burst queries                   | 20      |
| **ES_SERVER**        | Elastic search endpoint         | https://search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com:443 (You can disable indexing with `export ES_SERVER=""`)|
| **ES_INDEX**         | Elastic search index            | ripsaw-kube-burner|
| **PROM_URL**         | Prometheus endpoint         | https://prometheus-k8s.openshift-monitoring.svc.cluster.local:9091|
| **JOB_TIMEOUT**      | kube-burner's job timeout, in seconds      | 17500 |
| **POD_READY_TIMEOUT**| Timeout for kube-burner and benchmark-operator pods to be running | 1200 |
| **WORKLOAD_NODE**    | Workload node selector          | {"node-role.kubernetes.io/worker": ""} |
| **CERBERUS_URL**     | URL to check the health of the cluster using [Cerberus](https://github.com/openshift-scale/cerberus) | "" (don't check)|
| **STEP_SIZE**        | Prometheus step size, useful for long benchmarks | 30s|
| **METRICS_PROFILE**        | Metric profile that indicates what prometheus metrics kube-burner will collect, accepts __metrics.yaml__ or __metrics-aggregated.yaml__ | metrics.yaml for node-density workloads and metrics-aggregated.yaml for cluster-density workloads |
| **METADATA_COLLECTION**    | Enable metadata collection | true |
| **LOG_STREAMING**    | Enable log streaming of kube-burner pod | true |
| **CLEANUP**          | Delete old namespaces for the selected workload before starting benchmark | false |
| **CLEANUP_WHEN_FINISH** | Delete workload's namespaces after running it | false |
| **LOG_LEVEL**        | Kube-burner log level | info |

**Note**: You can use basic authentication for ES indexing using the notation `http(s)://[username]:[password]@[host]:[port]` in **ES_SERVER**.

### Cluster-density variables

The `cluster-density` workload supports the environment variable **JOB_ITERATIONS**. This variable configures the number of cluster-density jobs iterations to perform (1 namespace per iteration). By default 1000.

Each iteration creates the following objects:

- 12 imagestreams
- 3 buildconfigs
- 6 builds
- 1 deployment with 2 pod replicas (sleep) mounting two secrets each. deployment-2pod
- 2 deployments with 1 pod replicas (sleep) mounting two secrets. deployment-1pod
- 3 services, one pointing to deployment-2pod, and other two pointing to deployment-1pod
- 3 route. 1 pointing to the service deployment-2pod and other two pointing to deployment-1pod
- 10 secrets. 2 of them mounted by the previous deployments.
- 10 configMaps. 2 of them mounted by the previous deployments.


### Node-density and Node-density-heavy variables

The `node-density` and `node-density-heavy` workloads support the following environment variables:

- **NODE_COUNT**: Number of worker nodes to deploy the pods on. During the workload nodes will be labeled with `node-density=true`. Defaults to 4.
- **PODS_PER_NODE**: Define the maximum number of pods to deploy on each labeled node. Defaults to 250

These workloads create different objects each:

- **node-density**: Creates a single namespace with a number of Deployments proportional to the calculated number of pod.
Each iteration of this workload creates the following object:
  - 1 pod. (sleep)


- **node-density-heavy**. Creates a **single namespace with a number of applications proportional to the calculated number of pods / 2**. This application consists on two deployments (a postgresql database and a simple client that generates some CPU load) and a service that is used by the client to reach the database.
Each iteration of this workload can be broken down in:
  - 1 deployment holding a postgresql database
  - 1 deployment holding a client application for the previous database
  - 1 service pointing to the postgresl database

### Max-namespaces

The number of namespaces created by Kube-burner is defined by the variable `NAMESPACE_COUNT`. Each namespace is created with the following objects:

- 1 deployment holding a postgresql database
- 5 deployments consisting of a client application for the previous database
- 1 service pointing to the postgresl database
- 10 secrets


### Max-services

It creates n-replicas of an application deployment (hello-openshift) and a service in a single namespace as defined by the environment variable `SERVICE_COUNT`.


### Pod-density

It creates as many "sleep" pods as configured in the environment variable `PODS`.


### Remote configuration

Apart from the pre-defined workloads and metric profiles available in benchmark-operator, you can create a benchmark that uses a remote configuration, metric or alert profile. These files must be accesible through HTTP protocol by the kube-burner job. The following environment variables can be used to configure the source for the different configuration files:

- **`REMOTE_CONFIG`**: Refers to the remote location of the Kube-burner main configuration file.
- **`REMOTE_METRIC_PROFILE`**: Points to a URL of a valid metric profile.
- **`REMOTE_ALERT_PROFILE`**: Points to a URL of a valid alert profile.

> Note: These can be used separately and/or combined with the kube-burner workloads available in the benchmark-operator.


### Concurrent Builds

Creates a buildconfig and imagestream for a set application. **This will create as many namespaces with these objects as the configured job_iterations**.
After the initial creation of the objects the script will concurrently build different numbers of the builds and output the average times. 
To edit any of the build information edit the bash script correlating with the application of interest under the builds folder


## Configuration file

An [env.sh](env.sh) file is provided with all available configuration parameters.
