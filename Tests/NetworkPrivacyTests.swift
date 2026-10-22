// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import Foundation

enum NetworkPrivacyTests {
    static func run(_ suite: TestSuite) {
        suite.expect(!NetworkPrivacy.allowsContentUploads && !NetworkPrivacy.allowsRemoteMetadata
                     && !NetworkPrivacy.allowsAccountQueries, "privacy policy cannot be re-enabled by imported preferences")
        let id = String(repeating: "a", count: 32)
        var deletion = URLRequest(url: URL(string: "https://screenshots.vorssaint.com/v1/screenshots/" + id)!)
        deletion.httpMethod = "DELETE"
        suite.expect(NetworkPrivacy.permitsRevocation(deletion), "existing screenshot links can still be revoked")
        deletion.url = URL(string: "https://screenshots.vorssaint.com/v1/recordings/" + id)!
        suite.expect(NetworkPrivacy.permitsRevocation(deletion), "existing recording links can still be revoked")
        for raw in ["http://screenshots.vorssaint.com/v1/recordings/" + id,
                    "https://screenshots.vorssaint.com.evil.invalid/v1/recordings/" + id,
                    "https://screenshots.vorssaint.com:8443/v1/recordings/" + id,
                    "https://user:password@screenshots.vorssaint.com/v1/recordings/" + id,
                    "https://screenshots.vorssaint.com/v1/recordings/" + id + "?token=secret",
                    "https://screenshots.vorssaint.com/v1/feedback"] {
            deletion.url = URL(string: raw)!
            suite.expect(!NetworkPrivacy.permitsRevocation(deletion), "deletion credentials cannot travel to untrusted URLs")
        }
        deletion.url = URL(string: "https://screenshots.vorssaint.com/v1/screenshots/" + id)!
        for method in ["GET", "POST", "PUT", "PATCH"] {
            deletion.httpMethod = method
            suite.expect(!NetworkPrivacy.permitsRevocation(deletion), "revocation exception cannot upload or read: " + method)
        }
        let environment = NetworkPrivacy.brewEnvironment(["HOMEBREW_NO_ANALYTICS": "0", "https_proxy": "http://127.0.0.1:8080"])
        suite.expect(environment["HOMEBREW_NO_ANALYTICS"] == "1" && environment["HOMEBREW_NO_AUTO_UPDATE"] == "1"
                     && environment["https_proxy"] == "http://127.0.0.1:8080", "brew policy overrides analytics while preserving proxy settings")
        // These callbacks must be local URLProtocol failures, not DNS errors or
        // replies. No endpoint is contacted and no real user data is provided.
        for configuration in [NetworkPrivacy.offlineConfiguration(), NetworkPrivacy.revocationConfiguration()] {
            let session = URLSession(configuration: configuration)
            let done = DispatchSemaphore(value: 0)
            var request = URLRequest(url: URL(string: "https://privacy-test.invalid/upload")!)
            request.httpMethod = "POST"
            request.httpBody = Data("synthetic test fixture".utf8)
            session.dataTask(with: request) { data, response, error in
                let code = (error as? URLError)?.code
                suite.expect(response == nil && (data?.isEmpty ?? true)
                             && (code == .notConnectedToInternet || code == .noPermissionsToReadFile),
                             "session denies an upload locally before any HTTP response")
                done.signal()
            }.resume()
            suite.expect(done.wait(timeout: .now() + 3) == .success, "denied networking never waits for a remote server")
            session.invalidateAndCancel()
        }
    }
}
