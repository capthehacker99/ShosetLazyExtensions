-- {"id":610947673,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 610947673

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Read Fanfic"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://readfanfic.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://readfanfic.com/wp-content/uploads/2022/07/cropped-favicon-read-fanfic-1-192x192.jpeg"
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
    return url:gsub(".-readfanfic.com/", "")
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
    local img = document:selectFirst(".summary_image img")
    img = img and img:attr("data-src") or imageURL
    local desc = ""
    map(document:select(".description-summary p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local manga_id = tostring(document):match("manga_id\":\"(%d+)")
    local chapters_doc = RequestDocument(POST(expandURL("wp-admin/admin-ajax.php"), DEFAULT_HEADERS(), FormBodyBuilder():add("action", "manga_get_chapters"):add("manga", manga_id):build()))
    local selected = chapters_doc:select(".wp-manga-chapter a")
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
    local page = data[PAGE]
    local form = FormBodyBuilder()
            :add("action", "madara_load_more")
            :add("page", page)
            :add("template", "madara-core/content/content-archive")
            :add("vars[paged]", "1")
            :add("vars[orderby]", "meta_value_num")
            :add("vars[template]", "archive")
            :add("vars[sidebar]", "full")
            :add("vars[post_type]", "wp-manga")
            :add("vars[post_status]", "publish")
            :add("vars[meta_key]", "_latest_update")
            :add("vars[order]", "desc")
            :add("vars[meta_query][relation]", "AND")
            :add("vars[manga_archives_item_layout]", "big_thumbnail")
        :build()
    local document = RequestDocument(POST(expandURL("wp-admin/admin-ajax.php"), DEFAULT_HEADERS(), form))
    return map(document:select("[title]"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("data-src") or imageURL
        img = img or imageURL
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
    return map(document:select(".tab-content-wrap > div > .row"), function(v)
        local img = v:selectFirst(".tab-thumb img")
        img = img and (img:attr("data-src") or img:attr("src")) or imageURL
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
