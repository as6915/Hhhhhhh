#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

TARGET_DIR="/var/www/ctrlpanel"
TEMP_REPO="/tmp/ak-nobita-bot"
ZIP_NAME="copy-from-me.zip"
REPO_URL="https://github.com/as6915/nobita-bot.git"

print_header "Welcome to Phoenix Theme Installer"
echo -e "${CYAN}This installer is created and maintained by Alakreb (Developer).${NC}"
sleep 2

print_status "Cleaning temporary files"
rm -rf "$TEMP_REPO"
mkdir -p "$TEMP_REPO"
print_success "Temporary directory ready"

print_status "Cloning repository from GitHub"
git clone "$REPO_URL" "$TEMP_REPO" > /dev/null 2>&1 &
pid=$!
animate_progress $pid "Cloning repository"
wait $pid
check=$?
if [ $check -eq 0 ]; then print_success "Repository cloned"; else print_error "Clone failed"; exit 1; fi

ZIP_FILE="$TEMP_REPO/src/$ZIP_NAME"
if [ -f "$ZIP_FILE" ]; then
    print_success "$ZIP_NAME found at $ZIP_FILE"
else
    print_error "$ZIP_NAME not found inside $TEMP_REPO/src!"
    ls -l "$TEMP_REPO/src/"
    rm -rf "$TEMP_REPO"
    exit 1
fi

print_status "Moving $ZIP_NAME to $TARGET_DIR"
mkdir -p "$TARGET_DIR"
mv "$ZIP_FILE" "$TARGET_DIR/" > /dev/null 2>&1 &
pid=$!
animate_progress $pid "Moving ZIP"
wait $pid
check=$?
if [ $check -eq 0 ]; then print_success "ZIP moved"; else print_error "Move failed"; exit 1; fi

cd "$TARGET_DIR" || exit 1
print_status "Extracting $ZIP_NAME"
unzip -o "$ZIP_NAME" > /dev/null 2>&1 &
pid=$!
animate_progress $pid "Extracting ZIP"
wait $pid
check=$?
if [ $check -eq 0 ]; then print_success "ZIP extracted"; else print_error "Extraction failed"; exit 1; fi

print_status "Setting ownership to www-data and permissions 755"
chown -R www-data:www-data "$TARGET_DIR"
chmod -R 755 "$TARGET_DIR"
print_success "Ownership and permissions set"

rm -rf "$TEMP_REPO"

print_header "RUNNING LARAVEL COMMANDS"
cd "$TARGET_DIR" || exit 1

print_status "Running php artisan migrate"
php artisan migrate > /dev/null 2>&1 &
pid=$!
animate_progress $pid "Migrating database"
wait $pid
check=$?
if [ $check -eq 0 ]; then print_success "Migration completed"; else print_error "Migration failed"; exit 1; fi

print_status "Running php artisan optimize:clear"
php artisan optimize:clear > /dev/null 2>&1 &
pid=$!
animate_progress $pid "Optimizing"
wait $pid
check=$?
if [ $check -eq 0 ]; then print_success "Optimize cleared"; else print_error "Optimize failed"; exit 1; fi

print_header "INSTALLATION COMPLETE"
echo -e "${GREEN}🎉 Theme Phoenix installed successfully!${NC}"
echo -e "${CYAN}All rights reserved to Alakreb (Developer).${NC}"
read -p "$(echo -e "${YELLOW}Press Enter to exit...${NC}")" -n 1
