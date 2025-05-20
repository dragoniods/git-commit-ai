/**
 * Claude API Client - C Implementation
 *
 * This program connects to Anthropic's Claude API to submit a profile and git diff
 * for analysis, and returns a concise title and description of the changes.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include <cjson/cJSON.h>
#include <unistd.h>
#include <getopt.h>
#include <errno.h>
#include <time.h>
#include <stdarg.h>
#include <pwd.h>

/* Debug mode flag */
int debug_mode = 0;

/* Function declarations */
char* str_duplicate(const char *str);
char* get_default_profile_path(void);
char* get_default_api_key_path(void);
void debug_print(const char *format, ...);
int file_exists(const char* file_path);
char* read_file(const char* file_path);
void trim_string(char *str);
char* read_api_key(const char* file_path);
char* call_claude_api(const char* api_key, const char* profile, const char* git_diff);
int parse_claude_response(const char* response, char** title, char** description);
int save_results_to_file(const char* file_path, const char* title, const char* description);
void display_help(const char* program_name);

// Structure to hold memory buffer for CURL responses
struct MemoryStruct {
    char *memory;
    size_t size;
};

// Callback function for cURL to write received data
static size_t WriteMemoryCallback(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t realsize = size * nmemb;
    struct MemoryStruct *mem = (struct MemoryStruct *)userp;

    char *ptr = realloc(mem->memory, mem->size + realsize + 1);
    if (!ptr) {
        fprintf(stderr, "Error: Not enough memory (realloc returned NULL)\n");
        return 0;
    }

    mem->memory = ptr;
    memcpy(&(mem->memory[mem->size]), contents, realsize);
    mem->size += realsize;
    mem->memory[mem->size] = 0;

    debug_print("Received %zu bytes from API, total size: %zu", realsize, mem->size);

    return realsize;
}

/* Function for string duplication (strdup might not be available in C99) */
char* str_duplicate(const char *str) {
    if (str == NULL) return NULL;

    size_t len = strlen(str) + 1;
    char *dup = malloc(len);
    if (dup != NULL) {
        memcpy(dup, str, len);
    }
    return dup;
}

/* Get home directory */
const char* get_home_dir(void) {
    const char *home_dir;

    // Get home directory
    if ((home_dir = getenv("HOME")) == NULL) {
        struct passwd *pwd = getpwuid(getuid());
        if (pwd == NULL) {
            fprintf(stderr, "Error: Could not determine home directory\n");
            return NULL;
        }
        home_dir = pwd->pw_dir;
    }

    return home_dir;
}

/* Get default profile path */
char* get_default_profile_path(void) {
    const char *home_dir = get_home_dir();
    if (!home_dir) return NULL;

    // Construct the default profile path
    size_t path_len = strlen(home_dir) + strlen("/.config/claude/profile.txt") + 1;
    char *path = malloc(path_len);
    if (path == NULL) {
        fprintf(stderr, "Error: Memory allocation failed for default profile path\n");
        return NULL;
    }

    snprintf(path, path_len, "%s/.config/claude/profile.txt", home_dir);
    return path;
}

/* Get default API key path */
char* get_default_api_key_path(void) {
    const char *home_dir = get_home_dir();
    if (!home_dir) return NULL;

    // Construct the default API key path
    size_t path_len = strlen(home_dir) + strlen("/.config/claude/api_key.txt") + 1;
    char *path = malloc(path_len);
    if (path == NULL) {
        fprintf(stderr, "Error: Memory allocation failed for default API key path\n");
        return NULL;
    }

    snprintf(path, path_len, "%s/.config/claude/api_key.txt", home_dir);
    return path;
}

/* Debug print function */
void debug_print(const char *format, ...) {
    if (debug_mode) {
        va_list args;
        va_start(args, format);
        fprintf(stderr, "[DEBUG] ");
        vfprintf(stderr, format, args);
        fprintf(stderr, "\n");
        va_end(args);
    }
}

// Function to check if a file exists
int file_exists(const char* file_path) {
    return access(file_path, F_OK) == 0;
}

