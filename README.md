# Citrix ICA Auto-Launcher for macOS

This is a small macOS automation for people who must launch Citrix sessions from downloaded `.ica` files, but do not want to interact with the full Citrix Workspace UI every time.

The workflow is:

1. Sign in to the Citrix web portal in your browser.
2. Click the app or desktop you want to open.
3. The browser downloads an `.ica` file.
4. A macOS LaunchAgent notices the new file in `~/Downloads`.
5. A shell script opens the `.ica` using `Citrix Workspace.app`.
6. After a short delay, the script deletes the `.ica` file.

This does **not** replace Citrix Workspace. It only automates the local handling of `.ica` files.

## Requirements

- macOS
- Citrix Workspace installed at:

```text
/Applications/Citrix Workspace.app
```

- A browser that downloads `.ica` files to:

```text
~/Downloads
```

- `/bin/zsh` granted Full Disk Access, explained below.

## Files

This package contains:

```text
launch-citrix-ica.sh
com.example.citrix-ica-launcher.plist
install.sh
README.md
```

## Important macOS permission requirement

On recent macOS versions, LaunchAgents may not be able to read `~/Downloads` unless the shell running the script has permission.

Go to:

```text
System Settings > Privacy & Security > Full Disk Access
```

Add:

```text
/bin/zsh
```

If Finder does not let you browse to `/bin/zsh`, press `Command + Shift + G` in the file picker and enter:

```text
/bin
```

Then select `zsh`.

Without this permission, the script may run correctly but report that it found zero `.ica` files even though Terminal can see them.

## Option A: automatic install

From the folder containing these files:

```bash
chmod +x install.sh
./install.sh
```

The installer will:

- copy `launch-citrix-ica.sh` to `~/bin/launch-citrix-ica.sh`
- create a LaunchAgent at `~/Library/LaunchAgents/com.example.citrix-ica-launcher.plist`
- hardcode your current macOS username/path automatically
- load the LaunchAgent

After installing, grant Full Disk Access to `/bin/zsh` if you have not already done so.

## Option B: manual install

Create a bin folder if you do not already have one:

```bash
mkdir -p ~/bin
```

Copy the script:

```bash
cp launch-citrix-ica.sh ~/bin/launch-citrix-ica.sh
chmod +x ~/bin/launch-citrix-ica.sh
```

Copy the plist:

```bash
mkdir -p ~/Library/LaunchAgents
cp com.example.citrix-ica-launcher.plist ~/Library/LaunchAgents/
```

Edit the plist and replace:

```text
REPLACE_WITH_YOUR_MAC_USERNAME
```

with your actual macOS username.

You can find your username with:

```bash
whoami
```

For example, if your username is `jane`, these plist paths should become:

```text
/Users/jane/bin/launch-citrix-ica.sh
/Users/jane/Downloads
/Users/jane/Library/Logs/citrix-ica-launcher.stdout.log
/Users/jane/Library/Logs/citrix-ica-launcher.stderr.log
```

Validate the plist:

```bash
plutil -lint ~/Library/LaunchAgents/com.example.citrix-ica-launcher.plist
```

Load it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.citrix-ica-launcher.plist
launchctl enable gui/$(id -u)/com.example.citrix-ica-launcher
```

## Testing

Watch the log:

```bash
tail -f ~/Library/Logs/citrix-ica-launcher.log
```

Then download a new `.ica` file from your Citrix web portal.

You should see log entries similar to:

```text
SCRIPT STARTED user=...
Found 1 ICA file(s)
Candidate: /Users/yourname/Downloads/example.ica
Launching ICA via Citrix Workspace.app: /Users/yourname/Downloads/example.ica
open returned rc=0
Deleting ICA after handoff
```

If you already have an `.ica` file in Downloads and want to force the LaunchAgent to run:

```bash
touch ~/Downloads
```

Or manually invoke the script:

```bash
~/bin/launch-citrix-ica.sh
```

## Uninstall

Unload the LaunchAgent:

```bash
launchctl bootout gui/$(id -u)/com.example.citrix-ica-launcher 2>/dev/null
```

Remove the files:

```bash
rm -f ~/Library/LaunchAgents/com.example.citrix-ica-launcher.plist
rm -f ~/bin/launch-citrix-ica.sh
```

Optional: remove logs and temporary state:

```bash
rm -f ~/Library/Logs/citrix-ica-launcher.log
rm -f ~/Library/Logs/citrix-ica-launcher.stdout.log
rm -f ~/Library/Logs/citrix-ica-launcher.stderr.log
rm -rf /tmp/citrix-ica-launcher-state
rm -rf /tmp/citrix-ica-launcher.lockdir
```

## Troubleshooting

### The script runs but finds zero `.ica` files

Grant Full Disk Access to:

```text
/bin/zsh
```

This is the most common macOS issue.

You can confirm the symptom by checking the log:

```bash
tail -100 ~/Library/Logs/citrix-ica-launcher.log
```

If it says `Found 0 ICA file(s)` while Terminal can see `.ica` files in Downloads, this is likely a macOS privacy permission issue.

### The LaunchAgent is loaded but does not fire

Check whether it is loaded:

```bash
launchctl print gui/$(id -u)/com.example.citrix-ica-launcher
```

Unload and reload it:

```bash
launchctl bootout gui/$(id -u)/com.example.citrix-ica-launcher 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.citrix-ica-launcher.plist
launchctl enable gui/$(id -u)/com.example.citrix-ica-launcher
```

### Citrix launches manually but not from the LaunchAgent

Check the stderr log:

```bash
cat ~/Library/Logs/citrix-ica-launcher.stderr.log
cat /tmp/citrix-ica-open.err
```

Also confirm Citrix Workspace is installed at:

```text
/Applications/Citrix Workspace.app
```

### The `.ica` file is deleted too quickly

In `launch-citrix-ica.sh`, increase this line:

```zsh
sleep 15
```

For example:

```zsh
sleep 25
```

### I want to keep `.ica` files instead of deleting them

Comment out this line in the script:

```zsh
rm -f "$file"
```

Or replace the deletion block with a move to an archive folder.

## Notes

- The plist must contain absolute paths. Do not use `~` inside the plist.
- The shell script can use `$HOME`.
- If you edit the shell script, you do **not** need to reload the LaunchAgent.
- If you edit the plist, you **must** unload and reload the LaunchAgent.
- This automation depends on Citrix Workspace being the app that can handle `.ica` files.
