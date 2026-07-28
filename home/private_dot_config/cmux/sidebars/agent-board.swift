// Agent Board — compact workspace and agent activity sidebar for cmux.
//
// The interpreted sidebar API does not expose process metadata or arbitrary
// status entries. Agent activity is therefore derived from cmux's live signals:
// progress labels and activity-prefixed surface titles.

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

func spinnerFrame(_ second: Int) -> String {
    let frame = second % 8
    if frame == 0 { return "⠋" }
    if frame == 1 { return "⠙" }
    if frame == 2 { return "⠹" }
    if frame == 3 { return "⠸" }
    if frame == 4 { return "⠼" }
    if frame == 5 { return "⠴" }
    if frame == 6 { return "⠦" }
    return "⠧"
}

func progressLabel(_ workspace) -> String {
    if workspace.progress != nil && workspace.progress.label != nil {
        return workspace.progress.label.lowercased()
    }
    return ""
}

func hasWorkingSurface(_ workspace) -> Bool {
    return workspace.tabs.contains { hasSpinner($0.title) }
}

func hasInputSurface(_ workspace) -> Bool {
    return workspace.tabs.contains {
        $0.title.lowercased().contains("action required")
    }
}

func isStopped(_ workspace) -> Bool {
    let customTitleSuffix = "⁣⁤⁢⁣⁤⁢⁣⁤" // U+2063,U+2064,U+2062,U+2063,U+2064,U+2062,U+2063,U+2064
    let autoTitleSuffix = "⁣⁢⁤⁣⁢⁤⁣⁢" // U+2063,U+2062,U+2064,U+2063,U+2062,U+2064,U+2063,U+2062
    return workspace.title.hasSuffix(customTitleSuffix)
        || workspace.title.hasSuffix(autoTitleSuffix)
}

func needsInput(_ workspace) -> Bool {
    if isStopped(workspace) { return false }
    let label = progressLabel(workspace)
    return hasInputSurface(workspace)
        || label.contains("waiting")
        || label.contains("input")
        || label.contains("approval")
        || label.contains("question")
        || label.contains("blocked")
}

func isWorking(_ workspace) -> Bool {
    if isStopped(workspace) || needsInput(workspace) { return false }
    let label = progressLabel(workspace)
    return hasWorkingSurface(workspace)
        || label.contains("working")
        || label.contains("running")
        || label.contains("progress")
}

func isDone(_ workspace) -> Bool {
    if isStopped(workspace) || needsInput(workspace) || isWorking(workspace) { return false }
    let label = progressLabel(workspace)
    return label.contains("done")
        || label.contains("complete")
        || label.contains("finished")
        || label.contains("success")
}

func hasActivity(_ workspace) -> Bool {
    return needsInput(workspace)
        || isWorking(workspace)
        || isDone(workspace)
        || isStopped(workspace)
}

func activityTint(_ workspace) -> String {
    if needsInput(workspace) { return "#FF9F0A" }
    if isWorking(workspace) { return "#30D158" }
    if isDone(workspace) { return "#54A8FF" }
    if isStopped(workspace) { return "#FFD60A" }
    return "#8E8E93"
}

func activityIcon(_ workspace) -> String {
    if needsInput(workspace) { return "exclamationmark.circle.fill" }
    if isDone(workspace) { return "checkmark.circle.fill" }
    if isStopped(workspace) { return "stop.circle.fill" }
    return "circle"
}

func activityLabel(_ workspace) -> String {
    if needsInput(workspace) { return "Needs input" }
    if isWorking(workspace) { return "Working" }
    if isDone(workspace) { return "Done" }
    if isStopped(workspace) { return "Stopped" }
    return ""
}

func hasTabActivity(_ tab) -> Bool {
    return hasSpinner(tab.title)
        || tab.title.lowercased().contains("action required")
}

func activeAgentCount(_ workspace) -> Int {
    if isStopped(workspace) { return 0 }
    return workspace.tabs.count { hasTabActivity($0) }
}

func surfaceKind(_ tab) -> String {
    if hasTabActivity(tab) { return "Agent" }
    return ""
}

func tabStatusSummary(_ workspace, _ second: Int) -> String {
    return workspace.tabs.indices.filter { $0 < 8 }.reduce("") { summary, index in
        let tab = workspace.tabs[index]
        let symbol = !isStopped(workspace) && hasSpinner(tab.title)
            ? spinnerFrame(second)
            : (tab.focused ? "●" : "○")
        let separator = summary == "" ? "" : "  "
        return "\(summary)\(separator)\(symbol) \(index + 1)"
    }
}

func tabActivityLabel(_ tab) -> String {
    if hasSpinner(tab.title) { return "Working" }
    if tab.title.lowercased().contains("action required") { return "Needs input" }
    return ""
}

