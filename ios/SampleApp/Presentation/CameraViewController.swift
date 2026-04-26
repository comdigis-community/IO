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

import UIKit
import RealityKit
import QuartzCore
import IO

class CameraViewController: UIViewController {

    var arView: ARView!
    var coordinator: BinauralCoordinator?
    var objectAnchor: AnchorEntity?
    
    private var onboardingOverlayView: UIView?
    private var preloaderOverlayView: UIView?
    private var isReadyForPlacement = false
    private var listenerUpdateModel = ListenerUpdate()
    private var tick: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        configurePreloaderOverlay()
        configureOnboardingOverlay()
        warmUpExperience()
    }

    private func configure() {
        arView = ARView(frame: view.bounds)
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)
        view.backgroundColor = .black

        arView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        arView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        arView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        arView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapOnARView))
        arView.addGestureRecognizer(tapGesture)

        tick = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
        tick?.preferredFramesPerSecond = 20
        tick?.add(to: .main, forMode: .common)
    }
    
    override var shouldAutorotate: Bool {
        return true
    }

    @objc private func handleTapOnARView() {
        guard isReadyForPlacement else { return }
        hideOnboardingOverlay()
        addObjectIfNeeded()
    }

    @objc private func addObjectIfNeeded() {
        guard objectAnchor == nil else { return }

        // Resolve a forward placement point from camera transform so the demo object
        // appears in front of the listener and starts in an audible, deterministic position.
        let matrix = arView.cameraTransform.matrix
        let transform = arView.session.currentFrame?.camera.transform ?? matrix
        
        let distance: Float = 1.0
        let cameraWorldPosition = transform.position3
        let objectPosition = cameraWorldPosition + transform.forward3 * distance

        let mesh = MeshResource.generateSphere(radius: 0.1)
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let sphereEntity = ModelEntity(mesh: mesh, materials: [material])

        let sphereAnchor = AnchorEntity(world: objectPosition)
        sphereAnchor.addChild(sphereEntity)
        arView.scene.addAnchor(sphereAnchor)
        
        objectAnchor = sphereAnchor

        assertion(throwing: try play(with: .o1, distance: distance))
    }

    @objc private func handleDisplayLinkUpdate() {
        let timestamp = CACurrentMediaTime()
        guard shouldUpdateListener(at: timestamp) else { return }
        update(timestamp: timestamp)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isMovingFromParent || isBeingDismissed else { return }
        resetToInitialState()
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait, .landscapeRight]
    }

    deinit {
        resetToInitialState()
        tick?.invalidate()
        arView.removeFromSuperview()
        arView = nil
    }

}

extension CameraViewController {
    var listenerScale: Float { listenerUpdateModel.worldMetersToAudioUnits }

    private func resetToInitialState() {
        coordinator?.stop(after: .zero)
        coordinator = nil

        objectAnchor?.removeFromParent()
        objectAnchor = nil

        listenerUpdateModel = ListenerUpdate()
        arView?.session.pause()
    }

    private func configurePreloaderOverlay() {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .black
        overlay.alpha = 1.0
        overlay.isHidden = false
        overlay.isUserInteractionEnabled = true

        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.alpha = 1.0
        indicator.startAnimating()

        overlay.addSubview(indicator)
        view.addSubview(overlay)

        overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        overlay.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        indicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor).isActive = true
        indicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor).isActive = true

        view.bringSubviewToFront(overlay)
        preloaderOverlayView = overlay
    }

    private func configureOnboardingOverlay() {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        overlay.alpha = 0.0
        overlay.isHidden = true
        overlay.isUserInteractionEnabled = false

        let iconView = UIImageView(image: UIImage(systemName: "hand.tap.fill"))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = NSLocalizedString("sample.info.onboarding", comment: "")
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 17, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, messageLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center

        overlay.addSubview(stack)
        view.addSubview(overlay)

        overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        overlay.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        stack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32).isActive = true
        stack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32).isActive = true
        stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor).isActive = true
        stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor).isActive = true

        iconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 64).isActive = true

        onboardingOverlayView = overlay
    }

    private func warmUpExperience() {
        BinauralDatabaseLoader.preload { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                self.warmUpCoordinator()
            case .failure(let error):
                self.hidePreloaderOverlay()
                assertionFailure("Unable to preload HRTF database: \(error)")
            }
        }
    }

    private func warmUpCoordinator() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try BinauralCoordinator(contentsOf: BinauralObject.o1.url) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.hidePreloaderOverlay()
                switch result {
                case .success(let warmedCoordinator):
                    self.coordinator = warmedCoordinator
                    self.isReadyForPlacement = true
                    self.showOnboardingOverlay()
                case .failure(let error):
                    assertionFailure("Unable to warm up binaural coordinator: \(error)")
                }
            }
        }
    }

    private func hidePreloaderOverlay() {
        guard let overlay = preloaderOverlayView else { return }
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseInOut]) {
            overlay.alpha = 0.0
        } completion: { _ in
            overlay.removeFromSuperview()
        }
        preloaderOverlayView = nil
    }

    private func showOnboardingOverlay() {
        guard let overlay = onboardingOverlayView else { return }
        overlay.isHidden = false
        view.bringSubviewToFront(overlay)
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseInOut]) {
            overlay.alpha = 1.0
        }
    }

    private func hideOnboardingOverlay() {
        guard let overlay = onboardingOverlayView, !overlay.isHidden else { return }
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseInOut]) {
            overlay.alpha = 0.0
        } completion: { _ in
            overlay.isHidden = true
        }
    }
}

extension CameraViewController {
    func shouldSendListener(position: SIMD3<Float>, forward: SIMD3<Float>, up: SIMD3<Float>) -> Bool {
        listenerUpdateModel.shouldSend(position: position, forward: forward, up: up)
    }
    func shouldUpdateListener(at timestamp: CFTimeInterval) -> Bool {
        listenerUpdateModel.shouldUpdate(at: timestamp)
    }
}
