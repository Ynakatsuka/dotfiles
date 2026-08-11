// Agent Board — lightweight workspace and agent activity sidebar for cmux.
//
// cmux re-evaluates interpreted sidebars about once a second. Keep the data
// classification and rendered view tree deliberately small.

// The diff refresher replaces only this block in the runtime copy under
// ~/.local/state/cmux. This managed source remains static under chezmoi.
// BEGIN CMUX_DIFF_DATA (managed by cmux-agent-board-diff-refresh)
func diffTotalsOf(_ dir) -> String { return "" }
func diffTreeOf(_ dir) -> String { return "" }
func diffMoreOf(_ dir) -> String { return "" }
func diffRootOf(_ dir) -> String { return "" }
// END CMUX_DIFF_DATA

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

func progressLabel(_ workspace) -> String {
    if workspace.progress != nil && workspace.progress.label != nil {
        return workspace.progress.label.lowercased()
    }
    return ""
}

func managedTitleState(_ title: String) -> String {
    // Keep these zero-width markers literal. cmux 0.64.22 does not expand
    // Unicode escape sequences in interpreted sidebar string literals.
    if title.hasSuffix("⁠​⁠") { return "working" }
    if title.hasSuffix("⁠‌⁠") { return "idle" }
    if title.hasSuffix("⁠‍⁠") { return "input" }
    return ""
}

func displayTitle(_ title: String) -> String {
    return title
        .replacingOccurrences(of: "⁠​⁠", with: "")
        .replacingOccurrences(of: "⁠‌⁠", with: "")
        .replacingOccurrences(of: "⁠‍⁠", with: "")
}

func agentState(_ workspace) -> String {
    let legacyTitleState = managedTitleState(workspace.title)
    let label = progressLabel(workspace)
    let needsInput = workspace.tabs.contains {
        managedTitleState($0.title) == "input"
            || $0.title.lowercased().contains("action required")
    }
    if needsInput
        || legacyTitleState == "input"
        || label.contains("waiting")
        || label.contains("input")
        || label.contains("approval")
        || label.contains("question")
        || label.contains("blocked") {
        return "input"
    }

    let hasWorkingTab = workspace.tabs.contains {
        managedTitleState($0.title) == "working" || hasSpinner($0.title)
    }
    if hasWorkingTab
        || legacyTitleState == "working"
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

    if label.contains("idle") {
        return "idle"
    }

    return "idle"
}

func stateTint(_ state: String) -> String {
    if state == "input" { return "#FF9F0A" }
    if state == "working" { return "#30D158" }
    if state == "done" { return "#54A8FF" }
    if state == "idle" { return "#8E8E93" }
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

func managedDescriptionValue(_ workspace, _ prefix: String) -> String {
    // The interpreted sidebar does not unescape newline literals. Metadata
    // therefore uses a printable unit-separator symbol in one description.
    let matchingFields = "\(workspace.description)".split(separator: "␟").filter {
        $0.hasPrefix(prefix)
    }
    if matchingFields.count == 0 { return "" }
    return matchingFields[0]
        .replacingOccurrences(of: prefix, with: "")
        .trimmingCharacters(in: .whitespaces)
}

func managedDescriptionBranch(_ workspace) -> String {
    return managedDescriptionValue(workspace, "agent-board-branch:")
}

func diffCount(_ workspace) -> String {
    let parts = diffTotalsOf(workspace.directory).split(separator: "|")
    if parts.count < 3 { return "0" }
    return "\(parts[0])"
}

func diffBadge(_ workspace) -> some View {
    let parts = diffTotalsOf(workspace.directory).split(separator: "|")
    HStack(spacing: 3) {
        if parts.count > 2 {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 8))
                .foregroundColor("#8E8E93")
            Text("\(parts[0])")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor("#8E8E93")
            Text("+\(parts[1])")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor("#30D158")
            Text("−\(parts[2])")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor("#FF453A")
        }
    }
}

