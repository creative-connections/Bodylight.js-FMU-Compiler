    #!/bin/bash
set -x
echo script version 2401 for OM FMU with CVODE
emcc -v
# 1. set build dir, source dir for FMU glue files relative to current dir
build_dir="`pwd`/build"
fmu_dir="`pwd`/fmu"
sources_dir="`pwd`/sources"
fmudiff_dir="`pwd`/fmudiff"
cvode_dir="`pwd`/lib"
cvode_include="`pwd`/include"

# 2. check arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 INPUT_FMU EXPORT_NAME"
    exit 1
fi

# 3. clean fmu dir, and unzip FMU into it
if [ -d "$fmu_dir" ]; then
    rm -rf $fmu_dir;
fi
mkdir -p "$fmu_dir"
unzip -q $1 -d "$fmu_dir"

# 3.a patch the fmu sources in order to upgrade from sundials 5.x to sundials 6.x

cp -R "$fmudiff_dir/sources/"* "$fmu_dir/sources/"

# 4. zip file will be named as argument 2, if it exists, remove first
name=$2
echo NAME:$name

## replace dots with underscore
#name2="${name//./_}"
zipfile="$build_dir/$name.zip"
if [ -f $zipfile ] ; then
    rm $zipfile
fi

# 5. extract model name from description
model_name=$(xmllint "$fmu_dir"/modelDescription.xml --xpath "string(//CoSimulation/@modelIdentifier)")

# 6. set compilation flags

# 7. copy modelDescription.xml to $name.xml - it is used to recognize multiple XMLs in apps.
cp "$fmu_dir/modelDescription.xml" "$build_dir/$name.xml"

# 8. configure FMU compilation from C sources
#cd $build_dir
cd $fmu_dir/sources

#
emconfigure ./configure \
 CFLAGS="-DBUILD_SHARED_LIBS=OFF -DNEED_CVODE -DCVODE_DIRECTORY=$cvode_dir -DLINK_SUNDIAL_STATIC=1" \
 CPPFLAGS="-DBUILD_SHARED_LIBS=OFF -DRUNTIME_DEPENDENDCIES_LEVEL=modelica -DNEED_CVODE -DOMC_FMI_RUNTIME=1 -DLINK_SUNDIAL_STATIC=1 -I$sources_dir/fmi -I/usr/local/include -I$cvode_include -DCVODE_DIRECTORY=$cvode_dir"
 
 #-DCVODE_DIRECTORY=$cvode_dir -I$sources_dir/fmi -I/usr/local/include -I$cvode_include"

# 9. make
#cd $build_dir
emmake make -Wno-unused-value

## 10. link and create JS with emcc
emcc "$sources_dir/glue.c" "$fmu_dir/binaries/linux64/$model_name.so" $cvode_dir/libsundials_cvode.a $cvode_dir/libsundials_nvecserial.a \
    --post-js "$sources_dir/glue.js" \
    --embed-file $fmu_dir/resources@/ \
    -v \
    -g3 \
    -gsource-map \
    -lm -lsundials_cvode -lsundials_nvecserial \
    -L$cvode_dir \
    -I"$sources_dir/fmi" \
    -I"$fmu_dir/sources" \
    -I"$cvode_include" \
    -I/usr/local/include \
    -DWITH_SUNDIALS -DOMC_FMI_RUNTIME=1 -DLINK_SUNDIAL_STATIC=ON \
    -s MODULARIZE=1 \
    -s EXPORT_NAME=$name \
    -o "$build_dir/$name.js" \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s WASM=1 \
    -O0 \
    --closure 0 \
    -s SINGLE_FILE=1 \
    -s ASSERTIONS=2 \
    -s RESERVED_FUNCTION_POINTERS=80 \
    -s"BINARYEN_METHOD='native-wasm'" \
    -sEXPORTED_FUNCTIONS="['_${model_name}_fmi2DoStep',
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
        '_cvode_solver_initial',
        '_cvode_solver_deinitial',
        '_cvode_solver_fmi_step',
        '_snprintf',
        '_main',
        '_calloc',
        '_malloc',
        '_free']" \
    -sEXPORTED_RUNTIME_METHODS="[
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
        'removeRunDependency']"

# 11. create ZIP file with JS and XML
if [ -f "$build_dir/$name.js"  ] ; then
    zip -j $zipfile "$build_dir/$name.js" "$build_dir/$name.xml"
fi

rm "$build_dir/$name.js"
rm "$build_dir/$name.xml"

exit 0




# unused script from previous version

