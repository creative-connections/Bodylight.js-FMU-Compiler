#!/usr/bin/env bash

# Usage: ./run.sh [filename.fmu]
# output will be written to /output directory
# any file appearing in /input will be compiled
# docker earlier verion 1.13.1
docker run -d   --name bodylight.js.fmu.compiler -v $(pwd)/input:/input -v $(pwd)/output:/output  --rm bodylight.js.fmu.compiler:latest bash worker.sh
