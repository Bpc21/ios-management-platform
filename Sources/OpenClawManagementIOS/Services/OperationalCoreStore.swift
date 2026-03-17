import Foundation

@MainActor
@Observable
final class OperationalCoreStore {
    private static let tasksKey = "operational.tasks"
    private static let workflowsKey = "operational.workflows"
    private static let knowledgeKey = "operational.knowledge"

    private let defaults: UserDefaults

    private(set) var tasks: [TaskItem] = []
    private(set) var workflows: [WorkflowItem] = []
    private(set) var knowledgeEntries: [KnowledgeItem] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func tasks(in status: TaskStatus) -> [TaskItem] {
        tasks
            .filter { $0.status == status }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func createTask(
        title: String,
        descriptionText: String = "",
        priority: TaskPriority = .medium,
        status: TaskStatus = .inbox,
        assignedAgentId: String? = nil,
        workflowTemplateId: String? = nil,
        dueDate: Date? = nil
    ) -> TaskItem {
        let now = Date()
        let task = TaskItem(
            id: UUID().uuidString,
            title: title,
            descriptionText: descriptionText,
            status: status,
            priority: priority,
            assignedAgentId: assignedAgentId,
            workflowTemplateId: workflowTemplateId,
            dueDate: dueDate,
            createdAt: now,
            updatedAt: now)
        tasks.insert(task, at: 0)
        saveTasks()
        return task
    }

    func updateTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.updatedAt = Date()
        tasks[index] = updated
        saveTasks()
    }

    func moveTask(_ task: TaskItem, to status: TaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].status = status
        tasks[index].updatedAt = Date()
        saveTasks()
    }

    func deleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }

    @discardableResult
    func createWorkflow(
        name: String,
        descriptionText: String,
        stages: [WorkflowStageItem]
    ) -> WorkflowItem {
        let now = Date()
        let workflow = WorkflowItem(
            id: UUID().uuidString,
            name: name,
            descriptionText: descriptionText,
            isActive: true,
            stages: stages.sorted { $0.orderIndex < $1.orderIndex },
            createdAt: now,
            updatedAt: now)
        workflows.insert(workflow, at: 0)
        saveWorkflows()
        return workflow
    }

    func toggleWorkflow(_ workflow: WorkflowItem) {
        guard let index = workflows.firstIndex(where: { $0.id == workflow.id }) else { return }
        workflows[index].isActive.toggle()
        workflows[index].updatedAt = Date()
        saveWorkflows()
    }

    func deleteWorkflow(_ workflow: WorkflowItem) {
        workflows.removeAll { $0.id == workflow.id }
        saveWorkflows()
    }

    @discardableResult
    func createKnowledgeEntry(title: String, content: String, sourceTaskId: String? = nil) -> KnowledgeItem {
        let entry = KnowledgeItem(
            id: UUID().uuidString,
            title: title,
            content: content,
            sourceTaskId: sourceTaskId,
            createdAt: Date())
        knowledgeEntries.insert(entry, at: 0)
        saveKnowledge()
        return entry
    }

    func deleteKnowledgeEntry(_ entry: KnowledgeItem) {
        knowledgeEntries.removeAll { $0.id == entry.id }
        saveKnowledge()
    }

    private func load() {
        tasks = decode([TaskItem].self, key: Self.tasksKey) ?? []
        workflows = decode([WorkflowItem].self, key: Self.workflowsKey) ?? []
        knowledgeEntries = decode([KnowledgeItem].self, key: Self.knowledgeKey) ?? []
    }

    private func saveTasks() {
        encode(tasks, key: Self.tasksKey)
    }

    private func saveWorkflows() {
        encode(workflows, key: Self.workflowsKey)
    }

    private func saveKnowledge() {
        encode(knowledgeEntries, key: Self.knowledgeKey)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}
