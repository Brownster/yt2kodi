#!/bin/bash

# Configuration
PLAYLISTS=(
    "https://www.youtube.com/playlist?list=PLZ9QOgK214HDtQ7UrifLha1upraLC6yrD"
    "https://www.youtube.com/playlist?list=PLZ9QOgK214HCbn2C7sgL2R4MFp3v644ex"
)
OUTPUT_BASE_DIR="$HOME/KodiLibrary"
TEMP_DIR="$OUTPUT_BASE_DIR/temp"

# Function to fetch channel metadata
fetch_channel_metadata() {
    local CHANNEL_URL="$1"
    CHANNEL_INFO=$(yt-dlp --get-description --get-title "$CHANNEL_URL" | sed 's/\r$//')
    CHANNEL_NAME=$(echo "$CHANNEL_INFO" | head -n 1)
    CHANNEL_DESCRIPTION=$(echo "$CHANNEL_INFO" | tail -n +2 | tr '\n' ' ')

    echo "$CHANNEL_NAME|$CHANNEL_DESCRIPTION"
}

# Function to create tvshow.nfo dynamically
generate_tvshow_nfo() {
    local CHANNEL_NAME="$1"
    local CHANNEL_DESCRIPTION="$2"
    local CHANNEL_THUMB="$3"
    local OUTPUT_DIR="$4"

    # Save tvshow.nfo
    cat > "$OUTPUT_DIR/tvshow.nfo" <<EOL
<tvshow>
    <title>$CHANNEL_NAME</title>
    <plot>$CHANNEL_DESCRIPTION</plot>
    <genre>Entertainment</genre>
    <studio>YouTube</studio>
    <thumb>$CHANNEL_THUMB</thumb>
</tvshow>
EOL
}

# Process each playlist
for PLAYLIST_URL in "${PLAYLISTS[@]}"; do
    # Extract channel URL from playlist
    CHANNEL_URL=$(yt-dlp --get-channel-url "$PLAYLIST_URL")
    CHANNEL_METADATA=$(fetch_channel_metadata "$CHANNEL_URL")
    CHANNEL_NAME=$(echo "$CHANNEL_METADATA" | cut -d'|' -f1)
    CHANNEL_DESCRIPTION=$(echo "$CHANNEL_METADATA" | cut -d'|' -f2)

    # Define directories
    OUTPUT_DIR="$OUTPUT_BASE_DIR/$CHANNEL_NAME"
    ARCHIVE_FILE="$OUTPUT_DIR/archive.txt"
    CHANNEL_THUMB="$OUTPUT_DIR/channel.jpg"

    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$TEMP_DIR"

    # Fetch channel thumbnail
    yt-dlp --skip-download --write-thumbnail --convert-thumbnails jpg -o "$TEMP_DIR/%(channel)s" "$CHANNEL_URL"
    mv "$TEMP_DIR/$CHANNEL_NAME.jpg" "$CHANNEL_THUMB"

    # Generate tvshow.nfo
    if [ ! -f "$OUTPUT_DIR/tvshow.nfo" ]; then
        generate_tvshow_nfo "$CHANNEL_NAME" "$CHANNEL_DESCRIPTION" "$CHANNEL_THUMB" "$OUTPUT_DIR"
    fi

    # Download videos from playlist
    yt-dlp --download-archive "$ARCHIVE_FILE" \
           -o "$TEMP_DIR/%(playlist_index)s - %(title)s [%(id)s].%(ext)s" \
           "$PLAYLIST_URL"

    # Process downloaded videos
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

        # Rename merged file to E<episode_number>.mp4
        EPISODE_NUMBER=$(echo "$BASENAME" | grep -oP '\d+')
        FINAL_FILE="$OUTPUT_DIR/E$(printf "%02d" "$EPISODE_NUMBER").mp4"
        mv "$MERGED_FILE" "$FINAL_FILE"

        # Fetch thumbnail
        VIDEO_ID=$(echo "$BASENAME" | grep -oP '\[.*\]' | tr -d '[]')
        THUMB_FILE="$OUTPUT_DIR/E$(printf "%02d" "$EPISODE_NUMBER").jpg"
        THUMB_URL="https://img.youtube.com/vi/$VIDEO_ID/maxresdefault.jpg"
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
    <plot>Video from $CHANNEL_NAME.</plot>
    <aired>$(date '+%Y-%m-%d')</aired>
    <runtime>10</runtime>
    <thumb>$THUMB_FILE</thumb>
</episodedetails>
EOL
    done
done

# Clean up temporary directory
rm -rf "$TEMP_DIR"

echo "Download, metadata generation, and organization completed."
