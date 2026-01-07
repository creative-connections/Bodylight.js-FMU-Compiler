# Parse flags manually
$OPTIMIZED = $false
$WEB_IN_FMU = $false
$GEN_HTML = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "-o" { $OPTIMIZED = $true }
        "-w" { $WEB_IN_FMU = $true }
        "-s" { $GEN_HTML = $true }
    }
}

$INPUT = $args[-1]  # Last positional arg
if ([string]::IsNullOrEmpty($INPUT)) {
    Write-Host "Usage: .\compile_docker.ps1 [-o] [-w] [-s] input.fmu" -ForegroundColor Red
    exit 1
}

$ErrorActionPreference = "Stop"
Write-Host "script version 2512 for FMU (OpenModelica/Dymola auto-detect) with CVODE to WebAssembly Dockerized"

# Directories relative to current location
$current_dir = (Get-Location).Path
$build_dir   = Join-Path $current_dir "build_wasm"
$fmu_dir     = Join-Path $current_dir "fmu"
$sources_dir = Join-Path $current_dir "jsglue"
$fmudiff_dir = Join-Path $current_dir "fmudiff"
$cvode_dir   = Join-Path $current_dir "lib_cvode5.4.0"
$cvode_include = Join-Path $current_dir "include"

# Flags
$OPTIMIZED  = $o.IsPresent
$WEB_IN_FMU = $w.IsPresent
$GEN_HTML   = $s.IsPresent

if ($OPTIMIZED) {
    $EMCC_FLAGS_BASE  = "-O3 --closure 1 -g0"
    $EMCC_MAKE_FLAGS  = "-O3 -fPIC"
    $EMCC_MAKE_TYPE   = "Release"
} else {
    $EMCC_FLAGS_BASE  = "-O0 --closure 0"
    $EMCC_MAKE_FLAGS  = "-O0 -fPIC"
    $EMCC_MAKE_TYPE   = "Debug"
}
$EMCC_FLAGS = $EMCC_FLAGS_BASE

# Clean and extract
if (Test-Path $build_dir) { Remove-Item $build_dir -Recurse -Force }
if (Test-Path $fmu_dir)   { Remove-Item $fmu_dir   -Recurse -Force }

New-Item -ItemType Directory -Path $fmu_dir, $build_dir | Out-Null

# unzip FMU (requires 'tar' or 'Expand-Archive' depending on .fmu == .zip)
Expand-Archive -LiteralPath $Input -DestinationPath $fmu_dir -Force
$modelDescription = Join-Path $fmu_dir "modelDescription.xml"
[xml]$xml = Get-Content $modelDescription -Encoding UTF8

$name = ($xml.SelectSingleNode("//*[@modelIdentifier]").modelIdentifier)
$model_name = $name
$generation_tool = $xml.fmiModelDescription.generationTool

Write-Host "Detected: $generation_tool (model: $name)"


$zipfile = Join-Path $current_dir "$name.zip"
if (Test-Path $zipfile) { Remove-Item $zipfile -Force }

