//
//  AudioManager.swift
//  UWB_Testing
//
//  Created by Hong Yi Lin on 22/2/25.
//

import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    func switchToHomePod() {
        try? audioSession.setCategory(.playAndRecord, mode: .default)
        try? audioSession.overrideOutputAudioPort(.none)
        try? audioSession.setActive(true)
        print("Switched to HomePod")
    }
    
    func switchToIphone() {
        try? audioSession.setCategory(.playback, mode: .default)
        try? audioSession.overrideOutputAudioPort(.speaker)
        try? audioSession.setActive(true)
        print("Switched to iPhone")
    }
}
