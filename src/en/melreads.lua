-- {"id":1207937470,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1207937470

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "MelReads"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://melreads.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://melreads.com/wp-content/uploads/2026/01/melreads-2.png"
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
    return url:gsub(".-melreads.com/", "")
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
    local desc = ""
    map(document:select(".entry-content p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local selected = document:select(".eplister > ul > li > a")
    local cur = selected:size() + 1
	return NovelInfo({
        title = document:selectFirst(".entry-title"):text():gsub("\n" ,""),
        imageURL = document:selectFirst(".wp-post-image"):attr("src"),
        description = desc,
        chapters = AsList(
                map(filter(selected, function(v)
                    local price = v:selectFirst(".epl-num")
                    return price == nil or price:text():lower():find("🔒") == nil
                end), function(v)
                    cur = cur - 1
                    return NovelChapter {
                        order =cur,
                        title = v:selectFirst(".epl-title"):text(),
                        link = shrinkURL(v:attr("href"))
                    }
                end)
        )

    })
end

local function getListing(data)
    local page = data[PAGE]
    local document = GETDocument(expandURL("series/?page=" .. page))

    return map(document:select(".listupd article"), function(v)
        local header = v:selectFirst("h2")
        return Novel {
            title = header:text(),
            link = shrinkURL(header:selectFirst("a"):attr("href")),
            imageURL = v:selectFirst(".wp-post-image"):attr("src")
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("page/" .. page .. "/?s=" .. query))
    return map(document:select(".listupd article"), function(v)
        local header = v:selectFirst("h2")
        return Novel {
            title = header:text(),
            link = shrinkURL(header:selectFirst("a"):attr("href")),
            imageURL = v:selectFirst(".wp-post-image"):attr("src")
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
        Listing("Default", true, getListing)
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
