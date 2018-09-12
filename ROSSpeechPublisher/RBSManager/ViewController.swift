//
//  ViewController.swift
//  RBSManager
//
//  Created by wesgood on 01/06/2018.
//  Copyright (c) 2018 wesgood. All rights reserved.
//

import UIKit
import RBSManager
import Speech

class ViewController: UIViewController, RBSManagerDelegate {
    // user interface
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var connStatusView: UILabel!
    @IBOutlet weak var recordTextView: UILabel!
    
    var hostButton: UIBarButtonItem?
    var flexibleToolbarSpace: UIBarButtonItem?
    var stringManager: RBSManager?
    var stringPublisher: RBSPublisher?
    
    // speech
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US")) //1
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    var lang: String = "en-US"
    
    // sending message timer
    var controlTimer: Timer?
    
    // user settings
    var socketHost: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = []
        updateButtonStates(false)
        
        // load settings to retrieve the stored host value
        loadSettings()
        
        // add toolbar buttons
        hostButton = UIBarButtonItem(title: "Host", style: .plain, target: self, action: #selector(onHostButton))
        flexibleToolbarSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        updateToolbarItems()

        // request mic permission
        recordButton.isEnabled = false  //2
        speechRecognizer?.delegate = self as? SFSpeechRecognizerDelegate  //3
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        SFSpeechRecognizer.requestAuthorization { (authStatus) in  //4
            
            var isButtonEnabled = false
            
            switch authStatus {  //5
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.recordButton.isEnabled = isButtonEnabled
            }
        }
        
        // create the publisher
        stringManager = RBSManager.sharedManager()
        stringManager?.delegate = self
        stringPublisher = stringManager?.addPublisher(topic: "/phone/instruction", messageType: "sensor_msgs/String", messageClass: StringMessage.self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        socketHost = defaults.string(forKey: "socket_host")
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(socketHost, forKey: "socket_host")
    }
    
    @objc func onHostButton() {
        // change the host used by the websocket
        let alertController = UIAlertController(title: "Enter socket host", message: "IP or name of ROS master", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addTextField { (textField : UITextField) -> Void in
            textField.placeholder = "Host"
            textField.text = self.socketHost
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (result : UIAlertAction) -> Void in
        }
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
            if let textField = alertController.textFields?.first {
                self.socketHost = textField.text
                self.saveSettings()
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func managerDidConnect(_ manager: RBSManager) {
        updateButtonStates(true)
        updateToolbarItems()
    }
    
    func manager(_ manager: RBSManager, threwError error: Error) {
        if (manager.connected == false) {
            updateButtonStates(false)
        }
        print(error.localizedDescription)
    }
    
    func manager(_ manager: RBSManager, didDisconnect error: Error?) {
        updateButtonStates(false)
        updateToolbarItems()
        print(error?.localizedDescription ?? "connection did disconnect")
    }
    
    @IBAction func onConnectButton() {
        if stringManager?.connected == true {
            connStatusView.text = ""
            stringManager?.disconnect()
        } else {
            if socketHost != nil {
                // the manager will produce a delegate error if the socket host is invalid
                stringManager?.connect(address: socketHost!)
                connStatusView.text = "Connected to ROS Master at " + socketHost!
            } else {
                // print log error
                connStatusView.text = "Missing socket host value --> use host button"
            }
        }
    }
    
    // update interface for the different connection statuses
    func updateButtonStates(_ connected: Bool) {
        if connected {
            let redColor = UIColor(red: 0.729, green: 0.131, blue: 0.144, alpha: 1.0)
            connectButton.backgroundColor = redColor
            connectButton.setTitle("DISCONNECT", for: .normal)
        } else {
            let greenColor = UIColor(red: 0.329, green: 0.729, blue: 0.273, alpha: 1.0)
            connectButton.backgroundColor = greenColor
            connectButton.setTitle("CONNECT", for: .normal)
        }
    }
    
    // update record button
    func updateRecordButton(_ recording: Bool) {
        if recording {
            let yellowColor = UIColor(red: 0.255, green: 0.255, blue: 0.0, alpha: 1.0)
            recordButton.backgroundColor = yellowColor
            recordButton.setTitle("STOP RECORDING", for: .normal)
        } else {
            let greenColor = UIColor(red: 0.329, green: 0.729, blue: 0.273, alpha: 1.0)
            recordButton.backgroundColor = greenColor
            recordButton.setTitle("RECORD", for: .normal)
            self.recordTextView.text = ""
        }
    }
    
    func updateToolbarItems() {
        if stringManager?.connected == true {
            toolbar.setItems([], animated: false)
        } else {
            toolbar.setItems([flexibleToolbarSpace!, hostButton!], animated: false)
        }
    }
    
    @IBAction func onRecordButton(_ sender: Any) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            updateRecordButton(false)
        } else {
            startRecording()
            updateRecordButton(true)
        }
    }
    
    func startRecording() {
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                
                self.recordTextView.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
                
                self.sendStringMessage(message: self.recordTextView.text!)
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        self.recordTextView.text = "Listening . . ."
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
        } else {
            recordButton.isEnabled = false
        }
    }
    
    func sendStringMessage(message: String) {
        let msg = StringMessage()
        msg.data = message
        stringPublisher?.publish(msg)
    }
    
}

