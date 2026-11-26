import SwiftUI
import RelayCore

struct CategoryRecognitionView: View {
    @Binding var recognition: CategoryRecognition
    let categories: [String]
    let categoryName: (String) -> String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(L("Automatisch erkennen und senden"), isOn: $recognition.automaticallySends)
                Text(L("Ist die erkannte Kategorie verfügbar, sendet NZBPort den Auftrag direkt an SABnzbd. Sonst öffnet sich die Kategorieauswahl."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    ForEach(CategoryRecognition.Kind.allCases, id: \.self) { kind in
                        GridRow {
                            Text(title(for: kind)).accessibilityHidden(true)
                            categoryPicker(title(for: kind), selection: Binding(
                                get: { recognition[kind] },
                                set: { recognition[kind] = $0 }
                            ))
                            .labelsHidden()
                            .accessibilityLabel(Text(title(for: kind)))
                        }
                    }
                }
                DisclosureGroup(L("Eigene Titelregeln")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Die erste passende Titelregel hat Vorrang vor der Erkennung. Groß- und Kleinschreibung spielen keine Rolle."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(recognition.rules) { rule in
                            Divider()
                            TextField(L("Suchbegriff"), text: ruleField(rule, \.pattern))
                                .textFieldStyle(.roundedBorder)
                            categoryPicker(L("Zielkategorie"), selection: ruleField(rule, \.category))
                            HStack {
                                Button(L("Regel entfernen"), role: .destructive) {
                                    recognition.rules.removeAll { $0.id == rule.id }
                                }
                                Spacer()
                                Button(L("Nach oben"), systemImage: "arrow.up") { move(rule, by: -1) }
                                    .disabled(recognition.rules.first?.id == rule.id)
                                Button(L("Nach unten"), systemImage: "arrow.down") { move(rule, by: 1) }
                                    .disabled(recognition.rules.last?.id == rule.id)
                            }.controlSize(.small)
                        }
                        Button(L("Regel hinzufügen"), systemImage: "plus") {
                            recognition.rules.append(.init())
                        }
                    }.padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        } label: {
            Label(L("Automatische Kategoriezuordnung"), systemImage: "tag").font(.headline)
        }
    }

    private func categoryPicker(_ label: String, selection: Binding<String?>) -> some View {
        Picker(label, selection: selection) {
            Text(L("Deaktiviert")).tag(nil as String?)
            ForEach(categories, id: \.self) { category in
                Text(categoryName(category)).tag(Optional(category))
            }
            if let category = selection.wrappedValue, !categories.contains(category) {
                let name = categoryName(category)
                Text(L("\(name) (nicht verfügbar)")).tag(Optional(category))
            }
        }
        .pickerStyle(.menu)
    }

    private func title(for kind: CategoryRecognition.Kind) -> String {
        switch kind {
        case .series: L("Serien")
        case .games: L("Spiele")
        case .movies: L("Filme")
        case .misc: L("Sonstige Titel")
        }
    }

    private func ruleField<Value>(_ rule: CategoryRecognition.Rule,
                                  _ keyPath: WritableKeyPath<CategoryRecognition.Rule, Value>) -> Binding<Value> {
        Binding {
            (recognition.rules.first { $0.id == rule.id } ?? rule)[keyPath: keyPath]
        } set: { value in
            guard let index = recognition.rules.firstIndex(where: { $0.id == rule.id }) else { return }
            recognition.rules[index][keyPath: keyPath] = value
        }
    }

    private func move(_ rule: CategoryRecognition.Rule, by offset: Int) {
        guard let index = recognition.rules.firstIndex(where: { $0.id == rule.id }),
              recognition.rules.indices.contains(index + offset) else { return }
        recognition.rules.swapAt(index, index + offset)
    }
}
