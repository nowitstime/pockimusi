-- ============================================================================
-- tests/run.lua — runs every tests/test_*.lua file
--
-- Run from the repository root:
--   python3 tests/run.py          (uses lupa's LuaJIT: pip install lupa)
--   luajit tests/run.lua          (if LuaJIT is installed)
--   luajit tests/run.lua looper   (only files whose name contains "looper")
-- ============================================================================

package.path = "pocketgroove/?.lua;pocketgroove/?/init.lua;tests/?.lua;" .. package.path

local FILES = {
    "test_theory",
    "test_input",
    "test_looper",
    "test_smoke",
}

local filter = (arg and arg[1]) or TEST_FILTER

local passed, failed, failures = 0, 0, {}

for _, file in ipairs(FILES) do
    if not filter or file:find(filter, 1, true) then
        local cases = dofile("tests/" .. file .. ".lua")
        for _, case in ipairs(cases) do
            local ok, err = xpcall(case[2], debug.traceback)
            if ok then
                passed = passed + 1
            else
                failed = failed + 1
                table.insert(failures, string.format("FAIL %s :: %s\n  %s", file, case[1], err:gsub("\n", "\n  ")))
            end
        end
    end
end

for _, f in ipairs(failures) do print(f) end
print(string.format("\n%d passed, %d failed", passed, failed))

TEST_FAILED = failed
if not TEST_EMBEDDED and os and os.exit then
    os.exit(failed == 0 and 0 or 1)
end
return failed
