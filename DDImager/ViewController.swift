//
//  ViewController.swift
//  DDImager
//
//  Created by Homework User on 12/6/17.
//  Copyright © 2017 JackMacWindows. All rights reserved.
//  dd if=/Users/homeworkuser/Downloads/OS\ X\ Base\ System.dmg of=/dev/null

import Cocoa

var prefixes: [String] = ["B", "kB", "MB", "GB", "TB", "PB", "EB"]

class ValueCarrier {
    var fileSize: UInt64
    var command: String
    
    init(withSize size: UInt64, command c: String) {
        self.fileSize = size
        self.command = c
    }
}

var GlobalCarrier: ValueCarrier?

extension Decimal {
    var doubleValue: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
    var uint64Value: UInt64 {
        return NSDecimalNumber(decimal: self).uint64Value
    }
}

func runDDTask(input: String, output: String, arguments: String, parentVC: Any) {
    var fileSize: UInt64 = 0
    do {
        let attr = try FileManager.default.attributesOfItem(atPath: input.replacingOccurrences(of: "\\ ", with: " "))
        fileSize = attr[FileAttributeKey.size] as! UInt64
    } catch {
        print("Error: \(error)")
    }
    
    GlobalCarrier = ValueCarrier(withSize: fileSize, command: "{ dd if='\(input)' \(arguments) | '\(Bundle.main.url(forResource: "pv", withExtension: nil)?.absoluteString.replacingOccurrences(of: "file://", with: "") ?? "/usr/local/bin/pv")' --size \(fileSize) -b -n | dd of='\(output)' \(arguments); } 2>&1")
    (parentVC as! NSViewController).performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "openProgress"), sender: GlobalCarrier)
    
}

func bytesToHuman(_ bytes: UInt64) -> String {
    var i: Int = 10
    while bytes > pow(2, i).uint64Value {i += 10}
    i -= 10
    let u = Float64(bytes) / pow(2, i).doubleValue
    let t: Double
    if u > 100 {t = round(u*10)/10}
    else {t = round(u*100)/100}
    return String(t) + prefixes[i/10]
}

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func closeWindow(_ sender: Any?) {
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "inputDD"), sender: nil)
        self.view.window?.close()
    }

}

class DDViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func runCommand(_ sender: Any) {
        let newCommand = command.stringValue.replacingOccurrences(of: "\\ ", with: "\\").components(separatedBy: " ")
        var input = ""
        var output = ""
        var arguments: [String] = []
        for arg in newCommand {
            if arg.hasPrefix("if=") {
                input = arg.replacingOccurrences(of: "if=", with: "").replacingOccurrences(of: "\\", with: " ")
            } else if arg.hasPrefix("of=") {
                output = arg.replacingOccurrences(of: "of=", with: "").replacingOccurrences(of: "\\", with: " ")
            } else if arg != "dd" {
                arguments.append(arg.replacingOccurrences(of: "\\", with: " "))
            }
        }
        var args = ""
        for arg in arguments {
            if args == "" {args = arg}
            else {args += " " + arg}
        }
        runDDTask(input: input, output: output, arguments: args, parentVC: self)
        self.view.window?.close()
    }
    
    @IBOutlet weak var command: NSTextField!
    
}

class ProgressViewController: NSViewController {
    
    public var lastCopied: UInt64 = 0
    public var totalCopied: UInt64 = 0
    public var fileSize: UInt64 = 0
    public var command: String = ""
    var timer: Timer? = nil
    var task: STPrivilegedTask = STPrivilegedTask()
    var processHasBeenStopped: Bool = false
    
    @objc func parseData(_ notification: Notification) {
        //print("Got data")
        let data = notification.userInfo![NSFileHandleNotificationDataItem] as? Data
        //print("Got data 2")
        if (data != nil && !(data!.isEmpty)) {
            //print("Not empty")
            if let line = String(data: data!, encoding: String.Encoding.utf8)?.replacingOccurrences(of: "\n", with: "") {
                //print("Can be string: \(line)")
                if (UInt64(line) != nil) {
                    //print("Updating data")
                    //DispatchQueue.main.async {
                        self.lastCopied = UInt64(line)! - self.totalCopied
                        self.totalCopied = UInt64(line)!
                        self.refreshData()
                        //print("Updated data")
                        (notification.object! as! FileHandle).readInBackgroundAndNotify()
                    //}
                    //return
                } else if line.contains("records") {
                    self.lastCopied = self.fileSize - self.totalCopied
                    self.totalCopied = self.fileSize
                    self.refreshData()
                    (notification.object! as! FileHandle).readInBackgroundAndNotify()
                } else {
                    print("Not a number")
                    return
                }
            } else {
                print("Error decoding data: \(data!)")
                return
            }
        } else {
            print("Data is empty")
            return
        }
    }
    