if ($generation_tool -match "OpenModelica") {
    Write-Host "→ OpenModelica build path"

    # copy patch/*
    Copy-Item -Path (Join-Path $current_dir "patch\*") -Destination $fmu_dir -Recurse -Force

    # Patch CMakeLists.txt (using sed via Docker)
docker run --rm -v "${current_dir}:/src" alpine `
    sh -c "sed -i '/set(FMU_TARGET_SYSTEM_NAME \"darwin\")/a\
elseif(\${CMAKE_SYSTEM_NAME} STREQUAL \"Emscripten\")\
  set(FMU_TARGET_SYSTEM_NAME \"emscripten\")' /src/fmu/sources/CMakeLists.txt"

    # emcmake cmake
    docker run --rm -v "${current_dir}:/src" -w /src/fmu/sources emscripten/emsdk `
      emcmake cmake -S . -B "/src/build_wasm" `
        -D RUNTIME_DEPENDENCIES_LEVEL=none `
        -D FMI_INTERFACE_HEADER_FILES_DIRECTORY="/src/include" `
        -D NEED_CVODE=ON `
        -D SUNDIALS_CVODE_LIBRARY="/src/lib_cvode5.4.0/libsundials_cvode.a" `
        -D SUNDIALS_NVECSERIAL_LIBRARY="/src/lib_cvode5.4.0/libsundials_nvecserial.a" `
        -D WITH_SUNDIALS=1 -D OMC_FMI_RUNTIME=1 -D LINK_SUNDIAL_STATIC=ON `
        -D CMAKE_BUILD_TYPE=$EMCC_MAKE_TYPE -DCMAKE_C_FLAGS="$EMCC_MAKE_FLAGS" `
        -D CMAKE_TOOLCHAIN_FILE=/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

    # Build
    docker run --rm -v "${current_dir}:/src" -w /src/fmu/sources emscripten/emsdk `
      cmake --build /src/build_wasm

    # Version
    docker run --rm -v "${current_dir}:/src" -w /src emscripten/emsdk `
      emcc --version

    # Link
    docker run --rm -v "${current_dir}:/src" -w /src emscripten/emsdk `
      emcc "/src/jsglue/glue.c" "/src/build_wasm/$name.a" `
      --post-js "/src/jsglue/glue.js" `
      --embed-file "/src/fmu/resources@/" `
      -v `
      -g0 `
      -lsundials_cvode `
      -L"/src/lib_cvode5.4.0" `
      -I"/src/jsglue" `
      -I"/src/include" `
      -I/usr/local/include `
      -DWITH_SUNDIALS -DOMC_FMI_RUNTIME=1 -DLINK_SUNDIAL_STATIC=ON `
      -sMODULARIZE=1 `
      -s MAIN_MODULE=1 `
      -s LEGALIZE_JS_FFI=0 `
      -sEXPORT_NAME="$name" `
      -o "/src/build_wasm/$name.js" `
      -sALLOW_MEMORY_GROWTH=1 `
      -sWASM=1 `
      $EMCC_FLAGS `
      -D Linux `
      -sSINGLE_FILE=1 `
      -sASSERTIONS=2 `
      -sRESERVED_FUNCTION_POINTERS=80 `
      -s"BINARYEN_METHOD='native-wasm'" `
      -sEXPORTED_FUNCTIONS="['_CVodeCreate','_fmi2DoStep',`
'_fmi2Instantiate','_fmi2CompletedIntegratorStep','_fmi2DeSerializeFMUstate',`
'_fmi2EnterContinuousTimeMode','_fmi2EnterEventMode','_fmi2EnterInitializationMode',`
'_fmi2ExitInitializationMode','_fmi2FreeFMUstate','_fmi2FreeInstance','_fmi2GetBoolean',`
'_fmi2GetBooleanStatus','_fmi2GetContinuousStates','_fmi2GetDerivatives',`
'_fmi2GetDirectionalDerivative','_fmi2GetEventIndicators','_fmi2GetFMUstate',`
'_fmi2GetInteger','_fmi2GetIntegerStatus','_fmi2GetNominalsOfContinuousStates',`
'_fmi2GetReal','_fmi2GetRealOutputDerivatives','_fmi2GetRealStatus','_fmi2GetStatus',`
'_fmi2GetString','_fmi2GetStringStatus','_fmi2GetTypesPlatform','_fmi2GetVersion',`
'_fmi2NewDiscreteStates','_fmi2SerializedFMUstateSize','_fmi2SerializeFMUstate',`
'_fmi2SetBoolean','_fmi2SetContinuousStates','_fmi2SetDebugLogging','_fmi2SetFMUstate',`
'_fmi2SetInteger','_fmi2SetReal','_fmi2SetRealInputDerivatives','_fmi2SetString',`
'_fmi2SetTime','_fmi2SetupExperiment','_fmi2Terminate','_fmi2Reset','_createFmi2CallbackFunctions',`
'_cvode_solver_initial','_cvode_solver_deinitial','_cvode_solver_fmi_step',`
'_snprintf','_main','_calloc','_malloc','_free']" `
      -sEXPORTED_RUNTIME_METHODS="['FS_createPath','FS_createDataFile',`
'FS_createPreloadedFile','FS_createLazyFile','FS_createDevice','FS_unlink','addFunction',`
'ccall','cwrap','setValue','getValue','ALLOC_NORMAL','ALLOC_STACK','AsciiToString',`
'stringToAscii','UTF8ArrayToString','UTF8ToString','stringToUTF8Array','stringToUTF8',`
'lengthBytesUTF8','stackTrace','addOnPreRun','addOnInit','addOnPreMain','addOnExit',`
'addOnPostRun','intArrayFromString','intArrayToString','writeStringToMemory',`
'writeArrayToMemory','writeAsciiToMemory','addRunDependency','removeRunDependency','HEAPU8']"

} elseif ($generation_tool -match "Dymola") {
    Write-Host "→ Dymola build path"

    docker run --rm -v "${current_dir}:/src" -w /src emscripten/emsdk `
      emcc /src/fmu/sources/all.c /src/jsglue/glue.c `
        -I/src/fmu/sources `
        -I/src/include `
        -lm `
        $EMCC_FLAGS `
        -s WASM=1 `
        -s SINGLE_FILE=1 `
        -s MODULARIZE=1 `
        -s EXPORT_NAME="$name" `
        -o /src/build_wasm/$name.js `
        -s ALLOW_MEMORY_GROWTH=1 `
        -s ASSERTIONS=2 `
        -s STACK_SIZE=2097152 `
        -s RESERVED_FUNCTION_POINTERS=20 `
        -s "BINARYEN_METHOD='native-wasm'" `
        -s EXPORTED_FUNCTIONS="['_${model_name}_fmi2CancelStep', ... ]" `
        -s EXPORTED_RUNTIME_METHODS="['FS_createFolder', ... 'HEAPU8']"
} else {
    Write-Error "Unknown generationTool '$generation_tool' - must contain 'OpenModelica' or 'Dymola'"
    exit 1
}

