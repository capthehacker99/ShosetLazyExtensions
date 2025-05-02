-- {"id":571525654,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 571525654

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Ero Light Novel Translations"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "http://erolns.blogspot.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://www.blogger.com/img/logo_blogger_40px.png"
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
    return url:gsub(".-blogspot.com/", "")
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
	local document = Document("<body>" .. chapterURL .. "</body>")
    return pageOfElem(document:selectFirst("body"), true)
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

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
    local data = dkjson.GET(expandURL("feeds/posts/default/-/" .. urlEncode(novelURL) .. "?alt=json"))
    local chapters = {}
    local len = #data.feed.entry
    for i, chapter in next, data.feed.entry do
        table.insert(chapters, NovelChapter {
            order = 1 + len - i,
            title = chapter.title["$t"],
            link = chapter.content["$t"]
        })
    end
	return NovelInfo({
        title = novelURL,
        imageURL = imageURL,
        chapters = AsList(chapters)
    })
end

local function getListing()
    local data = dkjson.GET(expandURL("feeds/posts/summary?max-results=0&alt=json"))
    local novels = {}
    for _, novel in next, data.feed.category do
        table.insert(novels, Novel {
            title = novel.term,
            link = novel.term,
            imageURL = imageURL
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
    hasSearch = false,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
