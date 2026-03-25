//
//  HTTPClient.swift
//  VoiceAgent
//
//  Created on 2025
//  Copyright © 2025 Agora. All rights reserved.
//

import Foundation

// MARK: - HTTP Client
/// Unified HTTP client for network requests
class HTTPClient {
    
    // MARK: - Request Methods
    
    /// POST request with JSON body
    /// - Parameters:
    ///   - urlString: URL string
    ///   - params: Request parameters (will be converted to JSON)
    ///   - headers: Additional headers (optional)
    ///   - success: Success callback with response JSON
    ///   - failure: Failure callback with error message
    static func post(
        urlString: String,
        params: [String: Any]? = nil,
        headers: [String: String]? = nil,
        success: (([String: Any]) -> Void)?,
        failure: ((String) -> Void)?
    ) {
        guard let url = URL(string: urlString) else {
            failure?("Invalid URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Serialize params to JSON
        if let params = params {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: params)
            } catch {
                failure?("Failed to serialize params: \(error.localizedDescription)")
                return
            }
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network error
            if let error = error {
                DispatchQueue.main.async {
                    failure?(error.localizedDescription)
                }
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    failure?("Invalid response")
                }
                return
            }
            
            // Check status code
            guard httpResponse.statusCode == 200 else {
                let errorMsg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                DispatchQueue.main.async {
                    failure?("HTTP \(httpResponse.statusCode): \(errorMsg)")
                }
                return
            }
            
            // Validate data
            guard let data = data else {
                DispatchQueue.main.async {
                    failure?("No data received")
                }
                return
            }
            
            // Parse JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        success?(json)
                    }
                } else {
                    DispatchQueue.main.async {
                        failure?("Failed to parse response as JSON object")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    failure?("JSON parsing error: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
    
    /// POST request with Result type callback
    /// - Parameters:
    ///   - urlString: URL string
    ///   - params: Request parameters (will be converted to JSON)
    ///   - headers: Additional headers (optional)
    ///   - completion: Completion callback with Result
    static func post(
        urlString: String,
        params: [String: Any]? = nil,
        headers: [String: String]? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        post(
            urlString: urlString,
            params: params,
            headers: headers,
            success: { json in
                completion(.success(json))
            },
            failure: { errorMsg in
                let error = NSError(
                    domain: "HTTPClient",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: errorMsg]
                )
                completion(.failure(error))
            }
        )
    }
    
    /// GET request
    /// - Parameters:
    ///   - urlString: URL string
    ///   - headers: Additional headers (optional)
    ///   - completion: Completion callback with Result
    static func get(
        urlString: String,
        headers: [String: String]? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            let error = NSError(
                domain: "HTTPClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"]
            )
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(
                    domain: "HTTPClient",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMsg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                let error = NSError(
                    domain: "HTTPClient",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMsg)"]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let error = NSError(
                    domain: "HTTPClient",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(json))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Generate Basic Authorization header
    /// - Parameters:
    ///   - username: Username (e.g., REST_KEY)
    ///   - password: Password (e.g., REST_SECRET)
    /// - Returns: Base64 encoded authorization header value
    static func generateBasicAuth(username: String, password: String) -> String {
        let credentials = "\(username):\(password)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        return "Basic \(base64Credentials)"
    }
}