func diffKindIcon(_ kind: String) -> String {
    if kind == "N" { return "plus.circle.fill" }
    if kind == "D" { return "minus.circle.fill" }
    return "pencil.circle.fill"
}

func diffKindColor(_ kind: String) -> String {
    if kind == "N" { return "#30D158" }
    if kind == "D" { return "#FF453A" }
    return "#54A8FF"
}

func diffTreeRow(_ workspace, _ entry) -> some View {
    let fields = "\(entry)".split(separator: "|")
    let rowType = fields.count > 0 ? "\(fields[0])" : ""
    Group {
        if rowType == "D" {
            HStack(spacing: 5) {
                Text(fields.count > 1 ? "\(fields[1])" : " ")
                    .font(.system(size: 9, design: .monospaced))
                Image(systemName: "folder.fill")
                    .font(.system(size: 9))
                    .foregroundColor("#636366")
                    .frame(width: 12)
                Text(fields.count > 2 ? "\(fields[2])" : "")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor("#8E8E93")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(4)
        } else {
            let indent = fields.count > 1 ? "\(fields[1])" : " "
            let kind = fields.count > 2 ? "\(fields[2])" : ""
            let added = fields.count > 3 ? "\(fields[3])" : ""
            let deleted = fields.count > 4 ? "\(fields[4])" : ""
            let fileName = fields.count > 5 ? "\(fields[5])" : ""
            let filePath = fields.count > 6 ? "\(fields[6])" : ""
            let pathToken = fields.count > 7 ? "\(fields[7])" : ""
            Button(action: {
                cmux(
                    "surface.create",
                    workspace_id: workspace.id,
                    type: "terminal",
                    working_directory: diffRootOf(workspace.directory),
                    initial_command: "~/.local/bin/cmux-agent-board-diff-open \(pathToken) && exit",
                    focus: true
                )
            }) {
                HStack(spacing: 5) {
                    Text(indent)
                        .font(.system(size: 8, design: .monospaced))
                    Image(systemName: diffKindIcon(kind))
                        .font(.system(size: 9))
                        .foregroundColor(diffKindColor(kind))
                        .frame(width: 12)
                    Text(fileName)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor("#8E8E93")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if added == "-" {
                        Text("bin")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor("#636366")
                    } else {
                        Text("+\(added)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor("#30D158")
                        Text("−\(deleted)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor("#FF453A")
                    }
                }
                .padding(4)
            }
            .disabled(filePath == "" || pathToken == "")
            .help("View diff for \(filePath)")
        }
    }
}

func diffTreeList(_ workspace) -> some View {
    let rows = diffTreeOf(workspace.directory).split(separator: ";")
    let more = diffMoreOf(workspace.directory)
    VStack(alignment: .leading, spacing: 1) {
        ForEach(rows.indices) { index in
            diffTreeRow(workspace, rows[index])
        }
        if more != "" {
            Text("+ \(more) more")
                .font(.system(size: 9))
                .foregroundColor("#636366")
                .padding(4)
        }
    }
}

func workspaceBranchText(_ workspace) -> String {
    if workspace.branch != nil && workspace.branch != "" {
        return "\(workspace.branch)\(workspace.dirty == true ? " •" : "")"
    }

    let managedBranch = managedDescriptionBranch(workspace)
    if managedBranch != "" {
        return "\(managedBranch)\(workspace.dirty == true ? " •" : "")"
    }

    let focusedTabs = workspace.tabs.filter { $0.focused }
    if focusedTabs.count > 0 && focusedTabs[0].branch != nil && focusedTabs[0].branch != "" {
        return "\(focusedTabs[0].branch)\(focusedTabs[0].dirty == true ? " •" : "")"
    }

    let matchingTabs = workspace.tabs.filter { $0.directory == workspace.directory }
    if matchingTabs.count > 0 && matchingTabs[0].branch != nil && matchingTabs[0].branch != "" {
        return "\(matchingTabs[0].branch)\(matchingTabs[0].dirty == true ? " •" : "")"
    }

    let currentWorktree = worktreeName(workspace.directory)
    if currentWorktree != "" {
        let worktreeTabs = workspace.tabs.filter {
            $0.directory != nil && worktreeName($0.directory) == currentWorktree
        }
        if worktreeTabs.count > 0 && worktreeTabs[0].branch != nil && worktreeTabs[0].branch != "" {
            return "\(worktreeTabs[0].branch)\(worktreeTabs[0].dirty == true ? " •" : "")"
        }
    }

    return ""
}

func workspaceWorktreeText(_ workspace) -> String {
    let repository = repositoryName(workspace.directory)
    let worktree = worktreeName(workspace.directory)
    return worktree != "" ? "\(repository)/\(worktree)" : repository
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

func tabState(_ tab) -> String {
    let titleState = managedTitleState(tab.title)
    if titleState != "" { return titleState }
    if tab.title.lowercased().contains("action required") { return "input" }
    if hasSpinner(tab.title) { return "working" }
    return "idle"
}

func workspaceRow(_ workspace) -> some View {
    let state = agentState(workspace)
    let tint = stateTint(state)
    let branch = workspaceBranchText(workspace)
    let branchLabel = branch != "" ? branch : "—"

    HStack(spacing: 7) {
        Capsule()
            .foregroundColor(tint)
            .frame(width: 3)

        Text("\(workspace.index + 1)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor("#8E8E93")
            .frame(width: 14)

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(displayTitle(workspace.title))
                    .font(.system(size: 12))
                    .fontWeight(workspace.selected ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Label(workspaceWorktreeText(workspace), systemImage: "square.stack.3d.down.right")
                .font(.system(size: 9))
                .foregroundColor("#8E8E93")
                .lineLimit(1)
                .truncationMode(.middle)

            Label(branchLabel, systemImage: "arrow.triangle.branch")
                .font(.system(size: 9))
                .foregroundColor("#8E8E93")
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 4) {
                Spacer()
                diffBadge(workspace)
            }

            HStack(spacing: 4) {
                ForEach(workspace.tabs) { tab in
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundColor(stateTint(tabState(tab)))
                }
            }
        }

        Spacer()
    }
    .padding(6)
    .background(workspace.selected ? "#7A4FD826" : "#00000000")
    .cornerRadius(7)
    .onTapGesture { cmux("workspace.select", workspace_id: workspace.id) }
}

func tabRow(_ tab, _ workspaceDirectory: String) -> some View {
    let state = tabState(tab)
    let tint = stateTint(state)

    HStack(spacing: 7) {
        Image(systemName: state == "unknown" ? "terminal" : "circle.fill")
            .font(.system(size: 9))
            .foregroundColor(state == "unknown" ? "#8E8E93" : tint)
            .frame(width: 14)

        VStack(alignment: .leading, spacing: 2) {
            Text(displayTitle(tab.title))
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

    Reorderable(visibleWorkspaces, move: "workspace.reorder") { workspace in
        workspaceRow(workspace)
    }

    Divider()

    HStack {
        Text("Tabs")
            .font(.system(size: 10))
            .fontWeight(.semibold)
            .foregroundColor("#636366")
        Spacer()
        Text(displayTitle(selectedTitle))
            .font(.system(size: 10))
            .foregroundColor("#636366")
            .lineLimit(1)
    }
    .padding(4)

    ForEach(workspaces.filter { $0.selected }.prefix(1)) { selected in
        ForEach(selected.tabs.prefix(10)) { tab in
            tabRow(tab, selected.directory)
        }

        Divider()

        HStack {
            Text("Diff")
                .font(.system(size: 10))
                .fontWeight(.semibold)
                .foregroundColor("#636366")
            Spacer()
            Text(diffCount(selected))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor("#636366")
        }
        .padding(4)

        if diffTotalsOf(selected.directory) == "" {
            Text("No changes")
                .font(.system(size: 9))
                .foregroundColor("#636366")
                .padding(4)
        } else {
            diffTreeList(selected)
        }
    }

    Spacer()
}
.foregroundColor("#F2F2F7")
.padding(4)
