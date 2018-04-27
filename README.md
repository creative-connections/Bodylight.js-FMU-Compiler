FMU -> JS

### Compile environment setup on WSL

Install Windows Subsystem for Linux (tested on the Ubuntu distribution)

Prerequisites

```
unzip libxml2-utils python2.7 python nodejs cmake default-jre git
```

Emscripten SDK
```
git clone https://github.com/juj/emsdk.git
cd emsdk
./emsdk update
./emsdk install latest
./emsdk activate latest 
```



