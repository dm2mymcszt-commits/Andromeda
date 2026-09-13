//
//  BookMarkHelper.swift
//  TrollRoute
//
//  Developed by son3ra1n.
//

import Foundation
import SwiftUI

let sharedUserDefaultsSuiteName = "group.com.dm2mymcszt.trollroute"

func BookMarkSave(lat: Double, long: Double, name: String) -> Bool {
    let bookmark: [String: Any] = ["name": name, "lat": lat, "long": long]
    var bookmarks = BookMarkRetrieve()
    bookmarks.append(bookmark)
    let sharedUserDefaults = UserDefaults(suiteName: sharedUserDefaultsSuiteName)
    sharedUserDefaults?.set(bookmarks, forKey: "bookmarks")
    successVibrate()
    return true
}

func BookMarkRetrieve() -> [[String: Any]] {
    let sharedUserDefaults = UserDefaults(suiteName: sharedUserDefaultsSuiteName)
    if let bookmarks = sharedUserDefaults?.array(forKey: "bookmarks") as? [[String: Any]] {
        return bookmarks
    } else {
        return []
    }
}
