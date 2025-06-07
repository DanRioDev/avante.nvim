local PR = require("avante.extensions.pr")

describe("PR Extension", function()
  describe("review_pr", function()
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