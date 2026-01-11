# Menu Cross-Platform Update

## Summary

Updated the interactive menu system to support both Linux systemd and macOS launchd scheduling systems with automatic OS detection and platform-aware labeling.

## Changes Made

### 1. menu.sh Updates

#### OS Detection (Lines 11-27)

Added OS detection function at startup:

```bash
# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            OS="Linux"
            ;;
        Darwin*)
            OS="macOS"
            ;;
        *)
            OS="Unknown"
            ;;
    esac
}

# Auto-detect OS at startup
detect_os
```

#### Platform-Aware Menu Labels (Lines 105-114)

Main menu now displays OS-specific labels:

**On macOS:**
```
┌────────────────────────────────────────────────────────────┐
│ 1) Run Security Scan                                       │
│ 2) View Reports                                            │
│ 3) View Logs                                               │
│ 4) Schedule Management (launchd)                           │ ← Platform-aware
│ 5) Configuration                                           │
│ 6) Help & Information                                      │
│ q) Quit                                                    │
└────────────────────────────────────────────────────────────┘
```

**On Linux:**
```
┌────────────────────────────────────────────────────────────┐
│ 1) Run Security Scan                                       │
│ 2) View Reports                                            │
│ 3) View Logs                                               │
│ 4) Schedule Management (systemd)                           │ ← Platform-aware
│ 5) Configuration                                           │
│ 6) Help & Information                                      │
│ q) Quit                                                    │
└────────────────────────────────────────────────────────────┘
```

#### Cross-Platform Schedule Router (Lines 354-369)

```bash
# Schedule Management Menu (cross-platform)
schedule_menu() {
    if [ "$OS" = "Linux" ]; then
        systemd_menu
    elif [ "$OS" = "macOS" ]; then
        launchd_menu
    else
        display_header
        error_message "Schedule management not supported on $OS"
        echo ""
        echo "You can still run scans manually:"
        echo "  $INSTALL_DIR/security-scan.sh"
        echo ""
        pause_for_user
    fi
}
```

#### macOS launchd Menu (Lines 435-489)

New menu for macOS launchd management:

```
┌────────────────────────────────────────────────────────────┐
│ Schedule Management - launchd                              │
├────────────────────────────────────────────────────────────┤
│ 1) Show launchd status                                     │
│ 2) View launchd logs                                       │
│ 3) Load/Enable schedule                                    │
│ 4) Unload/Disable schedule                                 │
│ 5) Create/Update plist file                                │
│ 6) Show plist configuration                                │
│ b) Back to Main Menu                                       │
└────────────────────────────────────────────────────────────┘
```

Features:
- Load/unload launchd services
- Create/update plist files
- View status and logs
- Show configuration details

### 2. lib/menu_functions.sh Updates

Added 268 lines of macOS launchd management functions:

#### `show_launchd_status()`
- Checks if plist file exists
- Shows loaded/unloaded status
- Displays service details from launchctl
- Shows schedule information

#### `view_launchd_logs()`
- Displays stdout log (`launchd.log`)
- Displays stderr log (`launchd.err`)
- Shows tail of last 50 lines from each
- Provides log file paths

#### `load_launchd_service()`
- Loads the launchd plist
- Checks if already loaded
- Offers to reload if needed
- Provides status feedback

#### `unload_launchd_service()`
- Unloads the launchd service
- Confirms before unloading
- Provides status feedback

#### `create_launchd_plist_interactive()`
- Creates plist at `~/Library/LaunchAgents/com.security-scanner.plist`
- Configures Sunday 2:00 AM schedule
- Sets up log paths
- Offers to load immediately after creation
- Handles overwrites with confirmation

**Generated Plist Structure:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.security-scanner</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/paul/src/security-scanner/security-scan.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/paul/src/security-scanner/logs/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/paul/src/security-scanner/logs/launchd.err</string>
</dict>
</plist>
```

#### `show_plist_config()`
- Displays plist file contents
- Parses and shows schedule details
- Converts weekday number to name
- Formats time display

## Feature Comparison

| Feature | Linux (systemd) | macOS (launchd) |
|---------|----------------|-----------------|
| **Status Check** | `systemctl status` | `launchctl list` |
| **View Logs** | `journalctl` | File-based logs |
| **Enable** | `systemctl enable` | `launchctl load` |
| **Disable** | `systemctl disable` | `launchctl unload` |
| **Config File** | `/etc/systemd/system/` | `~/Library/LaunchAgents/` |
| **Schedule** | Timer definition | Plist CalendarInterval |
| **Root Required** | Yes (sudo) | No |

## Usage Examples

### macOS Workflow

1. **Launch Menu**
   ```bash
   ./menu.sh
   ```

2. **Navigate to Schedule Management**
   - Select option 4

3. **Create Plist File**
   - Select option 5
   - Confirm creation
   - Optionally load immediately

4. **Check Status**
   - Select option 1
   - View if service is loaded
   - See schedule details

5. **Enable Automatic Scans**
   - Select option 3 (Load/Enable)
   - Service will run every Sunday at 2:00 AM

### Linux Workflow (Existing)

1. **Launch Menu**
   ```bash
   ./menu.sh
   ```

2. **Navigate to Schedule Management**
   - Select option 4

3. **Check Timer Status**
   - Select option 1
   - View systemd timer status

4. **Enable Automatic Scans**
   - Select option 5 (Enable timer)
   - Requires sudo password

## Testing Results

### macOS Testing ✅

```bash
$ ./menu.sh

