#if os(Linux)
import Glibc
#endif
import Foundation
import CLibPNG

public struct PNGFile {
    public var width: Int = 0
    public var height: Int = 0
    public var colorType = png_byte()
    public var bitDepth = png_byte()
    public var rows: [[png_byte]] = []
    public var rowLength: Int = 0
}

extension PNGFile: Equatable {
    
}

public func readPngFile(_ filename: String) throws -> PNGFile {
    guard let fp = fopen(filename, "rb") else {
        throw PNGError.couldNotOpenFile
    }
    defer {
        fclose(fp)
    }
    
    guard let png = png_create_read_struct(PNG_LIBPNG_VER_STRING, nil, nil, nil) else {
        throw PNGError.invalidPngFile
    }
    
    guard let info = png_create_info_struct(png) else {
        throw PNGError.invalidPngFile
    }
    
    png_init_io(png, fp)
    
    png_read_info(png, info)
    
    var file = PNGFile()
    
    readPng(file: &file, png: png, info: info)
    
    return file
}

public func readPngFromData(_ data: Data) throws -> PNGFile {
    guard let png = png_create_read_struct(PNG_LIBPNG_VER_STRING, nil, nil, nil) else {
        throw PNGError.invalidPngFile
    }
    
    guard let info = png_create_info_struct(png) else {
        throw PNGError.invalidPngFile
    }
    
    let stream = InputStream(data: data)
    stream.open()
    
    png_set_read_fn(png, Unmanaged.passUnretained(stream).toOpaque()) { png, bytes, length in
        guard let png = png else {
            return
        }
        guard let bytes = bytes else {
            return
        }
        guard let io = png_get_io_ptr(png) else {
            return
        }
        
        let stream = Unmanaged<InputStream>.fromOpaque(io).takeUnretainedValue()
        
        if stream.read(bytes, maxLength: length) == -1 {
            if let error = stream.streamError {
                png_error(png, error.localizedDescription)
            } else {
                png_error(png, "Unknown error reading stream")
            }
        }
    }
    
    png_read_info(png, info)
    
    var file = PNGFile()
    
    readPng(file: &file, png: png, info: info)
    
    return file
}

private func readPng(file: inout PNGFile, png: png_structp, info: png_infop) {
    file.width     = Int(png_get_image_width(png, info))
    file.height    = Int(png_get_image_height(png, info))
    file.colorType = png_get_color_type(png, info)
    file.bitDepth  = png_get_bit_depth(png, info)
    
    // Read any color_type into 8bit depth, RGBA format.
    // See http://www.libpng.org/pub/png/libpng-manual.txt
    
    if file.bitDepth == 16 {
        png_set_strip_16(png)
    }
    
    if file.colorType == PNG_COLOR_TYPE_PALETTE {
        png_set_palette_to_rgb(png)
    }
    
    // PNG_COLOR_TYPE_GRAY_ALPHA is always 8 or 16bit depth.
    if file.colorType == PNG_COLOR_TYPE_GRAY && file.bitDepth < 8 {
        png_set_expand_gray_1_2_4_to_8(png)
    }
    
    if png_get_valid(png, info, PNG_INFO_tRNS) != 0 {
        png_set_tRNS_to_alpha(png)
    }
    
    // These color_type don't have an alpha channel then fill it with 0xff.
    if file.colorType == PNG_COLOR_TYPE_RGB ||
        file.colorType == PNG_COLOR_TYPE_GRAY ||
        file.colorType == PNG_COLOR_TYPE_PALETTE {
        
        png_set_filler(png, 0xFF, PNG_FILLER_AFTER)
    }
    
    if file.colorType == PNG_COLOR_TYPE_GRAY || file.colorType == PNG_COLOR_TYPE_GRAY_ALPHA {
        png_set_gray_to_rgb(png)
    }
    
    png_read_update_info(png, info)
    
    /* The easiest way to read the image: */
    let rowBytes = png_get_rowbytes(png, info)
    file.rowLength = rowBytes
    
    var rowPointers: [png_bytep?] = Array(repeating: nil, count: file.height)
    
    for y in 0..<file.height {
        rowPointers[y] = png_malloc(png, rowBytes)?.assumingMemoryBound(to: png_byte.self)
    }
    defer {
        for y in 0..<file.height {
            rowPointers[y]?.deinitialize(count: rowBytes)
        }
    }
    
    rowPointers.withUnsafeMutableBufferPointer { pointer in
        let rowsAddress = pointer.baseAddress
        
        png_read_image(png, rowsAddress)
    }
    
    for y in 0..<file.height {
        let buffer = UnsafeBufferPointer(start: rowPointers[y], count: rowBytes)
        file.rows.append(Array(buffer))
    }
}

