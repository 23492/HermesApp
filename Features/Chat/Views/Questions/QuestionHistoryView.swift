import SwiftUI

// MARK: - Question History View
// Shows question/answer pairs in conversation

struct QuestionHistoryView: View {
    let question: AskUserQuestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question section
            questionSection
            
            // Answer section (if answered)
            if question.isAnswered, let response = question.response {
                answerSection(response)
            }
        }
        .padding(14)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // MARK: - Subviews
    
    private var questionSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.bubble.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Question")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    Text(formattedTime(question.askedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(question.question)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Question type badge
                HStack {
                    questionTypeBadge
                    
                    if question.isAnswered, let answeredAt = question.answeredAt {
                        Text("Answered \(timeAgo(answeredAt))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func answerSection(_ response: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.fill")
                .font(.title3)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Answer")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                
                Text(response)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, -14),
            alignment: .top
        )
    }
    
    private var questionTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForType)
                .font(.caption2)
            Text(question.questionType.displayName)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Helpers
    
    private var iconForType: String {
        switch question.questionType {
        case .text:
            return "text.alignleft"
        case .confirm:
            return "checkmark.circle"
        case .choice:
            return "list.bullet"
        }
    }
    
    private var backgroundColor: Color {
        Color.orange.opacity(0.05)
    }
    
    private var borderColor: Color {
        Color.orange.opacity(0.2)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

// MARK: - Question History List

struct QuestionHistoryList: View {
    let questions: [AskUserQuestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.orange)
                
                Text("Question History")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(questions.count) question\(questions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 10) {
                ForEach(questions) { question in
                    QuestionHistoryView(question: question)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Pending Question Banner

struct PendingQuestionBanner: View {
    let question: AskUserQuestion
    let onTap: () -> Void
    
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Animated icon
                Image(systemName: "questionmark.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, options: .repeating, isActive: isPulsing)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI needs your input")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(question.question)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Question Response Card

struct QuestionResponseCard: View {
    let question: String
    let response: String
    let timestamp: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Question
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
                Text(question)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            // Response
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Text(response)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Pending question banner
            PendingQuestionBanner(
                question: AskUserQuestion(
                    question: "Should I proceed with the file deletion?",
                    questionType: .confirm
                ),
                onTap: {}
            )
            
            // Answered question
            QuestionHistoryView(
                question: answeredQuestion()
            )
            
            // Unanswered question
            QuestionHistoryView(
                question: AskUserQuestion(
                    question: "What is your preferred programming language?",
                    questionType: .choice,
                    options: ["Swift", "Python", "JavaScript"]
                )
            )
            
            // Question list
            QuestionHistoryList(
                questions: [
                    answeredQuestion(),
                    AskUserQuestion(
                        question: "Another question here?",
                        questionType: .text
                    )
                ]
            )
        }
        .padding()
    }
}

private func answeredQuestion() -> AskUserQuestion {
    var question = AskUserQuestion(
        question: "Should I proceed with deleting this file?",
        questionType: .confirm
    )
    question.submitResponse("Yes, proceed with caution.")
    return question
}
