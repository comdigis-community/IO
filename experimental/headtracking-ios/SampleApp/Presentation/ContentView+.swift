//
//  Copyright (c) 2019 - 2027 Comdigis, Argentina
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import SwiftUI
import Foundation
import simd

struct FloatingPlaybackView: View {
    let title: String
    let artist: String
    let coverAssetName: String
    let isPlaying: Bool
    let isEnabled: Bool
    let onPlayPause: () -> Void

    var body: some View {
        HStack(spacing: 12.0) {
            Image(coverAssetName)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
                .frame(width: 44.0, height: 44.0)
                .clipShape(RoundedRectangle(cornerRadius: 8.0, style: .continuous))

            VStack(alignment: .leading, spacing: 0.0) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(artist)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10.0)

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16.0, weight: .semibold))
                    .frame(width: 36.0, height: 36.0)
                    .background(.regularMaterial.opacity(isEnabled ? 1.0 : 0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
        .padding(.horizontal, 14.0)
        .padding(.vertical, 10.0)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16.0, style: .continuous))
    }
}

struct AirPodsPromptView: View {
    var body: some View {
        VStack(spacing: 12.0) {
            Image(systemName: "airpodspro")
                .font(.system(size: 44.0, weight: .regular))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 44.0)

            Text("Connect your AirPods to continue")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }
}
