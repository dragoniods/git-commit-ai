# API Key Setup Guide

## Creating and Securing Your Anthropic API Key File

1. First, sign up for an Anthropic API key at https://console.anthropic.com/ if you haven't already.

2. Create a text file to store your key:
   ```bash
   touch api_key.txt
   ```

3. Set restrictive permissions to protect the key file:
   ```bash
   chmod 600 api_key.txt
   ```

4. Open the file in a text editor and paste your API key:
   ```bash
   nano api_key.txt
   ```

5. Add your Anthropic API key in the following format:
   ```
   sk-ant-api03-youractualapikeyhere
   ```

6. Save the file (Ctrl+O, then Enter in nano, followed by Ctrl+X to exit).

## Security Best Practices

- Never commit your API key file to version control
- Consider storing the key in a secure location like:
  - `~/.config/claude/api_key.txt`
  - `~/.ssh/claude_api_key.txt`
- If using the tool in scripts, use absolute paths to the key file
- Regularly rotate your API keys according to your security policies
- Set up a `.gitignore` rule to prevent accidentally committing the key file

## Using the API Key with Claude API Client

```bash
./claude_api_client -k /path/to/your/api_key.txt profile.txt "$(git diff)"
```

## Troubleshooting

If you encounter "Unauthorized" errors:
1. Double-check that your API key is valid and active
2. Ensure there are no extra spaces or newlines in the key file
3. Run with the `-v` flag for verbose logging
4. Verify you can access the Anthropic API from your network

Remember that API keys are sensitive credentials - treat them like passwords!
