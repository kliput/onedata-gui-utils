#!/bin/bash

DIR_PREFIX=$1

if [ -z "$DIR_PREFIX" ]; then exit 1; fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

OPP_STANDALONE=$DIR_PREFIX/onepanel/_build/default/rel/op_panel/data/gui_static/
OZP_STANDALONE=$DIR_PREFIX/onepanel/_build/default/rel/oz_panel/data/gui_static/
OZP_HOSTED=`$SCRIPT_DIR/gui-build-path.sh oz-panel $DIR_PREFIX`
OPP_HOSTED=`$SCRIPT_DIR/gui-build-path.sh op-panel $DIR_PREFIX`

for DEPLOY_DIR in $OPP_STANDALONE $OZP_STANDALONE $OZP_HOSTED $OPP_HOSTED; do
  if [ "$DEPLOY_DIR" != "" ]; then
    echo "Deploying to $DEPLOY_DIR"
    mkdir -p $DEPLOY_DIR
    cp -r * $DEPLOY_DIR
  fi
done
