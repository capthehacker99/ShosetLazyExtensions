-- {"id":304044934,"ver":"1.1.0","libVer":"1.1.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
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
    local data = dkjson.decode(document:selectFirst("[data-page]"):attr("data-page"))
    local doc = Document("<body>" .. data.props.chapter.content .. "</body>")
    doc:select(".ad-container"):remove()
    return pageOfElem(doc:selectFirst("body"), true)
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
    local data = dkjson.decode(document:selectFirst("[data-page]"):attr("data-page"))
    local title = data.props.series.title
    local img = data.props.series.cover
    img = img and expandURL("storage/" .. img.path) or imageURL
    local desc = data.props.series.description:gsub("<p>", ""):gsub("</p>", "\n\n"):gsub("<br>", "\n")
    local chapters_data = dkjson.GET(url .. "/chapters?sort_order=asc")
    local chapters = {}
    for i, v in next, chapters_data.chapters do
        table.insert(chapters, NovelChapter {
            order = i,
            title = v.name,
            link = novelURL .. "/" .. v.slug
        })
    end
    return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = AsList(chapters)
    })
end

local function getListing(data)
    local document = GETDocument(expandURL("series?page=" .. data[PAGE]))
    local data = dkjson.decode(document:selectFirst("[data-page]"):attr("data-page"))
    local novels = {}
    for _, novel in next, data.props.seriesList.data do
        local image = imageURL
        if novel.cover and novel.cover.path then
            image = expandURL("storage/" .. novel.cover.path)
        end
        table.insert(novels, Novel {
            title = novel.title,
            imageURL = image,
            link = "series/" .. novel.slug
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
    local document = GETDocument(expandURL("series?order=desc&search=" .. urlEncode(query) .. "&page=" .. page))
    local data = dkjson.decode(document:selectFirst("[data-page]"):attr("data-page"))
    local novels = {}
    for _, novel in next, data.props.seriesList.data do
        local image = imageURL
        if novel.cover and novel.cover.path then
            image = expandURL("storage/" .. novel.cover.path)
        end
        table.insert(novels, Novel {
            title = novel.title,
            imageURL = image,
            link = "series/" .. novel.slug
        })
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
