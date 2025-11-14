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
*   **[Termux](https://github.com/termux/termux-app)** ([F-Droid](https://f-droid.org/packages/com.termux/))
*   **[Termux:Boot](https://github.com/termux/termux-boot)** ([F-Droid](https://f-droid.org/packages/com.termux.boot/))

**Note**: Make sure these apps are installed and configured correctly before proceeding.

### 2. Configure Shizuku (rish)

This script requires the `rish` and `rish_shizuku.dex` files to be placed in the `$HOME/.local/bin/` directory.

1.  **Export Files from Shizuku:**
    In the Shizuku app, navigate to the "Use Shizuku in terminal apps" section and select "Export files". This will place the `rish` and `rish_shizuku.dex` files into your Termux home directory (`$HOME`).

2.  **Move Files to the Local Bin Directory:**
    Once the files are in your home directory, run the following commands in Termux to move them to the location this script expects.
    ```bash
    # Create the target directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"

    # Move the files from your home directory
    mv "$HOME/rish" "$HOME/.local/bin/rish"
    mv "$HOME/rish_shizuku.dex" "$HOME/.local/bin/rish_shizuku.dex"

    echo "Successfully moved rish and rish_shizuku.dex."
    ```

3.  **Set the Application ID:**
    You must edit the `rish` script to tell Shizuku which application is using it.

    Open the script in a text editor like `nano`:
    ```bash
    nano ~/.local/bin/rish
    ```
    Find the line that sets `RISH_APPLICATION_ID` (it might be commented out or set to a different value) and change it to:
    ```sh
    export RISH_APPLICATION_ID="com.termux"
    ```
    Save the file and exit (in `nano`, press `Ctrl+X`, then `Y`, then `Enter`). This step is crucial for `rish` to work correctly from within Termux.

4.  **(Recommended) Add Local Bin to PATH:**
    To easily run `rish` and other local scripts from any directory, it's good practice to add `$HOME/.local/bin` to your shell's `PATH`.

    For `bash` (the default Termux shell), you can do this by adding the following line to your `~/.bashrc` file:
    ```bash
    # Add the local bin directory to the PATH
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

    # Apply the changes to your current session
    source ~/.bashrc
    ```
    For other shells like `zsh`, you would add the export line to `~/.zshrc` instead.

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

**Manual Execution**: You can also manually execute the script from Termux at any time by running `~/.termux/boot/auto-brevent-starter.sh`. This is useful for testing or if you need to restart Brevent without rebooting.

## Logging & Troubleshooting

Every step of the script's execution is logged. If you encounter any problems, you can check the log file for details.

Log file location: `~/.local/state/auto_brevent/script.log`

Use this command to view the log:
```bash
cat ~/.local/state/auto_brevent/script.log
```

## License

This project is licensed under the [WTFPL](LICENSE).
