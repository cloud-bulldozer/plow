#!/usr/bin/env bash
set -x

pip3 install -r requirements.txt

# Check cluster's health
if [[ ${CERBERUS_URL} ]]; then
  response=$(curl ${CERBERUS_URL})
  if [ "$response" != "True" ]; then
    echo "Cerberus status is False, Cluster is unhealthy"
    exit 1
  fi
fi

_es=${ES_SERVER:=search-cloud-perf-lqrf3jjtaqo7727m7ynd2xyt4y.us-west-2.es.amazonaws.com}
_es_port=${ES_PORT:=80}
_es_baseline=${ES_SERVER_BASELINE:=search-cloud-perf-lqrf3jjtaqo7727m7ynd2xyt4y.us-west-2.es.amazonaws.com}
_es_baseline_port=${ES_PORT_BASELINE:=80}
_metadata_collection=${METADATA_COLLECTION:=true}
COMPARE=${COMPARE:=false}
throughput_tolerance=${THROUGHPUT_TOLERANCE:=5}
latency_tolerance=${LATENCY_TOLERANCE:=5}
client_server_pairs=${CLIENT_SERVER_PAIRS:=(1 2 4)}

if [[ ${ES_SERVER} ]] && [[ ${ES_PORT} ]] && [[ ${ES_USER} ]] && [[ ${ES_PASSWORD} ]]; then
  _es=${ES_USER}:${ES_PASSWORD}@${ES_SERVER}
fi

if [[ ${ES_SERVER_BASELINE} ]] && [[ ${ES_PORT_BASELINE} ]] && [[ ${ES_USER_BASELINE} ]] && [[ ${ES_PASSWORD_BASELINE} ]]; then
  _es_baseline=${ES_USER_BASELINE}:${ES_PASSWORD_BASELINE}@${ES_SERVER_BASELINE}
fi

if [[ -z "$GSHEET_KEY_LOCATION" ]]; then
   export GSHEET_KEY_LOCATION=$HOME/.secrets/gsheet_key.json
fi

if [[ ${COMPARE} != "true" ]]; then
  export COMPARE=false
  unset ES_SERVER_BASELINE ES_PORT_BASELINE BASELINE_HOSTNET_UUID BASELINE_MULTUS_UUID \
        BASELINE_POD_1P_UUID BASELINE_POD_2P_UUID BASELINE_POD_4P_UUID \
        BASELINE_SVC_1P_UUID BASELINE_SVC_2P_UUID BASELINE_SVC_4P_UUID \
        BASELINE_CLOUD_NAME
fi

if [ ! -z ${2} ]; then
  export KUBECONFIG=${2}
fi

cloud_name=$1
if [ "$cloud_name" == "" ]; then
  cloud_name="test_cloud"
fi

# check if cluster is up
date
oc get clusterversion
if [ $? -ne 0 ]; then
  echo "Workload Failed for cloud $cloud_name, Unable to connect to the cluster"
  exit 1
fi

if [[ ${COMPARE} == "true" ]]; then
  echo $BASELINE_CLOUD_NAME,$cloud_name > uuid.txt
else
  echo $cloud_name > uuid.txt
fi

echo "Starting test for cloud: $cloud_name"

oc create ns my-ripsaw

git clone http://github.com/cloud-bulldozer/ripsaw /tmp/ripsaw
oc apply -f /tmp/ripsaw/deploy
oc apply -f /tmp/ripsaw/resources/backpack_role.yaml
oc apply -f /tmp/ripsaw/resources/crds/ripsaw_v1alpha1_ripsaw_crd.yaml
oc apply -f /tmp/ripsaw/resources/operator.yaml

server=""
client=""
pin=false
if [[ $(oc get nodes | grep worker | wc -l) -gt 1 ]]; then
  server=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{range .items[*]}{ .metadata.labels.kubernetes\.io/hostname}{"\n"}{end}' | head -n 1)
  client=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{range .items[*]}{ .metadata.labels.kubernetes\.io/hostname}{"\n"}{end}' | tail -n 1)
  pin=true
fi

oc adm policy -n my-ripsaw add-scc-to-user privileged -z benchmark-operator
oc adm policy -n my-ripsaw add-scc-to-user privileged -z backpack-view
oc patch scc restricted --type=merge -p '{"allowHostNetwork": true}'
