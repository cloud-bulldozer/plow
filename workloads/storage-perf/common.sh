#!/usr/bin/env bash

log() {
    echo ${bold}$(date -u):  ${@}${normal}
}

check_cluster_present() {
  echo ""
  oc get clusterversion
  if [ $? -ne 0 ]; then
    log "Workload Failed for cloud $cloud_name, Unable to connect to the cluster"
    exit 1
  fi
  cluster_version=$(oc get clusterversion --no-headers | awk '{ print $2 }')
  echo ""
}

export_defaults() {
  operator_repo=${OPERATOR_REPO:=https://github.com/cloud-bulldozer/benchmark-operator.git}
  export _es=${ES_SERVER:=search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com/}
  export _es_port=${ES_PORT:=80}
  _es_baseline=${ES_SERVER_BASELINE:=search-perfscale-dev-chmf5l4sh66lvxbnadi4bznl3a.us-west-2.es.amazonaws.com/}
  _es_baseline_port=${ES_PORT_BASELINE:=80}
  export _metadata_collection=${METADATA_COLLECTION:=true}
  COMPARE=${COMPARE:=false}
  gold_sdn=${GOLD_SDN:=openshiftsdn}
  throughput_tolerance=${THROUGHPUT_TOLERANCE:=5}
  latency_tolerance=${LATENCY_TOLERANCE:=5}

  if [[ ${ES_SERVER} ]] && [[ ${ES_PORT} ]] && [[ ${ES_USER} ]] && [[ ${ES_PASSWORD} ]]; then
    _es=${ES_USER}:${ES_PASSWORD}@${ES_SERVER}
  fi

  if [[ ${ES_SERVER_BASELINE} ]] && [[ ${ES_PORT_BASELINE} ]] && [[ ${ES_USER_BASELINE} ]] && [[ ${ES_PASSWORD_BASELINE} ]]; then
    _es_baseline=${ES_USER_BASELINE}:${ES_PASSWORD_BASELINE}@${ES_SERVER_BASELINE}
  fi

  if [[ -z "$GSHEET_KEY_LOCATION" ]]; then
     export GSHEET_KEY_LOCATION=$HOME/.secrets/gsheet_key.json
  fi

  if [ ! -z ${2} ]; then
    export KUBECONFIG=${2}
  fi
  platform=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.type}' | tr '[:upper:]' '[:lower:]')
  cloud_name=$1
  if [ "$cloud_name" == "" ]; then
    export cloud_name="test_cloud_${platform}_${cluster_version}"
  fi

  if [[ ${COMPARE} == "true" ]]; then
    echo $BASELINE_CLOUD_NAME,$cloud_name > uuid.txt
  else
    echo $cloud_name > uuid.txt
  fi
}

deploy_operator() {
  log "Starting test for cloud: $cloud_name"
  log "Deploying benchmark-operator"
  oc apply -f /tmp/benchmark-operator/resources/namespace.yaml
  oc apply -f /tmp/benchmark-operator/deploy
  oc apply -f /tmp/benchmark-operator/resources/crds/ripsaw_v1alpha1_ripsaw_crd.yaml
  oc apply -f /tmp/benchmark-operator/resources/operator.yaml
  oc apply -f /tmp/benchmark-operator/resources/backpack_role.yaml
  log "Waiting for benchmark-operator to be available"
  oc wait --for=condition=available -n my-ripsaw deployment/benchmark-operator --timeout=280s
}

check_toolbox_status() {
    
    log "checking Toolbox status"
    tool_box=`oc get pods -n openshift-storage | grep tool | awk '{print $1}'`
    log "deploy and wait for running tool box..."
    check_toolbox_status=true
    check_counter=0
    while $check_toolbox_status
    do
        status=`oc get pods -n openshift-storage | grep tool | awk '{print $3}'`
        if [ "$status" == "Running" ]; then
            check_toolbox_status=false
            log "ceph toolbox is running"
            return 0
        elif [ $check_counter -gt 4 ]; then #wait for 120s until failure
            log "failed to detect running toolbox, aborting..."
            return 1
        else
            check_counter=$((check_counter+1))
            sleep 30
        fi
    done
}

