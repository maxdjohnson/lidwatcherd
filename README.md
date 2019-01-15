# lidwatcherd

`lidwatcherd` is a utility for Mac OSX that shuts off bluetooth when the macbook lid is closed, and turns it back on when the lid is reopened.

**Motivation:** When I shut my macbook, I'd like my headphones to switch to my phone. Unfortunately, since the bluetooth on the macbook stays on, the headphones often don't switch over. It makes no sense to have bluetooth on while the lid is closed, so I wrote this tool.

**Features:**

  * If power and an external display is connected, `lidwatcherd` will not consider the lid closed.
  * When the lid is reopened, `lidwatcherd` will attempt to reconnect bluetooth devices that were connected before the lid was closed.

## Installation

```
git clone https://github.com/maxdjohnson/lidwatcherd.git
cd lidwatcherd
make install
```

By default, this installs the binary to `~/.bin/lidwatcherd` and the launchagent to `~/Library/LaunchAgents/io.maxj.lidwatcherd.plist`.

The name, paths, and check interval can be configured by passing environment variables to `make install`. Check `Makefile` for details.

### Uninstall

```
make uninstall
```

## Design

This project leverages `launchd` to periodically run the `lidwatcherd` binary. It is run every 10s by default.

The lid state is read from the `IORegistry` in the `IOKit` framework. Open/Close actions are determined by checking the current lid state against the last lid state. The lid state (and previously-connected bluetooth devices) is persisted in a JSON file between runs.

Bluetooth connections are controlled using the `IOBluetooth` framework. The function that enables & disables bluetooth is not public, so it's defined in the bridging header. Updates to OSX may break this.