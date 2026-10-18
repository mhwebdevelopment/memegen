# Marketing meme generator in progress

Needs format adjustments, csv input handling, & enabling cli caption input - but works with .gif or .mp4 files
- [] Adjust caption formatting and wrap
- [] Update for gifs shorter than set output time to loop rather than stop (as you can see in the output examples)
- [] Agent based hook generation (scheduled or workflow based)
- [] Simple cron job scheduling for runs
- [] Semantic meme folder usage for matching caption emotion to meme emotion


Ideal workflow is to, in an automated manner:
- find an emotion / action anchored meme clip
- generate scripts based on the specific action or emotion + niche context / pain points / specific offers etc

## Fixed bugs from v1
1. `sed` colon-escaping was silently stripped by double-quoted shell expansion — rewrote
   the escaper using pure bash parameter substitution (`${s//:/\\:}`).
2. `fold` with no trailing newline caused `while read` to silently drop the last
   wrapped line of every hook — fixed by piping `printf '%s\n'` into fold.
3. Long hooks (5-6 wrapped lines) overflowed the white header card — added dynamic
   font-size scaling: shrinks progressively as line count grows so text always
   stays inside the card.

## Usage

```bash
chmod +x meme_gen.sh

# Text-only card (black lower field, add your own clip later in CapCut)
./meme_gen.sh

# With a background clip filling the lower 70%
./meme_gen.sh path/to/clip.mp4


# With clip + custom looped audio
./meme_gen.sh path/to/clip.mp4 path/to/audio.mp3
```

Output: `./out/meme_001.mp4` ... `meme_010.mp4`

## Editing the hooks

Open the script, find the `HOOKS` array. Format is pipe-separated lines:

```bash
"Line 1|Line 2|Line 3|Line 4"
```

Each `|` segment auto-wraps if too long, and font size auto-shrinks if the
hook produces more than 3 wrapped lines — so you never have to manually
tune sizing per script.

## Format reference (in need of some TLC)
- White card = top 30% of frame
- Bold black text, centered
- Black lower 70% reserved for clip/reaction footage
- 8 seconds default duration — override by editing `DURATION` in the script
