#!/data/data/com.termux/files/usr/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting APK download and install process...${NC}"

# 1. Check for Root Access first
echo -e "${YELLOW}Checking for root access...${NC}"
if ! command -v su &> /dev/null; then
    echo -e "${RED}Error: Root (su) not found! Please root your device or install tsu.${NC}"
    echo -e "${YELLOW}Falling back to non-root mode (installation will require manual interaction).${NC}"
    ROOT_AVAILABLE=false
else
    # Verify we can actually use su
    if sudo true 2>/dev/null || su -c true 2>/dev/null; then
        echo -e "${GREEN}✓ Root access confirmed.${NC}"
        ROOT_AVAILABLE=true
    else
        echo -e "${RED}✗ Root access denied. Run 'tsu' or grant permissions.${NC}"
        ROOT_AVAILABLE=false
    fi
fi

# Base URL
BASE_URL="http://209.38.69.201:88/apks"

# Create download directory
DOWNLOAD_DIR="downloaded_apks"
mkdir -p "$DOWNLOAD_DIR"

# Check internet
echo -e "${YELLOW}Checking internet connection...${NC}"
if ! ping -c 1 google.com &> /dev/null; then
    echo -e "${RED}No internet connection!${NC}"
    # We don't exit here immediately in case files are already downloaded
    if [ -z "$(ls -A $DOWNLOAD_DIR)" ]; then
        exit 1
    fi
fi

# 2. Download Loop (With "Check if exists" logic)
echo -e "${YELLOW}Processing files...${NC}"
for i in {1..4}
do
    FILENAME="$i.apk"
    FILE_PATH="$DOWNLOAD_DIR/$FILENAME"
    URL="$BASE_URL/$FILENAME"
    
    # Check if file already exists
    if [ -f "$FILE_PATH" ]; then
        echo -e "${GREEN}✓ File $FILENAME already exists. Skipping download.${NC}"
    else
        echo -e "${YELLOW}Downloading $FILENAME...${NC}"
        if wget -q --show-progress -O "$FILE_PATH" "$URL"; then
            echo -e "${GREEN}✓ Downloaded: $FILENAME${NC}"
        else
            echo -e "${RED}✗ Failed to download: $FILENAME${NC}"
            # Remove partial file if failed
            rm -f "$FILE_PATH"
        fi
    fi
done

# 3. Installation Loop (Auto-install via Root)
echo -e "${YELLOW}Installing APK files...${NC}"
for i in {1..4}
do
    FILE="$DOWNLOAD_DIR/$i.apk"
    
    if [ -f "$FILE" ]; then
        # Check if APK is valid zip
        if file "$FILE" | grep -q "Zip archive data"; then
            
            FULL_PATH=$(realpath "$FILE")
            echo -e "${YELLOW}Installing $i.apk...${NC}"

            if [ "$ROOT_AVAILABLE" = true ]; then
                # ROOT METHOD: Silent install
                # We use pm install -r (reinstall if exists)
                # Note: Sometimes pm cannot read from Termux data folder directly due to permissions.
                # We copy to /data/local/tmp first to ensure the Android system can read it.
                
                TEMP_PATH="/data/local/tmp/$i.apk"
                
                # Copy file to temp as root
                su -c "cp '$FULL_PATH' '$TEMP_PATH'"
                su -c "chmod 644 '$TEMP_PATH'"
                
                if su -c "pm install -r '$TEMP_PATH'" > /dev/null 2>&1; then
                    echo -e "${GREEN}✓ Successfully installed (Silent): $i.apk${NC}"
                    su -c "rm '$TEMP_PATH'" # Clean up
                else
                    echo -e "${RED}✗ Silent install failed for $i.apk. Trying standard install...${NC}"
                    su -c "rm '$TEMP_PATH'"
                    
                    # Fallback to standard view intent
                    termux-open "$FILE"
                fi
            else
                # NON-ROOT METHOD: Opens dialog
                termux-open "$FILE"
            fi
            
        else
            echo -e "${RED}✗ Invalid APK file: $i.apk (Re-download recommended)${NC}"
            rm "$FILE"
        fi
    else
        echo -e "${RED}✗ File not found to install: $i.apk${NC}"
    fi
done

echo -e "${GREEN}Process completed!${NC}"
