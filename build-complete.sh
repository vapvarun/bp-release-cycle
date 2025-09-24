#!/bin/bash

# BuddyPress Complete Build Script with ZIP Generation
# This script creates a production-ready build and packages it as a versioned ZIP file

set -e  # Exit on any error

echo "========================================="
echo "BuddyPress Complete Build Process"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the plugin version from bp-loader.php
VERSION=$(grep "Version:" src/bp-loader.php | sed 's/.*Version:[ ]*//' | sed 's/[ ]*$//')

if [ -z "$VERSION" ]; then
    VERSION=$(grep "Version:" bp-loader.php | sed 's/.*Version:[ ]*//' | sed 's/[ ]*$//')
fi

echo -e "${GREEN}Building BuddyPress version: $VERSION${NC}"

# Step 1: Check if npm dependencies are installed
echo -e "\n${YELLOW}Step 1: Checking dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    echo "Installing npm dependencies..."
    npm install
else
    echo "Dependencies already installed."
fi

# Step 2: Clean previous builds
echo -e "\n${YELLOW}Step 2: Cleaning previous builds...${NC}"
rm -rf build/
rm -f buddypress-*.zip
echo "Cleaned previous builds."

# Step 3: Check for PHP dependencies and run appropriate build
echo -e "\n${YELLOW}Step 3: Checking PHP dependencies...${NC}"

# Check if grunt-contrib-compress is installed
if [ ! -d "node_modules/grunt-contrib-compress" ]; then
    echo "Installing grunt-contrib-compress for ZIP creation..."
    npm install grunt-contrib-compress --save-dev
fi

# Use the enhanced Gruntfile with ZIP creation
GRUNT_CMD="npx grunt --gruntfile Gruntfile-enhanced.js build-zip"

if [ -d "vendor" ] && [ -f "vendor/bin/phpcs" ]; then
    echo "PHP dependencies found. Running full build with PHP checks and ZIP creation..."
    $GRUNT_CMD
elif command -v composer &> /dev/null; then
    echo "Composer found. Installing PHP dependencies..."
    composer install
    echo "Running full build with all checks..."
    $GRUNT_CMD
else
    echo -e "${RED}ERROR: Composer not found!${NC}"
    echo "Please install Composer to run the complete build process:"
    echo "  brew install composer  (on macOS)"
    echo "  Or visit: https://getcomposer.org/download/"
    exit 1
fi


