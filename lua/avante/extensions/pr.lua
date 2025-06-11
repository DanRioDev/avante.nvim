---@class avante.extensions.pr
local M = {}

local Utils = require("avante.utils")

---Check if PR extension should be available (dependencies check)
---@return boolean, string?
function M.is_available()
  -- Check if gh CLI is available
  if vim.fn.executable("gh") == 0 then
    return false, "GitHub CLI (gh) is not installed or not in PATH. Please install it from https://cli.github.com/"
  end

  return true, nil
end

---Check if required dependencies are available
---@return boolean, string?
local function check_dependencies()
  -- Check if gh CLI is available
  if vim.fn.executable("gh") == 0 then
    return false, "GitHub CLI (gh) is not installed or not in PATH. Please install it from https://cli.github.com/"
  end

  -- Check if we're in a git repository
  local git_output = vim.fn.system("git rev-parse --git-dir 2>/dev/null")
  if vim.v.shell_error ~= 0 then return false, "Not in a Git repository" end

  -- Check if gh is authenticated
  local auth_output = vim.fn.system("gh auth status 2>/dev/null")
  if vim.v.shell_error ~= 0 then return false, "GitHub CLI is not authenticated. Please run 'gh auth login'" end

  return true, nil
end

---Get current Git branch name
---@return string?, string?
local function get_current_branch()
  local output = vim.fn.system("git branch --show-current"):gsub("\n", "")
  if vim.v.shell_error ~= 0 then return nil, "Failed to get current branch: " .. output end
  return output, nil
end

---Get PR information using gh CLI
---@param branch string
---@return table?, string?
local function get_pr_info(branch)
  -- Try to get PR info for the current branch using gh CLI
  -- This approach doesn't actually require octo.nvim to be loaded
  local cmd = string.format(
    "gh pr view --json title,body,number,author,labels,url 2>/dev/null || gh pr view --json title,body,number,author,labels,url %s",
    branch
  )
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    -- Try alternative approach - check if we're on a branch that has a PR
    cmd = string.format("gh pr list --head %s --json title,body,number,author,labels,url --limit 1", branch)
    output = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
      return nil,
        "No PR found for current branch '" .. branch .. "'. Make sure you're on a branch with an associated PR."
    end

    -- Parse as array and get first element
    local ok_decode, pr_list = pcall(vim.fn.json_decode, output)
    if not ok_decode or not pr_list or #pr_list == 0 then
      return nil, "No PR found for current branch '" .. branch .. "'"
    end

    return pr_list[1], nil
  end

  local ok_decode, pr_data = pcall(vim.fn.json_decode, output)
  if not ok_decode then return nil, "Failed to parse PR JSON data" end

  -- Validate PR data
  if not pr_data or not pr_data.number then return nil, "Invalid PR data received" end

  return pr_data, nil
end

---Get PR diff using gh CLI
---@param pr_number string|number
---@return string?, string?
local function get_pr_diff(pr_number)
  local cmd = string.format("gh pr diff %s", pr_number)
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then return nil, "Failed to get PR diff: " .. output end

  if output == "" or output:match("^%s*$") then
    return nil, "PR diff is empty. This might happen if the PR has no changes or has been merged."
  end

  return output, nil
end

