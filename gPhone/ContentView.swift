//
//  ContentView.swift
//  gPhone
//
//  Created by Oliver Epper on 13.01.22.
//

import SwiftUI
import GRPC
import SwiftProtobuf
import Combine

struct MyButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.largeTitle)
            .padding()
            .background(.orange)
            .clipShape(Capsule())
    }
}

struct StatusView: View {
    @EnvironmentObject var client: MicroSwitchClient

    var body: some View {
        VStack {
            HStack {
                Text(client.connectionString)
                statusIndicator().frame(width: 25)
            }
            if let sessionID = client.connectedSession {
                VStack {
                    Text("Connected Session")
                    Text(sessionID.description)
                        .onTapGesture {
                            UIPasteboard.general.string = sessionID.uuidString
                        }
                }
            }
            if let invitedToSession = client.invitedToSession {
                Text("Invited to Session")
                Text(invitedToSession.description)
            }
            Group {
                Text("has local SDP: \(client.hasLocalSdp.description)")
                Text("has remote SDP: \(client.hasRemoteSdp.description)")
                Text("local candidate count: \(client.localCandidateCount)")
                Text("remote candidate count: \(client.remoteCandidateCount)")
            }
        }
    }

    private func statusIndicator() -> some View {
        if (client.serverReachable) {
            return Circle().foregroundColor(.green)
        } else {
            return Circle().foregroundColor(.red)
        }
    }

}

struct ContentView: View {
    @EnvironmentObject var client: MicroSwitchClient

    var body: some View {
        StatusView()
            .onAppear {
                client.checkServer()
                client.listHandles()
            }
            .frame(height: 200)

        List(client.handles, id:\.self) { handle in
            Button("Call \(handle)") {
                client.inviteToken = client.$connectedSession
//                    .dropFirst()
                    .compactMap { $0 }
                    .sink { id in
                        print("Session id \(id)")
                        client.invite(handle, sessionID: id)
                    }

                client.connect()
            }
        }

        if let invited = client.invitedToSession {
            Button("Talk") {
                client.answerToken = client.$connectedSession.combineLatest(client.$hasRemoteSdp)
                    .dropFirst()
                    .compactMap { $0 }
                    .sink { _, _ in
                        client.sendAnswer()
                    }

                client.connect(to: invited)
            }.buttonStyle(MyButton())
        }

        if let _ = client.connectedSession {
            Button("Stop") {
                client.disconnect()
            }.buttonStyle(MyButton())
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
