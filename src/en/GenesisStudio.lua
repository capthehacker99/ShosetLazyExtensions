-- {"id":1035923222,"ver":"1.0.1","libVer":"1.0.1","author":"","repo":"","dep":[]}
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
    return pageOfElem(Document(data.data.content), true)
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
        data = json.decode(trans)
    end)
    if not data or not data.data then
        error("Failed to obtain novel data.")
    end
    local chapters = {}
    for _, v1 in next, data.data.chapters do
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
