-- {"id":304044934,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 304044934

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "DarkStar Translations"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://darkstartranslations.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://darkstartranslations.com/wp-content/uploads/2024/03/cropped-artworks-000124012668-q7lg09-t500x500-192x192.jpg"
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
    return url:gsub(".-darkstartranslations.com/", "")
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
    local htmlElement = document:selectFirst(".reading-content")
    htmlElement:select(".chapter-warning"):remove()
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
    local title = document:selectFirst(".post-title")
    title = title and title:text() or "Unknown Title"
    local desc = ""
    map(document:select(".description-summary p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local chapters_doc = GETDocument(url .. "/ajax/chapters/")
    local selected = chapters_doc:select(".free-chap a")
    local cur = selected:size() + 1
    return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = AsList(
                map(selected,function(v)
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
    local document = GETDocument(expandURL("manga/"))
    return map(document:select(".page-listing-item [data-post-id] > a"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("src") or imageURL
        return Novel {
            title = v:attr("title"),
            link = shrinkURL(v:attr("href")),
            imageURL = img
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("page/" .. page .. "/?s=" .. query .. "&post_type=wp-manga"))
    return map(document:select(".page-listing-item [data-post-id] > a"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("src") or imageURL
        return Novel {
            title = v:attr("title"),
            link = shrinkURL(v:attr("href")),
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
    hasSearch = true,
    isSearchIncrementing = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
