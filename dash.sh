#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() { echo -e "${YELLOW}⏳ $1...${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

animate_progress() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    
    print_status "$message"
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Check root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

TARGET_DIR="/var/www/ctrlpanel"
TEMP_REPO="/tmp/ak-nobita-bot"
ZIP_NAME="copy-from-me.zip"
REPO_URL="https://github.com/nobita586/ak-nobita-bot.git"

print_header "STARTING THEME INSTALLATION"

# Clean temp
print_status "Cleaning temporary files"
rm -rf "$TEMP_REPO"
mkdir -p "$TEMP_REPO"
print_success "Temporary directory ready"

# Clone repository
print_status "Cloning repository from GitHub"
git clone "$REPO_URL" "$TEMP_REPO" > /dev/null 2>&1 &
animate_progress $! "Cloning repository"
check=$?
if [ $check -eq 0 ]; then print_success "Repository cloned"; else print_error "Clone failed"; exit 1; fi

# Check ZIP
ZIP_FILE="$TEMP_REPO/src/$ZIP_NAME"
if [ -f "$ZIP_FILE" ]; then
    print_success "$ZIP_NAME found"
else
    print_error "$ZIP_NAME not found!"
    rm -rf "$TEMP_REPO"
    exit 1
fi

# Move ZIP
print_status "Moving $ZIP_NAME to $TARGET_DIR"
mv "$ZIP_FILE" "$TARGET_DIR/" > /dev/null 2>&1 &
animate_progress $! "Moving ZIP"
check=$?
if [ $check -eq 0 ]; then print_success "ZIP moved"; else print_error "Move failed"; exit 1; fi

# Extract ZIP
cd "$TARGET_DIR" || exit 1
print_status "Extracting $ZIP_NAME"
unzip -o "$ZIP_NAME" > /dev/null 2>&1 &
animate_progress $! "Extracting ZIP"
check=$?
if [ $check -eq 0 ]; then print_success "ZIP extracted"; else print_error "Extraction failed"; exit 1; fi

# Set ownership and permissions
print_status "Setting ownership to www-data and permissions 755"
chown -R www-data:www-data "$TARGET_DIR"
chmod -R 755 "$TARGET_DIR"
print_success "Ownership and permissions set"

# Clean temp repo
rm -rf "$TEMP_REPO"

# Run Laravel commands
print_header "RUNNING LARAVEL COMMANDS"
cd "$TARGET_DIR" || exit 1

print_status "Running php artisan migrate"
php artisan migrate > /dev/null 2>&1 &
animate_progress $! "Migrating database"
check=$?
if [ $check -eq 0 ]; then print_success "Migration completed"; else print_error "Migration failed"; exit 1; fi

print_status "Running php artisan optimize:clear"
php artisan optimize:clear > /dev/null 2>&1 &
animate_progress $! "Optimizing"
check=$?
if [ $check -eq 0 ]; then print_success "Optimize cleared"; else print_error "Optimize failed"; exit 1; fi

print_header "INSTALLATION COMPLETE"
echo -e "${GREEN}🎉 Theme installed and Laravel commands executed successfully!${NC}"
read -p "$(echo -e "${YELLOW}Press Enter to exit...${NC}")" -n 1
