import Foundation

public enum RelayError: LocalizedError, Sendable {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let message): message }
    }
}

public struct HTTPResult: Sendable {
    public let data: Data
    public let status: Int
    public init(data: Data, status: Int) { self.data = data; self.status = status }
}

public protocol HTTPTransport: Sendable {
    func perform(_ request: URLRequest) async throws -> HTTPResult
}

public struct SessionTransport: HTTPTransport {
    public init() {}
    public func perform(_ request: URLRequest) async throws -> HTTPResult {
        try Task.checkCancellation()
        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RelayError.message("Der Dienst hat keine HTTP-Antwort geliefert.")
        }
        return HTTPResult(data: body, status: http.statusCode)
    }
}

public enum FormEncoding {
    public static func encode(_ fields: [(String, String)]) -> Data {
        func escape(_ text: String) -> String {
            text.utf8.map { byte -> String in
                switch byte {
                case 65...90, 97...122, 48...57, 45, 46, 95, 126:
                    String(UnicodeScalar(byte))
                case 32: "+"
                default: String(format: "%%%02X", byte)
                }
            }.joined()
        }
        return Data(fields.map { "\(escape($0.0))=\(escape($0.1))" }.joined(separator: "&").utf8)
    }
}
