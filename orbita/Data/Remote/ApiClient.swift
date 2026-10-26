import Foundation

// The HTTP client of the Orbita API. `baseURL` is e.g. `http://192.168.1.10:3001/api/v1`;
// requests use paths relative to it (`auth/login`). Errors are not thrown for a status: they are
// read from the response (`ApiResponse.requireSuccess`).

/// Fields the API adds later are ignored (Codable does it by default), so an older app keeps
/// working. The API uses snake_case.
enum ApiJson {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}

/// The API sends amounts and rates as text ("1245.80"), never as a JSON number, so no platform
/// reads them as a Double. This reads the literal text (also a number, to be safe) and always
/// writes text. Every amount and rate of a DTO must use it.
struct ApiDecimal: Codable, Hashable {
    let text: String

    init(_ value: Decimal, scale: Int) {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = scale
        formatter.maximumFractionDigits = scale
        formatter.roundingMode = .halfUp
        text = formatter.string(from: value as NSDecimalNumber) ?? "0"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            text = string
        } else {
            text = "\(try container.decode(Decimal.self))"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    var value: Decimal { Decimal(string: text, locale: Locale(identifier: "en_US")) ?? 0 }
}

/// Every successful response of the API: { "data": ... }.
struct DataEnvelope<T: Decodable>: Decodable {
    let data: T
}

private struct ApiErrorEnvelope: Decodable {
    struct Body: Decodable {
        var code: String?
        var details: [FieldError]?
    }

    struct FieldError: Decodable {
        var field: String?
        var code: String?
    }

    var error: Body?
}

/// The domain error for a `code` of the API.
private func dataError(for code: String) -> DataError {
    switch code {
    case "INVALID_CREDENTIALS": .invalidCredentials
    case "EMAIL_ALREADY_REGISTERED": .emailAlreadyRegistered
    case "NOT_FOUND": .notFound
    case "CATEGORY_NAME_TAKEN": .nameTaken
    case "FX_RATE_NOT_CONFIGURED": .fxNotConfigured
    case "PURCHASE_ALREADY_PAID": .purchaseAlreadyPaid
    case "CARD_HAS_PENDING_PURCHASES": .cardHasPendingPurchases
    case "PAYMENT_EXPENSE_LOCKED": .paymentLocked
    case "SESSION_EXPIRED", "UNAUTHORIZED": .sessionExpired
    case "TOO_MANY_REQUESTS": .tooManyRequests
    case "RESET_CODE_INVALID": .resetCodeInvalid
    case "GOOGLE_UNAVAILABLE": .googleUnavailable
    case "GOOGLE_INVALID": .googleInvalid
    case "GOOGLE_CHALLENGE_EXPIRED": .googleChallengeExpired
    case "GOOGLE_LINK_REQUIRED": .googleLinkRequired
    case "GOOGLE_IDENTITY_CONFLICT": .googleIdentityConflict
    default: .unknown
    }
}

struct ApiRequest {
    var method = "GET"
    var path: String
    var query: [URLQueryItem] = []
    var body: Data?

    static func get(_ path: String, query: [URLQueryItem] = []) -> ApiRequest {
        ApiRequest(method: "GET", path: path, query: query)
    }

    static func send<Body: Encodable>(_ method: String, _ path: String, _ body: Body?) throws -> ApiRequest {
        ApiRequest(method: method, path: path, body: try body.map { try ApiJson.encoder.encode($0) })
    }

    static func post(_ path: String) -> ApiRequest { ApiRequest(method: "POST", path: path) }

    static func delete(_ path: String) -> ApiRequest { ApiRequest(method: "DELETE", path: path) }
}

struct ApiResponse {
    let status: Int
    let data: Data

    var isSuccess: Bool { (200..<300).contains(status) }

    private var errorBody: ApiErrorEnvelope.Body? {
        try? ApiJson.decoder.decode(ApiErrorEnvelope.self, from: data).error
    }

    var errorCode: String? { errorBody?.code }

    /// A 401 for a wrong password (deleting the account), not for the session: renewing would not
    /// help, and repeating the request would count the wrong password twice.
    var isWrongPassword: Bool { status == 401 && errorCode == "INVALID_CREDENTIALS" }

    /// The error of the response as a `DataException`.
    func toDataException() -> DataException {
        let body = errorBody
        let code = body?.code ?? ""
        if code == "VALIDATION_FAILED" {
            // The first field problem the app knows how to tell; the API sends them in the app's order.
            let invalid = body?.details?.lazy
                .compactMap { $0.code.flatMap(ValidationError.init(rawValue:)) }
                .first
            return DataException(.unknown, invalid: invalid)
        }
        return DataException(dataError(for: code))
    }

    /// Throws the API's error unless the response succeeded.
    @discardableResult
    func requireSuccess() throws -> ApiResponse {
        if !isSuccess { throw toDataException() }
        return self
    }

    /// The `data` of a successful response.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        do {
            return try ApiJson.decoder.decode(DataEnvelope<T>.self, from: data).data
        } catch {
            throw DataException(.unknown)
        }
    }
}

final class ApiClient {
    let baseURL: URL
    private let session: URLSession
    private let userAgent: String

    init(baseURL: URL, session: URLSession = .shared, userAgent: String = ApiClient.defaultUserAgent) {
        self.baseURL = baseURL
        self.session = session
        self.userAgent = userAgent
    }

    /// Names the app and the device: the API keeps it with each session.
    static var defaultUserAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "Orbita-iOS/\(version) (\(ProcessInfo.processInfo.operatingSystemVersionString))"
    }

    /// No connection, or the server could not be reached: told as `network`.
    func send(_ request: ApiRequest, token: String? = nil) async throws -> ApiResponse {
        let base = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
        guard var components = URLComponents(string: base + "/" + request.path) else {
            throw DataException(.unknown)
        }
        if !request.query.isEmpty { components.queryItems = request.query }
        guard let url = components.url else { throw DataException(.unknown) }

        var urlRequest = URLRequest(url: url, timeoutInterval: 20)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        // The same id is in every log line of the API for this request.
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        if let token { urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return ApiResponse(status: status, data: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw DataException(.network)
        }
    }
}
