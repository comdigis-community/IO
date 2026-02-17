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
    
    private var orientationOverlayView: UIView?
    private var listenerUpdateModel = ListenerUpdate()
    private var tick: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.barTintColor = UIColor.systemBlue
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.tintColor = UIColor.white

        let add = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addObject))
        navigationItem.rightBarButtonItem = add

        configure()
        configureOrientationOverlay()
        updateOrientationOverlay()
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

        tick = CADisplayLink(target: self, selector: #selector(handleDisplayLinkUpdate))
        tick?.preferredFramesPerSecond = 20
        tick?.add(to: .main, forMode: .common)
    }
    
    override var shouldAutorotate: Bool {
        return true
    }

    @objc private func addObject() {
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

    override func viewWillTransition(
        to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: { _ in
                self.updateOrientationOverlay()
            }, completion: { _ in
                self.updateOrientationOverlay()
            })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateOrientationOverlay()
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
    private func isPortraitInterface() -> Bool {
        view.window?.windowScene?
            .interfaceOrientation.isPortrait ?? (view.bounds.height >= view.bounds.width)
    }
    private func configureOrientationOverlay() {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        overlay.alpha = 0.0
        overlay.isHidden = true
        overlay.isUserInteractionEnabled = false

        let imageView = UIImageView(image: UIImage(systemName: "iphone.landscape"))
        let preferredConfiguration = UIImage.SymbolConfiguration(pointSize: 64, weight: .semibold)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .white
        imageView.preferredSymbolConfiguration = preferredConfiguration
        imageView.contentMode = .scaleAspectFit
        
        overlay.addSubview(imageView)
        view.addSubview(overlay)

        overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        overlay.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        imageView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor).isActive = true
        
        orientationOverlayView = overlay
    }
    private func updateOrientationOverlay() {
        guard let overlay = orientationOverlayView else { return }
        let shouldShow = isPortraitInterface()
        overlay.isHidden = !shouldShow
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseInOut]) {
            overlay.alpha = shouldShow ? 1.0 : 0.0
        } completion: { _ in
            overlay.isHidden = !shouldShow
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
