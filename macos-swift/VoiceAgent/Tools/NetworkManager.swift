//
//  NetworkManager.swift
//  VoiceAgent
//

import Cocoa

public enum AgoraTokenType: Int {
    case rtc = 1
    case rtm = 2
    case chat = 3
}

public class NetworkManager: NSObject {
    enum HTTPMethods: String {
        case GET
        case POST
    }

    public typealias SuccessClosure = ([String: Any]) -> Void
    public typealias FailClosure = (String) -> Void

    private var sessionConfig: URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return config
    }

    public static let shared = NetworkManager()

    public func generateToken(
        channelName: String,
        uid: String,
        expire: Int = 86400,
        types: [AgoraTokenType],
        success: @escaping (String?) -> Void
    ) {
        let params = [
            "appCertificate": KeyCenter.AGORA_APP_CERTIFICATE,
            "appId": KeyCenter.AGORA_APP_ID,
            "channelName": channelName,
            "expire": expire,
            "src": "iOS",
            "ts": 0,
            "types": types.map({ NSNumber(value: $0.rawValue) }),
            "uid": uid
        ] as [String: Any]
        let url = "https://service.apprtc.cn/toolbox/v2/token/generate"
        NetworkManager.shared.postRequest(urlString: url, params: params) { response in
            let data = response["data"] as? [String: String]
            let token = data?["token"] as? String
            success(token)
        } failure: { error in
            print("[NetworkManager] generateToken failed: \(error)")
            success(nil)
        }
    }

    public func getRequest(urlString: String, params: [String: Any]?, headers: [String: String]? = nil, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .GET, headers: headers, success: success, failure: failure)
        }
    }

    public func postRequest(urlString: String, params: [String: Any]?, headers: [String: String]? = nil, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .POST, headers: headers, success: success, failure: failure)
        }
    }

    private func request(urlString: String,
                         params: [String: Any]?,
                         method: HTTPMethods,
                         headers: [String: String]? = nil,
                         success: SuccessClosure?,
                         failure: FailClosure?) {
        let session = URLSession(configuration: sessionConfig)
        guard let request = getRequest(urlString: urlString,
                                       params: params,
                                       method: method,
                                       headers: headers) else { return }
        session.dataTask(with: request) { data, response, _ in
            DispatchQueue.main.async {
                self.checkResponse(response: response, data: data, success: success, failure: failure)
            }
        }.resume()
    }

    private func getRequest(urlString: String,
                            params: [String: Any]?,
                            method: HTTPMethods,
                            headers: [String: String]? = nil) -> URLRequest? {
        var string = urlString
        if method == .GET, let params = params {
            let query = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            string += string.contains("?") ? "&\(query)" : "?\(query)"
        }

        guard let url = URL(string: string) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { key, value in request.setValue(value, forHTTPHeaderField: key) }

        if method == .POST {
            let bodyParams = params ?? [:]
            request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams, options: .sortedKeys)
        }
        return request
    }

    private func checkResponse(response: URLResponse?, data: Data?, success: SuccessClosure?, failure: FailClosure?) {
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...201:
                if let resultData = data {
                    let result = try? JSONSerialization.jsonObject(with: resultData)
                    success?(result as! [String: Any])
                } else {
                    failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
                }
            default:
                failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
            }
        } else {
            failure?("Invalid response")
        }
    }
}
