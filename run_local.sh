#!/usr/bin/env bash

# Usage: ./run.sh [filename.fmu]
# output will be written to /output directory
# any file appearing in /input will be compiled
export COMPILER_HOME=`pwd`
if [ -d /home/vagrant/emsdk ]; then
  cd /home/vagrant/emsdk
elif [ -d /home/vagrant/emsdk-master ]; then
  cd /home/vagrant/emsdk-master
fi
./emsdk activate latest
source ./emsdk_env.sh

if [ -f "/home/vagrant/jupyter/etc/profile.d/conda.sh" ]; then
  . "/home/vagrant/jupyter/etc/profile.d/conda.sh"
else
  export PATH="/home/vagrant/jupyter/bin:$PATH"
fi
conda activate
python3 --version 
cd $COMPILER_HOME/compiler
. ./worker.sh
