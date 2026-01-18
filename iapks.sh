#!/data/data/com.termux/files/usr/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==========================================
# 1. AUTO-INSTALL NEEDED PACKAGES
# ==========================================
echo -e "${CYAN}[1/4] Checking Termux environment...${NC}"

# Function to install a package if command is missing
ensure_package() {
    CMD_NAME=$1
    PKG_NAME=$2
    
    if ! command -v "$CMD_NAME" &> /dev/null; then
        echo -e "${YELLOW}Missing tool '$CMD_NAME'. Installing package '$PKG_NAME'...${NC}"
        pkg install "$PKG_NAME" -y > /dev/null 2>&1
        
        # Verify if it installed correctly
        if ! command -v "$CMD_NAME" &> /dev/null; then
            echo -e "${RED}Failed to install $PKG_NAME. Trying 'pkg update' first...${NC}"
            pkg update -y > /dev/null 2>&1
            pkg install "$PKG_NAME" -y
        else
            echo -e "${GREEN}✓ Installed $PKG_NAME${NC}"
        fi
    fi
}

# Check all required tools
ensure_package "wget" "wget"
ensure_package "file" "file"
ensure_package "ping" "net-utils"

# ==========================================
# 2. ROOT ACCESS CHECK
# ==========================================
echo -e "${CYAN}[2/4] Checking Root Access...${NC}"

if command -v su &> /dev/null; then
    # Test if we can actually use root
    if sudo true 2>/dev/null || su -c true 2>/dev/null; then
        echo -e "${GREEN}✓ Root access granted.${NC}"
        ROOT_AVAILABLE=true
    else
        echo -e "${RED}✗ Root exists but permission denied. Check your Magisk/SuperUser popup.${NC}"
        ROOT_AVAILABLE=false
    fi
else
    echo -e "${RED}✗ Root (su) not found.${NC}"
    ROOT_AVAILABLE=false
fi

# ==========================================
# 3. DOWNLOAD FILES
# ==========================================
echo -e "${CYAN}[3/4] Checking Files...${NC}"

BASE_URL="http://209.38.69.201:88/apks"
DOWNLOAD_DIR="downloaded_apks"
mkdir -p "$DOWNLOAD_DIR"

# Check internet only if we need to download something
INTERNET_CHECKED=false

for i in {1..4}
do
    FILENAME="$i.apk"
    FILE_PATH="$DOWNLOAD_DIR/$FILENAME"
    URL="$BASE_URL/$FILENAME"
    
    if [ -f "$FILE_PATH" ]; then
        echo -e "${GREEN}✓ Found $FILENAME (Skipping download)${NC}"
    else
        # Only check internet once
        if [ "$INTERNET_CHECKED" = false ]; then
            if ! ping -c 1 8.8.8.8 &> /dev/null; then
                echo -e "${RED}Error: No internet connection to download files.${NC}"
                exit 1
            fi
            INTERNET_CHECKED=true
        fi

        echo -e "${YELLOW}Downloading $FILENAME...${NC}"
        if wget -q --show-progress -O "$FILE_PATH" "$URL"; then
            echo -e "${GREEN}✓ Downloaded $FILENAME${NC}"
        else
            echo -e "${RED}✗ Download failed: $FILENAME${NC}"
            rm -f "$FILE_PATH"
        fi
    fi
done

# ==========================================
# 4. INSTALL APKs
# ==========================================
echo -e "${CYAN}[4/4] Installing APKs...${NC}"

for i in {1..4}
do
    FILE="$DOWNLOAD_DIR/$i.apk"
    
    if [ -f "$FILE" ]; then
        # Check validity using 'file' command
        if file "$FILE" | grep -q -E "Zip archive data|Android package"; then
            
            FULL_PATH=$(realpath "$FILE")
            
            if [ "$ROOT_AVAILABLE" = true ]; then
                echo -e "${YELLOW}Installing $i.apk (Silent)...${NC}"
                
                # Copy to temp folder so Package Manager can read it
                TEMP_PATH="/data/local/tmp/$i.apk"
                
                su -c "cp '$FULL_PATH' '$TEMP_PATH'"
                su -c "chmod 644 '$TEMP_PATH'"
                
                if su -c "pm install -r '$TEMP_PATH'" > /dev/null 2>&1; then
                    echo -e "${GREEN}✓ Installed: $i.apk${NC}"
                    su -c "rm '$TEMP_PATH'"
                else
                    echo -e "${RED}✗ Silent install failed. Trying manual...${NC}"
                    su -c "rm '$TEMP_PATH'"
                    termux-open "$FILE"
                fi
            else
                echo -e "${YELLOW}Root not available. Requesting manual install...${NC}"
                termux-open "$FILE"
            fi
        else
            echo -e "${RED}✗ File is corrupt: $i.apk (Deleting...)${NC}"
            rm "$FILE"
        fi
    else
        echo -e "${RED}✗ Missing file: $i.apk${NC}"
    fi
done

echo -e "${GREEN}All Done!${NC}"
