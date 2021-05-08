# Bodylight.js FMU Compiler

**FMI** stands for [Functional Mockup Interface standard](https://fmi-standard.org/) for interchanging dynamic models. **FMU** stands for Functional Mockup Unit - standard encapsulated interoperable model. This repository contains scripts and configuration facilitating compilation of FMU file to Javascript with embedded WebAssembly. Such javascript conforms FMI standard and can be directly accessed by the FMI API. However, we recommend to use Bodylight.js-Components to create rich interactive web simulator and control FMI using higher level API.

This repository also contains basic HTML and Python script as CGI script to support compilation on Linux platform with (EMSDK, GlibC,...).
A basic docker container is included to run this compiler on any platform.

See [Bodylight-Virtualmachine](https://github.com/creative-connections/Bodylight-VirtualMachine) for a sample configuration in Scientific Linux 7.x.

Currently supports FMUs exported from Dymola (with sources) and OpenModelica.

To use Bodylight.js-FMU-Compiler, choose one of these options:
1. compiler in virtual machine - Vagrant tool and VirtualBox is needed
2. compiler in local environment - needs to install EMSDK,GLIBC and PYTHON3 manually
3. compiler in docker - needs docker to be installed in environment

To fully convert Modelica model to Javascript with WebAssembly see our tutorial at https://bodylight.physiome.cz/Bodylight-docs/tutorial/

## 1. Compiler in Virtual Machine

Install Bodylight-VirtualMachine using `vagrant` tool and VirtualBox. Instruction at https://github.com/creative-connections/Bodylight-VirtualMachine 

The compiler web service is available at http://localhost:8080/compiler

## 2. Compiler in Local Environmnet

Be sure that EMSDK, GLIBC 2.18, Python 3 and CMake are installed e.g.
- https://github.com/emscripten-core/emsdk.git
- https://ftp.gnu.org/gnu/glibc/glibc-2.18.tar.gz
- Python3 - use your system installer: e.g. `yum install python3` or `apt install python3` or install Miniconda or Anaconda environment (https://www.anaconda.com/products/individual)
- CMake - use your system installer: e.g. `yum install cmake` or `apt install cmake`

Bodylight.js-FMU-Compiler contains `index.html` and `save-file.py` to support compilation via simple web interface. Make the root of Bodylight.js-FMU-Compiler accessible for Apache web server, and the simple web form can be used.
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

Allow access to input and output subdirectories of `Bodylight.js-FMU-Compiler`.
```
chmod ugo+rwx input output
```

## 3. Compiler in Docker Container

It contains Docker container to run this compiler in any platform, uses older emsdk image.

### Windows instructions

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


### Linux instructions

1. Install [docker](https://docs.docker.com/install/)

2. Clone this repository and cd inside

3. Build the docker image
```bash
docker build -t bodylight.js.fmu.compiler "$(pwd)"
```
This builds the Dockerfile as bodylight.js.fmu.compiler. You might need to run this command with root privileges.


#### Automatic compilation
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


#### Manual compilation
Put a `name.fmu` file into the `input` directory and run the following command inside the directory. Taking care to replace name.fmu at the end of the command with the name of your `.fmu` file.

```bash
docker run \
  --mount type=bind,source="$(pwd)"/input,target=/input \
  --mount type=bind,source="$(pwd)"/output,target=/output \
  --rm bodylight.js.fmu.compiler:latest bash worker.sh name.fmu
```

After the compilation finishes, `input/name.fmu` is deleted and the resulting `name.js` file is copied to `output`. Along with the compilation log `name.log`.

# Examples

The following models were converted to web-based simulators using FMU compiler.
* [Simple Circulation](http://www.physiome.cz/en/simple-circulation/) - model published as part of Physiolibrary
  * Kulhánek T, Tribula M, Kofránek J, Mateják M: Simple models of the cardiovascular system for educational and research purposes. MEFANET Journal 2014; 2(2); ISSN:1805-9171. Available at WWW: http://mj.mefanet.cz/mj-04140914.
* [Nefron Simulation](http://www.physiome.cz/apps/Nephron/) - model and Bodylight.js technology published as 
  * ŠILAR, Jan, David POLÁK, Arnošt MLÁDEK, Filip JEŽEK, Theodore W KURTZ, Stephen E DICARLO, Jan ŽIVNÝ a Jiri KOFRANEK. Development of In-Browser Simulators for Medical Education: Introduction of a Novel Software Toolchain. Journal of Medical Internet Research [online]. 2019, 21(7) [cit. 2019-11-25]. DOI: 10.2196/14160. ISSN 1438-8871. Dostupné z: https://www.jmir.org/2019/7/e14160
* [Bodlight Scenarios](https://bodylight.physiome.cz/Bodylight-Scenarios) - simulators using web components. Section of hemodynamics, blood-gases, iron metabolism and virtual body preparing for publication
* [Buddy](http://physiome.cz/buddy/) - experimental simulator of most complex model of physiology [Physiomodel](https://www.physiomodel.org) 

The simple and medium size models compile into Javascript with size 0.5 MB - 2 MB. The embedded [WebAssembly](https://webassembly.org/) is supported by 4 major web browsers (Firefox,Chrome,Ms Edge,Safari). The simulation is nearly native speed (1.5x or 2x slower). One drawback can be memory limit on some mobile devices, which may prevent to run some of the most complex model (see Buddy above) there.
