#!/bin/bash

sudo docker run -d \
  --name bodylight.js.fmu.compiler \
  --mount type=bind,source="$(pwd)"/input,target=/input \
  --mount type=bind,source="$(pwd)"/output,target=/output \
  bodylight.js.fmu.compiler:latest
