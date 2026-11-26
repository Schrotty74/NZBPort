# Security

Do not include API keys, private server addresses, personal NZBlnk links or screenshots containing credentials in public issues.

To report a suspected vulnerability, use a private vulnerability report on GitHub if the repository offers that option. Otherwise open an issue containing only a request for a private reporting channel, without exploit details or secrets.

## Local settings and network access

NZBPort stores the SABnzbd endpoint and API key unencrypted in local app preferences. It does not use Keychain. Anyone with access to those preferences may be able to read them. HTTP endpoints are supported; use HTTPS or a trusted VPN on untrusted networks.

NZBIndex, NZBKing and BinSearch receive the link's search identifier. Configured Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder and Videothek accounts receive the release title and their own API key. Easynews receives the link's search identifier and the Easynews username and password over HTTPS. NZBPort saves provider credentials locally without encryption. Mac settings exports include them in plain text. SABnzbd credentials are not included in search queries. NZBPort downloads authenticated indexer results itself and sends the NZB file to SABnzbd. For each submission, NZBPort uses a category selected by the user or assigned by the optional automatic category rules.

Adding or deleting a category changes the configured SABnzbd server. Deletion requires confirmation, and the default category is protected. Hiding categories and changing favorites affect only NZBPort's local display preferences.

Release packages contain the app, not local preferences. Builds are ad hoc signed and not notarized by Apple. A source review or passing tests do not guarantee the absence of vulnerabilities.
