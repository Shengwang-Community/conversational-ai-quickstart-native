// pch.h: Precompiled Header File
// Files listed below are compiled only once, improving build performance.
// This also affects IntelliSense performance, including code completion.
// Do not add frequently updated files here as it negates the performance benefit.

#pragma once

#include "targetver.h"

// Prevent Windows.h conflicts with external libraries
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

// Temporarily undefine _WINDOWS_ to allow MFC's check to pass
// This is necessary because Agora SDK headers may include Windows.h before pch.h
#ifdef _WINDOWS_
#undef _WINDOWS_
#define _WINDOWS_WAS_DEFINED
#endif

// MFC Core Headers
// MFC will check for _WINDOWS_ and include Windows.h if not already included
#include <afxwin.h>         // MFC core and standard components
#include <afxext.h>         // MFC extensions
#include <afxcontrolbars.h> // MFC support for ribbons and control bars
#include <afxcmn.h>         // MFC support for Windows common controls

// Ensure Windows.h is included (MFC may have already included it)
#ifndef _WINDOWS_
#include <windows.h>
#endif


