-- {"id":964690806,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 964690806

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Lore Novels"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://lorenovels.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://lorenovels.com/wp-content/uploads/fbrfg/favicon-32x32.png"
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
    return url:gsub(".-lorenovels.com/", "")
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
    htmlElement:select("div"):remove()
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
    document:select("script"):remove()
    local content = document:selectFirst(".entry-content")
    local selected = content:select(".entry-content ul > li > a")
    local cur = selected:size() + 1
	return NovelInfo({
        title = content:selectFirst("div > p > strong"):text():gsub("\n" ,""),
        imageURL = content:selectFirst(".wp-block-image > img"):attr("src"),
        chapters = AsList(
                map(filter(selected, function(v)
                    return v:attr("href"):find("lorenovels.com") ~= nil
                end), function(v)
                    cur = cur - 1
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

    return map(filter(document:select(".entry-content > div > div > div"), function(v)
        return v:children():size() > 0
    end), function(v)
        return Novel {
            title = v:selectFirst("h2"):text(),
            link = shrinkURL(v:selectFirst("a"):attr("href")),
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
	-- Optional values to change
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
