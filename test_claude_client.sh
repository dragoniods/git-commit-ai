#!/bin/bash
# test_claude_client.sh - Simple test script for git-commit-ai

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PROGRAM_NAME="git-commit-ai"

echo -e "${YELLOW}${PROGRAM_NAME} Test Script${NC}"
echo "--------------------------------"

# Check if the program exists
if [ ! -f "./${PROGRAM_NAME}" ]; then
    echo -e "${RED}Error: ${PROGRAM_NAME} not found in current directory${NC}"
    echo "Please run 'make' first to build the program"
    exit 1
fi

# Check for API key file (optional parameter)
API_KEY_FILE="$HOME/.config/claude/api_key.txt"
if [ -n "$1" ]; then
    API_KEY_FILE="$1"
    echo -e "${YELLOW}Using specified API key file: ${API_KEY_FILE}${NC}"
else
    echo -e "${YELLOW}Using default API key file: ${API_KEY_FILE}${NC}"
fi

# Check if the API key file exists
if [ ! -f "$API_KEY_FILE" ]; then
    echo -e "${RED}Error: API key file '$API_KEY_FILE' not found${NC}"
    echo "Please set up your API key first or specify a valid key file as parameter"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo -e "${GREEN}Created temporary directory: $TEMP_DIR${NC}"

# Create a test profile
PROFILE_FILE="$TEMP_DIR/profile.txt"
cat > "$PROFILE_FILE" << ENDPROFILE
# Test Profile for Git Commit AI

I am a software developer with expertise in:
- C/C++ programming and systems development
- Clean, maintainable code with proper documentation
- Performance optimization and memory management
- Security-focused application development

For commit messages, I prefer:
- Clear, concise descriptions of changes
- Explanation of both what changed and why
- Proper formatting following git commit message conventions
ENDPROFILE
echo -e "${GREEN}Created test profile${NC}"

# Create a test git diff
DIFF_FILE="$TEMP_DIR/test.diff"
cat > "$DIFF_FILE" << ENDDIFF
diff --git a/main.c b/main.c
index 12345..67890 100644
--- a/main.c
+++ b/main.c
@@ -10,7 +10,7 @@

 int main(int argc, char *argv[]) {
     // Initialize resources
-    char *buffer = malloc(100);
+    char *buffer = malloc(100 * sizeof(char));
     if (!buffer) {
         fprintf(stderr, "Memory allocation failed\n");
         return 1;
@@ -25,6 +25,9 @@ int main(int argc, char *argv[]) {

     process_data(buffer);

+    // Free resources properly
+    free(buffer);
+
     return 0;
 }
ENDDIFF
echo -e "${GREEN}Created test git diff${NC}"

# Output file
OUTPUT_FILE="$TEMP_DIR/result.md"

echo -e "${YELLOW}Running ${PROGRAM_NAME}...${NC}"

# Test 1: Using custom API key and profile
echo -e "${YELLOW}Test 1: Using custom API key and profile...${NC}"
./${PROGRAM_NAME} -k "$API_KEY_FILE" -p "$PROFILE_FILE" -d "$DIFF_FILE" -o "$OUTPUT_FILE"

# Check result
if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    echo -e "${GREEN}Test 1 successful!${NC}"
    echo "--------------------------------"
    echo -e "${YELLOW}Output:${NC}"
    cat "$OUTPUT_FILE"
    echo "--------------------------------"
else
    echo -e "${RED}Test 1 failed${NC}"
fi

# Test 2: Using default API key (if we can) and custom profile
if [ -f "$HOME/.config/claude/api_key.txt" ]; then
    echo -e "${YELLOW}Test 2: Using default API key and custom profile...${NC}"
    rm "$OUTPUT_FILE" 2>/dev/null  # Remove previous output file
    ./${PROGRAM_NAME} -p "$PROFILE_FILE" -d "$DIFF_FILE" -o "$OUTPUT_FILE"
    
    if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
        echo -e "${GREEN}Test 2 successful!${NC}"
    else
        echo -e "${RED}Test 2 failed${NC}"
    fi
else
    echo -e "${YELLOW}Skipping Test 2: Default API key not available${NC}"
fi

# Test 3: With verbose flag
echo -e "${YELLOW}Test 3: Testing verbose mode...${NC}"
rm "$OUTPUT_FILE" 2>/dev/null  # Remove previous output file
./${PROGRAM_NAME} -v -k "$API_KEY_FILE" -p "$PROFILE_FILE" -d "$DIFF_FILE" -o "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Test 3 successful!${NC}"
else
    echo -e "${RED}Test 3 failed${NC}"
fi

echo -e "${GREEN}Test completed${NC}"
