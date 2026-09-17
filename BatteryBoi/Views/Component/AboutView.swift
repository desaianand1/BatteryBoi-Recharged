import SwiftUI

struct AboutTabView: View {
    @Environment(AppEnvironment.self) private var env

    private var updates: any UpdateManagerProtocol {
        self.env.update
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("AboutTitle".localise())
                .font(Typography.largeTitle)
                .foregroundStyle(Color("BBTitle"))

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("AboutBodyOne".localise())
                Text("AboutBodyTwo".localise())
                Text("AboutBodyThree".localise())
                Text("AboutBodyFour".localise())
            }
            .font(Typography.body)
            .foregroundStyle(Color("BBSubtitle"))
            .lineSpacing(6)
            .padding(Spacing.md)
            .surfaceCard()

            Text(self.updates.versionDisplay)
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle").opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, Spacing.sm)
    }
}

typealias AboutContainer = AboutTabView
