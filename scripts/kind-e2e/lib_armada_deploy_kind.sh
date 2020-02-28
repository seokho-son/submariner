#!/bin/bash
# This should only be sourced
if [ "${0##*/}" = "lib_armada_deploy_kind.sh" ]; then
    echo "Don't run me, source me" >&2
    exit 1
fi

### Variables ###

kubecfgs_rel_dir=scripts/output/kube-config/container/
kubecfgs_dir=${DAPPER_SOURCE}/$kubecfgs_rel_dir

### Functions ###

function create_kind_clusters() {
    version=$2
    deploy=$3

    # FIXME: Somehow don't leak helm/operator-specific logic into this lib
    if [[ $deploy = operator ]]; then
        /usr/bin/armada create clusters --image=kindest/node:v${version} -n 3 --weave
    elif [ "$deploy" = helm ]; then
        /usr/bin/armada create clusters --image=kindest/node:v${version} -n 3 --weave --tiller
    fi
}

function import_subm_images() {
    docker tag quay.io/submariner/submariner:dev submariner:local
    docker tag quay.io/submariner/submariner-route-agent:dev submariner-route-agent:local

    /usr/bin/armada load docker-images --clusters cluster1,cluster2,cluster3 --images submariner:local,submariner-route-agent:local
}

function destroy_kind_clusters() {
    /usr/bin/armada destroy clusters
}
