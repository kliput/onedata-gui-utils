#!/bin/bash

# one of: onezone, oneprovider-krakow
[ -z ${NODE_PREFIX+x} ] && NODE_PREFIX=onezone
# one of: op-worker, op-panel, oz-worker, oz-panel
[ -z ${SERVICE_TYPE+x} ] && SERVICE_TYPE=oz-panel
BASE_DIR=$HOME/.one-env/deployments
DEPLOYMENT_DIR=`ls -t $HOME/.one-env/deployments/ | head -1`
echo $BASE_DIR/$DEPLOYMENT_DIR/$NODE_PREFIX/$NODE_PREFIX-node-1-$SERVICE_TYPE-rel/data/gui_static

# NOTE: known paths
# onezone/onezone-node-1-oz-worker-rel
# onezone/onezone-node-1-oz-panel-rel
# oneprovider-krakow/oneprovider-krakow-node-1-op-panel-rel/
# oneprovider-krakow/oneprovider-krakow-node-1-op-worker-rel/
