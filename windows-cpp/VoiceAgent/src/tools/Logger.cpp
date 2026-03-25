#include "Logger.h"
#include <iostream>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <direct.h>
#include <io.h>

#ifdef _WIN32
#include <windows.h>
#endif

std::string Logger::formatMessage(LogLevel level, const std::string& message) {
    std::ostringstream oss;
    
    // Timestamp
    oss << "[" << getCurrentTime() << "] ";
    
    // Application prefix tag
    oss << "[VoiceAgent] ";
    
    // Log level (fixed spacing - no extra space after level)
    oss << "[" << getLevelString(level) << "] ";
    
    // Message
    oss << message;
    
    return oss.str();
}

void Logger::writeToFile(const std::string& message) {
    // Ensure log directory exists
    std::string logPath = m_logPath;
    size_t lastSlash = logPath.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        std::string logDir = logPath.substr(0, lastSlash);
        if (!logDir.empty()) {
            // Create directory using Windows API
            _mkdir(logDir.c_str());
        }
    }
    
    // Open file if not already open
    if (!m_logFile.is_open()) {
        m_logFile.open(m_logPath, std::ios::app | std::ios::binary);
        if (m_logFile.tellp() == 0) {
            // Write UTF-8 BOM for new files
            m_logFile.write("\xEF\xBB\xBF", 3);
        }
    }
    
    if (m_logFile.is_open()) {
        m_logFile << message << std::endl;
        m_logFile.flush();
    }
}

void Logger::writeToDebug(const std::string& message) {
#ifdef _DEBUG
#ifdef _WIN32
    // Windows debug output - only in debug builds
    OutputDebugStringA((message + "\n").c_str());
#else
    // Unix debug output
    std::cerr << message << std::endl;
#endif
#else
    // In release builds, do nothing to avoid console windows
    (void)message; // Suppress unused parameter warning
#endif
}

std::string Logger::getCurrentTime() {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()) % 1000;
    
    std::ostringstream oss;
    oss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
    oss << "." << std::setfill('0') << std::setw(3) << ms.count();
    
    return oss.str();
}

std::string Logger::getLevelString(LogLevel level) {
    switch (level) {
        case LogLevel::Trace: return "TRACE";
        case LogLevel::Debug: return "DEBUG";
        case LogLevel::Info:  return "INFO";
        case LogLevel::Warn:  return "WARN";
        case LogLevel::Error: return "ERROR";
        case LogLevel::Fatal: return "FATAL";
        default:              return "UNKNOWN";
    }
}
