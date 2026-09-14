#!/bin/bash

# Usage: ./convertToDXV.sh --folder /path/to/folder

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
  fileTargetFolder="${outputFolder}${folderToOrig:${#inputFolder}}"

  if [ "$fext" == "mov" ] || [ "$fext" == "mkv" ] || [ "$fext" == "mp4" ] || [ "$fext" == "avi" ] || [ "$fext" == "gif" ] || [ "$fext" == "webm" ]; then
    #-------------------------------------#
    # IF IT IS A MOVIE/GIF --> CONVERT IT #
    #-------------------------------------#

    # escape special characters
    printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithoutExt.mov"

    finalCommand="$finalCommand ffmpeg -i $fileOrig -an -c:v dxv -vf \"scale=min(1920\,iw):-2,scale=trunc(iw/16)*16:trunc(ih/16)*16,fps=30\" -r 30 $fileTarget; "
  else
    #-------------------#
    # ELSE JUST COPY IT #
    #-------------------#

    # escape special characters
    printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithExt"

    finalCommand="$finalCommand cp $fileOrig $fileTarget; "
  fi
}

# Parse --folder argument
inputFolder=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --folder)
      inputFolder="$2"
      shift 2
      ;;
    --folder=*)
      inputFolder="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --folder /path/to/folder" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$inputFolder" ]]; then
  echo "Usage: $0 --folder /path/to/folder" >&2
  exit 1
fi
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

# Process files (skip __thumbs_mov folders left over from before thumbnail
# generation moved to createContactSheet.sh)
while IFS= read -r -d '' file; do
  addToFinalCommand "$file"
done < <(find "$inputFolder" -type f -print0 | grep -zv "__thumbs_mov")

#echo "$finalCommand"
eval "$finalCommand"

# Refresh the contact sheet for the original folder -- DXV output can't be
# previewed in Explorer/Finder, so this is the browsable overview instead.
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$scriptDir/../contactsheet/createContactSheet.sh" --folder "$inputFolder"
