# trifacta-scripts
Scripts for use with Trifacta

Usage

Command
./run_api.sh [-t] [-s] -d OR -j <jobType> -w <wrangleId> -f <outputFormat> -o <outputFile> -p <{parameters}>"

Flags:
-t | --token =  Uses API Token set inside script
-s | --secure = Uses SSL
-d | --default = Uses default settings. Uses the job's saved writesettings without any changes
-w | --wrangleId <wrangleID> = (Required) Runs the job for this specific wrangleID
-o | --outputPath <path> = Changes output path to specified location
-f | --outputFormat <csv|json|avro|parquet> = Specifies the format of output
-j | --jobType <photon|spark> = Specifies which execution environment to run in
-p | --parameters <parameters> = Specifies parameter overrides for job. Parameter overrides must be in JSON format

Examples:
./run_api.sh -s -w 123 -o s3://mybucket/lni/example.json -f json -p '{"key":"Year","value":"2016"}' 
Runs wrangleId 123 with specified parameter overrides, outputting as a JSON format. Also uses SSL.

./run_api.sh -d -w 234 
Runs wrangleId 234 with all default settings (as saved in Trifacta UI)
