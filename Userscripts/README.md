# nzb-load for iOS Userscripts

[Deutsch](README.de.md)

LordBex wrote the original [nzb-load userscript](https://github.com/LordBex/nzb-load). [This version](nzb-load.user.js) is maintained alongside NZBPort. The userscript runs separately from the Mac app.

Version: `v2.3.7`.

## Changes in this version

- Added six optional indexers after the existing public search providers. These are Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder and Videothek. Each has its own API key field, which is empty by default. Videothek requires API access and approval for the tool.
- Made “Save NZB file” available from the category menu, when SABnzbd is unconfigured or unreachable, and after a failed submission. The script checks the NZB response before saving and preserves any archive password in the filename.
- Restored the use of the configured default category when sending directly to SABnzbd.
- Removed NZBGet support and the unused success notification setting. Settings saved by older versions are carried forward where supported.
