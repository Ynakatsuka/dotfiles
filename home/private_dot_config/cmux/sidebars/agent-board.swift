// Agent Board — lightweight workspace and agent activity sidebar for cmux.
//
// cmux re-evaluates interpreted sidebars about once a second. Keep the data
// classification and rendered view tree deliberately small.

func hasSpinner(_ title: String) -> Bool {
    return title.hasPrefix("⠁")
        || title.hasPrefix("⠂")
        || title.hasPrefix("⠄")
        || title.hasPrefix("⡀")
        || title.hasPrefix("⢀")
        || title.hasPrefix("⠠")
        || title.hasPrefix("⠐")
        || title.hasPrefix("⠈")
        || title.hasPrefix("⠋")
        || title.hasPrefix("⠙")
        || title.hasPrefix("⠹")
        || title.hasPrefix("⠸")
        || title.hasPrefix("⠼")
        || title.hasPrefix("⠴")
        || title.hasPrefix("⠦")
        || title.hasPrefix("⠧")
        || title.hasPrefix("⠇")
        || title.hasPrefix("⠏")
}

func hasIdleMarker(_ workspace) -> Bool {
    let customTitleSuffix = "⁣⁤⁢⁣⁤⁢⁣⁤"
    let autoTitleSuffix = "⁣⁢⁤⁣⁢⁤⁣⁢"
    return workspace.title.hasSuffix(customTitleSuffix)
        || workspace.title.hasSuffix(autoTitleSuffix)
}

func progressLabel(_ workspace) -> String {
    if workspace.progress != nil && workspace.progress.label != nil {
        return workspace.progress.label.lowercased()
    }
    return ""
}

func agentState(_ workspace) -> String {
    let label = progressLabel(workspace)
    let needsInput = workspace.tabs.contains {
        $0.title.lowercased().contains("action required")
    }
    if needsInput
        || label.contains("waiting")
        || label.contains("input")
        || label.contains("approval")
        || label.contains("question")
        || label.contains("blocked") {
        return "input"
    }

    let hasWorkingTab = workspace.tabs.contains {
        hasSpinner($0.title)
    }
    if hasWorkingTab
        || label.contains("working")
        || label.contains("running")
        || label.contains("progress") {
        return "working"
    }

    if label.contains("done")
        || label.contains("complete")
        || label.contains("finished")
        || label.contains("success") {
        return "done"
    }

    if hasIdleMarker(workspace) { return "idle" }

    return "unknown"
}

func stateLabel(_ state: String) -> String {
    if state == "input" { return "Needs input" }
    if state == "working" { return "Working" }
    if state == "done" { return "Done" }
    if state == "idle" { return "Idle" }
    return ""
}

func stateTint(_ state: String) -> String {
    if state == "input" { return "#FF9F0A" }
    if state == "working" { return "#30D158" }
    if state == "done" { return "#54A8FF" }
    if state == "idle" { return "#FFD60A" }
    return "#636366"
}

func repositoryName(_ directory: String) -> String {
    let components = directory.split(separator: "/")
    if components.count == 0 { return directory }
    if components.count > 1 {
        let parent = components[components.count - 2]
        if parent.hasSuffix("-worktree") {
            return parent.replacingOccurrences(of: "-worktree", with: "")
        }
    }
    return components[components.count - 1]
}

func worktreeName(_ directory: String) -> String {
    let components = directory.split(separator: "/")
    if components.count < 2 { return "" }
    let parent = components[components.count - 2]
    if !parent.hasSuffix("-worktree") { return "" }
    return components[components.count - 1]
}

func workspaceSubtitle(_ workspace) -> String {
    let repository = repositoryName(workspace.directory)
    let worktree = worktreeName(workspace.directory)
    let branch = workspace.branch != nil ? workspace.branch : ""
    let location = worktree != "" ? "\(repository)/\(worktree)" : repository
    return branch != "" ? "\(location)  \(branch)\(workspace.dirty == true ? " •" : "")" : location
}

func tabLocation(_ tab, _ workspaceDirectory: String) -> String {
    let workspaceRepository = repositoryName(workspaceDirectory)
    let workspaceWorktree = worktreeName(workspaceDirectory)
    let workspaceLocation = workspaceWorktree != "" ? "\(workspaceRepository)/\(workspaceWorktree)" : workspaceRepository

    if tab.directory == nil || tab.directory == "" { return workspaceLocation }
    if tab.directory == workspaceDirectory || tab.directory.hasPrefix("\(workspaceDirectory)/") {
        return workspaceLocation
    }

    let tabWorktree = worktreeName(tab.directory)
    if tabWorktree != "" {
        return "\(repositoryName(tab.directory))/\(tabWorktree)"
    }
    return repositoryName(tab.directory)
}

