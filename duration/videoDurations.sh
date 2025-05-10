#!/bin/bash

read -p "Pfad zum zu kontrollierenden Ordner: [/Users/david/Desktop/vj_test/ToConvert] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj_test/ToConvert"}
inputFolder="${inputFolder%/}"  # Remove trailing slash if present

# Define allowed video file extensions correctly
find "$inputFolder" -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.mkv' -o -iname '*.webm' \) -exec sh -c '
  for file do
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
    if [ -n "$duration" ]; then
      printf "%d|%s\n" "${duration%.*}" "$file"
    fi
  done
' sh {} + > videoDurations.txt
