#!/bin/bash

inotifywait -m -r -e create --format '%w%f' "/input" | while read FILE
do
  echo "=== Processing file ${FILE} ==="

  filename="${FILE##*/}"
  basename="${filename%.*}"
  log="/output/${basename}.log"

  mime=$(file ${FILE} -b --mime-type)
  if [ $mime != "application/zip" ];then
    echo "ERROR: ${FILE} (${mime}) is not a FMU type (application/zip)" | tee $log
    rm ${FILE}; continue
  fi

  if ! [[ `unzip -l ${FILE} | grep "modelDescription.xml"` ]];then
    echo "ERROR: ${FILE} does not contain modelDescription.xml" | tee $log
    rm ${FILE}; continue
  fi

  echo "Compiling FMU, log: ${log}"
  bash compile.sh ${FILE} ${basename} 2> $log

  build_file="/work/build/${basename}.zip"
  output_file="/output/${basename}.zip"

  if [ ! -f ${build_file} ]; then
    echo "ERROR: compilation unsuccessful, check log for details."
  else
    cp ${build_file} ${output_file}
    rm ${build_file}
    echo "Compilation finished."
  fi

  rm ${FILE}
done
