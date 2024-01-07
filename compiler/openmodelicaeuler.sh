#!/bin/bash
set -x
echo script version 2.a
build_dir="/home/vagrant/Bodylight.js-FMU-Compiler/compiler/build"
fmu_dir="$build_dir/fmu"
sources_dir="/home/vagrant/Bodylight.js-FMU-Compiler/compiler/sources"
fmu_dir="$build_dir/fmu"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 INPUT_FMU EXPORT_NAME"
    echo "Example: $0 mymodel.fmu mymodel"
    echo "         will create 'mymodel.zip' file containing 'mymodel.js' with fmu model compiled to webassembly and 'mymodel.xml' with model description."
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
# "
cppf1=""
cppflagsconf="-DOMC_MINIMAL_METADATA=1 -I$sources_dir/fmi"

cp "$fmu_dir/modelDescription.xml" "$build_dir/$name.xml"

cd "$fmu_dir/sources"
emconfigure ./configure \
    CFLAGS='-Wno-unused-value -Wno-logical-op-parentheses' \
    CPPFLAGS="-DOMC_MINIMAL_METADATA=1 -I$sources_dir/fmi -I/usr/local/include"

emmake make -Wno-unused-value

# 21.12.2023 TK removed --post-js "$sources_dir/glue.js" 

cd "$fmu_dir"
cat "$fmu_dir"/../../../output/flags
emcc "$fmu_dir/binaries/linux64/$model_name.so" \
    "$sources_dir/glue.c" \
    -I"$sources_dir/fmi" \
    --embed-file $fmu_dir/resources@/ \
    -I/usr/local/include \
    -lm \
    -s MODULARIZE=1 \
    -s EXPORT_NAME=$name \
    -o "$name.js" \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s WASM=1 \
    -g0 \
    -s SINGLE_FILE=1 \
    -s ASSERTIONS=2 \
    -s RESERVED_FUNCTION_POINTERS=50 \
    -s "BINARYEN_METHOD='native-wasm'" \
    -s EXPORTED_FUNCTIONS="['_${model_name}_fmi2DoStep',
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
        'removeRunDependency']" \
     $(< ../../../output/flags);
     
# TomasK 31.01.2022: try to removed flags if error happens     'ALLOC_STATIC',        'ALLOC_DYNAMIC',        'ALLOC_NONE',        'getMemory',        'Pointer_stringify',
#     -s LLD_REPORT_UNDEFINED \
# wasm-ld: error: symbol exported via --export not found: __stop_em_asm
# wasm-ld: error: symbol exported via --export not found: __start_em_asm


if [ -f "$fmu_dir/$name.js"  ] ; then
    zip -j $zipfile "$fmu_dir/$name.js" "$build_dir/$name.xml"
fi

rm "$fmu_dir/$name.js"
rm "$build_dir/$name.xml"
