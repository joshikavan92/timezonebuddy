# TimezoneBuddy

A macOS menu bar application that helps you track your teammates' time zones. Perfect for distributed teams working across different time zones.



## Features

- 🌍 Display teammates' local times in your menu bar
- 🔄 Real-time updates with background refresh
- ⚙️ Easy configuration through settings panel
- 🚀 Quick access to Slack team integration
- 💾 Persistent storage of team member data
- 🖥️ Native macOS menu bar app
- 🎨 Clean and intuitive interface
- 🔐 Secure Slack team ID integration

## Requirements

- macOS 15.4 or later
- Slack workspace access (for team integration)

## Installation

1. Download the latest release
2. Move TimezoneBuddy.app to your Applications folder
3. Launch the app
4. Configure your Slack Team ID in Settings (⌘,)

## Setup

1. When you first launch the app, it will appear in your menu bar
2. Click the menu bar icon to view your teammates' times
3. Right-click the icon for additional options:
   - Launch at Login
   - Settings
   - Reset App Data
   - Quit

## Slack Team ID Setup

1. Open Slack in your web browser
2. Navigate to any channel or DM
3. Look at the URL: `https://app.slack.com/client/T12345678/C23456789`
4. Your Team ID is the segment starting with 'T' (e.g., T12345678)

## Building from Source

1. Clone the repository
2. Open TimezoneBuddy.xcodeproj in Xcode
3. Build and run the project

## Privacy

TimezoneBuddy respects your privacy:
- No data is sent to external servers
- All data is stored locally on your device
- Slack integration only requires your Team ID

## License

MIT License - See LICENSE file for details

## Support

For issues and feature requests, please open an issue on the [GitHub repository](https://github.com/joshikavan92/timezonebuddy). 
