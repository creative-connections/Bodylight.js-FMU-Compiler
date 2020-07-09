# Usage: ./compile.sh [filename.fmu]
# output will be written to /output directory
# input file will be removed
# docker earlier verion 1.13.1
sudo docker run -d   --name bodylight.js.fmu.compiler -v $(pwd):/input -v $(pwd)/output:/output --rm bodylight.js.fmu.compiler:latest bash worker.sh $1
