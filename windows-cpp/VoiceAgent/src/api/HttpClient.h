// HttpClient.h: Modern HTTP client wrapper using libcurl
// Handles redirects, SSL, timeouts automatically
//
#pragma once

#include <string>
#include <map>
#include <functional>
#include <memory>

// Forward declaration to avoid including curl.h in header
typedef void CURL;

/// Simple HTTP client using libcurl
/// Automatically handles redirects (including 308), SSL, timeouts
class HttpClient {
public:
    /// Callback type for HTTP response
    /// Parameters: (success, response_or_error, status_code)
    using ResponseCallback = std::function<void(bool, const std::string&, int)>;
    
    HttpClient();
    ~HttpClient();
    
    /// Perform HTTP POST request
    /// @param url Target URL
    /// @param body Request body (JSON string)
    /// @param headers Request headers (key-value pairs)
    /// @param callback Response callback
    void PostAsync(
        const std::string& url,
        const std::string& body,
        const std::map<std::string, std::string>& headers,
        ResponseCallback callback
    );
    
    /// Set timeout in seconds (default: 30)
    void SetTimeout(int seconds);
    
    /// Enable/disable SSL certificate verification (default: true)
    void SetVerifySSL(bool verify);
    
private:
    struct Impl;
    std::shared_ptr<Impl> m_impl;
};

