#!/bin/bash
# install.sh - Installation script for Claude API Client

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PROGRAM_NAME="git-commit-ai"

echo -e "${YELLOW}${PROGRAM_NAME} Installation Script${NC}"
echo "----------------------------------------"

# Check for dependencies
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is required but not installed.${NC}"
        return 1
    fi
    return 0
}

check_lib() {
    if [ -z "$(ldconfig -p | grep $1)" ]; then
        echo -e "${RED}Error: Library $1 is required but not installed.${NC}"
        return 1
    fi
    return 0
}

# Check for required tools and libraries
echo -e "${YELLOW}Checking dependencies...${NC}"
DEPS_OK=true

check_dependency gcc || DEPS_OK=false
check_dependency make || DEPS_OK=false
check_lib libcurl.so || DEPS_OK=false
check_lib libcjson.so || DEPS_OK=false

# New check for regex support
if ! grep -q 'REGEX' /usr/include/regex.h 2>/dev/null; then
    echo -e "${RED}Error: regex.h header not found or incomplete.${NC}"
    DEPS_OK=false
fi

if [ "$DEPS_OK" = false ]; then
    echo -e "${RED}Missing dependencies. Please install them first.${NC}"
    echo "On Debian/Ubuntu: sudo apt-get install build-essential libcurl4-openssl-dev libcjson-dev"
    echo "On macOS with Homebrew: brew install curl cjson"
    exit 1
fi

echo -e "${GREEN}All dependencies are installed.${NC}"

# Build the project
echo -e "${YELLOW}Building ${PROGRAM_NAME}...${NC}"
make clean
make

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed. Please check the error messages above.${NC}"
    exit 1
fi

echo -e "${GREEN}Build completed successfully.${NC}"

# Determine installation type
echo -e "${YELLOW}Installation options:${NC}"
echo "1. Install system-wide (requires sudo permissions)"
echo "2. Install for current user only"
echo "3. Skip installation (just build)"

read -p "Select an option (1-3): " INSTALL_OPTION

case $INSTALL_OPTION in
    1)
        echo -e "${YELLOW}Installing system-wide...${NC}"
        sudo make install
        if [ $? -ne 0 ]; then
            echo -e "${RED}System-wide installation failed.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Installation completed. The program is now available as '${PROGRAM_NAME}'${NC}"
        ;;
    2)
        echo -e "${YELLOW}Installing for current user...${NC}"
        mkdir -p $HOME/.local/bin
        cp ${PROGRAM_NAME} $HOME/.local/bin/

        # Check if $HOME/.local/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo -e "${YELLOW}Adding $HOME/.local/bin to your PATH in .bashrc${NC}"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.bashrc
            echo "Please run 'source $HOME/.bashrc' or start a new terminal to update your PATH"
        fi

        echo -e "${GREEN}Installation completed. The program is now available as '${PROGRAM_NAME}'${NC}"
        ;;
    3)
        echo -e "${GREEN}Build completed. The executable is at $(pwd)/${PROGRAM_NAME}${NC}"
        ;;
    *)
        echo -e "${RED}Invalid option. Exiting.${NC}"
        exit 1
        ;;
esac

# Setup API key directory
echo -e "${YELLOW}Setting up config directory...${NC}"
CONFIG_DIR="$HOME/.config/claude"
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

echo -e "${GREEN}Config directory created at $CONFIG_DIR${NC}"

# Setup API key file
API_KEY_PATH="$CONFIG_DIR/api_key.txt"
if [ ! -f "$API_KEY_PATH" ]; then
    echo -e "${YELLOW}Creating API key file...${NC}"
    echo -e "${YELLOW}Please enter your Anthropic API key:${NC}"
    read -p "> " API_KEY
    echo "$API_KEY" > "$API_KEY_PATH"
    chmod 600 "$API_KEY_PATH"
    echo -e "${GREEN}API key file created at $API_KEY_PATH${NC}"
else
    echo -e "${YELLOW}API key file already exists at $API_KEY_PATH${NC}"
    echo "If you need to update your API key, edit this file or delete it and run the installer again."
fi

# Setup default profile
PROFILE_PATH="$CONFIG_DIR/profile.txt"
echo -e "${YELLOW}Checking for profile file...${NC}"

if [ ! -f "$PROFILE_PATH" ]; then
    echo -e "${YELLOW}Creating default profile...${NC}"

    # First check if profile.txt exists in current directory
    if [ -f "profile.txt" ]; then
        cp profile.txt "$PROFILE_PATH"
        echo -e "${GREEN}Installed profile.txt as default profile${NC}"
    else
        # Create a default profile
        cat > "$PROFILE_PATH" << ENDOFPROFILE
I am a developer with experience in software engineering.
My focus is on writing clean, maintainable code with proper documentation.
I specialize in C/C++ programming and systems development.
I prioritize code quality, performance, and security in my work.
ENDOFPROFILE
        echo -e "${GREEN}Created default profile at $PROFILE_PATH${NC}"
    fi

    chmod 600 "$PROFILE_PATH"
else
    echo -e "${GREEN}Profile file already exists at $PROFILE_PATH${NC}"
fi

echo "You can edit $PROFILE_PATH to better match your skills and preferences."

# Git integration
echo -e "${YELLOW}Do you want to set up git integration? (y/n)${NC}"
read -p "This will create a git alias to use Claude for commit message generation: " GIT_INTEGRATION

if [ "$GIT_INTEGRATION" = "y" ] || [ "$GIT_INTEGRATION" = "Y" ]; then
    # Create git alias
    if [ "$INSTALL_OPTION" -eq 1 ]; then
        GIT_CMD="${PROGRAM_NAME}"
    elif [ "$INSTALL_OPTION" -eq 2 ]; then
        GIT_CMD="$HOME/.local/bin/${PROGRAM_NAME}"
    else
        GIT_CMD="$(pwd)/${PROGRAM_NAME}"
    fi

    echo -e "${YELLOW}Setting up git alias...${NC}"
    ALIAS_NAME="claude-commit"
    git config --global alias.${ALIAS_NAME} "!git diff | ${GIT_CMD} -o commit_msg.md"

    echo -e "${GREEN}Git alias created successfully.${NC}"
    echo "You can now use 'git ${ALIAS_NAME}' to generate commit messages."
    echo "The program will automatically:"
    echo "  - Use your API key from $API_KEY_PATH"
    echo "  - Use your profile from $PROFILE_PATH"
    echo "  - Extract ticket numbers like DOT-1234 from your branch name"
fi

echo -e "${GREEN}Installation process completed!${NC}"
echo -e "${YELLOW}New feature:${NC}"
echo "  When your branch name contains a pattern like DOT-1234,"
echo "  it will automatically be included in the commit message."
