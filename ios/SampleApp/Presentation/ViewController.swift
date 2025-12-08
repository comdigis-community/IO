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
import MediaPlayer
import AVKit

class ViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigation()
        setupTableView()
    }
    
    override var shouldAutorotate: Bool {
        return true
    }

    fileprivate func setupNavigation() {
        let appearance = UINavigationBarAppearance()
        
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        navigationItem.title = L10n.navigationTitle
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationItem.largeTitleDisplayMode = .never
    }
    
    fileprivate func setupTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: ReuseIdentifier.cell)
        tableView.register(UIInfoTableViewCell.self, forCellReuseIdentifier: ReuseIdentifier.message)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.reloadData()
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

}

extension ViewController {
    @discardableResult
    func showActivityIndicator() -> UIActivityIndicatorView {
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.tag = Constants.overlayTag
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor)
        ])
        activityIndicator.startAnimating()
        view.addSubview(overlayView)
        return activityIndicator
    }

    func hideActivityIndicator(_ activityIndicator: UIActivityIndicatorView) {
        activityIndicator.stopAnimating()
        activityIndicator.superview?.removeFromSuperview()
    }
}

enum L10n {
    
    static var navigationTitle: String { localized("sample.navigation.title") }
    static var examplesSectionTitle: String { localized("sample.section.examples.title") }
    static var realityKitDemoTitle: String { localized("sample.demo.realitykit.title") }
    static var infoCaption: String { localized("sample.info.caption") }
    static var infoMessage: String { localized("sample.info.message") }
    
    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

}
