-- {"id":1035923222,"ver":"1.0.2","libVer":"1.0.2","author":"","repo":"","dep":[]}
local json = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1035923222

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Genesis Studio"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://genesistudio.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://genesistudio.com/favicon-32x32.png"
--- ChapterType provided by the extension.
---
--- Optional, Default is STRING. But please do HTML.
---
--- @type ChapterType
local chapterType = ChapterType.HTML

--- Index that pages start with. For example, the first page of search is index 1.
---
--- Optional, Default is 1.
---
--- @type number
local startIndex = 1

--- Shrink the website url down. This is for space saving purposes.
---
--- Required.
---
--- @param url string Full URL to shrink.
--- @param _ int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Shrunk URL.
local function shrinkURL(url, _)
    return url:gsub(".-genesistudio.com/", "")
end

--- Expand a given URL.
---
--- Required.
---
--- @param url string Shrunk URL to expand.
--- @param _ int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Full URL.
local function expandURL(url, _)
	return baseURL .. url
end


-- Library shit
local skip_ws;
local parse_expr;
local parse_table;
local parse_array;
local parse_key;
local parse_string;
skip_ws = function(lex)
    local chr;
    while true do
        chr = lex[1]:sub(lex[2], lex[2])
        if chr ~= " " and chr ~= "\n" and chr ~= "\t" and chr ~= "\r" then
            return
        end
        lex[2] = lex[2] + 1
    end
end

parse_string = function(lex)
    local chr = lex[1]:sub(lex[2], lex[2])
    if chr ~= '"' and chr ~= "'" then
        error("[STR] Expected `\"` or `'` got " .. lex[1]:sub(lex[2]))
    end
    local og = chr
    local es = false
    lex[2] = lex[2] + 1
    local beg = lex[2]
    while true do
        chr = lex[1]:sub(lex[2], lex[2])
        if chr == "" then
            error("[STR] Unterminated string.")
        end
        if not es and chr == og then
            local raw = lex[1]:sub(beg, lex[2] - 1)
            lex[2] = lex[2] + 1
            raw = raw:gsub("\\\\", "\\")
            raw = raw:gsub("\\b", "\b")
            raw = raw:gsub("\\f", "\f")
            raw = raw:gsub("\\n", "\n")
            raw = raw:gsub("\\r", "\r")
            raw = raw:gsub("\\t", "\t")
            raw = raw:gsub("\\v", "\v")
            raw = raw:gsub("\\'", "\'")
            raw = raw:gsub("\\\"", "\"")
            raw = raw:gsub("\\([0-7]?[0-7]?[0-7])", function(g)
                return string.char(tonumber(g, 8))
            end)
            raw = raw:gsub("\\x(%x%x)", function(g)
                return string.char(tonumber(g, 16))
            end)
            raw = raw:gsub("\\u(%x%x%x%x)", function(g)
                return ''
            end)
            return raw
        end
        if es then
            es = false
        elseif chr == '\\' then
            es = true
        end
        lex[2] = lex[2] + 1
    end
end

parse_key = function(lex)
    local chr = lex[1]:sub(lex[2], lex[2])
    if chr == '"' or chr == "'" then
        return parse_string(lex)
    end
    local l, r = lex[1]:sub(lex[2]):find("^[_$%l%u]+[_$%w]*")
    if not l then
        error("[KEY] Expected identifier got " .. lex[1]:sub(lex[2]))
    end
    local id = lex[1]:sub(lex[2] + l - 1, lex[2] + r - 1)
    lex[2] = lex[2] + r
    return id
end

parse_table = function(lex)
    local chr = lex[1]:sub(lex[2], lex[2])
    if chr ~= "{" then
        error("[TAB] Expected { at " .. lex[1]:sub(lex[2]))
    end
    lex[2] = lex[2] + 1
    skip_ws(lex)
    if lex[1]:sub(lex[2], lex[2]) == "}" then
        lex[2] = lex[2] + 1
        return {}
    end
    local arr = {}
    while true do
        skip_ws(lex)
        local key = parse_key(lex)
        -- print("Parsed key " .. dump(key))
        skip_ws(lex)
        chr = lex[1]:sub(lex[2], lex[2])
        if chr ~= ':' then
            error("[TAB] Expected : at " .. lex[1]:sub(lex[2]))
        end
        lex[2] = lex[2] + 1
        skip_ws(lex)
        arr[key] = parse_expr(lex)
        skip_ws(lex)
        chr = lex[1]:sub(lex[2], lex[2])
        if chr ~= ',' then
            break
        end
        lex[2] = lex[2] + 1
    end
    if chr ~= '}' then
        error("[TAB] Expected } at " .. lex[1]:sub(lex[2]))
    end
    lex[2] = lex[2] + 1
    -- print("Parsed table " .. dump(arr))
    return arr
end