// Function to read file contents into a string
char* read_file(const char* file_path) {
    FILE *file = fopen(file_path, "rb");
    if (!file) {
        fprintf(stderr, "Error: Failed to open file: %s (%s)\n",
                file_path, strerror(errno));
        return NULL;
    }

    debug_print("Opened file: %s", file_path);

    // Get file size
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    debug_print("File size: %ld bytes", file_size);

    // Allocate memory for the file content
    char *buffer = (char*)malloc(file_size + 1);
    if (!buffer) {
        fprintf(stderr, "Error: Memory allocation failed for file content\n");
        fclose(file);
        return NULL;
    }

    // Read file content
    size_t read_size = fread(buffer, 1, file_size, file);
    buffer[read_size] = '\0';  // Null-terminate the string

    if (read_size != (size_t)file_size) {
        fprintf(stderr, "Warning: Read %zu bytes, expected %ld bytes\n",
                read_size, file_size);
    }

    fclose(file);
    return buffer;
}

// Function to trim whitespace from a string
void trim_string(char *str) {
    if (!str) return;

    // Trim leading whitespace
    char *start = str;
    while (*start && (*start == ' ' || *start == '\n' || *start == '\r' || *start == '\t')) {
        start++;
    }

    if (start != str) {
        memmove(str, start, strlen(start) + 1);
    }

    // Trim trailing whitespace
    char *end = str + strlen(str) - 1;
    while (end > str && (*end == ' ' || *end == '\n' || *end == '\r' || *end == '\t')) {
        *end = '\0';
        end--;
    }

    debug_print("Trimmed string to %zu characters", strlen(str));
}

// Function to read API key from file
char* read_api_key(const char* file_path) {
    char *api_key = read_file(file_path);
    if (api_key) {
        trim_string(api_key);
        debug_print("Successfully read API key (length: %zu)", strlen(api_key));
    }
    return api_key;
}

// Function to make a request to Claude API
char* call_claude_api(const char* api_key, const char* profile, const char* git_diff) {
    debug_print("Preparing API request");

    CURL *curl;
    CURLcode res;
    struct MemoryStruct chunk;

    // Initialize memory chunk
    chunk.memory = malloc(1);
    if (!chunk.memory) {
        fprintf(stderr, "Error: Initial memory allocation failed\n");
        return NULL;
    }

    chunk.size = 0;

    // Create payload as JSON
    cJSON *root = cJSON_CreateObject();
    if (!root) {
        fprintf(stderr, "Error: Failed to create JSON object\n");
        free(chunk.memory);
        return NULL;
    }

    cJSON_AddStringToObject(root, "model", "claude-3-7-sonnet-20250219");
    cJSON_AddNumberToObject(root, "max_tokens", 1024);
    cJSON_AddNumberToObject(root, "temperature", 0.5);

    cJSON *messages = cJSON_CreateArray();
    if (!messages) {
        fprintf(stderr, "Error: Failed to create JSON array\n");
        cJSON_Delete(root);
        free(chunk.memory);
        return NULL;
    }

    cJSON *message = cJSON_CreateObject();
    if (!message) {
        fprintf(stderr, "Error: Failed to create JSON message object\n");
        cJSON_Delete(root);
        free(chunk.memory);
        return NULL;
    }

    cJSON_AddStringToObject(message, "role", "user");

    // Construct the content string
    const char *content_template = "Here is my profile:\n\n%s\n\nHere is a git diff that needs review:\n\n%s\n\nPlease provide a concise title and description of the changes.";

    // Calculate the length needed for the content string
    int content_len = snprintf(NULL, 0, content_template, profile, git_diff);
    
    char *content = malloc(content_len + 1);
    if (!content) {
        fprintf(stderr, "Error: Memory allocation failed for content string\n");
        cJSON_Delete(root);
        free(chunk.memory);
        return NULL;
    }

    // Format the content string
    snprintf(content, content_len + 1, content_template, profile, git_diff);
    debug_print("Content length: %d bytes", content_len);

    cJSON_AddStringToObject(message, "content", content);
    cJSON_AddItemToArray(messages, message);
    cJSON_AddItemToObject(root, "messages", messages);

    char *json_string = cJSON_Print(root);
    if (!json_string) {
        fprintf(stderr, "Error: Failed to convert JSON to string\n");
        free(content);
        cJSON_Delete(root);
        free(chunk.memory);
        return NULL;
    }

    free(content);

    debug_print("JSON request payload created (length: %zu)", strlen(json_string));

    // Initialize cURL
    curl_global_init(CURL_GLOBAL_ALL);
    curl = curl_easy_init();

    char *response = NULL;

    if (curl) {
        debug_print("cURL initialized");

        // Set cURL options
        curl_easy_setopt(curl, CURLOPT_URL, "https://api.anthropic.com/v1/messages");

        // Set HTTP headers
        struct curl_slist *headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/json");

        char auth_header[512];
        snprintf(auth_header, sizeof(auth_header), "x-api-key: %s", api_key);
        headers = curl_slist_append(headers, auth_header);
        headers = curl_slist_append(headers, "anthropic-version: 2023-06-01");

        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        // Set request data
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_string);

        // Set write function
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&chunk);

        // Set timeouts
        curl_easy_setopt(curl, CURLOPT_TIMEOUT, 120); // 2 minute timeout
        curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10); // 10 seconds to connect

        // Enable verbose output in debug mode
        if (debug_mode) {
            curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);
        }

        debug_print("Sending API request...");

        // Remember the request time
        time_t request_start = time(NULL);

        // Perform the request
        res = curl_easy_perform(curl);

        // Calculate request duration
        time_t request_end = time(NULL);
        debug_print("API request completed in %ld seconds", (long)(request_end - request_start));

        // Check for errors
        if (res != CURLE_OK) {
            fprintf(stderr, "Error: cURL request failed: %s\n", curl_easy_strerror(res));
        } else {
            // Get HTTP response code
            long http_code = 0;
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
            debug_print("HTTP response code: %ld", http_code);

            if (http_code >= 200 && http_code < 300) {
                response = str_duplicate(chunk.memory);
                debug_print("API response received (length: %zu)", chunk.size);
            } else {
                fprintf(stderr, "Error: API request failed with HTTP code %ld\n", http_code);
                fprintf(stderr, "Response: %s\n", chunk.memory);
            }
        }

        // Clean up
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
    } else {
        fprintf(stderr, "Error: Failed to initialize cURL\n");
    }

    curl_global_cleanup();
    free(json_string);
    cJSON_Delete(root);
    free(chunk.memory);

    return response;
}

