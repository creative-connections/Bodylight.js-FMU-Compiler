#!/bin/bash
# fmu-xmlstarlet-fixed.sh - CORRECT SYNTAX for pnnlmiscscripts/xmlstarlet volume mount
# Extracts FMU data WITHOUT usage errors, keeps _flatNorm suffix
# Usage: ./fmu-xmlstarlet-fixed.sh modelDescription.xml > fmi-ui.html 2>debug.log

if [ $# -ne 1 ]; then
  echo "Usage: $0 modelDescription.xml" >&2
  exit 1
fi

XML_FILE="$1"
BASENAME=$(basename "$XML_FILE")

# FIXED xmlquery - CORRECT Docker volume + xmlstarlet syntax
xmlquery() {
    echo DEBUG: docker run --rm -v .:/data pnnlmiscscripts/xmlstarlet sel --novalid $@ /data/$XML_FILE >&2
  docker run --rm -v .:/data pnnlmiscscripts/xmlstarlet sel --novalid $@ /data/$XML_FILE 
}

FMU_NAME=$(basename "$XML_FILE" .xml)
JS_NAME="${FMU_NAME}.js"

echo "DEBUG: FMU=$FMU_NAME XML=$BASENAME" >&2

echo 1. METADATA - simple attribute queries  >&2
GUID=$(xmlquery -t -v '//fmiModelDescription/@guid') # || xmlquery -t -v '//@guid' || echo "{1d4ccc00-2d27-41b0-ae1b-9e8bf1ab544b}")
START_TIME=$(xmlquery -t -v '//DefaultExperiment/@startTime') # || echo "0")
STOP_TIME=$(xmlquery -t -v '//DefaultExperiment/@stopTime') # || echo "2")
TOLERANCE=$(xmlquery -t -v '//DefaultExperiment/@tolerance') # || echo "1e-9")
STEP_SIZE=$(xmlquery -t -v '//DefaultExperiment/@stepSize') # || echo "0.001")

echo "DEBUG: GUID='$GUID'" >&2
echo "DEBUG: TIMES start=$START_TIME stop=$STOP_TIME tol=$TOLERANCE step=$STEP_SIZE" >&2

echo 2.States first 2 >&2
STATE1_VR=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]' -v '@valueReference')
STATE1_NAME=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]' -v '@name')
STATE1_OVR=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=1]/Real' -v '@derivative')
STATE1_ONAME=$(xmlquery -t -m "//ScalarVariable[@valueReference='$STATE1_OVR'][1]" -v '@name')
#STATE2_VR=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=2]' -v '@valueReference')
#STATE2_NAME=$(xmlquery -t -m '//ScalarVariable[Real/@derivative][position()=2]' -v '@name')

VR_LIST="${STATE1_OVR},${STATE1_VR}"
LABEL_LIST="${STATE1_ONAME},${STATE1_NAME}"

echo "DEBUG STATES: VR=$VR_LIST LABELS=$LABEL_LIST" >&2

#VR_LIST=$(echo "$STATES" | cut -d, -f1 | paste -sd, - | sed 's/,$//')
#LABEL_LIST=$(echo "$STATES" | cut -d, -f2- | paste -sd, - | sed 's/,$//')
#echo "DEBUG VR_LIST='$VR_LIST' LABEL_LIST='$LABEL_LIST'" >&2

echo 3. PARAMETERS causality="parameter" first 10  >&2
PARAMS=$(xmlquery -t \
  -m '//ScalarVariable[@causality="parameter"][position()<11]' \
  -v '@name' -o ',' -v '@valueReference' -o ',' \
  -m './Real[1]' -v '@start' -o ',' -v '@nominal' \
  -n)

echo "DEBUG PARAMS: '$PARAMS'" >&2

# Parse params → inputs/ranges
INPUTS=""
RANGE_HTML=""
echo "$PARAMS" | tr '\n' ';' | sed 's/;;*/;/g' | tr ';' '\n' | while IFS=, read -r NAME VREF START NOM; do
  [ -z "$NAME" ] && continue
  START=${START:-0}
  NOM=${NOM:-1}
  MULT=$([ "$START" = "0" ] && echo "10" || echo "1")
  MIN_R=$([ "$START" = "0" ] && echo "0" || echo "0.1")
  
  INPUTS="${INPUTS}${NAME},${VREF},${NOM},${MULT},t;"
  RANGE_HTML="${RANGE_HTML}  <dbs-range id=\"${NAME}\" label=\"${NAME}\" min=\"${MIN_R}\" max=\"2\" default=\"1\" step=\"0.1\"></dbs-range>\n"
done
INPUTS="${INPUTS%;}"
echo "DEBUG INPUTS preview: '${INPUTS:0:100}...'" >&2

# Charts
CHARTS=""
i=0
echo "$STATES" | tr '\n' ';' | sed 's/;;*/;/g' | tr ';' '\n' | while IFS=, read -r vref label; do
  [ -n "$vref" ] && {
    CHARTS="${CHARTS}  <dbs-chartjs4 fromid=\"fmi\" refindex=\"$i\" labels=\"time,$label\" timedenom=\"1\"></dbs-chartjs4>\n"
    ((i++))
  }
done

# PRODUCTION HTML
cat << EOF
<!DOCTYPE html>
<html>
<head>
<title>Web FMI: $FMU_NAME</title>
<script src="dbs-shared.js"></script>
<script src="dbs-chartjs.js"></script>
<style>
.w3-row:after,.w3-row:before{content:"";display:table;clear:both}
.w3-third,.w3-twothird{float:left;width:100%}
.w3-twothird{width:66.66666%}
.w3-third{width:33.33333%}
</style>
</head>
<body>  
<div class="w3-row">
  <div class="w3-twothird">
    <h2>Web FMI Simulation</h2>
    <dbs-fmi id="fmi" src="$JS_NAME" fminame="$FMU_NAME" guid="$GUID"
             valuereferences="$VR_LIST" valuelabels="$LABEL_LIST"
             inputs="$INPUTS" mode="oneshot" starttime="$START_TIME" 
             stoptime="$STOP_TIME" tolerance="$TOLERANCE" fstepsize="$STEP_SIZE">
    </dbs-fmi>
$CHARTS  </div>
  <div class="w3-third">
    <h2>Parameters</h2>
$RANGE_HTML  </div>
</div>
</body>
</html>
EOF

echo "=== HTML GENERATED SUCCESSFULLY ===" >&2
