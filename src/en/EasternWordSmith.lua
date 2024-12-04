-- {"id":1619485594,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1619485594

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Eastern Word Smith"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://easternwordsmith.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://easternwordsmith.com/images/logo2.png"
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
    return url:gsub(".-easternwordsmith.com/", "")
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
    local htmlElement = document:selectFirst("#CS")
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
    local img = document:selectFirst(".center > a > img")
    img = img and img:attr("src") or imageURL
    local title = document:selectFirst("div.row > div.col-8 > a")
    title = title and title:text() or "Unknown Title"
    local desc = ""
    map(document:select("div.row > div.d-md-block > p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
	return NovelInfo({
        title = title:gsub("\n" ,""),
        imageURL = img,
        description = desc,
        chapters = AsList(
            map(document:select("div.col-10:has(h4) > div.row a[href]"), function(v)
                return NovelChapter {
                    order = v,
                    title = v:text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )
    })
end

local function getListing()
    local document = GETDocument(expandURL("novels"))

    return map(document:select("div.row > div > div.row"), function(v)
        local title = v:selectFirst("h6 > a")
        return Novel {
            title = title:text(),
            link = shrinkURL(title:attr("href")),
            imageURL = v:selectFirst("img"):attr("src")
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
