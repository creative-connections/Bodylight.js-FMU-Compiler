#!/bin/bash

build_dir="/home/vagrant/Bodylight.js-FMU-Compiler/compiler/build"
fmu_dir="$build_dir/fmu"
sources_dir="/home/vagrant/Bodylight.js-FMU-Compiler/compiler/sources"
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
cppf1=""
cppflagsconf="-DOMC_MINIMAL_METADATA=1 -I$sources_dir/fmi"

cp "$fmu_dir/modelDescription.xml" "$build_dir/"

cd "$fmu_dir/sources"
emconfigure ./configure \
    CFLAGS='-Wno-unused-value -Wno-logical-op-parentheses' \
    CPPFLAGS="-DOMC_MINIMAL_METADATA=1 -I$sources_dir/fmi"

emmake make -Wno-unused-value

cd "$fmu_dir"

emcc "$fmu_dir/binaries/linux64/$model_name.so" \
    "$sources_dir/glue.c" \
    --post-js "$sources_dir/glue.js" \
    -I"$sources_dir/fmi" \
    -lm \
    -s MODULARIZE=1 \
    -s EXPORT_NAME=$name \
    -o "$name.js" \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s WASM=1 \
    -O2 \
    -g0 \
    --closure 1 \
    -s SINGLE_FILE=1 \
    -s ASSERTIONS=2 \
    -s RESERVED_FUNCTION_POINTERS=50 \
    -s "BINARYEN_METHOD='native-wasm'" \
    -s EXPORTED_FUNCTIONS="['_fmi2DoStep',
        '_fmi2CompletedIntegratorStep',
        '_fmi2DeSerializeFMUstate',
        '_fmi2DoStep',
        '_fmi2EnterContinuousTimeMode',
        '_fmi2EnterEventMode',
        '_fmi2EnterInitializationMode',
        '_fmi2ExitInitializationMode',
        '_fmi2FreeFMUstate',
        '_fmi2FreeInstance',
        '_fmi2GetBoolean',
        '_fmi2GetBooleanStatus',
        '_fmi2GetContinuousStates',
        '_fmi2GetDerivatives',
        '_fmi2GetDirectionalDerivative',
        '_fmi2GetEventIndicators',
        '_fmi2GetFMUstate',
        '_fmi2GetInteger',
        '_fmi2GetIntegerStatus',
        '_fmi2GetNominalsOfContinuousStates',
        '_fmi2GetReal',
        '_fmi2GetRealOutputDerivatives',
        '_fmi2GetRealStatus',
        '_fmi2GetStatus',
        '_fmi2GetString',
        '_fmi2GetStringStatus',
        '_fmi2GetTypesPlatform',
        '_fmi2GetVersion',
        '_fmi2Instantiate',
        '_fmi2NewDiscreteStates',
        '_fmi2Reset',
        '_fmi2SerializedFMUstateSize',
        '_fmi2SerializeFMUstate',
        '_fmi2SetBoolean',
        '_fmi2SetContinuousStates',
        '_fmi2SetDebugLogging',
        '_fmi2SetFMUstate',
        '_fmi2SetInteger',
        '_fmi2SetReal',
        '_fmi2SetRealInputDerivatives',
        '_fmi2SetString',
        '_fmi2SetTime',
        '_fmi2SetupExperiment',
        '_fmi2Terminate',
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

zip -j $zipfile "$fmu_dir/$name.js" "$build_dir/modelDescription.xml"

rm "$fmu_dir/$name.js"
rm "$build_dir/modelDescription.xml"
