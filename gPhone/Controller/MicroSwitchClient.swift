//
//  MicroSwitchClient.swift
//  gPhone
//
//  Created by Oliver Epper on 13.01.22.
//

import Foundation
import GRPC
import SwiftProtobuf
import UIKit
import CoreMedia
import WebRTC
import Combine
import NIO

final class MicroSwitchClient: ObservableObject {
    enum Keys: String {
        case server = "server"
        case port
        case insecure
    }

    @Published var invitedToSession: UUID?
    @Published var connectedSession: UUID?
    @Published var serverReachable = false
    @Published var handles = Array<String>()
    @Published var connectionString = ""

    @Published var hasLocalSdp = false
    @Published var hasRemoteSdp = false
    @Published var localCandidateCount = 0
    @Published var remoteCandidateCount = 0

    private let connection: ClientConnection
    private var stream: BidirectionalStreamingCall<Signal, Signal>?
    private var webRTCClient = WebRTCClient(iceServers: Config.default.webRTCIceServers)
    var cancellables = Set<AnyCancellable>()

    var inviteToken: AnyCancellable?
    var answerToken: AnyCancellable?

    init() {
        UserDefaults.standard.register(defaults: [
            Self.Keys.server.rawValue : "ms.oliver-epper.de",
            Self.Keys.port.rawValue : "3015",
            Self.Keys.insecure.rawValue : false
        ])

        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)

        let host = UserDefaults.standard.string(forKey: Keys.server.rawValue)!
        let port = UserDefaults.standard.integer(forKey: Keys.port.rawValue)
        let insecure = UserDefaults.standard.bool(forKey: Keys.insecure.rawValue)

        if (insecure) {
            connectionString = "Insecure Connection \(host):\(port)"
            self.connection = .init(configuration: .default(
                target: .hostAndPort(host, port),
                eventLoopGroup: group))
        } else {
            connectionString = "Secure Connection \(host):\(port)"
            self.connection = ClientConnection.usingPlatformAppropriateTLS(for: group)
                .connect(host: host, port: port)
        }

        invitationSubject.sink { id in
            self.invitedToSession = id
        }.store(in: &cancellables)

