import SwiftUI

struct ScorecardView: View {
    let players: [GamePlayer]
    let currentPlayerID: UUID
    let diceValues: [Int]
    let canScore: Bool
    let onSelect: (ScoreCategory) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section(title: "Bovenkant", categories: ScoreCategory.upper)
                totalsBlock(isUpper: true)
                section(title: "Onderkant", categories: ScoreCategory.lower)
                totalsBlock(isUpper: false)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func section(title: String, categories: [ScoreCategory]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.cream)

            ForEach(categories) { category in
                ScoreRowView(
                    category: category,
                    players: players,
                    currentPlayerID: currentPlayerID,
                    preview: preview(for: category),
                    isSelectable: canSelect(category),
                    onSelect: { onSelect(category) }
                )
            }
        }
    }

    private func totalsBlock(isUpper: Bool) -> some View {
        VStack(spacing: 6) {
            if isUpper {
                totalRow(label: "Subtotaal", values: players.map { "\($0.scorecard.upperSubtotal)" })
                totalRow(label: "Bonus (≥63 → 35)", values: players.map { card in
                    card.scorecard.upperBonus > 0
                        ? "\(card.scorecard.upperBonus)"
                        : "\(card.scorecard.upperSubtotal)/63"
                })
            } else {
                totalRow(label: "Yahtzee-bonus", values: players.map { "\($0.scorecard.yahtzeeBonusTotal)" })
                totalRow(label: "Totaal", values: players.map { "\($0.scorecard.total)" }, emphasize: true)
            }
        }
        .padding(12)
        .background(AppTheme.feltDeep.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func totalRow(label: String, values: [String], emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasize ? AppTheme.headlineFont : AppTheme.bodyFont)
                .foregroundStyle(AppTheme.cream)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(emphasize ? AppTheme.headlineFont : AppTheme.bodyFont)
                    .foregroundStyle(emphasize ? AppTheme.gold : AppTheme.cream)
                    .frame(width: 52, alignment: .trailing)
            }
        }
    }

    private func preview(for category: ScoreCategory) -> Int? {
        guard canScore else { return nil }
        let current = players.first(where: { $0.id == currentPlayerID })
        guard let current, current.scorecard.scores[category] == nil else { return nil }
        let open = YahtzeeScorer.availableCategories(dice: diceValues, scorecard: current.scorecard)
        guard open.contains(category) else { return nil }
        return YahtzeeScorer.pointsForPlacing(
            category: category,
            dice: diceValues,
            scorecard: current.scorecard
        ).score
    }

    private func canSelect(_ category: ScoreCategory) -> Bool {
        guard canScore,
              let current = players.first(where: { $0.id == currentPlayerID }) else { return false }
        return YahtzeeScorer.availableCategories(dice: diceValues, scorecard: current.scorecard)
            .contains(category)
    }
}

struct ScoreRowView: View {
    let category: ScoreCategory
    let players: [GamePlayer]
    let currentPlayerID: UUID
    let preview: Int?
    let isSelectable: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text(category.title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(players) { player in
                    cell(for: player)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelectable ? AppTheme.gold.opacity(0.9) : AppTheme.cream.opacity(0.92),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }

    @ViewBuilder
    private func cell(for player: GamePlayer) -> some View {
        let scored = player.scorecard.scores[category]
        let text: String = {
            if let scored { return "\(scored)" }
            if player.id == currentPlayerID, let preview { return "\(preview)" }
            return "—"
        }()

        Text(text)
            .font(AppTheme.bodyFont)
            .foregroundStyle(
                scored != nil
                    ? AppTheme.ink
                    : (player.id == currentPlayerID && preview != nil ? AppTheme.coral : AppTheme.ink.opacity(0.35))
            )
            .frame(width: 52, alignment: .trailing)
    }
}