func workspaceBranchText(_ workspace) -> String {
    if workspace.branch != nil && workspace.branch != "" {
        return "\(workspace.branch)\(workspace.dirty == true ? " •" : "")"
    }

    let focusedTabs = workspace.tabs.filter { $0.focused }
    if focusedTabs.count > 0 {
        let branch = tabBranchText(focusedTabs[0])
        if branch != "" { return branch }
    }

    let matchingTabs = workspace.tabs.filter { $0.directory == workspace.directory }
    if matchingTabs.count > 0 {
        let branch = tabBranchText(matchingTabs[0])
        if branch != "" { return branch }
    }

    let currentWorktree = worktreeName(workspace)
    if currentWorktree != "" {
        let worktreeTabs = workspace.tabs.filter {
            tabWorktreeName($0) == currentWorktree
        }
        if worktreeTabs.count > 0 {
            let branch = tabBranchText(worktreeTabs[0])
            if branch != "" { return branch }
        }
    }

    return ""
}

func repositoryNameFromDirectory(_ directory: String) -> String {
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

func worktreeNameFromDirectory(_ directory: String) -> String {
    let components = directory.split(separator: "/")
    if components.count < 2 { return "" }
    let parent = components[components.count - 2]
    if !parent.hasSuffix("-worktree") { return "" }
    return components[components.count - 1]
}

func repositoryName(_ workspace) -> String {
    return repositoryNameFromDirectory(workspace.directory)
}

func worktreeName(_ workspace) -> String {
    return worktreeNameFromDirectory(workspace.directory)
}

func tabRepositoryName(_ tab) -> String {
    if tab.directory == nil || tab.directory == "" { return "" }
    return repositoryNameFromDirectory(tab.directory)
}

func tabWorktreeName(_ tab) -> String {
    if tab.directory == nil || tab.directory == "" { return "" }
    return worktreeNameFromDirectory(tab.directory)
}

func hasPullRequest(_ workspace) -> Bool {
    return workspace.pr != nil && workspace.pr.label != nil && workspace.pr.label != ""
}

func tabBranchText(_ tab) -> String {
    if tab.branch == nil || tab.branch == "" { return "" }
    return "\(tab.branch)\(tab.dirty == true ? " •" : "")"
}

func prTint(_ workspace) -> String {
    if !hasPullRequest(workspace) { return "#8E8E93" }
    if workspace.pr.stale == true { return "#8E8E93" }
    if workspace.pr.status == "open" { return "#3FB950" }
    if workspace.pr.status == "merged" { return "#A371F7" }
    if workspace.pr.status == "closed" { return "#F85149" }
    return "#8E8E93"
}

func activityDetail(_ workspace) -> String {
    if needsInput(workspace) && workspace.latestMessage != nil {
        return workspace.latestMessage
    }
    if isWorking(workspace) && workspace.latestPrompt != nil {
        return workspace.latestPrompt
    }
    if isDone(workspace) && workspace.latestMessage != nil {
        return workspace.latestMessage
    }
    if isStopped(workspace) && workspace.latestMessage != nil {
        return workspace.latestMessage
    }
    return ""
}

func workspaceRow(_ workspace, _ second: Int) -> some View {
    let tint = activityTint(workspace)
    let detail = activityDetail(workspace)
    let worktree = worktreeName(workspace)
    let branch = workspaceBranchText(workspace)
    let agents = activeAgentCount(workspace)

    Button(action: { cmux("workspace.select", workspace_id: workspace.id) }) {
        HStack(alignment: .top, spacing: 7) {
            Capsule()
                .foregroundColor(workspace.selected ? "#7A4FD8" : tint)
                .opacity(workspace.selected ? 1.0 : 0.7)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(workspace.index + 1)")
                        .font(.system(size: 8, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(workspace.selected ? "#FFFFFF" : "#8E8E93")
                        .frame(width: 14, height: 14)
                        .background(workspace.selected ? "#7A4FD8" : "#8E8E9326")
                        .cornerRadius(4)

                    Text(workspace.title)
                        .font(.system(size: 13))
                        .fontWeight(workspace.selected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    if agents > 0 {
                        Label("\(agents)", systemImage: "cpu")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor("#636366")
                    }

                    if isWorking(workspace) {
                        Text(spinnerFrame(second))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(tint)
                    } else if hasActivity(workspace) {
                        Image(systemName: activityIcon(workspace))
                            .font(.system(size: 10))
                            .foregroundColor(tint)
                    }
                }

                HStack(spacing: 5) {
                    Text(repositoryName(workspace))
                        .font(.system(size: 10))
                        .foregroundColor("#8E8E93")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }

                if worktree != "" {
                    Label(worktree, systemImage: "square.stack.3d.down.right")
                        .font(.system(size: 10))
                        .foregroundColor("#636366")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if branch != "" {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundColor("#8E8E93")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if hasActivity(workspace) || hasPullRequest(workspace) {
                    HStack(spacing: 5) {
                        if hasActivity(workspace) {
                            Text(activityLabel(workspace))
                                .font(.system(size: 10))
                                .foregroundColor(tint)
                        }

                        if hasPullRequest(workspace) {
                            Text(workspace.pr.label)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(prTint(workspace))
                        }
                    }
                }

                Text("\(tabStatusSummary(workspace, second))\(workspace.tabCount > 8 ? "  +\(workspace.tabCount - 8)" : "")")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor("#8E8E93")
                    .lineLimit(1)
                    .truncationMode(.tail)

                if detail != "" {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor("#636366")
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(6)
        .background(workspace.selected ? "#7A4FD826" : "#00000000")
        .cornerRadius(8)
    }
}

func surfaceRow(_ tab, _ workspaceStopped: Bool) -> some View {
    let repository = tabRepositoryName(tab)
    let worktree = tabWorktreeName(tab)
    let branch = tabBranchText(tab)
    let activity = workspaceStopped ? "" : tabActivityLabel(tab)

    Button(action: { cmux("surface.focus", surface_id: tab.id) }) {
        HStack(spacing: 7) {
            Image(systemName: !workspaceStopped && hasTabActivity(tab) ? "cpu" : "terminal")
                .font(.system(size: 10))
                .foregroundColor(tab.focused ? "#7A4FD8" : "#8E8E93")
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.system(size: 11))
                    .fontWeight(tab.focused ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if repository != "" {
                    Text(repository)
                        .font(.system(size: 9))
                        .foregroundColor("#8E8E93")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if worktree != "" {
                    Label(worktree, systemImage: "square.stack.3d.down.right")
                        .font(.system(size: 9))
                        .foregroundColor("#636366")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if branch != "" {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.system(size: 9))
                        .foregroundColor("#636366")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if activity != "" {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(activity)
                        .font(.system(size: 9))
                        .foregroundColor("#8E8E93")
                    Text(surfaceKind(tab))
                        .font(.system(size: 8))
                        .foregroundColor("#636366")
                }
            }
        }
        .padding(5)
        .background(tab.focused ? "#7A4FD81F" : "#00000000")
        .cornerRadius(7)
    }
}

VStack(alignment: .leading, spacing: 6) {
    let visibleWorkspaces = workspaces.filter { $0.index < 30 }
    let inputCount = visibleWorkspaces.count { needsInput($0) }
    let workingCount = visibleWorkspaces.count { isWorking($0) }
    let doneCount = visibleWorkspaces.count { isDone($0) }
    let stoppedCount = visibleWorkspaces.count { isStopped($0) }

    HStack(spacing: 6) {
        Image(systemName: "rectangle.3.group")
            .font(.system(size: 12))
            .foregroundColor("#7A4FD8")
        Text("Agent Board")
            .font(.system(size: 13))
            .fontWeight(.semibold)
        Spacer()
        Text(clock.time)
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor("#636366")
    }
    .padding(4)

    HStack(spacing: 8) {
        if inputCount > 0 {
            Label("\(inputCount) needs input", systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 9))
                .foregroundColor("#FF9F0A")
        }
        if workingCount > 0 {
            Text("\(spinnerFrame(clock.second)) \(workingCount) working")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor("#30D158")
        }
        if doneCount > 0 {
            Label("\(doneCount) done", systemImage: "checkmark.circle.fill")
                .font(.system(size: 9))
                .foregroundColor("#54A8FF")
        }
        if stoppedCount > 0 {
            Label("\(stoppedCount) stopped", systemImage: "stop.circle.fill")
                .font(.system(size: 9))
                .foregroundColor("#FFD60A")
        }
        if inputCount == 0 && workingCount == 0 && doneCount == 0 && stoppedCount == 0 {
            Text("No active agents")
                .font(.system(size: 9))
                .foregroundColor("#636366")
        }
        Spacer()
    }
    .padding(4)

    Divider()

    HStack {
        Text("Workspaces")
            .font(.system(size: 10))
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundColor("#636366")
        Spacer()
        Text("\(visibleWorkspaces.count)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor("#636366")
    }
    .padding(4)

    ForEach(visibleWorkspaces) { workspace in
        workspaceRow(workspace, clock.second)
    }

    Divider()

    HStack {
        Text("Tabs")
            .font(.system(size: 10))
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundColor("#636366")
        Spacer()
        Text(selectedTitle)
            .font(.system(size: 10))
            .foregroundColor("#636366")
            .lineLimit(1)
    }
    .padding(4)

    ForEach(workspaces.filter { $0.selected }.prefix(1)) { selected in
        if selected.tabs.isEmpty {
            Text("No tabs")
                .font(.system(size: 10))
                .foregroundColor("#636366")
                .padding(6)
        } else {
            ForEach(selected.tabs.prefix(12)) { tab in
                surfaceRow(tab, isStopped(selected))
            }
        }
    }

    Spacer()
}
.foregroundColor("#F2F2F7")
.padding(4)
