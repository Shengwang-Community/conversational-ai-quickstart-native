// HttpClient.cpp: Modern HTTP client implementation using libcurl
//

#include "../general/pch.h"
#include <memory>
#include <thread>
#include <sstream>
#include "HttpClient.h"
#include "../tools/Logger.h"
#include <curl/curl.h>

// RAII wrapper for CURL cleanup
struct CurlHandle {
    CURL* curl;
    
    CurlHandle() : curl(curl_easy_init()) {}
    ~CurlHandle() { if (curl) curl_easy_cleanup(curl); }
    
    operator CURL*() { return curl; }
};

// Implementation details
struct HttpClient::Impl {
    int timeout = 30;
    bool verifySSL = true;
    
    // Write callback for response data
    static size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* userp) {
        size_t totalSize = size * nmemb;
        userp->append((char*)contents, totalSize);
        return totalSize;
    }
    
    // Perform synchronous HTTP POST (called in async thread)
    void PostSync(
        const std::string& url,
        const std::string& body,
        const std::map<std::string, std::string>& headers,
        HttpClient::ResponseCallback callback
    ) {
        CurlHandle curl;
        if (!curl.curl) {
            LOG_ERROR("[HttpClient] Failed to initialize CURL");
            callback(false, "Failed to initialize CURL", 0);
            return;
        }
        
        std::string responseBody;
        struct curl_slist* headerList = nullptr;
        
        try {
            // Set URL
            curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
            
            // Set POST method
            curl_easy_setopt(curl, CURLOPT_POST, 1L);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, body.size());
            
            // Add headers
            for (const auto& header : headers) {
                std::string headerLine = header.first + ": " + header.second;
                headerList = curl_slist_append(headerList, headerLine.c_str());
            }
            if (headerList) {
                curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headerList);
            }
            
            // Set response callback
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &responseBody);
            
            // ✅ Enable automatic redirect following (301, 302, 303, 307, 308)
            curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
            curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5L);  // Max 5 redirects
            
            // ✅ For 307/308, keep POST method (don't change to GET)
            curl_easy_setopt(curl, CURLOPT_POSTREDIR, CURL_REDIR_POST_ALL);
            
            // Set timeout
            curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
            curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
            
            // SSL settings
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, verifySSL ? 1L : 0L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, verifySSL ? 2L : 0L);
            
            // Enable verbose logging in debug mode
            #ifdef _DEBUG
            curl_easy_setopt(curl, CURLOPT_VERBOSE, 0L);  // Set to 1L for debugging
            #endif
            
            // Perform request
            LOG_INFO("[HttpClient] POST " + url);
            CURLcode res = curl_easy_perform(curl);
            
            // Cleanup headers
            if (headerList) {
                curl_slist_free_all(headerList);
                headerList = nullptr;
            }
            
            // Check result
            if (res != CURLE_OK) {
                std::string error = curl_easy_strerror(res);
                LOG_ERROR("[HttpClient] Request failed: " + error);
                callback(false, error, 0);
                return;
            }
            
            // Get HTTP status code
            long statusCode = 0;
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &statusCode);
            
            // Get effective URL (after redirects)
            char* effectiveUrl = nullptr;
            curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &effectiveUrl);
            if (effectiveUrl && std::string(effectiveUrl) != url) {
                LOG_INFO("[HttpClient] Redirected to: " + std::string(effectiveUrl));
            }
            
            LOG_INFO("[HttpClient] Response status: " + std::to_string(statusCode));
            
            if (statusCode == 200) {
                callback(true, responseBody, (int)statusCode);
            } else {
                LOG_ERROR("[HttpClient] HTTP error: " + std::to_string(statusCode));
                callback(false, responseBody, (int)statusCode);
            }
            
        } catch (const std::exception& e) {
            LOG_ERROR("[HttpClient] Exception: " + std::string(e.what()));
            if (headerList) {
                curl_slist_free_all(headerList);
            }
            callback(false, e.what(), 0);
        }
    }
};

// Constructor / Destructor
// Note: These must be defined in .cpp where Impl is complete (for std::shared_ptr)
HttpClient::HttpClient() : m_impl(std::make_shared<Impl>()) {
    // Initialize libcurl globally (thread-safe)
    static bool curlInitialized = false;
    if (!curlInitialized) {
        curl_global_init(CURL_GLOBAL_ALL);
        curlInitialized = true;
    }
}

// Destructor must be in .cpp to properly delete Impl via shared_ptr
HttpClient::~HttpClient() = default;

// Public methods
void HttpClient::PostAsync(
    const std::string& url,
    const std::string& body,
    const std::map<std::string, std::string>& headers,
    ResponseCallback callback
) {
    // CRITICAL: Capture shared_ptr copy to keep Impl alive during async operation
    // This increments the reference count, preventing Impl from being deleted
    // even if the HttpClient object is destroyed before the thread completes
    auto impl = m_impl;
    
    std::thread([impl, url, body, headers, callback]() {
        impl->PostSync(url, body, headers, callback);
    }).detach();
}

void HttpClient::SetTimeout(int seconds) {
    m_impl->timeout = seconds;
}

void HttpClient::SetVerifySSL(bool verify) {
    m_impl->verifySSL = verify;
}

