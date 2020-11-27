# Bodylight.js FMU Compiler

This is scripts facilitating compilation of FMU files with embedded
source code to JavaScript.

It contains Docker container to run this compiler in any platform.
It also contains scripts to be executed on Linux platform with EMSDK already installed there and index.html and python script run as CGI with simple web service serving compilation.
See [Bodylight-Virtualmachine](https://github.com/creative-connections/Bodylight-VirtualMachine) for a sample configuration on SL 7.x platform.

Currently supports FMUs exported from Dymola (with sources) and OpenModelica.

# 1.Docker container usage
It contains Docker container to run this compiler in any platform.

## Windows instructions

1. Install [docker](https://docs.docker.com/install/)

2. Download this repository and open PowerShell in the top directory

If you decide to clone this repository, take care to disable automatic line ending conversion in git.

3. Build the docker image
```powershell
docker build -t bodylight.js.fmu.compiler .
```
This builds the Dockerfile as bodylight.js.fmu.compiler.

#### Usage
Put a `name.fmu` file into the `input` directory and run the following command in PowerShell inside the directory. Taking care to replace name.fmu at the end of the command with the name of your `.fmu` file.

```powershell
docker run --rm --mount "type=bind,source=$(Get-Location)\input,target=/input" --mount "type=bind,source=$(Get-Location)\output,target=/output" bodylight.js.fmu.compiler:latest bash worker.sh name.fmu
```

After the compilation finishes, `input/name.fmu` is deleted and the resulting `name.js` file is copied to `output`. Along with the compilation log `name.log`.


## Linux instructions

1. Install [docker](https://docs.docker.com/install/)

2. Clone this repository and cd inside

3. Build the docker image
```bash
docker build -t bodylight.js.fmu.compiler "$(pwd)"
```
This builds the Dockerfile as bodylight.js.fmu.compiler. You might need to run this command with root privileges.


### Automatic compilation
#### Starting the compiler
```bash
docker run -d \
  --name bodylight.js.fmu.compiler \
  --mount type=bind,source="$(pwd)"/input,target=/input \
  --mount type=bind,source="$(pwd)"/output,target=/output \
  --rm bodylight.js.fmu.compiler:latest bash worker.sh
```
This starts the docker container and binds the `input` and `output` directories.

#### Stopping the compiler
```bash
docker stop bodylight.js.fmu.compiler
```

#### Usage
Put `name.fmu` files into the `input` directory. After the compilation finishes,
`input/name.fmu` is deleted and the resulting `name.js` file is copied to
`output`. Along with the compilation log `name.log`.

Files are processed sequentially in alphabetical order.

In case of error, only the compilation log will be present in the output directory.


### Manual compilation
Put a `name.fmu` file into the `input` directory and run the following command inside the directory. Taking care to replace name.fmu at the end of the command with the name of your `.fmu` file.

```bash
docker run \
  --mount type=bind,source="$(pwd)"/input,target=/input \
  --mount type=bind,source="$(pwd)"/output,target=/output \
  --rm bodylight.js.fmu.compiler:latest bash worker.sh name.fmu
```

After the compilation finishes, `input/name.fmu` is deleted and the resulting `name.js` file is copied to `output`. Along with the compilation log `name.log`.

# 2.Local scripts usage

Be sure that EMSDK, GLIBC 2.18, Python 3 and CMake are installed e.g.
- https://github.com/emscripten-core/emsdk.git
- https://ftp.gnu.org/gnu/glibc/glibc-2.18.tar.gz
- Python3 - use your system installer: e.g. `yum install python3` or `apt install python3` or install Miniconda or Anaconda environment (https://www.anaconda.com/products/individual)
- CMake - use your system installer: e.g. `yum install cmake` or `apt install cmake`

Make the Bodylight.js-FMU-Compiler accessible for Apache web server.
E.g.
```
Alias "/compiler" "/home/vagrant/Bodylight.js-FMU-Compiler/"
<Directory "/home/vagrant/Bodylight.js-FMU-Compiler">
  Options +ExecCGI
  AddHandler cgi-script .py
  Header set Access-Control-Allow-Origin "*"
  Require all granted
  Options +Indexes +FollowSymLinks +IncludesNOEXEC
  IndexOptions FancyIndexing HTMLTable NameWidth=*
  AllowOverride All
</Directory> 
```

Allow access to input and output subdirectories.
```
chmod ugo+rwx input output
```

# 3. Part of Bodylight-VirtualMachine
Bodylight.js-FMU-Compiler is configured within Bodylight-VirtualMachine. See it at https://github.com/creative-connections/Bodylight-VirtualMachine
