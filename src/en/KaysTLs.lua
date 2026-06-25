-- {"id":1343493282,"ver":"1.0.3","libVer":"1.0.2","author":"","repo":"","dep":[]}
local json = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1343493282

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "The Kay's rookie translations"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://kaystls.site/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://kaystls.site/wp-content/uploads/2021/07/cropped-Picture1-1-192x192.png"
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
    return url:gsub(".-kaystls.site/", "")
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
    local htmlElement = document:selectFirst("article > .entry-content > .wp-block-columns")
    htmlElement:select(".donate"):remove()
    htmlElement:select("h3 > a"):remove()
    htmlElement:select(".code-block"):remove()
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
    local header = document:selectFirst("main .wp-block-column > h1")
	return NovelInfo({
        title = header:text():gsub("\n" ,""),
        imageURL = imageURL,
        chapters = AsList(map(filter(document:select("nav > ul > li > a"),function(v)
            return v:selectFirst("img") == nil
        end), function(v)
            return NovelChapter {
                order = v,
                title = v:text(),
                link = shrinkURL(v:attr("href"))
            }
        end))
    })
end

local nonce;

local function getListing(data)
    if not nonce then
        local doc = GETDocument(expandURL("browse/"))
        nonce = doc:selectFirst("[data-nonce]"):attr("data-nonce")
    end
    local page = data[PAGE]
    local form = FormBodyBuilder()
        :add("status", "all")
        :add("page", page)
        :add("sort", "popular")
        :add("action", "kay_browse_query")
        :add("_wpnonce", nonce)
        :build()
    local req = Request(POST(expandURL("wp-admin/admin-ajax.php"), DEFAULT_HEADERS(), form))
    local str = req:body():string()
    local data = json.decode(str)
    local doc = Document(data.html)
    return map(doc:select("article"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("data-src") or imageURL
        img = img or imageURL
        local link = v:selectFirst(".kay-card-title > a")
        return Novel {
            title = link:text(),
            link = shrinkURL(link:attr("href")),
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
    hasSearch = false,
	-- Optional values to change
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
