## Git Workflow

- Name branches descriptively with a type prefix, such as `feat/add-user-auth` or `fix/resolve-login-bug`.
- Stage only files that belong to the change. Use `git commit -am` only when every modified file belongs in the commit.
- Push a new branch with `git push -u origin <branch-name>`.
- Use `git rebase -i` or `git push --force` only when the user explicitly asks for it.
- Do not modify `.gitconfig` or `.git/config` unless the task is to set them up.
- Create pull requests with `gh pr create`.