// Function to parse Claude's response
int parse_claude_response(const char* response, char** title, char** description) {
    debug_print("Parsing API response");

    if (!response || !title || !description) {
        fprintf(stderr, "Error: Invalid parameters for response parsing\n");
        return 0;
    }

    // Initialize output parameters
    *title = NULL;
    *description = NULL;

    cJSON *root = cJSON_Parse(response);
    if (!root) {
        const char *error_ptr = cJSON_GetErrorPtr();
        if (error_ptr) {
            fprintf(stderr, "Error: JSON parsing failed near: %s\n", error_ptr);
        } else {
            fprintf(stderr, "Error: JSON parsing failed\n");
        }
        return 0;
    }

    cJSON *content = cJSON_GetObjectItem(root, "content");
    if (!content || !cJSON_IsArray(content)) {
        fprintf(stderr, "Error: Invalid response format (content field not found or not an array)\n");
        cJSON_Delete(root);
        return 0;
    }

    cJSON *first_content = cJSON_GetArrayItem(content, 0);
    if (!first_content) {
        fprintf(stderr, "Error: Content array is empty\n");
        cJSON_Delete(root);
        return 0;
    }

    cJSON *text = cJSON_GetObjectItem(first_content, "text");
    if (!text || !cJSON_IsString(text)) {
        fprintf(stderr, "Error: Text field not found or not a string\n");
        cJSON_Delete(root);
        return 0;
    }

    // Parse the text to extract title and description
    char *text_value = text->valuestring;
    if (!text_value) {
        fprintf(stderr, "Error: Text value is NULL\n");
        cJSON_Delete(root);
        return 0;
    }

    debug_print("Response text length: %zu bytes", strlen(text_value));

    char *line_start = text_value;
    char *line_end = NULL;

    // Skip empty lines at the beginning
    while (*line_start && (*line_start == '\n' || *line_start == '\r')) {
        line_start++;
    }

    // Find the end of the first non-empty line (title)
    line_end = strchr(line_start, '\n');
    if (line_end) {
        *title = (char*)malloc(line_end - line_start + 1);
        if (!*title) {
            fprintf(stderr, "Error: Memory allocation failed for title\n");
            cJSON_Delete(root);
            return 0;
        }
        strncpy(*title, line_start, line_end - line_start);
        (*title)[line_end - line_start] = '\0';

        debug_print("Title extracted: \"%s\"", *title);

        // Description is everything after the title
        size_t desc_len = strlen(text_value) - (line_end - text_value) + 1;
        *description = (char*)malloc(desc_len);
        if (!*description) {
            fprintf(stderr, "Error: Memory allocation failed for description\n");
            free(*title);
            *title = NULL;
            cJSON_Delete(root);
            return 0;
        }
        strncpy(*description, line_end + 1, desc_len - 1);
        (*description)[desc_len - 1] = '\0';

        debug_print("Description extracted (length: %zu)", strlen(*description));
    } else {
        // Just one line in the response
        debug_print("No newline found, using entire response as title");
        *title = str_duplicate(line_start);
        *description = str_duplicate("");
    }

    cJSON_Delete(root);
    return 1;
}

