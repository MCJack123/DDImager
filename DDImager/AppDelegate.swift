//
//  AppDelegate.swift
//  DDImager
//
//  Created by Homework User on 12/6/17.
//  Copyright © 2017 JackMacWindows. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "STApplicationWillTerminate"), object: nil)
    }


}

