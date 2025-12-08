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

enum Section: Int, CaseIterable {
    case info
    case example
}

extension ViewController: UITableViewDataSource {

    enum ReuseIdentifier {
        static let cell = "cell"
        static let message = "message"
    }

    enum Constants {
        static let infoHeaderHeight: CGFloat = 15
        static let regularHeaderHeight: CGFloat = 30
        static let overlayTag = 999
        static let segueShowRealityKit = "showRealityKit"
        static let demoRowCount = 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section) == .example ? L10n.examplesSectionTitle : nil
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .info ? Constants.infoHeaderHeight : Constants.regularHeaderHeight
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) != .info
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        header.textLabel?.text = self.tableView(tableView, titleForHeaderInSection: section)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .info:
            1
        case .example:
            Constants.demoRowCount
        default:
            0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if Section(rawValue: indexPath.section) == .info {
            let dequeued = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.message, for: indexPath)
            let cell = (dequeued as? UIInfoTableViewCell)
                ?? UIInfoTableViewCell(style: .default, reuseIdentifier: ReuseIdentifier.message)
            cell.configure(caption: L10n.infoCaption, message: L10n.infoMessage)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.cell, for: indexPath)
        cell.textLabel?.text = L10n.realityKitDemoTitle
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

extension ViewController: UITableViewDelegate {

    // Gate navigation behind HRTF preload so demo starts with the database ready.
    // A failed preload keeps users on the list and reports the issue through assertions.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == Section.example.rawValue, indexPath.row == .zero else { return }
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        let activityIndicator = showActivityIndicator()
        BinauralDatabaseLoader.preload { [weak self] result in
            guard let self else { return }
            self.hideActivityIndicator(activityIndicator)

            switch result {
            case .success(let loaded) where loaded:
                self.performSegue(withIdentifier: Constants.segueShowRealityKit, sender: cell)
            case .success:
                assertionFailure("Unable to preload HRTF database: loadAsynchronously returned false")
            case .failure(let error):
                assertionFailure("Unable to preload HRTF database: \(error)")
            }
        }
    }
}

class UIInfoTableViewCell: UITableViewCell {

    private let captionLabel = UILabel()
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(caption: String, message: String) {
        captionLabel.text = caption
        messageLabel.text = message
    }

    fileprivate func configure() {
        let icon = UIImageView(image: UIImage(systemName: "info.circle.fill"))
        icon.contentMode = .scaleAspectFit

        captionLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        captionLabel.textColor = .label
        captionLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleStackView = UIStackView(arrangedSubviews: [icon, captionLabel])
        titleStackView.axis = .horizontal
        titleStackView.alignment = .center
        titleStackView.spacing = 5

        messageLabel.font = UIFont.systemFont(ofSize: 15)
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .label
        messageLabel.setContentHuggingPriority(.required, for: .vertical)
        messageLabel.lineBreakMode = .byWordWrapping

        let contentStackView = UIStackView(arrangedSubviews: [titleStackView, messageLabel])
        contentStackView.axis = .vertical
        contentStackView.alignment = .leading
        contentStackView.spacing = 10
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        contentView.addSubview(contentStackView)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}
