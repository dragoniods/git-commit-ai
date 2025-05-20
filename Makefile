CC = gcc
CFLAGS = -std=c99 -Wall -Wextra -pedantic -D_POSIX_C_SOURCE=200809L
LDFLAGS = -lcurl -lcjson

TARGET = git-commit-ai
SRCS = main.c
OBJS = $(SRCS:.c=.o)

# Debug build settings
DEBUG_DIR = debug
DEBUG_TARGET = $(DEBUG_DIR)/$(TARGET)
DEBUG_OBJS = $(addprefix $(DEBUG_DIR)/, $(notdir $(OBJS)))
DEBUG_CFLAGS = $(CFLAGS) -g -O0 -DDEBUG

# Release build settings
RELEASE_DIR = release
RELEASE_TARGET = $(RELEASE_DIR)/$(TARGET)
RELEASE_OBJS = $(addprefix $(RELEASE_DIR)/, $(notdir $(OBJS)))
RELEASE_CFLAGS = $(CFLAGS) -O3 -DNDEBUG

.PHONY: all clean debug release install

# Default build is release
all: release
	@echo "Creating symbolic link to release version"
	@ln -sf $(RELEASE_TARGET) $(TARGET)

debug: $(DEBUG_TARGET)
	@echo "Creating symbolic link to debug version"
	@ln -sf $(DEBUG_TARGET) $(TARGET)

release: $(RELEASE_TARGET)

# Debug rules
$(DEBUG_TARGET): $(DEBUG_OBJS)
	@mkdir -p $(DEBUG_DIR)
	$(CC) $(DEBUG_OBJS) -o $(DEBUG_TARGET) $(LDFLAGS)

$(DEBUG_DIR)/%.o: %.c
	@mkdir -p $(DEBUG_DIR)
	$(CC) $(DEBUG_CFLAGS) -c $< -o $@

# Release rules
$(RELEASE_TARGET): $(RELEASE_OBJS)
	@mkdir -p $(RELEASE_DIR)
	$(CC) $(RELEASE_OBJS) -o $(RELEASE_TARGET) $(LDFLAGS)

$(RELEASE_DIR)/%.o: %.c
	@mkdir -p $(RELEASE_DIR)
	$(CC) $(RELEASE_CFLAGS) -c $< -o $@

install: release
	install -m 755 $(RELEASE_TARGET) /usr/local/bin/$(TARGET)

clean:
	rm -rf $(DEBUG_DIR) $(RELEASE_DIR) $(TARGET)
