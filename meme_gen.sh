#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# ContentScaling TikTok-Style Meme Generator (v2 — fixed escaping)
# White header card (bold black text) + black lower field for clip overlay.
# "Ugly eye-catching old-meme" style — matches the high-performing posts.
#
# Usage:
#   ./meme_gen.sh                    → text-only cards, black lower field
#   ./meme_gen.sh clip.mp4            → clip fills lower 70%
#   ./meme_gen.sh clip.mp4 audio.mp3  → clip + looped audio track
# ─────────────────────────────────────────────────────────────
set -euo pipefail

CLIP="${1:-}"
AUDIO="${2:-}"
OUT="./out"
mkdir -p "$OUT"

pick_font() {
  local candidates=(
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
    "/Library/Fonts/Arial Bold.ttf"
    "C:/Windows/Fonts/arialbd.ttf"
  )
  for f in "${candidates[@]}"; do
    [[ -f "$f" ]] && { echo "$f"; return; }
  done
  echo ""
}
FONTFILE="$(pick_font)"
if [[ -z "$FONTFILE" ]]; then
  echo "No bold font found. Install: sudo apt install fonts-dejavu-core"
  exit 1
fi

declare -a HOOKS=(
  "POV:|you stopped paying|for AI tools|and ran it local"
  "Friend: AI posts sound robotic|Me: gave my AI my life story|it finds pain points and sells|with real experiences"
  "Me: I need a content strategy|Also me:|python -m deepresearch|ingest ~/vault"
  "POV: you found out how|to make 30 days of content|in one weekend|real stories not robotic AI"
  "Everyone hates on local AI|until they see the API bill|vs the electricity bill"
  "Your content calendar|My 6AM automation|running while I sleep"
  "Nobody:|Me explaining why my|research vault answers better|than ChatGPT"
  "POV: your Obsidian vault|just became a research engine|that cites its own sources"
  "Paying 300 dollars a month|for AI writing tools|vs 0.003 cents per article"
  "The AI doesnt know your work|until you give it|your own files"
)

W=1080; H=1920
HEADER_H=$(( H * 30 / 100 ))
FONT_SIZE=64
LINE_GAP=14
WRAP_CHARS=20
DURATION=8

# Escape text for ffmpeg drawtext: backslash, colon, single-quote
esc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//:/\\:}"
  s="${s//\'/\\\'}"
  printf '%s' "$s"
}

i=1
for hook in "${HOOKS[@]}"; do
  out_file="$OUT/meme_$(printf '%03d' "$i").mp4"

  IFS='|' read -r -a lines <<< "$hook"

  # Pre-wrap all lines first so we know total rendered line count
  declare -a WRAPPED=()
  for line in "${lines[@]}"; do
    while IFS= read -r sub; do
      [[ -z "$sub" ]] && continue
      WRAPPED+=("$sub")
    done < <(printf '%s\n' "$line" | fold -s -w "$WRAP_CHARS")
  done
  wcount=${#WRAPPED[@]}

  # Dynamic font size: shrink as line count grows so text always fits header
  if   (( wcount <= 3 )); then dyn_font=$FONT_SIZE
  elif (( wcount <= 4 )); then dyn_font=$(( FONT_SIZE * 85 / 100 ))
  elif (( wcount <= 5 )); then dyn_font=$(( FONT_SIZE * 72 / 100 ))
  else                          dyn_font=$(( FONT_SIZE * 60 / 100 ))
  fi
  dyn_gap=$(( LINE_GAP * dyn_font / FONT_SIZE ))

  total_h=$(( wcount * (dyn_font + dyn_gap) ))
  start_y=$(( (HEADER_H - total_h) / 2 ))
  y=$start_y

  declare -a DT_FILTERS=()
  for sub in "${WRAPPED[@]}"; do
    esc_sub=$(esc "$sub")
    DT_FILTERS+=("drawtext=fontfile='${FONTFILE}':text='${esc_sub}':fontsize=${dyn_font}:fontcolor=black:x=(w-text_w)/2:y=${y}")
    y=$(( y + dyn_font + dyn_gap ))
  done

  joined_text=$(IFS=,; echo "${DT_FILTERS[*]}")
  base_filter="drawbox=x=0:y=0:w=${W}:h=${HEADER_H}:color=white:t=fill,${joined_text}"

  if [[ -n "$CLIP" && -f "$CLIP" ]]; then
    lower_h=$(( H - HEADER_H ))
    filter_complex="[0:v]${base_filter}[base];[1:v]scale=${W}:${lower_h}:force_original_aspect_ratio=increase,crop=${W}:${lower_h}[clipv];[base][clipv]overlay=0:${HEADER_H}[outv]"

    if [[ -n "$AUDIO" && -f "$AUDIO" ]]; then
      ffmpeg -y -loglevel error \
        -f lavfi -i "color=c=black:s=${W}x${H}:d=${DURATION}" \
        -i "$CLIP" \
        -stream_loop -1 -i "$AUDIO" \
        -filter_complex "$filter_complex" \
        -map "[outv]" -map 2:a:0 \
        -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p \
        -c:a aac -b:a 128k -t "$DURATION" -shortest "$out_file"
    else
      ffmpeg -y -loglevel error \
        -f lavfi -i "color=c=black:s=${W}x${H}:d=${DURATION}" \
        -i "$CLIP" \
        -filter_complex "$filter_complex" \
        -map "[outv]" \
        -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p \
        -t "$DURATION" "$out_file"
    fi
  else
    ffmpeg -y -loglevel error \
      -f lavfi -i "color=c=black:s=${W}x${H}:d=${DURATION}" \
      -vf "$base_filter" \
      -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p \
      "$out_file"
  fi

  echo "✓ $out_file"
  unset DT_FILTERS WRAPPED
  i=$((i+1))
done

echo ""
echo "Done. ${#HOOKS[@]} Memes ready → $OUT/"
