import Flutter
import UIKit
import ReplayKit
import AVFoundation

public class SwiftFlutterScreenRecordingPlugin: NSObject, FlutterPlugin {
    
    let recorder = RPScreenRecorder.shared()
    var videoWriter: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    var audioWriterInput: AVAssetWriterInput?
    var videoOutputURL: URL?
    var isRecording = false
    private var isStarting = false
    private var isStopping = false
    var firstTimestamp: CMTime? 
    let screenSize = UIScreen.main.bounds
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_screen_recording", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterScreenRecordingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecordScreen":
            guard let args = call.arguments as? [String: Any],
                  let name = args["name"] as? String,
                  let includeAudio = args["audio"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments", details: nil))
                return
            }
            startRecording(videoName: name, recordAudio: includeAudio, result: result)
        case "stopRecordScreen", "stopRecordScreenConfirmed":
            stopRecording(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func startRecording(videoName: String, recordAudio: Bool, result: @escaping FlutterResult) {
        guard !isStarting, !isStopping, !recorder.isRecording else {
            result(FlutterError(code: "ALREADY_RECORDING", message: "Recording is already in progress", details: nil))
            return
        }
        
        isRecording = true
        
        // Configurar la ruta del archivo de video
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        videoOutputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("\(videoName).mp4")
        
        // Eliminar el archivo si ya existe
        if FileManager.default.fileExists(atPath: videoOutputURL!.path) {
            try? FileManager.default.removeItem(at: videoOutputURL!)
        }
        
        if #available(iOS 11.0, *) {
            // Crear el AVAssetWriter
            do {
                videoWriter = try AVAssetWriter(outputURL: videoOutputURL!, fileType: .mp4)
            } catch {
                isRecording = false
                result(FlutterError(code: "FILE_ERROR", message: "Unable to create video file", details: error.localizedDescription))
                return
            }
            
            // Configurar la entrada de video
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: screenSize.width,
                AVVideoHeightKey: screenSize.height
            ]
            videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoWriterInput?.expectsMediaDataInRealTime = true
            videoWriter?.add(videoWriterInput!)
            
            // Configurar la entrada de audio si es necesario
            audioWriterInput = nil
            if recordAudio {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2
                ]
                audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioWriterInput?.expectsMediaDataInRealTime = true
                videoWriter?.add(audioWriterInput!)
            }
            
            // Iniciar la captura con ReplayKit
            recorder.isMicrophoneEnabled = recordAudio
            isStarting = true
            recorder.startCapture(handler: { [weak self] sampleBuffer, sampleBufferType, error in
                DispatchQueue.main.async {
                    guard let self = self, self.isRecording, error == nil else { return }
                    switch sampleBufferType {
                    case .video:
                        self.handleVideoBuffer(sampleBuffer)
                    case .audioMic:
                        if recordAudio {
                            self.handleAudioBuffer(sampleBuffer)
                        }
                    default:
                        break
                    }
                }
            }) { error in
                DispatchQueue.main.async {
                    self.isStarting = false
                    if let error = error {
                        self.isRecording = false
                        result(FlutterError(code: "CAPTURE_ERROR", message: "Failed to start screen recording", details: error.localizedDescription))
                    } else {
                        result(true)
                    }
                }
            }
        } 
        else {
            isRecording = false
            result(FlutterError(code: "IOS_VERSION_ERROR", message: "This feature is only available on iOS 11 or later", details: nil))
        }
    }
    
    func handleVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Añadir el video al archivo
        guard let writer = videoWriter, let input = videoWriterInput else { return }
        
        if writer.status == .unknown {
            firstTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startWriting()
            writer.startSession(atSourceTime: firstTimestamp!)
        }
        
        if writer.status == .writing && input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }
    
    func handleAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Añadir el audio al video
        guard let writer = videoWriter, let input = audioWriterInput else { return }
        
        if writer.status == .writing && input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }
    
    func stopRecording(result: @escaping FlutterResult) {
        guard !isStarting, !isStopping else {
            result(FlutterError(code: "RECORDING_PENDING", message: "A recording operation is still pending", details: nil))
            return
        }
        guard recorder.isRecording else {
            isRecording = false
            if videoWriter?.status == .writing { videoWriter?.cancelWriting() }
            result("")
            return
        }
        guard #available(iOS 11.0, *) else {
            result(FlutterError(code: "IOS_VERSION_ERROR", message: "This feature is only available on iOS 11 or later", details: nil))
            return
        }
        isStopping = true
        recorder.stopCapture { error in
            DispatchQueue.main.async {
                guard !self.recorder.isRecording else {
                    self.isStopping = false
                    result(FlutterError(code: "STOP_ERROR", message: "Recording stop was not confirmed", details: error?.localizedDescription))
                    return
                }
                self.isRecording = false
                guard let writer = self.videoWriter, writer.status == .writing else {
                    self.isStopping = false
                    result("")
                    return
                }
                self.videoWriterInput?.markAsFinished()
                self.audioWriterInput?.markAsFinished()
                writer.finishWriting {
                    DispatchQueue.main.async {
                        self.isStopping = false
                        result(writer.status == .completed ? writer.outputURL.path : "")
                    }
                }
            }
        }
    }
}
