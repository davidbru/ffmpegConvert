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
#   ./convertToH264.sh --folder /path/to/folder

# ffmpeg -i inputFile.mkv -an -c:v mjpeg -vf "scale='min(1280,iw)':-1" -b:v 12M -ss 00:05:44 -t 00:00:33 outputFile.mov
# ffmpeg -i inputFile.mkv -an -c:v hap -vf "scale='min(1280,iw)':-1" -b:v 12M -ss 00:05:44 -t 00:00:33 outputFile.mov

# h264_videotoolbox is macOS-only hardware encoding; use the NVIDIA hardware
# encoder on Windows/Linux instead (requires a supported NVIDIA GPU + driver).
if [[ "$(uname -s)" == "Darwin" ]]; then
  videoCodec="h264_videotoolbox"
else
  videoCodec="h264_nvenc"
fi

currentFileIndex=0
totalFiles=0

progress() {
  printf '\033[1;92m%s\033[0m\n' "$1"
}

convertFile() {
  currentFileIndex=$((currentFileIndex + 1))

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

    progress "[${currentFileIndex}/${totalFiles}] Converting: ${fnameWithExt}"
    eval "ffmpeg -i $fileOrig -an -c:v $videoCodec -vf \"scale=min(1920\,iw):-2,scale=trunc(iw/4)*4:trunc(ih/4)*4, fps=30\" -b:v 12000k $fileTarget"
  else
    #-------------------#
    # ELSE JUST COPY IT #
    #-------------------#

    # escape special characters
    printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithExt"

    progress "[${currentFileIndex}/${totalFiles}] Copying: ${fnameWithExt}"
    eval "cp $fileOrig $fileTarget"
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
outputFolder="${inputFolder}_h264"
mkdir -p "$outputFolder"

# Process directories first to ensure structure
progress "Scanning folder structure..."
dirCount=0
while IFS= read -r dir; do
  targetDir="${outputFolder}${dir:${#inputFolder}}"
  mkdir -p "$targetDir"
  dirCount=$((dirCount + 1))
  printf '\033[2m  [%d] %s\033[0m\n' "$dirCount" "$dir"
done < <(find "$inputFolder" -type d)
progress "Folder structure ready (${dirCount} folder(s))."

# Collect files first so we know the total count for progress reporting
progress "Scanning for files..."
videoFiles=()
scanCount=0
while IFS= read -r -d '' file; do
  scanCount=$((scanCount + 1))
  videoFiles+=("$file")
  if (( scanCount % 25 == 0 )); then
    printf '\033[2m  ...scanned %d files so far\033[0m\n' "$scanCount"
  fi
done < <(find "$inputFolder" -type f -print0)

totalFiles=${#videoFiles[@]}
progress "Found ${totalFiles} file(s) to process."

for file in "${videoFiles[@]}"; do
  convertFile "$file"
done

# Build an overview image into the output folder, sourced from the
# original files, alongside the per-file H.264 output.
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$scriptDir/../overview/createOverview.sh" --folder "$inputFolder" --output "$outputFolder"
