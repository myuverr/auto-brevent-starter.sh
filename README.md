# auto-brevent-starter.sh

Start the Brevent server automatically at boot using Termux:Boot and Shizuku.

## Requirements

- [Brevent](https://play.google.com/store/apps/details?id=me.piebridge.brevent), with its setup completed.
- [Shizuku](https://github.com/RikkaApps/Shizuku) or the [thedjchi fork](https://github.com/thedjchi/Shizuku), which supports waiting for Wi-Fi before starting on boot.
- [Termux](https://f-droid.org/packages/com.termux/) and [Termux:Boot](https://f-droid.org/packages/com.termux.boot/), installed from the same source.

Open Termux:Boot once after installation to enable it to run at boot.

**Shizuku must start separately.** This script waits for Shizuku; it does not start it. Configure Shizuku's boot startup if you want the entire process to be automatic.

## Setup

Run the following commands in Termux.

### 1. Configure rish

In Shizuku, open **Use Shizuku in terminal apps** and export `rish` and `rish_shizuku.dex` to your Termux home directory (`$HOME`). Select **Termux** in the file picker's sidebar to access that directory.

Move the files and set the application ID for Termux:

```sh
mkdir -p "$HOME/.local/bin"
mv "$HOME/rish" "$HOME/rish_shizuku.dex" "$HOME/.local/bin/"
sed -i 's/RISH_APPLICATION_ID="PKG"/RISH_APPLICATION_ID="com.termux"/' "$HOME/.local/bin/rish"
chmod +x "$HOME/.local/bin/rish"
```

With Shizuku running, run this command and approve Termux's access if prompted:

```sh
"$HOME/.local/bin/rish" -c true
```

**Optional: Add rish to PATH**

To run `rish` manually without its full path, add `$HOME/.local/bin` to your shell's `PATH`. For Bash:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
```

For other shells, add the same PATH entry to the appropriate startup file.

### 2. Install the startup script

```sh
mkdir -p "$HOME/.termux/boot"
curl -fL "https://raw.githubusercontent.com/myuverr/auto-brevent-starter.sh/main/auto-brevent-starter.sh" \
    -o "$HOME/.termux/boot/auto-brevent-starter.sh"
chmod +x "$HOME/.termux/boot/auto-brevent-starter.sh"
```

### 3. Run it

Run the script once and confirm that Brevent shows its server as running:

```sh
~/.termux/boot/auto-brevent-starter.sh
```

After rebooting, Termux:Boot will run it automatically. You can also use the same command whenever Brevent needs to be started again.

## Settings

The defaults should suit most installations. To change them, edit the constants near the top of `~/.termux/boot/auto-brevent-starter.sh`.

| Setting | Default | Purpose |
| --- | --- | --- |
| `RISH_PATH` | `$HOME/.local/bin/rish` | Location of rish |
| `BREVENT_SCRIPT_PATH` | `/data/local/tmp/brevent.sh` | Brevent start script, as accessed through Shizuku |
| `SHIZUKU_WAIT_TIMEOUT_MINUTES` | `5` | Maximum wait for Shizuku, in minutes |
| `BREVENT_LAUNCH_TIMEOUT_SECONDS` | `60` | Maximum wait for Brevent to report startup, in seconds |

## Logging & Troubleshooting

If something goes wrong, check the log:

```sh
cat ~/.local/state/auto_brevent/script.log
```

To follow a run in real time:

```sh
tail -F ~/.local/state/auto_brevent/script.log
```

## License

This project is licensed under the [WTFPL](LICENSE).
