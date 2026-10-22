// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import Foundation

/// This personal build never uploads user content or performs optional remote
/// lookups. These are build policy, not preferences an import can reactivate.
/// Explicit speed tests, user-requested package operations and opening links
/// in the user's browser remain separate, visible actions.
enum NetworkPrivacy {
    static let allowsContentUploads = false
    static let allowsRemoteMetadata = false
    static let allowsAccountQueries = false

    static func offlineConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OfflineURLProtocol.self]
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        return config
    }

    static let offlineSession = URLSession(configuration: offlineConfiguration())

    /// Keep revocation of already-created links possible without allowing new
    /// uploads. Imported URLs cannot send deletion credentials to another host.
    static func permitsRevocation(_ request: URLRequest) -> Bool {
        guard request.httpMethod == "DELETE", let url = request.url,
              url.scheme == "https", url.host == "screenshots.vorssaint.com",
              url.port == nil || url.port == 443, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return false }
        return url.path.range(of: "^/v1/(screenshots|recordings)/[A-Za-z0-9_-]{32}$", options: .regularExpression) != nil
    }

    static func revocationConfiguration() -> URLSessionConfiguration {
        let config = offlineConfiguration()
        config.protocolClasses = [RevocationURLProtocol.self]
        config.httpShouldSetCookies = false
        return config
    }

    static func brewEnvironment(_ base: [String: String]) -> [String: String] {
        base.merging(["HOMEBREW_NO_ANALYTICS": "1", "HOMEBREW_NO_AUTO_UPDATE": "1",
                      "HOMEBREW_NO_ENV_HINTS": "1"]) { _, policy in policy }
    }
}

/// Defense in depth: denied sessions fail locally before DNS or HTTP, even if
/// a future caller accidentally bypasses a feature's early return.
private final class OfflineURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}

private final class RevocationURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { !NetworkPrivacy.permitsRevocation(request) }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.noPermissionsToReadFile)) }
    override func stopLoading() {}
}

/// A deletion token must never travel through an HTTP redirect.
final class NetworkRevocationDelegate: NSObject, URLSessionTaskDelegate {
    static let shared = NetworkRevocationDelegate()
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