---Construct comprehensive system prompt for PR review
---@param pr_data table PR information from octo/gh
---@param diff_content string PR diff content
---@param user_input? string Optional user input following @pr
---@return string
local function construct_system_prompt(pr_data, diff_content, user_input)
  local prompt_parts = {
    "# AI-Assisted Pull Request Review",
    "",
    "You are a domain expert in this diff's subject, your goal is to analyze and conduct a comprehensive review of a GitHub Pull Request.",
    "You should analyze the provided PR information and code changes to provide insightful,",
    "professional expert, and actionable feedback. Address them as friendly and constructive.",
    "",
    "## Pull Request Information",
    "",
    string.format("**Title:** %s", pr_data.title or "N/A"),
    string.format("**Author:** %s", (pr_data.author and pr_data.author.login) or "N/A"),
    string.format("**PR Number:** #%s", pr_data.number or "N/A"),
  }

  if pr_data.url then table.insert(prompt_parts, string.format("**URL:** %s", pr_data.url)) end

  table.insert(prompt_parts, "")

  -- Add description if available
  if pr_data.body and pr_data.body ~= "" and pr_data.body ~= vim.NIL then
    table.insert(prompt_parts, "**Description:**")
    table.insert(prompt_parts, pr_data.body)
    table.insert(prompt_parts, "")
  end

  -- Add labels if available
  if pr_data.labels and #pr_data.labels > 0 then
    local label_names = {}
    for _, label in ipairs(pr_data.labels) do
      if label.name then table.insert(label_names, label.name) end
    end
    if #label_names > 0 then
      table.insert(prompt_parts, string.format("**Labels:** %s", table.concat(label_names, ", ")))
      table.insert(prompt_parts, "")
    end
  end

  -- Add the diff content
  table.insert(prompt_parts, "## Code Changes")
  table.insert(prompt_parts, "")
  table.insert(prompt_parts, "```diff")
  table.insert(prompt_parts, diff_content)
  table.insert(prompt_parts, "```")
  table.insert(prompt_parts, "")

  -- Add review guidelines
  table.insert(prompt_parts, "## Code Review Guidelines")
  table.insert(prompt_parts, "")
  table.insert(
    prompt_parts,
    "To ensure our reviews are efficient, effective, and collaborative, please follow these guidelines."
  )
  table.insert(prompt_parts, "")

  table.insert(prompt_parts, "### Providing Feedback")
  table.insert(
    prompt_parts,
    "- **Be Kind and Constructive:** Comment on the code, not the author. Assume good intentions."
  )
  table.insert(prompt_parts, "- **Keep it Small:** Submit small, focused changes. A review of 200-400 lines is ideal.")
  table.insert(
    prompt_parts,
    "- **Write a Clear Description:** Explain the **why** behind your review, not just the **what**. Provide context."
  )
  table.insert(
    prompt_parts,
    "- **Prioritize Feedback:** Focus on major issues (design, architecture) before minor ones (style nits)."
  )
  table.insert(
    prompt_parts,
    "- **Distinguish Suggestions:** Clearly label suggestions or optional improvements (e.g., prefix with `Nit:` or `Suggestion:`)."
  )
  table.insert(
    prompt_parts,
    "- **Offer Solutions:** When you spot an issue, try to suggest a better approach or ask a clarifying question."
  )
  table.insert(prompt_parts, "")

  table.insert(prompt_parts, "### The Checklist: What to Look For")
  table.insert(
    prompt_parts,
    "- **Design & Architecture:** Does this solve the problem correctly? Does it fit our existing architecture or introduce unneeded complexity?"
  )
  table.insert(
    prompt_parts,
    "- **Functionality & Correctness:** Does the code do what it claims to do? Does it handle all requirements?"
  )
  table.insert(
    prompt_parts,
    "- **Readability & Maintainability:** Is the code clear and easy for a new team member to understand? Are names descriptive and self-explanatory?"
  )
  table.insert(
    prompt_parts,
    "- **Error Handling & Observability:** Does the code handle failures gracefully? Is there sufficient logging to debug issues in production?"
  )
  table.insert(
    prompt_parts,
    "- **Test Coverage:** Are the tests thorough? Do they cover happy paths, failures, and relevant edge cases?"
  )
  table.insert(
    prompt_parts,
    "- **Performance:** Are there obvious performance bottlenecks (e.g., N+1 queries, loops over large datasets)? Flag clear issues, don't prematurely optimize."
  )
  table.insert(
    prompt_parts,
    "- **Security:** Does this change introduce any vulnerabilities (e.g., injection, data exposure, insecure auth)?"
  )
  table.insert(
    prompt_parts,
    "- **Consistency & Documentation:** Does the code follow project conventions and style guides? Are complex parts commented and relevant docs updated?"
  )
  table.insert(prompt_parts, "")

  -- Add user input if provided
  if user_input and user_input ~= "" then
    table.insert(prompt_parts, "## Specific Request")
    table.insert(prompt_parts, "")
    table.insert(prompt_parts, "The user has specifically requested:")
    table.insert(prompt_parts, user_input)
    table.insert(prompt_parts, "")
  else
    table.insert(prompt_parts, "## Default Request")
    table.insert(prompt_parts, "")
    table.insert(prompt_parts, "Please provide a comprehensive code review of this Pull Request.")
    table.insert(prompt_parts, "")
  end

  return table.concat(prompt_parts, "\n")
end

---Main function to handle PR review
---@param user_input? string Optional user input following @pr command
---@param callback function Callback function to handle the result
function M.review_pr(user_input, callback)
  -- Check dependencies
  local deps_ok, deps_err = check_dependencies()
  if not deps_ok then
    callback(false, deps_err)
    return
  end

  -- Get current branch
  local branch, branch_err = get_current_branch()
  if not branch then
    callback(false, branch_err)
    return
  end

  -- Get PR information
  local pr_data, pr_err = get_pr_info(branch)
  if not pr_data then
    callback(false, pr_err)
    return
  end

  -- Get PR diff
  local diff_content, diff_err = get_pr_diff(pr_data.number)
  if not diff_content then
    callback(false, diff_err)
    return
  end

  -- Construct system prompt
  local system_prompt = construct_system_prompt(pr_data, diff_content, user_input)

  callback(true, system_prompt)
end

return M

