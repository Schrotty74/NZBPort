import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct NZBExportItem: Transferable {
    let data: Data
    static var contentType: UTType { UTType(filenameExtension: "nzb") ?? .xml }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: contentType) { item in item.data }
    }
}
