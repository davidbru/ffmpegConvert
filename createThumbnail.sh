#!/bin/bash


inputFile="/Volumes/vj_assets/new_long/Abstract_Liquid.mp4"
outputFile="/Volumes/vj_assets/new_long/Abstract_Liquid.jpg"

durationFull=$(ffmpeg -i $inputFile 2>&1 | grep Duration | awk '{print $2}' | tr -d ,)
durationHalf=$(echo $durationFull | awk -F ':' '{print ($3+$2*60+$1*3600)/2}' | awk -F ',' '{print ($1)}')
ffmpeg -ss $durationHalf -i $inputFile -vframes 1 $outputFile
