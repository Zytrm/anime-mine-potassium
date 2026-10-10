-- Stable Potassium loader. Resolve main to a commit so raw CDN caching cannot
-- return a previous branch version.
local ok, response = pcall(request, {
    Url = "https://api.github.com/repos/Zytrm/anime-mine-potassium/commits/main",
    Method = "GET",
    Headers = {["User-Agent"] = "AnimeMinePotassium"},
})

local sha = "a54bba4"
if ok and response and response.Success then
    local http = game:GetService("HttpService")
    local parsed, commit = pcall(http.JSONDecode, http, response.Body)
    if parsed and type(commit) == "table" and type(commit.sha) == "string"
        and commit.sha:match("^[0-9a-f]+$") then
        sha = commit.sha
    end
end

local source = game:HttpGet("https://raw.githubusercontent.com/Zytrm/anime-mine-potassium/"
    .. sha .. "/main.luau")
local run, compileError = loadstring(source)
assert(run, compileError)
run()
