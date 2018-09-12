//
//  ViewController.swift
//  RBSManager
//
//  Created by wesgood on 01/06/2018.
//  Copyright (c) 2018 wesgood. All rights reserved.
//

import UIKit
import RBSManager

class ViewController: UIViewController, RBSManagerDelegate {
    // user interface
    @IBOutlet var toolbar: UIToolbar!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var backgroundButton: UIButton!
    var hostButton: UIBarButtonItem?
    var flexibleToolbarSpace: UIBarButtonItem?
    
    var stringManager: RBSManager?
    var stringPublisher: RBSPublisher?
    
    // sending message timer
    var controlTimer: Timer?
    
    // user settings
    var socketHost: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = []
        stringManager = RBSManager.sharedManager()
        stringManager?.delegate = self
        updateButtonStates(false)
        
        // load settings to retrieve the stored host value
        loadSettings()
        
        // add toolbar buttons
        hostButton = UIBarButtonItem(title: "Host", style: .plain, target: self, action: #selector(onHostButton))
        flexibleToolbarSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        updateToolbarItems()
        
        // create the publisher and subscriber
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
            stringManager?.disconnect()
        } else {
            if socketHost != nil {
                // the manager will produce a delegate error if the socket host is invalid
                stringManager?.connect(address: socketHost!)
            } else {
                // print log error
                print("Missing socket host value --> use host button")
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
    
    func updateToolbarItems() {
        if stringManager?.connected == true {
            toolbar.setItems([], animated: false)
        } else {
            toolbar.setItems([flexibleToolbarSpace!, hostButton!], animated: false)
        }
    }
}

