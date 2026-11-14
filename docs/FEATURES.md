# NZBPort features

[Back to the README](../README.md) · [Deutsch](FEATURES.de.md)

## Links, files and waiting submissions

Open an NZBlnk link from Safari, use **Paste NZBlnk** for a copied link, or drop a link into the window. NZBPort checks the macOS link association when it starts and when it becomes active. If the app is already the default, the registration button shows that it is set up.

Open NZB files with the file chooser, Finder’s **Open With** menu or drag and drop. The limit is 16 MiB per file and 64 MiB for NZB data held for pending submissions, including the current one. NZBPort handles submissions one at a time. In **Waiting Links and Files**, you can see what comes next and remove individual entries before they are sent.

## Categories and submission options

NZBPort refreshes categories from SABnzbd at startup, when opening a submission and when you request a refresh. The startup check runs in the background. Connection and submission errors are shown in the app.

In **Connection Settings**, expand or collapse **Your Categories**, hide or restore categories, and pin and reorder favorites. These choices affect only NZBPort. New categories from SABnzbd appear automatically. Before sending a job, choose a category and, if needed, a different priority or **Add Paused**.

NZBPort asks you to confirm repeat submissions detected within ten minutes, including after an uncertain transfer. It keeps only hashes and timestamps for this check in memory. If the transfer outcome is unclear, check the SABnzbd queue before trying again.

## Downloads, menu bar and notifications

**Downloads** shows progress, status and category for each queued job, along with overall speed, remaining size and time, and recent history. Pause or resume an individual job or the whole SABnzbd queue. The view also has a refresh button.

The NZBPort menu shows the queue count and speed when available. It reports a paused or empty queue and lets you know if the status could not be retrieved. Opening the menu requests a refresh. **Open SABnzbd in Browser** opens the configured server without putting the API key in the browser URL.

Optional macOS notifications report completed or failed downloads. Existing history is skipped on the first refresh, and a job that is still unpacking is not reported as finished. While Downloads is visible or notifications are enabled, NZBPort waits two seconds after each status request before starting the next one.

## Updates

Use **Check for Updates** to look for a newer GitHub release. You can include test releases. NZBPort opens the release page; it does not download or install updates automatically.

## Language, appearance and startup

The interface supports English and German. Choose **Language → System, Deutsch or English** in the app menu, menu bar menu or gear menu. System is the default and follows the first supported language in your macOS language preferences, falling back to English. A manual choice is saved locally and takes effect immediately, including menus and app-generated error messages.

The app menu and gear menu offer **Standard, Coffee, Ivory and Mint** color themes, independently of system, light or dark appearance and system, transparent or opaque window backgrounds. Themes adapt to light and dark mode, and the choice is saved locally. Controls use native Liquid Glass. The Icon Composer asset supports the system icon appearances.

The main window grows to fit its content up to the visible screen height. You can scroll if more space is needed. A size you set by hand stays in effect until you reopen the window.

Use **Launch at Login** in the app menu, menu bar menu or gear menu to enable or disable startup at macOS login. It is changed only when you toggle it. If macOS requires approval, choose **Allow in macOS…** to open the Login Items settings. At login, NZBPort stays in the menu bar. Launching it manually opens the window.

**About NZBPort** links to the project on GitHub and the developer’s [portfolio homepage](https://schrotty74.github.io/Portfolio/). Links open in your default browser only when selected.

## How a link becomes a download

1. A browser hands a `nzblnk:` URL to the registered macOS app. A browser confirmation may appear first.
2. NZBPort parses the search identifier (`h`), title (`t`), optional password (`p`) and repeated group fields (`g`). It accepts percent-encoded text and expands abbreviated `a.b.` groups for NZBIndex.
3. The app fetches the current SABnzbd categories and applies your local hidden-category choices. You can filter the category buttons by name.
4. Selecting a category starts the lookup. NZBIndex is tried first through its public JSON API, without a separate search API key. If it fails, the app tries NZBKing and then BinSearch using their public search responses.
5. NZBPort submits the resolved download URL, title, chosen category and optional archive password to SABnzbd. SABnzbd performs the download; NZBPort does not download Usenet articles itself.
6. A confirmed submission closes the window or advances to the next waiting link. An error remains visible in the window. If a submission times out, check the SABnzbd queue before trying again to avoid duplicate jobs.

NZBIndex results with multiple distinct collection IDs are rejected by that provider; the fallback then continues. The HTML providers use the first supported result in their response. Search results are not a guarantee of the content or its availability. The app does not create or delete SABnzbd categories or manage Usenet accounts.
