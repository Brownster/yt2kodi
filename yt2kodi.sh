#!/bin/bash

# Configuration
PLAYLISTS=(
    "https://www.youtube.com/playlist?list=PLZ9QOgK214HDtQ7UrifLha1upraLC6yrD"
    "https://www.youtube.com/playlist?list=PLZ9QOgK214HCbn2C7sgL2R4MFp3v644ex"
)
OUTPUT_DIR="$HOME/KodiLibrary/DazGames"
ARCHIVE_FILE="$OUTPUT_DIR/archive.txt"
TEMP_DIR="$OUTPUT_DIR/temp"

# Create necessary directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# Generate tvshow.nfo (if not already exists)
if [ ! -f "$OUTPUT_DIR/tvshow.nfo" ]; then
    cat > "$OUTPUT_DIR/tvshow.nfo" <<EOL
<tvshow>
    <title>Daz Games</title>
    <plot>All videos from the Daz Games YouTube channel, organized as a series.</plot>
    <genre>Gaming</genre>
    <studio>YouTube</studio>
    <thumb>https://yt3.ggpht.com/ytc/AAUvwngTZoztGc8Ir6YvX4DRyAxZsdCuIkm4opRy8nDI=s900-c-k-c0x00ffffff-no-rj</thumb>
</tvshow>
EOL
fi

# Download videos from playlists
for PLAYLIST in "${PLAYLISTS[@]}"; do
    yt-dlp --download-archive "$ARCHIVE_FILE" \
           -o "$TEMP_DIR/%(playlist_index)s - %(title)s [%(id)s].%(ext)s" \
           "$PLAYLIST"
done

# Process each downloaded video
for VIDEO_FILE in "$TEMP_DIR"/*.mp4; do
    BASENAME=$(basename "$VIDEO_FILE" .mp4 | sed 's/\.[f0-9]*$//')
    AUDIO_FILE="$TEMP_DIR/$BASENAME.f251.webm"
    MERGED_FILE="$TEMP_DIR/${BASENAME}.merged.mp4"

    # Combine video and audio
    if [ -f "$AUDIO_FILE" ]; then
        ffmpeg -i "$VIDEO_FILE" -i "$AUDIO_FILE" -c:v copy -c:a aac "$MERGED_FILE" -y
    else
        echo "No matching audio file for $VIDEO_FILE. Skipping..."
        continue
    fi

    # Rename the merged file
    EPISODE_NUMBER=$(echo "$BASENAME" | grep -oP '\d+')
    FINAL_FILE="$OUTPUT_DIR/E$(printf "%02d" "$EPISODE_NUMBER").mp4"
    mv "$MERGED_FILE" "$FINAL_FILE"

    # Fetch thumbnail
    VIDEO_ID=$(echo "$BASENAME" | grep -oP '\[.*\]' | tr -d '[]')
    THUMB_URL="https://img.youtube.com/vi/$VIDEO_ID/maxresdefault.jpg"
    THUMB_FILE="$OUTPUT_DIR/E$(printf "%02d" "$EPISODE_NUMBER").jpg"
    curl -s -o "$THUMB_FILE" "$THUMB_URL"

    # Fallback to hqdefault if maxresdefault doesn't exist
    if [ ! -s "$THUMB_FILE" ]; then
        THUMB_URL="https://img.youtube.com/vi/$VIDEO_ID/hqdefault.jpg"
        curl -s -o "$THUMB_FILE" "$THUMB_URL"
    fi

    # Fallback to extracting thumbnail from video
    if [ ! -s "$THUMB_FILE" ]; then
        ffmpeg -i "$FINAL_FILE" -vf "thumbnail" -frames:v 1 "$THUMB_FILE" -y
    fi

    # Create episode metadata (.nfo)
    EPISODE_NFO="$OUTPUT_DIR/E$(printf "%02d" "$EPISODE_NUMBER").nfo"
    cat > "$EPISODE_NFO" <<EOL
<episodedetails>
    <title>$(echo "$BASENAME" | sed 's/[0-9]* - //')</title>
    <season>1</season>
    <episode>$EPISODE_NUMBER</episode>
    <plot>Episode from Daz Games channel.</plot>
    <aired>$(date '+%Y-%m-%d')</aired>
    <runtime>10</runtime>
    <thumb>$THUMB_FILE</thumb>
</episodedetails>
EOL
done

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo "Download, metadata generation, and organization completed. Check your Kodi library at $OUTPUT_DIR."
