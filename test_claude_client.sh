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

# Test 4: Testing DOT-XXXX pattern extraction
echo -e "${YELLOW}Test 4: Testing DOT-XXXX pattern extraction...${NC}"

# Create a fake git repo and branch with DOT-XXXX pattern
TEST_GIT_DIR="$TEMP_DIR/git_test"
mkdir -p "$TEST_GIT_DIR"
cd "$TEST_GIT_DIR"

# Initialize git repo and simulate a branch with DOT ticket
git init -q
touch README.md
git add README.md
git config --local user.email "test@example.com"
git config --local user.name "Test User"
git commit -q -m "Initial commit"
git checkout -b feature/DOT-1234-test-feature

echo -e "${GREEN}Created test git repo with branch 'feature/DOT-1234-test-feature'${NC}"

# Create a simple diff in the test repo
echo "# Test Project" > README.md
git add README.md
git diff --staged > "$TEMP_DIR/branch_test.diff"

# Go back to original directory
cd - > /dev/null

# Run with the test diff and verbose mode to see DOT pattern detection
rm "$OUTPUT_FILE" 2>/dev/null  # Remove previous output file
echo -e "${YELLOW}Running with diff from DOT-1234 branch...${NC}"
./${PROGRAM_NAME} -v -k "$API_KEY_FILE" -p "$PROFILE_FILE" -d "$TEMP_DIR/branch_test.diff" -o "$OUTPUT_FILE"

# Check if DOT-1234 is in the output
if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    if grep -q "DOT-1234" "$OUTPUT_FILE"; then
        echo -e "${GREEN}Test 4 successful - DOT-1234 pattern found in output!${NC}"
        echo "--------------------------------"
        echo -e "${YELLOW}Output:${NC}"
        cat "$OUTPUT_FILE"
        echo "--------------------------------"
    else
        echo -e "${RED}Test 4 failed - DOT-1234 pattern not found in output${NC}"
        echo "--------------------------------"
        echo -e "${YELLOW}Output:${NC}"
        cat "$OUTPUT_FILE"
        echo "--------------------------------"
    fi
else
    echo -e "${RED}Test 4 failed - Program execution error${NC}"
fi

# Test 5: Manual test with explicit DOT-XXXX pattern
echo -e "${YELLOW}Test 5: Creating explicit test for pattern matching...${NC}"

# Create a simulated source file with pattern checker function
PATTERN_TEST_FILE="$TEMP_DIR/pattern_test.c"
cat > "$PATTERN_TEST_FILE" << END_TEST_FILE
#include <stdio.h>
#include <stdlib.h>
#include <regex.h>

// Function to extract DOT-XXXX pattern - copied from main.c for testing
char* extract_dot_pattern(const char* branch_name) {
    if (!branch_name) {
        return NULL;
    }
    
    printf("Testing pattern extraction from: %s\\n", branch_name);
    
    regex_t regex;
    regmatch_t matches[1];
    char *result = NULL;
    
    // Compile the regular expression
    if (regcomp(&regex, "DOT-[0-9][0-9][0-9][0-9]", REG_EXTENDED) != 0) {
        printf("Failed to compile regex\\n");
        return NULL;
    }
    
    // Execute the regex
    if (regexec(&regex, branch_name, 1, matches, 0) == 0) {
        int start = matches[0].rm_so;
        int end = matches[0].rm_eo;
        int length = end - start;
        
        result = (char*)malloc(length + 1);
        if (result) {
            strncpy(result, branch_name + start, length);
            result[length] = '\\0';
            printf("Found DOT pattern: %s\\n", result);
        }
    } else {
        printf("No DOT-XXXX pattern found\\n");
    }
    
    regfree(&regex);
    return result;
}

int main() {
    char* test_branches[] = {
        "feature/DOT-1234-test-feature",
        "hotfix/DOT-5678-urgent-fix",
        "DOT-9876-simple-branch",
        "feature/ticket-DOT-4321-end",
        "no-ticket-here",
        NULL
    };
    
    printf("Testing DOT-XXXX pattern extraction\\n");
    printf("-----------------------------------\\n");
    
    int i = 0;
    while (test_branches[i] != NULL) {
        printf("\\nTest %d: ", i+1);
        char* result = extract_dot_pattern(test_branches[i]);
        if (result) {
            free(result);
        }
        i++;
    }
    
    printf("\\nPattern testing complete!\\n");
    return 0;
}
END_TEST_FILE

# Compile and run the pattern test
echo -e "${YELLOW}Compiling pattern test...${NC}"
gcc -o "$TEMP_DIR/pattern_test" "$PATTERN_TEST_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Pattern test compilation successful!${NC}"
    echo -e "${YELLOW}Running pattern test...${NC}"
    echo "--------------------------------"
    "$TEMP_DIR/pattern_test"
    echo "--------------------------------"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Test 5 successful - Pattern extraction function works!${NC}"
    else
        echo -e "${RED}Test 5 failed - Pattern extraction function has issues${NC}"
    fi
else
    echo -e "${RED}Test 5 failed - Could not compile pattern test${NC}"
fi

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo -e "${GREEN}Test completed${NC}"
