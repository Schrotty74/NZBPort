# NZBPort features

[Back to the README](../README.md) · [Deutsch](FEATURES.de.md)

## Open links and files

- **NZBlnk links:** Open a link from Safari, use **Paste NZBlnk** for a copied link, or drop a link into the window.
- **macOS link association:** NZBPort checks the current association when it starts and when it becomes active. If it is already the default app, the registration button shows that it is set up.
- **NZB files:** Use the file chooser, Finder’s **Open With** menu, or drag and drop. NZBPort accepts up to 16 MiB per file and holds up to 64 MiB of NZB file data across the current and waiting submissions.
- **Waiting links and files:** NZBPort handles submissions one at a time. The list shows what comes next and lets you remove individual entries before sending them. The current submission stays in place.

## Choose a category and send

- **Fetch categories:** NZBPort reads the current SABnzbd categories at startup, when you open a submission, and on request. The startup check runs in the background.
- **Find a category:** Filter the category buttons by name before sending.
- **Organize categories:** Hide or restore categories, pin and reorder favorites, and expand or collapse **Your Categories** in Connection Settings. These choices affect only NZBPort. New categories from SABnzbd appear automatically.
- **Priority:** Choose Low, Normal, High, or Force before sending. Use **Add Paused** to add a job without starting it.
- **Title and archive password:** NZBPort passes the title and any archive password from the NZBlnk link to SABnzbd with the selected category.
- **Submission feedback:** After SABnzbd confirms the job, NZBPort shows the next submission or closes the window and stays in the menu bar. The app shows connection and submission failures.
- **Duplicate warning:** NZBPort asks you to confirm repeat attempts detected within ten minutes, including after an uncertain transfer. It keeps only hashes and timestamps for this check in memory. If the outcome is unclear, check the SABnzbd queue before sending again.

## Downloads, menu bar and notifications

- **Queue details:** In **Downloads**, see each queued job’s title, progress, status, and category. The overview also shows the queue’s overall speed, remaining size, and estimated time.
- **Queue controls:** Pause or resume one job or the whole SABnzbd queue.
- **Recent history:** See the ten most recent entries shown by the app, with their status.
- **Status refresh:** Refresh Downloads on demand. While Downloads is visible or notifications are enabled, NZBPort waits two seconds after each status request before starting the next one.
- **Quick status in the menu bar:** Open the NZBPort menu to request a fresh queue count and speed. It also shows when the queue is empty or paused, the connection is not set up, or the status is unavailable.
- **macOS notifications:** Opt in to notifications for finished or failed downloads. The first refresh skips existing history, and a job that is still unpacking is not reported as finished.
- **Open SABnzbd in Browser:** Open the configured server without putting the API key in the browser URL.

## Language, appearance and startup

- **Language:** Choose System, Deutsch, or English from the app menu, menu bar menu, or gear menu. System follows the first supported macOS preference and falls back to English. A manual choice is saved and applies immediately to menus and app-generated errors.
- **Color themes:** Choose Standard, Coffee, Ivory, or Mint. Themes adapt to light and dark mode.
- **Appearance and background:** Choose system, light, or dark appearance independently of the theme. The window background can follow the system or be transparent or opaque.
- **Native macOS design:** NZBPort uses Liquid Glass controls. Its Icon Composer app icon supports the system icon appearances.
- **Window height:** The window grows to fit its content up to the visible screen height. Scroll when more space is needed. A size you set by hand stays in effect until you reopen the window.
- **Launch at login:** Enable or disable startup from the app menu, menu bar menu, or gear menu. Choose **Allow in macOS…** if macOS asks for approval. NZBPort stays in the menu bar at login; launching it manually opens the window. If SABnzbd is still starting, NZBPort retries the category request up to three times, waiting 2, 5, then 10 seconds. It still reports persistent failures and rejected credentials. Manual launches keep their existing behavior.

## Updates, project links and source code

- **Check for Updates:** Check GitHub for a newer release, optionally including test releases. NZBPort opens the release page; it does not download or install updates automatically.
- **About NZBPort:** Open the GitHub project or the developer’s [portfolio](https://schrotty74.github.io/Portfolio/) in your default browser.
- **Build from source:** NZBPort’s application code is written in Swift with Apple system frameworks. No third-party packages are required. See [build instructions](../README.md#build) and [privacy and service limits](../README.md#privacy-and-service-limits).

## How a link becomes a download

1. A browser hands a `nzblnk:` URL to the registered macOS app. A browser confirmation may appear first.
2. NZBPort parses the search identifier (`h`), title (`t`), optional password (`p`) and repeated group fields (`g`). It accepts percent-encoded text and expands abbreviated `a.b.` groups for NZBIndex.
3. The app fetches the current SABnzbd categories and applies your local hidden-category choices. You can filter the category buttons by name.
4. Selecting a category starts the lookup in NZBIndex, NZBKing and BinSearch. If none finds the NZB, the app searches Treasure Maps and then NewzBay by release title. Enter a provider’s API key in Connection Settings to enable it.
5. NZBPort sends SABnzbd the public download URL or the NZB file it retrieved from Treasure Maps or NewzBay, along with the title, category and optional archive password. SABnzbd downloads the Usenet articles.
6. A confirmed submission closes the window or advances to the next waiting link. An error remains visible in the window. If a submission times out, check the SABnzbd queue before trying again to avoid duplicate jobs.

NZBIndex results with multiple distinct collection IDs are rejected by that provider; the fallback then continues. The HTML providers use the first supported result in their response. Search results are not a guarantee of the content or its availability. The app does not create or delete SABnzbd categories or manage Usenet accounts.
