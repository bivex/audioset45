import AudioSetCore
import XCTest

final class VolumeTests: XCTestCase {

    func test_clampsValuesOutOfRange() {
        XCTAssertEqual(Volume(percent: 150).percent, 100)
        XCTAssertEqual(Volume(percent: -10).percent, 0)
        XCTAssertEqual(Volume(percent: 0).percent, 0)
        XCTAssertEqual(Volume(percent: 100).percent, 100)
    }

    func test_equalityIsByPercent() {
        XCTAssertEqual(Volume(percent: 42), Volume(percent: 42))
        XCTAssertNotEqual(Volume(percent: 42), Volume(percent: 43))
    }

    func test_isSilentOnlyAtZero() {
        XCTAssertTrue(Volume(percent: 0).isSilent)
        XCTAssertFalse(Volume(percent: 1).isSilent)
    }
}
