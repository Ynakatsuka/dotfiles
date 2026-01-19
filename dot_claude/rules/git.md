## GitHub

- Use the `gh` command-line tool for **all** GitHub operations: cloning, branching, committing, creating pull requests, etc.
- Follow standard conventional commit message guidelines (see Git Workflow section). Branch names should be descriptive (e.g., `feat/add-user-auth`, `fix/resolve-login-bug`).
- Keep local and remote repositories synchronized frequently.

## Git Workflow

### General Principles

- Never commit automatically without explicit user approval.
- Commit **only** relevant files related to the change. Avoid committing unrelated files, IDE configuration, or empty commits.
- Use `git commit -am` (stage and commit in one step) **only** when you are certain **all** modified files should be included in the commit. Be cautious.
- **Always** use the `-u` flag when pushing a new branch (`git push -u origin <branch-name>`).
- **Do not** use interactive rebase (`git rebase -i`) or force push (`git push --force`) unless explicitly instructed and fully understanding the consequences.
- **Do not** alter global or local Git configuration files (`.gitconfig`, `.git/config`) unless specifically required for a setup task.

### Committing Changes

1.  **Inspect changes thoroughly before committing:**
    ```bash
    git status
    git diff # Review unstaged changes
    git diff --staged # Review staged changes
    git log --oneline --graph # Review recent history
    ```
2.  **Analyze changes:**
    - Identify modified or added files.
    - Understand the nature of the change (feature, bug fix, refactor, etc.).
    - Evaluate the impact on the project.
    - **Crucially:** Check for any accidentally included sensitive information or credentials.
3.  **Write clear, concise, and informative commit messages in English.**
    - **The commit message title MUST follow the Conventional Commits format.**
    - Examples:
        ```markdown
        - feat: Introduce Result type for robust error handling
        - update: Improve caching performance by using Redis
        - fix: Correct handling of expired authentication tokens
        - refactor: Abstract external API dependencies using Adapter pattern
        - test: Add comprehensive unit tests for Result type error cases
        - docs: Update README with error handling best practices
        ```

### Creating Pull Requests

1.  **Before creating a PR, check the status of your branch:**
    ```bash
    git status
    git log main..HEAD # See commits unique to your branch
    git diff main...HEAD # See cumulative changes compared to main
    ```
2.  **Analyze the commits** and their overall impact. Ensure commits are logical and atomic.
3.  **Create the pull request** using the `gh pr create` command.