parse_array = function(lex)
    local chr = lex[1]:sub(lex[2], lex[2])
    if chr ~= "[" then
        error("[ARR] Expected [ at " .. lex[1]:sub(lex[2]))
    end
    lex[2] = lex[2] + 1
    skip_ws(lex)
    if lex[1]:sub(lex[2], lex[2]) == "]" then
        lex[2] = lex[2] + 1
        return {}
    end
    local arr = {}
    while true do
        skip_ws(lex)
        table.insert(arr, parse_expr(lex))
        skip_ws(lex)
        chr = lex[1]:sub(lex[2], lex[2])
        if chr ~= ',' then
            break
        end
        lex[2] = lex[2] + 1
    end
    if chr ~= ']' then
        error("[ARR] Expected ] at " .. lex[1]:sub(lex[2]))
    end
    lex[2] = lex[2] + 1
    -- print("Parsed arr " .. dump(arr))
    return arr
end

parse_expr = function(lex)
    skip_ws(lex)
    local chr = lex[1]:sub(lex[2], lex[2])
    if chr == "[" then
        return parse_array(lex)
    elseif chr == "{" then
        return parse_table(lex)
    elseif chr == "\"" or chr == "\'" then
        return parse_string(lex)
    end
    if lex[1]:sub(lex[2], lex[2] + 4) == "false" then
        lex[2] = lex[2] + 5
        return false
    end
    if lex[1]:sub(lex[2], lex[2] + 3) == "true" then
        lex[2] = lex[2] + 4
        return true
    end
    if lex[1]:sub(lex[2], lex[2] + 3) == "null" then
        lex[2] = lex[2] + 4
        return nil
    end
    do
        local l, r = lex[1]:sub(lex[2]):find("^%d+.%d+")
        if not l then
            l, r = lex[1]:sub(lex[2]):find("^.%d+")
        end
        if not l then
            l, r = lex[1]:sub(lex[2]):find("^%d+")
        end
        if l then
            local num = lex[1]:sub(lex[2] + l - 1, lex[2] + r - 1)
            lex[2] = lex[2] + r
            return tonumber(num)
        end
    end
    error("[EXPR] Unexpected `" .. chr .. "` at " .. lex[1]:sub(lex[2]))
end

local function parse_obj(tar)
    local lex = { tar, 1 }
    return parse_expr(lex)
end