┌────────────────────────────────────────────────────────────┐
│              Security Scanner Management Menu              │
└────────────────────────────────────────────────────────────┘

Host: pan
Date: 2026-01-11 10:31:53

Last scan: 2026-01-11 10:20:23

┌────────────────────────────────────────────────────────────┐
│ Main Menu                                                  │
├────────────────────────────────────────────────────────────┤
│ 1) Run Security Scan                                       │
│ 2) View Reports                                            │
│ 3) View Logs                                               │
│ 4) Schedule Management (launchd)                           │ ✓ Correct label
│ 5) Configuration                                           │
│ 6) Help & Information                                      │
│ q) Quit                                                    │
└────────────────────────────────────────────────────────────┘

# Select option 4:

┌────────────────────────────────────────────────────────────┐
│ Schedule Management - launchd                              │ ✓ macOS menu
├────────────────────────────────────────────────────────────┤
│ 1) Show launchd status                                     │
│ 2) View launchd logs                                       │
│ 3) Load/Enable schedule                                    │
│ 4) Unload/Disable schedule                                 │
│ 5) Create/Update plist file                                │
│ 6) Show plist configuration                                │
│ b) Back to Main Menu                                       │
└────────────────────────────────────────────────────────────┘
```

✅ OS detection works
✅ Menu labels update correctly
✅ launchd menu displays properly
✅ Functions available for macOS scheduling

### Expected Linux Behavior

On Linux, selecting option 4 should show:

```
┌────────────────────────────────────────────────────────────┐
│ Schedule Management - systemd                              │
├────────────────────────────────────────────────────────────┤
│ 1) Show timer status                                       │
│ 2) Show service status                                     │
│ 3) View next scheduled run                                 │
│ 4) View systemd logs                                       │
│ 5) Enable timer (requires sudo)                            │
│ 6) Disable timer (requires sudo)                           │
│ 7) Start manual scan via systemd (requires sudo)           │
│ b) Back to Main Menu                                       │
└────────────────────────────────────────────────────────────┘
```

## Benefits

### 1. Platform-Aware Interface
- Menu automatically adapts to OS
- No confusing systemd references on macOS
- Clear indication of which scheduler is in use

### 2. Consistent User Experience
- Same menu structure across platforms
- Similar workflow for schedule management
- Familiar terminology per platform

### 3. Native Integration
- Uses platform-native schedulers
- Follows platform conventions
- No need for third-party tools

### 4. Zero Manual Configuration
- Automatic OS detection
- No need to edit menu code for different platforms
- Works out of the box

## Implementation Details

### Design Decisions

1. **Router Pattern**: `schedule_menu()` acts as router, directing to platform-specific menus
2. **Separate Functions**: Linux and macOS functions completely separated for clarity
3. **Plist Location**: `~/Library/LaunchAgents/` (user-level, no sudo required)
4. **Log Location**: Reuses existing `logs/` directory
5. **Schedule Alignment**: Both platforms use Sunday 2:00 AM for consistency

### Error Handling

- Graceful degradation on unsupported OS
- Clear error messages
- Confirmation prompts before destructive actions
- Status validation before operations

### Future Enhancements

Potential improvements:
- Custom schedule configuration (not just Sunday 2AM)
- Multiple schedule presets (daily, weekly, monthly)
- Timezone configuration
- Email notification after scheduled runs
- Status notifications via system notifications

## Migration Notes

### For Existing Users

**No breaking changes!**

- Existing Linux systemd configurations continue to work
- Menu structure remains familiar
- All existing functions preserved
- Only new macOS functionality added

### For New Users

**Zero setup required:**

1. Run `./install.sh` (creates plist on macOS)
2. Or use menu option 5 to create plist manually
3. Load with menu option 3
4. Done!

## File Summary

**Modified Files:**
- `menu.sh` - Added OS detection and platform routing
- `lib/menu_functions.sh` - Added 268 lines of macOS functions

**Lines Changed:**
- `menu.sh`: +102 lines
- `lib/menu_functions.sh`: +268 lines
- Total: +370 lines

**Functions Added:**
- `show_launchd_status()`
- `view_launchd_logs()`
- `load_launchd_service()`
- `unload_launchd_service()`
- `create_launchd_plist_interactive()`
- `show_plist_config()`
- `schedule_menu()` (router)
- `launchd_menu()` (menu interface)

## Conclusion

The menu system now provides a seamless, platform-aware interface for managing scheduled scans on both Linux and macOS, with automatic OS detection and native integration with each platform's scheduling system.

Users see only relevant options for their platform, reducing confusion and improving usability. The implementation maintains backward compatibility while adding comprehensive macOS support.
