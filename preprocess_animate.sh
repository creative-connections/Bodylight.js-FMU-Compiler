#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 INPUT_ANIMATE"
    exit 1
fi

if [ ! -f $1 ]; then
   echo "File $1 does not exist."
   exit 1
fi

OUT="$1.new"
name='.*name *='

while IFS= read -r line || [ -n "$line" ]
do
    echo "$line"
    if [[ $line =~ $name ]] ; then
      reference=`echo $line | awk -F"\.name" '{print $1;}'`
      echo "lib.addExportedComponent($reference);"
    fi

done < "$1"  > $OUT

rm $1
mv $OUT $1
