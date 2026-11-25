# NZBPort userscript for iPhone

[Deutsch](README.de.md)

Open [NZBPort.user.js](https://raw.githubusercontent.com/Schrotty74/NZBPort/main/Userscripts/NZBPort.user.js) in Safari and install it with the Userscripts extension. The script runs independently of the Mac app. If you have a JSON backup from the previous script, you can import it under **Import / Export** in the script settings and save it.

## What it does

- Tap an NZBlnk to look up the release. With category selection enabled, the script opens the menu after a match and sends the NZB to SABnzbd when you choose a category.
- On NewzBay, select **Download → Send to SABnzbd**. The script uses your NewzBay sign-in in Safari and opens the category menu.
- Choose **Save NZB file** to keep a local copy. The script checks that the response is an NZB file before saving it.
- Add API keys for Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder or Videothek in the settings. Videothek requires API access and approval for the tool. Exported settings include the API keys, so keep the backup private.
