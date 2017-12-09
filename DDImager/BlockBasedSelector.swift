//
//  BlockBasedSelector.swift
//  Parking
//
//  Created by Charlton Provatas on 11/9/17.
//  Copyright © 2017 Passport Parking. All rights reserved.
//

import Foundation
// swiftlint:disable identifier_name
func Selector(_ block: @escaping () -> Void) -> Selector {
    let selector = NSSelectorFromString("\(CACurrentMediaTime())")
    class_addMethodWithBlock(PPSelector.self, selector) { _ in block() }
    return selector
}

/// used w/ callback if you need to get sender argument
func Selector(_ block: @escaping (Any?) -> Void) -> Selector {
    let selector = NSSelectorFromString("\(CACurrentMediaTime())")
    class_addMethodWithBlockAndSender(PPSelector.self, selector) { (_, sender) in block(sender) }
    return selector
}

// swiftlint:disable identifier_name
let Selector = PPSelector.shared
@objc class PPSelector: NSObject {
    static let shared = PPSelector()
}
