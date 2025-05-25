//
//  CustomErrorView.swift
//  StikJIT
//
//  Created by neoarz on 3/29/25.
//

import SwiftUI

public enum MessageType {
    case error
    case success
    case info
}

struct CustomErrorView: View {
    var title: String
    var message: String
    var onDismiss: () -> Void
    var showButton: Bool = true
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    var primaryButtonText: String = "OK"
    var secondaryButtonText: String = "Cancel"
    var onPrimaryButtonTap: (() -> Void)? = nil
    var onSecondaryButtonTap: (() -> Void)? = nil
    var showSecondaryButton: Bool = false
    var messageType: MessageType = .error
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    
    private var accentColor: Color {
        if customAccentColorHex.isEmpty {
            return .blue
        } else {
            return Color(hex: customAccentColorHex) ?? .blue
        }
    }
    
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .opacity(opacity)
                .onTapGesture {
                    if showButton {
                        dismissWithAnimation()
                    }
                }
            
            // Card itself
            VStack(spacing: 12) {
                // Icon based on messageType
                switch messageType {
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red.opacity(0.9))
                        .padding(.top, 8)
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green.opacity(0.9))
                        .padding(.top, 8)
                case .info:
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor.opacity(0.9))
                        .padding(.top, 8)
                }
                
                // Title - slightly smaller
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.center)
                
                // Divider
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.2))
                    .padding(.horizontal, 12)
                
                // Message 
                Text(LocalizedStringKey(message))
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                
                
                // Dismiss button (only shown when showButton is true)
                if showButton {
                    VStack(spacing: 6) {
                        Button(action: {
                            dismissWithAnimation()
                            onPrimaryButtonTap?() // Call primary action if provided
                        }) {
                            Text(primaryButtonText)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                                .frame(height: 38)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(colorScheme == .dark ? Color.white : accentColor)
                                )
                        }
                        
                        if showSecondaryButton {
                            Button(action: {
                                dismissWithAnimation()
                                onSecondaryButtonTap?() // Call secondary action if provided
                            }) {
                                Text(secondaryButtonText)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white : .gray)
                                    .frame(height: 38)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .padding(.top, 6)
                } else {
                    Spacer()
                        .frame(height: 12)
                }
            }
            // Made the card smaller overall
            .frame(width: min(UIScreen.main.bounds.width - 80, 300))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? 
                          Color(UIColor.systemGray6).opacity(0.95) : 
                          Color(UIColor.systemGray6).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colorScheme == .dark ? 
                                   Color.white.opacity(0.2) : 
                                   Color.black.opacity(0.1), 
                                   lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.15), radius: 16, x: 0, y: 8)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
            }
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.15)) {
            opacity = 0
            scale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDismiss()
        }
    }
} 
