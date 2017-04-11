#!/bin/bash -eu
#   -e:  Exit immed. if cmd. returns non-zero status.
#   -u:  Unset vars treated as error on substitution.
#   -x:  Trace (i.e. output commands)
#   -v:  Verbose
#
for searchTerm in "raw cashews" "cashews, raw"
do
  echo "$searchTerm:"
  echo "--------------------------------------------------------------------------------"
  curlData="{\"q\":\"$searchTerm\",\"max\":\"10\",\"offset\":\"0\"}"
  #curl -H "Content-Type: application/json" -d "$curlData" DEMO_KEY@api.nal.usda.gov/ndb/search | grep -i -e "name"
  curl -H "Content-Type: application/json" -d "$curlData" DEMO_KEY@api.nal.usda.gov/ndb/search
done;

