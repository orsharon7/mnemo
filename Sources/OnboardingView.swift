import SwiftUI

struct OnboardingView: View {
    let hotkeyDisplay: String
    var onDismiss: (_ openPrefs: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mnemo is running")
                        .font(.title2.bold())
                    Text("Your clipboard now has a memory.")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Row(icon: "keyboard",
                    title: "Press \(hotkeyDisplay) anywhere",
                    detail: "Opens the search panel from any app.")
                Row(icon: "magnifyingglass",
                    title: "Type to search your history",
                    detail: "Substring + fuzzy matching across every clip you've ever copied.")
                Row(icon: "return",
                    title: "Hit ↩ to copy the selected item",
                    detail: "Then ⌘V to paste — or enable auto-paste in Preferences.")
                Row(icon: "pin.fill",
                    title: "⌘P pins favorites to the top",
                    detail: "Pinned clips survive Clear All.")
                Row(icon: "menubar.rectangle",
                    title: "We live in the menu bar",
                    detail: "Click the clipboard icon for Preferences, Pause, Clear, Quit.")
            }

            Spacer(minLength: 4)

            HStack {
                Spacer()
                Button("Open Preferences…") { onDismiss(true) }
                Button("Got it") { onDismiss(false) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460, height: 380)
    }

    private struct Row: View {
        let icon: String
        let title: String
        let detail: String

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 14, weight: .medium))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.bold())
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
