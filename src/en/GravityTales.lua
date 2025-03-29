-- {"id":28508335,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 28508335

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Gravity Tales"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://gravitytales.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://gravitytales.com/wp-content/uploads/2024/07/153447053-187d129a8b1bb4c31fa0ebb07ffa7aa5ed36511035ddf6d3b4994fecb0ebab97-1.png"
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
    return url:gsub(".-gravitytales.com/", "")
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
    htmlElement:select("div > figure"):remove()
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
    local img = document:selectFirst(".summary_image img")
    img = img and (img:attr("src") or img:attr("data-src")) or imageURL
    local desc = ""
    map(document:select(".manga-summary p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local chapters_doc = RequestDocument(POST(url .. "ajax/chapters/"))
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

local function getListing(data)
    local document = GETDocument(expandURL("browse/page/" .. data[PAGE] .. "/"))

    return map(document:select(".page-item-detail > [data-post-id] > a"), function(v)
        return Novel {
            title = v:attr("title"),
            link = shrinkURL(v:attr("href")),
            imageURL = v:selectFirst("img"):attr("src")
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("page/" .. page .. "/?s=" .. query .. "&post_type=wp-manga"))
    return map(document:select(".tab-content-wrap > div > .row"), function(v)
        local img = v:selectFirst(".tab-thumb img")
        img = img and img:attr("src") or imageURL
        local title = v:selectFirst(".post-title a")
        return Novel {
            title = title:text(),
            link = shrinkURL(title:attr("href")),
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
