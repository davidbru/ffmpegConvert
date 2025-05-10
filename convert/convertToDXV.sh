#!/bin/bash

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

    finalCommand="$finalCommand ffmpeg -i $fileOrig -an -c:v dxv -vf \"scale=min(1920\,iw):-2,scale=trunc(iw/16)*16:trunc(ih/16)*16,fps=30\" -r 30 $fileTarget; "

    #----------------------#
    # MAKE THUMBNAIL MOVIE #
    #----------------------#
    mkdir -p "$fileTargetFolder/__thumbs_mov"
    printf -v fileTargetThumbnailMovie "%q" "$fileTargetFolder/__thumbs_mov/$fnameWithoutExt.mp4"

    finalCommand="$finalCommand ffmpeg -i $fileOrig -an -c:v h264_videotoolbox -vf \"scale='if(gt(iw,480),480,iw)':'trunc(ow/a/2)*2', fps=30\" -b:v 250k $fileTargetThumbnailMovie; "
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
outputFolder="${inputFolder}_dxv"
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
