#!/bin/bash
# Script filename: convert.sh
# Description: regrids grib2 files and writes the output to the output directory
scriptName=$(basename "$0")
inputFile="${INPUT_FILE}"
outputFile="${OUTPUT_FILE}"
weightsFile="${WEIGHTS_FILE}"
descriptionFile="${DESCRIPTION_FILE}"

processFromDir=

usage="Regrids grib2 files and writes the output to the output directory.
\n\nUsage: $scriptName [-i <INPUT_FILE>] [-o <OUTPUT_FILE>] [-w <WEIGHTS_FILE>] [-d <DESCRIPTION_FILE>]
\n\n
\nAlternatively the following environment variables can be used to control this script:
\n\t - INPUT_FILE : grib2 file or directory containing grib file(s)
\n\t - OUTPUT_FILE : grib2 file or directory to output regridded file(s)
\n\t - WEIGHTS_FILE : netCDF file that contains interpolation weights
\n\t - DESCRIPTION_FILE : cdo target grid description file for the given weights file
\n\n
\nExample (with command line options):
\n\t $scriptName \\
\n\t\t -i /data/samples/icon/ \\
\n\t\t -o /output/ \\
\n\t\t -w /data/weights/icon/icon_weights.nc \\
\n\t\t -d /data/descriptions/icon/icon_description.txt
\n
\nExample (with environment variables):
\n\t export INPUT_FILE=/data/samples/icon/
\n\t export OUTPUT_FILE=/output/
\n\t export WEIGHTS_FILE=/data/weights/icon/icon_weights.nc
\n\t export DESCRIPTION_FILE=/data/descriptions/icon/icon_description.txt
\n\t $scriptName
\n"

# ':' after the argument means it has a value
while getopts ':h?i:o:w:d:' opt; do
  case $opt in
    i)  inputFile="$OPTARG"
        ;;
    o)  outputFile="$OPTARG"
        ;;
    w)  weightsFile="$OPTARG"
        ;;
    d)  descriptionFile="$OPTARG"
        ;;
    \? | h | \* ) echo -e $usage
       exit 1
       ;;
  esac
done


# process given parameters and/or environment variables

if [ -z "$inputFile" ]; then
    inputFile="$(pwd)" #if unset, use current directory
fi

if [ -d "$inputFile" ]; then
    inputDirectory=$(cd "$inputFile"; pwd) #convert to absolute path
    processFromDir=1
else
    if [ -f "$inputFile" ]; then
        inputDirectory=$(cd $(dirname $inputFile) && pwd) #convert to absolute path
        inputFileName=$(basename "$inputFile") #extract filename from path
        processFromDir=0
    else
        echo "Error: INPUT_FILE '$inputFile' not found." 1>&2
        echo -e $usage
        exit 1
    fi
fi

if [ -z "$outputFile" ]; then
    outputFile="$(pwd)" #if unset, use current directory for output
fi

if [ -d "$outputFile" ]; then
    outputDirectory=$(cd "$outputFile"; pwd) #convert to absolute path
else
    # assume it's an output file name
    outputDirectory=$(cd $(dirname $outputFile) && pwd) #extract directory from path
    outputFileName=$(basename "$outputFile") #extract filename from path
fi


if [ "$processFromDir" == "1" ]; then
    echo "Regridding all files in directory '${inputDirectory}' ..."
    for i in $(ls ${inputDirectory} | grep -v .sh); do
        input="${inputDirectory}/${i}"
        output="${outputDirectory}/regridded_${i}"
        echo "Regridding '${input}' > '${output}'..."
        cdo -f grb2 remap,${descriptionFile},${weightsFile} ${input} ${output}
    done
    echo "Done."
else
    #regrid a single file
    input="${inputDirectory}/${inputFileName}"
    output="${outputDirectory}/${outputFileName}"
    echo "Regridding '${input}' > '${output}'..."
    cdo -f grb2 remap,${descriptionFile},${weightsFile} ${input} ${output}
    echo "Done."
fi