-- {"id":1140740461,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1140740461

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Mystic Translations"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://mystictranslations.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://mystictranslations.com/favicon.svg"
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
    return url:gsub(".-mystictranslations.com/", "")
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
    local htmlElement = document:selectFirst("#chapter-text")
    return pageOfElem(htmlElement, true)
end

-- Library

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
    local total_str = ""
    while true do
        chr = lex[1]:sub(lex[2], lex[2])
        if chr == "" then
            error("[STR] Unterminated string.")
        end
        if not es and chr == og then
            lex[2] = lex[2] + 1
            return total_str
        end
        if es then
            if chr == '\\' then
                total_str = total_str .. chr
            elseif chr == 'b' then
                total_str = total_str .. '\b'
            elseif chr == 'f' then
                total_str = total_str .. '\f'
            elseif chr == 'n' then
                total_str = total_str .. '\n'
            elseif chr == 'r' then
                total_str = total_str .. '\r'
            elseif chr == 't' then
                total_str = total_str .. '\t'
            elseif chr == 'v' then
                total_str = total_str .. '\v'
            elseif chr == '\'' then
                total_str = total_str .. '\''
            elseif chr == '\"' then
                total_str = total_str .. '\"'
            else
                local match = lex[1]:sub(lex[2]):match("^([0-7]?[0-7]?[0-7])")
                if match then
                    total_str = total_str .. string.char(tonumber(match, 8))
                    lex[2] = lex[2] + #match
                else
                    match = lex[1]:sub(lex[2]):match("^x(%x%x)")
                    if match then
                        total_str = total_str .. string.char(tonumber(match, 16))
                        lex[2] = lex[2] + #match
                    else
                        match = lex[1]:sub(lex[2]):match("^u(%x%x%x%x)")
                        if match then
                            lex[2] = lex[2] + #match
                        end
                    end
                end
            end
            es = false
        elseif chr == '\\' then
            es = true
        else
            total_str = total_str .. chr
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

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
	local url = expandURL(novelURL)

	--- Novel page, extract info from it.
	local document = GETDocument(url)
    local chapter_data
    local novel_data
    map(document:select("script[type=\"application/ld+json\"]"), function(script)
        if novel_data and chapter_data then
            return
        end
        if not novel_data and string.find(tostring(script), "\"datePublished\":") ~= nil then
            novel_data = parse_obj(tostring(script):match("%b{}"))
            return
        end
        if not chapter_data and string.find(tostring(script), "\"itemListElement\":") ~= nil then
            chapter_data = parse_obj(tostring(script):match("%b{}"))
            return
        end
    end)
    if not novel_data then
        error("Failed to obtain novel data.")
    end
    if not chapter_data then
        error("Failed to obtain novel data.")
    end
	return NovelInfo({
        title = novel_data.name,
        imageURL = novel_data.thumbnailUrl,
        description = novel_data.description,
        chapters = AsList(
            map(chapter_data.itemListElement, function(v)
                return NovelChapter {
                    order = v.position,
                    title = v.name,
                    link = shrinkURL(v.item)
                }
            end)
        )
    })
end

local function getListing()
    local document = GETDocument(expandURL("n"))
    return map(document:select(".flex-row > .mud-paper"), function(v)
        local img = v:selectFirst("img")
        return Novel {
            title = v:selectFirst("h5"):text(),
            link = shrinkURL(v:selectFirst("a"):attr("href")),
            imageURL = expandURL(img:attr("src"))
        }
    end)
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
    hasSearch = false,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
