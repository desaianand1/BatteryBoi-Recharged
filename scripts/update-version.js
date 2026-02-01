#!/usr/bin/env node

/**
 * Updates version numbers in Xcode project files.
 * Called by semantic-release during the prepare phase.
 *
 * Usage: node scripts/update-version.js <version>
 * Example: node scripts/update-version.js 3.0.0
 */

const fs = require('fs');
const path = require('path');

const PROJECT_FILE = path.join(__dirname, '..', 'BatteryBoi.xcodeproj', 'project.pbxproj');

function parseVersion(version) {
  const match = version.match(/^(\d+)\.(\d+)\.(\d+)/);
  if (!match) {
    throw new Error(`Invalid version format: ${version}`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

function calculateBuildNumber(major, minor, patch) {
  // Build number formula: major*10000 + minor*100 + patch
  // e.g., 3.0.0 = 30000, 2.4.1 = 20401
  return major * 10000 + minor * 100 + patch;
}

function updateProjectFile(version) {
  const { major, minor, patch } = parseVersion(version);
  const buildNumber = calculateBuildNumber(major, minor, patch);

  console.log(`Updating version to ${version} (build ${buildNumber})`);

  let content = fs.readFileSync(PROJECT_FILE, 'utf8');

  // Update MARKETING_VERSION
  const marketingRegex = /MARKETING_VERSION = [\d.]+;/g;
  const marketingReplacement = `MARKETING_VERSION = ${version};`;
  content = content.replace(marketingRegex, marketingReplacement);

  // Update CURRENT_PROJECT_VERSION
  const buildRegex = /CURRENT_PROJECT_VERSION = \d+;/g;
  const buildReplacement = `CURRENT_PROJECT_VERSION = ${buildNumber};`;
  content = content.replace(buildRegex, buildReplacement);

  fs.writeFileSync(PROJECT_FILE, content, 'utf8');

  console.log(`Updated ${PROJECT_FILE}`);
  console.log(`  MARKETING_VERSION = ${version}`);
  console.log(`  CURRENT_PROJECT_VERSION = ${buildNumber}`);
}

// Main
const version = process.argv[2];

if (!version) {
  console.error('Usage: node update-version.js <version>');
  console.error('Example: node update-version.js 3.0.0');
  process.exit(1);
}

try {
  updateProjectFile(version);
  console.log('Version update complete!');
} catch (error) {
  console.error('Error updating version:', error.message);
  process.exit(1);
}
