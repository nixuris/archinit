#!/bin/bash

# --- Configuration for User-Wide npm Setup ---
NPM_GLOBAL_PREFIX="$HOME/.local"
NPM_BIN_PATH="$NPM_GLOBAL_PREFIX/bin"
NPM_LIB_PATH="$NPM_GLOBAL_PREFIX/lib/node_modules"
FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_CONF_D_DIR="$FISH_CONFIG_DIR/conf.d"
NPM_FISH_CONFIG_FILE="$FISH_CONF_D_DIR/npm.fish"
# --------------------------------------------

echo "Starting user-wide npm setup for Fish shell..."

# 1. Check if Fish shell is detected as current shell
if [[ -z "$FISH_VERSION" ]]; then
    echo "WARNING: Fish shell not detected as your current shell."
    echo "Aborting. Please run this script in a Fish shell or adjust for your shell."
      exit 1
fi
# 2. Configure npm to use the user's local directory as prefix
echo "Setting npm global prefix to '$NPM_GLOBAL_PREFIX'..."
npm config set prefix "$NPM_GLOBAL_PREFIX"
if [ $? -eq 0 ]; then
    echo "npm prefix set successfully."
else
    echo "Failed to set npm prefix. Aborting."
    exit 1
fi

# 3. Create necessary directories
echo "Creating necessary directories: $NPM_BIN_PATH and $NPM_LIB_PATH..."
mkdir -p "$NPM_BIN_PATH" "$NPM_LIB_PATH"
if [ $? -eq 0 ]; then
    echo "Directories created/ensured."
else
    echo "Failed to create directories. Aborting."
    exit 1
fi

# 4. Create or update the npm.fish configuration for Fish shell
echo "Creating/updating Fish shell config file: $NPM_FISH_CONFIG_FILE..."
cat << EOF > "$NPM_FISH_CONFIG_FILE"
# ~/.config/fish/conf.d/npm.fish

# NPM User-Wide Global Package Configuration
# This ensures global npm packages installed to ~/.local/bin are found.

set -gx NPM_GLOBAL_BIN "$HOME/.local/bin"

if not string match -q -- \$NPM_GLOBAL_BIN \$PATH
  set -gx PATH "\$NPM_GLOBAL_BIN" \$PATH
end
EOF

if [ $? -eq 0 ]; then
    echo "npm.fish configuration created successfully."
else
    echo "❌ Failed to create npm.fish configuration. Aborting."
    exit 1
fi

echo "--- Setup Complete! ---"
echo "To activate the changes, please do ONE of the following:"
echo "1. Open a new Fish shell terminal."
echo "2. Run: 'source $FISH_CONFIG_DIR/config.fish' in your current Fish session."
echo ""
echo "--- Verification Steps ---"
echo "After activating the changes, run these commands to verify:"
echo "1. Verify npm prefix:         npm config get prefix"
echo "   (Should show: '$NPM_GLOBAL_PREFIX')"
echo "2. Install a global package:  npm install -g npm-check-updates"
echo "3. Verify package executable: which ncu"
echo "   (Should show: '$NPM_BIN_PATH/ncu')"
echo ""
