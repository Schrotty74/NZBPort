# nzb-load for iOS Userscripts

LordBex wrote the original [nzb-load userscript](https://github.com/LordBex/nzb-load). We adapted [this copy](nzb-load.user.js) for use alongside NZBPort and added support for Videothek. The userscript runs separately from the Mac app.

Version: `v2.3.7`.

The script resolves NZBlnk links, sends NZB files to SABnzbd, and offers local NZB saving. Provider keys are empty by default and must be entered in the script settings. Videothek is optional and requires the account permissions and tool approval set by Videothek.

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
