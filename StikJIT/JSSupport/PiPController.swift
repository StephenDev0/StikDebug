//
//  PiPController.swift
//  StikDebug
//
//  Created by Stossy11 on 10/07/2025.
//


import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: UIViewRepresentable {
    let pipController: PiPController = PiPController.shared
    let view: any View
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        // Setup player layer
        let playerLayer = AVPlayerLayer()
        playerLayer.frame = CGRect(x: 0, y: 0, width: 200, height: 150)
        
        // Load video from bundle
        guard let videoURL = Bundle.main.url(forResource: "black", withExtension: "MP4") else {
            print("Could not find black.MP4 in bundle")
            return containerView
        }
        
        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        playerLayer.player = player
        player.isMuted = true
        player.allowsExternalPlayback = true
        
        containerView.layer.addSublayer(playerLayer)
        
        // Convert SwiftUI view to UIView using UIHostingController
        let hostingController = UIHostingController(rootView: AnyView(self.view))
        let swiftUIAsUIView = hostingController.view!
        
        // Set the converted UIView to the PiPController
        pipController.customUIView = swiftUIAsUIView
        
        pipController.setupPiP(with: playerLayer)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update UI if needed
    }
}
