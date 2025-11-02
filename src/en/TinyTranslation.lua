-- {"id":1141686301,"ver":"1.0.7","libVer":"1.0.6","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1141686301

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Tiny Translation"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://www.tinytranslation.xyz/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://www.tinytranslation.xyz/wp-content/uploads/2023/06/Logo-new.png"
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
    return url:gsub(".-tinytranslation.xyz/", "")
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
    local htmlElement = document:selectFirst(".content") or document:selectFirst(".entry-content")
    htmlElement:select("p[style],navigate"):remove()
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
    local title = document:selectFirst(".title-content")
    title = title and title:text() or "Unknown Title"
    local desc = ""
    map(document:select(".entry-content .text-justify"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    return NovelInfo({
        title = title,
        imageURL = imageURL,
        description = desc,
        chapters = AsList(mapNotNil(document:select("#info ul > li a, .entry-content div.container ul > li a, .entry-content ul > li a"), function(v)
            local link = v:attr("href")
            if not (link:find("tinytranslation") or link:find("^/")) then return end
            return NovelChapter {
                order = v,
                title = v:text(),
                link = shrinkURL(link)
            }
        end))
    })
end

local function getListing()
    local document = GETDocument(expandURL("list-novels/"))

    return mapNotNil(document:select("ul.series-posts-list > li > a"), function(v)
        local link = v:attr("href")
        if not link:find("series") then return end
        return Novel {
            title = v:text(),
            link = shrinkURL(link),
            imageURL = imageURL
        }
    end)
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

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("?s=" .. urlEncode(query) .. "&paged=" .. page))
    return mapNotNil(document:select(".search-results > div.latest-postItemContainer > a"), function(v)
        local link = v:attr("href")
        if not link:find("series") and not link:find("uncategorized") then return end
        return Novel {
            title = v:text(),
            link = shrinkURL(link),
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
    hasSearch = true,
    isSearchIncrementing = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
