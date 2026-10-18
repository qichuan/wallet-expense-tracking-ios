#!/usr/bin/env bash
# Turns a raw device recording into an App Store app preview:
# intro card → recording with caption banners → outro card, joined with dissolves.
#
#   scripts/app-store/make_preview.sh <raw.mp4> [out dir]
#
# Env:
#   START=1.0   seconds to skip at the start of the recording
#   LENGTH=22   seconds of recording to use (total stays within Apple's 15–30s)
#   MUSIC=path  optional licensed soundtrack; otherwise a silent stereo track is added
#
# Output matches App Store Connect's preview spec: 886×1920 portrait (accepted for
# every Face ID / Dynamic Island iPhone size), 30 fps, H.264 High@4.0 ~11 Mbps,
# AAC stereo 256 kbps 48 kHz.
set -euo pipefail
cd "$(dirname "$0")"

RAW="${1:?usage: make_preview.sh <raw.mp4> [out dir]}"
OUT="${2:-./output}"
START="${START:-1.0}"
CARDS="$OUT/preview-cards"
mkdir -p "$OUT"

swift StoreArt.swift preview-cards "$CARDS" > /dev/null

# bc prints ".3"; ffmpeg wants "0.300".
calc() { printf "%.3f" "$(echo "$1" | bc -l)"; }

RAW_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW")
AVAILABLE=$(calc "$RAW_DURATION - $START")
LENGTH="${LENGTH:-$(calc "if ($AVAILABLE < 22) $AVAILABLE else 22")}"

INTRO=2.5 OUTRO=2.5 FADE=0.4
TOTAL=$(calc "$INTRO + $LENGTH + $OUTRO - 2 * $FADE")
if (( $(echo "$TOTAL < 15 || $TOTAL > 30" | bc -l) )); then
  echo "Preview would be ${TOTAL}s; Apple requires 15–30s. Adjust LENGTH (recording has ${AVAILABLE}s)." >&2
  exit 1
fi

# Each caption covers a quarter of the recording, fading in and out.
SEG=$(calc "$LENGTH / 4")
CAPTION_INPUTS=() CAPTION_FILTERS="" CHAIN="[rec]"
for i in 1 2 3 4; do
  IN=$(calc "($i - 1) * $SEG + 0.3")
  OUTT=$(calc "$i * $SEG - 0.55")
  CAPTION_INPUTS+=(-loop 1 -t "$LENGTH" -i "$CARDS/caption-$i.png")
  idx=$((i + 2))
  CAPTION_FILTERS+="[$idx:v]format=rgba,fps=30,fade=in:st=$IN:d=0.25:alpha=1,fade=out:st=$OUTT:d=0.25:alpha=1[c$i];"
  CAPTION_FILTERS+="${CHAIN}[c$i]overlay=0:0:shortest=1[r$i];"
  CHAIN="[r$i]"
done

if [[ -n "${MUSIC:-}" ]]; then
  AUDIO=(-i "$MUSIC")
  AUDIO_FILTER="[7:a]atrim=0:$TOTAL,afade=t=out:st=$(calc "$TOTAL - 1.5"):d=1.5,aresample=48000,aformat=channel_layouts=stereo[aout]"
else
  AUDIO=(-f lavfi -t "$TOTAL" -i "anullsrc=channel_layout=stereo:sample_rate=48000")
  AUDIO_FILTER="[7:a]anull[aout]"
fi

V="fps=30,scale=886:1920:flags=lanczos,setsar=1,format=yuv420p"
ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -t "$INTRO" -i "$CARDS/intro.png" \
  -ss "$START" -t "$LENGTH" -i "$RAW" \
  -loop 1 -t "$OUTRO" -i "$CARDS/outro.png" \
  "${CAPTION_INPUTS[@]}" \
  "${AUDIO[@]}" \
  -filter_complex "
    [0:v]$V[intro];
    [2:v]$V[outro];
    [1:v]setpts=PTS-STARTPTS,$V[rec];
    $CAPTION_FILTERS
    [intro]$CHAIN xfade=transition=fade:duration=$FADE:offset=$(calc "$INTRO - $FADE")[a];
    [a][outro]xfade=transition=fade:duration=$FADE:offset=$(calc "$INTRO + $LENGTH - 2 * $FADE"),format=yuv420p[vout];
    $AUDIO_FILTER" \
  -map "[vout]" -map "[aout]" -t "$TOTAL" \
  -c:v libx264 -profile:v high -level:v 4.0 -pix_fmt yuv420p \
  -b:v 11M -maxrate 12M -bufsize 24M -r 30 \
  -c:a aac -b:a 256k -ar 48000 -ac 2 \
  -movflags +faststart \
  "$OUT/app-preview.mp4"

echo "Wrote $OUT/app-preview.mp4 (${TOTAL}s)"
