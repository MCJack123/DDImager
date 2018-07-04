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
import DiskArbitration

var prefixes: [String] = ["B", "kB", "MB", "GB", "TB", "PB", "EB"]
let debug = true
var log = ""
var newlog = ""
var bad = false
var preLaunched = false
var preRun = false
var unmounted = false
var nested = false

class ValueCarrier {
    var fileSize: UInt64
    var command: String
	var inputDisk: String
	var outputDisk: String
    
    init(withSize size: UInt64, command c: String, input id: String, output od: String) {
        self.fileSize = size
        self.command = c
		self.inputDisk = id
		self.outputDisk = od
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

extension NSTextView {
    func appendText(line: String) {
        DispatchQueue.main.async {
            let attrDict = [NSAttributedStringKey.font: NSFont.systemFont(ofSize: 18.0)]
            let astring = NSAttributedString(string: "\(line)\n", attributes: attrDict)
            self.textStorage?.append(astring)
            let loc = self.string.lengthOfBytes(using: String.Encoding.utf8)
            
            let range = NSRange(location: loc, length: 0)
            self.scrollRangeToVisible(range)
        }
    }
}

func runDDTask(input: String, output: String, fileSize: UInt64?, arguments: String, parentVC: Any) {
    var finalFileSize: UInt64 = 0
    if fileSize == nil {
		do {
        	let attr = try FileManager.default.attributesOfItem(atPath: input.replacingOccurrences(of: "\\ ", with: " "))
        	finalFileSize = attr[FileAttributeKey.size] as! UInt64
    	} catch {
        	print("Error: \(error)")
    	}
    } else {
        finalFileSize = fileSize!
    }
    GlobalCarrier = ValueCarrier(withSize: finalFileSize, command: "{ dd if='\(input)' \(arguments) | '\(Bundle.main.path(forResource: "pv", ofType: nil) ?? "/usr/local/bin/pv")' \(fileSize == nil ? "" : "--size \(String(describing: fileSize!))") -b -n -i 0.25 | dd of='\(output)' \(arguments); } 2>&1", input: input, output: output)
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
    
    var running = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if !preLaunched {
			for i in 0...CommandLine.argc-1 {
				if CommandLine.arguments[Int(i)] == "-c" {
					let newCommand = CommandLine.arguments[Int(i+1)].replacingOccurrences(of: "\\ ", with: "\\").components(separatedBy: " ")
					var input = ""
					var output = ""
					var size: UInt64? = nil
					var arguments: [String] = []
					for arg in newCommand {
						if arg.hasPrefix("if=") {
							input = arg.replacingOccurrences(of: "if=", with: "").replacingOccurrences(of: "\\", with: " ")
						} else if arg.hasPrefix("of=") {
							output = arg.replacingOccurrences(of: "of=", with: "").replacingOccurrences(of: "\\", with: " ")
						} else if arg.hasPrefix("size=") {
							size = UInt64(arg.replacingOccurrences(of: "size=", with: ""))
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
					running = true
					preRun = true
					self.view.window?.close()
					self.dismiss(nil)
					DispatchQueue.main.async {
						runDDTask(input: input, output: output, fileSize: size, arguments: args, parentVC: self)
					}
					print("Running")
					break
				}
			}
        }
        preLaunched = true

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear() {
        if running {
            print("will")
            DispatchQueue.main.async {
                self.view.window!.close()
            }
        }
    }
    
    override func viewDidAppear() {
        if running {
            print("did")
            DispatchQueue.main.async {
                self.view.window!.close()
            }
        }
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
	
	@IBAction func browseFile(sender: AnyObject) {
		
		let dialog = NSOpenPanel();
		
		dialog.title                   = "Choose the source image";
		dialog.showsResizeIndicator    = true;
		dialog.showsHiddenFiles        = false;
		dialog.canChooseDirectories    = false;
		dialog.canCreateDirectories    = false;
		dialog.allowsMultipleSelection = false;
		dialog.allowedFileTypes        = ["img", "iso"];
		
		if (dialog.runModal() == NSApplication.ModalResponse.OK) {
			let result = dialog.url // Pathname of the file
			
			if (result != nil) {
				let path = result!.path
				print(path)
				let attr = try! FileManager.default.attributesOfItem(atPath: path)
				let finalFileSize = attr[FileAttributeKey.size] as! UInt64
				GlobalCarrier = ValueCarrier(withSize: finalFileSize, command: "", input: path, output: "")
				self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "destDisk"), sender: nil)
				self.view.window?.close()
			}
		} else {
			// User clicked on "Cancel"
			return
		}
		
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
		var size: UInt64? = nil
        var arguments: [String] = []
        for arg in newCommand {
            if arg.hasPrefix("if=") {
                input = arg.replacingOccurrences(of: "if=", with: "").replacingOccurrences(of: "\\", with: " ")
            } else if arg.hasPrefix("of=") {
                output = arg.replacingOccurrences(of: "of=", with: "").replacingOccurrences(of: "\\", with: " ")
			} else if arg.hasPrefix("size=") {
				size = UInt64(arg.replacingOccurrences(of: "size=", with: ""))
            } else if arg == "sudo" && getuid() != 0 {
                let alert = NSAlert()
                alert.messageText = "Application will relaunch as root"
                alert.informativeText = "To copy the file to the destination as root, the application needs to relaunch. After typing an administrator password, the program will relaunch."
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")
                let retval = alert.runModal().rawValue - 1000
                //print(retval)
                if retval == 0 {runAsRoot()}
                else {return}
                NSApplication.shared.terminate(self)
            } else if arg != "dd" && arg != "sudo" {
                arguments.append(arg.replacingOccurrences(of: "\\", with: " "))
            }
        }
        var args = ""
        for arg in arguments {
            if args == "" {args = arg}
            else {args += " " + arg}
        }
        runDDTask(input: input, output: output, fileSize: size, arguments: args, parentVC: self)
        self.view.window?.close()
    }
    
    @IBOutlet weak var command: NSTextField!
    
}

class ProgressViewController: NSViewController {
    
    public var lastCopied: UInt64 = 0
    public var totalCopied: UInt64 = 0
    public var fileSize: UInt64? = 0
    public var command: String = ""
    var done = false
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
                newlog = line + "\n"
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DDLogAvailable"), object: nil)
				if line == "" {
                    print("No information")
                    if task.isRunning {task.terminate()}
                    return
                }
                //print("Can be string: \(line)")
                if (UInt64(line) != nil) {
                    //print("Updating data")
                    //DispatchQueue.main.async {
                    if (UInt64(line)! > self.mostCopied * 5 && mostCopied > 1000000) || UInt64(line)! > fileSize! {
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
                } else if line.contains("records") || line.contains("bytes") {
                    self.lastCopied = self.fileSize! - self.totalCopied
                    self.totalCopied = self.fileSize!
                    self.refreshData()
                    //(notification.object! as! FileHandle).readInBackgroundAndNotify()
                } else if line.contains("Permission denied") || line.contains("Resource busy") {
                    
                    //if task.isRunning {task.terminate()}
                    handle.readabilityHandler = nil
                    handle = FileHandle()
                    task = Process()
                    DispatchQueue.main.sync {
                        let alert = NSAlert()
                        alert.informativeText = line
                        alert.messageText = "You do not have permission to write to this file. Try again using sudo, or, if the problem persists, make sure any output disk is unmounted."
                        alert.runModal()
                    }
                    finished(nil)
                    
                    
                    return
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
        if !done {
            done = true
            DispatchQueue.main.async {
                print("Finished")
                //NotificationCenter.default.removeObserver(obs1!)
                //NotificationCenter.default.removeObserver(obs2!)
                if self.task.isRunning {self.task.terminate()}
                self.handle.readabilityHandler = nil
                _ = Timer(timeInterval: TimeInterval(1), repeats: false, block: {timer in
                    if self.task.isRunning {print("Task is still running!")}
                })
                log = ""
                self.view.window?.close()
                self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "return"), sender: nil)
            }
        }
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
        DispatchQueue.main.async {
            self.finished(nil)
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
	    
        let session = DASessionCreate(kCFAllocatorDefault)
        DASessionSetDispatchQueue(session!, DispatchQueue.main)
        let inputDisk = GlobalCarrier?.inputDisk
        if (inputDisk?.hasPrefix("/dev/disk"))! {
            let indata = inputDisk!.data(using: String.Encoding.utf8, allowLossyConversion: false)
            let indisk: DADisk? = indata!.withUnsafeBytes {
                return DADiskCreateFromBSDName(kCFAllocatorDefault, session!, $0)
            }
            if indisk != nil {
                let diskinfo = DADiskCopyDescription(indisk!) as? [CFString: AnyObject]
                var fspath: CFURL?
                let infArray = Array(diskinfo!.keys)
                if infArray.contains("DAVolumePath" as CFString) {fspath = (diskinfo!["DAVolumePath" as CFString] as! CFURL)}
                self.fileSize = diskinfo![kDADiskDescriptionMediaSizeKey] as? UInt64
                //print(kDADiskDescriptionVolumePathKey)
                //let infArray = Array(diskinfo!.keys)
                for a in infArray {
                    print(String(a) + ": " + String(describing: diskinfo![a]))
                }
			
                let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                bad = false
                //if (diskinfo![kDADiskDescriptionMediaWholeKey] as! Int == 0) {
                    if (fspath != nil) {
                        if (CFURLGetFileSystemRepresentation(fspath , false, buf, 1024)) {
                            print("Unmounting indisk")
                            unmounted = false
                            nested = false
                            //DispatchQueue.global().async {
                            DADiskUnmount(indisk!, DADiskUnmountOptions(kDADiskUnmountOptionDefault), { (disk: DADisk, dissenter: DADissenter?, context: UnsafeMutableRawPointer?) in
                                //DispatchQueue.global().async {
                                
                                if ((dissenter) != nil) {
                                    print(" Unmount failed. ")
                                    //buf.deallocate(capacity: 1024)
                                    let buff = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                                    let diskinfoo = DADiskCopyDescription(disk) as? [AnyHashable: Any]
                                    let fspathh = diskinfoo![kDADiskDescriptionVolumePathKey] as? String
									if (CFURLGetFileSystemRepresentation((fspathh as! CFURL), false, buff, 1024)) {
                                        DispatchQueue.main.sync {
                                            let alert = NSAlert()
                                            alert.messageText = "Error unmounting"
                                            alert.informativeText = "Unmount failed (Error: 0x\(DADissenterGetStatus(dissenter!)) Reason: \(buff)). Please unmount the disk manually.\n"
                                            alert.runModal()
                                            buff.deallocate()
                                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ProgressExit") , object: nil)
                                        }
                                    } else {
                                        print("???")
                                    }
                                }
                                print("Done")
                                unmounted = true
                                if nested {
                                    CFRunLoopStop(CFRunLoopGetCurrent())
                                }
                                //}
                            }, nil)
                            //}
                            if !unmounted {
                                nested = true
                                CFRunLoopRun()
                                nested = false
                            }
                        }
                        if bad {self.finished(nil)}
                        buf.deallocate()
                    }
                //}
            }
        }
        let outputDisk = GlobalCarrier?.outputDisk
        if (outputDisk?.hasPrefix("/dev/disk"))! {
            let outdata = outputDisk!.data(using: String.Encoding.utf8, allowLossyConversion: false)
            let outdisk: DADisk? = outdata!.withUnsafeBytes {
                return DADiskCreateFromBSDName(kCFAllocatorDefault, session!, $0)
            }
            if outdisk != nil {
                let diskinfo = DADiskCopyDescription(outdisk!) as? [CFString: AnyObject]
                let fspath = diskinfo![kDADiskDescriptionVolumePathKey]
                let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                //if diskinfo![kDADiskDescriptionMediaWholeKey] as! Int == 0 {
                    if (fspath != nil) {
						if (CFURLGetFileSystemRepresentation((fspath as! CFURL), false, buf, 1024)) {
                            bad = false
                            unmounted = false
                            nested = false
                            DADiskUnmount(outdisk!, DADiskUnmountOptions(kDADiskUnmountOptionDefault), { (disk: DADisk, dissenter: DADissenter?, context: UnsafeMutableRawPointer?) in
                                if ((dissenter) != nil) {
                                    /* Unmount failed. */
                                    //buf.deallocate(capacity: 1024)
                                    let buff = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                                    let diskinfoo = DADiskCopyDescription(disk) as? [CFString: AnyObject]
                                    let fspathh = diskinfoo![kDADiskDescriptionVolumePathKey] as? String
									if (CFURLGetFileSystemRepresentation((fspathh as! CFURL), false, buff, 1024)) {
                                        DispatchQueue.main.sync {
                                            let alert = NSAlert()
                                            alert.messageText = "Error unmounting"
                                            alert.informativeText = "Unmount failed (Error: 0x\(DADissenterGetStatus(dissenter!)) Reason: \(buff)). Please unmount the disk manually.\n"
                                            alert.runModal()
                                            buff.deallocate()
                                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ProgressExit"), object: nil)
                                        }
                                    } else {
                                        print("???")
                                    }
                                }
                                unmounted = true
                                if nested {
                                    CFRunLoopStop(CFRunLoopGetCurrent())
                                }
                            }, nil)
                            if !unmounted {
                                nested = true
                                CFRunLoopRun()
                                nested = false
                            }
                            //if bad {self.finished(nil)}
                        }
                    }
                    buf.deallocate()
                //}
            }
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
        if fileSize != nil {
            totalSizeText.stringValue = "/ " + bytesToHuman(fileSize!)
		} else {
			totalSizeText.stringValue = ""
			progress.isIndeterminate = true
		}
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
                self.progress.doubleValue = 1.0
                self.totalCopiedText.stringValue = "0B"
                self.speedText.stringValue = "0B/s"
                return
            }
			self.totalCopiedText.stringValue = bytesToHuman(self.totalCopied)
			self.speedText.stringValue = bytesToHuman(self.lastCopied * 4) + "/s"
            if self.fileSize == nil {
				self.progress.doubleValue = 100.0
			} else {
                if (self.totalCopied > self.fileSize! || self.fileSize == 0) {}
                else {self.progress.doubleValue = (Float64(self.totalCopied) / Float64(self.fileSize!)) * 100}
			}
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
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "DDLogAvailable"), object: nil, queue: nil, using: { (notif: Notification) in
            DispatchQueue.main.async {
                self.logView.string = log
                //  Converted to Swift 4 by Swiftify v4.1.6600 - https://objectivec2swift.com/
                let scroll: Bool = NSMaxY(self.logView.visibleRect) == NSMaxY(self.logView.bounds)
                // Append string to textview
                //logView.textStorage.append(NSAttributedString(string: newlog))
                if scroll {
                    // Scroll to end of the textview contents
                    self.logView.scrollRangeToVisible(NSRange(location: self.logView.string.count, length: 0))
                }

            }
		})
        logView.string = log
	}
	
    @IBOutlet weak var logView: NSTextView!
}

class DiskOptionsViewController: NSViewController {
	
