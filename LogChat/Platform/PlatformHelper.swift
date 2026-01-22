//
//  PlatformHelper.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

enum Platform {
    case ios
    
    static var current: Platform {
        return .ios
    }
    
    var isMac: Bool {
        return false
    }
    
    var isIOS: Bool {
        return true
    }
}