local function conv2lua(js)
    js = [[
local __ret;
local parseInt = function(str)
    local res = tonumber(str:match("^%d+"))
    if res == nil then
        return 9e9999-9e9999
    end
    return res
end
    ]] .. js
    local add_back = ""
    js = js:gsub("===", "==")
    js = js:gsub("if%s*(%b())([^;]+);%s*else%s*([^;]+);", function(args, l, r)
        return "if" .. args .. "then " .. l .. " else " .. r .. " end "
    end)
    js = js:gsub("return%s+([_$%l%u]+[_$%w]*)%s*=%s*function%s*(%b())%s*(%b{})%s*,", function(name, args, content)
        content = content:sub(2, #content - 1)
        return name .. " = " .. "(" .. "function" .. args .. content .. "end)\nreturn "
    end)
    js = js:gsub("function%s+([_$%l%u]+[_$%w]*)(%b())%s*(%b{})", function(name, args, content)
        content = content:sub(2, #content - 1)
        return name .. " = " .. "function" .. args .. content .. "end "
    end)
    js = js:gsub("function%s*(%b())%s*(%b{})", function(args, content)
        content = content:sub(2, #content - 1)
        return "(" .. "function" .. args .. content .. "end)"
    end)
    js = js:gsub("try%s*(%b{})%s*catch%s*(%b())%s*(%b{})", function(content, excep_var, excep_clause)
        content = content:sub(2, #content - 1)
        excep_var = excep_var:sub(2, #excep_var - 1)
        excep_clause = excep_clause:sub(2, #excep_clause - 1)
        return "do local __should_break = false local __try_success, " .. excep_var .. " = pcall(function()" .. content:gsub("break","__should_break=true return") .. " end) if __should_break then break end if not __try_success then " .. excep_clause .. " end end "
    end)
    js = js:gsub("while%s*(%b())%s*(%b{})", function(args, content)
        content = content:sub(2, #content - 1)
        return "while " .. args .. " do " .. content .. " end "
    end)
    js = js:gsub("var%s+([_$%l%u]+[_$%w]*)%s*=%s*([^,]+),%s*([_$%l%u]+[_$%w]*)%s*=%s*([^;]+);", function(name, l, name2, r)
        return "var " .. name .. " = " .. l .. ";var " .. name2 .. " = " .. r .. ";"
    end)
    js = js:gsub("var%s+([_$%l%u]+[_$%w]*)", function(name)
        return "local " .. name
    end)
    js = js:gsub("!%[%]", "false")
    js = js:gsub("!false", "true")
    js = js:gsub("(%b\'\')%s*:", function(name)
        return "[" .. name .. "] ="
    end)
    js = js:gsub("(%b\"\")%s*:", function(name)
        return "[" .. name .. "] ="
    end)
    js = js:gsub("(%b[])", function(arr)
        local content = arr:sub(2, #arr - 1)
        if content:find("^[_$%l%u]+[_$%w]*$") then
            return "[" .. content .. "+1]"
        end
        if content:find(",") then
            return "{" .. content .. "}"
        end
        return arr
    end)
    js = js:gsub("([_$%l%u]+[_$%w]*)%['push'%](%b())", function(name, args)
        return " table.insert(" .. name .. ", " .. args:sub(2, #args - 1) .. ")"
    end)
    js = js:gsub("([_$%l%u]+[_$%w]*)%['shift'%](%b())", function(name, args)
        return " table.remove(" .. name .. ", 1)"
    end)
    js = js:gsub("%((%b()%b())%s*,%s*%((%b()%b())%)%)", function(l, r)
        add_back = l .. ";return " .. r .. ""
        return ""
    end)
    js = js .. add_back
    return js
end

--- Get a chapter passage based on its chapterURL.
---
--- Required.
---
--- @param chapterURL string The chapters shrunken URL.
--- @return string Strings in lua are byte arrays. If you are not outputting strings/html you can return a binary stream.
local function getPassage(chapterURL)
	local url = expandURL(chapterURL)

	--- Chapter page, extract info from it.
	local document = GETDocument(url)
    local data;
    map(document:select("script"),function(script)
        if data then
            return
        end
        local matched = string.match(tostring(script), "{\"type\":\"data\",\"data\":{form:.+];")
        if not matched then
            return
        end
        local trans = matched:sub(0, #matched-2):gsub("void (%d)", function(o) return o end):gsub("([,{][a-zA-Z_$][0-9a-zA-Z_$]*):", function(a) return a:sub(0, 1) .. '"' .. a:sub(2) .. '":' end)
        data = json.decode(trans)
    end)
    if not data or not data.data then
        error("Failed to obtain passage data.")
    end

    local real_content;
    for _, v in next, data.data do
        if type(v) == "string" then
            local content = data.data[v]
            if content then
                real_content = content
                break
            end
        end
    end
    if not real_content then
        real_content = data.data.content
    end
    if real_content then
        return pageOfElem(Document(real_content), true)
    end
    error("Content not found.")
end

local function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
	local url = expandURL(novelURL)
	local document = GETDocument(url)
    local data;
    map(document:select("script"),function(script)
        if data then
            return
        end
        local matched = string.match(tostring(script), "{\"type\":\"data\",\"data\":{novel:.+];")
        if not matched then
            return
        end
        local trans = matched:sub(0, #matched-2):gsub("([,{][a-zA-Z_$][0-9a-zA-Z_$]*):", function(a) return a:sub(0, 1) .. '"' .. a:sub(2) .. '":' end)
        data = parse_obj(trans)
    end)
    if not data or not data.data then
        error("Failed to obtain novel data.")
    end
    local chapters = {}
    local lua_script = conv2lua(data.data.chapters)
    --print(data.data.chapters)
    local f, err = load(lua_script)
    if err then
        error(err)
    end
    local chapters_data = f()
    for _, v1 in next, chapters_data do
        for _, v2 in next, v1 do
            if v2.required_tier == 0 then
                table.insert(chapters, NovelChapter {
                    order = v2.chapter_number,
                    title = v2.chapter_title,
                    link = "viewer/" .. v2.id
                })
            end
        end
    end
	return NovelInfo({
        title = data.data.novel.novel_title,
        imageURL = data.data.novel.cover,
        description = data.data.novel.synopsis,
        chapters = chapters
    })
end

local function getListing()
    local novels_json = json.GET("https://genesistudio.com/api/search?serialization=All&sort=Popular")
    local novels = {}
    for _, novel in pairs(novels_json) do
        table.insert(novels, Novel {
            title = novel.novel_title,
            link = "novels/" .. novel.abbreviation,
            genres = novel.genres,
            imageURL = novel.cover and novel.cover or imageURL
        })
    end
    return novels
end

local function search(data)
    local query = data[QUERY]
    local novels_json = json.GET("https://genesistudio.com/api/search?serialization=All&sort=Popular&title=" .. query)
    local novels = {}
    for _, novel in pairs(novels_json) do
        table.insert(novels, Novel {
            title = novel.novel_title,
            link = "novels/" .. novel.abbreviation,
            genres = novel.genres,
            imageURL = novel.cover and novel.cover or imageURL
        })
    end
    return novels
end

-- Return all properties in a lua table.
return {
	-- Required
	id = id,
	name = name,
	baseURL = baseURL,
	listings = {
        Listing("Default", false, getListing)
    }, -- Must have at least one listing
	getPassage = getPassage,
	parseNovel = parseNovel,
	shrinkURL = shrinkURL,
	expandURL = expandURL,
    hasSearch = true,
    isSearchIncrementing = false,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