# Step 4: Check if build was successful
if [ ! -d "build" ] || [ -z "$(ls -A build)" ]; then
    echo -e "${YELLOW}Build directory empty. Attempting fallback build...${NC}"

    # Fallback: Run individual build tasks
    npx grunt clean:all
    npx grunt copy:files
    npx grunt uglify:core
    npx grunt cssmin
    npm run build || true

    # If still no build directory, copy from src
    if [ ! -d "build" ] || [ -z "$(ls -A build)" ]; then
        echo -e "${YELLOW}Creating build from source directory...${NC}"
        mkdir -p build
        cp -r src/* build/
    fi
fi

# Step 5: Ensure all root files are copied to build
echo -e "\n${YELLOW}Step 5: Ensuring all necessary files are in build...${NC}"

# Copy any missing root files that should be in the distribution
if [ -f "src/bp-loader.php" ] && [ ! -f "build/bp-loader.php" ]; then
    cp src/bp-loader.php build/
    echo "Copied bp-loader.php to build/"
fi

# Copy readme if exists
if [ -f "readme.txt" ] && [ ! -f "build/readme.txt" ]; then
    cp readme.txt build/
elif [ -f "README.md" ] && [ ! -f "build/README.md" ]; then
    cp README.md build/
fi

# Copy license if exists
if [ -f "license.txt" ] && [ ! -f "build/license.txt" ]; then
    cp license.txt build/
fi

# Step 5b: Generate POT file
echo -e "\n${YELLOW}Step 5b: Generating language POT file...${NC}"

# Find WP-CLI (check Local's path first)
WP_CLI=""
if [ -f "/Applications/Local.app/Contents/Resources/extraResources/bin/wp-cli/posix/wp" ]; then
    WP_CLI="/Applications/Local.app/Contents/Resources/extraResources/bin/wp-cli/posix/wp"
elif command -v wp &> /dev/null; then
    WP_CLI="wp"
fi

if [ -n "$WP_CLI" ]; then
    echo "Generating buddypress.pot file using WP-CLI..."

    # IMPORTANT: Fix ownership of build directory for WP-CLI to write
    echo "Fixing build directory permissions..."
    CURRENT_USER=$(whoami)

    # If running with sudo, get the actual user
    if [ -n "$SUDO_USER" ]; then
        ACTUAL_USER=$SUDO_USER
    else
        ACTUAL_USER=$CURRENT_USER
    fi

    # Change ownership of build to actual user (not root)
    if [ "$EUID" -eq 0 ] || [ -n "$SUDO_USER" ]; then
        sudo chown -R $ACTUAL_USER:staff build/ 2>/dev/null || true
        echo "Changed build ownership to $ACTUAL_USER"
    fi

    # Generate POT file in temp directory first (always works)
    echo "Creating POT file..."
    TEMP_POT="/tmp/buddypress-$$.pot"

    # Run WP-CLI as the actual user (not root)
    if [ "$EUID" -eq 0 ] || [ -n "$SUDO_USER" ]; then
        # Drop sudo privileges for WP-CLI command
        sudo -u $ACTUAL_USER $WP_CLI i18n make-pot build "$TEMP_POT" \
            --slug=buddypress \
            --domain=buddypress \
            --exclude="node_modules,vendor,tests,*.min.js,*.min.css" \
            --headers='{"Project-Id-Version": "BuddyPress 11.5.1", "Report-Msgid-Bugs-To": "https://buddypress.trac.wordpress.org"}' 2>&1 | grep -v "Warning:" || true
    else
        $WP_CLI i18n make-pot build "$TEMP_POT" \
            --slug=buddypress \
            --domain=buddypress \
            --exclude="node_modules,vendor,tests,*.min.js,*.min.css" \
            --headers='{"Project-Id-Version": "BuddyPress 11.5.1", "Report-Msgid-Bugs-To": "https://buddypress.trac.wordpress.org"}' 2>&1 | grep -v "Warning:" || true
    fi

    # Move POT file to build directory
    if [ -f "$TEMP_POT" ]; then
        # Move with appropriate permissions
        if [ "$EUID" -eq 0 ] || [ -n "$SUDO_USER" ]; then
            # Running as root, use sudo to move
            sudo mv "$TEMP_POT" build/buddypress.pot
            sudo chmod 644 build/buddypress.pot
        else
            mv "$TEMP_POT" build/buddypress.pot
            chmod 644 build/buddypress.pot 2>/dev/null || true
        fi

        if [ -f "build/buddypress.pot" ]; then
            POT_SIZE=$(du -h "build/buddypress.pot" | cut -f1)
            echo -e "${GREEN}✓ POT file generated successfully (${POT_SIZE})${NC}"
        fi
    else
        # Fallback: Try direct generation with proper user
        echo "Trying direct POT generation..."
        if [ "$EUID" -eq 0 ] || [ -n "$SUDO_USER" ]; then
            sudo -u $ACTUAL_USER $WP_CLI i18n make-pot build build/buddypress.pot \
                --slug=buddypress \
                --domain=buddypress 2>&1 | grep -v "Warning:" || true
        else
            $WP_CLI i18n make-pot build build/buddypress.pot \
                --slug=buddypress \
                --domain=buddypress 2>&1 | grep -v "Warning:" || true
        fi

        if [ -f "build/buddypress.pot" ]; then
            POT_SIZE=$(du -h "build/buddypress.pot" | cut -f1)
            echo -e "${GREEN}✓ POT file generated successfully (${POT_SIZE})${NC}"
        else
            echo -e "${YELLOW}⚠ POT file generation failed - will need manual generation${NC}"
            echo "Run after build: sudo chown -R \$(whoami) build/ && wp i18n make-pot build build/buddypress.pot"
        fi
    fi
else
    echo -e "${YELLOW}⚠ WP-CLI not found - skipping POT file generation${NC}"
    echo "To install WP-CLI: curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
fi

# Step 6: Check if ZIP was created by Grunt
echo -e "\n${YELLOW}Step 6: Checking ZIP file...${NC}"
ZIP_NAME="buddypress-${VERSION}.zip"

# If Grunt didn't create the ZIP, create it manually
if [ ! -f "$ZIP_NAME" ]; then
    echo "Creating ZIP file manually..."

    # Create a temporary directory with the plugin folder name
    TEMP_DIR="buddypress-build-temp"
    rm -rf $TEMP_DIR
    mkdir -p $TEMP_DIR/buddypress

    # Copy build contents to temp directory
    cp -r build/* $TEMP_DIR/buddypress/

    # Create ZIP from temp directory
    cd $TEMP_DIR
    zip -r ../$ZIP_NAME buddypress -x "*.DS_Store" "*/\.*" "*.git*" "*.svn*"
    cd ..

    # Clean up temp directory
    rm -rf $TEMP_DIR
