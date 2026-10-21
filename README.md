# NZBPort

[Deutsch](README.de.md) · [Downloads](https://github.com/Schrotty74/NZBPort/releases)

NZBPort is a small macOS menu bar app that opens `nzblnk:` links and sends downloads to SABnzbd. Choose a category, and the app searches NZBIndex, NZBKing, then BinSearch as needed. The window closes when SABnzbd confirms the submission; NZBPort stays in the menu bar.

## Requirements and installation

- Apple Silicon Mac with macOS 26 or later.
- A running SABnzbd server and its full API key.

Download the DMG or ZIP from [Releases](https://github.com/Schrotty74/NZBPort/releases). Open the DMG and drag NZBPort into Applications, or extract the ZIP and move the app there. The app is ad hoc signed, without Apple notarization. macOS may block it; review the source and use the system's Privacy & Security settings to allow it only if you trust this build.

## Setup

1. Open NZBPort and enter the SABnzbd URL and full API key.
2. Test the connection, then save it.
3. Select **Als Link-App verwenden** to register NZBPort for `nzblnk:` links.
4. If a browser userscript already intercepts these links, disable it on this Mac.

The interface is currently in German. You can also paste a copied link using **NZBlnk aus Zwischenablage**. Categories refresh from SABnzbd when a link opens. Hide or restore categories in settings; this changes only their visibility in NZBPort. New categories appear automatically. Links opened together are processed in sequence.

The app menu and gear menu offer system, light and dark appearance, with system, transparent or opaque window backgrounds. Controls use native Liquid Glass. The Icon Composer asset supports the system icon appearances.

## How a link becomes a download

1. A browser hands a `nzblnk:` URL to the registered macOS app. A browser confirmation may appear first.
2. NZBPort parses the search identifier (`h`), title (`t`), optional password (`p`) and repeated group fields (`g`). It accepts percent-encoded text and expands abbreviated `a.b.` groups for NZBIndex.
3. The app fetches the current SABnzbd categories and applies your local hidden-category choices. You can filter the category buttons by name.
4. Selecting a category starts the lookup. NZBIndex is tried first through its public JSON API, without a separate search API key. If it fails, the app tries NZBKing and then BinSearch using their public search responses.
5. NZBPort submits the resolved download URL, title, chosen category and optional archive password to SABnzbd. SABnzbd performs the download; NZBPort does not download Usenet articles itself.
6. A confirmed submission closes the window or advances to the next waiting link. An error remains visible in the window. If a submission times out, check the SABnzbd queue before trying again to avoid duplicate jobs.

NZBIndex results with multiple distinct collection IDs are rejected by that provider; the fallback then continues. The HTML providers use the first supported result in their response. Search results are not a guarantee of the content or its availability. The app does not create or delete SABnzbd categories, manage Usenet accounts, or control SABnzbd’s global pause state.

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
| `Sources/NZBRelay/Theme` | Appearance and native glass controls |
| `Resources/NZBPort.icon` | Editable Icon Composer artwork |
| `Scripts` | App build and original brand artwork generation |
| `Tests` | Parser, resolver and API contract tests |

Internal target names remain `NZBRelay`; the displayed app name is NZBPort. Settings are associated with the app's bundle identifier.

## License

GNU General Public License version 3. See [LICENSE](LICENSE).
