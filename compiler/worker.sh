#!/bin/bash
compile () {
  FILE=$1
  filename="${FILE##*/}"
  basename="${filename%.*}"

  log="${COMPILER_HOME}/output/${basename}.log"
  build_file="build/${basename}.zip"
  output_file="${COMPILER_HOME}/output/${basename}.zip"

  [ -f ${log} ] && rm $log
  [ -f ${build_file} ] && rm $build_file
  [ -f ${output_file} ] && rm $output_file

  echo "=== Processing file ${FILE} ===" | tee -a $log

  mime=$(file ${FILE} -b --mime-type)
  if [ $mime != "application/zip" ];then
    echo "ERROR: ${FILE} (${mime}) is not a FMU type (application/zip)" | tee -a $log
    rm ${FILE}; continue
  fi

  if ! [[ `unzip -l ${FILE} | grep "modelDescription.xml"` ]];then
    echo "ERROR: ${FILE} does not contain modelDescription.xml" | tee -a $log
    rm ${FILE}; continue
  fi

  # FMUs exported by Dymola up to 2019 contain file all.c, whereas the ones exported
  # by OpenModelica do not. Therefore we can differentiate them only by the presence
  # of the all.c file.

  if [[ `unzip -l ${FILE} | grep "sources/all.c"` ]]; then
    echo "Compiling Dymola FMU, log: ${log}" | tee -a $log
    bash dymola.sh ${FILE} ${basename} |& tee -a $log
  else
    echo "Compiling OpenModelica FMU, log: ${log}" | tee -a $log
    bash openmodelica.sh ${FILE} ${basename} |& tee -a $log
  fi

  if [ ! -f ${build_file} ]; then
    echo "ERROR: compilation unsuccessful, check log for details." | tee -a $log
  else
    cp ${build_file} ${output_file}
    rm ${build_file}
    echo "Compilation finished." | tee -a $log
  fi

  rm -f ${FILE}
}

if [[ $# -eq 0 ]]; then
  inotifywait -m -r -e close_write --format '%w%f' "${COMPILER_HOME}/input" | while read FILE
  do
    compile $FILE
  done
fi

if [[ $# -eq 1 ]]; then
  compile ${COMPILER_HOME}/input/$1
fi
