#!/usr/bin/bash -e

set -e

build_array=(1 8 15 30 45 60 75)
app_array=("django" "nodejs" "eap" "rails")

max=0
for v in ${build_array[@]}; do
    if (( $v > $max )); then max=$v; fi;
done
echo "Max $max"

export MAX_CONC_BUILDS=$((max + 1))

export CLEANUP_WHEN_FINISH=true
export build_test_repo=${BUILD_TEST_REPO:=https://github.com/openshift/svt.git}
export build_test_branch=${BUILD_TEST_BRANCH:=master}

export WORKLOAD=concurrent-builds
export METRICS_PROFILE=${METRICS_PROFILE:-metrics-aggregated.yaml}
export JOB_ITERATIONS=${MAX_CONC_BUILDS:-$max}

function prepare_builds_file()
{
  echo "prepare builds file: $1"
  project_name=`oc get project --no-headers | grep -m 1 svt- | awk {'print $1'}`
  bc_name=`oc get bc -n $project_name --no-headers | awk {'print $1'}`
  running_build_file="running-builds.json"
  # generate running-builds.json on the fly
  printf '%s\n' "[" > "${running_build_file}"
  echo "proj name $project_name "
  proj_substring=${project_name::${#project_name}-1}
  echo "sub $proj_substring"
  for (( c=1; c<"${MAX_CONC_BUILDS}"; c++ ))
  do
    if [[ "$c" == $((MAX_CONC_BUILDS - 1)) ]]; then
      printf '%s\n' "{\"namespace\":\"$proj_substring${c}\", \"name\":\"$bc_name\"}" >> "${running_build_file}"
    else
      printf '%s\n' "{\"namespace\":\"$proj_substring${c}\", \"name\":\"$bc_name\"}," >> "${running_build_file}"
    fi
  done
  printf '%s' "]" >> "${running_build_file}"
}


function install_svt_repo() {
  rm -rf svt
  git clone --single-branch --branch ${build_test_branch} ${build_test_repo} --depth 1
  python2 -m pip install futures pytimeparse logging
}

function run_builds() {
  echo "${build_array[@]}"
  for i in "${build_array[@]}"
  do
    echo "running $i $1 concurrent builds"
    fileName="conc_builds_$1.out"
    python2 svt/openshift_performance/ose3_perf/scripts/build_test.py -z -a -n 2 -r $i -f running-builds.json >> $fileName 2>&1
    sleep 10
  done
}

function wait_for_running_builds() {
  running=`oc get pods -A --no-headers | grep svt-$1 | grep Running | wc -l`
  echo "running $running"
  while [ $running -ne 0 ]; do
    sleep 15
    running=`oc get pods -A | grep svt-$1 | grep Running | wc -l`
    echo "$running pods are still running"
  done

}

rm -rf conc_builds_results.out

. common.sh

deploy_operator
check_running_benchmarks

install_svt_repo

for app in "${app_array[@]}"
do
  export APP_SUBNAME=$app
  rm -rf conc_builds_$app.out
  echo "app here $app $APP_SUBNAME"
  . ./builds/$app.sh
  deploy_workload
  wait_for_benchmark ${APP_SUBNAME}${WORKLOAD}
  sleep 15
  wait_for_running_builds $app
  sleep 10

  prepare_builds_file
  run_builds $app
  proj=$app

  echo "================ Average times for $proj app =================" >> conc_builds_results.out
  grep "Average build time, all good builds" conc_builds_$proj.out >> conc_builds_results.out
  grep "Average push time, all good builds" conc_builds_$proj.out >> conc_builds_results.out
  grep "Good builds included in stats" conc_builds_$proj.out >> conc_builds_results.out
  echo "==============================================================" >> conc_builds_results.out

  if [[ ${CLEANUP_WHEN_FINISH} == "true" ]]; then
    cleanup
  fi

done

cat conc_builds_results.out 

exit ${rc}
