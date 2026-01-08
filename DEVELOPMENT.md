# Bash and PowerShell Implementation of C compilation of FMU into Web Assembly

Development notes for scripts using docker image emscripten to compile FMU with C sources to WebAssembly

## Feature Comparison

| Feature | Bash Script (`compile_docker.sh`) | PowerShell Script (`compile_docker.ps1`) |
|---------|-----------------------------------|------------------------------------------|
| **XML Parsing** | Docker + xmlstarlet | Native PowerShell `[xml]` type |
| **HTML Generation** | Bash heredoc + xmlquery Docker | Native PowerShell with here-strings |
| **ZIP Creation** | `zip` command | Native `Compress-Archive` cmdlet |
| **FMU Extraction** | `unzip` command | Native `Expand-Archive` cmdlet |
| **FMU Update** | `zip -ur` command | Native `Expand-Archive` + `Compress-Archive` |
| **WebAssembly Build** | Docker + emscripten | Docker + emscripten (same) |
| **Path Handling** | Direct Unix paths | Windows to Docker path conversion |
| **CMake Patching** | `sed` in-place | PowerShell regex replace |

## Detailed Differences

### 1. XML Parsing

**Bash (Docker-based):**
```bash
xmlquery() {
    docker run --rm -v .:/data pnnlmiscscripts/xmlstarlet sel --novalid $@ /data/$XML_FILE 
}

GUID=$(xmlquery -t -v '//fmiModelDescription/@guid')
STATE1_VR=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]' -v '@valueReference')
```

**PowerShell (Native):**
```powershell
[xml]$xml = Get-Content $modelDescription -Encoding UTF8

function Get-XmlValue {
    param([string]$XPath, [string]$Attribute = $null)
    $node = $xml.SelectSingleNode($XPath)
    if ($Attribute) {
        return $node.GetAttribute($Attribute)
    } else {
        return $node.InnerText
    }
}

$GUID = Get-XmlValue -XPath "//fmiModelDescription" -Attribute "guid"
$stateNodes = $xml.SelectNodes("//ScalarVariable[Real/@derivative]")
```

**Advantages of PowerShell approach:**
- ✅ No Docker overhead for XML operations
- ✅ Faster execution
- ✅ Built-in error handling
- ✅ Type-safe XML manipulation
- ✅ Direct object access

### 2. HTML Generation

**Bash:**
```bash
cat > "$build_dir/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
<title>Web FMI: $FMU_NAME</title>
...
EOF
```

**PowerShell:**
```powershell
$html = @"
<!DOCTYPE html>
<html>
<head>
<title>Web FMI: $FMU_NAME</title>
...
"@

$html | Set-Content -Encoding UTF8 $indexFile
```

### 3. Archive Operations

**Bash:**
```bash
# Extract
unzip -q "$INPUT" -d "$fmu_dir"

# Create
zip -j "$zipfile" "$build_dir/$name.js" "$build_dir/$name.xml"

# Update FMU
(cd "$fmu_dir" && zip -ur "../$INPUT" binaries/wasm32)
```

**PowerShell:**
```powershell
# Extract
$fmu_temp = Join-Path $current_dir "temp_fmu.zip"
Copy-Item $INPUT $fmu_temp -Force
Expand-Archive -LiteralPath $fmu_temp -DestinationPath $fmu_dir -Force

# Create
Compress-Archive -LiteralPath $filesToZip -DestinationPath $zipfile -Force

# Update FMU (more complex but native)
Expand-Archive -LiteralPath $INPUT -DestinationPath $tempUpdateDir -Force
# ... add files ...
Compress-Archive -Path "$tempUpdateDir\*" -DestinationPath $tempFmuZip -Force
Move-Item $tempFmuZip $INPUT -Force
```

### 4. CMakeLists.txt Patching

**Bash:**
```bash
sed -i '/set(FMU_TARGET_SYSTEM_NAME "darwin")/a\
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Emscripten")\
  set(FMU_TARGET_SYSTEM_NAME "emscripten")' "$fmu_dir/sources/CMakeLists.txt"
```

**PowerShell:**
```powershell
$cmakeContent = Get-Content $cmakeFile -Raw

if ($cmakeContent -notmatch "emscripten") {
    $cmakeContent = $cmakeContent -replace '(set\(FMU_TARGET_SYSTEM_NAME "darwin"\))', 
@'
$1
elseif(${CMAKE_SYSTEM_NAME} STREQUAL "Emscripten")
  set(FMU_TARGET_SYSTEM_NAME "emscripten")
'@
    Set-Content -Path $cmakeFile -Value $cmakeContent -NoNewline
}
```

### 5. Path Conversion

**Bash:**
```bash
# Native Unix paths work directly
current_dir="$(pwd)"
docker run --rm -v "$current_dir":/src -w /src ...
```

**PowerShell:**
```powershell
# Needs conversion for Docker
function Convert-ToDockerPath {
    param([string]$WindowsPath)
    $unixPath = $WindowsPath -replace '\\', '/'
    if ($unixPath -match '^([A-Za-z]):(.*)$') {
        $drive = $matches[1].ToLower()
        $path = $matches[2]
        return "/$drive$path"
    }
    return $unixPath
}

$current_dir = (Get-Location).Path
$docker_current_dir = Convert-ToDockerPath $current_dir
docker run --rm -v "${docker_current_dir}:/src" -w /src ...
```

## Docker Usage Comparison

### Both Scripts Use Docker For:
1. Emscripten compilation (`emcmake`, `cmake`)
2. WebAssembly linking (`emcc`)
3. Building OpenModelica FMUs (with CVODE)
4. Building Dymola FMUs

### Only Bash Uses Docker For:
1. ❌ XML parsing (xmlstarlet container)
2. ❌ CMake patching (sed in Alpine container)

### PowerShell Uses Native For:
1. ✅ XML parsing (`[xml]` type accelerator)
2. ✅ CMake patching (regex replace)
3. ✅ HTML generation (string interpolation)
4. ✅ ZIP operations (Compress-Archive/Expand-Archive)


## Migration Notes

If porting from bash to PowerShell:
1. Replace `xmlquery` calls with native XPath
2. Replace heredocs with here-strings
3. Replace `zip`/`unzip` with Compress-Archive/Expand-Archive
4. Add Windows-to-Docker path conversion
5. Use `-Force` flag to avoid prompts
6. Set `$ErrorActionPreference = "Stop"` for bash-like error handling
