-- {"id":28508335,"ver":"1.0.1","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
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
    local htmlElement = document:selectFirst("#chapter-content")
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
    local title = document:selectFirst("meta[property=\"og:title\"]")
    title = title and title:attr("content") or "Unknown Title"
    -- local img = document:selectFirst(".summary_image img")
    -- img = img and (img:attr("src") or img:attr("data-src")) or imageURL
    local img = imageURL
    local desc = document:selectFirst("meta[property=\"og:description\"]")
    desc = desc and desc:attr("content") or ""

    return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = AsList(
            map(document:select(".chapter-group__list a"), function(v)
                return NovelChapter {
                    order = v,
                    title = v:text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )
    })
end

local function getListing(data)
    local data = dkjson.GET(expandURL("wp-json/wp/v2/fcn_story?per_page=100&_fields=link,title&offset=" .. data[PAGE] * 100))
    local novels = {}
    for _, v in next, data do
        table.insert(novels, Novel {
            title = v.title.rendered,
            link = shrinkURL(v.link),
            imageURL = imageURL
        })
    end
    return novels
end

local function urlEncode(str)
    if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-%_%.%~])", function(c)
            return ("%%%02X"):format(string.byte(c))
        end)
        str = str:gsub(" ", "+")
    end
    return str
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local data = dkjson.GET(expandURL("wp-json/wp/v2/search?search=" .. urlEncode(query) .. "&per_page=100&_fields=url,title,subtype&offset=" .. data[PAGE] * 100))
    local novels = {}
    for _, v in next, data do
        if v.subtype == "fcn_story" then
            table.insert(novels, Novel {
                title = v.title,
                link = shrinkURL(v.url),
                imageURL = imageURL
            })
        end
    end
    return novels
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