public func writePngData(file: PNGFile) throws -> Data {
    let data = NSMutableData()
    
    try writePng(file: file, to: data)
    
    return data as Data
}

public func writePngFile(file: PNGFile, filename: String) throws {
    guard let fp = fopen(filename, "wb") else {
        throw PNGError.couldNotOpenFile
    }
    defer {
        fclose(fp)
    }
    
    try writePng(file: file, to: fp)
}

private func writePng(file: PNGFile, to fp: UnsafeMutablePointer<FILE>) throws {
    guard let png = png_create_write_struct(PNG_LIBPNG_VER_STRING, nil, nil, nil) else {
        throw PNGError.invalidPngFile
    }
    
    guard let info = png_create_info_struct(png) else {
        throw PNGError.invalidPngFile
    }
    
    png_init_io(png, fp)
    
    writePng(file: file, png: png, info: info)
}

private func writePng(file: PNGFile, to data: NSMutableData) throws {
    guard let png = png_create_write_struct(PNG_LIBPNG_VER_STRING, nil, nil, nil) else {
        throw PNGError.invalidPngFile
    }
    
    guard let info = png_create_info_struct(png) else {
        throw PNGError.invalidPngFile
    }
    
    let stream = OutputStream(toMemory: ())
    stream.open()
    
    png_set_write_fn(png, Unmanaged.passUnretained(stream).toOpaque()) { png, bytes, size in
        guard let bytes = bytes else { return }
        guard let dataPtr = png_get_io_ptr(png) else {
            return
        }
        
        let stream = Unmanaged<OutputStream>.fromOpaque(dataPtr).takeUnretainedValue()
        
        stream.write(bytes, maxLength: size)
    } _: { _ in
        
    }
    
    writePng(file: file, png: png, info: info)
    
    guard let outputData = stream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? Data else {
        throw PNGError.memoryError
    }
    
    data.append(outputData)
}

private func writePng(file: PNGFile, png: png_structp, info: png_infop) {
    // Output is 8bit depth, RGBA format.
    png_set_IHDR(
        png,
        info,
        png_uint_32(file.width), png_uint_32(file.height),
        Int32(file.bitDepth),
        Int32(file.colorType),
        PNG_INTERLACE_NONE,
        PNG_COMPRESSION_TYPE_DEFAULT,
        PNG_FILTER_TYPE_DEFAULT
    )
    png_write_info(png, info)
    
    // To remove the alpha channel for PNG_COLOR_TYPE_RGB format,
    // Use png_set_filler().
    //png_set_filler(png, 0, PNG_FILLER_AFTER)
    
    var rowPointers: [png_bytep?] = Array(repeating: nil, count: file.height)
    
    for y in 0..<file.height {
        rowPointers[y] = png_malloc(png, file.rowLength)?.assumingMemoryBound(to: png_byte.self)
        let row = file.rows[y]
        
        row.withUnsafeBufferPointer { pointer in
            rowPointers[y]?.assign(from: pointer.baseAddress!, count: pointer.count)
        }
    }
    defer {
        for pointer in rowPointers {
            pointer?.deinitialize(count: file.rowLength)
        }
    }
    
    png_write_image(png, &rowPointers)
    png_write_end(png, nil)
}

private func _writePng(_ png: png_structp, _ bytes: png_bytep, _ length: png_size_t) {
    
}

private func _flushPng(_ png: png_structp) {
    // No-op
}

public enum PNGError: Error {
    case couldNotOpenFile
    case invalidPngFile
    case memoryError
}
