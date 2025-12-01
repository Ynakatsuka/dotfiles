#!/usr/bin/env swift
// Get window information using CoreGraphics (no accessibility permission required for basic info)

import Foundation
import CoreGraphics

struct WindowInfo: Codable {
    let app: String
    let title: String
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let pid: Int
}

func getWindows() -> [WindowInfo] {
    var result: [WindowInfo] = []

    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return result
    }

    for window in windowList {
        guard let ownerName = window[kCGWindowOwnerName as String] as? String,
              let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let pid = window[kCGWindowOwnerPID as String] as? Int,
              let layer = window[kCGWindowLayer as String] as? Int else {
            continue
        }

        // Skip system UI elements (layer != 0) and small windows
        let width = Int(bounds["Width"] as? CGFloat ?? 0)
        let height = Int(bounds["Height"] as? CGFloat ?? 0)

        if layer == 0 && width > 100 && height > 100 {
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let x = Int(bounds["X"] as? CGFloat ?? 0)
            let y = Int(bounds["Y"] as? CGFloat ?? 0)

            let info = WindowInfo(
                app: ownerName,
                title: windowName,
                x: x,
                y: y,
                width: width,
                height: height,
                pid: pid
            )
            result.append(info)
        }
    }

    return result
}

let windows = getWindows()
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted

if let jsonData = try? encoder.encode(windows),
   let jsonString = String(data: jsonData, encoding: .utf8) {
    print(jsonString)
} else {
    print("[]")
}
