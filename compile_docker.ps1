#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Write-Host "script version 2512 for FMU (OpenModelica/Dymola auto-detect) with CVODE to WebAssembly Dockerized"

# Detect platform
$IsWindowsOS = $IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)
if (-not $IsWindowsOS) {
    Write-Host "Running on Linux/WSL - using native paths" -ForegroundColor Cyan
}

# Parse flags manually
$OPTIMIZED = $false
$WEB_IN_FMU = $false
$GEN_HTML = $false
$INPUT = ""

# Process arguments
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "-o" { $OPTIMIZED = $true }
        "-w" { $WEB_IN_FMU = $true }
        "-s" { $GEN_HTML = $true }
        default { 
            # Assume it's the input file if it doesn't start with -
            if (-not $args[$i].StartsWith("-")) {
                $INPUT = $args[$i]
            }
        }
    }
}

# Validate input
if ([string]::IsNullOrEmpty($INPUT)) {
    Write-Host "Usage: .\compile_docker.ps1 [-o] [-w] [-s] input.fmu" -ForegroundColor Red
    Write-Host "  -o Optimize code, default no" -ForegroundColor Yellow
    Write-Host "  -w Embed webassembly in FMU, by default webassembly is only in resulting ZIP" -ForegroundColor Yellow
    Write-Host "  -s Generate standalone web app in ZIP" -ForegroundColor Yellow
    exit 1
}

# Directories relative to current location
$current_dir = (Get-Location).Path
$build_dir   = Join-Path $current_dir "build_wasm"
$fmu_dir     = Join-Path $current_dir "fmu"
$sources_dir = Join-Path $current_dir "jsglue"
$fmudiff_dir = Join-Path $current_dir "fmudiff"
$cvode_dir   = Join-Path $current_dir "lib_cvode5.4.0"
$cvode_include = Join-Path $current_dir "include"

# Set flags for emscripten
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

# Extract FMU (FMU files are ZIP archives)
$fmu_temp = Join-Path $current_dir "temp_fmu.zip"
Copy-Item $INPUT $fmu_temp -Force
Expand-Archive -LiteralPath $fmu_temp -DestinationPath $fmu_dir -Force
Remove-Item $fmu_temp -Force

# Parse modelDescription.xml using native PowerShell XML parsing
$modelDescription = Join-Path $fmu_dir "modelDescription.xml"
[xml]$xml = Get-Content $modelDescription -Encoding UTF8

# Extract model name and generation tool
$coSimNode = $xml.SelectSingleNode("//*[@modelIdentifier]")
$name = $coSimNode.modelIdentifier
$model_name = $name
$generation_tool = $xml.fmiModelDescription.generationTool

Write-Host "Detected: $generation_tool (model: $name)"

$zipfile = Join-Path $current_dir "$name.zip"
if (Test-Path $zipfile) { Remove-Item $zipfile -Force }

# Convert Windows path to Unix path for Docker (handle both WSL and native Docker)
function Convert-ToDockerPath {
    param([string]$WindowsPath)
    
    # On Linux/WSL, return path as-is
    if (-not $IsWindowsOS) {
        return $WindowsPath
    }
    
    # Convert backslashes to forward slashes
    $unixPath = $WindowsPath -replace '\\', '/'
    # Convert C:/ to /c/ (for Docker on Windows)
    if ($unixPath -match '^([A-Za-z]):(.*)$') {
        $drive = $matches[1].ToLower()
        $path = $matches[2]
        return "/$drive$path"
    }
    return $unixPath
}

$docker_current_dir = Convert-ToDockerPath $current_dir

# Set Docker user parameter (needed on Linux to avoid permission issues)
$dockerUser = ""
if (-not $IsWindowsOS) {
    $userId = sh -c 'id -u'
    $groupId = sh -c 'id -g'
    $dockerUser = "-u ${userId}:${groupId}"
}

