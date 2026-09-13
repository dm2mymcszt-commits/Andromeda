import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ActionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let content = SharePlaceView(load: { [weak self] in
            guard let items = self?.extensionContext?.inputItems as? [NSExtensionItem] else {
                throw SearchError.message("No location was shared.")
            }
            // Prefer a URL attachment to display text supplied alongside it.
            for type in [UTType.url.identifier, UTType.plainText.identifier] {
                for item in items {
                    for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(type) {
                        let value = try await provider.loadItem(forTypeIdentifier: type, options: nil)
                        let text: String?
                        if let url = value as? URL { text = url.absoluteString }
                        else if let string = value as? String { text = string }
                        else if let attributed = value as? NSAttributedString { text = attributed.string }
                        else if let data = value as? Data { text = String(data: data, encoding: .utf8) }
                        else { text = nil }
                        if let text = text, !text.isEmpty {
                            return try await WorldwidePlaceSearch.resolve(PlaceInput.parse(text))
                        }
                    }
                }
            }
            if let text = items.compactMap(\.attributedContentText?.string).first, !text.isEmpty {
                return try await WorldwidePlaceSearch.resolve(PlaceInput.parse(text))
            }
            throw SearchError.message("Share a Maps link, address, coordinates or plus code.")
        }, done: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) })
        let host = UIHostingController(rootView: content.tint(.indigo))
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}
