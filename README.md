# NZBPort

[Deutsch](README.de.md) · [Downloads](https://github.com/Schrotty74/NZBPort/releases)

> Current test version: **0.2**. [Download DMG or ZIP](https://github.com/Schrotty74/NZBPort/releases/tag/v0.2).

NZBPort is a small macOS menu bar app that opens `nzblnk:` links and sends downloads to SABnzbd. Choose a category, and the app searches NZBIndex, NZBKing, then BinSearch as needed. The window closes when SABnzbd confirms the submission; NZBPort stays in the menu bar.

## Features

- Open `nzblnk:` links directly from Safari or paste them from the clipboard.
- Choose a SABnzbd category before submitting a download.
- Search through NZBIndex, with NZBKing and BinSearch as fallbacks.
- Pass the link title and optional unpacking password to SABnzbd.
- Refresh categories at app startup, when opening a link, or manually in settings.
- Hide and restore categories locally without changing them in SABnzbd; new categories appear automatically.
- Report connection and submission failures in the app.
- Process multiple links in sequence and remain in the menu bar after submission.
- Switch immediately between **English**, **Deutsch** and **System**, following the supported macOS language preferences by default.
- Choose **Standard**, **Coffee**, **Ivory** or **Mint**, independently of light/dark appearance and window transparency.
- Use native Liquid Glass controls and an adaptive Icon Composer app icon.
- Enable or disable **Launch at Login** through macOS login items.
- Open the GitHub project and portfolio homepage from **About NZBPort**.
- Build from original Swift application code using Apple system frameworks, with no third-party package dependencies.

- Open `.nzb` files through the file chooser, Open With or drag-and-drop (16 MiB per file; 64 MiB total pending data).
- Choose download priority or submit jobs paused.
- Pin and reorder favorite categories; collapse or expand the categories section in connection settings.
- View progress, speed, remaining size and time, and recent history in the Downloads view.
- Pause or resume individual jobs or the whole SABnzbd queue.
- Refresh status with a two-second wait between requests while Downloads is visible or notifications are enabled.
- Enable optional macOS completion and failure notifications. Existing history is skipped on the first refresh; unpacking is not reported as completed.
- Confirm duplicate attempts within ten minutes, including retries after uncertain network failures; only hashes and timestamps are held in memory.
- Open SABnzbd in the browser without including the API key in the URL.
- Check GitHub updates manually, optionally including test releases; no automatic download or installation.

## Screenshots

| Main window | Connection settings |
| --- | --- |
| ![NZBPort main window](docs/screenshots/nzbport-main.png) | ![NZBPort connection settings](docs/screenshots/nzbport-settings.png) |

The private server address in the first screenshot has been redacted.

## Requirements and installation

- Apple Silicon Mac with macOS 26 or later.
- A running SABnzbd server and its full API key.

Download the DMG or ZIP from [Releases](https://github.com/Schrotty74/NZBPort/releases). Open the DMG and drag NZBPort into Applications, or extract the ZIP and move the app there. The app is ad hoc signed and is not notarized by Apple. If macOS blocks the first launch, follow the Gatekeeper steps below.

### Gatekeeper: opening NZBPort for the first time

Only approve a build downloaded from the official [NZBPort GitHub Releases](https://github.com/Schrotty74/NZBPort/releases), and only if you trust it.

1. After moving the app to Applications, try to open `NZBPort.app` normally once so macOS registers the blocked launch.
2. Open **System Settings → Privacy & Security** and scroll down to **Security**.
3. Click **Open Anyway** for NZBPort.
4. Confirm with **Open** and authenticate if macOS asks you to.

**Open Anyway** is available only for a limited time after the blocked launch attempt. If it is missing, try opening the app again and return to these settings. This creates an exception for NZBPort and does not disable Gatekeeper system-wide.

See [Apple’s instructions for opening apps safely](https://support.apple.com/en-us/102445).

## Setup

1. Open NZBPort and enter the SABnzbd URL and full API key.
2. Test the connection, then save it.
3. Select **Use as Link App** to register NZBPort for `nzblnk:` links.
4. If a browser userscript already intercepts these links, disable it on this Mac.

The interface supports English and German. Choose **Language → System, Deutsch or English** in the app menu, menu bar menu or gear menu. System is the default and follows the first supported language in your macOS language preferences, falling back to English. A manual choice is saved locally and takes effect immediately, including menus and app-generated error messages. You can also paste a copied link using **Paste NZBlnk**. Categories refresh from SABnzbd when the app starts and whenever a link opens. Startup checks run in the background; a failed check is shown as an error in the app. The refresh button beside **Your Categories** in connection settings also reloads them on request. Hide or restore categories in settings; this changes only their visibility in NZBPort. New categories appear automatically. Links opened together are processed in sequence.

The app menu and gear menu offer **Standard, Coffee, Ivory and Mint** color themes, independently of system, light or dark appearance and system, transparent or opaque window backgrounds. Themes adapt to light and dark mode, and the choice is saved locally. Controls use native Liquid Glass. The Icon Composer asset supports the system icon appearances.

Use **Launch at Login** in the app menu, menu bar menu or gear menu to enable or disable startup at macOS login. It is changed only when you toggle it. If macOS requires approval, choose **Allow in macOS…** to open the Login Items settings.

**About NZBPort** links to the project on GitHub and the developer’s [portfolio homepage](https://schrotty74.github.io/Portfolio/). Links open in your default browser only when selected.

## How a link becomes a download

1. A browser hands a `nzblnk:` URL to the registered macOS app. A browser confirmation may appear first.
2. NZBPort parses the search identifier (`h`), title (`t`), optional password (`p`) and repeated group fields (`g`). It accepts percent-encoded text and expands abbreviated `a.b.` groups for NZBIndex.
3. The app fetches the current SABnzbd categories and applies your local hidden-category choices. You can filter the category buttons by name.
4. Selecting a category starts the lookup. NZBIndex is tried first through its public JSON API, without a separate search API key. If it fails, the app tries NZBKing and then BinSearch using their public search responses.
5. NZBPort submits the resolved download URL, title, chosen category and optional archive password to SABnzbd. SABnzbd performs the download; NZBPort does not download Usenet articles itself.
6. A confirmed submission closes the window or advances to the next waiting link. An error remains visible in the window. If a submission times out, check the SABnzbd queue before trying again to avoid duplicate jobs.

NZBIndex results with multiple distinct collection IDs are rejected by that provider; the fallback then continues. The HTML providers use the first supported result in their response. Search results are not a guarantee of the content or its availability. The app does not create or delete SABnzbd categories or manage Usenet accounts.

## Privacy and service limits

The SABnzbd URL and API key are stored locally, unencrypted, in app preferences. The app does not use Keychain. The API key is sent in a POST body to the configured SABnzbd endpoint. HTTP is supported; use HTTPS or a trusted VPN for untrusted networks.

Search services receive the link's search identifier; NZBIndex also receives its groups. The title, archive password and SABnzbd key are not part of search requests. The title and optional password are passed to SABnzbd with the selected category. Search availability depends on external services and their terms. HTML fallbacks can stop working when a service changes its pages or blocks automated access. No access-control or CAPTCHA bypass is included.

NZBPort’s application code was written specifically for this project in Swift, including the NZBlnk parser, search providers, HTML parser, SABnzbd client and local category filter. It includes no third-party application code or package dependencies. It uses Apple’s Swift standard library and system frameworks such as Foundation, AppKit and SwiftUI. The brand artwork is also original to this project.

## Build

Use Xcode with the macOS 26 SDK or newer, including Icon Composer asset compilation, and select it with `xcode-select`. No third-party packages are required.

```sh
swift test
zsh Scripts/build.sh
```

The app is created at `Build/NZBPort.app` and signed locally ad hoc. The build script derives the project location from its own path and strips debug symbols from the distributed executable. It installs no certificates and publishes nothing.

| Location | Purpose |
| --- | --- |
| `Sources/RelayCore` | Link parsing, search providers, SABnzbd API and category preferences |
| `Sources/NZBRelay` | App lifecycle, menu bar and state |
| `Sources/NZBRelay/UI` | Views and settings |
| `Sources/NZBRelay/Localization` | Saved language selection and native language menu |
| `Sources/RelayCore/Resources` | English and German interface and error translations |
| `Sources/NZBRelay/Theme` | Appearance and native glass controls |
| `Resources/NZBPort.icon` | Editable Icon Composer artwork |
| `Scripts` | App build and original brand artwork generation |
| `Tests` | Parser, resolver and API contract tests |

Internal target names remain `NZBRelay`; the displayed app name is NZBPort. Settings are associated with the app's bundle identifier.

## License

GNU General Public License version 3. See [LICENSE](LICENSE).
