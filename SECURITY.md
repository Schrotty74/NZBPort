# Security

Do not include API keys, private server addresses, personal NZBlnk links or screenshots containing credentials in public issues.

To report a suspected vulnerability, use a private vulnerability report on GitHub if the repository offers that option. Otherwise open an issue containing only a request for a private reporting channel, without exploit details or secrets.

## Local settings and network access

NZBPort stores the SABnzbd endpoint and API key unencrypted in local app preferences. It does not use Keychain. Anyone with access to those preferences may be able to read them. HTTP endpoints are supported; use HTTPS or a trusted VPN on untrusted networks.

Search metadata is sent to NZBIndex and, when needed, NZBKing or BinSearch. SABnzbd credentials are not included in search queries. Link submissions require a category selection in the app.

Release packages contain the app, not local preferences. Builds are ad hoc signed and not notarized by Apple. A source review or passing tests do not guarantee the absence of vulnerabilities.
