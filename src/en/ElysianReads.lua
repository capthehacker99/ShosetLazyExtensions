-- {"id":220455404,"ver":"1.0.10","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 220455404

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Elysian Reads"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://www.elysianreads.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://cdn.jsdelivr.net/gh/elysianreads/elysian-assets/elysian/Logo.webp"
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
    return url:gsub(".-elysianreads.com/", "")
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
    local elem = document:selectFirst("#ch-content-wrapper")
    elem:select("[aria-hidden=\"true\"]"):remove()
    return pageOfElem(elem, true)
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
    local desc = document:selectFirst("meta[property=\"og:description\"]")
    if desc then
        desc = desc:attr("content")
    end
    local image = document:selectFirst("meta[property=\"og:image\"]")
    if image then
        image = image:attr("content")
    end
    local title = document:selectFirst("meta[property=\"og:title\"]")
    if title then
        title = title:attr("content")
    end
	return NovelInfo({
        title = title,
        imageURL = image,
        description = desc,
        chapters = mapNotNil(document:select("nav[aria-label=\"Chapter list\"] a"), function(v)
            if v:text():match(" %(VIP%)$") then
                return
            end
            return NovelChapter {
                order = v:text(),
                title = v:text(),
                link = shrinkURL(v:attr("href"))
            }
        end)
    })
end

local function getListing(data)
    local novel_data = dkjson.GET(expandURL("wp-json/elysian/v1/novels"))
    local novels = {}
    for k, v in next, novel_data do
        table.insert(novels, Novel {
            title = v.title,
            link = "novel/" .. k,
            imageURL = v.cover
        })
    end
    return AsList(novels)
end

local function search(data)
    local query = data[QUERY]
    local novel_data = dkjson.GET(expandURL("wp-json/elysian/v1/novels"))
    local novels = {}
    for k, v in next, novel_data do
        if v.title:find(query) then
            table.insert(novels, Novel {
                title = v.title,
                link = "novel/" .. k,
                imageURL = v.cover
            })
        end
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
