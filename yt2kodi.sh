#!/bin/bash

# Configuration
CHANNEL_URL="https://www.youtube.com/@dazgames/videos"
OUTPUT_DIR="$HOME/KodiLibrary/DazGames"
ARCHIVE_FILE="$OUTPUT_DIR/archive.txt"
TEMP_DIR="$OUTPUT_DIR/temp"

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# Generate tvshow.nfo
cat > "$OUTPUT_DIR/tvshow.nfo" <<EOL
<tvshow>
    <title>Daz Games</title>
    <plot>All videos from the Daz Games YouTube channel, organized as a series.</plot>
    <genre>Gaming</genre>
    <studio>YouTube</studio>
    <thumb>https://yt3.ggpht.com/ytc/AAUvwngTZoztGc8Ir6YvX4DRyAxZsdCuIkm4opRy8nDI=s900-c-k-c0x00ffffff-no-rj</thumb>
</tvshow>
EOL

# Download videos
yt-dlp --download-archive "$ARCHIVE_FILE" \
       -o "$TEMP_DIR/%(upload_date)s - %(title)s [%(id)s].%(ext)s" \
       --merge-output-format mp4 \
       --postprocessor-args "-c:v libx265 -crf 28 -preset medium" \
       "$CHANNEL_URL"

# Process each downloaded video
for FILE in "$TEMP_DIR"/*.mp4; do
    if [ -f "$FILE" ]; then
        BASENAME=$(basename "$FILE" .mp4)
        UPLOAD_DATE=$(echo "$BASENAME" | cut -d' ' -f1)
        TITLE=$(echo "$BASENAME" | cut -d' ' -f3- | sed 's/\[.*\]//')
        VIDEO_ID=$(echo "$BASENAME" | grep -oP '\[\K[^\]]+(?=\])')
        YEAR=${UPLOAD_DATE:0:4}

        # Create season directory
        SEASON_DIR="$OUTPUT_DIR/Season $YEAR"
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
    <season>$YEAR</season>
    <episode>$(ls "$SEASON_DIR"/*.nfo | wc -l)</episode>
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

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo "Download, metadata generation, and organization by season completed. Check your Kodi library at $OUTPUT_DIR."
