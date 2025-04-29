//
//  AVFoundationPlayer.swift
//  AVDemo
//
//  Created by Shepherd on 2025/4/28.
//

import UIKit
import AVFoundation

class AVFoundationTest: NSObject, AVAudioPlayerDelegate {
    private var player:AVAudioPlayer?
    private var path: URL?
    
    init(path: URL) {
        super.init()
        self.path = path
        NotificationCenter.default.addObserver(self, selector: #selector(enterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc func enterBackground() {
        print("Enter background")
    }
    
    // 使用AVFoundation.framework播放音频
    func play() {
        do {
            // 1. 创建AVAudioPlayer
            self.player = try AVAudioPlayer(contentsOf: path!)
            self.player?.delegate = self
            // 2. 准备播放
            if let _ = self.player?.prepareToPlay() {
                print("Play music")
                // 3.播放
                self.player?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
                    print("Play pause")
                    // 暂停
                    self.player?.pause()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
                        print("Play replay")
                        // 音量调节
                        self.player?.volume = 0.5
                        // 快进
                        self.player?.currentTime += 80
                        // 继续播放
                        self.player?.play()
                        // 音频会话类型简介
                        /**
                         1. AVAudioSessionCategoryAmbient 混音播放，可以与其他音频应用同时播放
                         2. AVAudioSessionCategorySoloAmbient 独占播放
                         3. AVAudioSessionCategoryPlayback 后台播放，也是独占的
                         4. AVAudioSessionCategoryRecord 录音模式，用于录音时使用
                         5. AVAudioSessionCategoryPlayAndRecord 播放和录音，此时可以录音也可以播放
                         6. AVAudioSessionCategoryAudioProcessing 硬件解码音频，此时不能播放和录制
                         7. AVAudioSessionCategoryMultiRoute 多种输入输出，例如可以耳机、USB设备同时播放
                         */
                        self.playCategory(category: .playback)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: {
                            print("Play stop")
                            // 停止
                            self.player?.stop()
                        })
                    })
                    
                })
                
            }
        } catch {
            
        }
    }
    
    func playCategory(category:AVAudioSession.Category) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(category)
            try session.setActive(true)
        } catch {
            
        }
    }
    
    /* audioPlayerDidFinishPlaying:successfully: is called when a sound has finished playing. This method is NOT called if the player is stopped due to an interruption. */
    // 正常播放结束才会回调
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("notification: Play stop \(flag)")
    }
}
