---@class avante.extensions.pr
local M = {}

local Utils = require("avante.utils")

---Check if PR extension should be available (dependencies check)
---@return boolean, string?
function M.is_available()
  -- Check if Octo plugin is available
  local octo_ok, _ = pcall(require, 'octo')
  if not octo_ok then
    return false, "Octo plugin is not installed. Please install it from https://github.com/pwntester/octo.nvim"
  end
  
  -- Check if gh CLI is available
  if vim.fn.executable("gh") == 0 then
    return false, "GitHub CLI (gh) is not installed or not in PATH. Please install it from https://cli.github.com/"
  end
  
  return true, nil
end

---Check if required dependencies are available
---@return boolean, string?
local function check_dependencies()
  -- Check if Octo plugin is available
  local octo_ok, _ = pcall(require, 'octo')
  if not octo_ok then
    return false, "Octo plugin is not installed. Please install it from https://github.com/pwntester/octo.nvim"
  end
  
  -- Check if gh CLI is available
  if vim.fn.executable("gh") == 0 then
    return false, "GitHub CLI (gh) is not installed or not in PATH. Please install it from https://cli.github.com/"
  end
  
  -- Check if we're in a git repository
  local git_output = vim.fn.system("git rev-parse --git-dir 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return false, "Not in a Git repository"
  end
  
  -- Check if gh is authenticated
  local auth_output = vim.fn.system("gh auth status 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return false, "GitHub CLI is not authenticated. Please run 'gh auth login'"
  end
  
  return true, nil
end

---Get current Git branch name
---@return string?, string?
local function get_current_branch()
  local output = vim.fn.system("git branch --show-current"):gsub("\n", "")
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to get current branch: " .. output
  end
  return output, nil
end

---Get PR information using gh CLI
---@param branch string
---@return table?, string?
local function get_pr_info(branch)
  -- Try to get PR info for the current branch using gh CLI
  -- This approach doesn't actually require octo.nvim to be loaded
  local cmd = string.format("gh pr view --json title,body,number,author,labels,url 2>/dev/null || gh pr view --json title,body,number,author,labels,url %s", branch)
  local output = vim.fn.system(cmd)
  
  if vim.v.shell_error ~= 0 then
    -- Try alternative approach - check if we're on a branch that has a PR
    cmd = string.format("gh pr list --head %s --json title,body,number,author,labels,url --limit 1", branch)
    output = vim.fn.system(cmd)
    
    if vim.v.shell_error ~= 0 then
      return nil, "No PR found for current branch '" .. branch .. "'. Make sure you're on a branch with an associated PR."
    end
    
    -- Parse as array and get first element
    local ok_decode, pr_list = pcall(vim.fn.json_decode, output)
    if not ok_decode or not pr_list or #pr_list == 0 then
      return nil, "No PR found for current branch '" .. branch .. "'"
    end
    
    return pr_list[1], nil
  end
  
  local ok_decode, pr_data = pcall(vim.fn.json_decode, output)
  if not ok_decode then
    return nil, "Failed to parse PR JSON data"
  end
  
  -- Validate PR data
  if not pr_data or not pr_data.number then
    return nil, "Invalid PR data received"
  end
  
  return pr_data, nil
end

---Get PR diff using gh CLI
---@param pr_number string|number
---@return string?, string?
local function get_pr_diff(pr_number)
  local cmd = string.format("gh pr diff %s", pr_number)
  local output = vim.fn.system(cmd)
  
  if vim.v.shell_error ~= 0 then
    return nil, "Failed to get PR diff: " .. output
  end
  
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
    "You are an expert code reviewer conducting a comprehensive review of a GitHub Pull Request.",
    "Your task is to analyze the provided PR information and code changes to provide insightful,",
    "professional, and actionable feedback.",
    "",
    "## Pull Request Information",
    "",
    string.format("**Title:** %s", pr_data.title or "N/A"),
    string.format("**Author:** %s", (pr_data.author and pr_data.author.login) or "N/A"),
    string.format("**PR Number:** #%s", pr_data.number or "N/A"),
  }
  
  if pr_data.url then
    table.insert(prompt_parts, string.format("**URL:** %s", pr_data.url))
  end
  
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
      if label.name then
        table.insert(label_names, label.name)
      end
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
  table.insert(prompt_parts, "## Review Guidelines")
  table.insert(prompt_parts, "")
  table.insert(prompt_parts, "Please provide a thorough review focusing on:")
  table.insert(prompt_parts, "- Code quality and best practices")
  table.insert(prompt_parts, "- Potential bugs or security issues")
  table.insert(prompt_parts, "- Performance considerations")
  table.insert(prompt_parts, "- Maintainability and readability")
  table.insert(prompt_parts, "- Test coverage and edge cases")
  table.insert(prompt_parts, "- Documentation and comments")
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

---Get PR context data for @pr mentions
---@param callback function Callback function to handle the result (success: boolean, data: table|string)
function M.get_pr_context(callback)
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
  
  -- Return structured PR context
  local pr_context = {
    number = pr_data.number,
    title = pr_data.title,
    author = pr_data.author and pr_data.author.login,
    body = pr_data.body,
    url = pr_data.url,
    base_ref = pr_data.base and pr_data.base.ref,
    head_ref = pr_data.head and pr_data.head.ref,
    raw_diff = diff_content,
  }
  
  callback(true, pr_context)
end

---Build PR context for chat usage from cached PR details
---@param pr_details AvantePRDetails The cached PR details
---@param user_input? string Optional user input (after @pr removal)
---@return table PR context suitable for chat usage
function M.build_pr_context_for_chat(pr_details, user_input)
  if not pr_details then
    return nil
  end
  
  -- Handle empty or whitespace-only user input by using default review prompt
  local processed_user_input = user_input and user_input:match("^%s*(.-)%s*$") or ""
  local has_user_request = processed_user_input ~= ""
  
  -- Create a context structure similar to what get_pr_context returns
  -- but optimized for chat usage rather than full system prompts
  local context = {
    number = pr_details.number,
    title = pr_details.title,
    author = pr_details.author,
    body = pr_details.body,
    url = pr_details.url,
    base_ref = pr_details.base_ref,
    head_ref = pr_details.head_ref,
    raw_diff = pr_details.raw_diff,
    user_request = has_user_request and processed_user_input or nil,
    default_review = not has_user_request, -- Flag to indicate default review should be used
  }
  
  return context
end

---Main function to handle PR review
---@param user_input? string Optional user input following @pr command
---@param callback function Callback function to handle the result
function M.review_pr(user_input, callback)
  M.get_pr_context(function(success, result)
    if not success then
      callback(false, result)
      return
    end
    
    -- Store PR context for backward compatibility
    local PRContextManager = require("avante.pr_context_manager")
    PRContextManager.set_active_pr_details(result)
    
    -- Construct system prompt
    local system_prompt = construct_system_prompt({
      number = result.number,
      title = result.title,
      author = { login = result.author },
      body = result.body,
      url = result.url,
      base = { ref = result.base_ref },
      head = { ref = result.head_ref },
    }, result.raw_diff, user_input)
    
    callback(true, system_prompt)
  end)
end

return M