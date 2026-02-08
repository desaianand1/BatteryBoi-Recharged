import SwiftUI

struct AboutContainer: View {
    @Environment(\.appEnvironment) private var env

    private var updates: UpdateManager {
        env.update
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("AboutTitle".localise())

                }
                .foregroundColor(Color("BatteryTitle"))
                .font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 28) {
                    Text("AboutBodyOne".localise())

                    Text("AboutBodyTwo".localise())

                    Text("AboutBodyThree".localise())

                    Text("AboutBodyFour".localise())

                }
                .lineSpacing(14)
                .foregroundColor(Color("BatterySubtitle"))
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 24)

                // Version display
                Text(updates.versionDisplay)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color("BatterySubtitle").opacity(0.6))
                    .padding(.top, 20)
            }
            .frame(width: 340)

        }
        .frame(minWidth: 340, idealWidth: 380, maxWidth: 420)
        .frame(minHeight: 240, idealHeight: 278, maxHeight: 320)
        .padding(10)

    }

}