else
    echo "ZIP file already created by Grunt: $ZIP_NAME"
fi

# Step 7: Create additional distribution formats
echo -e "\n${YELLOW}Step 7: Creating additional distribution formats...${NC}"

# Create a development version ZIP (includes source)
DEV_ZIP_NAME="buddypress-${VERSION}-dev.zip"
zip -r $DEV_ZIP_NAME . -x "*.DS_Store" "*/\.*" "*.git*" "*.svn*" "node_modules/*" "build/*" "*.zip"
echo "Created development ZIP: $DEV_ZIP_NAME"

# Step 8: Run validation
echo -e "\n${YELLOW}Step 8: Running build validation...${NC}"
echo "========================================="

# Check if validation script exists
if [ -f "validate-build.sh" ]; then
    # Make it executable if it isn't
    chmod +x validate-build.sh 2>/dev/null

    # Run validation and capture result
    if ./validate-build.sh; then
        echo -e "\n${GREEN}✓ BUILD VALIDATION PASSED${NC}"
        VALIDATION_STATUS="${GREEN}PASSED${NC}"
    else
        echo -e "\n${YELLOW}⚠ BUILD VALIDATION HAD WARNINGS${NC}"
        VALIDATION_STATUS="${YELLOW}PASSED WITH WARNINGS${NC}"
    fi
else
    echo -e "${YELLOW}Validation script not found - skipping validation${NC}"
    VALIDATION_STATUS="${YELLOW}NOT VALIDATED${NC}"
fi

# Step 9: Final report
echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "Version: ${YELLOW}$VERSION${NC}"
echo -e "Production ZIP: ${YELLOW}$ZIP_NAME${NC}"
echo -e "Development ZIP: ${YELLOW}$DEV_ZIP_NAME${NC}"
echo -e "Build Directory: ${YELLOW}build/${NC}"
echo -e "Validation: ${VALIDATION_STATUS}"

# Check file sizes
if [ -f "$ZIP_NAME" ]; then
    SIZE=$(du -h "$ZIP_NAME" | cut -f1)
    echo -e "Production ZIP Size: ${YELLOW}$SIZE${NC}"
fi

if [ -f "$DEV_ZIP_NAME" ]; then
    DEV_SIZE=$(du -h "$DEV_ZIP_NAME" | cut -f1)
    echo -e "Development ZIP Size: ${YELLOW}$DEV_SIZE${NC}"
fi

# Count total files in build
if [ -d "build" ]; then
    TOTAL_FILES=$(find build -type f | wc -l | tr -d ' ')
    echo -e "Total Files in Build: ${YELLOW}$TOTAL_FILES${NC}"
fi

echo -e "\n${GREEN}The plugin is ready for distribution!${NC}"
echo -e "You can now:"
echo -e "  1. Use ${YELLOW}$ZIP_NAME${NC} for production deployment"
echo -e "  2. Upload to WordPress.org repository"
echo -e "  3. Test the build in ${YELLOW}build/${NC} directory"
echo -e "  4. Review validation report above for any warnings"