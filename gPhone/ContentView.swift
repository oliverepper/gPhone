//
//  ContentView.swift
//  gPhone
//
//  Created by Oliver Epper on 13.01.22.
//

import SwiftUI
import GRPC
import SwiftProtobuf

struct ContentView: View {
    @EnvironmentObject var client: MicroSwitchClient

    var body: some View {
        if let sessionID = client.connectedSession {
            Text(sessionID.description)
                .onTapGesture {
                    UIPasteboard.general.string = sessionID.uuidString
                }
        }
        List(client.handles, id:\.self) { handle in
            Button(handle) {
                client.invite(handle)
            }
        }
        statusIndicator().frame(width: 30)
            .onAppear {
                client.checkServer()
                client.listHandles()
            }
        Text("Invited to Session \(client.invitedToSession?.uuidString.prefix(10).description ?? "")").font(.headline)
        Group {
            Text("has local SDP: \(client.hasLocalSdp.description)")
            Text("has remote SDP: \(client.hasRemoteSdp.description)")
            Text("local candidate count: \(client.localCandidateCount)")
            Text("remote candidate count: \(client.remoteCandidateCount)")
        }
        Group {
            Button("Create Session") {
                client.connect()
            }
            if let session = client.invitedToSession?.uuidString {
                Button("Connect to Session") {
                    client.connectToSession(sessionID: session)
                }
            }
//            Button("Broadcast Message") {
//                client.broadcast(message: "Hallo Welt".data(using: .utf8)!)
//            }
//            Button("Send Offer") {
//                client.sendOffer()
//            }
            Button("Answer") {
                client.sendAnswer()
            }
            Button("Stop") {
                client.disconnect()
            }
        }.font(.system(size: 22.0))
    }
    
    private func statusIndicator() -> some View {
        if (client.serverReachable) {
            return Circle().foregroundColor(.green)
        } else {
            return Circle().foregroundColor(.red)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