    @objc func finished(_ sender: Any?) {
        print("Finished")
        self.view.window?.close()
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "return"), sender: nil)
    }
    
    @objc @IBAction func stopProcess(_ sender: Any?) {
        if (task.isRunning) {
            let qtask = Process();
            qtask.launchPath = "/bin/bash"
            qtask.arguments = ["-c", "ps -ax | grep 'pv --size \(fileSize)' | grep -v grep | grep -o '^[0-9]*'"]
            
            let pipe = Pipe()
            qtask.standardOutput = pipe
            qtask.launch()
            let outdata = pipe.fileHandleForReading.readDataToEndOfFile()
            var output: [String] = []
            if var string = String(data: outdata, encoding: .utf8) {
                string = string.trimmingCharacters(in: .newlines)
                output = string.components(separatedBy: "\n")
            }
            qtask.waitUntilExit()
            let pid = Int32(output[0])!
            processHasBeenStopped = true
            let ret = kill(pid, SIGKILL)
            
            if (ret != 0) {
                print("Error \(ret)");
            }
            Timer(timeInterval: TimeInterval(0.2), repeats: false, block: {timer in
                self.progress.doubleValue = 0.0
            })
        }
        //self.view.window?.close()
        //self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "return"), sender: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //print("Execute A")
        if self.fileSize == 0 {
            self.command = GlobalCarrier!.command
            self.fileSize = GlobalCarrier!.fileSize
        }
        if (!STPrivilegedTask.authorizationFunctionAvailable()) {
            print("Uh oh.")
        }
        task = STPrivilegedTask()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        NotificationCenter.default.addObserver(self, selector: #selector(self.finished), name: NSNotification.Name(rawValue: STPrivilegedTaskDidTerminateNotification), object: nil)
        let err = task.launch()
        if err != noErr {
            print("Error: \(err)")
        }
        let readHandle = task.outputFileHandle
        NotificationCenter.default.addObserver(self, selector: #selector(self.parseData), name: FileHandle.readCompletionNotification, object: readHandle)
        NotificationCenter.default.addObserver(self, selector: #selector(self.stopProcess), name: NSNotification.Name(rawValue: "STApplicationWillTerminate"), object: nil)
        readHandle!.readInBackgroundAndNotify()
        
        print(task.arguments![1])
        
        
        //progress.startAnimation(self)
        //while fileSize == 0 {usleep(10000)}
        totalSizeText.stringValue = bytesToHuman(fileSize)
        refreshData()
        //commandText.stringValue = command
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(0.5), repeats: true, block: {m in DispatchQueue.main.async {self.refreshData()}})
        // Do any additional setup after loading the view.
    }
    
    /*override func shouldPerformSegue(withIdentifier identifier: NSStoryboardSegue.Identifier, sender: Any?) -> Bool {
        print("Execute B")
        //progressController2 = self
        self.command = (sender as! ValueCarrier).command
        self.fileSize = (sender as! ValueCarrier).fileSize
        return true
    }*/
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func refreshData() {
        DispatchQueue.main.async {
            if (self.processHasBeenStopped) {
                self.progress.doubleValue = 0.0
                self.totalCopiedText.stringValue = "0B"
                self.speedText.stringValue = "0B/s"
                return
            }
            self.totalCopiedText.stringValue = bytesToHuman(self.totalCopied)
            self.speedText.stringValue = bytesToHuman(self.lastCopied) + "/s"
            if (self.totalCopied > self.fileSize || self.fileSize == 0) {self.progress.startAnimation(self)}
            else {self.progress.stopAnimation(self); self.progress.doubleValue = (Float64(self.totalCopied) / Float64(self.fileSize)) * 100}
        }
    }
    
    @IBOutlet weak var totalCopiedText: NSTextField!
    @IBOutlet weak var totalSizeText: NSTextField!
    @IBOutlet weak var speedText: NSTextField!
    @IBOutlet weak var progress: NSProgressIndicator!
    @IBOutlet weak var commandText: NSTextField!
    
}

