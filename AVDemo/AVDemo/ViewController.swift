//
//  ViewController.swift
//  AVDemo
//
//  Created by Shepherd on 2025/4/26.
//

import UIKit

class ViewController: UIViewController {
    private var player:AudioToolboxTest?
    private var player2:AVFoundationTest?
    override func viewDidLoad() {
        super.viewDidLoad()
        // if let music = Bundle.main.url(forResource: "v24tagswithalbumimage", withExtension: "mp3") {
        if let music = Bundle.main.url(forResource: "天空之城", withExtension: "mp3") {
            player = AudioToolboxTest(path: music)
            if let format = player?.audioFormat() {
                print(format)
            }
            player?.play()
            player?.setVolumn(volumn: 0.5)
            if let len = player?.fileBytes() {
                print("File len:\(len)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
                self.player?.setVolumn(volumn: 0.1)
            })
            
            // player2 = AVFoundationTest(path: music)
            // player2?.play()
        }
    }
}

