-- {"id":1007632639,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1007632639

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Infinite Novel Translations"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://infinitenoveltranslations.net/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://infinitenoveltranslations.net/wp-content/uploads/2024/08/Infinite-Novel-Translations-logo-inverted-smoll.png"
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
    return url:gsub(".-infinitenoveltranslations.net/", "")
end

--- Expand a given URL.
---
--- Required.
---
--- @param url string Shrunk URL to expand.
--- @param _ int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Full URL.
local function expandURL(url, _)
    if url:find("^http://") or url:find("^https://") then
        return url
    end
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
    local htmlElement = document:selectFirst("#content")
    map(htmlElement:select("img"), function(v)
        local lazy = v:attr("data-src")
        if lazy then
            v:attr("src", lazy)
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
    local title = document:selectFirst(".entry-title")
    title = title and title:text() or "Unknown Title"
    local img = document:selectFirst("[data-image-title=\"cover\"]")
    img = img and img:attr("src") or imageURL
    local desc = ""
    map(document:select(".bs-card-box > p[style]"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
	return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = AsList(
            map(document:select(".bs-card-box a"), function(v)
                return NovelChapter {
                    order = cur,
                    title = v:text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )
    })
end

local function getListing()
    local document = GETDocument(baseURL)

    return map(document:select(".dropdown-item"), function(v)
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
