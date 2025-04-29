//
//  AudioToolboxTest.swift
//  AVDemo
//
//  Created by Shepherd on 2025/4/28.
//

import UIKit
import AudioToolbox

class AudioToolboxTest: NSObject {
    private var audioFile: AudioFileID?
    private var path: URL
    private var queue:AudioQueueRef?;
    private var packetDescs: UnsafeMutablePointer<AudioStreamPacketDescription>?
    private let maxBufferNum = 3 // 示例值，根据实际情况调整
    private var buffers = [AudioQueueBufferRef?](repeating: nil, count: 3) // 根据maxBufferNum调整
    private let maxBufferSize: UInt32 = 0x10000 // 示例值
    private let minBufferSize: UInt32 = 0x4000 // 示例值
    private var numPacketsToRead:UInt32 = 0
    private var packetIndex:Int64 = 0
    private var maxPacketSize: UInt32 = 0
    private var size = UInt32(MemoryLayout<UInt32>.size)
    private var outBufferSize: UInt32 = 0
    
    private let playbackCallback: AudioQueueOutputCallback = {
        inUserData,          // UnsafeMutableRawPointer?
        inAQ,                // AudioQueueRef
        buffer               // AudioQueueBufferRef
        in
        
        // 1. 保护
        guard let inUserData = inUserData else { return }
        
        // 2. 将指针转换为对象实例
        let player:AudioToolboxTest = Unmanaged<AudioToolboxTest>.fromOpaque(inUserData).takeUnretainedValue()
        
        // 3. 实际处理逻辑
        // 调用对象方法处理音频缓冲区
        player.audioQueueOutput(audioQueue: inAQ, queueBuffer: buffer)
    }
    
    /// 属性变更回调
    private let propertyChangeCallback: AudioQueuePropertyListenerProc = {
        inUserData,          // UnsafeMutableRawPointer?
        inAQ,                // AudioQueueRef
        buffer               // AudioQueueBufferRef
        in
        guard let inUserData = inUserData else { return }
        print("property changed")
    }
    
    init(path: URL) {
        self.path = path
    }
    
    func play() {
        var format = self.audioFormat()
        guard format != nil else {
            return;
        }
        
        var status = AudioFileOpenURL(path as CFURL, .readPermission, 0, &audioFile)
        guard status == noErr else {
            return
        }
        
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        // 创建输出队列,注册回调函数
        status = AudioQueueNewOutput(&format!, playbackCallback, context, nil, nil, 0, &queue)
        guard status == noErr else {
            print("Create new output queue error")
            return
        }
        
        status = AudioFileGetProperty(audioFile!, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize)
        guard status == noErr else {
            print("Get maxPacketSize property error")
            return
        }
        
        print(maxPacketSize)
        
        // 计算缓冲区大小
        // For uncompressed audio, the value is 1. For variable bit-rate formats, the value is a larger fixed number, such as 1024 for AAC. For formats with a variable number of frames per packet, such as Ogg Vorbis, set this field to 0.
        // MP3的值是1152
        if format!.mFramesPerPacket != 0 {
            // 每秒的包的数量 = 采样率/每个包的帧数
            // 比如MP3每秒采样44100次,每个包有1152帧,两者相除就是每秒的包数量
            let numPacketsPerSecond = format!.mSampleRate / Double(format!.mFramesPerPacket)
            // 每秒的包的数量 * 包大小的理论峰值, 即1s内占用内存的峰值
            outBufferSize = UInt32(numPacketsPerSecond * Double(maxPacketSize))
        } else {
            outBufferSize = max(maxBufferSize, maxPacketSize)
        }
        
        // 调整缓冲区大小
        if outBufferSize > maxBufferSize && outBufferSize > maxPacketSize {
            outBufferSize = maxBufferSize
        } else if outBufferSize < minBufferSize {
            outBufferSize = minBufferSize
        }
        
        // 计算包数量并分配包描述数组
        // 每次读取的包的数量 = 缓冲区大小 / 包大小的理论峰值
        numPacketsToRead = outBufferSize / maxPacketSize
        packetDescs = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: Int(numPacketsToRead))
        packetDescs?.initialize(repeating: AudioStreamPacketDescription(), count: Int(numPacketsToRead))
        
