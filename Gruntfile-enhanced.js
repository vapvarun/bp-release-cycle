/* jshint node:true */
/* global module */

/**
 * Enhanced Gruntfile for BuddyPress with ZIP creation
 *
 * This file extends the original Gruntfile with additional tasks for
 * creating versioned ZIP files after build.
 *
 * Usage:
 *   grunt --gruntfile Gruntfile-enhanced.js build-zip
 *   grunt --gruntfile Gruntfile-enhanced.js build-release
 */

module.exports = function( grunt ) {
    // Load the original Gruntfile configuration
    var originalGruntConfig = require('./Gruntfile.js');

    // Apply original configuration
    originalGruntConfig(grunt);

    // Get existing configuration
    var config = grunt.config.get();

    // Add compression task configuration
    config.compress = {
        production: {
            options: {
                archive: function() {
                    // Read version from package.json
                    var pkg = grunt.file.readJSON('package.json');
                    var version = pkg.version || '11.5.1';

                    // Try to get version from bp-loader.php if not in package.json
                    if (!version && grunt.file.exists('src/bp-loader.php')) {
                        var bpLoader = grunt.file.read('src/bp-loader.php');
                        var versionMatch = bpLoader.match(/Version:\s*(.+)/);
                        if (versionMatch) {
                            version = versionMatch[1].trim();
                        }
                    }

                    return 'buddypress-' + version + '.zip';
                },
                mode: 'zip',
                level: 9 // Maximum compression
            },
            files: [{
                expand: true,
                cwd: 'build/',
                src: ['**/*'],
                dest: 'buddypress/'
            }]
        },
        development: {
            options: {
                archive: function() {
                    var pkg = grunt.file.readJSON('package.json');
                    var version = pkg.version || '11.5.1';
                    return 'buddypress-' + version + '-dev.zip';
                },
                mode: 'zip',
                level: 9
            },
            files: [{
                expand: true,
                src: [
                    '**/*',
                    '!node_modules/**',
                    '!build/**',
                    '!*.zip',
                    '!.git/**',
                    '!.svn/**',
                    '!*.log',
                    '!.DS_Store',
                    '!**/Thumbs.db'
                ],
                dest: 'buddypress-dev/'
            }]
        }
    };

    // Add clean tasks for ZIP files
    if (!config.clean) {
        config.clean = {};
    }
    config.clean.zip = {
        src: ['*.zip']
    };

    // Add copy task to ensure all files are in build
    if (!config.copy) {
        config.copy = {};
    }
    config.copy.rootfiles = {
        files: [
            {
                src: ['readme.txt', 'README.md', 'license.txt', 'LICENSE'],
                dest: 'build/',
                filter: 'isFile',
                expand: true,
                flatten: true
            }
        ]
    };

    // Set the updated configuration
    grunt.config.set('compress', config.compress);
    grunt.config.set('clean', config.clean);
    grunt.config.set('copy', config.copy);

    // Load additional npm tasks
    grunt.loadNpmTasks('grunt-contrib-compress');

    // Register new tasks

    // Simple makepot task for Local WP
    grunt.registerTask('makepot-simple', 'Generate POT file using WP-CLI', function() {
        var done = this.async();
        var cmd = 'wp i18n make-pot build build/buddypress.pot';

        grunt.log.writeln('Generating POT file with WP-CLI...');

        grunt.util.spawn({
            cmd: 'sh',
            args: ['-c', cmd],
            opts: { stdio: 'inherit' }
        }, function(error, result) {
            if (error) {
                grunt.log.warn('POT file generation skipped (optional)');
            } else {
                grunt.log.ok('POT file generated successfully');
            }
            done();
        });
    });

    // Build with ZIP creation
    grunt.registerTask('build-zip',
        'Build BuddyPress and create a versioned ZIP file',
        function() {
            // Run all build tasks with simplified makepot
            grunt.task.run([
                'commit', 'clean:all', 'copy:files', 'uglify:core',
                'jsvalidate:build', 'exec:blocks_build', 'cssmin',
                'bp_rest', 'makepot-simple', 'exec:bpdefault',
                'exec:cli', 'clean:cli', 'copy:rootfiles',
                'compress:production'
            ]);
        }
    );

    // Full release build (production and development ZIPs)
    grunt.registerTask('build-release',
        'Build BuddyPress and create both production and development ZIP files',
        ['build', 'copy:rootfiles', 'compress:production', 'compress:development']
    );

    // Clean build with ZIP
    grunt.registerTask('build-clean',
        'Clean everything, rebuild, and create ZIP',
        ['clean:zip', 'build', 'copy:rootfiles', 'compress:production']
    );

    // Version info task
    grunt.registerTask('version', 'Display version information', function() {
        var pkg = grunt.file.readJSON('package.json');
        var version = pkg.version || 'Unknown';

        // Try to get version from bp-loader.php
        if (grunt.file.exists('src/bp-loader.php')) {
            var bpLoader = grunt.file.read('src/bp-loader.php');
            var versionMatch = bpLoader.match(/Version:\s*(.+)/);
            if (versionMatch) {
                version = versionMatch[1].trim();
            }
        }

        grunt.log.writeln('');
        grunt.log.writeln('BuddyPress Version: ' + version);
        grunt.log.writeln('');
        grunt.log.writeln('Available enhanced tasks:');
        grunt.log.writeln('  grunt --gruntfile Gruntfile-enhanced.js build-zip      : Build and create production ZIP');
        grunt.log.writeln('  grunt --gruntfile Gruntfile-enhanced.js build-release  : Build and create all ZIPs');
        grunt.log.writeln('  grunt --gruntfile Gruntfile-enhanced.js build-clean    : Clean, build, and ZIP');
        grunt.log.writeln('');
    });
};