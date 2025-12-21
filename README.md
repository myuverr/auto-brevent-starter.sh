# auto-brevent-starter.sh

A robust script that leverages Termux:Boot to automatically start the Brevent server via Shizuku on device startup.

## Features

*   **Reliable Startup**: Intelligently waits for Shizuku to be ready before attempting to launch Brevent.
*   **Safe Timeouts**: Prevents the script from waiting indefinitely. It will exit gracefully if Shizuku or Brevent fail to start in a timely manner.
*   **Detailed Logging**: Every action is logged to a file, making troubleshooting simple.
*   **Customizable**: Easily change timeout durations or the path to your `rish` executable.
*   **Instance Locking**: Prevents multiple instances of the script from running simultaneously.

## How It Works

The script follows a simple, automated workflow when your device boots up:

1.  **Boot Trigger**: `Termux:Boot` automatically executes the script.
2.  **Wait for Shizuku**: The script polls for the Shizuku service, waiting until it's fully initialized and ready to accept commands.
3.  **Launch Brevent**: Once Shizuku is active, the script uses `rish` (Shizuku's command-line interface) to start the Brevent server.
4.  **Confirm & Exit**: The script monitors for a success message from Brevent and then exits.

---

## Installation and Setup Guide

Follow these steps carefully to get the script running.

### Step 1: Prerequisites

First, ensure you have the following applications installed and properly configured on your device:

*   **[Brevent](https://play.google.com/store/apps/details?id=me.piebridge.brevent)**
*   **[Shizuku](https://github.com/RikkaApps/Shizuku)** (Official) or **[Shizuku (thedjchi fork)](https://github.com/thedjchi/Shizuku)** (**Recommended**)
    *   *Why the fork?* It includes a more robust "start on boot" feature that waits for a Wi-Fi connection before starting. Combined with this script, it provides a more seamless automated experience.
*   **[Termux](https://github.com/termux/termux-app)** ([F-Droid](https://f-droid.org/packages/com.termux/))
*   **[Termux:Boot](https://github.com/termux/termux-boot)** ([F-Droid](https://f-droid.org/packages/com.termux.boot/))

> **Warning**: Make sure these apps are installed and working correctly before proceeding.

### Step 2: Configure Shizuku (`rish`)

This script needs to use `rish`, the tool that lets Termux talk to Shizuku.

1.  **Export `rish` Files**:
    *   In the Shizuku app, go to the **Use Shizuku in terminal apps** section.
    *   Tap **Export files**. When the system file picker appears:
        *   Open the sidebar (usually a hamburger menu on the top left).
        *   Select **Termux** from the list.
        *   Confirm the selection (e.g., tap "Use this folder"). This will copy `rish` and `rish_shizuku.dex` to your Termux home directory (`$HOME`).

2.  **Move and Configure `rish`**:
    Run the following commands in Termux to move the files to a standard location and configure them for use with Termux.

    ```bash
    # Create the target directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"

    # Move the files
    mv "$HOME/rish" "$HOME/.local/bin/rish"
    mv "$HOME/rish_shizuku.dex" "$HOME/.local/bin/rish_shizuku.dex"

    # IMPORTANT: Set the Application ID for Termux
    # This command replaces the 'PKG' placeholder inside the rish script with Termux's package name.
    sed -i 's/PKG/com.termux/' "$HOME/.local/bin/rish"

    echo "rish setup complete."
    ```

3.  **(Recommended) Add to PATH**:
    To make it easier to run `rish` manually, add it to your shell's `PATH`.

    ```bash
    # Add the local bin directory to your .bashrc file
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

    # Apply the changes to your current session
    source ~/.bashrc
    ```
    *(If you use a different shell, please add the local bin directory to your PATH according to your shell's configuration method.)*
### Step 3: Install the Script

Place the script in the `Termux:Boot` startup directory.

```bash
# Create the Termux boot directory if it doesn't exist
mkdir -p "$HOME/.termux/boot/"

# Download the script from GitHub into that directory
curl -L "https://raw.githubusercontent.com/myuverr/auto-brevent-starter.sh/main/auto-brevent-starter.sh" -o "$HOME/.termux/boot/auto-brevent-starter.sh"

# Grant the script execute permissions
chmod +x "$HOME/.termux/boot/auto-brevent-starter.sh"

echo "Script installed successfully!"
```

### Step 4: Reboot!

That's it! Reboot your device. `Termux:Boot` will run the script, which will wait for Shizuku and then start Brevent.

> **Manual Activation**: You can manually run the script at any time to start the Brevent service without rebooting. This is useful if the service stops for any reason.
> `~/.termux/boot/auto-brevent-starter.sh`

---

## Customization

You can easily tweak the script's behavior by editing the constants at the top of the file.
Open the script with a text editor (e.g., `nvim` or any other text editor you prefer): `nvim ~/.termux/boot/auto-brevent-starter.sh`

Here are the most common variables to change:

*   **`RISH_PATH`**: Change this if your `rish` executable is not in the default location.
    ```sh
    # Default:
    readonly RISH_PATH="$HOME/.local/bin/rish"
    ```
*   **`SHIZUKU_WAIT_TIMEOUT_MINUTES`**: How long the script waits for Shizuku (in minutes).
    ```sh
    # Default: 5 minutes
    readonly SHIZUKU_WAIT_TIMEOUT_MINUTES=5
    ```
*   **`BREVENT_LAUNCH_TIMEOUT_SECONDS`**: How long the script waits for Brevent to confirm its launch (in seconds).
    ```sh
    # Default: 60 seconds
    readonly BREVENT_LAUNCH_TIMEOUT_SECONDS=60
    ```

## Logging & Troubleshooting

If something goes wrong, the log file is the first place to look.

*   **Log File Location**: `~/.local/state/auto_brevent/script.log`
*   **View the Log**:
    ```bash
    cat ~/.local/state/auto_brevent/script.log
    ```
*   **View the Log in Real-time**:
    ```bash
    tail -f ~/.local/state/auto_brevent/script.log
    ```

## License

This project is licensed under the [WTFPL](LICENSE).