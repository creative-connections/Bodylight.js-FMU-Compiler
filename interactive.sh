#!/bin/bash

sudo docker run \
  --mount type=bind,source="$(pwd)"/input,target=/input \
  --mount type=bind,source="$(pwd)"/output,target=/output \
  -it bodylight.js.fmu.compiler:latest bash $1
