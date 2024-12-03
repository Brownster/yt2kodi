#!/bin/bash

# Configuration
CHANNEL_URL="https://www.youtube.com/@dazgames/videos"
OUTPUT_DIR="$HOME/KodiLibrary/DazGames"
ARCHIVE_FILE="$OUTPUT_DIR/archive.txt"
STATE_FILE="$OUTPUT_DIR/library_state.json"
TEMP_DIR="$OUTPUT_DIR/temp"

# Create necessary directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# Initialize state file if not exists
if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" <<EOL
{
    "last_season": 1,
    "last_episode": 0
}
EOL
fi

# Load state
LAST_SEASON=$(jq '.last_season' "$STATE_FILE")
LAST_EPISODE=$(jq '.last_episode' "$STATE_FILE")

# Download only new videos
yt-dlp --download-archive "$ARCHIVE_FILE" \
       -o "$TEMP_DIR/%(upload_date)s - %(title)s [%(id)s].%(ext)s" \
       --merge-output-format mp4 \
       "$CHANNEL_URL"

# Process each downloaded video
for FILE in "$TEMP_DIR"/*.mp4; do
    if [ -f "$FILE" ]; then
        BASENAME=$(basename "$FILE" .mp4)
        UPLOAD_DATE=$(echo "$BASENAME" | cut -d' ' -f1)
        TITLE=$(echo "$BASENAME" | cut -d' ' -f3- | sed 's/\[.*\]//')
        VIDEO_ID=$(echo "$BASENAME" | grep -oP '\[\K[^\]]+(?=\])')
        YEAR=${UPLOAD_DATE:0:4}

        # Increment episode number
        LAST_EPISODE=$((LAST_EPISODE + 1))

        # Handle season rollover (optional)
        # Uncomment if you want a new season each year
        # if [ "$YEAR" -ne "$LAST_SEASON_YEAR" ]; then
        #     LAST_SEASON=$((LAST_SEASON + 1))
        #     LAST_EPISODE=1
        # fi

        # Create season directory
        SEASON_DIR="$OUTPUT_DIR/Season $LAST_SEASON"
        mkdir -p "$SEASON_DIR"

        # Fetch thumbnail
        THUMB_URL="https://img.youtube.com/vi/$VIDEO_ID/maxresdefault.jpg"
        THUMB_FILE="$SEASON_DIR/$BASENAME.jpg"
        curl -s -o "$THUMB_FILE" "$THUMB_URL"

        # Fallback to hqdefault if maxresdefault doesn't exist
        if [ ! -s "$THUMB_FILE" ]; then
            THUMB_URL="https://img.youtube.com/vi/$VIDEO_ID/hqdefault.jpg"
            curl -s -o "$THUMB_FILE" "$THUMB_URL"
        fi

        # Fallback to extracting thumbnail from video
        if [ ! -s "$THUMB_FILE" ]; then
            ffmpeg -i "$FILE" -vf "thumbnail" -frames:v 1 "$THUMB_FILE" -y
        fi

        # Create episode metadata (.nfo)
        EPISODE_NFO="$SEASON_DIR/$BASENAME.nfo"
        cat > "$EPISODE_NFO" <<EOL
<episodedetails>
    <title>$TITLE</title>
    <season>$LAST_SEASON</season>
    <episode>$LAST_EPISODE</episode>
    <plot>Episode from Daz Games channel uploaded on $UPLOAD_DATE.</plot>
    <aired>${UPLOAD_DATE:0:4}-${UPLOAD_DATE:4:2}-${UPLOAD_DATE:6:2}</aired>
    <runtime>10</runtime>
    <thumb>$THUMB_FILE</thumb>
</episodedetails>
EOL

        # Move video to season directory
        mv "$FILE" "$SEASON_DIR/$BASENAME.mp4"
    fi
done

# Save updated state
jq --argjson last_season "$LAST_SEASON" \
   --argjson last_episode "$LAST_EPISODE" \
   '.last_season = $last_season | .last_episode = $last_episode' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo "Update completed. New episodes added to Kodi library at $OUTPUT_DIR."
Group videos by upload year to create multiple seasons.
