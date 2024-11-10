-- {"id":516385957,"ver":"1.0.2","libVer":"1.0.2","author":"","repo":"","dep":[]}
local json = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 516385957

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "inoveltranslation"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://inoveltranslation.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://inoveltranslation.com/favicon.ico"
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
    return url:gsub(".-inoveltranslation.com/", "")
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
    local doc = GETDocument(expandURL(chapterURL))
    doc:select("section"):remove()
    return pageOfElem(Document(doc), true)
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
    local doc = GETDocument(expandURL(novelURL))
    local title = doc:selectFirst("main > section > div > section > h1")
    title = title and title:text() or "Unknown Title"
    local img = doc:selectFirst("[alt=\"Novel main cover\"]")
    img = img and img:attr("src") or imageURL
    local desc = ""
    map(doc:select("dd > div > p"), function(v)
        desc = desc .. v:text() .. '\n\n'
    end)
    local chapters = {}
    map(doc:select("script"), function(v)
        local code = tostring(v)
        for a, b in code:gmatch("{%s*\\\"href\\\"%s*:%s*\\\"([^\"]+)\\\"[^}]+\\\"children\\\"%s*:%s*\\\"([^\"]+)\\\"") do
            table.insert(chapters, NovelChapter {
                link = a,
                title = b,
            })
        end
    end)
    for i = 1, #chapters do
        chapters[i]:setOrder(#chapters - i)
    end
    return NovelInfo {
        title = title,
        description = desc,
        imageURL = img,
        chapters = chapters
    }
end

local function getListing()
    local doc = GETDocument(expandURL("novels/"))
    return map(doc:select("main > section > div > section > a"), function(v)
        local img = v:selectFirst("img")
        img = img and v:attr("src") or nil
        return Novel {
            title = v:selectFirst("span"):text(),
            link = v:attr("href"),
            imageURL = img
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
	-- Optional values to change
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