check_ocs_status() {
    log "checking ocs status"
    check_app_status=true
    time_counter=0
    while $check_app_status
    do
        osd_running_count=0
        for i in `oc get pods -n openshift-storage | grep rook-ceph-osd-[0-9] | awk '{print $3}'`; 
        do 
            if [ "$i" == "Running" ]; then
                osd_running_count=$((osd_running_count+1))
            fi
        done
        
        mon_running_count=0
        for i in `oc get pods -n openshift-storage | grep rook-ceph-mon-[a-z] | awk '{print $3}'`; 
        do 
            if [ $i == "Running" ]; then
                mon_running_count=$((mon_running_count+1))
            fi
        done
        
        mgr_status=`oc get pods -n openshift-storage | grep rook-ceph-mgr-[a-z] | awk '{print $3}'`
        if [ "$mgr_status" == "Running" ]; then
                mgr_running_count=1
        fi
        
        
        if [ $osd_running_count -eq 3 ] && [ $mon_running_count -eq 3 ] && [ $mgr_running_count -eq 1 ]; then
            log "minimum apps started osds(${osd_running_count}), mons(${mon_running_count}), mgrs(${mgr_running_count})"
            check_app_status=false
        elif [ $time_counter -gt 600 ]; then
            log "Timeout: failed to detect healthy OCS app status"
            exit 1
        else
            time_counter=$((time_counter+1))
            sleep 30
        fi
    done
    
    log "checking ceph status via ceph-toolbox"
    
    check_toolbox_status
    status=$?
    if [ $status -eq 0 ]; then
        oc patch OCSInitialization ocsinit -n openshift-storage --type json --patch  '[{ "op": "replace", "path": "/spec/enableCephTools", "value": false }]'
        sleep 5 #added delay to give system to time to remove old toolbox
        oc patch OCSInitialization ocsinit -n openshift-storage --type json --patch  '[{ "op": "replace", "path": "/spec/enableCephTools", "value": true }]'
        sleep 5
    else
        oc patch OCSInitialization ocsinit -n openshift-storage --type json --patch  '[{ "op": "replace", "path": "/spec/enableCephTools", "value": true }]'
    fi
    
    #wait for new toolbox to become live
    check_toolbox_status
        
    
    log "check ceph status for health ok and 3 pools"
    ceph_status=`oc rsh -n openshift-storage $tool_box ceph status`
    check_ceph_status=true
    check_ceph_status_timeout=0
    while $check_ceph_status
    do
        if [[ "$ceph_status" == *"health: HEALTH_OK"* ]]; then 
            log "detected health ok "
            detected_health_ok=true
        elif [ $check_ceph_status_timeout -gt 80 ]; then
            log "failed to detect health ceph cluster, abort..."
        fi
            
        if [[ "$ceph_status" == *"pools:   3 pools"* ]]; then 
            log "detected minimum number of pools(3)"
            detected_min_pools=true
        elif [ $check_ceph_status_timeout -gt 80 ]; then
            log "failed to detect health ceph cluster, abort..."
        fi
        
        if [ "$detected_health_ok" == "true" ] && [ "$detected_min_pools" == "true" ]; then
            log "completed ceph health check"
            echo "${ceph_status}"
            check_ceph_status=false
        elif [ $check_ceph_status_timeout -gt 80 ]; then #wait for 10 minutes util failure
            log "Timeout - failed to detect ceph status within the allotted time, aborting..."
            return 1
        else
            check_ceph_status_timeout=$((check_ceph_status_timeout+1))
            sleep 30
        fi
        
    done
    log "OCS is healthy and all pools are present"
    return 0
}

