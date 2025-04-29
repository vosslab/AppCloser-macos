import SwiftUI
import AppKit
import Foundation

@main
struct AppCloser: App {
	var body: some Scene {
		WindowGroup {
			AppCloserView()
		}
	}
}

struct AppInfo: Identifiable {
	let id = UUID()
	let name: String
	let icon: NSImage?
	var shouldClose: Bool
}

struct AppCloserView: View {
	@State private var apps: [AppInfo] = []
	@State private var isLoaded = false
	@State private var showAccessoryApps = false
	@State private var isClosing = false
	@State private var closingStatus = ""
	@State private var totalToClose = 0
	@State private var currentIndex = 0


	var body: some View {
		VStack(alignment: .leading) {
			Text("Select apps to close:")
				.font(.headline)

			Toggle("Include menu bar / accessory apps", isOn: $showAccessoryApps)
				.padding(.bottom, 4)

			HStack {
				Button("Refresh App List") {
					loadApps(force: true)
				}
				Button("Uncheck All") {
					for index in apps.indices {
						apps[index].shouldClose = false
					}
				}
				Spacer()
			}
			.padding(.bottom, 8)

			List {
				ForEach($apps) { $app in
					HStack(alignment: .center, spacing: 12) {
						if let icon = app.icon {
							Image(nsImage: icon)
								.resizable()
								.frame(width: 48, height: 48)
						}
						Toggle(app.name, isOn: $app.shouldClose)
							.font(.system(size: 24))
					}
					.padding(.vertical, 6)
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
			.frame(maxHeight: .infinity)

			if isClosing {
				Text(closingStatus)
					.foregroundColor(.red)
					.padding(.top, 4)
			}
			HStack {
				Spacer()
				Button("Cancel") {
					NSApplication.shared.terminate(nil)
				}
				Button("Close Selected Apps") {
					isClosing = true
					closingStatus = "Closing apps..."
					DispatchQueue.global(qos: .userInitiated).async {
						closeSelectedApps()
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
							closingStatus = "Done. Exiting..."
							NSApplication.shared.terminate(nil)
						}
					}
				}
				.disabled(isClosing)
				.keyboardShortcut(.defaultAction)
			}
		}
		.padding()
		.frame(width: 800, height: 600)
		.onAppear {
			loadApps(force: true)
		}
	}


	func loadApps(force: Bool = false) {
		if isLoaded && !force { return }
		isLoaded = true

		let runningApps = NSWorkspace.shared.runningApplications
		let ownExecutableURL = Bundle.main.executableURL

		let filtered = runningApps
			.filter {
				($0.activationPolicy == .regular || (showAccessoryApps && $0.activationPolicy == .accessory))
				&& $0.executableURL != ownExecutableURL
			}
			.compactMap { app -> AppInfo? in
				guard let name = app.localizedName else { return nil }
				let shouldClose = app.activationPolicy == .regular
				return AppInfo(name: name, icon: app.icon, shouldClose: shouldClose)
			}
			.filter { $0.name != "Finder" }
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

		apps = filtered
		print("[Debug] Loaded apps: \(apps.map { "\($0.name): \($0.shouldClose ? "✅" : "⬜️")" })")
	}

	func closeSelectedApps() {
		let toClose = apps.filter { $0.shouldClose }.map { $0.name }
		totalToClose = toClose.count

		for (index, app) in toClose.enumerated() {
			DispatchQueue.main.async {
				currentIndex = index + 1
				closingStatus = "Closing app \(currentIndex) of \(totalToClose): \(app)"
			}
			let quitScript = "tell application \"\(app)\" to quit"
			_ = runAppleScript(quitScript)
			usleep(100000) // 0.1 seconds for visibility
		}
	}


	func runAppleScript(_ script: String) -> String? {
		print("[AppleScript] Running:\n\(script)\n")

		var error: NSDictionary?
		if let appleScript = NSAppleScript(source: script) {
			let output = appleScript.executeAndReturnError(&error)
			if let error = error {
				if let code = error[NSAppleScript.errorNumber] as? Int, code == -128 {
					print("[AppleScript] User canceled quit for: \(script)")
				} else {
					print("[AppleScript] Error: \(error)")
				}
				return nil
			}
			print("[AppleScript] Output: \(output.stringValue ?? "<nil>")")
			return output.stringValue
		}
		print("[AppleScript] Failed to compile")
		return nil
	}
}
