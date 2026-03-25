#pragma once

#include <string>
#include <Windows.h>
#include <atlstr.h>

// UTF-8 and Unicode conversion utilities for MFC applications
class StringUtils {
public:
    // Convert UTF-8 std::string to Unicode CString for MFC controls
    static CString Utf8ToCString(const std::string& utf8Str) {
        if (utf8Str.empty()) {
            return CString();
        }

        // Convert UTF-8 to UTF-16 (Unicode)
        int wideCharLen = MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, nullptr, 0);
        if (wideCharLen == 0) {
            return CString();
        }

        wchar_t* wideCharBuf = new wchar_t[wideCharLen];
        MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, wideCharBuf, wideCharLen);
        
        CString result(wideCharBuf);
        delete[] wideCharBuf;
        
        return result;
    }

    // Convert UTF-8 std::string to std::wstring for logging
    static std::wstring Utf8ToWString(const std::string& utf8Str) {
        if (utf8Str.empty()) {
            return std::wstring();
        }

        int wideCharLen = MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, nullptr, 0);
        if (wideCharLen == 0) {
            return std::wstring();
        }

        wchar_t* wideCharBuf = new wchar_t[wideCharLen];
        MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, wideCharBuf, wideCharLen);
        
        std::wstring result(wideCharBuf);
        delete[] wideCharBuf;
        
        return result;
    }

    // Convert UTF-8 std::string to GBK std::string (for console/log if needed)
    static std::string Utf8ToGBK(const std::string& utf8Str) {
        if (utf8Str.empty()) {
            return std::string();
        }

        // First convert UTF-8 to UTF-16
        int wideCharLen = MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, nullptr, 0);
        if (wideCharLen == 0) {
            return std::string();
        }

        wchar_t* wideCharBuf = new wchar_t[wideCharLen];
        MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, wideCharBuf, wideCharLen);

        // Then convert UTF-16 to GBK
        int gbkLen = WideCharToMultiByte(CP_ACP, 0, wideCharBuf, -1, nullptr, 0, nullptr, nullptr);
        if (gbkLen == 0) {
            delete[] wideCharBuf;
            return std::string();
        }

        char* gbkBuf = new char[gbkLen];
        WideCharToMultiByte(CP_ACP, 0, wideCharBuf, -1, gbkBuf, gbkLen, nullptr, nullptr);

        std::string result(gbkBuf);
        delete[] wideCharBuf;
        delete[] gbkBuf;

        return result;
    }

    // Convert CString to UTF-8 std::string
    static std::string CStringToUtf8(const CString& cstr) {
        if (cstr.IsEmpty()) {
            return std::string();
        }

        // CString is already UTF-16, convert to UTF-8
        int utf8Len = WideCharToMultiByte(CP_UTF8, 0, cstr, -1, nullptr, 0, nullptr, nullptr);
        if (utf8Len == 0) {
            return std::string();
        }

        char* utf8Buf = new char[utf8Len];
        WideCharToMultiByte(CP_UTF8, 0, cstr, -1, utf8Buf, utf8Len, nullptr, nullptr);

        std::string result(utf8Buf);
        delete[] utf8Buf;

        return result;
    }
};

