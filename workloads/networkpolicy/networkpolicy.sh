#!/usr/bin/bash -e

set -e
. ../kube-burner/common.sh

export NS_LABEL=${NS_LABEL:-kube-burner-job=${WORKLOAD}}
if [[ ${DEPLOY_INFRA} == "true" ]]; then
  deploy_operator
  check_running_benchmarks
  deploy_workload
  wait_for_benchmark ${WORKLOAD}
  rm -rf benchmark-operator
  if [[ ${CLEANUP_WHEN_FINISH} == "true" ]]; then
    cleanup
  fi
fi

if [[ ${DEPLOY_CLIENT} == "true" ]]; then
  envsubst < pod-scraper.yaml | oc apply -f -
  if [[ $DEPLOY_ADDITIONAL_PODS == "true" ]]; then
    curl -LsS https://github.com/cloud-bulldozer/kube-burner/releases/download/v0.11/kube-burner-0.11-Linux-x86_64.tar.gz | tar xz
    export UUID=$(oc get benchmarks.ripsaw.cloudbulldozer.io -n my-ripsaw -o jsonpath='{.items[0].status.uuid}')
    envsubst < additional-pod.yaml.tmpl > additional-pod.yaml;
    ./kube-burner init -c additional-pod.yaml --uuid=${UUID}
  fi
fi  
