local PR = require("avante.extensions.pr")

describe("PR Extension", function()
  describe("is_available", function()
    it("should return false when Octo plugin is not available", function()
      -- Mock pcall to simulate Octo not being available
      local original_pcall = _G.pcall
      _G.pcall = function(fn, module_name)
        if module_name == 'octo' then
          return false, "module 'octo' not found"
        end
        return original_pcall(fn, module_name)
      end
      
      local available, error_msg = PR.is_available()
      
      -- Restore original pcall
      _G.pcall = original_pcall
      
      assert.is_false(available)
      assert.is_string(error_msg)
      assert.has_match("Octo plugin.*not installed", error_msg)
    end)
    
    it("should return false when gh CLI is not available", function()
      -- Mock pcall to simulate Octo being available
      local original_pcall = _G.pcall
      _G.pcall = function(fn, module_name)
        if module_name == 'octo' then
          return true, {}
        end
        return original_pcall(fn, module_name)
      end
      
      -- Mock vim.fn.executable to return 0 (not found)
      local original_executable = vim.fn.executable
      vim.fn.executable = function(name)
        if name == "gh" then
          return 0
        end
        return original_executable(name)
      end
      
      local available, error_msg = PR.is_available()
      
      -- Restore original functions
      _G.pcall = original_pcall
      vim.fn.executable = original_executable
      
      assert.is_false(available)
      assert.is_string(error_msg)
      assert.has_match("GitHub CLI.*not installed", error_msg)
    end)
    
    it("should return true when both dependencies are available", function()
      -- Mock pcall to simulate Octo being available
      local original_pcall = _G.pcall
      _G.pcall = function(fn, module_name)
        if module_name == 'octo' then
          return true, {}
        end
        return original_pcall(fn, module_name)
      end
      
      -- Mock vim.fn.executable to return 1 (found)
      local original_executable = vim.fn.executable
      vim.fn.executable = function(name)
        if name == "gh" then
          return 1
        end
        return original_executable(name)
      end
      
      local available, error_msg = PR.is_available()
      
      -- Restore original functions
      _G.pcall = original_pcall
      vim.fn.executable = original_executable
      
      assert.is_true(available)
      assert.is_nil(error_msg)
    end)
  end)
  
  describe("review_pr", function()
    it("should handle missing Octo dependency gracefully", function()
      local success, error_msg
      
      -- Mock pcall to simulate Octo not being available
      local original_pcall = _G.pcall
      _G.pcall = function(fn, module_name)
        if module_name == 'octo' then
          return false, "module 'octo' not found"
        end
        return original_pcall(fn, module_name)
      end
      
      PR.review_pr(nil, function(s, msg)
        success = s
        error_msg = msg
      end)
      
      -- Restore original pcall
      _G.pcall = original_pcall
      
      assert.is_false(success)
      assert.is_string(error_msg)
      assert.has_match("Octo plugin.*not installed", error_msg)
    end)
    
    it("should handle missing dependencies gracefully", function()
      local success, error_msg
      
      -- Mock vim.fn.executable to return 0 (not found)
      local original_executable = vim.fn.executable
      vim.fn.executable = function(name)
        if name == "gh" then
          return 0
        end
        return original_executable(name)
      end
      
      PR.review_pr(nil, function(s, msg)
        success = s
        error_msg = msg
      end)
      
      -- Restore original function
      vim.fn.executable = original_executable
      
      assert.is_false(success)
      assert.is_string(error_msg)
      assert.has_match("GitHub CLI.*not installed", error_msg)
    end)
    
    it("should handle git repository check", function()
      local success, error_msg
      
      -- Mock vim.fn.system to simulate not being in a git repo
      local original_system = vim.fn.system
      local original_shell_error = vim.v.shell_error
      
      vim.fn.system = function(cmd)
        if cmd:match("git rev%-parse") then
          vim.v.shell_error = 1
          return "fatal: not a git repository"
        end
        return original_system(cmd)
      end
      
      PR.review_pr(nil, function(s, msg)
        success = s
        error_msg = msg
      end)
      
      -- Restore original functions
      vim.fn.system = original_system
      vim.v.shell_error = original_shell_error
      
      assert.is_false(success)
      assert.is_string(error_msg)
      assert.has_match("Not in a Git repository", error_msg)
    end)
  end)
end)