#!/bin/bash
set -e
echo "script version 2512 for FMU (OpenModelica/Dymola auto-detect) with CVODE to WebAssembly Dockerized"

# Keep directories relative to host working dir
current_dir="$(pwd)"
build_dir="$current_dir/build_wasm"
fmu_dir="$current_dir/fmu"
sources_dir="$current_dir/jsglue"
fmudiff_dir="$current_dir/fmudiff"
cvode_dir="$current_dir/lib_cvode5.4.0"
cvode_include="$current_dir/include"

OPTIMIZED=0
WEB_IN_FMU=0
GEN_HTML=0

# Parse options
while getopts ":ows" opt; do
  case "$opt" in
    o) OPTIMIZED=1 ;;
    w) WEB_IN_FMU=1 ;;
    s) GEN_HTML=1 ;;
    \?) echo -e "Usage: $0 [-o] [-w] [-s] input.fmu\n  -o Optimize code, default no\n  -w Embed webassembly in FMU, by default webassembly is only in resulting ZIP\n  -s Generate standalone web app in ZIP\n" >&2; exit 1
  esac
done
shift $((OPTIND - 1))

# Positional argument: input
INPUT="$1"
if [ -z "$INPUT" ]; then
  echo -e "Usage: $0 [-o] [-w] [-s] input.fmu\n  -o Optimize code, default no\n  -w Embed webassembly in FMU, by default webassembly is only in resulting ZIP\n  -s Generate standalone web app in ZIP\n" >&2; exit 1
fi

if [ "$OPTIMIZED" -eq 1 ]; then
  EMCC_FLAGS_BASE="-O3 --closure 1 -g0"
  EMCC_MAKE_FLAGS="-O3 -fPIC"
  EMCC_MAKE_TYPE="Release"
else
  EMCC_FLAGS_BASE="-O0 --closure 0"
  EMCC_MAKE_FLAGS="-O0 -fPIC"
  EMCC_MAKE_TYPE="Debug"
fi

# Clean and extract
rm -rf "$build_dir" "$fmu_dir"
mkdir -p "$fmu_dir" "$build_dir"
unzip -q "$INPUT" -d "$fmu_dir"

# Extract model name and detect tool
name=$(awk 'BEGIN{RS="<CoSimulation";FS="\""} NR>1{for(i=1;i<NF;i++) if($i~/modelIdentifier=/){print $(i+1);exit}}' "$fmu_dir/modelDescription.xml")
model_name=$name
generation_tool=$(awk '/generationTool=/ {gsub(/.*generationTool="|".*/,"",$0);print $0;exit}' "$fmu_dir/modelDescription.xml")

echo "Detected: $generation_tool (model: $name)"

zipfile="$current_dir/$name.zip"
[ -f "$zipfile" ] && rm "$zipfile"

