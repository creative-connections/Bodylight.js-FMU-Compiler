#!/bin/bash
set -ex
echo script version 2503 for Dymola FMU with CVODE compiler to WebAssembly Dockerized

# Keep directories relative to host working dir
current_dir="`pwd`"
build_dir="`pwd`/build_wasm"
fmu_dir="`pwd`/fmu"
sources_dir="`pwd`/jsglue"
fmudiff_dir="`pwd`/fmudiff"
cvode_dir="`pwd`/lib_cvode5.4.0"
cvode_include="`pwd`/include"

OPTIMIZED=0

# Parse options
while getopts ":o" opt; do
  case "$opt" in
    o) OPTIMIZED=1 ;;
    \?) echo "Usage: $0 [-o] input" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# Positional argument: input
INPUT="$1"

if [ "$OPTIMIZED" -eq 1 ]; then
  EMCC_FLAGS="$EMCC_BASE_FLAGS -O3 --closure 1 -g0"
else
  EMCC_FLAGS="$EMCC_BASE_FLAGS -O0 -g4 --closure 0"
fi

# Clean and extract
rm -rf "$build_dir"
rm -rf "$fmu_dir"
mkdir -p "$fmu_dir"
mkdir -p "$build_dir"
unzip -q "$1" -d "$fmu_dir"

#name=$(xmllint "$fmu_dir"/modelDescription.xml --xpath "string(//CoSimulation/@modelIdentifier)")
name=$(awk 'BEGIN{RS="<CoSimulation";FS="\""} NR>1{for(i=1;i<NF;i++) if($i~/modelIdentifier=/){print $(i+1);exit}}' "$fmu_dir/modelDescription.xml")
model_name=$name

# patch external solvers
#cp -r patch/* fmu/

#name="$2"
zipfile="$current_dir/$name.zip"
[ -f "$zipfile" ] && rm "$zipfile"

docker run --rm  -u $(id -u):$(id -g) -v "$current_dir":/src -w /src emscripten/emsdk \
emcc /src/fmu/sources/all.c /src/jsglue/glue.c \
    -I/src/fmu/sources \
    -I/src/include \
    -lm \
    $EMCC_FLAGS \
    -s WASM=1 \
    -s SINGLE_FILE=1 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME=\"$name\" \
    -o /src/build_wasm/$name.js \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s ASSERTIONS=2 \
    -s STACK_SIZE=2097152 \
    -s RESERVED_FUNCTION_POINTERS=20 \
    -s "BINARYEN_METHOD='native-wasm'" \
-s EXPORTED_FUNCTIONS="['_${model_name}_fmi2CancelStep',
'_${model_name}_fmi2CompletedIntegratorStep',
'_${model_name}_fmi2DeSerializeFMUstate',
'_${model_name}_fmi2DoStep',
'_${model_name}_fmi2EnterContinuousTimeMode',
'_${model_name}_fmi2EnterEventMode',
'_${model_name}_fmi2EnterInitializationMode',
'_${model_name}_fmi2ExitInitializationMode',
'_${model_name}_fmi2FreeFMUstate',
'_${model_name}_fmi2FreeInstance',
'_${model_name}_fmi2GetBoolean',
'_${model_name}_fmi2GetBooleanStatus',
'_${model_name}_fmi2GetContinuousStates',
'_${model_name}_fmi2GetDerivatives',
'_${model_name}_fmi2GetDirectionalDerivative',
'_${model_name}_fmi2GetEventIndicators',
'_${model_name}_fmi2GetFMUstate',
'_${model_name}_fmi2GetInteger',
'_${model_name}_fmi2GetIntegerStatus',
'_${model_name}_fmi2GetNominalsOfContinuousStates',
'_${model_name}_fmi2GetReal',
'_${model_name}_fmi2GetRealOutputDerivatives',
'_${model_name}_fmi2GetRealStatus',
'_${model_name}_fmi2GetStatus',
'_${model_name}_fmi2GetString',
'_${model_name}_fmi2GetStringStatus',
'_${model_name}_fmi2GetTypesPlatform',
'_${model_name}_fmi2GetVersion',
'_${model_name}_fmi2Instantiate',
'_${model_name}_fmi2NewDiscreteStates',
'_${model_name}_fmi2Reset',
'_${model_name}_fmi2SerializedFMUstateSize',
'_${model_name}_fmi2SerializeFMUstate',
'_${model_name}_fmi2SetBoolean',
'_${model_name}_fmi2SetContinuousStates',
'_${model_name}_fmi2SetDebugLogging',
'_${model_name}_fmi2SetFMUstate',
'_${model_name}_fmi2SetInteger',
'_${model_name}_fmi2SetReal',
'_${model_name}_fmi2SetRealInputDerivatives',
'_${model_name}_fmi2SetString',
'_${model_name}_fmi2SetTime',
'_${model_name}_fmi2SetupExperiment',
'_${model_name}_fmi2Terminate',
'_createFmi2CallbackFunctions',
'_snprintf',
'_calloc',
'_malloc',
'_free']" \
    -s EXPORTED_RUNTIME_METHODS="[
'FS_createFolder',
'FS_createPath',
'FS_createDataFile',
'FS_createPreloadedFile',
'FS_createLazyFile',
'FS_createLink',
'FS_createDevice',
'FS_unlink',
'addFunction',
'ccall',
'cwrap',
'setValue',
'getValue',
'ALLOC_NORMAL',
'ALLOC_STACK',
'allocate',
'AsciiToString',
'stringToAscii',
'UTF8ArrayToString',
'UTF8ToString',
'stringToUTF8Array',
'stringToUTF8',
'lengthBytesUTF8',
'stackTrace',
'addOnPreRun',
'addOnInit',
'addOnPreMain',
'addOnExit',
'addOnPostRun',
'intArrayFromString',
'intArrayToString',
'writeStringToMemory',
'writeArrayToMemory',
'writeAsciiToMemory',
'addRunDependency',
'removeRunDependency',
'HEAPU8']";    

