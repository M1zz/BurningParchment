// BlowDetector.swift
// 마이크에 대고 "후" 부는 입김을 감지한다. 소리는 녹음·저장하지 않고 음량만 본다.
//
// 입김은 마이크 바로 앞에서 넓은 대역의 큰 소음으로 들어온다(-15dBFS 안팎).
// 말소리도 순간적으로는 비슷하게 커질 수 있어서, 한 번 튀는 소리로는 꺼지지 않고
// "센 입김이 이어지는 동안" 꺼짐 정도(extinguish)가 차오르게 했다.

import AVFoundation
import Combine
import os

// @unchecked Sendable: 엔진·isRunning 은 audioQueue 에서만, @Published 값은 메인에서만 만지고
// wanted 는 잠금으로 지킨다. 그 규칙 안에서만 스레드를 건너간다.
final class BlowDetector: ObservableObject, @unchecked Sendable {
    enum Availability { case unknown, listening, unavailable }

    /// 지금 들어오는 입김의 세기 (0~1). 불꽃이 눕는 정도에 쓴다.
    @Published private(set) var breath: Double = 0
    /// 불이 꺼진 정도 (0~1). 1 이 되면 꺼진 것.
    @Published private(set) var extinguish: Double = 0
    @Published private(set) var availability: Availability = .unknown

    private let engine = AVAudioEngine()

    // 오디오 세션 켜기·끄기(setActive)는 수십~수백 ms 걸릴 수 있어 메인에서 부르면 화면이 멈춘다.
    // 세션·엔진은 이 직렬 큐에서만 만진다 — 시작과 정지가 부른 순서대로 처리된다.
    private let audioQueue = DispatchQueue(label: "BlowDetector.audio", qos: .userInitiated)
    /// 큐에서만 읽고 쓴다
    private var isRunning = false
    /// 화면이 지금 마이크를 원하는지. 권한을 묻는 사이에 화면이 닫히면 늦게 온 시작을 버린다.
    private let wanted = OSAllocatedUnfairLock(initialState: false)

    // 음량 → 0~1. -50dBFS 이하는 조용함, -12dBFS 이상은 최대.
    private static let floorDB: Float = -50
    private static let ceilDB:  Float = -12
    /// 이 세기를 넘는 입김만 불을 끈다
    private static let blowThreshold: Double = 0.62
    /// 센 입김을 대략 0.8초 이어 불면 꺼진다
    private static let fillPerSecond: Double = 1.4
    /// 멈추면 불이 천천히 되살아난다
    private static let recoverPerSecond: Double = 0.25

    // MARK: - Start / Stop

    @MainActor
    func start() async {
        wanted.withLock { $0 = true }
        guard await AVAudioApplication.requestRecordPermission() else {
            availability = .unavailable
            return
        }
        let result: Availability? = await withCheckedContinuation { cont in
            audioQueue.async { cont.resume(returning: self.startOnQueue()) }
        }
        if let result { availability = result }
    }

    /// 큐에서 부른다. 이미 듣고 있거나 그새 화면이 닫혔으면 nil (상태를 바꾸지 않는다).
    private func startOnQueue() -> Availability? {
        guard !isRunning, wanted.withLock({ $0 }) else { return nil }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            // 입력 장치가 없으면(일부 시뮬레이터 등) 샘플레이트가 0 으로 나온다
            guard format.sampleRate > 0, format.channelCount > 0 else {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                return .unavailable
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.process(buffer)
            }
            engine.prepare()
            try engine.start()
            isRunning = true
            return .listening
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            return .unavailable
        }
    }

    func stop() {
        wanted.withLock { $0 = false }
        audioQueue.async { [weak self] in
            guard let self, self.isRunning else { return }
            self.isRunning = false
            Self.tearDown(self.engine)
        }
        DispatchQueue.main.async { [weak self] in self?.breath = 0 }
    }

    private static func tearDown(_ engine: AVAudioEngine) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Level

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let samples = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }

        var sum: Float = 0
        for i in 0..<n { sum += samples[i] * samples[i] }
        let rms = sqrt(sum / Float(n))
        let db = 20 * log10(max(rms, 1e-7))
        let level = Double(min(max((db - Self.floorDB) / (Self.ceilDB - Self.floorDB), 0), 1))
        let dt = Double(n) / buffer.format.sampleRate

        DispatchQueue.main.async { [weak self] in
            guard let self, self.extinguish < 1 else { return }
            // 세지는 건 바로, 약해지는 건 천천히 — 불꽃이 입김에 부드럽게 눕고 일어선다
            let k = level > self.breath ? 0.6 : 0.15
            self.breath += (level - self.breath) * k

            if level > Self.blowThreshold {
                let push = (level - Self.blowThreshold) / (1 - Self.blowThreshold)
                self.extinguish = min(1, self.extinguish + (0.5 + push) * Self.fillPerSecond * dt)
            } else {
                self.extinguish = max(0, self.extinguish - Self.recoverPerSecond * dt)
            }
        }
    }

    deinit {
        // 큐의 시작 작업은 self 를 붙잡고 있으므로, 여기까지 왔으면 isRunning 은 더 바뀌지 않는다.
        // 듣던 중일 때만 정리한다 — 그렇지 않으면 다른 화면이 켠 오디오 세션을 끌 수 있다.
        guard isRunning else { return }
        let engine = self.engine
        audioQueue.async { Self.tearDown(engine) }
    }
}
