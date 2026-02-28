import SwiftUI
import AppKit
import Foundation

@main
struct AppCloser: App {
	init() {
		// Disable macOS window state restoration so the window
		// always opens at its configured size
		UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
	}

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
	@State private var showConfirmation = false

	// Count of apps selected for closing
	private var selectedCount: Int {
		apps.filter { $0.shouldClose }.count
	}

	// Toolbar buttons for refreshing and bulk selection
	private var toolbarButtons: some View {
		HStack {
			Button("Refresh App List") {
				loadApps(force: true)
			}
			Button("Check All") {
				for index in apps.indices {
					apps[index].shouldClose = true
				}
			}
			Button("Uncheck All") {
				for index in apps.indices {
					apps[index].shouldClose = false
				}
			}
			Spacer()
		}
		.padding(.bottom, 8)
		.fixedSize(horizontal: false, vertical: true)
	}

	// Single row in the app list showing icon, toggle, and color-coded background
	private func appRow(_ app: Binding<AppInfo>) -> some View {
		HStack(alignment: .center, spacing: 12) {
			if let icon = app.wrappedValue.icon {
				Image(nsImage: icon)
					.resizable()
					.frame(width: 48, height: 48)
			}
			Toggle(app.wrappedValue.name, isOn: app.shouldClose)
				.font(.system(size: 24))
		}
		.padding(.vertical, 6)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: 6)
				.fill(app.wrappedValue.shouldClose
					? Color.red.opacity(0.15)
					: Color.green.opacity(0.15))
		)
	}

	// Scrollable list of running apps
	private var appList: some View {
		List {
			ForEach($apps) { $app in
				appRow($app)
			}
		}
		.frame(maxHeight: .infinity)
	}

	// Status text and selected count
	private var statusSection: some View {
		VStack(alignment: .leading, spacing: 2) {
			if isClosing {
				Text(closingStatus)
					.foregroundColor(.red)
			}
			Text("\(selectedCount) app\(selectedCount == 1 ? "" : "s") selected")
				.foregroundColor(.secondary)
		}
		.fixedSize(horizontal: false, vertical: true)
	}

	// Bottom action buttons: Cancel and Close Selected Apps
	private var actionButtons: some View {
		HStack {
			Spacer()
			Button("Cancel") {
				NSApplication.shared.terminate(nil)
			}
			Button("Close Selected Apps") {
				showConfirmation = true
			}
			.disabled(isClosing || selectedCount == 0)
			.keyboardShortcut(.defaultAction)
		}
		.fixedSize(horizontal: false, vertical: true)
	}

	// Begin closing the selected apps in a background thread
	private func beginClosing() {
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

	var body: some View {
		VStack(alignment: .leading) {
			Text("Select apps to close:")
				.font(.headline)
			Toggle("Include menu bar / accessory apps", isOn: $showAccessoryApps)
				.padding(.bottom, 4)
			toolbarButtons
			appList
			statusSection
			actionButtons
		}
		.padding()
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.onAppear {
			loadApps(force: true)
			// Set the window to 800x600 on launch, but keep it resizable
			DispatchQueue.main.async {
				if let window = NSApplication.shared.windows.first {
					let size = NSSize(width: 800, height: 600)
					window.setContentSize(size)
					window.center()
				}
			}
		}
		.onChange(of: showAccessoryApps) { _ in
			loadApps(force: true)
		}
		.alert("Close \(selectedCount) app\(selectedCount == 1 ? "" : "s")?",
			   isPresented: $showConfirmation) {
			Button("Cancel", role: .cancel) { }
			Button("Close", role: .destructive) {
				beginClosing()
			}
		} message: {
			Text("This will quit the selected applications.")
		}
	}


	// Fetch running apps filtered by activation policy
	func getRunningApps() -> [NSRunningApplication] {
		let ownExecutableURL = Bundle.main.executableURL
		let runningApps = NSWorkspace.shared.runningApplications
		return runningApps.filter {
			($0.activationPolicy == .regular
				|| (showAccessoryApps && $0.activationPolicy == .accessory))
			&& $0.executableURL != ownExecutableURL
		}
	}

	// Convert a single NSRunningApplication to AppInfo
	func toAppInfo(_ app: NSRunningApplication) -> AppInfo? {
		guard let name = app.localizedName else { return nil }
		if name == "Finder" { return nil }
		let shouldClose = app.activationPolicy == .regular
		return AppInfo(name: name, icon: app.icon, shouldClose: shouldClose)
	}

	func loadApps(force: Bool = false) {
		if isLoaded && !force { return }
		isLoaded = true

		let filtered = getRunningApps()
			.compactMap { toAppInfo($0) }
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

		apps = filtered
		print("[Debug] Loaded apps: \(apps.map { "\($0.name): \($0.shouldClose ? "[x]" : "[ ]")" })")
	}

	func closeSelectedApps() {
		let toClose = apps.filter { $0.shouldClose }.map { $0.name }
		totalToClose = toClose.count

		for (index, app) in toClose.enumerated() {
			DispatchQueue.main.async {
				currentIndex = index + 1
				closingStatus = "Closing app \(currentIndex) of \(totalToClose): \(app)"
			}
			// Check if the app is still running before sending quit
			let stillRunning = NSWorkspace.shared.runningApplications.contains {
				$0.localizedName == app
			}
			if stillRunning {
				let quitScript = "tell application \"\(app)\" to quit"
				_ = runAppleScript(quitScript)
			} else {
				print("[AppCloser] Skipping \(app): already quit")
			}
			usleep(100000) // 0.1 seconds for visibility
		}
	}


	func runAppleScript(_ script: String) -> String? {
		print("[AppleScript] Running:\n\(script)\n")

		var error: NSDictionary?
		if let appleScript = NSAppleScript(source: script) {
			let output = appleScript.executeAndReturnError(&error)
			if let error = error {
				if let code = error[NSAppleScript.errorNumber] as? Int {
					if code == -128 {
						print("[AppleScript] User canceled quit for: \(script)")
					} else if code == -600 {
						print("[AppleScript] App already quit: \(script)")
					} else {
						print("[AppleScript] Error (code \(code)): \(error)")
					}
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
