#!/bin/bash
# This should only be sourced
if [ "${0##*/}" = "lib_helm_deploy_subm.sh" ]; then
    echo "Don't run me, source me" >&2
    exit 1
fi

### Variables ###

SUBMARINER_BROKER_NS=submariner-k8s-broker
SUBMARINER_PSK=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
subm_ns=submariner

### Functions ###

function install_helm() {
    helm init --client-only
    helm repo add submariner-latest https://submariner-io.github.io/submariner-charts/charts
    pids=(-1 -1 -1)
    logs=()
    for i in 1 2 3; do
        if kubectl --context=cluster${i} -n kube-system rollout status deploy/tiller-deploy > /dev/null 2>&1; then
            echo Helm already installed on cluster${i}, skipping helm installation...
        else
            logs[$i]=$(mktemp)
            echo Installing helm on cluster${i}, logging to ${logs[$i]}...
            (
            kubectl --context=cluster${i} -n kube-system create serviceaccount tiller
            kubectl --context=cluster${i} create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
            helm --kube-context cluster${i} init --service-account tiller
            kubectl --context=cluster${i} -n kube-system rollout status deploy/tiller-deploy
            ) > ${logs[$i]} 2>&1 &
            set pids[$i] = $!
        fi
    done
    print_logs "${logs[@]}"
}

function deploytool_prereqs() {
    install_helm
}

function setup_broker() {
    context=$1
    if kubectl --context=$context get crd clusters.submariner.io > /dev/null 2>&1; then
        echo Submariner CRDs already exist, skipping broker creation...
    else
        echo Installing broker on $context.
        helm --kube-context $context install submariner-latest/submariner-k8s-broker --name ${SUBMARINER_BROKER_NS} --namespace ${SUBMARINER_BROKER_NS}
    fi

    SUBMARINER_BROKER_URL=$(kubectl --context=$context -n default get endpoints kubernetes -o jsonpath="{.subsets[0].addresses[0].ip}:{.subsets[0].ports[?(@.name=='https')].port}")
    SUBMARINER_BROKER_CA=$(kubectl --context=$context -n ${SUBMARINER_BROKER_NS} get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='${SUBMARINER_BROKER_NS}-client')].data['ca\.crt']}")
    SUBMARINER_BROKER_TOKEN=$(kubectl --context=$context -n ${SUBMARINER_BROKER_NS} get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='${SUBMARINER_BROKER_NS}-client')].data.token}"|base64 --decode)
}

function helm_install_subm() {
    cluster_id=$1
    crd_create=$2
    cluster_cidr=$3
    service_cidr=$4
    global_cidr=$5
    globalnet_enable="true" && [[ -z $global_cidr ]] && globalnet_enable="false"

    kubectl config use-context $cluster_id
    helm --kube-context ${cluster_id} install submariner-latest/submariner \
        --name submariner \
        --namespace submariner \
        --set ipsec.psk="${SUBMARINER_PSK}" \
        --set broker.server="${SUBMARINER_BROKER_URL}" \
        --set broker.token="${SUBMARINER_BROKER_TOKEN}" \
        --set broker.namespace="${SUBMARINER_BROKER_NS}" \
        --set broker.ca="${SUBMARINER_BROKER_CA}" \
        --set submariner.clusterId="${cluster_id}" \
        --set submariner.clusterCidr="${cluster_cidr}" \
        --set submariner.serviceCidr="${service_cidr}" \
        --set submariner.globalCidr="${global_cidr}" \
        --set serviceAccounts.globalnet.create=${globalnet_enable} \
        --set submariner.natEnabled="false" \
        --set routeAgent.image.repository="submariner-route-agent" \
        --set routeAgent.image.tag="local" \
        --set routeAgent.image.pullPolicy="IfNotPresent" \
        --set engine.image.repository="submariner" \
        --set engine.image.tag="local" \
        --set engine.image.pullPolicy="IfNotPresent" \
        --set crd.create="${crd_create}"
}


function install_subm_all_clusters() {
    if kubectl --context=cluster1 get crd clusters.submariner.io > /dev/null 2>&1; then
        echo Submariner CRDs already exist, skipping broker creation...
    else
        echo Installing Submariner Broker in cluster1...
        helm_install_subm cluster1 false ${cluster_CIDRs[cluster1]} ${service_CIDRs[cluster1]} ${global_CIDRs[cluster1]}
    fi

    for i in 2 3; do
      cluster_id=cluster$i
      if kubectl --context=$cluster_id wait --for=condition=Ready pods -l app=submariner-engine -n submariner --timeout=60s > /dev/null 2>&1; then
          echo Submariner already installed in $cluster_id, skipping submariner helm installation...
      else
          echo Installing Submariner in $cluster_id...
          helm_install_subm $cluster_id true ${cluster_CIDRs[$cluster_id]} ${service_CIDRs[$cluster_id]} ${global_CIDRs[$cluster_id]}
      fi
    done
}

function deploytool_postreqs() {
    # This function must exist for parity with Operator deploys, but does nothing for Helm
    :
}
