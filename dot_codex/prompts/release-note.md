## Your task

Based on the above changes, create a release note following these steps:

### 1. Determine Version Number

- Previous release: Check from the context above
- New version: Increment patch version (v2.4.X → v2.4.X+1)

### 2. Categorize Changes

Analyze commits and categorize them into:

### 3. Create Release Note

Use this template with commit links:

```markdown
## XXX
- feat: [features]

**Full Changelog**: https://github.com/XXX/XXX/compare/vX.X.X...vY.Y.Y
```

### 4. Create GitHub Release

```bash
gh release create vX.X.X --title "vX.X.X" --notes "[Release note content]"
```

## Important Notes

- **Always include commit links** for traceability
- Each feature/fix should link to actual commits: `([hash](https://github.com/Ynakatsuka/horse-racing-predictor/commit/full_hash))`
- Multiple related commits: `([hash1](link1), [hash2](link2))`
- Use **Japanese** for release note descriptions
- Maintain consistency in formatting across releases
- Check that all significant changes are included before creating the release