        // 分配3个缓冲区
        for i in 0..<maxBufferNum {
            var buffer: AudioQueueBufferRef?
            /**
             Once allocated, the pointer to the buffer and the buffer's size are fixed and cannot be
             changed. The mAudioDataByteSize field in the audio queue buffer structure,
             AudioQueueBuffer, is initially set to 0.
             
             @param      inAQ
             // 分配缓冲区的音频队列
             The audio queue you want to allocate a buffer.
             @param      inBufferByteSize
             // 缓冲区大小
             The desired size of the new buffer, in bytes. An appropriate buffer size depends on the
             processing you will perform on the data as well as on the audio data format.
             @param      outBuffer
             // 指向新创建的缓冲区
             On return, points to the newly created audio buffer. The mAudioDataByteSize field in the
             audio queue buffer structure, AudioQueueBuffer, is initially set to 0.
             @result     An OSStatus result code.
             */
            AudioQueueAllocateBuffer(queue!, outBufferSize, &buffer)
            buffers[i] = buffer
            audioQueueOutput(audioQueue: queue!, queueBuffer: buffer!)
        }
        
        // 启动队列
        AudioQueueStart(queue!, nil)
    }
    
    public func audioQueueOutput(audioQueue: AudioQueueRef, queueBuffer audioQueueBuffer: AudioQueueBufferRef) {
        var ioNumBytes = outBufferSize
        var ioNumPackets = numPacketsToRead
        
        // 读取音频文件
        let status = AudioFileReadPacketData(
            audioFile!,  // 音频文件
            false, // 是否缓存
            // on input the size of outBuffer in bytes.
            // on output, the number of bytes actually returned.
            // 输入场景等于缓存大小
            // 输出场景:比如播放根据文件的实际情况
            &ioNumBytes, // 包的长度
            packetDescs, // 音频包信息
            packetIndex, // 索引值
            &ioNumPackets, // 包的个数
            audioQueueBuffer.pointee.mAudioData // 读取到的数据
        )
        
        guard status == noErr else {
            print("Error reading packet data: \(status)")
            return
        }
        
        if ioNumPackets > 0 {
            // 设置音频缓冲区数据大小
            audioQueueBuffer.pointee.mAudioDataByteSize = ioNumBytes
            
            // 将音频数据入队列让系统去播放
            AudioQueueEnqueueBuffer(
                audioQueue,
                audioQueueBuffer,
                ioNumPackets,
                packetDescs
            )
            
            // 更新包的索引值
            self.packetIndex += Int64(ioNumPackets)
        }
    }
    
    // 暂停
    public func pause() {
        AudioQueuePause(queue!)
    }
    
    // 恢复
    public func resume() {
        AudioQueueStart(queue!, nil)
    }
    
    // 停止
    public func stop() {
        AudioQueueStop(queue!, true)
    }
    
    // 设置声音
    public func setVolumn(volumn:Float32) {
        AudioQueueSetParameter(self.queue!, kAudioQueueParam_Volume, volumn)
    }
    
    public func volumn() -> Float32 {
        var volumn:Float32 = 0
        let status = AudioQueueGetParameter(self.queue!, kAudioQueueParam_Volume, &volumn)
        guard status == noErr else {
            return 0
        }
        return volumn
    }
    
    // 使用AudioTools.framework获取音频格式信息
    public func audioFormat() -> AudioStreamBasicDescription? {
        var size: UInt32 = 0
        var audioFile: AudioFileID? // 使用可选类型
        var status = AudioFileOpenURL(self.path as CFURL, .readPermission, 0, &audioFile)
        guard status == noErr else {
            print("*** Error *** filePath: \(self.path) -- code: \(status)")
            return nil
        }
        
        // 获取音频数据格式
        var dataFormat = AudioStreamBasicDescription()
        size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        status = AudioFileGetProperty(
            audioFile!,
            kAudioFilePropertyDataFormat,
            &size,
            &dataFormat
        )
        
        // 可选：检查属性获取是否成功
        guard status == noErr else {
            print("Failed to get data format: \(status)")
            AudioFileClose(audioFile!) // 关闭文件防止泄漏
            return nil
        }
        
        return dataFormat
    }
    
    // 文件大小
    public func fileBytes() -> UInt64 {
        var c:UInt64 = 0
        var size = UInt32(MemoryLayout<UInt64>.size)
        let status = AudioFileGetProperty(
            audioFile!,
            kAudioFilePropertyAudioDataByteCount,
            &size,
            &c
        )
        guard status == noErr else {
            return 0
        }
        
        return c
    }

    deinit {
        if let queue = queue {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }
    }
}