	var blockSize: Int32 = 4096
	var blockCount: Int32? = nil
	var outputSeek: Int32 = 0
	var inputSkip: Int32 = 0
	var ignoreErrors = false
	var eraseDisk = true
	var fillBlocks = false
	var swapBytes = false
	
	@IBOutlet var blockSizeText: NSTextField!
	@IBOutlet var blockCountText: NSTextField!
	@IBOutlet var outputSeekText: NSTextField!
	@IBOutlet var inputSkipText: NSTextField!
	@IBOutlet var ignoreErrorsButton: NSButton!
	@IBOutlet var eraseDiskButton: NSButton!
	@IBOutlet var fillBlocksButton: NSButton!
	@IBOutlet var swapBytesButton: NSButton!
	
	@IBAction func close(_ sender: Any) {
		blockSize = blockSizeText.intValue
		blockCount = (blockCountText.stringValue == "" ? nil : blockCountText.intValue)
		outputSeek = outputSeekText.intValue
		inputSkip = inputSkipText.intValue
		ignoreErrors = ignoreErrorsButton.state == .on
		eraseDisk = eraseDiskButton.state == .on
		fillBlocks = fillBlocksButton.state == .on
		swapBytes = swapBytesButton.state == .on
		self.dismiss(nil)
	}
	
