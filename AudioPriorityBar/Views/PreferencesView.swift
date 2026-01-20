import SwiftUI

/// Main preferences view with General and About tabs
struct PreferencesView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var selectedTab: PreferencesTab = .general

    enum PreferencesTab: String, CaseIterable {
        case general = "General"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(PreferencesTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .general:
                    GeneralPreferencesTab()
                        .transition(.opacity)
                case .about:
                    AboutPreferencesTab()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
        }
        .frame(width: 480, height: 400)
    }
}

/// General preferences tab
struct GeneralPreferencesTab: View {
    @StateObject private var launchManager = LaunchAtLoginManager.shared
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Launch at Login section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $launchManager.isEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Launch at Login")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Automatically start Audio Priority Bar when you log in")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                    .padding(12)
                } label: {
                    Label("Startup", systemImage: "power.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                .groupBoxStyle(PreferencesGroupBoxStyle())

                // Quick Switch section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { audioManager.priorityManager.isQuickSwitchEnabled },
                            set: { audioManager.priorityManager.isQuickSwitchEnabled = $0 }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quick Switch Mode")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Single-click the menu bar icon to toggle between speakers and headphones. Right-click to open the menu.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if audioManager.priorityManager.isQuickSwitchEnabled {
                            Text("Restart the app for this change to take effect.")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                        }
                    }
                    .padding(12)
                } label: {
                    Label("Menu Bar", systemImage: "hand.point.up.left.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                .groupBoxStyle(PreferencesGroupBoxStyle())

                // Auto-switching section
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-Switching Behavior")
                            .font(.system(size: 13, weight: .medium))

                        Text("Audio Priority Bar automatically switches between speakers and headphones based on your device priorities. Use the mode toggle to switch between Speaker and Headphone modes, or enable Manual mode to disable auto-switching.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                } label: {
                    Label("Auto-Switching", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                .groupBoxStyle(PreferencesGroupBoxStyle())

                Spacer()
            }
            .padding(20)
        }
    }
}

/// About preferences tab
struct AboutPreferencesTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon and name
                VStack(spacing: 12) {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(12)
                    }

                    Text(AppInfo.appName)
                        .font(.system(size: 18, weight: .semibold))

                    Text(AppInfo.versionString)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 40)

                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Text("Audio Priority Bar is a menu bar utility for macOS that helps you quickly switch between audio devices and manage your sound output priorities.")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 20)

                // GitHub link
                VStack(spacing: 10) {
                    Button {
                        if let url = URL(string: "https://github.com/johanhenkens/AudioPriorityBar") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                            Text("View on GitHub")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.bottom, 20)
        }
    }
}

/// Custom group box style matching MenuBarView design
struct PreferencesGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
                .padding(.horizontal, 4)

            configuration.content
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
