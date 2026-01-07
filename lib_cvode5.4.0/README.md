# introduction 
the sundials 6.x depended lib compiled to WASM
# rebuild
To rebuild
1. Download and extract sundials 6.x sources to `~\sundials`
2. Download and install emscripten sdk to `~\emsdk`
3. install lates emscripten `cd ~emsdk; ./emsdk install latest`
4. set emsdk environment `source ~/emsdk/emsdk_env.sh`
5. compile sundials
```bash
cd ~/sundials
mkdir build
cd build
emcmake cmake ..
emmake make
```

