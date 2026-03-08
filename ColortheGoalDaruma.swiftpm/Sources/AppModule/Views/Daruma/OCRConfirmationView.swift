import SwiftUI

/// OCRで解析したテキストを確認する画面
struct OCRConfirmationView: View {
    let ocrText: String
    var startsInManualEditing: Bool = false
    var failureMessage: String? = nil
    @State private var manualText: String = ""
    @State private var isEditingManually: Bool = false
    @FocusState private var isManualFieldFocused: Bool
    var onConfirm: () -> Void
    var onRejectAndEdit: (String) -> Void
    var onRetryOCR: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let failureMessage {
                                Text("Let's enter your wish")
                                    .font(.shiranui(size: 24))
                                    .foregroundStyle(.primary)
                                Text(failureMessage)
                                    .font(.shiranui(size: 14))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Does this look right?")
                                    .font(.shiranui(size: 24))
                                    .foregroundStyle(.primary)
                                Text("Review the recognized wish before continuing.")
                                    .font(.shiranui(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)

                        if !ocrText.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Recognized wish", systemImage: "text.viewfinder")
                                    .font(.shiranui(size: 16))
                                    .foregroundStyle(.primary)

                                Text(ocrText)
                                    .font(.shiranui(size: 15))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .textSelection(.enabled)
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
                            )
                            .padding(.horizontal, 20)
                        }

                        if isEditingManually {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Edit wish", systemImage: "pencil")
                                    .font(.shiranui(size: 16))

                                TextField("Type your wish", text: $manualText, axis: .vertical)
                                    .focused($isManualFieldFocused)
                                    .lineLimit(4...6)
                                    .textInputAutocapitalization(.sentences)
                                    .autocorrectionDisabled(false)
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text("Tap outside the field to dismiss the keyboard.")
                                    .font(.shiranui(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
                            )
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        isManualFieldFocused = false
                    }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        SoundPlayer.shared.playSelect()
                        isManualFieldFocused = false
                    }
                    .font(.shiranui(size: 14))
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if isEditingManually {
                        Button {
                            SoundPlayer.shared.playSelect()
                            isManualFieldFocused = false
                            onRejectAndEdit(manualText)
                        } label: {
                            Label(failureMessage == nil ? "Continue with Edited Text" : "Continue with Typed Text", systemImage: "arrow.right.circle.fill")
                                .font(.shiranui(size: 16))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if let onRetryOCR {
                            Button {
                                SoundPlayer.shared.playSelect()
                                isManualFieldFocused = false
                                onRetryOCR()
                            } label: {
                                Label("Retry OCR", systemImage: "arrow.clockwise.circle")
                                    .font(.shiranui(size: 16))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        } else {
                            Button {
                                SoundPlayer.shared.playSelect()
                                isManualFieldFocused = false
                                isEditingManually = false
                                manualText = ""
                            } label: {
                                Label("Use Recognized Text", systemImage: "arrow.uturn.backward.circle")
                                    .font(.shiranui(size: 16))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    } else {
                        Button {
                            SoundPlayer.shared.playSelect()
                            onConfirm()
                        } label: {
                            Label("Yes, Continue", systemImage: "checkmark.circle.fill")
                                .font(.shiranui(size: 16))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            SoundPlayer.shared.playSelect()
                            manualText = ocrText
                            isEditingManually = true
                            DispatchQueue.main.async {
                                isManualFieldFocused = true
                            }
                        } label: {
                            Label("Edit Manually", systemImage: "pencil.circle")
                                .font(.shiranui(size: 16))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(.regularMaterial)
            }
        }
        .onAppear {
            isEditingManually = startsInManualEditing
            if startsInManualEditing {
                manualText = ocrText
                DispatchQueue.main.async {
                    isManualFieldFocused = true
                }
            }
        }
    }
}
