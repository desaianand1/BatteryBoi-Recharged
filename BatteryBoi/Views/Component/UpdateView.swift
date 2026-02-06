import SwiftUI

struct UpdatePromptView: View {
    @Environment(\.appEnvironment) private var env

    private var updates: UpdateManager {
        env.update
    }

    private var settings: any SettingsServiceProtocol {
        env.settings
    }

    var body: some View {
        if updates.available != nil {
            HStack(alignment: .top, spacing: 3) {
                Circle()
                    .fill(Color("BatteryEfficient"))
                    .frame(width: 5, height: 5)
                    .offset(y: 5)

                Text("UpdateStatusNewLabel".localise())

            }
            .padding(0)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color("BatteryEfficient"))
            .lineLimit(2)
            .padding(.top, 10)
            .onHover { hover in
                switch hover {
                case true: NSCursor.pointingHand.push()
                default: NSCursor.pop()
                }

            }
            .onTapGesture {
                settings.performAction(SettingsActionObject(.appInstallUpdate))

            }

        } else {
            EmptyView()

        }

    }

}