if ($generation_tool -match "OpenModelica") {
    Write-Host "→ OpenModelica build path"

    # Copy patch files
    Copy-Item -Path (Join-Path $current_dir "patch\*") -Destination $fmu_dir -Recurse -Force

    # Patch CMakeLists.txt - add emscripten as a target
    $cmakeFile = Join-Path $fmu_dir "sources\CMakeLists.txt"
    $cmakeContent = Get-Content $cmakeFile -Raw
    
    # Add emscripten target if not already present
    if ($cmakeContent -notmatch "emscripten") {
        $cmakeContent = $cmakeContent -replace '(set\(FMU_TARGET_SYSTEM_NAME "darwin"\))', 
@'
$1
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Emscripten")
  set(FMU_TARGET_SYSTEM_NAME "emscripten")
'@
        Set-Content -Path $cmakeFile -Value $cmakeContent -NoNewline
    }

    # Run emcmake cmake inside docker
    Write-Host "Running cmake configuration..."
    docker run --rm $dockerUser -v "${docker_current_dir}:/src" -w /src/fmu/sources emscripten/emsdk `
      emcmake cmake -S . -B "/src/build_wasm" `
        -D RUNTIME_DEPENDENCIES_LEVEL=none `
        -D FMI_INTERFACE_HEADER_FILES_DIRECTORY="/src/include" `
        -D NEED_CVODE=ON `
        -D SUNDIALS_CVODE_LIBRARY="/src/lib_cvode5.4.0/libsundials_cvode.a" `
        -D SUNDIALS_NVECSERIAL_LIBRARY="/src/lib_cvode5.4.0/libsundials_nvecserial.a" `
        -D WITH_SUNDIALS=1 -D OMC_FMI_RUNTIME=1 -D LINK_SUNDIAL_STATIC=ON `
        "-D CMAKE_BUILD_TYPE=$EMCC_MAKE_TYPE" "-DCMAKE_C_FLAGS=$EMCC_MAKE_FLAGS" `
        -D CMAKE_TOOLCHAIN_FILE=/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake

    # Build inside docker
    Write-Host "Building..."
    docker run --rm $dockerUser -v "${docker_current_dir}:/src" -w /src/fmu/sources emscripten/emsdk `
      cmake --build /src/build_wasm

    # Show emcc version
    docker run --rm $dockerUser -v "${docker_current_dir}:/src" -w /src emscripten/emsdk `
      emcc --version

    # Link step inside docker
    Write-Host "Linking..."
    
    # Build emcc command with proper flag handling
    $emccCmd = @(
        "emcc", "/src/jsglue/glue.c", "/src/build_wasm/$name.a",
        "--post-js", "/src/jsglue/glue.js",
        "--embed-file", "/src/fmu/resources@/",
        "-v", "-g0",
        "-lsundials_cvode",
        "-L/src/lib_cvode5.4.0",
        "-I/src/jsglue",
        "-I/src/include",
        "-I/usr/local/include",
        "-DWITH_SUNDIALS", "-DOMC_FMI_RUNTIME=1", "-DLINK_SUNDIAL_STATIC=ON",
        "-sMODULARIZE=1",
        "-s", "MAIN_MODULE=1",
        "-s", "LEGALIZE_JS_FFI=0",
        "-sEXPORT_NAME=$name",
        "-o", "/src/build_wasm/$name.js",
        "-sALLOW_MEMORY_GROWTH=1",
        "-sWASM=1"
    )
    
    # Add optimization flags
    if ($OPTIMIZED) {
        $emccCmd += @("-O3", "--closure", "1", "-g0")
    } else {
        $emccCmd += @("-O0", "--closure", "0")
    }
    
    $emccCmd += @(
        "-D", "Linux",
        "-sSINGLE_FILE=1",
        "-sASSERTIONS=2",
        "-sRESERVED_FUNCTION_POINTERS=80",
        "-sBINARYEN_METHOD=native-wasm",
        "-sEXPORTED_FUNCTIONS=['_CVodeCreate','_fmi2DoStep','_fmi2Instantiate','_fmi2CompletedIntegratorStep','_fmi2DeSerializeFMUstate','_fmi2EnterContinuousTimeMode','_fmi2EnterEventMode','_fmi2EnterInitializationMode','_fmi2ExitInitializationMode','_fmi2FreeFMUstate','_fmi2FreeInstance','_fmi2GetBoolean','_fmi2GetBooleanStatus','_fmi2GetContinuousStates','_fmi2GetDerivatives','_fmi2GetDirectionalDerivative','_fmi2GetEventIndicators','_fmi2GetFMUstate','_fmi2GetInteger','_fmi2GetIntegerStatus','_fmi2GetNominalsOfContinuousStates','_fmi2GetReal','_fmi2GetRealOutputDerivatives','_fmi2GetRealStatus','_fmi2GetStatus','_fmi2GetString','_fmi2GetStringStatus','_fmi2GetTypesPlatform','_fmi2GetVersion','_fmi2NewDiscreteStates','_fmi2SerializedFMUstateSize','_fmi2SerializeFMUstate','_fmi2SetBoolean','_fmi2SetContinuousStates','_fmi2SetDebugLogging','_fmi2SetFMUstate','_fmi2SetInteger','_fmi2SetReal','_fmi2SetRealInputDerivatives','_fmi2SetString','_fmi2SetTime','_fmi2SetupExperiment','_fmi2Terminate','_fmi2Reset','_createFmi2CallbackFunctions','_cvode_solver_initial','_cvode_solver_deinitial','_cvode_solver_fmi_step','_snprintf','_main','_calloc','_malloc','_free']",
        "-sEXPORTED_RUNTIME_METHODS=['FS_createPath','FS_createDataFile','FS_createPreloadedFile','FS_createLazyFile','FS_createDevice','FS_unlink','addFunction','ccall','cwrap','setValue','getValue','ALLOC_NORMAL','ALLOC_STACK','AsciiToString','stringToAscii','UTF8ArrayToString','UTF8ToString','stringToUTF8Array','stringToUTF8','lengthBytesUTF8','stackTrace','addOnPreRun','addOnInit','addOnPreMain','addOnExit','addOnPostRun','intArrayFromString','intArrayToString','writeStringToMemory','writeArrayToMemory','writeAsciiToMemory','addRunDependency','removeRunDependency','HEAPU8']"
    )
    
    docker run --rm $dockerUser -v "${docker_current_dir}:/src" -w /src emscripten/emsdk $emccCmd

} elseif ($generation_tool -match "Dymola") {
    Write-Host "→ Dymola build path"

    # Build Dymola FMU
    Write-Host "Building Dymola FMU..."
    
    # Build emcc command with proper flag handling
    $emccCmd = @(
        "emcc", "/src/fmu/sources/all.c", "/src/jsglue/glue.c",
        "-I/src/fmu/sources",
        "-I/src/include",
        "-lm"
    )
    
    # Add optimization flags
    if ($OPTIMIZED) {
        $emccCmd += @("-O3", "--closure", "1", "-g0")
    } else {
        $emccCmd += @("-O0", "--closure", "0")
    }
    
    $emccCmd += @(
        "-s", "WASM=1",
        "-s", "SINGLE_FILE=1",
        "-s", "MODULARIZE=1",
        "-s", "EXPORT_NAME=$name",
        "-o", "/src/build_wasm/$name.js",
        "-s", "ALLOW_MEMORY_GROWTH=1",
        "-s", "ASSERTIONS=2",
        "-s", "STACK_SIZE=2097152",
        "-s", "RESERVED_FUNCTION_POINTERS=20",
        "-s", "BINARYEN_METHOD=native-wasm",
        "-s", "EXPORTED_FUNCTIONS=['_${model_name}_fmi2CancelStep','_${model_name}_fmi2CompletedIntegratorStep','_${model_name}_fmi2DeSerializeFMUstate','_${model_name}_fmi2DoStep','_${model_name}_fmi2EnterContinuousTimeMode','_${model_name}_fmi2EnterEventMode','_${model_name}_fmi2EnterInitializationMode','_${model_name}_fmi2ExitInitializationMode','_${model_name}_fmi2FreeFMUstate','_${model_name}_fmi2FreeInstance','_${model_name}_fmi2GetBoolean','_${model_name}_fmi2GetBooleanStatus','_${model_name}_fmi2GetContinuousStates','_${model_name}_fmi2GetDerivatives','_${model_name}_fmi2GetDirectionalDerivative','_${model_name}_fmi2GetEventIndicators','_${model_name}_fmi2GetFMUstate','_${model_name}_fmi2GetInteger','_${model_name}_fmi2GetIntegerStatus','_${model_name}_fmi2GetNominalsOfContinuousStates','_${model_name}_fmi2GetReal','_${model_name}_fmi2GetRealOutputDerivatives','_${model_name}_fmi2GetRealStatus','_${model_name}_fmi2GetStatus','_${model_name}_fmi2GetString','_${model_name}_fmi2GetStringStatus','_${model_name}_fmi2GetTypesPlatform','_${model_name}_fmi2GetVersion','_${model_name}_fmi2Instantiate','_${model_name}_fmi2NewDiscreteStates','_${model_name}_fmi2Reset','_${model_name}_fmi2SerializedFMUstateSize','_${model_name}_fmi2SerializeFMUstate','_${model_name}_fmi2SetBoolean','_${model_name}_fmi2SetContinuousStates','_${model_name}_fmi2SetDebugLogging','_${model_name}_fmi2SetFMUstate','_${model_name}_fmi2SetInteger','_${model_name}_fmi2SetReal','_${model_name}_fmi2SetRealInputDerivatives','_${model_name}_fmi2SetString','_${model_name}_fmi2SetTime','_${model_name}_fmi2SetupExperiment','_${model_name}_fmi2Terminate','_createFmi2CallbackFunctions','_snprintf','_calloc','_malloc','_free']",
        "-s", "EXPORTED_RUNTIME_METHODS=['FS_createFolder','FS_createPath','FS_createDataFile','FS_createPreloadedFile','FS_createLazyFile','FS_createLink','FS_createDevice','FS_unlink','addFunction','ccall','cwrap','setValue','getValue','ALLOC_NORMAL','ALLOC_STACK','allocate','AsciiToString','stringToAscii','UTF8ArrayToString','UTF8ToString','stringToUTF8Array','stringToUTF8','lengthBytesUTF8','stackTrace','addOnPreRun','addOnInit','addOnPreMain','addOnExit','addOnPostRun','intArrayFromString','intArrayToString','writeStringToMemory','writeArrayToMemory','writeAsciiToMemory','addRunDependency','removeRunDependency','HEAPU8']"
    )
    
    docker run --rm $dockerUser -v "${docker_current_dir}:/src" -w /src emscripten/emsdk $emccCmd

} else {
    Write-Error "Unknown generationTool '$generation_tool' - must contain 'OpenModelica' or 'Dymola'"
    exit 1
}

# Helper functions for XML querying using native PowerShell
function Get-XmlValue {
    param(
        [string]$XPath,
        [string]$Attribute = $null
    )
    
    try {
        $node = $xml.SelectSingleNode($XPath)
        if ($null -eq $node) {
            return ""
        }
        
        if ($Attribute) {
            return $node.GetAttribute($Attribute)
        } else {
            return $node.InnerText
        }
    } catch {
        return ""
    }
}

function Get-XmlNodes {
    param(
        [string]$XPath
    )
    
    try {
        return $xml.SelectNodes($XPath)
    } catch {
        return @()
    }
}

# Generate web app HTML
function Generate-WebApp {
    $BASENAME = $name
    $FMU_NAME = $name
    $JS_NAME  = "$name.js"

    # Get metadata from XML
    $GUID      = Get-XmlValue -XPath "//fmiModelDescription" -Attribute "guid"
    $START_TIME = Get-XmlValue -XPath "//DefaultExperiment" -Attribute "startTime"
    $STOP_TIME  = Get-XmlValue -XPath "//DefaultExperiment" -Attribute "stopTime"
    $TOLERANCE  = Get-XmlValue -XPath "//DefaultExperiment" -Attribute "tolerance"
    $STEP_SIZE  = Get-XmlValue -XPath "//DefaultExperiment" -Attribute "stepSize"

    # Set defaults if not found
    if ([string]::IsNullOrEmpty($START_TIME)) { $START_TIME = "0" }
    if ([string]::IsNullOrEmpty($STOP_TIME)) { $STOP_TIME = "2" }
    if ([string]::IsNullOrEmpty($TOLERANCE)) { $TOLERANCE = "1e-9" }
    if ([string]::IsNullOrEmpty($STEP_SIZE)) { $STEP_SIZE = "0.001" }

    # Get state variables
    $stateNodes = Get-XmlNodes -XPath "//ScalarVariable[Real/@derivative]"
    
    if ($stateNodes.Count -gt 0) {
        $state1 = $stateNodes[0]
        $STATE1_VR = $state1.GetAttribute("valueReference")
        $STATE1_NAME = $state1.GetAttribute("name")
        
        # Extract original variable name from der(varname)
        $STATE1_ONAME = $STATE1_NAME -replace '^der\(', '' -replace '\)$',''
        
        # Find the original variable's value reference
        $originalVar = $xml.SelectSingleNode("//ScalarVariable[@name='$STATE1_ONAME']")
        if ($originalVar) {
            $STATE1_OVR = $originalVar.GetAttribute("valueReference")
        } else {
            $STATE1_OVR = $STATE1_VR
        }
    } else {
        # No state variables found, use first two scalar variables
        $allVars = Get-XmlNodes -XPath "//ScalarVariable[position()<=2]"
        if ($allVars.Count -gt 0) {
            $STATE1_OVR = $allVars[0].GetAttribute("valueReference")
            $STATE1_ONAME = $allVars[0].GetAttribute("name")
            if ($allVars.Count -gt 1) {
                $STATE1_VR = $allVars[1].GetAttribute("valueReference")
                $STATE1_NAME = $allVars[1].GetAttribute("name")
            } else {
                $STATE1_VR = $STATE1_OVR
                $STATE1_NAME = $STATE1_ONAME
            }
        } else {
            $STATE1_OVR = "0"
            $STATE1_ONAME = "var1"
            $STATE1_VR = "1"
            $STATE1_NAME = "var2"
        }
    }

    $VR_LIST    = "$STATE1_OVR,$STATE1_VR"
    $LABEL_LIST = "$STATE1_ONAME,$STATE1_NAME"

    # Get parameters
    $paramNodes = Get-XmlNodes -XPath "//ScalarVariable[@causality='parameter'][position()<=20]"
    
    $INPUTS = ""
    $RANGE_HTML = ""

    foreach ($param in $paramNodes) {
        $NAME = $param.GetAttribute("name")
        $VREF = $param.GetAttribute("valueReference")
        
        # Get Real child element
        $realNode = $param.SelectSingleNode("Real")
        if ($realNode) {
            $START = $realNode.GetAttribute("start")
            $NOM = $realNode.GetAttribute("nominal")
        } else {
            $START = ""
            $NOM = ""
        }
        
        if ([string]::IsNullOrEmpty($START)) { $START = "0" }
        if ([string]::IsNullOrEmpty($NOM)) { $NOM = "1" }

        # Determine ranges based on start value
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

        $RANGE_HTML += "  <dbs-range id=`"$NAME`" label=`"$NAME`" min=`"$MIN_R`" max=`"$MAX`" default=`"$DEFAULT`" step=`"0.1`"></dbs-range>`n"
    }

    # Generate charts
    $CHARTS = ""
    $i = 0
    $CHARTS += "  <dbs-chartjs4 fromid=`"fmi`" refindex=`"$i`" labels=`"time,$STATE1_ONAME`" timedenom=`"1`"></dbs-chartjs4>`n"
    $i++
    $CHARTS += "  <dbs-chartjs4 fromid=`"fmi`" refindex=`"$i`" labels=`"time,$STATE1_NAME`" timedenom=`"1`"></dbs-chartjs4>`n"

    # Create HTML content
    $html = @"
