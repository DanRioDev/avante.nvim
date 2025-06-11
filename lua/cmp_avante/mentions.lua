local api = vim.api

---@class mentions_source : cmp.Source
---@field get_mentions fun(): AvanteMention[]
local MentionsSource = {}
MentionsSource.__index = MentionsSource

---@param get_mentions fun(): AvanteMention[]
function MentionsSource:new(get_mentions)
  local instance = setmetatable({}, MentionsSource)

  instance.get_mentions = get_mentions

  return instance
end

function MentionsSource:is_available()
  return vim.bo.filetype == "AvanteInput" or vim.bo.filetype == "AvantePromptInput"
end

function MentionsSource.get_position_encoding_kind() return "utf-8" end

function MentionsSource:get_trigger_characters() return { "@" } end

function MentionsSource:get_keyword_pattern() return [[\%(@\|#\|/\)\k*]] end

function MentionsSource:complete(_, callback)
  local kind = require("cmp").lsp.CompletionItemKind.Variable

  local items = {}

  local mentions = self.get_mentions()
  vim.notify("MentionsSource:complete - Retrieved " .. #mentions .. " mentions", vim.log.levels.INFO, {title = "Avante Debug"})

  for _, mention in ipairs(mentions) do
    local item = {
      label = "@" .. mention.command .. " ",
      kind = kind,
      detail = mention.details,
    }
    table.insert(items, item)
    vim.notify("MentionsSource:complete - Added mention: " .. item.label, vim.log.levels.INFO, {title = "Avante Debug"})
  end

  vim.notify("MentionsSource:complete - Returning " .. #items .. " completion items", vim.log.levels.INFO, {title = "Avante Debug"})
  callback({
    items = items,
    isIncomplete = false,
  })
end

---@param completion_item table
---@param callback fun(response: {behavior: number})
function MentionsSource:execute(completion_item, callback)
  local current_line = api.nvim_get_current_line()
  local label = completion_item.label:match("^@(%S+)") -- Extract mention command without '@' and space

  vim.notify("MentionsSource:execute - Processing completion item", vim.log.levels.INFO, {title = "Avante Debug"})
  vim.notify("MentionsSource:execute - Current line: " .. current_line, vim.log.levels.INFO, {title = "Avante Debug"})
  vim.notify("MentionsSource:execute - Extracted label: " .. (label or "nil"), vim.log.levels.INFO, {title = "Avante Debug"})
  vim.notify("MentionsSource:execute - Completion item label: " .. (completion_item.label or "nil"), vim.log.levels.INFO, {title = "Avante Debug"})

  local mentions = self.get_mentions()
  vim.notify("MentionsSource:execute - Found " .. #mentions .. " available mentions", vim.log.levels.INFO, {title = "Avante Debug"})

  -- Find the corresponding mention
  local selected_mention
  for _, mention in ipairs(mentions) do
    if mention.command == label then
      selected_mention = mention
      vim.notify("MentionsSource:execute - Found matching mention: " .. mention.command, vim.log.levels.INFO, {title = "Avante Debug"})
      break
    end
  end

  if not selected_mention then
    vim.notify("MentionsSource:execute - No matching mention found for: " .. (label or "nil"), vim.log.levels.WARN, {title = "Avante Debug"})
  end

  local sidebar = require("avante").get()
  vim.notify("MentionsSource:execute - Sidebar obtained: " .. (sidebar and "success" or "failed"), vim.log.levels.INFO, {title = "Avante Debug"})

  -- Execute the mention's callback if it exists
  if selected_mention and type(selected_mention.callback) == "function" then
    vim.notify("MentionsSource:execute - Executing callback for: " .. selected_mention.command, vim.log.levels.INFO, {title = "Avante Debug"})
    selected_mention.callback(sidebar)
    vim.notify("MentionsSource:execute - Callback executed for: " .. selected_mention.command, vim.log.levels.INFO, {title = "Avante Debug"})
    
    -- Get the current cursor position
    local row, col = unpack(api.nvim_win_get_cursor(0))

    -- Replace the current line with the new line (removing the mention)
    local new_line = current_line:gsub(vim.pesc(completion_item.label), "")
    api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })

    -- Adjust the cursor position if needed
    local new_col = math.min(col, #new_line)
    api.nvim_win_set_cursor(0, { row, new_col })
    
    vim.notify("MentionsSource:execute - Line updated and cursor repositioned", vim.log.levels.INFO, {title = "Avante Debug"})
  else
    if selected_mention then
      vim.notify("MentionsSource:execute - Selected mention has no callback function", vim.log.levels.WARN, {title = "Avante Debug"})
    end
  end

  callback({ behavior = require("cmp").ConfirmBehavior.Insert })
  vim.notify("MentionsSource:execute - Execution completed", vim.log.levels.INFO, {title = "Avante Debug"})
end

return MentionsSource
