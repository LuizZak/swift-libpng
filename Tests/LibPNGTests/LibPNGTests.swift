import XCTest
import CLibPNG
import LibPNG

class LibPNGTests: XCTestCase {
    func testReadFromFile() throws {
        let path = "\(pathToResources())/bl-getting-started-1.png"

        let pngFile = try readPngFile(path)

        XCTAssertEqual(pngFile.bitDepth, 8)
        XCTAssertEqual(pngFile.colorType, png_byte(PNG_COLOR_TYPE_RGB_ALPHA))
        XCTAssertEqual(pngFile.width, 480)
        XCTAssertEqual(pngFile.height, 480)
        XCTAssertEqual(pngFile.rows.count, Int(pngFile.height))
        XCTAssert(pngFile.rows.allSatisfy { $0.count == Int(pngFile.rowLength) })
    }

    func testWritePngData() throws {
        let path = "\(pathToResources())/bl-getting-started-1.png"
        let pngFile = try readPngFile(path)

        let data = try writePngData(file: pngFile)
        let fromData = try readPngFromData(data)

        XCTAssertEqual(pngFile, fromData)
    }

    func testFromArgb() throws {
        let path = "\(pathToResources())/test.png"
        let data = try writePngData(file: try readPngFile(path))
        let fromData = try readPngFromData(data)
        let mockData = allocateMockImage(width: 200, height: 200)

        let pngFile = mockData.withUnsafeBufferPointer { mockData in
            PNGFile.fromArgb(mockData, width: 200, height: 200)
        }

        XCTAssertEqual(pngFile, fromData)
    }

    func testFromRgba() {
        let pngFile = PNGFile.fromRgba([1, 2, 3, 4], width: 2, height: 2)

        XCTAssertEqual(pngFile.width, 2)
        XCTAssertEqual(pngFile.height, 2)
        XCTAssertEqual(pngFile.bitDepth, 8)
        XCTAssertEqual(pngFile.colorType, png_byte(PNG_COLOR_TYPE_RGB_ALPHA))
        XCTAssertEqual(pngFile.rowLength, 2 * MemoryLayout<UInt32>.size)
        XCTAssertEqual(pngFile.rows.count, Int(pngFile.height))
        XCTAssert(pngFile.rows.allSatisfy { $0.count == Int(pngFile.rowLength) })
    }
}

// MARK: - Test internals

func pathToResources() -> String {
    let file = #file
    return (((file as NSString)
        .deletingLastPathComponent as NSString)
        .appendingPathComponent("TestResources") as NSString)
        .standardizingPath
}

/// Creates a checkerboard-pattern image with cells 10x10 wide.
func allocateMockImage(width: Int, height: Int) -> [UInt32] {
    var pixels: [UInt32] = []
    let checkerSplit = width / 10

    for y in 0..<height {
        let yBit = (y / checkerSplit) % 2

        for x in 0..<width {
            let xBit = (x / checkerSplit) % 2
            let bit = yBit ^ xBit

            if bit == 1 {
                pixels.append(.max)
            } else {
                pixels.append(.zero | 0xFF000000)
            }
        }
    }

    return pixels
}
