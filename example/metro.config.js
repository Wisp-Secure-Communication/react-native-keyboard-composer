// Learn more https://docs.expo.io/guides/customizing-metro
const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, "..");

const config = getDefaultConfig(projectRoot);

// Watch the parent directory for the library source files
config.watchFolders = [workspaceRoot];

// Block the parent's node_modules react/react-native to avoid duplicates
config.resolver.blockList = [
  ...Array.from(config.resolver.blockList ?? []),
  new RegExp(path.resolve(workspaceRoot, "node_modules", "react", ".*")),
  new RegExp(path.resolve(workspaceRoot, "node_modules", "react-native", ".*")),
];

// Resolve modules from both the example and the parent
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
  path.resolve(workspaceRoot, "node_modules"),
];

// Map the library to the parent directory source
config.resolver.extraNodeModules = {
  "@launchhq/react-native-keyboard-composer": workspaceRoot,
};

module.exports = config;