install_aws_ocs() {

    scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    oc describe -n openshift-storage -f storage_classes/ocs_aws_storageclass.yaml | grep -B 1 "Type:                  Available" | grep True
    cluster_status=$?
    
    if [ $cluster_status -gt 0 ]; then
    
        export version=`oc version | grep "Server Version:" | sed -e  s/"Server Version: "// | awk -F "." '{print $1 "." $2}'`
        log "Attempting to install OCS $version"
        git clone https://github.com/openshift/ocs-operator.git
        cd ocs-operator/deploy/
        
        export image="image: quay.io/rhceph-dev/ocs-olm-operator:latest-${version}"
        version_deploy_with_olm_file="${version}-deploy-with-olm.yaml"
        cp deploy-with-olm.yaml $version_deploy_with_olm_file
        
        sed -i "s|image: quay.io/ocs-dev/ocs-registry:latest|${image}|g" $version_deploy_with_olm_file
        sed -i "s|channel: alpha|channel: stable-${version}|g" $version_deploy_with_olm_file
        
        oc create -f $version_deploy_with_olm_file
        check_health=true
        counter=0
        
        while $check_health 
        do
            ocs_operator_status=`oc get pods -n openshift-storage | grep ocs-operator | awk '{print $3}'`
            if [ "${ocs_operator_status}" = "Running" ]; then
                log "detected running OCS operator"
                check_health=false
            elif [ $counter -lt 10 ]; then
                log "waiting 30s to recheck ocs operator status..."
                sleep 30
                counter=$((counter+1))
            else
                log "failed to detect ocs operator status in running state."
                exit 1
            fi 
        done
        log "Detected OCS Operator status of running."
        
        log "labeling first three workers with cluster.ocs.openshift.io/openshift-storage=''"
        node_count=0
        for i in `oc get nodes | grep worker | awk '{print $1}'`
        do
            if [ $node_count -lt 3 ]; then
                oc label nodes $i cluster.ocs.openshift.io/openshift-storage=''
                node_count=$((node_count+1))
            fi
        done
        
        log "Creating OCS Storage Cluster..."
        
        oc create -n openshift-storage -f ${scriptdir}/storage_classes/ocs_aws_storageclass.yaml
    else
        log " detect OCS Storage Cluster, by-passing OCS setup."
    fi
    log "checking minimum OCS apps(OSDs, MONs, MGR)"
    check_ocs_status
    
}


run_ocs_fio_benchmark() {

prom_access_token=`oc -n openshift-monitoring sa get-token prometheus-k8s`

cat << EOF | oc create -n my-ripsaw -f -
apiVersion: ripsaw.cloudbulldozer.io/v1alpha1
kind: Benchmark
metadata:
  name: fio-benchmark
  namespace: my-ripsaw
spec:
  elasticsearch:
    url: ${_es}:${_es_port}
    parallel: true
  prometheus:
    es_url: ${_es}:${_es_port}
    prom_url: https://prometheus-k8s.openshift-monitoring.svc.cluster.local:9091
    prom_token: ${prom_access_token} 
    es_parallel: true # enable parallel uploads to elasticsearch
  clustername: $cloud_name
  test_user: ${cloud_name}-ci
  workload:
    name: "fio_distributed"
    args:
      prefill: true
      samples: 4
      servers: 30
      pin_server: ''
      jobs:
        - write
        - read
      bs:
        - 8KiB
        - 16KiB
        - 4096KiB
      numjobs:
        - 1
      iodepth: 16
      runtime: 300  
      ramp_time: 0
      filesize: 32GiB
      log_sample_rate: 30000
      storageclass: ocs-storagecluster-ceph-rbd
      storagesize: 36Gi
#######################################
#  EXPERT AREA - MODIFY WITH CAUTION  #
#######################################
  job_params:
    - jobname_match: write
      params:
        - time_based=1
        - runtime={{ workload_args.runtime }}
        - ramp_time={{ workload_args.ramp_time }}
    - jobname_match: read
      params:
        - time_based=1
        - runtime={{ workload_args.runtime }}
        - ramp_time={{ workload_args.ramp_time }}
    - jobname_match: randwrite
      params:
        - time_based=1
        - runtime={{ workload_args.runtime }}
        - ramp_time={{ workload_args.ramp_time }}
    - jobname_match: randread
      params:
        - time_based=1
        - runtime={{ workload_args.runtime }}
        - ramp_time={{ workload_args.ramp_time }}
EOF

}

