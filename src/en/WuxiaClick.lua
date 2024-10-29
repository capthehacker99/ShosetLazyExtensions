-- {"id":1401762246,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1401762246

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "WuxiaClick"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://wuxia.click/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://wuxia.click/favicon.ico"
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
    return url:gsub(".-wuxia.click/", "")
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
    local htmlElement = nil
    map(document:select(".mantine-Paper-root"), function(v)
        if v:select("#chapterText") ~= nil then
            htmlElement = v
        end
    end)
    return pageOfElem(htmlElement, true)
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
    local info_group = document:select(".mantine-Group-root")
    local img = info_group:select("img.mantine-Image-image")
    img = img and img:attr("src") or nil
    local title = info_group:select(".mantine-Title-root")
    title = title and title:text() or nil
    local desc = document:select(".mantine-Spoiler-content .mantine-Text-root")
    desc = desc and desc:text() or nil

    local data = dkjson.GET(expandURL("api/chapters/" .. novelURL:gsub("^/novel/", "")))
    local chapters = {}
    for _, v in next, data do
        table.insert(chapters, NovelChapter {
            order = v.index,
            title = v.title,
            link = "chapter/" .. v.novSlugChapSlug
        })
    end

	return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = chapters
    })
end

local function getListing()
    local document = GETDocument(baseURL)

    return map(document:select(".mantine-Grid-root > div > div > a"), function(v)
        local header = v:selectFirst(".mantine-Text-root")
        return Novel {
            title = header:text(),
            link = shrinkURL(v:attr("href")),
            imageURL = v:selectFirst("img.mantine-Image-image"):attr("src")
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("https://wuxia.click/search/" .. query .. "?page=" .. page))
    return map(document:select(".mantine-Grid-root > div > div > a"), function(v)
        local header = v:selectFirst(".mantine-Text-root")
        return Novel {
            title = header:text(),
            link = shrinkURL(v:attr("href")),
            imageURL = v:selectFirst("img.mantine-Image-image"):attr("src")
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
    hasSearch = true,
    isSearchIncrementing = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
