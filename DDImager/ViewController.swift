//
//  ViewController.swift
//  DDImager
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Cocoa

var prefixes: [String] = ["B", "kB", "MB", "GB", "TB", "PB", "EB"]
let debug = true
var log = "";

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
    
	GlobalCarrier = ValueCarrier(withSize: fileSize, command: "{ dd if='\(input)' \(arguments) | '\(Bundle.main.path(forResource: "pv", ofType: nil) ?? "/usr/local/bin/pv")' --size \(fileSize) -b -n -i 0.25 | dd of='\(output)' \(arguments); } 2>&1")
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
		for i in 1..CommandLine.argc {
			if CommandLine.arguments[i] == "-c" {
				let newCommand = CommandLine.arguments[i+1].replacingOccurrences(of: "\\ ", with: "\\").components(separatedBy: " ")
        		var input = ""
        		var output = ""
        		var arguments: [String] = []
        		for arg in newCommand {
        		    if arg.hasPrefix("if=") {
        		        input = arg.replacingOccurrences(of: "if=", with: "").replacingOccurrences(of: "\\", with: " ")
        		    } else if arg.hasPrefix("of=") {
         		       	output = arg.replacingOccurrences(of: "of=", with: "").replacingOccurrences(of: "\\", with: " ")
        		    } else if arg == "sudo" && getuid() != 0 {
          		      	return;
           		 	} else if arg != "dd" && arg != "sudo" {
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
		}

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
    
    func runAsRoot() {
        //let pasteboard = NSPasteboard.general
        //pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        //pasteboard.setString(command.stringValue, forType: NSPasteboard.PasteboardType.string)
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", "do shell script \"\(Bundle.main.executablePath!.replacingOccurrences(of: " ", with: "\\\\ ")) -c \(command.stringValue.replacingOccurrences(of: " ", with: "\\\\ "))\" with administrator privileges"]
        process.terminationHandler = {reason in
            NSApplication.shared.terminate(self)
        }
        process.launch()
        self.view.window?.close()
        process.waitUntilExit()
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
            } else if arg == "sudo" && getuid() != 0 {
                let alert = NSAlert()
                alert.messageText = "Application will relaunch as root"
                alert.informativeText = "To copy the file to the destination as root, the application needs to relaunch. The command to be run will be copied to the clipboard. After typing an administrator password, the program will relaunch."
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")
                let retval = alert.runModal().rawValue - 1000
                print(retval)
                if retval == 0 {runAsRoot()}
                else {return}
            } else if arg != "dd" && arg != "sudo" {
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
    var task: Process = Process()
    var processHasBeenStopped: Bool = false
    //var obs1: NSObjectProtocol?
    //var obs2: NSObjectProtocol?
    var pipe: Pipe = Pipe()
    var handle: FileHandle = FileHandle()
    var mostCopied: UInt64 = 0
    
    @objc func parseData(_ pipe: FileHandle) {
        //print("Got data")
        //let data = notification.userInfo![NSFileHandleNotificationDataItem] as? Data
        //print("Got data 2")
        //if (data != nil && !(data!.isEmpty)) {
            //print("Not empty")
            if let line = String(data: pipe.availableData, encoding: String.Encoding.utf8)?.replacingOccurrences(of: "\n", with: "") {
                log += line + "\n"
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DDLogAvailable"), object: nil)
				if line == "" {
                    print("No information")
                    task.terminate()
                    return
                }
                //print("Can be string: \(line)")
                if (UInt64(line) != nil) {
                    //print("Updating data")
                    //DispatchQueue.main.async {
                    if (UInt64(line)! > self.mostCopied * 5 && mostCopied > 1000000) || UInt64(line)! > fileSize {
                    	print("Error in reporting! \(line)")
					} else {
                        self.lastCopied = UInt64(line)! - self.totalCopied
                        self.totalCopied = UInt64(line)!
                        self.refreshData()
                        if UInt64(line)! > mostCopied {
                        	mostCopied = UInt64(line)!
						}
					}
                        //print("Updated data")
                        //(notification.object! as! FileHandle).readInBackgroundAndNotify()
                    //}
                    //return
                } else if line.contains("records") {
                    self.lastCopied = self.fileSize - self.totalCopied
                    self.totalCopied = self.fileSize
                    self.refreshData()
                    //(notification.object! as! FileHandle).readInBackgroundAndNotify()
                } else if line.contains("Permission denied") {
                    DispatchQueue.main.sync {
						let alert = NSAlert()
                    	alert.informativeText = line
                    	alert.messageText = "You do not have permission to write to this file. Try again using sudo, or, if the problem persists, make sure any output disk is unmounted."
                    	alert.runModal()
					}
                    if task.isRunning {task.waitUntilExit()}
                    finished(nil)
                } else {
                    print("Not a number: \(line)")
                    //(notification.object! as! FileHandle).readInBackgroundAndNotify()
                    return
                }
            } else {
                print("Error decoding data: \(pipe.availableData)")
                //(notification.object! as! FileHandle).readInBackgroundAndNotify()
                return
            }
        //} else {
        //    print("Data is empty")
        //    (notification.object! as! FileHandle).readInBackgroundAndNotify()
        //    return
        //}
    }
    
    @objc func finished(_ sender: Any?) {
        print("Finished")
        //NotificationCenter.default.removeObserver(obs1!)
        //NotificationCenter.default.removeObserver(obs2!)
        if task.isRunning {task.terminate()}
        _ = Timer(timeInterval: TimeInterval(1), repeats: false, block: {timer in
        	if self.task.isRunning {print("Task is still running!")}
		})
		log = ""
        self.view.window?.close()
        self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "return"), sender: nil)
    }
    
    @objc @IBAction func stopProcess(_ sender: Any?) {
        if (task.isRunning) {
            /*let qtask = Process();
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
            */
            //task.terminate()
            //task.interrupt()
			
            /*_ = Timer(timeInterval: TimeInterval(0.2), repeats: false, block: {timer in
                self.progress.doubleValue = 0.0
            })*/
            
            
        }
        task.interrupt()
        //task.standardOutput = nil
		//task.standardError = nil
		handle.readabilityHandler = nil
        pipe = Pipe()
        handle = FileHandle()
        //task = Process()
        finished(nil)
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
        task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
		task.terminationHandler = finished
        
        pipe = Pipe()
        task.standardOutput = pipe
        handle = pipe.fileHandleForReading
        
        handle.readabilityHandler = parseData
        /*handle.waitForDataInBackgroundAndNotify()
        
        obs1 = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: handle, queue: nil, using: parseData)
        obs2 = NotificationCenter.default.addObserver(forName: Process.didTerminateNotification, object: task, queue: nil, using: finished)*/
        task.launch()
        
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
            self.speedText.stringValue = bytesToHuman(self.lastCopied * 4) + "/s"
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

class LogViewController : NSViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "DDLogAvailable"), object: nil, using: (Notification) -> Void {
			self.logView.stringValue = log
		})
		logView.stringValue = log
	}
	
	@IBOutlet weak var logView: NSTextView!
