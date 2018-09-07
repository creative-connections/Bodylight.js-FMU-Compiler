#!/bin/bash

sudo docker run \
  --mount type=bind,source="$(pwd)"/input,target=/input \
  -it bodylight.js.fmu.compiler:latest bash
