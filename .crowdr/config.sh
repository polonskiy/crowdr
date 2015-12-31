#!/bin/bash

project="eval"
name_format="%s-%s"

config="
foo image busybox
foo command sh -c 'trap \"echo BYE; exit\" TERM; while true; do date; sleep 1; done'
foo after.run source $CROWDR_DIR/message.sh
"
somevar='hi the111re!'
