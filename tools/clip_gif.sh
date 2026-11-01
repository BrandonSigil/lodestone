#!/usr/bin/env bash
# Turns a Godot movie-writer clip (.avi) into a small looping GIF for a Studio card ([USER] 2026-11-01: little videos of
# feel features). Usage: tools/clip_gif.sh <in.avi> <out.gif> [skip seconds] [width] [fps]
# Record the clip first, through tools/godot.sh, e.g.:
#   tools/godot.sh --path game --write-movie /tmp/fish.avi --fixed-fps 30 -s res://tools/feel_clip.gd -- fishing
set -euo pipefail
in="$1"; out="$2"; skip="${3:-0}"; width="${4:-640}"; fps="${5:-15}"
ffmpeg -loglevel error -y -ss "$skip" -i "$in" \
	-vf "fps=$fps,scale=$width:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
	-loop 0 "$out"
echo "$out: $(du -h "$out" | cut -f1)"
