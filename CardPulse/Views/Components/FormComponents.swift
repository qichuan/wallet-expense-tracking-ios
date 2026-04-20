//
//  FormComponents.swift
//  CardPulse
//

import SwiftUI

// MARK: - Section wrapper

struct FormSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = title {
                SectionLabel(text: title)
                    .padding(.horizontal, 20)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(AppColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Text field row

struct FormTextFieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var onChange: ((String) -> Void)? = nil
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 96, alignment: .leading)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(AppColors.textTertiary))
                .keyboardType(keyboardType)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    onChange?(newValue)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Divider

struct FormDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.divider)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

// MARK: - Generic picker row

struct FormPickerRow<Value: Hashable, LabelContent: View>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let optionLabel: (Value) -> String
    @ViewBuilder var trailing: () -> LabelContent

    init(title: String,
         selection: Binding<Value>,
         options: [Value],
         optionLabel: @escaping (Value) -> String,
         @ViewBuilder trailing: @escaping () -> LabelContent = { EmptyView() }) {
        self.title = title
        self._selection = selection
        self.options = options
        self.optionLabel = optionLabel
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            trailing()
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(optionLabel(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Date row

struct FormDateRow: View {
    let title: String
    @Binding var date: Date
    var components: DatePickerComponents = [.date, .hourAndMinute]

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            DatePicker("", selection: $date, displayedComponents: components)
                .labelsHidden()
                .tint(AppColors.accent)
                .colorScheme(.dark)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Toggle row

struct FormToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Note editor

struct FormNoteEditor: View {
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 96)
        }
    }
}

// MARK: - Destructive button

struct DestructiveButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: 0xEF4444))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: 0xEF4444).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}
