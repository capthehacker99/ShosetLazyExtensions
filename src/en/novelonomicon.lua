-- {"id":541210855,"ver":"1.0.3","libVer":"1.0.3","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 541210855

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "novelonomicon"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://novelonomicon.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://311a7f82.rocketcdn.me/wp-content/uploads/2024/06/NovelonomiconLogo_darkbg.png"
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
    return url:gsub(".-novelonomicon.com/", "")
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
    local htmlElement = document:selectFirst(".entry-content")
    document:select(".su-spoiler"):remove()
    return pageOfElem(htmlElement, true)
end


local function parseChapters(doc, tab)
    map(doc:select("#masonry-grid .entry-title > a"), function(v)
        table.insert(tab, NovelChapter {
            title = v:text(),
            link = shrinkURL(v:attr("href"))
        })
    end)
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
    local desc = ""
    map(document:select(".tdb_category_description > div > p, .tdb_category_description > div > p"), function(p)
        desc = desc .. '\n\n' .. p:text()
    end)
    local page = 1
    map(document:select(".pages-nav a"), function(v)
        local link = v:attr("href")
        if not link then return end
        local cur = link:match("page/(%d+)")
        if not cur then return end
        local cp = tonumber(cur)
        if page < cp then page = cp end
    end)
    page = 1
    local chapters = {}
    parseChapters(document, chapters)
    for i = 1, page do
        local doc = GETDocument(url .. "page/" .. i .. "/")
        parseChapters(doc, chapters)
    end
    local len = #chapters
    for i, v in ipairs(chapters) do
        v:setOrder(len - i)
    end
    return NovelInfo({
        title = document:selectFirst(".page-title"):text():gsub("\n" ,""),
        imageURL = imageURL,
        description = desc,
        chapters = chapters
    })
end

local function getListing()
    local document = GETDocument(expandURL("novels/"))

    return map(document:select(".main-content .entry span a"), function(v)
        return Novel {
            title = v:text(),
            link = shrinkURL(v:attr("href")),
            imageURL = imageURL
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
