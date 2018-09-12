//
//  StringMessage.swift
//  Pod
//
//  Created by Julian on 12.09.18.
//

import UIKit
import ObjectMapper

public class StringMessage: RBSMessage {
    public var data: String?
    
    override public func mapping(map: Map) {
        data <- map["data"]
    }
}
