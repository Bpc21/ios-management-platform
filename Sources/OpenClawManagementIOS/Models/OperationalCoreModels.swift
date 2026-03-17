import Foundation

enum TaskStatus: String, CaseIterable, Codable {
    case inbox
    case assigned
    case inProgress
    case review
    case testing
    case done

    var label: String {
        switch self {
        case .inbox: return "Inbox"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .review: return "Review"
        case .testing: return "Testing"
        case .done: return "Done"
        }
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case low
    case medium
    case high
    case critical

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

struct TaskItem: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var descriptionText: String
    var status: TaskStatus
    var priority: TaskPriority
    var assignedAgentId: String?
    var workflowTemplateId: String?
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
}

struct WorkflowStageItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var role: String
    var orderIndex: Int
}

struct WorkflowItem: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var descriptionText: String
    var isActive: Bool
    var stages: [WorkflowStageItem]
    var createdAt: Date
    var updatedAt: Date
}

struct KnowledgeItem: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var content: String
    var sourceTaskId: String?
    var createdAt: Date
}
