import XCTest
@testable import LyriCarCore

final class LRCParserTests: XCTestCase {
    func testParsesMetadataMultipleTimestampsAndOffset() throws {
        let source = """
        [ar:Example Artist]
        [ti:Example Song]
        [offset:250]
        [00:01.50][00:03.000]First line
        [00:05.25]<00:05.25>Second line
        """

        let result = try LRCParser().parse(source)
        XCTAssertEqual(result.metadata["ar"], "Example Artist")
        XCTAssertEqual(result.lines.count, 3)
        XCTAssertEqual(result.lines[0].timestamp, 1.75, accuracy: 0.001)
        XCTAssertEqual(result.lines[1].timestamp, 3.25, accuracy: 0.001)
        XCTAssertEqual(result.lines[2].text, "Second line")
    }

    func testRejectsUntimedText() {
        XCTAssertThrowsError(try LRCParser().parse("A plain lyric without timestamps")) { error in
            XCTAssertEqual(error as? LRCParserError, .noTimedLines)
        }
    }

    func testParsesHourTimestamp() throws {
        let result = try LRCParser().parse("[01:02:03.500]Long-form timestamp")
        XCTAssertEqual(result.lines[0].timestamp, 3_723.5, accuracy: 0.001)
    }
}
