# auto-brevent-starter.sh

A script that leverages Termux:Boot to automatically start the Brevent server via Shizuku on device startup.

## How It Works

This script is designed for `Termux:Boot` to ensure the Brevent service is running after a reboot. Here is the workflow:

1.  After the device boots, the `Termux:Boot` app automatically executes this script.
2.  The script waits until the Shizuku service is fully initialized and available.
3.  Once Shizuku is ready, the script uses Shizuku's command-line interface, `rish`, to execute Brevent's server startup script (`brevent.sh`) with `adb`-equivalent privileges.
4.  The entire process is logged, making it easy to trace and troubleshoot any issues.

## How to Use

Follow these steps to set up and install the script.

### 1. Prerequisites

Ensure you have the following applications installed and properly configured:

*   **[Brevent](https://play.google.com/store/apps/details?id=me.piebridge.brevent)**
*   **[Shizuku](https://github.com/RikkaApps/Shizuku)**
*   **[Termux](https://github.com/termux/termux-app)** (Recommended from F-Droid)
*   **[Termux:Boot](https://github.com/termux/termux-boot)** (Available on F-Droid)

**Note**: Make sure these apps are working correctly before proceeding (e.g., Shizuku is running and Brevent has been activated).

### 2. Configure Shizuku (rish)

The script depends on the `rish` command to communicate with Shizuku. You need to place the `rish` executable in the path expected by the script.

1.  Open the Shizuku app, go to the "Use Shizuku in terminal apps" section, and follow the instructions to export files.
2.  Return to Termux and run the following commands to create the necessary directory and copy `rish` to the expected location:

    ```bash
    # First, ensure 'rish' is accessible in Termux.
    # If 'which rish' finds nothing, complete the setup in the Shizuku app first.
    if ! command -v rish &> /dev/null; then
        echo "Error: 'rish' command not found in Termux."
        echo "Please follow the guide in the Shizuku app first, then re-run this."
        return
    fi

    # Create the local bin directory and copy rish into it.
    mkdir -p "$HOME/.local/bin"
    cp "$(which rish)" "$HOME/.local/bin/rish"
    ```

### 3. Install the Script

The script must be placed in Termux's `boot` directory to run automatically on startup.

Run the following commands to create the directory and download the script:

```bash
# Create the Termux boot directory if it doesn't exist
mkdir -p "$HOME/.termux/boot/"

# Download the script file from GitHub into that directory
# (We use curl for a single file, as 'git clone' would download the whole repository)
curl -L "https://raw.githubusercontent.com/myuverr/auto-brevent-starter.sh/main/auto-brevent-starter.sh" -o "$HOME/.termux/boot/auto-brevent-starter.sh"

# Grant the script execute permissions
chmod +x "$HOME/.termux/boot/auto-brevent-starter.sh"
```

### 4. Reboot

After completing all the steps above, reboot your device.

`Termux:Boot` will launch the script automatically, which will then start the Brevent service.

## Logging & Troubleshooting

Every step of the script's execution is logged. If you encounter any problems, you can check the log file for details.

Log file location: `~/.local/state/auto_brevent/script.log`

Use this command to view the log:
```bash
cat ~/.local/state/auto_brevent/script.log
```

## License

This project is licensed under the [WTFPL](LICENSE).
