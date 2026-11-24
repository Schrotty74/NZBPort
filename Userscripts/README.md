# nzb-load for iOS Userscripts

[Deutsch](README.de.md)

LordBex wrote the original [nzb-load userscript](https://github.com/LordBex/nzb-load). [This version](nzb-load.user.js) is maintained alongside NZBPort. The userscript runs separately from the Mac app.

Version: `v2.3.7`.

## Changes in this version

- Added six optional indexers after the existing public search providers. These are Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder and Videothek. Each has its own API key field, which is empty by default. Videothek requires API access and approval for the tool.
- Made “Save NZB file” available from the category menu, when SABnzbd is unconfigured or unreachable, and after a failed submission. The script checks the NZB response before saving and preserves any archive password in the filename.
- Restored the use of the configured default category when sending directly to SABnzbd.
- Removed NZBGet support and the unused success notification setting. Settings saved by older versions are carried forward where supported.

## Videothek identification

Every Videothek search and NZB-file request uses:

```text
NZBPort/nzb-load/2.3.7 (NZB link search; iOS Userscripts)
```

The header is passed to `indexerRequest` for both the search and the subsequent file fetch. The userscript manager performs the requests; this source-level header setting has not been verified in a live iPhone capture.

The native Mac client has its own fixed identification string in [NewznabClient.swift](../Sources/RelayCore/NewznabClient.swift):

```text
NZBPort/0.2.5 (+https://github.com/Schrotty74/NZBPort)
```

Do not put API keys in this repository, download links, issues, or support messages.
