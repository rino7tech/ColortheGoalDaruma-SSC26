import Foundation

struct DarumaColorResolver {
    func resolveColor(from state: WishState) -> DarumaColor {
        let stance = state.topStance ?? .balance
        guard let topCategory = state.topCategory else {
            return fallbackColor(for: state, stance: stance)
        }

        switch topCategory {
        case .achievement:
            if stance == .attack {
                return state.deadline == .short ? .gold : .blue
            } else if stance == .balance {
                return .orange
            } else {
                return .black
            }
        case .money:
            return .yellow
        case .relationship:
            return stance == .defend ? .purple : .pink
        case .health:
            return .green
        case .learning:
            return .white
        case .reset:
            return .silver
        case .protection:
            return stance == .defend ? .black : .orange
        }
    }

    private func fallbackColor(for state: WishState, stance: WishStance) -> DarumaColor {
        if let obstacle = state.obstacle {
            switch obstacle {
            case .people, .confidence:
                return .purple
            case .money:
                return .yellow
            case .habit, .time:
                return .blue
            case .luck:
                return .red
            case .other:
                return .silver
            }
        }

        if let category = state.topCategory {
            switch category {
            case .achievement:
                return stance == .attack ? .gold : .orange
            case .money:
                return .yellow
            case .reset:
                return .silver
            case .protection:
                return .black
            case .learning:
                return .white
            case .health:
                return .green
            case .relationship:
                return stance == .defend ? .purple : .pink
            }
        }

        if state.deadline == .short && stance == .attack {
            return .gold
        }
        if state.deadline == .long {
            return .white
        }
        if stance == .defend {
            return .black
        }
        return .red
    }
}
