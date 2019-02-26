# Bodylight.js FMU Compiler

This is a Docker image facilitating compilation of FMU files with embedded
source code to JavaScript.

Currently supporting FMUs from Dymola.

## Installation

1. Install [docker](https://docs.docker.com/install/)

2. Build docker image
```bash
sudo docker build -t bodylight.fmu.compiler "$(pwd)"
```

3. Start the worker script
```bash
sudo docker run -d \
  --name bodylight.fmu.compiler \
  --mount type=bind,source="$(pwd)"/input,target=/input \
  --mount type=bind,source="$(pwd)"/output,target=/output \
  bodylight.fmu.compiler:latest bash worker.sh
```

## Usage
Put `name.fmu` files into the `input` directory. After the compilation finishes,
`input/name.fmu` is deleted and the resulting `name.js` file is copied to
`output`. Along with the compilation log `name.log`.

Files are processed sequentially in alphabetical order.

In case of error, only the compilation log will be present in the output directory.
