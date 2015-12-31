#!/bin/bash

project="coolvars"
name_format="%s-%s"

somevar='hi there!'

config="
foo image busybox
foo command sleep 1
foo after.run source $CROWDR_DIR/message.sh
"