# Helper: xmlquery via Docker+xmlstarlet (volume maps current dir as /data)
function xmlquery_old {
    param([string[]]$Args)
    docker run --rm -v "${current_dir}:/data" pnnlmiscscripts/xmlstarlet `
        sel --novalid @Args "/data/fmu/modelDescription.xml"
}
function xmlquery {
    param([string]$XPath)
    return $xml.SelectSingleNode($XPath).InnerText
}

function generate_web_app {
    $BASENAME = $name
    $FMU_NAME = $name
    $JS_NAME  = "$name.js"

    $GUID      = xmlquery -t -v '//fmiModelDescription/@guid'
    $START_TIME = xmlquery -t -v '//DefaultExperiment/@startTime'
    $STOP_TIME  = xmlquery -t -v '//DefaultExperiment/@stopTime'
    $TOLERANCE  = xmlquery -t -v '//DefaultExperiment/@tolerance'
    $STEP_SIZE  = xmlquery -t -v '//DefaultExperiment/@stepSize'

    $STATE1_VR = xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]' -v '@valueReference'
    $STATE1_NAME = xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]' -v '@name'
    $STATE1_ONAME = $STATE1_NAME -replace '^der\(', '' -replace '\)$',''
    $STATE1_OVR = xmlquery -t -m "//ScalarVariable[@name='${STATE1_ONAME}']" -v '@valueReference'

    $VR_LIST    = "$STATE1_OVR,$STATE1_VR"
    $LABEL_LIST = "$STATE1_ONAME,$STATE1_NAME"

    $PARAMS = xmlquery -t `
      -m '//ScalarVariable[@causality="parameter"][position()<21]' `
      -v '@name' -o ',' -v '@valueReference' -o ',' `
      -m './Real[1]' -v '@start' -o ',' -v '@nominal' `
      -n

    $INPUTS = ""
    $RANGE_HTML = ""

    $PARAM_LINES = ($PARAMS -split "`n") | Where-Object { $_ -ne "" }
    foreach ($line in $PARAM_LINES) {
        $parts = $line.Split(',')
        if ($parts.Count -lt 2) { continue }
        $NAME = $parts[0]
        $VREF = $parts[1]
        $START = if ($parts.Count -gt 2 -and $parts[2] -ne "") { $parts[2] } else { "0" }
        $NOM = if ($parts.Count -gt 3 -and $parts[3] -ne "") { $parts[3] } else { "1" }

        if ($START -eq "0.0" -or $START -eq "0") {
            $MIN_R = "0"
            $MAX   = "10"
            $DEFAULT = "0"
        } else {
            $MIN_R = "0.1"
            $MAX   = "2"
            $DEFAULT = "1"
        }

        $MULT = "1"
        $INPUTS += "${NAME},${VREF},${NOM},${MULT},t;"

        $RANGE_HTML += "  <dbs-range id=""$NAME"" label=""$NAME"" min=""$MIN_R"" max=""$MAX"" default=""$DEFAULT"" step=""0.1""></dbs-range>`n"
    }

    $CHARTS = ""
    $i = 0
    $CHARTS += "  <dbs-chartjs4 fromid=""fmi"" refindex=""$i"" labels=""time,$STATE1_ONAME"" timedenom=""1""></dbs-chartjs4>`n"
    $i++
    $CHARTS += "  <dbs-chartjs4 fromid=""fmi"" refindex=""$i"" labels=""time,$STATE1_NAME"" timedenom=""1""></dbs-chartjs4>`n"

    $html = @"
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
"@

    $indexFile = Join-Path $build_dir "index.html"
    $html | Set-Content -Encoding UTF8 $indexFile
}

