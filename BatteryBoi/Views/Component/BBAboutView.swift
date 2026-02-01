import SwiftUI

struct AboutContainer: View {
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
                Text(UpdateManager.shared.versionDisplay)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color("BatterySubtitle").opacity(0.6))
                    .padding(.top, 20)
            }
            .frame(width: 340)

        }
        .frame(width: 380, height: 278, alignment: .center)
        .padding(10)

    }

}