<!DOCTYPE html>
<html>
<head>
<title>Web FMI: $FMU_NAME</title>
<script src="dbs-shared.js"></script>
<script src="dbs-fmi.js"></script>
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
$CHARTS  </div>
  <div class="w3-third">
    <h3>Parameters</h3>
    <p>Adjust the parameters (relative value based on default,0-10 times nominal, or 0.1 to 2 times of default non-zero start)</p>
$RANGE_HTML  </div>
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
    Generate-WebApp
}

Write-Host "Generating ZIP ..."

# Package outputs
$jsFile = Join-Path $build_dir "$name.js"
if (Test-Path $jsFile) {
    Copy-Item -Path (Join-Path $fmu_dir "modelDescription.xml") -Destination (Join-Path $build_dir "$name.xml") -Force

    if ($GEN_HTML) {
        # Create ZIP with HTML and JS files
        $filesToZip = @(
            (Join-Path $build_dir "$name.js"),
            (Join-Path $build_dir "$name.xml"),
            (Join-Path $build_dir "index.html"),
            (Join-Path $current_dir "js\dbs-shared.js"),
            (Join-Path $current_dir "js\dbs-chartjs.js")
        )
        
        Compress-Archive -LiteralPath $filesToZip -DestinationPath $zipfile -Force
        Write-Host "Standalone zip with WebAssembly and default web simulator in index.html generated: $zipfile" -ForegroundColor Green
    } else {
        # Create ZIP with just JS and XML
        $filesToZip = @(
            (Join-Path $build_dir "$name.js"),
            (Join-Path $build_dir "$name.xml")
        )
        
        Compress-Archive -LiteralPath $filesToZip -DestinationPath $zipfile -Force
        Write-Host "Standalone zip with WebAssembly embedded in JS generated: $zipfile" -ForegroundColor Green
    }

    if ($WEB_IN_FMU) {
        $wasm_dir = Join-Path $fmu_dir "binaries\wasm32"
        New-Item -ItemType Directory -Path $wasm_dir -Force | Out-Null
        Copy-Item (Join-Path $build_dir "$name.js") -Destination $wasm_dir -Force
        
        # Update FMU with wasm binaries using native PowerShell
        # First, create a temp directory for the update
        $tempUpdateDir = Join-Path $current_dir "temp_fmu_update"
        if (Test-Path $tempUpdateDir) { Remove-Item $tempUpdateDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempUpdateDir | Out-Null
        
        # Extract original FMU
        Expand-Archive -LiteralPath $INPUT -DestinationPath $tempUpdateDir -Force
        
        # Copy wasm files
        $wasmDestDir = Join-Path $tempUpdateDir "binaries\wasm32"
        New-Item -ItemType Directory -Path $wasmDestDir -Force | Out-Null
        Copy-Item (Join-Path $build_dir "$name.js") -Destination $wasmDestDir -Force
        
        # Re-compress
        $tempFmuZip = Join-Path $current_dir "temp_updated_fmu.zip"
        if (Test-Path $tempFmuZip) { Remove-Item $tempFmuZip -Force }
        Compress-Archive -Path "$tempUpdateDir\*" -DestinationPath $tempFmuZip -Force
        
        # Replace original
        Move-Item $tempFmuZip $INPUT -Force
        Remove-Item $tempUpdateDir -Recurse -Force
        
        Write-Host "JS/WASM added to FMU: $INPUT" -ForegroundColor Green
    }
} else {
    Write-Host "Warning: Build output not found at $jsFile" -ForegroundColor Yellow
}

# Cleanup
if (Test-Path $build_dir) { Remove-Item $build_dir -Recurse -Force }
if (Test-Path $fmu_dir)   { Remove-Item $fmu_dir   -Recurse -Force }

Write-Host "Done!" -ForegroundColor Green
exit 0
