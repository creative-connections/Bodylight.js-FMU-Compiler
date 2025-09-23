#!/bin/bash
set -ex
echo script version 2503 for OM FMU with CVODE compiler to WebAssembly Dockerized

# Keep directories relative to host working dir
current_dir="`pwd`"
build_dir="`pwd`/build_wasm"
fmu_dir="`pwd`/fmu"
sources_dir="`pwd`/jsglue"
fmudiff_dir="`pwd`/fmudiff"
cvode_dir="`pwd`/lib_cvode5.4.0"
cvode_include="`pwd`/include"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 INPUT_FMU MODEL_NAME"
    exit 1
fi

# Clean and extract
rm -rf "$build_dir"
rm -rf "$fmu_dir"
mkdir -p "$fmu_dir"
mkdir -p "$build_dir"
unzip -q "$1" -d "$fmu_dir"

# patch external solvers
cp -r patch/* fmu/

name="$2"
zipfile="$current_dir/$name.zip"
[ -f "$zipfile" ] && rm "$zipfile"

# Patch CMakeLists.txt, add emscripten as a target
sed -i '/set(FMU_TARGET_SYSTEM_NAME "darwin")/a\
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Emscripten")\
  set(FMU_TARGET_SYSTEM_NAME "emscripten")' "$fmu_dir/sources/CMakeLists.txt"

# Run emcmake cmake inside docker pointing to mounted /src for entire host pwd
docker run --rm  -u $(id -u):$(id -g) -v "$current_dir":/src -w /src/fmu/sources emscripten/emsdk \
  emcmake cmake -S . -B "/src/build_wasm" \
    -D RUNTIME_DEPENDENCIES_LEVEL=none \
    -D FMI_INTERFACE_HEADER_FILES_DIRECTORY="/src/include" \
    -D NEED_CVODE=ON \
    -D SUNDIALS_CVODE_LIBRARY="/src/lib_cvode5.4.0/libsundials_cvode.a" \
    -D SUNDIALS_NVECSERIAL_LIBRARY="/src/lib_cvode5.4.0/libsundials_nvecserial.a" \
    -D WITH_SUNDIALS=1 -D OMC_FMI_RUNTIME=1 -D LINK_SUNDIAL_STATIC=ON \
    -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS="-O0 -fPIC" \
    -D CMAKE_TOOLCHAIN_FILE=/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

# Build inside docker
docker run --rm  -u $(id -u):$(id -g) -v "$current_dir":/src -w /src/fmu/sources emscripten/emsdk \
  cmake --build /src/build_wasm

# version
docker run --rm  -u $(id -u):$(id -g) -v "$current_dir":/src -w /src emscripten/emsdk \
  emcc --version

# Link step inside docker
#  -s DISABLE_EXCEPTION_CATCHING=0 \
#  -s EMULATE_FUNCTION_POINTER_CASTS=1 \
#  --llvm-lto 0 \

docker run --rm  -u $(id -u):$(id -g) -v "$current_dir":/src -w /src emscripten/emsdk \
  emcc "/src/jsglue/glue.c" "/src/build_wasm/$name.a" \
  --post-js "/src/jsglue/glue.js" \
  --embed-file "/src/fmu/resources@/" \
  -v \
  -g0 \
  -lsundials_cvode \
  -L"/src/lib_cvode5.4.0" \
  -I"/src/jsglue" \
  -I"/src/include" \
  -I/usr/local/include \
  -DWITH_SUNDIALS -DOMC_FMI_RUNTIME=1 -DLINK_SUNDIAL_STATIC=ON \
  -sMODULARIZE=1 \
  -s MAIN_MODULE=1 \
  -s LEGALIZE_JS_FFI=0 \
  -sEXPORT_NAME="$name" \
  -o "/src/build_wasm/$name.js" \
  -sALLOW_MEMORY_GROWTH=1 \
  -sWASM=1 \
  -O0 \
  --closure 0 \
  -D Linux \
  -sSINGLE_FILE=1 \
  -sASSERTIONS=2 \
  -sRESERVED_FUNCTION_POINTERS=80 \
  -s"BINARYEN_METHOD='native-wasm'" \
  -sEXPORTED_FUNCTIONS="['_CVodeCreate','_fmi2DoStep',\
'_fmi2Instantiate','_fmi2CompletedIntegratorStep','_fmi2DeSerializeFMUstate',\
'_fmi2EnterContinuousTimeMode','_fmi2EnterEventMode','_fmi2EnterInitializationMode',\
'_fmi2ExitInitializationMode','_fmi2FreeFMUstate','_fmi2FreeInstance','_fmi2GetBoolean',\
'_fmi2GetBooleanStatus','_fmi2GetContinuousStates','_fmi2GetDerivatives',\
'_fmi2GetDirectionalDerivative','_fmi2GetEventIndicators','_fmi2GetFMUstate',\
'_fmi2GetInteger','_fmi2GetIntegerStatus','_fmi2GetNominalsOfContinuousStates',\
'_fmi2GetReal','_fmi2GetRealOutputDerivatives','_fmi2GetRealStatus','_fmi2GetStatus',\
'_fmi2GetString','_fmi2GetStringStatus','_fmi2GetTypesPlatform','_fmi2GetVersion',\
'_fmi2NewDiscreteStates','_fmi2SerializedFMUstateSize','_fmi2SerializeFMUstate',\
'_fmi2SetBoolean','_fmi2SetContinuousStates','_fmi2SetDebugLogging','_fmi2SetFMUstate',\
'_fmi2SetInteger','_fmi2SetReal','_fmi2SetRealInputDerivatives','_fmi2SetString',\
'_fmi2SetTime','_fmi2SetupExperiment','_fmi2Terminate','_fmi2Reset','_createFmi2CallbackFunctions',\
'_cvode_solver_initial','_cvode_solver_deinitial','_cvode_solver_fmi_step',\
'_snprintf','_main','_calloc','_malloc','_free']" \
  -sEXPORTED_RUNTIME_METHODS="['FS_createPath','FS_createDataFile',\
'FS_createPreloadedFile','FS_createLazyFile','FS_createDevice','FS_unlink','addFunction',\
'ccall','cwrap','setValue','getValue','ALLOC_NORMAL','ALLOC_STACK','AsciiToString',\
'stringToAscii','UTF8ArrayToString','UTF8ToString','stringToUTF8Array','stringToUTF8',\
'lengthBytesUTF8','stackTrace','addOnPreRun','addOnInit','addOnPreMain','addOnExit',\
'addOnPostRun','intArrayFromString','intArrayToString','writeStringToMemory',\
'writeArrayToMemory','writeAsciiToMemory','addRunDependency','removeRunDependency','HEAPU8']"

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
