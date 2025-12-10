#!/bin/bash
set -x
echo script version 2503 for OM FMU with CVODE compiler to WebAssembly
emcc -v
# 1. set build dir, source dir for FMU glue files relative to current dir
current_dir="`pwd`"
build_dir="`pwd`/build_wasm"
fmu_dir="`pwd`/fmu"
sources_dir="`pwd`/jsglue"
fmudiff_dir="`pwd`/fmudiff"
# compiled WASM of sundials version 5.x - some patches and configuration need to be done to compile it to webassembly
cvode_dir="`pwd`/lib_cvode5.4.0"
# copy of current OM /usr/include/omc/c/fmi
cvode_include="`pwd`/include" 

# 2. check arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 INPUT_FMU"
    exit 1
fi

# 3. clean build dir
rm -rf $build_dir
# clean fmu dir, and unzip FMU into it
if [ -d "$fmu_dir" ]; then
  rm -rf $fmu_dir;
fi 
mkdir -p "$fmu_dir"
unzip -q $1 -d "$fmu_dir"

# patch external solvers
cp -r patch/* "$fmu_dir"

# 4. zip file will be named as argument 2, if it exists, remove first
#name=$2
#name=$(xmllint "$fmu_dir"/modelDescription.xml --xpath "string(//CoSimulation/@modelIdentifier)")
name=$(awk 'BEGIN{RS="<CoSimulation";FS="\""} NR>1{for(i=1;i<NF;i++) if($i~/modelIdentifier=/){print $(i+1);exit}}' "$fmu_dir/modelDescription.xml")

echo NAME:$name

zipfile=$current_dir/$name.zip
if [ -f $zipfile ] ; then
    rm $zipfile
fi

# ?? extract model name from description
#model_name=$(xmllint "$fmu_dir"/modelDescription.xml --xpath "string(//CoSimulation/@modelIdentifier)")
#model_name=$3

# 5. patch cmakelists.txt to accept emscripten
sed -i '/set(FMU_TARGET_SYSTEM_NAME "darwin")/a\
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Emscripten")\
  set(FMU_TARGET_SYSTEM_NAME "emscripten")' $fmu_dir/sources/CMakeLists.txt

# 6. configure FMU compilation from C sources
cd $fmu_dir/sources

# no runtime dependencies - static .a (cvode) libraries are added in 8. emcc step 
#-DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE="-O3" \
#-D SUNDIALS_NVECSERIAL_LIBRARY=$cvode_dir/libsundials_nvecserial.a \
#-D CVODE_DIRECTORY=$cvode_dir \
emcmake cmake -S . -B $build_dir \
-s DISABLE_EXCEPTION_CATCHING=0 \
-s EMULATE_FUNCTION_POINTER_CASTS=1 \
-D RUNTIME_DEPENDENCIES_LEVEL=none \
-D FMI_INTERFACE_HEADER_FILES_DIRECTORY=$cvode_include \
-D NEED_CVODE=ON \
-D SUNDIALS_CVODE_LIBRARY=$cvode_dir/libsundials_cvode.a \
-D SUNDIALS_NVECSERIAL_LIBRARY=$cvode_dir/libsundials_nvecserial.a \
-D WITH_SUNDIALS=1 -D OMC_FMI_RUNTIME=1 -D LINK_SUNDIAL_STATIC=ON \
-DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS="-O0 -fPIC" \
-D CMAKE_TOOLCHAIN_FILE=/home/vagrant/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

# 7. build - no other arguments needed - Emscripten toolchain is configured in previous step
cmake --build $build_dir

# 8. link using emcc and produce WASM embedded in JS
echo 6. emcc
#-sEXPORT_ALL=1 \
#  $cvode_dir/libsundials_cvode.a 
emcc "$sources_dir/glue.c" "$build_dir/$name.a" \
--post-js "$sources_dir/glue.js" \
--embed-file $fmu_dir/resources@/ \
-s DISABLE_EXCEPTION_CATCHING=0 \
-s EMULATE_FUNCTION_POINTER_CASTS=1 \
-v \
-g0 \
-lsundials_cvode \
-L$cvode_dir \
-I"$sources_dir" \
-I"$cvode_include" \
-I/usr/local/include \
-DWITH_SUNDIALS -DOMC_FMI_RUNTIME=1 -DLINK_SUNDIAL_STATIC=ON \
-sMODULARIZE=1 \
-s MAIN_MODULE=1 \
-s LEGALIZE_JS_FFI=0 \
-sEXPORT_NAME=$name \
-o "$build_dir/$name.js" \
-sALLOW_MEMORY_GROWTH=1 \
-sWASM=1 \
-O0 \
--closure 0 \
-D Linux \
-sSINGLE_FILE=1 \
-sASSERTIONS=2 \
-sRESERVED_FUNCTION_POINTERS=80 \
-s"BINARYEN_METHOD='native-wasm'" \
-sEXPORTED_FUNCTIONS="['_CVodeCreate','_fmi2DoStep', \
        '_fmi2Instantiate',\
        '_fmi2CompletedIntegratorStep',\
        '_fmi2DeSerializeFMUstate',\
        '_fmi2EnterContinuousTimeMode',\
        '_fmi2EnterEventMode',\
        '_fmi2EnterInitializationMode',\
        '_fmi2ExitInitializationMode',\
        '_fmi2FreeFMUstate',\
        '_fmi2FreeInstance',\
        '_fmi2GetBoolean',\
        '_fmi2GetBooleanStatus',\
        '_fmi2GetContinuousStates',\
        '_fmi2GetDerivatives',\
        '_fmi2GetDirectionalDerivative',\
        '_fmi2GetEventIndicators',\
        '_fmi2GetFMUstate',\
        '_fmi2GetInteger',\
        '_fmi2GetIntegerStatus', \
        '_fmi2GetNominalsOfContinuousStates', \
        '_fmi2GetReal',\
        '_fmi2GetRealOutputDerivatives',\
        '_fmi2GetRealStatus',\
        '_fmi2GetStatus',\
        '_fmi2GetString',\
        '_fmi2GetStringStatus',\
        '_fmi2GetTypesPlatform',\
        '_fmi2GetVersion',\
        '_fmi2NewDiscreteStates',\
        '_fmi2SerializedFMUstateSize',\
        '_fmi2SerializeFMUstate',\
        '_fmi2SetBoolean',\
        '_fmi2SetContinuousStates',\
        '_fmi2SetDebugLogging',\
        '_fmi2SetFMUstate',\
        '_fmi2SetInteger',\
        '_fmi2SetReal',\
        '_fmi2SetRealInputDerivatives',\
        '_fmi2SetString',\
        '_fmi2SetTime',\
        '_fmi2SetupExperiment',\
        '_fmi2Terminate',\
        '_fmi2Reset',\
        '_createFmi2CallbackFunctions',\
        '_cvode_solver_initial',\
        '_cvode_solver_deinitial',\
        '_cvode_solver_fmi_step',\
        '_snprintf',\
        '_main',\
        '_calloc',\
        '_malloc',\
        '_free']" \
-sEXPORTED_RUNTIME_METHODS="[ \
        'FS_createPath',\
        'FS_createDataFile',\
        'FS_createPreloadedFile',\
        'FS_createLazyFile',\
        'FS_createDevice',\
        'FS_unlink',\
        'addFunction',\
        'ccall',\
        'cwrap',\
        'setValue',\
        'getValue',\
        'ALLOC_NORMAL',\
        'ALLOC_STACK',\
        'AsciiToString',\
        'stringToAscii',\
        'UTF8ArrayToString',\
        'UTF8ToString',\
        'stringToUTF8Array',\
        'stringToUTF8',\
        'lengthBytesUTF8',\
        'stackTrace',\
        'addOnPreRun',\
        'addOnInit',\
        'addOnPreMain',\
        'addOnExit',\
        'addOnPostRun',\
        'intArrayFromString',\
        'intArrayToString',\
        'writeStringToMemory',\
        'writeArrayToMemory',\
        'writeAsciiToMemory',\
        'addRunDependency',\
        'removeRunDependency',\
        'HEAPU8']"

# 11. create ZIP file with JS and XML
if [ -f "$build_dir/$name.js"  ] ; then
    cp "$fmu_dir/modelDescription.xml" "$build_dir/$name.xml"
    zip -j $zipfile "$build_dir/$name.js" "$build_dir/$name.xml"
fi

# 12. create new FMU with JS file as new binary
if [ -f "$build_dir/$name.js"  ] ; then
    mkdir $fmu_dir/binaries/wasm32
    cp $build_dir/$name.js $fmu_dir/binaries/wasm32
    (cd $fmu_dir && zip -ur ../$1 binaries/wasm32)
fi

rm -rf $build_dir
rm -rf $fmu_dir

exit 0
