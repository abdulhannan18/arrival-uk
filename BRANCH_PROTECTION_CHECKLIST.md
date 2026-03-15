# Branch Protection Checklist

Apply these settings to `main` in GitHub repository settings.

- Require a pull request before merging
- Require approvals: minimum `1`
- Dismiss stale approvals when new commits are pushed
- Require review from Code Owners (if CODEOWNERS is configured)
- Require status checks to pass before merging:
  - `Backend Lint + Build`
  - `iOS Validate + Build`
  - `Analyze backend/functions` (CodeQL)
- Require branches to be up to date before merging
- Restrict who can push to matching branches (or disable direct pushes)
- Disallow force pushes
- Disallow branch deletion
- Enable conversation resolution before merging

## Verify via CLI

```bash
gh api \
  repos/<owner>/<repo>/branches/main/protection
```

The API response should show required pull request reviews, required status checks, and disabled force-push/deletion.
