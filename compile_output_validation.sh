#/bin/bash

build_dir="build/validation"
sources_dir="sources/validation"
fmi_dir="sources/fmi"

wasm_dir="$build_dir/wasm"
wasm_sources="$sources_dir/wasm"
c_dir="$build_dir/c"
c_sources="$sources_dir/c"
fmu_dir="$build_dir/fmu"
lib_dir="$sources_dir/lib"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 INPUT_FMU time stepsize variable [tolerance]"
  exit 1
fi

# cleanup previous builds
if [ -d "$build_dir" ]; then rm -rf $build_dir; fi
if [ -d "$fmu_dir" ]; then rm -rf $fmu_dir; fi
mkdir -p "$fmu_dir"
if [ -d "$wasm_dir" ]; then rm -rf $wasm_dir; fi
mkdir -p "$wasm_dir"

# extract FMU
unzip -q $1 -d "$fmu_dir"

if [ "$#" -lt 4 ]; then
  variables=$(xmllint "$fmu_dir"/modelDescription.xml --xpath "//ScalarVariable[not(@causality='parameter')]/@name
  |
  //ScalarVariable[not(@causality='parameter')]/@valueReference")
  variables=$(echo "$variables" | sed 's/name=/\n/g')

  echo "Variables: "
  echo "$variables"
  echo "Usage: $0 INPUT_FMU stoptime stepsize variable [tolerance]"
  exit 1
fi

stoptime=$2
stepsize=$3
variable=$4

if [ "$#" -eq 5 ]; then
  tolerance=$5
else
  tolerance=""
fi

# copy C sources
cp -a $c_sources $build_dir
cp -a $fmu_dir/sources $c_dir

# inject configurables
if [ "$tolerance" ]; then
  sed -i -e 's/{TOLERANCEDEFINED}/fmi2True/g' $c_dir/variables.h
  sed -i -e "s/{TOLERANCE}/${tolerance}/g" $c_dir/variables.h
else
  sed -i -e 's/{TOLERANCEDEFINED}/fmi2False/g' $c_dir/variables.h
  sed -i -e "s/{TOLERANCE}/0.0/g" $c_dir/variables.h
fi
sed -i -e "s/{STOPTIME}/${stoptime}/g" $c_dir/variables.h
sed -i -e "s/{STEPSIZE}/${stepsize}/g" $c_dir/variables.h
sed -i -e "s/{VARIABLE}/${variable}/g" $c_dir/variables.h
sed -i -e "s/{PROFILING}//g" $c_dir/variables.h

# compile C sources
gcc $c_dir/main.c -I$c_dir/. -I$fmi_dir -I$c_dir/sources -I$c_dir/sources/cvode -I$c_dir/sources/nvector -I/$c_dir/sources/sundials -lm -o$c_dir/main.out



model_name=$(xmllint "$fmu_dir"/modelDescription.xml --xpath "string(//CoSimulation/@modelIdentifier)")






exit;
