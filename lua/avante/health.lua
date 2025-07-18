local M = {}
local H = require("vim.health")
local Utils = require("avante.utils")
local Config = require("avante.config")

function M.check()
  H.start("avante.nvim")

  -- Required dependencies with their module names
  local required_plugins = {
    ["nvim-treesitter"] = {
      path = "nvim-treesitter/nvim-treesitter",
      module = "nvim-treesitter",
    },
    ["plenary.nvim"] = {
      path = "nvim-lua/plenary.nvim",
      module = "plenary",
    },
    ["nui.nvim"] = {
      path = "MunifTanjim/nui.nvim",
      module = "nui.popup",
    },
  }

  for name, plugin in pairs(required_plugins) do
    if Utils.has(name) or Utils.has(plugin.module) then
      H.ok(string.format("Found required plugin: %s", plugin.path))
    else
      H.error(string.format("Missing required plugin: %s", plugin.path))
    end
  end

  -- Optional dependencies
  if Utils.icons_enabled() then
    H.ok("Found icons plugin (nvim-web-devicons or mini.icons)")
  else
    H.warn("No icons plugin found (nvim-web-devicons or mini.icons). Icons will not be displayed")
  end

  -- Check input UI provider
  local input_provider = Config.input and Config.input.provider or "native"
  if input_provider == "dressing" then
    if Utils.has("dressing.nvim") or Utils.has("dressing") then
      H.ok("Found configured input provider: dressing.nvim")
    else
      H.error("Input provider is set to 'dressing' but dressing.nvim is not installed")
    end
  elseif input_provider == "snacks" then
    if Utils.has("snacks.nvim") or Utils.has("snacks") then
      H.ok("Found configured input provider: snacks.nvim")
    else
      H.error("Input provider is set to 'snacks' but snacks.nvim is not installed")
    end
  else
    H.ok("Using native input provider (no additional dependencies required)")
  end

  -- Check Copilot if configured
  if Config.provider and Config.provider == "copilot" then
    if Utils.has("copilot.lua") or Utils.has("copilot.vim") or Utils.has("copilot") then
      H.ok("Found Copilot plugin")
    else
      H.error("Copilot provider is configured but neither copilot.lua nor copilot.vim is installed")
    end
  end

  -- Check PR extension dependencies
  M.check_pr_extension()

  -- Check TreeSitter dependencies
  M.check_treesitter()
end

-- Check PR extension dependencies
function M.check_pr_extension()
  H.start("PR Extension Dependencies")
  
  local pr_ext_ok, pr_ext = pcall(require, "avante.extensions.pr")
  if not pr_ext_ok then
    H.error("PR extension module not available")
    return
  end
  
  if not pr_ext.is_available then
    H.error("PR extension is_available function not found")
    return
  end
  
  local available, error_msg = pr_ext.is_available()
  if available then
    H.ok("PR extension is available (Octo plugin and gh CLI found)")
  else
    H.warn("PR extension is not available: " .. error_msg)
    H.info("The :AvantePR command will not be registered")
    H.info("Install missing dependencies to enable PR review functionality")
  end
end

-- Check TreeSitter functionality and parsers
function M.check_treesitter()
  H.start("TreeSitter Dependencies")

  -- Check if TreeSitter is available
  local has_ts, _ = pcall(require, "nvim-treesitter.configs")
  if not has_ts then
    H.error("TreeSitter not available. Make sure nvim-treesitter is properly installed")
    return
  end

  H.ok("TreeSitter core functionality is available")

  -- Check for essential parsers
  local has_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
  if not has_parsers then
    H.error("TreeSitter parsers module not available")
    return
  end

  -- List of important parsers for avante.nvim
  local essential_parsers = {
    "markdown",
  }

  local missing_parsers = {}

  for _, parser in ipairs(essential_parsers) do
    if parsers.has_parser and not parsers.has_parser(parser) then table.insert(missing_parsers, parser) end
  end

  if #missing_parsers == 0 then
    H.ok("All essential TreeSitter parsers are installed")
  else
    H.warn(
      string.format(
        "Missing recommended parsers: %s. Install with :TSInstall %s",
        table.concat(missing_parsers, ", "),
        table.concat(missing_parsers, " ")
      )
    )
  end

  -- Check TreeSitter highlight
  local _, highlighter = pcall(require, "vim.treesitter.highlighter")
  if not highlighter then
    H.warn("TreeSitter highlighter not available. Syntax highlighting might be limited")
  else
    H.ok("TreeSitter highlighter is available")
  end
end

return M
