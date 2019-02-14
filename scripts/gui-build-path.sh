#!/bin/bash

TYPE=$1
PREFIX=$2

if [ -z "$TYPE" ]; then exit 1; fi
if [ -z "$PREFIX" ]; then exit 2; fi

if [ "$TYPE" == "oz-worker" ]; then
  FILE_NAME="oz_gui_static.tar.gz"
else
  FILE_NAME="gui_static.tar.gz"
fi

if [[ "$TYPE" == o?-panel ]]; then
  REPO_DIR="onepanel"
else
  REPO_DIR=$TYPE
fi

SHA=`shasum -a 256 $PREFIX/$REPO_DIR/_build/default/lib/$FILE_NAME | cut -d ' ' -f 1`

case "$TYPE" in
  oz-worker)
    GUI_DIR="oz"
    ;;
  op-worker)
    GUI_DIR="op"
    ;;
  op-panel)
    GUI_DIR="opp"
    ;;
  oz-panel)
    GUI_DIR="ozp"
    ;;
  *)
    exit 3
esac

echo "$PREFIX/oz-worker/_build/default/rel/oz_worker/data/gui_static/$GUI_DIR/$SHA"
