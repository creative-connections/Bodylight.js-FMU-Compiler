#!/bin/bash

build_dir="build"
fmu_dir="$build_dir/fmu"

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

cp "$fmu_dir/modelDescription.xml" "$build_dir/"


emcc $fmu_dir/sources/all.c \
    sources/glue.c \
    --post-js sources/glue.js \
    -Isources/fmi \
    -I$fmu_dir/sources \
    -lm \
    -s MODULARIZE=1 \
    -s EXPORT_NAME=\"$2\" \
    -o $build_dir/$2.js \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s WASM=1 \
    -O2 \
    -g0 \
    --closure 1 \
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
    -s EXTRA_EXPORTED_RUNTIME_METHODS="[
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
        'removeRunDependency']";


zip -j $zipfile "$build_dir/$name.js" "$build_dir/modelDescription.xml"

rm "$build_dir/$name.js"
rm "$build_dir/modelDescription.xml"
