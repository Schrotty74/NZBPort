import Testing
@testable import RelayCore

@Test func parsesNormalizedNamesAndAllAttributeForms() throws {
    let tags = SearchHTML.tags(in: #"<A HREF="https://host/x?q=1>0" DATA-ID='A&amp;B' class=result download DISABLED="">"#)
    let anchor = try #require(tags.first)
    #expect(anchor.name == "a")
    #expect(anchor.isClosing == false)
    #expect(anchor.attributes["href"] == "https://host/x?q=1>0")
    #expect(anchor.attributes["data-id"] == "A&B")
    #expect(anchor.attributes["class"] == "result")
    #expect(anchor.attributes["download"] == "")
    #expect(anchor.attributes["disabled"] == "")
}

@Test func decodesNamedAndNumericEntitiesInAttributeValues() throws {
    let tag = try #require(SearchHTML.tags(in: #"<a title="&quot;&apos;&lt;&gt;&amp; &#65; &#x1F600;">"#).first)
    #expect(tag.attributes["title"] == "\"'<>& A 😀")
}

@Test func skipsCommentsAndScriptOrStyleRawText() {
    let html = #"<!-- <a href="comment"> --><script>const x = "<a href='script'>";</script><style>.x:after{content:"<a>"}</style><a href="kept">"#
    let tags = SearchHTML.tags(in: html)
    #expect(tags.map(\.name) == ["script", "style", "a"])
    #expect(tags.last?.attributes["href"] == "kept")
}

@Test func toleratesMalformedTagsAndFindsLaterWellFormedTags() {
    let tags = SearchHTML.tags(in: #"< a><a href="unterminated><a HREF=ok>"#)
    #expect(tags.count == 1)
    #expect(tags.first?.attributes["href"] == "ok")
}

@Test func closingTagsAndFormBoundariesAreReported() {
    let tags = SearchHTML.tags(in: #"<form action=/search><input name=q value=hello><input disabled><a href=/item>NZB</a></form>"#)
    #expect(tags.map(\.name) == ["form", "input", "input", "a", "a", "form"])
    #expect(tags[0].attributes["action"] == "/search")
    #expect(tags[1].attributes["value"] == "hello")
    #expect(tags[2].attributes["disabled"] == "")
    #expect(tags[4].isClosing)
    #expect(tags[5].isClosing)
}
