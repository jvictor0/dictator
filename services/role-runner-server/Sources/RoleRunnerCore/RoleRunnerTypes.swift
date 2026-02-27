import Foundation

public enum Role: String, Codable, CaseIterable {
    case architect
    case implementer
    case reviewer
    case tester
}

public struct RunRoleRequest: Codable {
    public let workItemID: String
    public let sliceID: String
    public let role: Role

    public init(workItemID: String, sliceID: String, role: Role) {
        self.workItemID = workItemID
        self.sliceID = sliceID
        self.role = role
    }

    enum CodingKeys: String, CodingKey {
        case workItemID = "work_item_id"
        case sliceID = "slice_id"
        case role
    }
}

public enum RunStatus: String, Codable {
    case success
    case validationError = "validation_error"
    case executionError = "execution_error"
}

public struct RunRoleResponse: Codable {
    public let runID: String
    public let status: RunStatus
    public let workItemID: String
    public let sliceID: String
    public let role: Role
    public let artifactsWritten: [String]
    public let issuesOpen: [String]
    public let issuesCreated: [String]
    public let nextAllowedRoles: [Role]
    public let message: String

    public init(
        runID: String,
        status: RunStatus,
        workItemID: String,
        sliceID: String,
        role: Role,
        artifactsWritten: [String],
        issuesOpen: [String],
        issuesCreated: [String],
        nextAllowedRoles: [Role],
        message: String
    ) {
        self.runID = runID
        self.status = status
        self.workItemID = workItemID
        self.sliceID = sliceID
        self.role = role
        self.artifactsWritten = artifactsWritten
        self.issuesOpen = issuesOpen
        self.issuesCreated = issuesCreated
        self.nextAllowedRoles = nextAllowedRoles
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case status
        case workItemID = "work_item_id"
        case sliceID = "slice_id"
        case role
        case artifactsWritten = "artifacts_written"
        case issuesOpen = "issues_open"
        case issuesCreated = "issues_created"
        case nextAllowedRoles = "next_allowed_roles"
        case message
    }
}

public struct HTTPResponse {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}
