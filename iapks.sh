#!/data/data/com.termux/files/usr/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting APK download and install process...${NC}"

# Base URL
BASE_URL="http://209.38.69.201:88/apks"

# Create download directory
DOWNLOAD_DIR="downloaded_apks"
mkdir -p "$DOWNLOAD_DIR"

# Check if we have internet connectivity
echo -e "${YELLOW}Checking internet connection...${NC}"
if ! ping -c 1 google.com &> /dev/null; then
    echo -e "${RED}No internet connection!${NC}"
    exit 1
fi

# Download APKs from 1.apk to 4.apk
echo -e "${YELLOW}Downloading APK files...${NC}"
for i in {1..4}
do
    FILENAME="$i.apk"
    URL="$BASE_URL/$FILENAME"
    
    echo -e "${YELLOW}Downloading $FILENAME...${NC}"
    
    if wget -q --show-progress -O "$DOWNLOAD_DIR/$FILENAME" "$URL"; then
        echo -e "${GREEN}✓ Downloaded: $FILENAME${NC}"
    else
        echo -e "${RED}✗ Failed to download: $FILENAME${NC}"
        FAILED=true
    fi
done

# Check if any downloads failed
if [ "$FAILED" = true ]; then
    echo -e "${RED}Some downloads failed. Continuing with successful ones...${NC}"
fi

# Install APKs
echo -e "${YELLOW}Installing APK files...${NC}"
for i in {1..4}
do
    FILE="$DOWNLOAD_DIR/$i.apk"
    
    if [ -f "$FILE" ]; then
        echo -e "${YELLOW}Installing $i.apk...${NC}"
        
        # Check if APK is valid
        if file "$FILE" | grep -q "Zip archive data"; then
            # Install the APK
            if termux-open "$FILE" 2>/dev/null || am start -a android.intent.action.VIEW -t application/vnd.android.package-archive -d "file://$(realpath $FILE)" 2>/dev/null; then
                echo -e "${GREEN}✓ Installation started for: $i.apk${NC}"
                # Small delay between installations
                sleep 2
            else
                echo -e "${RED}✗ Failed to start installation for: $i.apk${NC}"
                echo -e "${YELLOW}Trying alternative method...${NC}"
                # Alternative installation method
                if pm install "$FILE" 2>/dev/null; then
                    echo -e "${GREEN}✓ Installed via pm: $i.apk${NC}"
                else
                    echo -e "${RED}✗ Could not install: $i.apk${NC}"
                    echo -e "${YELLOW}You may need to install it manually${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ Invalid APK file: $i.apk${NC}"
        fi
    else
        echo -e "${RED}✗ File not found: $i.apk${NC}"
    fi
done

echo -e "${GREEN}Process completed!${NC}"
echo -e "${YELLOW}Downloaded APKs are in: $(realpath $DOWNLOAD_DIR)${NC}"
echo -e "${YELLOW}If any installations didn't start automatically, you can install them manually from the download folder.${NC}"
