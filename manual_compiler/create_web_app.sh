#!/bin/bash
# extract-states-params.sh - Generate dbs-fmi + charts + parameters HTML (pure grep/sed/awk)

if [ $# -ne 1 ]; then
  echo "Usage: $0 modelDescription.xml" >&2
  exit 1
fi

XML_FILE="$1"
FMU_NAME=$(basename "$XML_FILE" .xml)
JS_NAME="${FMU_NAME}.js"

# Extract metadata
GUID=$(grep -o 'guid="[^"]*"' "$XML_FILE" | head -1 | sed 's/.*guid="//;s/"$//')
START_TIME=$(grep -o 'startTime="[0-9.e-]*"' "$XML_FILE" | head -1 | sed 's/.*="//;s/"$//' || echo "0.0")
STOP_TIME=$(grep -o 'stopTime="[0-9.e-]*"' "$XML_FILE" | head -1 | sed 's/.*="//;s/"$//' || echo "2")
TOLERANCE=$(grep -o 'tolerance="[0-9.e-]*"' "$XML_FILE" | head -1 | sed 's/.*="//;s/"$//' || echo "1e-9")
FSTEP_SIZE=$(grep -o 'stepSize="[0-9.e-]*"' "$XML_FILE" | head -1 | sed 's/.*="//;s/"$//' || echo "0.001")

# Extract first 2 state variables (variables with matching der* derivative reference)
STATE_DATA=$(awk '
  /<ScalarVariable/ { inVar=1; block=""; next }
  inVar && /<\/ScalarVariable>/ { 
    inVar=0
    if (block ~ /derivative="[0-9]+"/) {
      # Extract name and valueReference from der line
      if (match(block, /name="([^"]+)"/)) name = substr(block, RSTART+6, RLENGTH-7)
      if (match(block, /valueReference="([0-9]+)"/)) vr = substr(block, RSTART+16, RLENGTH-17)
      if (name != "" && vr != "") {
        print vr ":" name
        count++
        if (count >= 2) exit
      }
    }
    block=""
  }
  inVar { block = block $0 }
' "$XML_FILE")

VR_LIST=$(echo "$STATE_DATA" | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
LABEL_LIST=$(echo "$STATE_DATA" | cut -d: -f2- | tr '\n' ',' | sed 's/,$//')

# Extract first 10 parameters (causality="parameter")
# Extract first 10 ScalarVariable blocks with causality="parameter" and Real subelement
PARAMS=$(awk '
  /<ScalarVariable/ { inVar=1; block=$0 ORS; next }
  inVar {
    block = block $0 ORS
    if ($0 ~ /<\/ScalarVariable>/) {
      inVar=0
      if (block ~ /causality="parameter"/ && block ~ /<Real/) {
        # name
        name=""
        if (match(block, /name="[^"]+"/)) {
          name = substr(block, RSTART+6, RLENGTH-7)
        }
        # valueReference
        vr=""
        if (match(block, /valueReference="[^"]+"/)) {
          vr = substr(block, RSTART+16, RLENGTH-17)
        }
        # start
        start=""
        if (match(block, /start="[^"]+"/)) {
          start = substr(block, RSTART+7, RLENGTH-8)
        }
        # min
        minv=""
        if (match(block, /min="[^"]+"/)) {
          minv = substr(block, RSTART+5, RLENGTH-6)
        }
        # nominal
        nominal=""
        if (match(block, /nominal="[^"]+"/)) {
          nominal = substr(block, RSTART+9, RLENGTH-10)
        }

        # decide default and is_start flag
        default=start
        is_start=1
        if (start == "" || start ~ /^0*(\.0*)?$/) {
          default=nominal
          is_start=0
        }

        # fallback ranges
        if (minv == "") minv="0.0"
        if (default == "") default="1"
        maxv="2"   # per your example: max always 2

        printf "%s,%s,%s,%d,%s,%s\n", name, vr, default, is_start, minv, maxv
        count++
        if (count>=10) exit
      }
      block=""
    }
  }
' "$XML_FILE")

# Build inputs attribute for dbs-fmi
INPUTS=""
RANGES=""
while IFS=',' read -r name vr default is_start min max; do
  INPUTS="$INPUTS$name,$vr,$default,1,t;"
  RANGES="$RANGES  <dbs-range id=\"$name\" label=\"$name\" min=\"$min\" max=\"$max\" default=\"$is_start\" step=\"0.1\"></dbs-range>
"
done <<< "$PARAMS"

INPUTS=${INPUTS%;}  # Remove trailing semicolon

# Generate complete HTML
cat << EOF
<html>
<head>
<title>Web FMI simulator</title>
<script src="dbs-shared.js"></script>
<script src="dbs-chartjs.js"></script>
<style>
  .w3-row:after,.w3-row:before{content:"";display:table;clear:both}
  .w3-third,.w3-twothird,.w3-threequarter,.w3-quarter{float:left;width:100%}
  .w3-twothird{width:66.66666%}
  .w3-third{width:33.33333%}
</style>
</head>
<body>  
  <div class="w3-row">
    <div class="w3-twothird">
      <h2>Web FMI Simulation</h2>
<dbs-fmi id="fmi" 
  src="$JS_NAME" 
  fminame="$FMU_NAME" 
  guid="$GUID"
  valuereferences="$VR_LIST"
  valuelabels="$LABEL_LIST"
  inputs="$INPUTS"
  mode="oneshot" starttime="$START_TIME" stoptime="$STOP_TIME" tolerance="$TOLERANCE" fstepsize="$FSTEP_SIZE">
</dbs-fmi>
<dbs-chartjs4 fromid="fmi" refindex="0" labels="time,${LABEL_LIST%%,*}" timedenom="1"></dbs-chartjs4>
EOF

# Second chart if exists
if [ "$(echo "$LABEL_LIST" | tr ',' '\n' | wc -l)" -gt 1 ]; then
  SECOND_LABEL=$(echo "$LABEL_LIST" | sed 's/[^,]*,//')
  echo "  <dbs-chartjs4 fromid=\"fmi\" refindex=\"1\" labels=\"time,$SECOND_LABEL\" timedenom=\"1\"></dbs-chartjs4>"
fi
cat << EOF2
    </div>
    <div class="w3-third">
      <h2>Parameters</h2>
EOF2

# Parameter ranges
echo "$RANGES"
cat << EOF3
    </div>
  </div>
</body>
</html>
EOF3
