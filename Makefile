# NAME is the "fully qualified" name, should be in "reverse dns" format eg.
# com.apple.itunes
NAME ?= io.maxj.lidwatcherd

# BIN_DIR is the directory to place the binary.
BIN_DIR ?= $(HOME)/.bin

# LOG_DIR is the directory to place logs. Should be unique, not already exist.
LOG_DIR ?= $(HOME)/Library/Logs/$(NAME)

# DATA_DIR is the directory used for persistent data. Should be unique, not
# already exist.
DATA_DIR ?= $(HOME)/Library/Application Support/$(NAME)

# CHECK_INTERVAL is the time interval in seconds between checks of the lid
# state.
CHECK_INTERVAL ?= 10

# Other variables
SHORTNAME = $(patsubst .%,%,$(suffix $(NAME)))
BIN_PATH = $(BIN_DIR)/$(SHORTNAME)
LOG_PATH = $(LOG_DIR)/log.txt
LAUNCHAGENT_PATH = $(HOME)/Library/LaunchAgents/$(NAME).plist

# Export vars used by template.plist
export NAME
export BIN_PATH
export LOG_PATH
export DATA_DIR
export CHECK_INTERVAL

build:
	TARGET_BUILD_DIR=$(PWD)/build xcodebuild -project lidwatcherd.xcodeproj

.PHONY: install
install: build
	mkdir "$(LOG_DIR)"
	mkdir "$(DATA_DIR)"
	mkdir -v -p "$(BIN_DIR)"
	cp -n build/Release/lidwatcherd "$(BIN_PATH)"
	eval "echo \"$$(< template.plist)\"" > "$(LAUNCHAGENT_PATH)"
	launchctl load "$(LAUNCHAGENT_PATH)"

.PHONY: uninstall
uninstall:
	launchctl unload "$(LAUNCHAGENT_PATH)"
	rm -f "$(LAUNCHAGENT_PATH)"
	rm -f "$(BIN_PATH)"
	rm -vrf "$(DATA_DIR)"
	rm -vrf "$(LOG_DIR)"


.PHONY: clean
clean:
	rm -rf ./build
