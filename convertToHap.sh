#!/bin/bash

# Convert files with ffmpeg in user specified folder
#   Creates a "converted" folder in the specified folder with the converted files

# Forces a maximum video width of 1920
# Forces a frame rate of 30

# Requirements
#   ffmpeg needs to be present in PathVar
#   Current location: /usr/local/bin/ffmpeg

# Usage
#   chmod +x ./ffmpegConvert.sh
#   ./ffmpegConvert.sh
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

    finalCommand="$finalCommand ffmpeg -i $fileOrig -an -c:v hap -vf \"scale=min(1920\,iw):-2,scale=trunc(iw/4)*4:trunc(ih/4)*4\" -filter:v fps=30 -b:v 12M $fileTarget; "

    #----------------#
    # MAKE THUMBNAIL #
    #----------------#
#    mkdir -p "$fileTargetFolder/__thumbs"
#    printf -v fileTargetThumbnail "%q" "$fileTargetFolder/__thumbs/$fnameWithoutExt.jpg"
#
#    durationFull=$(ffmpeg -i $fileTarget 2>&1 | grep Duration | awk '{print $2}' | tr -d ,)
#    durationHalf=$(echo $durationFull | awk -F ':' '{print ($3+$2*60+$1*3600)/2}' | awk -F ',' '{print ($1)}')
#    finalCommand="$finalCommand ffmpeg -ss $durationHalf -i $fileTarget -vframes 1 $fileTargetThumbnail; "
  else
    #-------------------#
    # ELSE JUST COPY IT #
    #-------------------#

    # escape special characters
    printf -v fileTarget "%q" "$fileTargetFolder/$fnameWithExt"

    finalCommand="$finalCommand cp $fileOrig $fileTarget; "
  fi
}

# catch trailing slash from userinput
read -p "Pfad zum zu konvertierenden Ordner: [/Users/david/Desktop/vj_test/ToConvert]
" inputFolder
if [ ! "$inputFolder" ]; then
  inputFolder="/Users/david/Desktop/vj_test/ToConvert"
fi
if [ "${inputFolder: -1}" = "/" ]; then
  inputFolder="${inputFolder%?}"
fi

# create "converted" folder
outputFolder="${inputFolder}_hap"
mkdir -p "${outputFolder}"

# go through files in user specified folder and convert them
for entry1 in "$inputFolder"/*; do
  if [ -f "$entry1" ]; then
    addToFinalCommand "$entry1"
  else
    echo "folder $entry1"

    tmpFolder="${entry1}"
    tmpFolder=${tmpFolder/$inputFolder/$outputFolder}

    mkdir -p "${tmpFolder}"

    for entry2 in "$entry1"/*; do
      if [ -f "$entry2" ]; then
        addToFinalCommand "$entry2"
      else
        echo "folder $entry2"

        tmpFolder="${entry2}"
        tmpFolder=${tmpFolder/$inputFolder/$outputFolder}

        mkdir -p "${tmpFolder}"

        for entry3 in "$entry2"/*; do
          if [ -f "$entry3" ]; then
            addToFinalCommand "$entry3"
          else
            echo "folder $entry3"

            tmpFolder="${entry3}"
            tmpFolder=${tmpFolder/$inputFolder/$outputFolder}

            mkdir -p "${tmpFolder}"

            for entry4 in "$entry3"/*; do
              if [ -f "$entry4" ]; then
                addToFinalCommand "$entry4"
              else
                echo "folder $entry4"
              fi
            done

          fi
        done
      fi
    done
  fi
done

#echo $finalCommand
eval $finalCommand
