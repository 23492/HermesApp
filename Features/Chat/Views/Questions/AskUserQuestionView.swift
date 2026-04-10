import SwiftUI

// MARK: - Question Type

enum QuestionType: String, Codable {
    case text       // Free text input
    case confirm    // Yes/No buttons
    case choice     // Multiple choice options
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .confirm: return "Yes/No"
        case .choice: return "Choice"
        }
    }
}

// MARK: - Ask User Question Model

struct AskUserQuestion: Codable, Identifiable {
    var id: String
    var question: String
    var questionType: QuestionType
    var options: [String]?      // For choice type
    var placeholder: String?    // For text type
    var context: String?        // Additional context
    var askedAt: Date
    var answeredAt: Date?
    var response: String?
    var isAnswered: Bool
    
    init(
        id: String = UUID().uuidString,
        question: String,
        questionType: QuestionType = .text,
        options: [String]? = nil,
        placeholder: String? = nil,
        context: String? = nil
    ) {
        self.id = id
        self.question = question
        self.questionType = questionType
        self.options = options
        self.placeholder = placeholder
        self.context = context
        self.askedAt = Date()
        self.isAnswered = false
    }
    
    mutating func submitResponse(_ response: String) {
        self.response = response
        self.answeredAt = Date()
        self.isAnswered = true
    }
}

// MARK: - Ask User Question View

struct AskUserQuestionView: View {
    let question: AskUserQuestion
    let onSubmit: (String) -> Void
    let onDismiss: (() -> Void)?
    
    @State private var textResponse: String = ""
    @State private var selectedOption: String? = nil
    @State private var isSubmitting = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            questionHeader
            
            // Context (if provided)
            if let context = question.context {
                contextView(context)
            }
            
            // Question text
            Text(question.question)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Input based on question type
            inputSection
            
            // Action buttons
            actionButtons
        }
        .padding(16)
        .background(backgroundGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: .orange.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Subviews
    
    private var questionHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill.questionmark")
                .font(.title3)
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI needs your input")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(question.questionType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let onDismiss = onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func contextView(_ context: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(context)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    @ViewBuilder
    private var inputSection: some View {
        switch question.questionType {
        case .text:
            textInput
        case .confirm:
            confirmInput
        case .choice:
            choiceInput
        }
    }
    
    private var textInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $textResponse)
                .font(.body)
                .focused($isTextFieldFocused)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 80, maxHeight: 150)
                .background(Color.systemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            
            HStack {
                Spacer()
                Text("\(textResponse.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private var confirmInput: some View {
        HStack(spacing: 12) {
            confirmButton(
                title: "Yes",
                icon: "checkmark.circle.fill",
                color: .green,
                action: { submit("yes") }
            )
            
            confirmButton(
                title: "No",
                icon: "xmark.circle.fill",
                color: .red,
                action: { submit("no") }
            )
        }
    }
    
    private func confirmButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }
    
    private var choiceInput: some View {
        VStack(spacing: 8) {
            if let options = question.options {
                ForEach(options, id: \.self) { option in
                    choiceButton(option)
                }
            } else {
                Text("No options available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }
    
    private func choiceButton(_ option: String) -> some View {
        Button {
            selectedOption = option
            submit(option)
        } label: {
            HStack {
                Text(option)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if selectedOption == option {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.orange)
                        .symbolEffect(.scale, options: .speed(2))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary.opacity(0.4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                selectedOption == option
                ? Color.orange.opacity(0.15)
                : Color.secondary.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        selectedOption == option
                        ? Color.orange.opacity(0.4)
                        : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }
    
    private var actionButtons: some View {
        HStack {
            if question.questionType == .text {
                Button("Cancel", role: .cancel) {
                    onDismiss?()
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)
                
                Spacer()
                
                Button {
                    submit(textResponse)
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text("Submit")
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(textResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.08),
                Color.yellow.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Actions
    
    private func submit(_ response: String) {
        guard !isSubmitting else { return }
        
        isSubmitting = true
        onSubmit(response)
    }
}

// MARK: - Inline Question View
// For embedding directly in chat stream

struct InlineQuestionView: View {
    let question: AskUserQuestion
    let onSubmit: (String) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question bubble
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.question)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if question.isAnswered, let response = question.response {
                        // Show answer
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            
                            Text("You: \(response)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    } else {
                        // Show input based on type
                        compactInput
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1.5)
        )
    }
    
    @ViewBuilder
    private var compactInput: some View {
        switch question.questionType {
        case .confirm:
            HStack(spacing: 8) {
                compactButton("Yes", color: .green) { onSubmit("yes") }
                compactButton("No", color: .red) { onSubmit("no") }
            }
            
        case .choice:
            if let options = question.options {
                FlowLayout(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        compactOptionButton(option)
                    }
                }
            }
            
        case .text:
            CompactTextInput(onSubmit: onSubmit)
        }
    }
    
    private func compactButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func compactOptionButton(_ option: String) -> some View {
        Button {
            onSubmit(option)
        } label: {
            Text(option)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.systemBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Text Input

struct CompactTextInput: View {
    let onSubmit: (String) -> Void
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("Type your answer...", text: $text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...3)
                .focused($isFocused)
            
            Button {
                onSubmit(text)
                text = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(text.isEmpty ? Color.secondary.opacity(0.4) : Color.orange)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
        .background(Color.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Text question
            AskUserQuestionView(
                question: AskUserQuestion(
                    question: "What specific information are you looking for?",
                    questionType: .text,
                    context: "I need more details to help you effectively."
                ),
                onSubmit: { _ in },
                onDismiss: {}
            )
            
            // Confirm question
            AskUserQuestionView(
                question: AskUserQuestion(
                    question: "Should I proceed with deleting this file?",
                    questionType: .confirm
                ),
                onSubmit: { _ in },
                onDismiss: {}
            )

            // Choice question
            AskUserQuestionView(
                question: AskUserQuestion(
                    question: "Which programming language would you prefer?",
                    questionType: .choice,
                    options: ["Swift", "Python", "JavaScript", "Rust", "Go"]
                ),
                onSubmit: { _ in },
                onDismiss: {}
            )
            
            // Inline question
            InlineQuestionView(
                question: AskUserQuestion(
                    question: "Do you want to continue?",
                    questionType: .confirm
                ),
                onSubmit: { _ in }
            )
        }
        .padding()
    }
}