// Function to save results to file
int save_results_to_file(const char* file_path, const char* title, const char* description) {
    if (!file_path || !title || !description) {
        fprintf(stderr, "Error: Invalid parameters for saving results\n");
        return 0;
    }

    FILE *file = fopen(file_path, "w");
    if (!file) {
        fprintf(stderr, "Error: Failed to open output file: %s (%s)\n",
                file_path, strerror(errno));
        return 0;
    }

    fprintf(file, "# %s\n\n%s", title, description);
    fclose(file);

    printf("Results saved to: %s\n", file_path);
    return 1;
}

// Function to display the help message
void display_help(const char* program_name) {
    printf("Claude API Client for Git Diff Analysis\n");
    printf("\nUsage: %s [options] [git_diff]\n", program_name);
    printf("\nOptions:\n");
    printf("  -h                Display this help message\n");
    printf("  -k <file>         Path to file containing the API key\n");
    printf("                    (default: ~/.config/claude/api_key.txt)\n");
    printf("  -p <file>         Path to profile file\n");
    printf("                    (default: ~/.config/claude/profile.txt)\n");
    printf("  -d <file>         Read git diff from a file instead of command line\n");
    printf("  -o <file>         Save results to the specified file\n");
    printf("  -v                Enable verbose/debug output\n");
    printf("\nExamples:\n");
    printf("  %s \"$(git diff)\"                            # Use defaults\n", program_name);
    printf("  %s -k custom_key.txt \"$(git diff)\"         # Custom API key\n", program_name);
    printf("  %s -p my_profile.txt \"$(git diff)\"         # Custom profile\n", program_name);
    printf("  %s -d changes.diff                         # Read diff from file\n", program_name);
    printf("  %s -o commit_message.md \"$(git diff)\"      # Save to file\n", program_name);
    printf("\nSee README.md for more information.\n");
}

