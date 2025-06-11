-- Module to manage the currently active PR context

local M = {}

---@class AvantePRFile
---@field path string Relative path of the changed file.
---@field diff_summary string? A short summary of changes or the diff hunk.

---@class AvantePRDetails
---@field number number|string The PR number or identifier.
---@field title string The title of the PR.
---@field author string? The author of the PR.
---@field body string? The body/description of the PR.
---@field url string? URL to the PR.
---@field base_ref string? Base branch of the PR.
---@field head_ref string? Head branch of the PR.
---@field changed_files AvantePRFile[]? List of changed files with summaries/diffs.
---@field raw_diff string? The full raw diff of the PR.
---@field loaded_at string Timestamp when the PR was loaded.

---@type AvantePRDetails | nil
local current_pr_details = nil

--- Sets the PR details, typically called by AvantePR command.
---@param pr_data AvantePRDetails|nil The structured PR data.
function M.set_active_pr_details(pr_data)
  if pr_data then
    pr_data.loaded_at = os.date("!%Y-%m-%dT%H:%M:%SZ") -- UTC timestamp
    current_pr_details = pr_data
    vim.notify("Avante: PR #" .. (pr_data.number or "N/A") .. " context loaded. Title: " .. pr_data.title, vim.log.levels.INFO, { title = "Avante PR Context" })
  else
    current_pr_details = nil
    vim.notify("Avante: PR context cleared.", vim.log.levels.INFO, { title = "Avante PR Context" })
  end
end

--- Gets the currently active PR details.
---@return AvantePRDetails|nil The stored PR data, or nil if none is active.
function M.get_active_pr_details()
  return current_pr_details
end

return M