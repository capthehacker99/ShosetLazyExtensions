-- {"id":639193459,"ver":"1.0.2","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 639193459

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Novel Dex"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://noveldex.io/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://noveldex.io/_next/image?url=%2Fuploads%2Fsettings%2Flogo-9f6ca6403bb40c476fb1c57fa981d6bc.webp&w=256&q=75"
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
    return url:gsub(".-noveldex.io/", "")
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

local function urlEncode(str)
    if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-%_%.%~])", function(c)
            return ("%%%02X"):format(string.byte(c))
        end)
        str = str:gsub(" ", "+")
    end
    return str
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
    map(document:select("script"), function(val)
        for val in a:gmatch("(%b())") do
            local div_match = a:match("\"\\u003cdiv\\u003e(.*)\\u003c/div\\u003e")
            if div_match then
                return pageOfElem(Document("<body>" .. div_match .. "</body>"):selectFirst("body"), true)
            end
        end
    end)
    error("Passage content not found")
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
    local series;
    local chapters_data;
    map(document:select("script"), function(val)
        local script_val = tostring(val)
        local series_match = script_val:match("series\\\":(%b{})")
        if series_match then
            local parsed_series = dkjson.decode(series_match:gsub("\\\"", "\""))
            if parsed_series then
                series = parsed_series
            end
        end
        local chapters_data_match = script_val:match("chapters\\\":(%b[])")
        if chapters_data_match then
            local parsed_chapters_data = dkjson.decode(chapters_data_match:gsub("\\\"", "\""))
            if parsed_chapters_data then
                chapters_data = parsed_chapters_data
            end
        end
    end)
    if not series then
        error("Series data not found")
    end
    if not chapters_data then
        error("Chapters data not found")
    end
    local chapters = {}
    for _, chapter in next, chapters_data do
        if not chapter.isLocked then
            table.insert(chapters, NovelChapter {
                order = chapter.number,
                title = chapter.title,
                link = novelURL .. "/chapter/" .. chapter.number
            })
        end
    end
	return NovelInfo({
        title = series.title,
        imageURL = expandURL(series.coverImage),
        description = series.description,
        chapters = AsList(chapters)
    })
end

local function getListing(data)
    local novel_data = dkjson.GET(expandURL("api/series?page=" .. data[PAGE] .. "&limit=100"))
    local novels = {}
    for _, v in next, novel_data.data do
        table.insert(novels, Novel {
            title = v.title,
            link = "series/novel/" .. v.urlSlug,
            imageURL = expandURL(v.coverImage)
        })
    end
    return AsList(novels)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local novel_data = dkjson.GET(expandURL("api/series?q=" .. urlEncode(query) .. "&page=" .. page .. "&limit=100"))
    local novels = {}
    for _, v in next, novel_data.data do
        table.insert(novels, Novel {
            title = v.title,
            link = "series/novel/" .. v.urlSlug,
            imageURL = expandURL(v.coverImage)
        })
    end
    return AsList(novels)
end

-- Return all properties in a lua table.
return {
	-- Required
	id = id,
	name = name,
	baseURL = baseURL,
	listings = {
        Listing("Default", true, getListing)
    }, -- Must have at least one listing
	getPassage = getPassage,
	parseNovel = parseNovel,
	shrinkURL = shrinkURL,
	expandURL = expandURL,
    hasSearch = true,
    isSearchIncrementing = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