func tabSubtitle(_ tab, _ workspaceDirectory: String) -> String {
    let location = tabLocation(tab, workspaceDirectory)
    let branch = tab.branch != nil ? tab.branch : ""
    return branch != "" ? "\(location)  \(branch)\(tab.dirty == true ? " •" : "")" : location
}

func tabState(_ tab, _ workspaceState: String) -> String {
    if tab.title.lowercased().contains("action required") { return "input" }
    if hasSpinner(tab.title) { return "working" }
    if workspaceState == "idle" { return "idle" }
    return "unknown"
}

func workspaceRow(_ workspace) -> some View {
    let state = agentState(workspace)
    let tint = stateTint(state)

    HStack(spacing: 7) {
        Capsule()
            .foregroundColor(workspace.selected ? "#7A4FD8" : tint)
            .frame(width: 3, height: 30)

        Text("\(workspace.index + 1)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor("#8E8E93")
            .frame(width: 14)

        VStack(alignment: .leading, spacing: 2) {
            Text(workspace.title)
                .font(.system(size: 12))
                .fontWeight(workspace.selected ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(workspaceSubtitle(workspace))
                .font(.system(size: 9))
                .foregroundColor("#8E8E93")
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 4) {
                Text("\(workspace.tabCount) tabs")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor("#636366")

                ForEach(workspace.tabs.prefix(6)) { tab in
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundColor(stateTint(tabState(tab, state)))
                }

                if workspace.tabCount > 6 {
                    Text("+\(workspace.tabCount - 6)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor("#636366")
                }
            }
        }

        Spacer()

        if state != "unknown" {
            Text(stateLabel(state))
                .font(.system(size: 9))
                .foregroundColor(tint)
        }
    }
    .padding(6)
    .background(workspace.selected ? "#7A4FD826" : "#00000000")
    .cornerRadius(7)
    .onTapGesture { cmux("workspace.select", workspace_id: workspace.id) }
}

func tabRow(_ tab, _ workspaceState: String, _ workspaceDirectory: String) -> some View {
    let state = tabState(tab, workspaceState)
    let tint = stateTint(state)

    HStack(spacing: 7) {
        Image(systemName: state == "unknown" ? "terminal" : "circle.fill")
            .font(.system(size: 9))
            .foregroundColor(state == "unknown" ? "#8E8E93" : tint)
            .frame(width: 14)

        VStack(alignment: .leading, spacing: 2) {
            Text(tab.title)
                .font(.system(size: 11))
                .fontWeight(tab.focused ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.tail)

            let subtitle = tabSubtitle(tab, workspaceDirectory)
            if subtitle != "" {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor("#636366")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }

        Spacer()
    }
    .padding(5)
    .background(tab.focused ? "#7A4FD81F" : "#00000000")
    .cornerRadius(7)
    .onTapGesture { cmux("surface.focus", surface_id: tab.id) }
}

VStack(alignment: .leading, spacing: 6) {
    let visibleWorkspaces = workspaces.prefix(20)
    let inputCount = visibleWorkspaces.count { agentState($0) == "input" }
    let workingCount = visibleWorkspaces.count { agentState($0) == "working" }
    let idleCount = visibleWorkspaces.count { agentState($0) == "idle" }

    HStack {
        Image(systemName: "rectangle.3.group")
            .font(.system(size: 12))
            .foregroundColor("#7A4FD8")
        Text("Agent Board")
            .font(.system(size: 13))
            .fontWeight(.semibold)
        Spacer()
    }
    .padding(4)

    Text("\(workingCount) working   \(inputCount) needs input   \(idleCount) idle")
        .font(.system(size: 9, design: .monospaced))
        .foregroundColor("#8E8E93")
        .padding(4)

    Divider()

    ForEach(visibleWorkspaces) { workspace in
        workspaceRow(workspace)
    }

    Divider()

    HStack {
        Text("Tabs")
            .font(.system(size: 10))
            .fontWeight(.semibold)
            .foregroundColor("#636366")
        Spacer()
        Text(selectedTitle)
            .font(.system(size: 10))
            .foregroundColor("#636366")
            .lineLimit(1)
    }
    .padding(4)

    ForEach(workspaces.filter { $0.selected }.prefix(1)) { selected in
        ForEach(selected.tabs.prefix(10)) { tab in
            tabRow(tab, agentState(selected), selected.directory)
        }
    }

    Spacer()
}
.foregroundColor("#F2F2F7")
.padding(4)