if ($GEN_HTML) {
    Write-Host "Generating simple web app HTML ..."
    generate_web_app
}

Write-Host "Generating ZIP ... 2"

if (Test-Path (Join-Path $build_dir "$name.js")) {
    Copy-Item -Path (Join-Path $fmu_dir "modelDescription.xml") -Destination (Join-Path $build_dir "$name.xml") -Force

    if ($GEN_HTML) {
        Compress-Archive -LiteralPath `
            (Join-Path $build_dir "$name.js"), `
            (Join-Path $build_dir "$name.xml"), `
            (Join-Path $build_dir "index.html"), `
            (Join-Path $current_dir "js\dbs-shared.js"), `
            (Join-Path $current_dir "js\dbs-chartjs.js") `
            -DestinationPath $zipfile -Force

        Write-Host "Standalone zip with WebAssembly and default web simulator in index.html generated: $zipfile"
    } else {
        Compress-Archive -LiteralPath `
            (Join-Path $build_dir "$name.js"), `
            (Join-Path $build_dir "$name.xml") `
            -DestinationPath $zipfile -Force

        Write-Host "Standalone zip with WebAssembly embedded in JS generated: $zipfile"
    }

    if ($WEB_IN_FMU) {
        $wasm_dir = Join-Path $fmu_dir "binaries\wasm32"
        New-Item -ItemType Directory -Path $wasm_dir -Force | Out-Null
        Copy-Item (Join-Path $build_dir "$name.js") -Destination $wasm_dir -Force
        Push-Location $fmu_dir
        & zip -ur "../$Input" "binaries/wasm32"
        Pop-Location
        Write-Host "JS/WASM added to FMU: $Input"
    }
}

if (Test-Path $build_dir) { Remove-Item $build_dir -Recurse -Force }
if (Test-Path $fmu_dir)   { Remove-Item $fmu_dir   -Recurse -Force }

exit 0
