-- {"id":402713732,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 402713732

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "nhvnovels"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://nhvnovels.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://nhvnovels.com/wp-content/uploads/2025/01/cropped-nhv-photoaidcom-cropped-png-192x192.webp"
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
    return url:gsub(".-nhvnovels.com/", "")
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
    local htmlElement = document:selectFirst(".chapter-container")
    htmlElement:select(".recommendation, .down-chapter-header, .ch-review-div, #comments"):remove()
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
    local desc_container = document:selectFirst(".novel-content-2")
    local desc = ""
    map(desc_container:select("p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local selected = document:select(".chapters > ul > li > a[class=\"\"]")
    local cur = selected:size() + 1
	return NovelInfo({
        title = desc_container:selectFirst("h1"):text():gsub("\n" ,""),
        imageURL = document:selectFirst(".novel-topcard .attachment-post-thumbnail"):attr("src"),
        description = desc,
        chapters = AsList(
            map(selected, function(v)
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

    return map(document:select(".novel-item"), function(v)
        local thumbnail = v:selectFirst(".novel-thumbnail")
        return Novel {
            title = v:selectFirst(".novel-content > h2"):text(),
            link = shrinkURL(thumbnail:selectFirst("a"):attr("href")),
            imageURL = thumbnail:selectFirst("img"):attr("src")
        }
    end)
end

local function search(data)
    --local page = data[PAGE]
    local query = data[QUERY]
    local form = FormBodyBuilder()
            :add("action", "ajax_novel_search")
            :add("search_query", query)
            :build()
    local document = RequestDocument(POST(expandURL("wp-admin/admin-ajax.php"), DEFAULT_HEADERS(), form))
    return map(document:select(".novel-item"), function(v)
        local thumbnail = v:selectFirst(".novel-thumbnail")
        return Novel {
            title = v:selectFirst(".novel-content > h2"):text(),
            link = shrinkURL(thumbnail:selectFirst("a"):attr("href")),
            imageURL = thumbnail:selectFirst("img"):attr("src")
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
    isSearchIncrementing = false,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
