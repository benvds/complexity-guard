#!/usr/bin/env node

const { spawnSync } = require('child_process');
const { join } = require('path');

// Map process.platform + process.arch to package names
const PLATFORM_MAP = {
  'darwin-arm64': '@complexity-guard/darwin-arm64',
  'darwin-x64': '@complexity-guard/darwin-x64',
  'linux-arm64': '@complexity-guard/linux-arm64',
  'linux-x64': '@complexity-guard/linux-x64',
  'win32-x64': '@complexity-guard/windows-x64',
};

const platformKey = `${process.platform}-${process.arch}`;
const packageName = PLATFORM_MAP[platformKey];

if (!packageName) {
  console.error(
    `Unsupported platform: ${process.platform}-${process.arch}\n` +
    `Supported platforms: ${Object.keys(PLATFORM_MAP).join(', ')}`
  );
  process.exit(1);
}

let binaryPath;
try {
  const packageJsonPath = require.resolve(`${packageName}/package.json`);
  const packageDir = join(packageJsonPath, '..');
  const binaryName = process.platform === 'win32' ? 'complexity-guard.exe' : 'complexity-guard';
  binaryPath = join(packageDir, binaryName);
} catch (err) {
  console.error(
    `Failed to find ${packageName}.\n` +
    `This usually means the platform-specific binary was not installed.\n` +
    `Try running: npm install --force\n\n` +
    `Error: ${err.message}`
  );
  process.exit(1);
}

const result = spawnSync(binaryPath, process.argv.slice(2), {
  stdio: 'inherit',
});

process.exit(result.status ?? 1);
