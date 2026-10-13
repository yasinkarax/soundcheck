import AppKit
import CoreAudio
import AudioRender

struct AudioFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
func check(_ status: OSStatus, _ operation: String) throws {
    if status != noErr { throw AudioFailure(message: "\(operation) failed (\(status)). Check Soundcheck’s system audio recording permission in System Settings.") }
}
func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}
func readValue<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, initial: T, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> T {
    var value = initial
    var size = UInt32(MemoryLayout<T>.size)
    var key = address(selector, scope)
    try withUnsafeMutablePointer(to: &value) { pointer in
        try check(AudioObjectGetPropertyData(id, &key, 0, nil, &size, pointer), "Read audio property")
    }
    return value
}
func readString(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<CFString>.size)
    var key = address(selector)
    try check(AudioObjectGetPropertyData(id, &key, 0, nil, &size, &value), "Read audio name")
    guard let value else { throw AudioFailure(message: "Audio property returned no name.") }
    return value.takeRetainedValue() as String
}
func readIDs(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> [AudioObjectID] {
    var key = address(selector, scope)
    var size: UInt32 = 0
    try check(AudioObjectGetPropertyDataSize(id, &key, 0, nil, &size), "Read audio list")
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard !ids.isEmpty else { return [] }
    try ids.withUnsafeMutableBytes { bytes in
        try check(AudioObjectGetPropertyData(id, &key, 0, nil, &size, bytes.baseAddress!), "Read audio list")
    }
    return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
}

struct AudioApp: Identifiable {
    let id: String
    let name: String
    let icon: NSImage?
    var processes: [AudioObjectID]
    var active: Bool
}

@available(macOS 14.2, *)
func discoverApps() throws -> [AudioApp] {
    var apps: [String: AudioApp] = [:]
    for object in try readIDs(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList) {
        guard let pid = try? readValue(object, kAudioProcessPropertyPID, initial: pid_t(0)), pid != ProcessInfo.processInfo.processIdentifier else { continue }
        let running = NSRunningApplication(processIdentifier: pid)
        let bundle = (try? readString(object, kAudioProcessPropertyBundleID)) ?? ""
        let key = bundle.isEmpty ? "pid:\(pid)" : bundle
        let active = (try? readValue(object, kAudioProcessPropertyIsRunningOutput, initial: UInt32(0))) == 1
        if var existing = apps[key] {
            existing.processes.append(object)
            existing.active = existing.active || active
            apps[key] = existing
        } else {
            let applicationURL = bundle.isEmpty ? nil : NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
            let outermostAppURL = containingApplicationURL(for: running?.bundleURL ?? applicationURL)
            let bundleName = outermostAppURL?.deletingPathExtension().lastPathComponent
            let runningName = running?.localizedName
            let helperFreeName = runningName?.replacingOccurrences(of: " Helper", with: "")
            let bundleLeaf = bundle.split(separator: ".").last.map(String.init)
            let friendlySystemName = bundle == "com.apple.CoreSpeech" ? "Speech Services" : nil
            let resolvedName = bundleName ?? friendlySystemName
                ?? helperFreeName.flatMap { $0 == bundle ? nil : $0 }
                ?? bundleLeaf.map { $0.replacingOccurrences(of: "-", with: " ") }
                ?? "Audio process \(pid)"
            let appIcon = outermostAppURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
            apps[key] = AudioApp(id: key, name: resolvedName, icon: appIcon, processes: [object], active: active)
        }
    }
    return apps.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

private func containingApplicationURL(for startURL: URL?) -> URL? {
    guard var current = startURL else { return nil }
    var outermostApp: URL?
    while current.pathComponents.count > 1 {
        if current.pathExtension == "app" { outermostApp = current }
        let parent = current.deletingLastPathComponent()
        guard parent != current else { break }
        current = parent
    }
    return outermostApp
}

final class GainStorage {
    let pointer: OpaquePointer
    init() throws {
        guard let pointer = MixerGainCreate() else { throw AudioFailure(message: "Could not allocate audio state.") }
        self.pointer = pointer
    }
    deinit { MixerGainDestroy(pointer) }
}

@available(macOS 14.2, *)
final class AudioSession {
    private var tap: AudioObjectID = 0
    private var device: AudioObjectID = 0
    private var io: AudioDeviceIOProcID?
    private let storage: GainStorage
    private var gain: OpaquePointer { storage.pointer }
    let processes: [AudioObjectID]
    let output: AudioObjectID

    init(processes: [AudioObjectID], output: AudioObjectID, volume: Float) throws {
        storage = try GainStorage()
        let state = storage.pointer
        self.processes = processes
        self.output = output
        MixerGainSet(gain, volume)
        do {
            let uid = try readString(output, kAudioDevicePropertyDeviceUID)
            let description = CATapDescription(processes: processes, deviceUID: uid, stream: 0)
            description.name = "Soundcheck app volume"
            description.isPrivate = true
            description.muteBehavior = .mutedWhenTapped
            try check(AudioHardwareCreateProcessTap(description, &tap), "Create app audio tap")
            let format = try readValue(tap, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
            guard format.mFormatID == kAudioFormatLinearPCM,
                  format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
                  format.mBitsPerChannel == 32, format.mChannelsPerFrame == 2 else {
                throw AudioFailure(message: "This first version supports stereo, 32-bit floating-point output devices. Choose your Mac speakers or stereo headphones.")
            }
            let composition: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Soundcheck private mixer",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceMainSubDeviceKey: uid,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: uid, kAudioSubDeviceInputChannelsKey: 0]],
                kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString, kAudioSubTapDriftCompensationKey: true]],
                kAudioAggregateDeviceTapAutoStartKey: true
            ]
            try check(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &device), "Create mixer device")
            // Reject unknown layouts before the tap starts muting the original audio.
            let inputs = try streamFormats(scope: kAudioDevicePropertyScopeInput)
            let outputs = try streamFormats(scope: kAudioDevicePropertyScopeOutput)
            guard !inputs.isEmpty, inputs.count == outputs.count,
                  zip(inputs, outputs).allSatisfy({ a, b in
                      a.mFormatID == kAudioFormatLinearPCM && b.mFormatID == kAudioFormatLinearPCM &&
                      a.mFormatFlags & kAudioFormatFlagIsFloat != 0 && b.mFormatFlags & kAudioFormatFlagIsFloat != 0 &&
                      a.mBitsPerChannel == 32 && b.mBitsPerChannel == 32 &&
                      a.mChannelsPerFrame == b.mChannelsPerFrame && a.mSampleRate == b.mSampleRate &&
                      a.mBytesPerFrame == b.mBytesPerFrame
                  }), outputs.reduce(0, { $0 + $1.mChannelsPerFrame }) == 2 else {
                throw AudioFailure(message: "This output device’s audio layout is not supported yet. Your original audio has been preserved.")
            }
            try check(AudioDeviceCreateIOProcIDWithBlock(&io, device, nil) { _, input, _, output, _ in
                MixerRender(state, input, output)
            }, "Create audio renderer")
            try check(AudioDeviceStart(device, io), "Start app volume control")
        } catch {
            stop()
            throw error
        }
    }
    private func streamFormats(scope: AudioObjectPropertyScope) throws -> [AudioStreamBasicDescription] {
        try readIDs(device, kAudioDevicePropertyStreams, scope: scope).map {
            try readValue($0, kAudioStreamPropertyVirtualFormat, initial: AudioStreamBasicDescription())
        }
    }
    func setVolume(_ value: Float) { MixerGainSet(gain, value) }
    func stop() {
        if let io {
            AudioDeviceStop(device, io)
            AudioDeviceDestroyIOProcID(device, io)
            self.io = nil
        }
        if device != 0 { AudioHardwareDestroyAggregateDevice(device); device = 0 }
        if tap != 0 { AudioHardwareDestroyProcessTap(tap); tap = 0 }
    }
    deinit { stop() }
}