run_raw_fio_benchmark() {
prom_access_token=`oc -n openshift-monitoring sa get-token prometheus-k8s`

cat << EOF | oc create -n my-ripsaw -f -
apiVersion: ripsaw.cloudbulldozer.io/v1alpha1
kind: Benchmark
metadata:
  name: fio-benchmark
  namespace: my-ripsaw
spec:
  elasticsearch:
    url: ${_es}:${_es_port}
    parallel: true
  prometheus:
    es_url: ${_es}:${_es_port}
    prom_url: https://prometheus-k8s.openshift-monitoring.svc.cluster.local:9091
    prom_token: ${prom_access_token} 
    es_parallel: true # enable parallel uploads to elasticsearch
  clustername: $cloud_name
  test_user: ${cloud_name}-ci
  workload:
    name: "fio_distributed"
    args:
      prefill: true
      samples: 4
      servers: 3
      pin_server: ''
      jobs:
        - write
        - read
      bs:
        - 8KiB
        - 16KiB
        - 4096KiB
      numjobs:
        - 10
      iodepth: 16
      runtime: 300  
      ramp_time: 0
      filesize: 32GiB
      log_sample_rate: 30000
      storageclass: raw_gp2
      storagesize: 2Ti
#######################################
#  EXPERT AREA - MODIFY WITH CAUTION  #
#######################################
  job_params:
    - jobname_match: write
      params:
        - time_based=1
        - runtime={{ workload_args.runtime }}
        - ramp_time={{ workload_args.ramp_time }}
    - jobname_match: read
      params:
        - time_based=1
        - runtime={{ workload_args.runtime }}
        - ramp_time={{ worhttp://search-cloud-perf-lqrf3jjtaqo7727m7ynd2xyt4y.us-west-2.es.amazonaws.com/068128
        191820
        kload_args.ramp_time }}
    - jobname_match: randwrite
      params:
        - time_based=1
        - runtime={{ workload_args.runtime }}
        - ramp_time={{ workload_args.ramp_time }}
    - jobname_match: randread
      params:
        - time_based=1
        - runtime={{ workload_args.runtime }}
        - ramp_time={{ workload_args.ramp_time }}
EOF
}


update() {
  benchmark_state=$(oc get benchmark.ripsaw.cloudbulldozer.io/fio-benchmark -n my-ripsaw -o jsonpath='{.status.state}')
  benchmark_uuid=$(oc get benchmark.ripsaw.cloudbulldozer.io/fio-benchmark -n my-ripsaw -o jsonpath='{.status.uuid}')
  #benchmark_current_pair=$(oc get benchmarks.ripsaw.cloudbulldozer.io/uperf-benchmark-${WORKLOAD}-network -n my-ripsaw -o jsonpath='{.spec.workload.args.pair}')
}

wait_for_fio_benchmark() {
    log "Waiting for benchmark test to complete..."
    
    for i in {1..480} # 2hours
    do
        update
        if [ "${benchmark_state}" == "Error" ]; then
          log "Cerberus status is False, Cluster is unhealthy"
          exit 1
        fi
        
        oc describe -n my-ripsaw benchmark.ripsaw.cloudbulldozer.io/fio-benchmark | grep State | grep Complete
        fio_state=$?
        if [ $fio_state -eq 0 ]; then
            log "fio workload done!"
            break
        fi
        update
        sleep 30
    done
    
    if [ $fio_state -gt 0 ]; then
        log "Timeout, execution of benchmark test exceeded allotted time. "
    fi
}


create_raw_aws_storageclass() {

cat << EOF | oc create -n my-ripsaw -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: raw_gp2
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
volumeBindingMode: WaitForFirstConsumer
EOF

}

init_cleanup() {
  log "Cloning benchmark-operator from ${operator_repo}"
  rm -rf /tmp/benchmark-operator
  git clone ${operator_repo} /tmp/benchmark-operator
  oc delete -f /tmp/benchmark-operator/deploy
  oc delete -f /tmp/benchmark-operator/resources/crds/ripsaw_v1alpha1_ripsaw_crd.yaml
  oc delete -f /tmp/benchmark-operator/resources/operator.yaml  
}

delete_benchmark() {
  oc delete benchmark.ripsaw.cloudbulldozer.io/fio-benchmark -n my-ripsaw
}

export TERM=screen-256color
bold=$(tput bold)
uline=$(tput smul)
normal=$(tput sgr0)
python3 -m pip install -r requirements.txt | grep -v 'already satisfied'
export_defaults
check_cluster_present
init_cleanup
deploy_operator

