---
description: Generate a concise commit message based on current git changes
---

Analyze the current git status and diff, then generate a concise commit message following these rules:

1. Run `git status` and `git diff --cached` (or `git diff` if nothing is staged)
2. Analyze the changes to understand what was modified
3. Generate a commit message that:
   - Is a single line (no multi-line messages)
   - Uses imperative mood (e.g., "Add feature" not "Added feature")
   - Is specific but concise (aim for under 72 characters)
   - Focuses on the "what" and "why", not the "how"
   - Follows the existing commit style in `git log --oneline -10`

4. Present the suggested commit message in a code block for easy copying
5. Do NOT create the commit - only suggest the message

If there are no changes to commit, inform the user.