if [[ "$generation_tool" =~ OpenModelica ]]; then
  echo "→ OpenModelica build path"
  
  # === OPENMODELICA: ALL STEPS TOGETHER ===
  cp -r patch/* "$fmu_dir/"
  
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
    -D CMAKE_BUILD_TYPE=$EMCC_MAKE_TYPE -DCMAKE_C_FLAGS="$EMCC_MAKE_FLAGS" \
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
  $EMCC_FLAGS \
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

elif [[ "$generation_tool" =~ Dymola ]]; then
  echo "→ Dymola build path"
  
  # === DYMOLA: ALL STEPS TOGETHER ===
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

else
  echo "Error: Unknown generationTool '$generation_tool' - must contain 'OpenModelica' or 'Dymola'" >&2
  exit 1
fi

XML_FILE="fmu/modelDescription.xml"
# FIXED xmlquery - CORRECT Docker volume + xmlstarlet syntax
xmlquery() {
    #echo DEBUG: docker run --rm -v .:/data pnnlmiscscripts/xmlstarlet sel --novalid $@ /data/$XML_FILE >&2
    docker run --rm -v .:/data pnnlmiscscripts/xmlstarlet sel --novalid $@ /data/$XML_FILE 
}
generate_web_app() {
#XML_FILE="$fmu_dir/modelDescription.xml"
BASENAME=$name

FMU_NAME=$name
JS_NAME=$name.js

#echo "DEBUG: FMU=$FMU_NAME XML=$BASENAME" >&2

#echo 1. METADATA - simple attribute queries  >&2
GUID=$(xmlquery -t -v '//fmiModelDescription/@guid') # || xmlquery -t -v '//@guid' || echo "{1d4ccc00-2d27-41b0-ae1b-9e8bf1ab544b}")
START_TIME=$(xmlquery -t -v '//DefaultExperiment/@startTime') # || echo "0")
STOP_TIME=$(xmlquery -t -v '//DefaultExperiment/@stopTime') # || echo "2")
TOLERANCE=$(xmlquery -t -v '//DefaultExperiment/@tolerance') # || echo "1e-9")
STEP_SIZE=$(xmlquery -t -v '//DefaultExperiment/@stepSize') # || echo "0.001")

#echo "DEBUG: GUID='$GUID'" >&2
#echo "DEBUG: TIMES start=$START_TIME stop=$STOP_TIME tol=$TOLERANCE step=$STEP_SIZE" >&2

#echo 2.States first 2 >&2
STATE1_VR=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]' -v '@valueReference')
STATE1_NAME=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]' -v '@name')
STATE1_ONAME=$(echo "$STATE1_NAME" | sed 's/^der(//; s/)$//')
STATE1_OVR=$(xmlquery -t -m "//ScalarVariable[@name='${STATE1_ONAME}']" -v '@valueReference')
#STATE1_OVR=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]/Real' -v '@derivative')
#STATE1_ONAME=$(xmlquery -t -m "//ScalarVariable[@valueReference='$STATE1_OVR'][1]" -v '@name')
#STATE2_VR=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=2]' -v '@valueReference')
#STATE2_NAME=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=2]' -v '@name')

VR_LIST="${STATE1_OVR},${STATE1_VR}"
LABEL_LIST="${STATE1_ONAME},${STATE1_NAME}"

#echo "DEBUG STATES: VR=$VR_LIST LABELS=$LABEL_LIST" >&2

#VR_LIST=$(echo "$STATES" | cut -d, -f1 | paste -sd, - | sed 's/,$//')
#LABEL_LIST=$(echo "$STATES" | cut -d, -f2- | paste -sd, - | sed 's/,$//')
#echo "DEBUG VR_LIST='$VR_LIST' LABEL_LIST='$LABEL_LIST'" >&2

#echo 3. PARAMETERS causality="parameter" first 10  >&2
PARAMS=$(xmlquery -t \
  -m '//ScalarVariable[@causality="parameter"][position()<21]' \
  -v '@name' -o ',' -v '@valueReference' -o ',' \
  -m './Real[1]' -v '@start' -o ',' -v '@nominal' \
  -n)

#echo "DEBUG PARAMS: '$PARAMS'" >&2

# Parse params → inputs/ranges
INPUTS=""
RANGE_HTML=""
mapfile -t PARAM_LINES < <(echo "$PARAMS" | tr '\n' ';' | sed 's/;;*/;/g' | tr ';' '\n')
for line in "${PARAM_LINES[@]}"; do
  #echo "DEBUG processing param line: '$line'" >&2
  IFS=, read -r NAME VREF START NOM <<< "$line"
  [ -z "$NAME" ] && continue
  START=${START:-0}
  NOM=${NOM:-1}
  MULT=1 
  #MULT=$([ "$START" = "0.0" ] && echo "10" || echo "1")
  MIN_R=$([ "$START" = "0.0" ] && echo "0" || echo "0.1")
  MAX=$([ "$START" = "0.0" ] && echo "10" || echo "2")
  DEFAULT=$([ "$START" = "0.0" ] && echo "0" || echo "1")
  
  INPUTS="${INPUTS}${NAME},${VREF},${NOM},${MULT},t;"
  printf -v RANGE_LINE '  <dbs-range id="%s" label="%s" min="%s" max="%s" default="%s" step="0.1"></dbs-range>\n' "$NAME" "$NAME" "$MIN_R" "$MAX" "$DEFAULT"
  RANGE_HTML="${RANGE_HTML}${RANGE_LINE}"
  #RANGE_HTML="${RANGE_HTML}  <dbs-range id=\"${NAME}\" label=\"${NAME}\" min=\"${MIN_R}\" max=\"2\" default=\"1\" step=\"0.1\"></dbs-range>\n"
  #echo DEBUG range html:$RANGE_HTML >&2
  #echo DEBUG inputs:$INPUTS >&2
