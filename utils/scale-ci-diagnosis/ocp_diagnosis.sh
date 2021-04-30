#!/bin/bash

set -eo pipefail

prometheus_namespace=openshift-monitoring

function help() {
	printf "\n"
	printf "Usage: source env.sh; $0\n"
        printf "\n"
        printf "options supported:\n"
	printf "\t OUTPUT_DIR=str,                       str=dir to store the capture prometheus data\n"
	printf "\t PROMETHEUS_CAPTURE=str,               str=true or false, enables/disables prometheus capture\n"
	printf "\t PROMETHEUS_CAPTURE_TYPE=str,          str=wal or full, wal captures the write ahead log and full captures the entire prometheus DB\n"
	printf "\t OPENSHIFT_MUST_GATHER=str,            str=true or false, gathers cluster data including information about all the operator managed components\n"
	printf "\t STORAGE_MODE=str,                     str=pbench, moves the results to the pbench results dir to be shipped to the pbench server in case the tool is run using pbench\n"
	printf "\t DATA_SERVER_URL=str                   str=url that points to an http server that hosts data"
}

echo "==========================================================================="
echo "                      RUNNING SCALE-CI-DIAGNOSIS                           "
echo "==========================================================================="

if [[ -z "$OUTPUT_DIR" ]]; then
	echo "Looks like OUTPUT_DIR is not defined, please check"
	help
	exit 1
fi

if [[ -z "$PROMETHEUS_CAPTURE" ]]; then
	echo "Looks like PROMETHEUS_CAPTURE is not defined, please check"
	help
	exit 1
fi

if [[ -z "$PROMETHEUS_CAPTURE_TYPE" ]]; then
	echo "Looks like PROMETHEUS_CAPTURE_TYPE is not defined, please check"
	help
	exit 1
fi

if [[ -z "$OPENSHIFT_MUST_GATHER" ]]; then
	echo "Looks like OPENSHIFT_MUST_GATHER is not defined, please check"
	help
	exit 1
fi

# Check for kubeconfig
if [[ -z $KUBECONFIG ]] && [[ ! -s $HOME/.kube/config ]]; then
    echo "KUBECONFIG var is not defined and cannot find kube config in the home directory, please check"
    exit 1
fi

# Check if oc client is installed
which oc &>/dev/null
echo "Checking if oc client is installed"
if [[ $? -ne 0 ]]; then
    echo "oc client is not installed, please install"
    exit 1
else
	echo "oc client is present"
fi

# pick a prometheus pod
prometheus_pod=$(oc get pods -n $prometheus_namespace | grep -w "Running" | awk -F " " '/prometheus-k8s/{print $1}' | tail -n1)

# get the timestamp
ts=$(date +"%Y%m%d-%H%M%S")

function capture_wal() {
	echo "================================================================================="
	echo "               copying prometheus wal from $prometheus_pod                       "
	echo "================================================================================="
	oc cp $prometheus_namespace/$prometheus_pod:/prometheus/wal -c prometheus $OUTPUT_DIR/wal/
	XZ_OPT=--threads=0 tar cJf $OUTPUT_DIR/prometheus-$ts.tar.xz $OUTPUT_DIR/wal
	if [[ $? -eq 0 ]]; then
		rm -rf $OUTPUT_DIR/wal
	fi
}


function capture_full_db() {
	echo "================================================================================="
	echo "            copying the entire prometheus DB from $prometheus_pod                "
	echo "================================================================================="
	oc cp  $prometheus_namespace/$prometheus_pod:/prometheus/ -c prometheus $OUTPUT_DIR/data/
	XZ_OPT=--threads=0 tar cJf $OUTPUT_DIR/prometheus-$ts.tar.xz -C $OUTPUT_DIR/data .
	if [[ $? -eq 0 ]]; then
		rm -rf $OUTPUT_DIR/data
	fi
}


function must_gather() {
	oc adm must-gather --dest-dir=$OUTPUT_DIR/must-gather-$ts
	XZ_OPT=--threads=0 tar cJf $OUTPUT_DIR/must-gather-$ts.tar.xz $OUTPUT_DIR/must-gather-$ts
	if [[ $? -eq 0 ]]; then
		rm -rf $OUTPUT_DIR/must-gather-$ts
	fi
}


function prometheus_capture() {
	if [[ "$PROMETHEUS_CAPTURE_TYPE" == "wal" ]]; then
		capture_wal
	elif [[ "$PROMETHEUS_CAPTURE_TYPE" == "full" ]]; then
		capture_full_db
	else
		echo "Looks like $type is not a valid option, please check"
		help
	fi
}


function set_pbench() {
	echo "Detected storage mode as $STORAGE_MODE"
	echo "Assuming that the ocp diagnosis tool is run using pbench-user-benchmark"
	echo "Fetching the latest pbench results dir"
	result_dir="/var/lib/pbench-agent/$(ls -t /var/lib/pbench-agent/ | grep "pbench-user" | head -1)"/1-default/reference-result
	OUTPUT_DIR="/var/lib/pbench-agent/$(ls -t /var/lib/pbench-agent/ | grep "pbench-user" | head -1)"/1-default
	echo "Copying the collected data to $result_dir"
}


function store() {
	# parameters
	# 	1 function to capture data
	# 	2 filename

	if [[ -z $STORAGE_MODE ]]; then
		echo "Looks like STORAGE_MODE is not defined, storing the results on local file system"
		$1;
	elif [[ $STORAGE_MODE == "pbench" ]]; then
		set_pbench;
		$1;
	elif [[ $STORAGE_MODE == "snappy" ]]; then
		export platform=$(oc get infrastructure cluster -o jsonpath='{.status.platformStatus.type}')
 		export cluster_version=$(oc get clusterversion | grep -o [0-9.]* | head -1)
 		export network_type=$(oc get network cluster  -o jsonpath='{.status.networkType}' | tr '[:upper:]' '[:lower:]')
 		export folder_date_time=$(TZ=UTC date +"%Y-%m-%d_%I:%M_%p")
		export SNAPPY_USER_FOLDER=${SNAPPY_USER_FOLDER:=perf-ci}
		if [[ -n $RUNID ]];then 
            runid=$RUNID-
        fi
		../../utils/snappy-move-results/generate_metadata.sh > metadata.json 
 		../snappy-move-results/run_snappy.sh "$OUTPUT_DIR/$2" "$SNAPPY_USER_FOLDER/$runid$platform-$cluster_version-$network_type/$workload/$folder_date_time/"
		../snappy-move-results/run_snappy.sh metadata.json "$SNAPPY_USER_FOLDER/$runid$platform-$cluster_version-$network_type/$workload/$folder_date_time/"
		

	else
		echo "Invalid storage mode chosen. STORAGE_MODE is $STORAGE_MODE"
		exit 1
	fi
}


if [[ $PROMETHEUS_CAPTURE == "true" ]]; then
	export workload=prometheus 
	store prometheus_capture "prometheus-$ts.tar.xz"
fi


if [[ $OPENSHIFT_MUST_GATHER == "true" ]]; then
	export workload=must_gather
	store must_gather "must-gather-$ts.tar.xz"
fi

