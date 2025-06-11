local Utils = require("avante.utils")

describe("Utils", function()
  describe("trim", function()
    it("should trim prefix", function() assert.equals("test", Utils.trim("prefix_test", { prefix = "prefix_" })) end)

    it("should trim suffix", function() assert.equals("test", Utils.trim("test_suffix", { suffix = "_suffix" })) end)

    it(
      "should trim both prefix and suffix",
      function() assert.equals("test", Utils.trim("prefix_test_suffix", { prefix = "prefix_", suffix = "_suffix" })) end
    )

    it(
      "should return original string if no match",
      function() assert.equals("test", Utils.trim("test", { prefix = "xxx", suffix = "yyy" })) end
    )
  end)

  describe("url_join", function()
    it("should join url parts correctly", function()
      assert.equals("http://example.com/path", Utils.url_join("http://example.com", "path"))
      assert.equals("http://example.com/path", Utils.url_join("http://example.com/", "/path"))
      assert.equals("http://example.com/path/to", Utils.url_join("http://example.com", "path", "to"))
      assert.equals("http://example.com/path", Utils.url_join("http://example.com/", "/path/"))
    end)

    it("should handle empty parts", function()
      assert.equals("http://example.com", Utils.url_join("http://example.com", ""))
      assert.equals("http://example.com", Utils.url_join("http://example.com", nil))
    end)
  end)

  describe("is_type", function()
    it("should check basic types correctly", function()
      assert.is_true(Utils.is_type("string", "test"))
      assert.is_true(Utils.is_type("number", 123))
      assert.is_true(Utils.is_type("boolean", true))
      assert.is_true(Utils.is_type("table", {}))
      assert.is_true(Utils.is_type("function", function() end))
      assert.is_true(Utils.is_type("nil", nil))
    end)

    it("should check list type correctly", function()
      assert.is_true(Utils.is_type("list", { 1, 2, 3 }))
      assert.is_false(Utils.is_type("list", { a = 1, b = 2 }))
    end)

    it("should check map type correctly", function()
      assert.is_true(Utils.is_type("map", { a = 1, b = 2 }))
      assert.is_false(Utils.is_type("map", { 1, 2, 3 }))
    end)
  end)

  describe("get_indentation", function()
    it("should get correct indentation", function()
      assert.equals("  ", Utils.get_indentation("  test"))
      assert.equals("\t", Utils.get_indentation("\ttest"))
      assert.equals("", Utils.get_indentation("test"))
    end)

    it("should handle empty or nil input", function()
      assert.equals("", Utils.get_indentation(""))
      assert.equals("", Utils.get_indentation(nil))
    end)
  end)

  describe("remove_indentation", function()
    it("should remove indentation correctly", function()
      assert.equals("test", Utils.remove_indentation("  test"))
      assert.equals("test", Utils.remove_indentation("\ttest"))
      assert.equals("test", Utils.remove_indentation("test"))
    end)

    it("should handle empty or nil input", function()
      assert.equals("", Utils.remove_indentation(""))
      assert.equals(nil, Utils.remove_indentation(nil))
    end)
  end)

  describe("is_first_letter_uppercase", function()
    it("should detect uppercase first letter", function()
      assert.is_true(Utils.is_first_letter_uppercase("Test"))
      assert.is_true(Utils.is_first_letter_uppercase("ABC"))
    end)

    it("should detect lowercase first letter", function()
      assert.is_false(Utils.is_first_letter_uppercase("test"))
      assert.is_false(Utils.is_first_letter_uppercase("abc"))
    end)
  end)

  describe("extract_mentions", function()
    it("should extract @codebase mention", function()
      local result = Utils.extract_mentions("test @codebase")
      assert.equals("test", result.new_content)
      assert.is_true(result.enable_project_context)
      assert.is_false(result.enable_diagnostics)
      assert.is_false(result.enable_pr_context)
    end)

    it("should extract @diagnostics mention", function()
      local result = Utils.extract_mentions("test @diagnostics")
      assert.equals("test @diagnostics", result.new_content)
      assert.is_false(result.enable_project_context)
      assert.is_true(result.enable_diagnostics)
      assert.is_false(result.enable_pr_context)
    end)

    it("should extract @pr mention", function()
      local result = Utils.extract_mentions("test @pr")
      assert.equals("test", result.new_content)
      assert.is_false(result.enable_project_context)
      assert.is_false(result.enable_diagnostics)
      assert.is_true(result.enable_pr_context)
    end)

    it("should handle multiple mentions", function()
      local result = Utils.extract_mentions("test @codebase @diagnostics")
      assert.equals("test @diagnostics", result.new_content)
      assert.is_true(result.enable_project_context)
      assert.is_true(result.enable_diagnostics)
      assert.is_false(result.enable_pr_context)
    end)

    it("should handle all three mentions", function()
      local result = Utils.extract_mentions("test @codebase @pr @diagnostics")
      assert.equals("test @diagnostics", result.new_content)
      assert.is_true(result.enable_project_context)
      assert.is_true(result.enable_diagnostics)
      assert.is_true(result.enable_pr_context)
    end)

    it("should clean up multiple spaces", function()
      local result = Utils.extract_mentions("test  @codebase   @pr  extra")
      assert.equals("test extra", result.new_content)
      assert.is_true(result.enable_project_context)
      assert.is_false(result.enable_diagnostics)
      assert.is_true(result.enable_pr_context)
    end)
  end)

  describe("get_mentions", function()
    it("should return valid mentions", function()
      local mentions = Utils.get_mentions()
      assert.equals("codebase", mentions[1].command)
      assert.equals("diagnostics", mentions[2].command)
      assert.equals("pr", mentions[3].command)
    end)
  end)
  
  describe("get_chat_mentions", function()
    it("should return chat mentions including pr_debug", function()
      local mentions = Utils.get_chat_mentions()
      
      -- Check that basic mentions are included
      local has_codebase, has_diagnostics, has_pr_debug = false, false, false
      for _, mention in ipairs(mentions) do
        if mention.command == "codebase" then has_codebase = true end
        if mention.command == "diagnostics" then has_diagnostics = true end
        if mention.command == "pr_debug" then has_pr_debug = true end
      end
      
      assert.is_true(has_codebase)
      assert.is_true(has_diagnostics)
      assert.is_true(has_pr_debug)
    end)
    
    it("should have pr_debug mention with correct properties", function()
      local mentions = Utils.get_chat_mentions()
      
      local pr_mention
      for _, mention in ipairs(mentions) do
        if mention.command == "pr_debug" then
          pr_mention = mention
          break
        end
      end
      
      assert.is_not_nil(pr_mention)
      assert.equals("pr_debug", pr_mention.command)
      assert.equals("pr_debug", pr_mention.description)
      assert.equals("AI-assisted Pull Request review", pr_mention.details)
      assert.is_function(pr_mention.callback)
    end)
    
    it("should have pr_debug callback with enhanced debugging", function()
      -- Mock vim.notify to capture debug messages
      local debug_messages = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level, opts)
        table.insert(debug_messages, {
          message = msg,
          level = level,
          title = opts and opts.title or nil
        })
      end
      
      -- Mock vim.api.nvim_get_current_line to simulate user input
      local original_get_line = vim.api.nvim_get_current_line
      vim.api.nvim_get_current_line = function()
        return "@pr_debug test user input"
      end
      
      -- Mock the avante.api module
      local original_require = _G.require
      _G.require = function(name)
        if name == "avante.api" then
          return {
            pr = function(input)
              -- Mock implementation that doesn't fail
              return true
            end
          }
        end
        return original_require(name)
      end
      
      local mentions = Utils.get_chat_mentions()
      local pr_mention
      for _, mention in ipairs(mentions) do
        if mention.command == "pr_debug" then
          pr_mention = mention
          break
        end
      end
      
      -- Execute the callback
      if pr_mention and pr_mention.callback then
        pr_mention.callback({ test = "mock_sidebar" })
      end
      
      -- Restore original functions
      vim.notify = original_notify
      vim.api.nvim_get_current_line = original_get_line
      _G.require = original_require
      
      -- Check that debug messages were generated
      assert.is_true(#debug_messages > 0, "Expected debug messages to be generated")
      
      -- Look for specific debug messages to ensure our enhanced debugging is working
      local found_callback_trigger = false
      local found_input_capture = false
      local found_api_call = false
      
      for _, msg in ipairs(debug_messages) do
        if string.match(msg.message, "@pr_debug callback triggered") then
          found_callback_trigger = true
        elseif string.match(msg.message, "Current line captured") then
          found_input_capture = true
        elseif string.match(msg.message, "About to call avante.api.pr") then
          found_api_call = true
        end
      end
      
      assert.is_true(found_callback_trigger, "Expected to find callback trigger debug message")
      assert.is_true(found_input_capture, "Expected to find input capture debug message")
      assert.is_true(found_api_call, "Expected to find API call debug message")
    end)
  end)

  describe("trim_think_content", function()
    it("should remove think content", function()
      local input = "<think>this should be removed</think> Hello World"
      assert.equals(" Hello World", Utils.trim_think_content(input))
    end)

    it("The think tag that is not in the prefix should not be deleted.", function()
      local input = "Hello <think>this should not be removed</think> World"
      assert.equals("Hello <think>this should not be removed</think> World", Utils.trim_think_content(input))
    end)

    it("should handle multiple think blocks", function()
      local input = "<think>first</think>middle<think>second</think>"
      assert.equals("middle<think>second</think>", Utils.trim_think_content(input))
    end)

    it("should handle empty think blocks", function()
      local input = "<think></think>testtest"
      assert.equals("testtest", Utils.trim_think_content(input))
    end)

    it("should handle empty think blocks", function()
      local input = "test<think></think>test"
      assert.equals("test<think></think>test", Utils.trim_think_content(input))
    end)

    it("should handle input without think blocks", function()
      local input = "just normal text"
      assert.equals("just normal text", Utils.trim_think_content(input))
    end)
  end)

  describe("debounce", function()
    it("should debounce function calls", function()
      local count = 0
      local debounced = Utils.debounce(function() count = count + 1 end, 100)

      -- Call multiple times in quick succession
      debounced()
      debounced()
      debounced()

      -- Should not have executed yet
      assert.equals(0, count)

      -- Wait for debounce timeout
      vim.wait(200, function() return false end)

      -- Should have executed once
      assert.equals(1, count)
    end)

    it("should cancel previous timer on new calls", function()
      local count = 0
      local debounced = Utils.debounce(function(c) count = c end, 100)

      -- First call
      debounced(1)

      -- Wait partial time
      vim.wait(50, function() return false end)

      -- Second call should cancel first
      debounced(233)

      -- Count should still be 0
      assert.equals(0, count)

      -- Wait for timeout
      vim.wait(200, function() return false end)

      -- Should only execute the latest once
      assert.equals(233, count)
    end)

    it("should pass arguments correctly", function()
      local result
      local debounced = Utils.debounce(function(x, y) result = x + y end, 100)

      debounced(2, 3)

      -- Wait for timeout
      vim.wait(200, function() return false end)

      assert.equals(5, result)
    end)
  end)
end)