# 12/2025 TK removed 'ALLOC_STATIC',        'ALLOC_DYNAMIC',        'ALLOC_NONE','getMemory',        'Pointer_stringify',
# Package outputs on host side (normal host shell commands)
if [ -f "$build_dir/$name.js" ] ; then
    cp "$fmu_dir/modelDescription.xml" "$build_dir/$name.xml"
    zip -j "$zipfile" "$build_dir/$name.js" "$build_dir/$name.xml"
    mkdir -p "$fmu_dir/binaries/wasm32"
    cp "$build_dir/$name.js" "$fmu_dir/binaries/wasm32"
    (cd "$fmu_dir" && zip -ur ../"$1" binaries/wasm32)
fi

#rm -rf "$build_dir"
#rm -rf "$fmu_dir"

exit 0







#!/bin/bash
set -x
build_dir="build"
#flags_file="../output/flags"
fmu_dir="$build_dir/fmu"
sources_dir=`pwd`/sources

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 INPUT_FMU EXPORT_NAME"
    exit 1
fi

if [ -d "$fmu_dir" ]; then
    rm -rf $fmu_dir;
fi
mkdir -p "$fmu_dir"
unzip -q $1 -d "$fmu_dir"

name=$2
zipfile="$build_dir/$name.zip"
if [ -f $zipfile ] ; then
    rm $zipfile
fi

model_name=$(xmllint "$fmu_dir"/modelDescription.xml --xpath "string(//CoSimulation/@modelIdentifier)")

cp "$fmu_dir/modelDescription.xml" "$build_dir/$name.xml"