        connection.connectivity.delegate = self
        webRTCClient.delegate = self
    }

    func checkServer() {
        let client = ServerInfoServiceClient(channel: connection)
        client.info(.init()).status.whenSuccess { _ in
            DispatchQueue.main.async {
                self.serverReachable = true
            }
        }
    }

    func addToken(token: Data, for handle: String) {
        let client = PushServiceClient(channel: connection)
        client.add(.with {
            $0.handle = handle
            $0.token = token.hexStringFromPushToken()
        }).status.whenComplete { result in
            switch result {
            case let .success(status):
                if let message = status.message {
                    print(message)
                } else {
                    print("Token added")
                }
            case let .failure(error):
                print(error)
            }
        }
    }

    func invite(_ handle: String, sessionID: UUID) {
        inviteToken = nil
        guard let data = try? JSONEncoder().encode(SessionID(value: sessionID)) else {
            return
        }

        let client = PushServiceClient(channel: connection)
        client.invite(.with {
            $0.from = UIDevice.current.name
            $0.to = [handle]
            $0.payload = data
        }) { response in
            print(response)
        }.status.cascade(to: nil)
    }

    func listHandles() {
        let client = AddressBookServiceClient(channel: connection)
        client.list(.init()) { handle in
            if handle.value.elementsEqual(UIDevice.current.name) {
                return
            }
            DispatchQueue.main.async {
                self.handles.append(handle.value)
            }
        }.status.whenComplete { result in
            print(result)
        }
    }

    func setupSignalStream() {
        let client = SignalServiceClient(channel: connection)

        stream = client.signal() { signal in
            switch signal.type {
            case let .connect(data):    self.handleConnectionEvent(data)
            case let .broadcast(data):  self.handleBroadcastEvent(data)
            case let .error(error):
                print(error)
            case .none:
                print("I cannot understand the signal type")
            }
        }

        stream?.status.whenFailure { error in
            print(error)
        }
    }

    func connect() {
        if stream == nil {
            print("Connecting to SignalService")
            setupSignalStream()
        } else {
            print("SignalService already connected")
        }

        stream?.sendMessage(.with {
            $0.connect = .init()
        }).cascade(to: nil)
    }

    func connectToSession(sessionID: UUID) {
        if stream == nil {
            print("Connecting to SignalService")
            setupSignalStream()
        } else {
            print("SignalService already connected")
        }

        stream?.sendMessage(.with {
            $0.connect = .with {
                $0.sessionID = sessionID.uuidString
            }
        }).whenComplete({ result in
            if case .success() = result {
                DispatchQueue.main.async {
                    self.connectedSession = sessionID
                }
            }
        })
    }

    func broadcast(message: Data, to session: UUID? = nil) {
        if stream == nil {
            print("Connecting to SignalService")
            setupSignalStream()
        } else {
            print("SignalService already connected")
        }

        stream?.sendMessage(.with {
            $0.broadcast = .with {
                if let sessionID = session?.uuidString {
                    $0.sessionID = sessionID
                }
                $0.payload = message
            }
        }).cascade(to: nil)
    }

    func disconnect() {
        stream?.sendEnd(promise: nil)
        stream = nil
        connectedSession = nil
    }

    func sendOffer() {
        self.webRTCClient.offer { sdp in
            DispatchQueue.main.async {
                self.hasLocalSdp = true
            }
            let message = Message.sdp(SessionDescription(from: sdp))
            guard let data = try? JSONEncoder().encode(message) else {
                return
            }
            self.broadcast(message: data)
        }
    }

    func sendAnswer() {
        self.inviteToken = nil
        self.webRTCClient.answer { sdp in
            DispatchQueue.main.async {
                self.hasLocalSdp = true
            }
            let message = Message.sdp(SessionDescription(from: sdp))
            guard let data = try? JSONEncoder().encode(message) else {
                return
            }
            self.broadcast(message: data)
        }
    }

    private func handleConnectionEvent(_ data: Connect) {
        if data.connected {
            print("Someone else connected to my session. I will do the do")
            self.sendOffer()
        } else {
            print("I created the Session \(data.sessionID)")
            DispatchQueue.main.async {
                self.connectedSession = UUID(uuidString: data.sessionID)
            }
        }
    }

    private func handleBroadcastEvent(_ data: Broadcast) {
        print("I received: \(data.payload)")
        do {
            let message = try JSONDecoder().decode(Message.self, from: data.payload)

            switch message {
            case let .sdp(sessionDescription):
                self.handleRemoteSdp(sessionDescription)
            case let .candidate(iceCandidate):
                self.handleRemoteCandidate(iceCandidate)
            }
        } catch {
            print("ERROR: Could not decode incoming message")
            return
        }
    }

    private func handleRemoteSdp(_ data: SessionDescription) {
        self.webRTCClient.set(remoteSdp: data.rtcSessionDescription) { error in
            if let error = error {
                print(error)
                return
            }

            DispatchQueue.main.async {
                self.hasRemoteSdp = true
            }
        }
    }

    private func handleRemoteCandidate(_ data: IceCandidate) {
        self.webRTCClient.set(remoteCandidate: data.rtcIceCandidate) { error in
            if let error = error {
                print(error)
                return
            }

            DispatchQueue.main.async {
                self.remoteCandidateCount += 1
            }
        }
    }
}

extension MicroSwitchClient: ConnectivityStateDelegate {
    func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        print("\(oldState) -> \(newState)")
    }
}


extension MicroSwitchClient: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        DispatchQueue.main.async {
            self.localCandidateCount += 1
        }
        let message = Message.candidate(IceCandidate.init(from: candidate))
        guard let data = try? JSONEncoder().encode(message) else {
            return
        }
        self.broadcast(message: data)
        print(#function)
    }

    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        print(#function)
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        print(#function)
    }


}
