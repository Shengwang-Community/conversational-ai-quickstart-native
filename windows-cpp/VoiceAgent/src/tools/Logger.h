#pragma once

#include <string>
#include <memory>
#include <mutex>
#include <fstream>
#include <sstream>
#include <chrono>
#include <iomanip>

// Simple string formatting for C++17 compatibility
namespace StringFormat {
    template<typename T>
    std::string format(const std::string& format_str, T value) {
        std::ostringstream oss;
        size_t pos = format_str.find("{}");
        if (pos != std::string::npos) {
            oss << format_str.substr(0, pos) << value << format_str.substr(pos + 2);
        } else {
            oss << format_str;
        }
        return oss.str();
    }
    
    template<typename T1, typename T2>
    std::string format(const std::string& format_str, T1 value1, T2 value2) {
        std::ostringstream oss;
        std::string result = format_str;
        
        size_t pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value1;
            result.replace(pos, 2, temp.str());
        }
        
        pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value2;
            result.replace(pos, 2, temp.str());
        }
        
        return result;
    }
    
    template<typename T1, typename T2, typename T3>
    std::string format(const std::string& format_str, T1 value1, T2 value2, T3 value3) {
        std::ostringstream oss;
        std::string result = format_str;
        
        size_t pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value1;
            result.replace(pos, 2, temp.str());
        }
        
        pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value2;
            result.replace(pos, 2, temp.str());
        }
        
        pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value3;
            result.replace(pos, 2, temp.str());
        }
        
        return result;
    }
    
    template<typename T1, typename T2, typename T3, typename T4>
    std::string format(const std::string& format_str, T1 value1, T2 value2, T3 value3, T4 value4) {
        std::ostringstream oss;
        std::string result = format_str;
        
        size_t pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value1;
            result.replace(pos, 2, temp.str());
        }
        
        pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value2;
            result.replace(pos, 2, temp.str());
        }
        
        pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value3;
            result.replace(pos, 2, temp.str());
        }
        
        pos = result.find("{}");
        if (pos != std::string::npos) {
            std::ostringstream temp;
            temp << value4;
            result.replace(pos, 2, temp.str());
        }
        
        return result;
    }
}

// Modern C++ logging levels
enum class LogLevel : uint8_t {
    Trace = 0,
    Debug = 1,
    Info = 2,
    Warn = 3,
    Error = 4,
    Fatal = 5
};

// Thread-safe singleton logger
class Logger {
public:
    static Logger& instance() {
        static Logger logger;
        return logger;
    }

    // Simple string logging for C++17 compatibility
    void log(LogLevel level, const std::string& message) {
        if (level < m_minLevel) return;
        
        // Format with basic info
        auto formatted = formatMessage(level, message);
        
        // Thread-safe write
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            writeToFile(formatted);
            writeToDebug(formatted);
        }
    }

    // Convenience methods
    void trace(const std::string& message) { log(LogLevel::Trace, message); }
    void debug(const std::string& message) { log(LogLevel::Debug, message); }
    void info(const std::string& message) { log(LogLevel::Info, message); }
    void warn(const std::string& message) { log(LogLevel::Warn, message); }
    void error(const std::string& message) { log(LogLevel::Error, message); }
    void fatal(const std::string& message) { log(LogLevel::Fatal, message); }

    // Configuration
    void setLogLevel(LogLevel level) { m_minLevel = level; }
    void setLogFile(const std::string& path) { m_logPath = path; }

private:
    Logger() = default;
    ~Logger() = default;
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;

    std::string formatMessage(LogLevel level, const std::string& message);
    void writeToFile(const std::string& message);
    void writeToDebug(const std::string& message);
    std::string getCurrentTime();
    std::string getLevelString(LogLevel level);

    std::mutex m_mutex;
    std::ofstream m_logFile;
    std::string m_logPath = "logs/modern_log.txt";
    LogLevel m_minLevel = LogLevel::Debug;
};

// Simple macro definitions for C++17 compatibility
#define LOG_TRACE(msg) Logger::instance().trace(msg)
#define LOG_DEBUG(msg) Logger::instance().debug(msg)
#define LOG_INFO(msg)  Logger::instance().info(msg)
#define LOG_WARN(msg)  Logger::instance().warn(msg)
#define LOG_ERROR(msg) Logger::instance().error(msg)
#define LOG_FATAL(msg) Logger::instance().fatal(msg)

// Formatted logging macros
#define LOG_TRACE_FMT(fmt, ...) Logger::instance().trace(StringFormat::format(fmt, __VA_ARGS__))
#define LOG_DEBUG_FMT(fmt, ...) Logger::instance().debug(StringFormat::format(fmt, __VA_ARGS__))
#define LOG_INFO_FMT(fmt, ...)  Logger::instance().info(StringFormat::format(fmt, __VA_ARGS__))
#define LOG_WARN_FMT(fmt, ...)  Logger::instance().warn(StringFormat::format(fmt, __VA_ARGS__))
#define LOG_ERROR_FMT(fmt, ...) Logger::instance().error(StringFormat::format(fmt, __VA_ARGS__))
#define LOG_FATAL_FMT(fmt, ...) Logger::instance().fatal(StringFormat::format(fmt, __VA_ARGS__))

// Conditional logging macros
#define LOG_DEBUG_IF(condition, msg) \
    do { if (condition) LOG_DEBUG(msg); } while(0)

#define LOG_ERROR_IF(condition, msg) \
    do { if (condition) LOG_ERROR(msg); } while(0)
