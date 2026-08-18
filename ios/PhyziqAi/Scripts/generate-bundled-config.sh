#!/bin/bash
# Generates a bundled config plist from EXPO_PUBLIC_* environment variables.
# This runs as a build script phase so the values are baked into the app bundle.

set -e

OUTPUT_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
OUTPUT_FILE="${OUTPUT_DIR}/BundledConfig.plist"

mkdir -p "${OUTPUT_DIR}"

# Extract EXPO_PUBLIC_* values from the build environment.
# If a value is missing, write an empty string.
PROJECT_ID="${EXPO_PUBLIC_PROJECT_ID:-}"
API_BASE_URL="${EXPO_PUBLIC_RORK_API_BASE_URL:-}"
APP_KEY="${EXPO_PUBLIC_RORK_APP_KEY:-}"
AUTH_URL="${EXPO_PUBLIC_RORK_AUTH_URL:-}"
FUNCTIONS_URL="${EXPO_PUBLIC_RORK_FUNCTIONS_URL:-}"
TOOLKIT_SECRET="${EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY:-}"
TEAM_ID="${EXPO_PUBLIC_TEAM_ID:-}"
TOOLKIT_URL="${EXPO_PUBLIC_TOOLKIT_URL:-}"

cat > "${OUTPUT_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>EXPO_PUBLIC_PROJECT_ID</key>
    <string>${PROJECT_ID}</string>
    <key>EXPO_PUBLIC_RORK_API_BASE_URL</key>
    <string>${API_BASE_URL}</string>
    <key>EXPO_PUBLIC_RORK_APP_KEY</key>
    <string>${APP_KEY}</string>
    <key>EXPO_PUBLIC_RORK_AUTH_URL</key>
    <string>${AUTH_URL}</string>
    <key>EXPO_PUBLIC_RORK_FUNCTIONS_URL</key>
    <string>${FUNCTIONS_URL}</string>
    <key>EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY</key>
    <string>${TOOLKIT_SECRET}</string>
    <key>EXPO_PUBLIC_TEAM_ID</key>
    <string>${TEAM_ID}</string>
    <key>EXPO_PUBLIC_TOOLKIT_URL</key>
    <string>${TOOLKIT_URL}</string>
</dict>
</plist>
EOF

echo "Generated BundledConfig.plist at ${OUTPUT_FILE}"
