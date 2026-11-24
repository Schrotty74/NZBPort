# NZBPort features

[Back to the README](../README.md) · [Deutsch](FEATURES.de.md)

## Open links and files

- **NZBlnk links:** Open a link from Safari, use **Paste NZBlnk** for a copied link, or drop a link into the window.
- **macOS link association:** NZBPort checks the current association when it starts and when it becomes active. If it is already the default app, the registration button shows that it is set up.
- **NZB files:** Use the file chooser, Finder’s **Open With** menu, or drag and drop. NZBPort accepts up to 16 MiB per file and holds up to 64 MiB of NZB file data across the current and waiting submissions.
- **Save an NZB:** Save the current NZB to a location you choose, including when SABnzbd is not configured or cannot be reached. Imported NZB files can be saved as copies. For a link with an archive password, NZBPort writes that exact password into the NZB file’s password metadata. Canceling the save dialog or a save error leaves the current submission available.
- **Waiting links and files:** NZBPort handles submissions one at a time. The list shows what comes next and lets you remove individual entries before sending them. The current submission stays in place.

## Choose a category and send

- **Fetch categories:** NZBPort reads the current SABnzbd categories at startup, when you open a submission, and on request. The startup check runs in the background.
- **Find a category:** Filter the category buttons by name before sending.
- **Add a category:** On the dedicated **Categories** page, add a category to SABnzbd.
- **Delete a category:** Confirm before deleting an existing category in SABnzbd. The default category is protected. Deleting a category changes SABnzbd’s configuration; it does not delete queued jobs or downloaded files.
- **Local category preferences:** On the **Categories** page, hide or restore categories and pin or reorder favorites. These choices affect only NZBPort. New categories from SABnzbd appear automatically.
- **Priority:** Choose Low, Normal, High, or Force before sending. Use **Add Paused** to add a job without starting it.
- **Title and archive password:** NZBPort passes the title and any archive password from the NZBlnk link to SABnzbd with the selected category.
- **Submission feedback:** After SABnzbd confirms the job, NZBPort shows the next submission or closes the window and stays in the menu bar. The app shows connection and submission failures.
- **Duplicate warning:** NZBPort asks you to confirm repeat attempts detected within ten minutes, including after an uncertain transfer. It keeps only hashes and timestamps for this check in memory. If the outcome is unclear, check the SABnzbd queue before sending again.

## Search providers

- **Public search:** NZBIndex, NZBKing and BinSearch are tried in that order. NZBIndex uses its public API and does not need a search API key.
- **Optional indexers:** If public search finds nothing, NZBPort tries providers with saved API keys in order. Each provider has its own optional API key in Connection Settings. The search ends when a provider returns a valid result; errors, unmatched titles and ambiguous API results let it continue to the next provider.

| Order | Provider | Search API key |
| --- | --- | --- |
| 1 | NZBIndex | No, public API |
| 2 | NZBKing | No |
| 3 | BinSearch | No |
| 4 | Treasure Maps | Optional, saved separately |
| 5 | NewzBay | Optional, saved separately |
| 6 | NinjaCentral | Optional, saved separately |
| 7 | DrunkenSlug | Optional, saved separately |
| 8 | NZBFinder | Optional, saved separately; premium membership required for API access |
| 9 | Videothek | Optional, saved separately; API permission and an approved tool required |

- **Provider requests:** A configured provider receives the release title and its own API key. Keys are stored locally without encryption only after you explicitly save them. To disable a provider, clear its key and save.
- **NZB retrieval:** NZBPort downloads indexer results itself and passes the NZB file to SABnzbd. The indexer key is not sent to SABnzbd.
- **Provider limits:** A direct authenticated NinjaCentral test returned a matching result and a valid NZB file. An authenticated NewzBay test returned HTTP 429, so a live download from it remains unverified. A live search and NZB retrieval succeeded for DrunkenSlug with a 40-character hexadecimal ID. NZBFinder requires a premium membership for API access; a free account may return HTTP 401 with API error 102. Provider availability and terms can change. HTML fallbacks may stop working if a provider changes its pages or blocks automated access. NZBPort does not bypass access controls or CAPTCHAs.

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
- **Connection settings and window height:** Separate group boxes organize the SABnzbd connection and optional search provider keys. The window grows or shrinks to fit its content within the available screen height. Scroll when more space is needed. A size you set by hand stays in effect until you reopen the window.
- **Launch at login:** Enable or disable startup from the app menu, menu bar menu, or gear menu. Choose **Allow in macOS…** if macOS asks for approval. NZBPort stays in the menu bar at login; launching it manually opens the window. If SABnzbd is still starting, NZBPort retries the category request up to three times, waiting 2, 5, then 10 seconds. It still reports persistent failures and rejected credentials. Manual launches keep their existing behavior.

## Updates, project links and source code

- **Check for Updates:** Check GitHub for a newer release, optionally including test releases. NZBPort opens the release page; it does not download or install updates automatically.
- **About NZBPort:** Open the GitHub project or the developer’s [portfolio](https://schrotty74.github.io/Portfolio/) in your default browser.
- **Build from source:** NZBPort’s application code is written in Swift with Apple system frameworks. No third-party packages are required. See [build instructions](../README.md#build) and [privacy and service limits](../README.md#privacy-and-service-limits).

## How a link becomes a download

1. A browser hands a `nzblnk:` URL to the registered macOS app. A browser confirmation may appear first.
2. NZBPort parses the search identifier (`h`), title (`t`), optional password (`p`) and repeated group fields (`g`). It accepts percent-encoded text and expands abbreviated `a.b.` groups for NZBIndex.
3. The app fetches the current SABnzbd categories and applies your local hidden-category choices. You can filter the category buttons by name.
4. Selecting a category starts the lookup in NZBIndex, NZBKing and BinSearch. If none finds the NZB, the app searches configured providers by release title, in order: Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder and Videothek. Each provider needs its own saved API key.
5. NZBPort sends SABnzbd the public download URL or the NZB file it retrieved from an indexer, along with the title, category and optional archive password. SABnzbd downloads the Usenet articles.
6. A confirmed submission closes the window or advances to the next waiting link. An error remains visible in the window. If a submission times out, check the SABnzbd queue before trying again to avoid duplicate jobs.

NZBIndex results with multiple distinct collection IDs are rejected by that provider; the fallback then continues. The HTML providers use the first supported result in their response. Search results are not a guarantee of the content or its availability. NZBPort does not manage Usenet accounts.

Videothek is available from 0.2.6. Videothek approved both the Mac app and the iOS userscript. The latest authenticated test returned API code 500, so search and NZB retrieval remain unverified.