# 21.11.2021 - TK O2 to O0 - zero optimization, from deprecated (EXTRA_E...) to EXPORTED_RUNTIME_METHODS
# 3.12.2021 TK O0 produced outofmemory in chrome for some models - try O3, closure 0 (instead of closure 1)
# 9.12.2021 TK removed -O3 --closure 0 - now in flags file - can be set externally
# 21.12.2023 TK removed --post-js sources/glue.js --bug in emscripten seems to be fixed
emcc $fmu_dir/sources/all.c \
    sources/glue.c \
    -I$sources_dir/fmi \
    -I$fmu_dir/sources \
    -lm \
    -s MODULARIZE=1 \
    -s EXPORT_NAME=\"$2\" \
    -o $build_dir/$2.js \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s WASM=1 \
    -g0 \
    -D linux \
    -s ASSERTIONS=2 \
    -s SINGLE_FILE=1 \
    -s RESERVED_FUNCTION_POINTERS=20 \
    -s "BINARYEN_METHOD='native-wasm'" \
    -s EXPORTED_FUNCTIONS="['_${model_name}_fmi2CancelStep',
        '_${model_name}_fmi2CompletedIntegratorStep',
        '_${model_name}_fmi2DeSerializeFMUstate',
        '_${model_name}_fmi2DoStep',
        '_${model_name}_fmi2EnterContinuousTimeMode',
        '_${model_name}_fmi2EnterEventMode',
        '_${model_name}_fmi2EnterInitializationMode',
        '_${model_name}_fmi2ExitInitializationMode',
        '_${model_name}_fmi2FreeFMUstate',
        '_${model_name}_fmi2FreeInstance',
        '_${model_name}_fmi2GetBoolean',
        '_${model_name}_fmi2GetBooleanStatus',
        '_${model_name}_fmi2GetContinuousStates',
        '_${model_name}_fmi2GetDerivatives',
        '_${model_name}_fmi2GetDirectionalDerivative',
        '_${model_name}_fmi2GetEventIndicators',
        '_${model_name}_fmi2GetFMUstate',
        '_${model_name}_fmi2GetInteger',
        '_${model_name}_fmi2GetIntegerStatus',
        '_${model_name}_fmi2GetNominalsOfContinuousStates',
        '_${model_name}_fmi2GetReal',
        '_${model_name}_fmi2GetRealOutputDerivatives',
        '_${model_name}_fmi2GetRealStatus',
        '_${model_name}_fmi2GetStatus',
        '_${model_name}_fmi2GetString',
        '_${model_name}_fmi2GetStringStatus',
        '_${model_name}_fmi2GetTypesPlatform',
        '_${model_name}_fmi2GetVersion',
        '_${model_name}_fmi2Instantiate',
        '_${model_name}_fmi2NewDiscreteStates',
        '_${model_name}_fmi2Reset',
        '_${model_name}_fmi2SerializedFMUstateSize',
        '_${model_name}_fmi2SerializeFMUstate',
        '_${model_name}_fmi2SetBoolean',
        '_${model_name}_fmi2SetContinuousStates',
        '_${model_name}_fmi2SetDebugLogging',
        '_${model_name}_fmi2SetFMUstate',
        '_${model_name}_fmi2SetInteger',
        '_${model_name}_fmi2SetReal',
        '_${model_name}_fmi2SetRealInputDerivatives',
        '_${model_name}_fmi2SetString',
        '_${model_name}_fmi2SetTime',
        '_${model_name}_fmi2SetupExperiment',
        '_${model_name}_fmi2Terminate',
        '_createFmi2CallbackFunctions',
        '_snprintf',
        '_calloc',
        '_free']" \
    -s EXPORTED_RUNTIME_METHODS="[
        'FS_createFolder',
        'FS_createPath',
        'FS_createDataFile',
        'FS_createPreloadedFile',
        'FS_createLazyFile',
        'FS_createLink',
        'FS_createDevice',
        'FS_unlink',
        'addFunction',
        'ccall',
        'cwrap',
        'setValue',
        'getValue',
        'ALLOC_NORMAL',
        'ALLOC_STACK',
        'ALLOC_STATIC',
        'ALLOC_DYNAMIC',
        'ALLOC_NONE',
        'allocate',
        'getMemory',
        'Pointer_stringify',
        'AsciiToString',
        'stringToAscii',
        'UTF8ArrayToString',
        'UTF8ToString',
        'stringToUTF8Array',
        'stringToUTF8',
        'lengthBytesUTF8',
        'stackTrace',
        'addOnPreRun',
        'addOnInit',
        'addOnPreMain',
        'addOnExit',
        'addOnPostRun',
        'intArrayFromString',
        'intArrayToString',
        'writeStringToMemory',
        'writeArrayToMemory',
        'writeAsciiToMemory',
        'addRunDependency',
        'removeRunDependency']" \
    $(< ../output/flags);

if [ -f "$build_dir/$name.js"  ] ; then
    zip -j $zipfile "$build_dir/$name.js" "$build_dir/$name.xml"
fi
#rm "$build_dir/$name.js"
#rm "$build_dir/$name.xml"

# Package outputs on host side (normal host shell commands)
if [ -f "$build_dir/$name.js" ] ; then
    cp "$fmu_dir/modelDescription.xml" "$build_dir/$name.xml"
    zip -j "$zipfile" "$build_dir/$name.js" "$build_dir/$name.xml"
    mkdir -p "$fmu_dir/binaries/wasm32"
    cp "$build_dir/$name.js" "$fmu_dir/binaries/wasm32"
    (cd "$fmu_dir" && zip -ur ../"$1" binaries/wasm32)
fi

#rm -rf "$build_dir"
#rm -rf "$fmu_dir"

exit 0
