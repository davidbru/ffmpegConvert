#!/bin/bash

# Convert files with ffmpeg in user specified folder
#   Creates a "converted" folder in the specified folder with the converted files

# Forces a maximum video width of 1920
# Forces a frame rate of 30

# Requirements
#   ffmpeg needs to be present in PathVar
#   Current location: /usr/local/bin/ffmpeg

# Usage
#   chmod +x ./convertToH264.sh
#   ./convertToH264.sh
#       specify /path/to/folder

# ffmpeg -i inputFile.mkv -an -c:v mjpeg -vf "scale='min(1280,iw)':-1" -b:v 12M -ss 00:05:44 -t 00:00:33 outputFile.mov
# ffmpeg -i inputFile.mkv -an -c:v hap -vf "scale='min(1280,iw)':-1" -b:v 12M -ss 00:05:44 -t 00:00:33 outputFile.mov

finalCommand=""

addToFinalCommand() {
  echo "addToFinalCommand $1"

  export fspec=$1
  fnameWithExt=$(basename "$fspec")
  folderToOrig=$(dirname "$fspec")
  fnameWithoutExt="${fnameWithExt%.*}"
  fext="${fnameWithExt##*.}"

  # escape special characters
  printf -v fileOrig "%q" "$fspec"

  # replace path to get targetFolder
  fileTargetFolder=$(sed "s|$inputFolder|$outputFolder|" <<<$folderToOrig)

  if [ "$fext" == "mov" ] || [ "$fext" == "mkv" ] || [ "$fext" == "mp4" ] || [ "$fext" == "avi" ] || [ "$fext" == "gif" ] || [ "$fext" == "webm" ]; then
    #-------------------------------------#
    # IF IT IS A MOVIE/GIF --> CONVERT IT #
    #-------------------------------------#

    # escape special characters
    printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithoutExt.mov"

    finalCommand="$finalCommand ffmpeg -i $fileOrig -an -c:v h264_videotoolbox -vf \"scale=min(1920\,iw):-2,scale=trunc(iw/4)*4:trunc(ih/4)*4, fps=30\" -b:v 12000k $fileTarget; "
  else
    #-------------------#
    # ELSE JUST COPY IT #
    #-------------------#

    # escape special characters
    printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithExt"

    finalCommand="$finalCommand cp $fileOrig $fileTarget; "
  fi
}

# Catch trailing slash from user input
read -p "Pfad zum zu konvertierenden Ordner: [/Users/david/Desktop/vj_test/ToConvert] " inputFolder
inputFolder=${inputFolder:-"/Users/david/Desktop/vj_test/ToConvert"}
inputFolder="${inputFolder%/}"  # Remove trailing slash if present

echo "$inputFolder"
# Create "converted" folder
outputFolder="${inputFolder}_h264"
mkdir -p "$outputFolder"

# Process directories first to ensure structure
find "$inputFolder" -type d | while read -r dir; do
  targetDir="${dir/$inputFolder/$outputFolder}"
  echo "folder $dir"
  mkdir -p "$targetDir"
done

# Process files
while IFS= read -r -d '' file; do
  addToFinalCommand "$file"
done < <(find "$inputFolder" -type f -print0)

#echo "$finalCommand"
eval "$finalCommand"