int main(int argc, char* argv[]) {
    // Default values
    char *key_file_path = NULL;
    char *profile_path = NULL;
    char *git_diff = NULL;
    char *git_diff_file_path = NULL;
    char *output_file_path = NULL;
    int use_diff_file = 0;
    int use_default_key = 1;  // Default to using the default API key
    int use_default_profile = 1;  // Default to using the default profile

    // Parse command line arguments
    int opt;
    while ((opt = getopt(argc, argv, "hk:p:d:o:v")) != -1) {
        switch (opt) {
            case 'h':
                display_help(argv[0]);
                return 0;
            case 'k':
                key_file_path = optarg;
                use_default_key = 0;  // Don't use default key if -k is specified
                break;
            case 'p':
                profile_path = optarg;
                use_default_profile = 0;  // Don't use default profile if -p is specified
                break;
            case 'd':
                git_diff_file_path = optarg;
                use_diff_file = 1;
                break;
            case 'o':
                output_file_path = optarg;
                break;
            case 'v':
                debug_mode = 1;
                break;
            default:
                fprintf(stderr, "Unknown option: %c\n", opt);
                display_help(argv[0]);
                return 1;
        }
    }

    if (debug_mode) {
        debug_print("Debug mode enabled");
    }

    // Get non-option arguments (git diff)
    if (optind < argc && !use_diff_file) {
        git_diff = argv[optind];
    }

    // If no key file path specified, use default
    if (use_default_key) {
        key_file_path = get_default_api_key_path();
        if (!key_file_path) {
            fprintf(stderr, "Error: Failed to determine default API key path\n");
            return 1;
        }

        debug_print("Using default API key from: %s", key_file_path);
    }

    // Check if the key file exists
    if (!file_exists(key_file_path)) {
        fprintf(stderr, "Error: API key file not found at %s\n", key_file_path);
        fprintf(stderr, "Create it first or specify a key file with -k option\n");
        if (use_default_key) {
            free(key_file_path);
        }
        return 1;
    }

    // If no profile path specified, use default
    if (use_default_profile) {
        profile_path = get_default_profile_path();
        if (!profile_path) {
            fprintf(stderr, "Error: Failed to determine default profile path\n");
            if (use_default_key) {
                free(key_file_path);
            }
            return 1;
        }

        debug_print("Using default profile from: %s", profile_path);
    }

    // Check if the profile file exists
    if (!file_exists(profile_path)) {
        fprintf(stderr, "Error: Profile file not found at %s\n", profile_path);
        fprintf(stderr, "Create it first or specify a profile with -p option\n");
        if (use_default_key) {
            free(key_file_path);
        }
        if (use_default_profile) {
            free(profile_path);
        }
        return 1;
    }

    // Git diff is required
    if (!git_diff && !use_diff_file) {
        fprintf(stderr, "Error: Git diff is required (either as an argument or via -d option)\n");
        display_help(argv[0]);
        if (use_default_key) {
            free(key_file_path);
        }
        if (use_default_profile) {
            free(profile_path);
        }
        return 1;
    }

    // Read API key from file
    char *api_key = read_api_key(key_file_path);
    if (!api_key) {
        if (use_default_key) {
            free(key_file_path);
        }
        if (use_default_profile) {
            free(profile_path);
        }
        return 1;
    }

    // Read profile from file
    char *profile = read_file(profile_path);
    if (!profile) {
        free(api_key);
        if (use_default_key) {
            free(key_file_path);
        }
        if (use_default_profile) {
            free(profile_path);
        }
        return 1;
    }

    // Read git diff from file if specified
    char *git_diff_content = NULL;
    if (use_diff_file) {
        git_diff_content = read_file(git_diff_file_path);
        if (!git_diff_content) {
            free(api_key);
            free(profile);
            if (use_default_key) {
                free(key_file_path);
            }
            if (use_default_profile) {
                free(profile_path);
            }
            return 1;
        }
    } else {
        git_diff_content = str_duplicate(git_diff);
        if (!git_diff_content) {
            fprintf(stderr, "Error: Memory allocation failed for git diff content\n");
            free(api_key);
            free(profile);
            if (use_default_key) {
                free(key_file_path);
            }
            if (use_default_profile) {
                free(profile_path);
            }
            return 1;
        }
    }

    // Free paths if they were allocated
    if (use_default_key) {
        free(key_file_path);
    }
    if (use_default_profile) {
        free(profile_path);
    }

    // Call Claude API
    printf("Sending request to Anthropic API...\n");
    char *response = call_claude_api(api_key, profile, git_diff_content);
    if (!response) {
        fprintf(stderr, "Failed to get response from Claude API\n");
        free(api_key);
        free(profile);
        free(git_diff_content);
        return 1;
    }

    // Parse response
    char *title = NULL;
    char *description = NULL;
    if (parse_claude_response(response, &title, &description)) {
        // Output result
        printf("TITLE: %s\n\n", title);
        printf("DESCRIPTION:\n%s\n", description);

        // Save to file if requested
        if (output_file_path) {
            save_results_to_file(output_file_path, title, description);
        }

        free(title);
        free(description);
    } else {
        fprintf(stderr, "Failed to parse Claude's response\n");
    }

    // Clean up
    free(api_key);
    free(profile);
    free(git_diff_content);
    free(response);

    return 0;
}
