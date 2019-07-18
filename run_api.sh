#!/bin/bash

# Execution parameters
AppHost='<TRIFACTAHOST>'
#AppHost='latest-dev.trifacta.net'
AppPort='<TRIFACTAPORT>'
User="lni"
Password='<PASSWORD>'
SSLEnabled=0
Interval=15  #Interval to poll job status (seconds)
JobName="<JOBNAME>"
ApiToken="<APITOKEN>"
useToken=0


if [ $# -lt 1 ]
 then
 echo "No parameters specified. Using default"
fi 

# Define default Job parameters
WrangleId=1
JobType="photon"
RunDefaultSettings=0
OutputPath=""
AuthMethod="-u $User:$Password"
Overrides=""
ParamOverrides=""
Parameters=""

# Flags and overrides
while test $# -gt 0; 
 do
 case "$1" in
  -d|--default)
    shift
      RunDefaultSettings=1
    ;;
	-w|--wrangleId) 
	   shift
	   if test $# -gt 0
	   then
		WrangleId=$1
	   else
		echo "No WrangleId supplied. Using default '1'."
	   fi
	   shift
	   ;;
	-o|--outputPath)
      shift
      if test $# -gt 0
        then
           OutputPath=$1
      else
        echo "No output path supplied."
      fi
      shift
      ;;
  -f|--outputFormat)
      shift
      if test $# -gt 0
        then
           OutputFormat=$1
      else
        echo "No output path supplied."
      fi
      shift
      ;;
  -j|--jobType)
      shift
      if test $# -gt 0
        then
           JobType=$1    # either 'photon' or 'spark'
      else
        echo "No execution type supplied."
      fi
      shift
      ;;
  -p|--parameters)
      shift
      if test $# -gt 0
        then
           Parameters=$1    # either 'photon' or 'spark'
      else
        echo "No parameter ovverides supplied."
      fi
      shift
      ;;
  -t|--token)
    shift
      useToken=1
      ;;
  -s|--secure)
    shift
      SSLEnabled=1
    ;;
	-h|--help)
	   echo "./run_api.sh [-t] [-s] -d OR -j <jobType> -w <wrangleId> -f <outputFormat> -o <outputFile> -p <{parameters}>"
	   exit 1;
	   ;;
	*)
           break
           ;;
 esac
done


echo "WrangleId is $WrangleId."
echo "Job Type is $JobType"
echo "OutputPath is $OutputPath"
echo "OutputFormat is $OutputFormat"
echo "Default - $RunDefaultSettings"


# Example of basic run input
# {
#  "wrangledDataset": {
#    "id": 7
#  }
#}

# Example of Parameter override
#"runParameters": {
#      "overrides": {
#        "data": [{
#          "key": "varRegion",
#          "value": "02"
#        }
#]} },

# Check if there are parameters provided
if [[ $Parameters == *"key"* ]]
  then
    ParamOverrides=",\
    \"runParameters\": {\
      \"overrides\": {\
        \"data\": [\
          $Parameters\
    ] }}"
  else
    ParamOverrides=""
fi

# Build POST form with settings and overrides
if [ $RunDefaultSettings -eq 0 ]
  then
    Overrides="\"execution\": \"$JobType\",\
    \"writesettings\": [{\
        \"path\": \"$OutputPath\",\
        \"action\": \"create\",\
        \"format\": \"$OutputFormat\"\
      }] "
  else Overrides=""
fi

# Build Request body
RequestBody="{\"wrangledDataset\": {\"id\": $WrangleId}, \"ranfrom\": \"ui\", \"overrides\": { $Overrides} $ParamOverrides }"
echo $RequestBody

# Use API Token if flag is enabled
if [ $useToken -eq 1 ]
  then
    AuthMethod="-u $User: -H \"Authorization: Bearer $ApiToken\""
  else
    AuthMethod="-u $User:$Password"
fi

# Launch Job - Use Https if SSL
if [ $SSLEnabled -eq 1 ] 
  then
    echo "curl -k -X POST $AuthMethod -H \"Content-Type: application/json\" \"https://$AppHost:$AppPort/v4/jobGroups\" -d \"$RequestBody\""
    JobLaunched=`curl -s -k -X POST $AuthMethod -H "Content-Type: application/json" "https://$AppHost:$AppPort/v4/jobGroups" -d "$RequestBody"`
    echo $JobLaunched >  $JobName.out
  else
    echo "curl -X POST $AuthMethod -H \"Content-Type: application/json\" \"http://$AppHost:$AppPort/v4/jobGroups\" -d \"$RequestBody\""
    JobLaunched=`curl -s -X POST $AuthMethod -H "Content-Type: application/json" "http://$AppHost:$AppPort/v4/jobGroups" -d "$RequestBody"`
    echo $JobLaunched >  $JobName.out 
fi

# Expects output
# {
#    "reason": "JobStarted",
#    "sessionId": "eb3e98e0-02e3-11e8-a819-25c9559a2a2c",
#    "id": 9
# }

# Check if Job was launched properly
if [[ $JobLaunched == *"JobStarted"* ]]
then
  echo "Job launched succesfully"
else
  echo "Failed to launch job. See $JobName.out for details"
  exit 1
fi

# Parse JobId. Requires Python
JobId=`echo $JobLaunched | python -c "import sys, json; print json.load(sys.stdin)['id']"`
JobId=$((JobId/1))
echo "Job Id - $JobId"

JobInfo=''
JobStatus='Pending'

# Poll Trifacta with job ID for status 
if [ "$JobId" -ge 0 ] 
 then
  echo "Checking status for $JobId"

  # Start loop to monitor job status
  while [ "$JobStatus" != '"Complete"' ] && [ "$JobStatus" != '"Failed"' ]
  do
    # Get job status from server
    if [ $SSLEnabled -eq 1 ] 
      then
        JobStatus=`curl -k -s $AuthMethod -H "Content-Type: application/json" "https://$AppHost:$AppPort/v4/jobGroups/$JobId/status"` 
        echo $JobStatus >> $JobName.out 
      else
        JobStatus=`curl -s $AuthMethod -H "Content-Type: application/json" "http://$AppHost:$AppPort/v4/jobGroups/$JobId/status"` 
        echo $JobStatus >> $JobName.out 
    fi

    # Loop if not completed/failed
    if [ "$JobStatus" != '"Complete"' ] && [ "$JobStatus" != '"Failed"' ]
     then
      echo "Waiting for job to complete..."
      sleep $Interval
    fi    
  done 
 else 
  echo "Failed to get JobId. See $JobName.err for details"
  exit 1
fi 

# Exit cases
if [ "$JobStatus" = '"Complete"' ]
 then
  echo "Job "$JobId" is complete."
  exit 0
 else
  echo "Job failed to complete. See logs for errors"
  exit 1
fi