	override func viewWillAppear() {
		blockSizeText.intValue = blockSize
		blockCountText.stringValue = (blockCount == nil ? "" : String(blockCount!))
		outputSeekText.intValue = outputSeek
		inputSkipText.intValue = inputSkip
		ignoreErrorsButton.state = ignoreErrors ? .on : .off
		eraseDiskButton.state = eraseDisk ? .on : .off
		fillBlocksButton.state = fillBlocks ? .on : .off
		swapBytesButton.state = swapBytes ? .on : .off
	}
	
}

class DiskViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
	
	class DiskData {
        var isExternal: Bool?
        var diskName: String?
		var bsdName = ""
		var diskSize: UInt64?
	}
	
	@IBOutlet var diskTable: NSTableView!
	@IBOutlet var copyButton: NSButton!
	var disks = [DiskData]()
	var options = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: Bundle.main).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "DiskOptionsViewController")) as! DiskOptionsViewController
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return disks.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		var image: NSImage?
		var text: String = ""
		var cellIdentifier: String = ""
		if disks.count < row {
			print("No celll")
			return nil
		}
		let item = disks[row]
		if tableColumn == diskTable.tableColumns[0] {
			//image = NSImage(named: NSImage.Name(rawValue: item.isExternal ? "External" : "Internal"))
			image = NSImage(named: NSImage.Name(rawValue: item.isExternal == false ? "Internal" : "External"))
            text = item.diskName == nil ? item.bsdName : item.diskName!
			cellIdentifier = "diskNameCell"
		} else if tableColumn == diskTable.tableColumns[1] {
			text = item.bsdName
			cellIdentifier = "bsdNameCell"
		} else if tableColumn == diskTable.tableColumns[2] {
            if item.diskSize != nil {text = bytesToHuman(item.diskSize!)}
            else {text = "??"}
			cellIdentifier = "diskSizeCell"
		}
		//print(cellIdentifier)
		let oldcell = diskTable.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil)
		let cell = oldcell as! NSTableCellView
        cell.textField?.stringValue = text
        cell.imageView?.image = image ?? nil
        return cell
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		copyButton.isEnabled = true
	}
	
	@objc func parseData(_ pipe: FileHandle) {
		if let line = String(data: pipe.availableData, encoding: String.Encoding.utf8)?.replacingOccurrences(of: "\n", with: "") {
			print(line)
		}
	}
	
	func runAsRoot(_ command: String) {
		//let pasteboard = NSPasteboard.general
		//pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
		//pasteboard.setString(command.stringValue, forType: NSPasteboard.PasteboardType.string)
		print("do shell script \"\(Bundle.main.executablePath!.replacingOccurrences(of: " ", with: "\\\\ ")) -c \\\"\(command.replacingOccurrences(of: " ", with: "\\\\ "))\\\"\" with administrator privileges")
		let process = Process()
		process.launchPath = "/usr/bin/osascript"
		process.arguments = ["-e", "do shell script \"\(Bundle.main.executablePath!.replacingOccurrences(of: " ", with: "\\\\ ")) -c \\\"\(command.replacingOccurrences(of: " ", with: "\\\\ "))\\\"\" with administrator privileges"]
		process.terminationHandler = {reason in
			NSApplication.shared.terminate(self)
		}
		let pipe = Pipe()
		process.standardOutput = pipe
		let handle = pipe.fileHandleForReading
		handle.readabilityHandler = parseData
		process.launch()
		self.view.window?.close()
		process.waitUntilExit()
	}
	
	override func viewDidLoad() {
		diskTable.delegate = self
		diskTable.dataSource = self
		let session = DASessionCreate(kCFAllocatorDefault)!
		let oldfiles = try! FileManager().contentsOfDirectory(atPath: "/dev")
		let files = oldfiles.filter({(_ s: String) -> Bool in return s.range(of: "^disk[0-9]+s[0-9]+$", options: .regularExpression, range: nil, locale: nil) != nil})
		//print(oldfiles)
		//print(files)
		for f in files {
			let disk: DADisk? = f.data(using: .ascii)!.withUnsafeBytes {
				return DADiskCreateFromBSDName(kCFAllocatorDefault, session, $0)
			}
			if disk == nil {
				print("No disk \(f)")
				continue
			}
			let dd = DiskData();
			dd.bsdName = f
			let diskinfo = DADiskCopyDescription(disk!) as! [CFString: AnyObject]
			dd.diskName = diskinfo[kDADiskDescriptionVolumeNameKey] as? String
			dd.diskSize = diskinfo[kDADiskDescriptionMediaSizeKey] as? UInt64
			dd.isExternal = diskinfo[kDADiskDescriptionDeviceInternalKey] as? Bool
			disks.append(dd)
			//print("Inserted \(f)")
		}
		diskTable.reloadData()
	}
	
	@IBAction func close(_ sender: Any) {
		self.performSegue(withIdentifier: NSStoryboardSegue.Identifier(rawValue: "diskBack"), sender: nil)
		self.view.window?.close()
	}
	
	@IBAction func openOptions(_ sender: Any) {
		self.presentViewControllerAsSheet(options)
	}
	
	@IBAction func startTransfer(_ sender: Any) {
		let row = diskTable.selectedRow
		var arguments = ""
		if options.blockCount != nil {
			arguments += "count=\(options.blockCount!) "
		}
		if options.blockSize != 4096 {
			arguments += "bs=\(options.blockSize)"
		}
		if (!options.eraseDisk || options.fillBlocks || options.ignoreErrors || options.swapBytes) {
			arguments += "conv="
			var e = false
			if (!options.eraseDisk) {
				e = true
				arguments += "notrunc"
			}
			if (options.fillBlocks) {
				if (e) {
					arguments += ","
				} else {
					e = true
				}
				arguments += "sync"
			}
			if (options.ignoreErrors) {
				if (e) {
					arguments += ","
				} else {
					e = true
				}
				arguments += "noerror"
			}
			if (options.swapBytes) {
				if (e) {
					arguments += ","
				} else {
					e = true
				}
				arguments += "swab"
			}
			arguments += " "
		}
		let iarguments = arguments + (options.inputSkip != 0 ? "skip=\(options.inputSkip) " : "")
		let oarguments = arguments + (options.outputSeek != 0 ? "seek=\(options.outputSeek) " : "")
		if getuid() != 0 {
			let command = "{ dd if='\(GlobalCarrier!.inputDisk)' \(iarguments) | '\(Bundle.main.path(forResource: "pv", ofType: nil) ?? "/usr/local/bin/pv")' --size \(String(describing: GlobalCarrier!.fileSize)) -b -n -i 0.25 | dd of='/dev/\(disks[row].bsdName)' \(oarguments); } 2>&1"
			//print(command)
			runAsRoot(command)
			NSApplication.shared.terminate(self)
			// switching is broken right now
		} else {
			runDDTask(input: GlobalCarrier!.inputDisk, output: "/dev/\(disks[row].bsdName)", fileSize: GlobalCarrier!.fileSize, arguments: arguments, parentVC: self)
			self.view.window?.close()
		}
	}
	
}
