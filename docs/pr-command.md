# @pr Command - AI-Assisted Pull Request Review

The `@pr` command enables AI-assisted Pull Request review in Avante.nvim. When invoked, it automatically gathers PR context and changes, then provides them to the AI for comprehensive analysis.

## Prerequisites

1. **GitHub CLI (gh)**: Must be installed and authenticated
   ```bash
   # Install GitHub CLI (example for Ubuntu/Debian)
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update && sudo apt install gh
   
   # Authenticate with GitHub
   gh auth login
   ```

2. **Git repository**: Must be working in a Git repository
3. **Active Pull Request**: Current branch must have an associated Pull Request

## Usage

### Basic Usage
```vim
:AvantePR
```

This will:
1. Identify the PR associated with your current branch
2. Fetch PR metadata (title, description, author, labels)
3. Get the complete diff using `gh pr diff`
4. Construct a comprehensive system prompt
5. Open Avante with the PR context for AI review

### With Specific Instructions
```vim
:AvantePR look for potential security issues
:AvantePR summarize the changes and check for performance impacts
:AvantePR review the test coverage
```

## What the AI Receives

The AI gets a structured prompt containing:

1. **PR Information**:
   - Title and description
   - Author information
   - PR number and URL
   - Labels (if any)

2. **Complete Code Changes**:
   - Full diff output from `gh pr diff`
   - All modified files and their changes

3. **Review Guidelines**:
   - Code quality and best practices
   - Potential bugs or security issues
   - Performance considerations
   - Maintainability and readability
   - Test coverage and edge cases
   - Documentation and comments

4. **User's Specific Request** (if provided):
   - Custom instructions or focus areas

## Example Output

When you run `:AvantePR`, the AI receives a prompt like:

```
# AI-Assisted Pull Request Review

You are an expert code reviewer conducting a comprehensive review of a GitHub Pull Request.
Your task is to analyze the provided PR information and code changes to provide insightful,
professional, and actionable feedback.

## Pull Request Information

**Title:** Add user authentication feature
**Author:** username
**PR Number:** #123
**URL:** https://github.com/owner/repo/pull/123

**Description:**
This PR adds JWT-based authentication to the application...

## Code Changes

```diff
diff --git a/src/auth.js b/src/auth.js
new file mode 100644
index 0000000..1234567
+++ b/src/auth.js
@@ -0,0 +1,50 @@
+const jwt = require('jsonwebtoken');
...
```

## Review Guidelines

Please provide a thorough review focusing on:
- Code quality and best practices
- Potential bugs or security issues
- Performance considerations
- Maintainability and readability
- Test coverage and edge cases
- Documentation and comments

## Default Request

Please provide a comprehensive code review of this Pull Request.
```

## Error Handling

The command will provide helpful error messages for common issues:

- **GitHub CLI not installed**: "GitHub CLI (gh) is not installed or not in PATH"
- **Not authenticated**: "GitHub CLI is not authenticated. Please run 'gh auth login'"
- **Not in Git repo**: "Not in a Git repository"
- **No PR found**: "No PR found for current branch 'branch-name'"
- **No diff available**: "Failed to get PR diff"

## Tips

1. **Work from feature branches**: The command works best when you're on a feature branch with an associated PR
2. **Keep PRs focused**: Smaller, focused PRs will get better AI reviews
3. **Use specific instructions**: Provide specific areas of focus for more targeted reviews
4. **Multiple reviews**: You can run the command multiple times with different instructions

## Integration with Avante

The `AvantePR` command integrates seamlessly with Avante's existing functionality:
- Loads PR context for use with `@pr` mentions
- Supports all of Avante's AI providers
- Can be combined with other Avante features like file selection

## @pr Chat Mention

After loading a PR using the `AvantePR` command, you can reference the PR context in subsequent chat messages using the `@pr` mention:

### Usage Examples

```
Summarize @pr
What are the changed files in @pr?
@codebase @pr How does this PR impact the overall architecture?
Are there any potential security issues in @pr?
```

### Features

- **Context Persistence**: PR context remains loaded across multiple chat interactions
- **Automatic Stripping**: The `@pr` mention is automatically removed from your query and replaced with PR context
- **Error Handling**: If you use `@pr` without loading a PR first, you'll get a helpful error message to run `AvantePR` command first

### Manual Context Setting

For testing or advanced usage, you can manually set PR context:

```lua
require("avante.pr_context_manager").set_active_pr_details({
  number = 123,
  title = "Your PR Title",
  body = "PR description",
  changed_files = {{ path = "file.lua" }}
})
```

### Clear Context

To clear the current PR context:

```lua
require("avante.pr_context_manager").set_active_pr_details(nil)
```