done
#echo "DEBUG INPUTS preview: '$INPUTS'" >&2
#echo DEBUG range html:$RANGE_HTML >&2

# Charts
CHARTS=""
i=0
printf -v CHARTS_LINE '  <dbs-chartjs4 fromid="fmi" refindex="%d" labels="time,%s" timedenom="1"></dbs-chartjs4>\n' "$i" "$STATE1_ONAME"
CHARTS="${CHARTS}${CHARTS_LINE}"
i=$(( i + 1 ))
printf -v CHARTS_LINE '  <dbs-chartjs4 fromid="fmi" refindex="%d" labels="time,%s" timedenom="1"></dbs-chartjs4>\n' "$i" "$STATE1_NAME"
CHARTS="${CHARTS}${CHARTS_LINE}"
#echo "DEBUG CHARTS preview: '$CHARTS'" >&2

# PRODUCTION HTML
cat > "$build_dir/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
<title>Web FMI: $FMU_NAME</title>
<script src="dbs-shared.js"></script>
<script src="dbs-chartjs.js"></script>
<style>
.w3-row:after,.w3-row:before{content:"";display:table;clear:both}
.w3-third,.w3-twothird{float:left;width:100%}
.w3-twothird{width:66.66666%}
.w3-third{width:33.33333%}
.w3-small{font-size:12px!important}
</style>
</head>
<body>  
<div class="w3-row">
  <div class="w3-twothird">
    <h3>Web FMI Simulation</h3>
    <p>Chart of state variable and it's derivative</p>
    <dbs-fmi id="fmi" src="$JS_NAME" fminame="$FMU_NAME" guid="$GUID"
             valuereferences="$VR_LIST" valuelabels="$LABEL_LIST"
             inputs="$INPUTS" mode="oneshot" starttime="$START_TIME" 
             stoptime="$STOP_TIME" tolerance="$TOLERANCE" fstepsize="$STEP_SIZE">
    </dbs-fmi>
$CHARTS  
</div>
  <div class="w3-third">
    <h3>Parameters</h3>
    <p>Adjust the parameters (relative value based on default,0-10 times nominal, or 0.1 to 2 times of default non-zero start)</p>
$RANGE_HTML  
</div>
</div>
<p class="w3-small">Generated by Bodylight.js FMI Compiler. To customize web simulators, 
for 2025 version visit <a href="https://digital-biosystems.github.io/dbs-components/">https://digital-biosystems.github.io/dbs-components/</a> or for previous version visit <a href="https://bodylight.physiome.cz">https://bodylight.physiome.cz</a>.</p>
</body>
</html>
EOF
}

if [ "$GEN_HTML" -eq 1 ]; then
  echo "Generating simple web app HTML ..."
  generate_web_app
fi

echo "Generating ZIP ... 2"

# Package outputs (common)
if [ -f "$build_dir/$name.js" ] ; then
    cp "$fmu_dir/modelDescription.xml" "$build_dir/$name.xml"
    if [ "$GEN_HTML" -eq 1 ]; then
      zip -j "$zipfile" "$build_dir/$name.js" "$build_dir/$name.xml" "$build_dir/index.html" "js/dbs-shared.js" "js/dbs-chartjs.js"
      echo "Standalone zip with WebAssembly and default web simulator in index.html generated: $zipfile"
    else
      zip -j "$zipfile" "$build_dir/$name.js" "$build_dir/$name.xml"
      echo "Standalone zip with WebAssembly embedded in JS generated: $zipfile"
    fi
    if [ "$WEB_IN_FMU" -eq 1 ]; then
        mkdir -p "$fmu_dir/binaries/wasm32"
        cp "$build_dir/$name.js" "$fmu_dir/binaries/wasm32"
        (cd "$fmu_dir" && zip -ur "../$INPUT" binaries/wasm32)
        echo "JS/WASM added to FMU: $INPUT"
    else
        echo ""
    fi
fi

rm -rf "$build_dir" "$fmu_dir"
exit 0
