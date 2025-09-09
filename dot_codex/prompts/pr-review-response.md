# PR Review Response Workflow

## Your task

Systematically address all review comments on the current PR branch following this workflow:

### 1. Gather PR Review Information

First, identify the current PR and fetch all review comments:

```bash
# Get current branch name
CURRENT_BRANCH=$(git branch --show-current)

# Find PR associated with current branch
PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number -q '.[0].number')

# Fetch all review comments and conversations
gh pr view $PR_NUMBER --json reviews,comments,title,url

# Get detailed review threads
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments --paginate

# Get review comment threads with context
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews --paginate
```

### 2. Parse and Categorize Review Comments

Analyze review comments and categorize them:

**Comment Types:**

- **🔴 Change Requested**: Must be addressed before merge
- **🟡 Suggestion**: Recommended improvements
- **🔵 Question**: Clarifications needed
- **🟢 Nitpick**: Optional style/formatting fixes
- **✅ Resolved**: Already addressed comments

**Analysis Structure:**

```markdown
## Review Comments Summary

### 🔴 Change Requested (X items)
1. **File:** `path/to/file.ext` (Line XX)
   **Reviewer:** @username
   **Comment:** [Original comment text]
   **Context:** [Code snippet around the comment]
   **Status:** Pending

### 🟡 Suggestions (Y items)
...
```

### 3. Address Each Comment Loop

For each unresolved comment, follow this loop:

**Processing Template:**

```markdown
## Processing Comment #X

### Comment Details
- **File:** `path/to/file.ext`
- **Line:** XX
- **Reviewer:** @username
- **Type:** Change Requested / Suggestion / Question
- **Comment:** "[Full comment text]"

### Current Code
```

```text
[Current code at the location]
```

```markdown
### Proposed Fix
```

```text
[Proposed new code]
```

```markdown
### Rationale

[Explanation of why this fix addresses the comment]

### Actions to Take

1. [Specific file edits]
2. [Any additional changes needed]

---

#### 🔄 User Approval Required

- [ ] Proceed with this fix?
- [ ] Modify the approach?
- [ ] Skip this comment?
- [ ] Request clarification from reviewer?
```

### 4. Implementation Workflow

After user approval for each comment:

```bash
# 1. Make the approved changes
[Edit commands based on user approval]

# 2. Commit with descriptive message
git add -p  # Interactive staging
git commit -m "fix: Address review comment about [specific issue]

- [Detailed description of the change]
- Addresses @reviewer's comment on [file]:[line]"

# 3. Mark comment as resolved (if applicable)
gh pr comment $PR_NUMBER --body "Fixed in commit [hash]. [Additional explanation if needed]"

# 4. Update PR description if needed
gh pr edit $PR_NUMBER --body "[Updated description]"
```

### 5. Progress Tracking

Maintain a progress report throughout the process:

```markdown
## Review Response Progress

### Completed (X/Total)
- [x] Comment #1: Fixed validation logic
- [x] Comment #2: Added error handling
- [ ] Comment #3: Pending user approval

### Summary of Changes
- Total commits added: X
- Files modified: Y
- Tests added/updated: Z

### Next Steps
- [ ] Push all changes
- [ ] Request re-review
- [ ] Update PR description
```

### 6. Final Steps

After all comments are addressed:

```bash
# Push all changes
git push

# Request re-review from specific reviewers
gh pr review $PR_NUMBER --request-changes --body "All review comments have been addressed. Please re-review."

# Add summary comment
gh pr comment $PR_NUMBER --body "## Review Response Summary

All review comments have been addressed:
- 🔴 Change Requested: X/X completed
- 🟡 Suggestions: Y/Y implemented
- 🔵 Questions: Z/Z answered

See individual commits for specific fixes."
```

## Workflow Guidelines

### Comment Prioritization

1. **Always address "Changes Requested" first**
2. **Consider all suggestions seriously**
3. **Provide clear answers to questions**
4. **Document why certain suggestions were not implemented**

### Best Practices

- **One commit per logical fix** (can address multiple related comments)
- **Reference the comment in commit messages**
- **Test each change before moving to next comment**
- **Keep reviewer's context in mind**
- **Be respectful in responses**

### Communication Template

```markdown
@reviewer Thank you for the review! I've addressed your comment as follows:

**Change Made:**
[Description of what was changed]

**Rationale:**
[Why this approach was taken]

**Testing:**
[How it was tested]

Please let me know if this addresses your concern or if you'd like a different approach.
```

### Error Handling

- If a suggested fix causes test failures, document and propose alternative
- If unclear about a comment, ask for clarification before proceeding
- If a fix is too complex, break it down into smaller commits

## Important Notes

- **Always get user approval before making changes**
- **Each loop iteration handles one comment or a group of related comments**
- **Maintain traceability between comments and commits**
- **Use Japanese for user interactions, English for code and commits**
- **Don't mark comments as resolved until changes are verified**
- **Consider the impact of each change on the overall codebase**
- **Group related fixes when appropriate but keep commits atomic**