emconfigure ./configure \
    CFLAGS='-Wno-unused-value -Wno-logical-op-parentheses' \
    CPPFLAGS="-DNEED_CVODE -DWITH_SUNDIALS -DOMC_FMI_RUNTIME=1 -DLINK_SUNDIAL_STATIC=1 -DOMC_MINIMAL_METADATA=1 -I$sources_dir/fmi -I/usr/local/include"

emmake make -Wno-unused-value

pwd
cd "$fmu_dir"
pwd
#cat "$fmu_dir"/../../../output/flags
# 1. embed resource files --embed-file resources/Physiolibrary_Hydraulic_Examples_Fernandez2013_PulsatileCirculation_flags.json@/resources/Physiolibrary_Hydraulic_Examples_Fernandez2013_PulsatileCirculation_flags.json 
# 2. link JS and WASM file to produce single file
# 3. link sundials cvode into JS 
#    -L/home/tomas/sundials-6.7.0/buildjs/src/cvode/ -L/home/tomas/sundials-6.7.0/buildjs/src/nvector/serial/ 
#    -lm -lsundials_cvode -lsundials_nvecserial
# to include, force libs   -Wl,-whole-archive \
#     --embed-file resources/Physiolibrary_Hydraulic_Examples_Fernandez2013_PulsatileCirculation_flags.json@/resources/Physiolibrary_Hydraulic_Examples_Fernandez2013_PulsatileCirculation_flags.json \
# /home/tomas/sundials-6.7.0/buildjs/src/cvode/libsundials_cvode.a /home/tomas/sundials-6.7.0/buildjs/src/nvector/serial/libsundials_nvecserial.a
emcc -DWITH_SUNDIALS -DOMC_FMI_RUNTIME=1 -DNEED_CVODE /home/tomas/sundials-6.7.0/buildjs/src/cvode/libsundials_cvode.a /home/tomas/sundials-6.7.0/buildjs/src/nvector/serial/libsundials_nvecserial.a "$fmu_dir/binaries/linux64/$model_name.so" \
    "$sources_dir/glue.c" "$build_dir/fmu/sources/simulation/solver/cvode_solver.c" \
    --post-js "$sources_dir/glue.js" \
    --embed-file resources@/ \
    --embed-file /home/tomas/sundials-6.7.0/buildjs/src/cvode/libsundials_cvode.a@/libsundials_cvode.a \
    --embed-file /home/tomas/sundials-6.7.0/buildjs/src/nvector/serial/libsundials_nvecserial.a@/libsundials_nvecserial.a \
    -v \
    -g3 \
    -gsource-map \
    -lm -lsundials_cvode -lsundials_nvecserial \
    -L/home/tomas/sundials-6.7.0/buildjs/src/cvode/ -L/home/tomas/sundials-6.7.0/buildjs/src/nvector/serial/ \
    -I"$sources_dir/fmi" \
    -I"$build_dir/fmu/sources" \
    -I/usr/local/include \
    -s MODULARIZE=1 \
    -s EXPORT_NAME=$name \
    -o "$name.js" \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s WASM=1 \
    -O0 \
    --closure 0 \
    -s SINGLE_FILE=1 \
    -s ASSERTIONS=2 \
    -s RESERVED_FUNCTION_POINTERS=80 \
    -s"BINARYEN_METHOD='native-wasm'" \
    -sEXPORTED_FUNCTIONS="['_${model_name}_fmi2DoStep',
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
        '_main',
        '_calloc',
        '_malloc',
        '_free']" \
    -sEXPORTED_RUNTIME_METHODS="[
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
        'removeRunDependency']"

# TomasK 31.01.2022: try to removed flags if error happens     'ALLOC_STATIC',        'ALLOC_DYNAMIC',        'ALLOC_NONE',        'getMemory',        'Pointer_stringify',
#     -s LLD_REPORT_UNDEFINED \
# wasm-ld: error: symbol exported via --export not found: __stop_em_asm
# wasm-ld: error: symbol exported via --export not found: __start_em_asm
# tomask 26.12.2023 removed         'ALLOC_STATIC',        'ALLOC_DYNAMIC', 'ALLOC_NONE',         'getMemory',        'Pointer_stringify',


# 3. create ZIP file with JS and XML

if [ -f "$fmu_dir/$name.js"  ] ; then
    zip -j $zipfile "$fmu_dir/$name.js" "$build_dir/$name.xml"
fi

rm "$fmu_dir/$name.js"
rm "$build_dir/$name.xml"
