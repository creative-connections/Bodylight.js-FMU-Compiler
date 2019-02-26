# Bodylight.js FMU Compiler

This is a Docker container facilitating compilation of FMU files with embedded
source code to JavaScript.

Currently supports FMUs exported from Dymola (with sources).

## Installation

1. Install [docker](https://docs.docker.com/install/)

2. Clone this repository and cd inside

2. Build the docker image
```bash
docker build -t bodylight.fmu.compiler "$(pwd)"
```
 This builds the Dockerfile as bodylight.fmu.compiler. This might take a while, as it downloads about 400 MiBs of a docker image from the internet.

 You might need to run this command with root privileges.

## Starting the compiler
```bash
docker run -d \
  --name bodylight.fmu.compiler \
  --mount type=bind,source="$(pwd)"/input,target=/input \
  --mount type=bind,source="$(pwd)"/output,target=/output \
  bodylight.fmu.compiler:latest bash worker.sh
```
This starts the docker container and binds the `input` and `output` directories.

## Stopping the compiler
```bash
docker stop bodylight.fmu.compiler
```

## Usage

Put `name.fmu` files into the `input` directory. After the compilation finishes,
`input/name.fmu` is deleted and the resulting `name.js` file is copied to
`output`. Along with the compilation log `name.log`.

Files are processed sequentially in alphabetical order.

In case of error, only the compilation log will be present in the output directory.
