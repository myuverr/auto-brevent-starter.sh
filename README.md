# Auto Brevent Starter

Automatically start the Brevent server with either the [Shevery module](#shevery-module) or the [Termux:Boot script](#termuxboot-script).

## Shevery module

Requires [Shevery](https://github.com/HmnDev-Tech/shevery) and [Brevent](https://play.google.com/store/apps/details?id=me.piebridge.brevent).

Download `shevery-module-*.zip` from the [latest release](https://github.com/myuverr/auto-brevent-starter.sh/releases/latest), install it through Shevery's module manager, and enable the module.

In Shevery, open **Settings → Modules**:

1. Set **Module access mode** to **Full access**, or select **Custom** and enable **Run Service** under **Custom permissions**.
2. Enable **Allow background actions**.

Brevent will start automatically whenever Shevery becomes active.

## Termux:Boot script

### Requirements

- [Brevent](https://play.google.com/store/apps/details?id=me.piebridge.brevent), with its setup completed.
- [Shizuku](https://github.com/RikkaApps/Shizuku) or the [thedjchi fork](https://github.com/thedjchi/Shizuku) (supports automatic startup at boot after Wi-Fi becomes available).
- [Termux](https://github.com/termux/termux-app) ([F-Droid](https://f-droid.org/packages/com.termux/)) and [Termux:Boot](https://github.com/termux/termux-boot) ([F-Droid](https://f-droid.org/packages/com.termux.boot/)). Both must be installed from the same distribution source.

Open Termux:Boot once after installation to enable it to run at boot.

Start Shizuku separately first. For a fully automatic setup, configure Shizuku to start on boot.

### Setup

Run the following commands in Termux.

#### 1. Configure rish

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

#### 2. Install the startup script

```sh
mkdir -p "$HOME/.termux/boot"
curl -fL "https://github.com/myuverr/auto-brevent-starter.sh/releases/latest/download/auto-brevent-starter.sh" \
    -o "$HOME/.termux/boot/auto-brevent-starter.sh"
chmod +x "$HOME/.termux/boot/auto-brevent-starter.sh"
```

#### 3. Run it

Run the script once and confirm that Brevent shows its server as running:

```sh
~/.termux/boot/auto-brevent-starter.sh
```

After rebooting, Termux:Boot will run it automatically. You can also use the same command whenever Brevent needs to be started again.

### Settings

The defaults should suit most installations. To change them, edit the constants near the top of `~/.termux/boot/auto-brevent-starter.sh`.

| Setting | Default | Purpose |
| --- | --- | --- |
| `RISH_PATH` | `$HOME/.local/bin/rish` | Location of rish |
| `BREVENT_SCRIPT_PATH` | `/data/local/tmp/brevent.sh` | Brevent start script, as accessed through Shizuku |
| `SHIZUKU_WAIT_TIMEOUT_MINUTES` | `5` | Maximum wait for Shizuku, in minutes |
| `BREVENT_LAUNCH_TIMEOUT_SECONDS` | `60` | Maximum wait for Brevent to report startup, in seconds |

### Logging & Troubleshooting

If something goes wrong, check the log:

```sh
cat ~/.local/state/auto_brevent/script.log
```

To follow a run in real time:

```sh
tail -F ~/.local/state/auto_brevent/script.log
```

## License

This project is dual-licensed under the [ISC](LICENSE-ISC) or [WTFPL](LICENSE-WTFPL), at your option.
