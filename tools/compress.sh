#!/bin/bash
mkdir -p output
find . -maxdepth 1 -name '*.mp4' -type f | while read f; do
    if [ ! -e  "output/${f%.*}.mp4" ]; then
        #ffmpeg -nostdin -i "$f" -vcodec libx264 -acodec aac -af "volume=20dB" -vf "scale=trunc(iw/6)*2:trunc(ih/6)*2" "output/${f%.*}.mp4"
        ffmpeg -nostdin -i "$f" -vcodec libx264 -acodec aac -vf "scale=trunc(iw/4)*2:trunc(ih/4)*2" "output/${f%.*}.mp4"
    fi
done
