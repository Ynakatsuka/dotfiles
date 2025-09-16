# Release Note Creation Guide

## Your task

Based on the above changes and PR history, create a comprehensive release note following these steps:

### 1. Gather PR and Commit Information

First, collect both PR and commit information for the release period:

```bash
# Get PR history since last release
gh pr list --state merged --limit 50 --json number,title,body,mergedAt,author,labels,url

# Get detailed commit history
git log --oneline --since="YYYY-MM-DD" --pretty=format:"%h %s (%an, %ad)" --date=short

# Get PR-commit associations
gh pr list --state merged --limit 50 --json number,title,mergeCommit
```

### 2. Determine Version Number

- Previous release: Check from the context above
- New version: Increment patch version (v2.4.X → v2.4.X+1)
- Consider semantic versioning based on change types

### 3. Analyze and Categorize Changes

Analyze both PR titles/descriptions and commits to categorize into:

**Categories:**

- **✨ New Features**: New functionality or enhancements
- **🐛 Bug Fixes**: Issue resolutions and error corrections  
- **📝 Documentation**: Documentation updates and improvements
- **♻️ Refactoring**: Code restructuring without behavior changes
- **⚡ Performance**: Performance improvements and optimizations
- **🔧 Maintenance**: Dependency updates, tooling changes
- **🚨 Breaking Changes**: Changes that may affect compatibility

**Analysis Priority:**

1. PR titles and descriptions (primary source)
2. PR labels and reviewers' feedback
3. Individual commit messages (supplementary)
4. Related issues mentioned in PRs

### 4. Create Release Note

Use this enhanced template with both PR and commit links:

```markdown
## vX.X.X - YYYY-MM-DD

### ✨ New Features
- [Feature description] ([PR #123](https://github.com/owner/repo/pull/123))
  - Additional details from PR description
  - Related commits: ([abc123](https://github.com/owner/repo/commit/abc123))

### 🐛 Bug Fixes  
- [Fix description] ([PR #124](https://github.com/owner/repo/pull/124))
  - Problem solved and impact
  - Related commits: ([def456](https://github.com/owner/repo/commit/def456))

### 📝 Documentation
- [Doc improvement] ([PR #125](https://github.com/owner/repo/pull/125))

### ♻️ Refactoring
- [Refactoring description] ([PR #126](https://github.com/owner/repo/pull/126))

### 🔧 Maintenance
- [Maintenance update] ([PR #127](https://github.com/owner/repo/pull/127))

**Full Changelog**: https://github.com/owner/repo/compare/vX.X.X...vY.Y.Y
```

### 5. Create GitHub Release

```bash
gh release create vX.X.X --title "vX.X.X" --notes "[Release note content]"
```

## Enhanced Analysis Guidelines

### PR Information Priority

1. **PR Title**: Primary source for change description
2. **PR Body**: Context, motivation, and implementation details
3. **PR Labels**: Help with automatic categorization
4. **Review Comments**: Additional insights and edge cases
5. **Linked Issues**: Background and user impact

### Quality Checklist

- [ ] All merged PRs since last release are included
- [ ] Each change links to both PR and relevant commits
- [ ] Categories are accurate based on actual impact
- [ ] Breaking changes are clearly highlighted
- [ ] User-facing changes are explained in simple terms
- [ ] Technical changes include context for developers

### Important Notes

- **Always include both PR and commit links** for complete traceability
- **Prioritize PR information** over individual commits for better context
- Use **Japanese** for release note descriptions but keep technical terms in English
- **Link format**: `([PR #123](PR_URL))` for PRs, `([hash](commit_URL))` for commits
- **Breaking changes must be prominently featured** at the top
- Consider grouping related PRs under broader feature themes
- Include contributor acknowledgments when appropriate
