# BuddyPress Release Cycle Build System

A professional build and release system for BuddyPress plugin that automates the entire build process, generates translation files, creates versioned ZIP distributions, and validates the build output.

## 🎯 Purpose

This build system provides:
- **Automated build process** with minification and optimization
- **POT file generation** for translations
- **Versioned ZIP files** for distribution
- **Build validation** to ensure nothing is missing
- **Support for Local WP** and standard WordPress environments

## 📁 Files in This Package

### 1. `build-complete.sh`
Complete build orchestration script that handles:
- Installing dependencies (npm and composer)
- Running Grunt build tasks
- Generating POT translation file
- Creating versioned ZIP files
- Running build validation
- Managing file permissions

### 2. `Gruntfile-enhanced.js`
Enhanced Grunt configuration that extends the original with:
- ZIP compression tasks
- Versioned file naming
- Safe makepot task for translations
- Build validation integration

## 🚀 Quick Start

### Prerequisites

1. **Node.js and npm** installed
2. **Composer** installed (for PHP dependencies)
3. **WP-CLI** installed (for POT file generation)
4. **Local WP** or standard WordPress environment

### Installation

**IMPORTANT:** These files must be placed in the BuddyPress plugin root directory (where `bp-loader.php` is located).

1. Navigate to your BuddyPress plugin root:
```bash
cd /path/to/wp-content/plugins/buddypress
```

2. Copy the build files to the root:
```bash
# If you have the release-cycle folder
cp release-cycle/build-complete.sh ./
cp release-cycle/Gruntfile-enhanced.js ./

# Or download directly from GitHub
wget https://github.com/YOUR-REPO/release-cycle/build-complete.sh
wget https://github.com/YOUR-REPO/release-cycle/Gruntfile-enhanced.js

# Make the script executable
chmod +x build-complete.sh
```

3. Install the compression dependency:
```bash
npm install grunt-contrib-compress --save-dev
```

### Directory Structure

Your BuddyPress root should look like this:
```
buddypress/
├── src/                      # Source files
├── build/                    # Created by build process
├── node_modules/             # npm dependencies
├── bp-loader.php             # Main plugin file
├── package.json              # npm configuration
├── Gruntfile.js              # Original Gruntfile
├── Gruntfile-enhanced.js     # ← Add this file here
├── build-complete.sh         # ← Add this file here
└── ...
```

### Running the Build

From the BuddyPress root directory:
```bash
sudo ./build-complete.sh
```

This single command will:
1. ✅ Install all npm dependencies
2. ✅ Install PHP dependencies via Composer
3. ✅ Run all quality checks (PHP CodeSniffer, JSHint)
4. ✅ Build and minify all assets
5. ✅ Generate POT file for translations
6. ✅ Create production ZIP: `buddypress-11.5.1.zip`
7. ✅ Create development ZIP: `buddypress-11.5.1-dev.zip`
8. ✅ Validate the build completeness

## 📋 Detailed Build Process

### Step 1: Dependencies
- Checks and installs npm packages
- Installs Composer dependencies for PHP checks
- Installs grunt-contrib-compress for ZIP creation

### Step 2: Clean Build
- Removes previous build directory
- Cleans up old ZIP files

### Step 3: Grunt Build
- Runs commit tasks (linting, validation)
- Copies all source files to build/
- Minifies JavaScript files
- Minifies CSS files
- Builds block components
- Generates REST API components

### Step 4: POT File Generation
- Uses WP-CLI to scan all PHP files
- Extracts translatable strings
- Creates `build/buddypress.pot`
- Handles permission issues automatically

### Step 5: ZIP Creation
- Creates production ZIP with version number
- Creates development ZIP with source files
- Proper folder structure for WordPress

### Step 6: Validation
- Checks for all required files
- Validates component directories
- Verifies minified assets
- Reports any missing items

## 🏗️ Build Output Structure

```
build/
├── bp-activity/
├── bp-blogs/
├── bp-core/
├── bp-friends/
├── bp-groups/
├── bp-members/
├── bp-messages/
├── bp-notifications/
├── bp-settings/
├── bp-templates/
├── bp-xprofile/
├── bp-loader.php
├── buddypress.pot
└── ... (1200+ files total)

buddypress-11.5.1.zip (Production - 3.5MB)
buddypress-11.5.1-dev.zip (Development - 15MB)
```

## 🔧 Customization

### Changing Version Number

The version is automatically read from:
- `src/bp-loader.php` or
- `bp-loader.php`

Update the version in these files before building.

### Modifying Build Tasks

Edit `Gruntfile-enhanced.js` to customize:
- Compression settings
- File exclusions
- Build paths
- Task sequences

### Permission Issues

The script handles permissions automatically:
- Detects if running with sudo
- Manages WP-CLI root user issues
- Fixes build directory ownership

## 🐛 Troubleshooting

### POT File Not Generated
```bash
# Fix permissions and generate manually
sudo chown -R $(whoami) build/
wp i18n make-pot build build/buddypress.pot
```

### Composer Not Found
```bash
# Install Composer (macOS)
brew install composer

# Or download directly
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### WP-CLI Not Found
```bash
# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```

### Build Directory Permission Denied
```bash
# Fix ownership
sudo chown -R $(whoami):staff build/
```

## 📊 Validation Output Example

```
=========================================
BuddyPress Build Validation
=========================================
✓ bp-loader.php
✓ All 11 components present
✓ 78 minified CSS files
✓ 147 minified JS files
✓ Templates included
✓ POT file generated
✓ ZIP file created

Build Status: PASSED
Total Files: 1,247
Build Size: 12.3MB
ZIP Size: 3.5MB
```

## 🔄 Release Workflow

For a complete release with version tagging:

1. **Update version** in `bp-loader.php`
2. **Commit changes** to git/svn
3. **Create version tag**:
   ```bash
   git tag -a v11.5.2 -m "Release version 11.5.2"
   git push origin v11.5.2
   ```
4. **Run build**:
   ```bash
   sudo ./build-complete.sh
   ```
5. **Upload** `buddypress-11.5.2.zip` to WordPress.org

## 📚 Additional Resources

- [BuddyPress Development](https://codex.buddypress.org/developer/)
- [WordPress Plugin Guidelines](https://developer.wordpress.org/plugins/wordpress-org/detailed-plugin-guidelines/)
- [WP-CLI Documentation](https://wp-cli.org/)
- [Grunt Documentation](https://gruntjs.com/)

## 🤝 Contributing

This build system is designed to be reusable for other WordPress plugins. Feel free to:
- Fork and adapt for your plugin
- Submit improvements via pull requests
- Report issues on GitHub
- Share with the WordPress community

## 📄 License

This build system is released under the same license as BuddyPress (GPL v2 or later).

---

**Created for BuddyPress and the WordPress community** 🚀
