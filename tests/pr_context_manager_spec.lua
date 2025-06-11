local PRContextManager = require("avante.pr_context_manager")

describe("PRContextManager", function()
  before_each(function()
    -- Clear any existing PR context before each test
    PRContextManager.set_active_pr_details(nil)
  end)

  describe("set_active_pr_details", function()
    it("should set PR details with timestamp", function()
      local test_pr = {
        number = 123,
        title = "Test PR",
        author = "testuser",
        body = "Test description"
      }
      
      PRContextManager.set_active_pr_details(test_pr)
      local active_pr = PRContextManager.get_active_pr_details()
      
      assert.is_not_nil(active_pr)
      assert.equals(123, active_pr.number)
      assert.equals("Test PR", active_pr.title)
      assert.equals("testuser", active_pr.author)
      assert.equals("Test description", active_pr.body)
      assert.is_not_nil(active_pr.loaded_at)
    end)

    it("should clear PR details when passed nil", function()
      -- First set some PR data
      PRContextManager.set_active_pr_details({
        number = 123,
        title = "Test PR"
      })
      
      -- Then clear it
      PRContextManager.set_active_pr_details(nil)
      local active_pr = PRContextManager.get_active_pr_details()
      
      assert.is_nil(active_pr)
    end)
  end)

  describe("get_active_pr_details", function()
    it("should return nil when no PR is set", function()
      local active_pr = PRContextManager.get_active_pr_details()
      assert.is_nil(active_pr)
    end)

    it("should return the correct PR details when set", function()
      local test_pr = {
        number = 456,
        title = "Another Test PR",
        changed_files = {
          { path = "file1.lua" },
          { path = "file2.lua" }
        }
      }
      
      PRContextManager.set_active_pr_details(test_pr)
      local active_pr = PRContextManager.get_active_pr_details()
      
      assert.is_not_nil(active_pr)
      assert.equals(456, active_pr.number)
      assert.equals("Another Test PR", active_pr.title)
      assert.equals(2, #active_pr.changed_files)
      assert.equals("file1.lua", active_pr.changed_files[1].path)
      assert.equals("file2.lua", active_pr.changed_files[2].path)
    end)
  end)
end)