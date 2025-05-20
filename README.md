# Git Commit AI

A C program that connects to Anthropic's Claude API to analyze git diffs using your developer profile, providing concise titles and descriptions for changes.

## Features

- Submit git diffs directly from the command line
- Automatically detect ticket numbers (e.g., DOT-1234) from branch names
- Use default API key and profile locations for ease of use
- Save analysis results to a file in Markdown format
- Debug mode for troubleshooting
- Robust error handling
- Simple command-line interface with helpful options

## Requirements

- C99-compatible compiler (gcc, clang)
- libcurl for HTTP requests
- cJSON for JSON parsing
- regex.h support
- POSIX-compatible system (Linux, macOS, etc.)

## Installation

### Dependencies

#### On Debian/Ubuntu:

```bash
sudo apt-get install build-essential libcurl4-openssl-dev libcjson-dev
```

#### On macOS with Homebrew:

```bash
brew install curl cjson
```

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/git-commit-ai.git
   cd git-commit-ai
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```
   
   The script will:
   - Build the application
   - Offer to install it system-wide or for the current user
   - Set up the necessary configuration directories
   - Create default API key and profile files
   - Optionally set up a git alias for easy use

## Usage

```
Usage: git-commit-ai [options] [git_diff]

Options:
  -h                Display this help message
  -k <file>         Path to file containing the API key
                    (default: ~/.config/claude/api_key.txt)
  -p <file>         Path to profile file
                    (default: ~/.config/claude/profile.txt)
  -d <file>         Read git diff from a file instead of command line
  -o <file>         Save results to the specified file
  -v                Enable verbose/debug output

Examples:
  git-commit-ai "$(git diff)"                      # Use defaults
  git-commit-ai -k custom_key.txt "$(git diff)"    # Custom API key
  git-commit-ai -p my_profile.txt "$(git diff)"    # Custom profile
  git-commit-ai -d changes.diff                    # Read diff from file
  git-commit-ai -o commit_message.md "$(git diff)" # Save to file
```

### Ticket Number Detection

The program automatically detects ticket numbers in your branch name that match the pattern DOT-XXXX (where XXXX is a 4-digit number) and includes them in the commit message. For example:

- If your branch is named `feature/DOT-1234-add-new-feature`, the program will extract `DOT-1234`
- If your branch is named `hotfix/DOT-5678-fix-critical-bug`, the program will extract `DOT-5678`

This happens automatically without any additional configuration.

### Default File Locations

The program automatically looks for:
- API key at `~/.config/claude/api_key.txt`
- Profile at `~/.config/claude/profile.txt`

You only need to specify these files with `-k` or `-p` if you want to override the defaults.

### File Output

To save the analysis results to a file, use the `-o` option:

```bash
git-commit-ai -o commit_message.md "$(git diff)"
```

The output file will be in Markdown format with the title as a heading and the description as normal text.

### Debug Mode

For troubleshooting or to see more detailed information, use the `-v` option:

```bash
git-commit-ai -v "$(git diff)"
```

This will print detailed debug information to stderr.

## API Key Setup

If you haven't set up your API key during installation:

1. Create the configuration directory and API key file:
   ```bash
   mkdir -p ~/.config/claude
   chmod 700 ~/.config/claude
   echo "your-anthropic-api-key" > ~/.config/claude/api_key.txt
   chmod 600 ~/.config/claude/api_key.txt
   ```

## Profile File

Your developer profile provides context for the AI. The default profile is created during installation, but you can edit it at `~/.config/claude/profile.txt`.

Example profile:
```
I am a C/C++ developer with 5 years of experience.
My expertise includes:
- Systems programming
- Network protocols
- Performance optimization
- Real-time systems
```

## Git Integration

If you've set up git integration during installation, you can generate commit messages with:

```bash
git claude-commit
```

This will analyze your changes and save the result to `commit_msg.md` in the current directory.

You can also manually set up the git alias:
```bash
git config --global alias.claude-commit '!git diff | git-commit-ai -o commit_msg.md'
```

When you use this command:
1. The program will extract the current git diff
2. Detect any ticket numbers (DOT-XXXX) in your current branch name
3. Send both to Claude for analysis
4. Save the resulting commit message with the ticket reference to commit_msg.md

## Error Handling

The application includes comprehensive error handling for:
- File I/O errors (with detailed error messages)
- Memory allocation failures
- Network request failures (with timeout handling)
- JSON parsing errors
- API response validation
- Regex pattern matching failures

## Development

### Building in Debug Mode

To build with debug symbols and additional runtime checks:

```bash
make debug
```

### Running Tests

To run the basic functionality tests:

```bash
./test_claude_client.sh ~/.config/claude/api_key.txt
```

The test script includes specific tests for the DOT-XXXX pattern detection feature.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Anthropic for the Claude API
- Dave Gamble for the cJSON library
