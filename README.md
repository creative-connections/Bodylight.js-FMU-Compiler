# Bodylight.js FMU Compiler

This is a Docker image facilitating compilation of FMU files with embedded
source code to JavaScript.

Currently supporting FMUs from Dymola.

## Docker install

Install Windows Subsystem for Linux

## Usage
Put `name.fmu` files into the `input` directory. After the compilation finishes,
`input/name.fmu` is deleted and the resulting `name.js` file is copied to
`output`. Along with the compilation log `name.log`.

Files are processed sequentially in alphabetical order.

In case of error, only the compilation log is present in the output directory.
