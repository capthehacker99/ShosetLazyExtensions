-- {"id":472808831,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}
local json = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 472808831

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Ranobes"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://ranobes.top/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://ranobes.top/templates/Dark/images/favicon.ico"
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
    return url:gsub(".-ranobes.top/", "")
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
    local htmlElement = document:selectFirst("#arrticle")
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
    local chapters_link = document:selectFirst(".read-continue"):attr("href")
    local chapters = {}
    local high = 100000
    local max_page = 0
    local first_page = GETDocument(expandURL(chapters_link))
    local function add_chapters(page)
        local data;
        map(page:select("script"), function(v)
            if data then
                return
            end
            local match = tostring(v):match("window.__DATA__ = %b{}")
            if not match then
                return
            end
            data = json.decode(match:sub(18))
        end)
        if not data then
            error("Failed to find chapter data.")
        end
        max_page = math.max(max_page, data.pages_count)
        for _, v in next, data.chapters do
            table.insert(chapters, NovelChapter {
                order = high,
                title = v.title,
                link = shrinkURL(v.link)
            })
            high = high - 1
        end
    end
    add_chapters(first_page)
    for i = 2, max_page do
        add_chapters(GETDocument(expandURL(chapters_link .. "page/" .. i .. "/")))
    end
	return NovelInfo({
        title = document:selectFirst("h1.title"):text():gsub("\n" ,""),
        imageURL = document:selectFirst(".poster img"):attr("src"),
        description = document:selectFirst("[itemprop=\"description\"]"):text(),
        chapters = chapters
    })
end

local function getListing(data)
    local page = data[PAGE]
    local document = GETDocument(expandURL("novels/page/" .. page .."/"))

    return map(document:select("article"), function(v)
        local title = v:selectFirst(".title a")
        local link = v:selectFirst(".cover"):attr("style"):match("url%b()")
        link = link:sub(5, #link - 1)
        return Novel {
            title = title:text(),
            link = shrinkURL(title:attr("href")),
            imageURL = link
        }
    end)
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
    local document = GETDocument(expandURL("search/" .. urlEncode(query) .. "/page/" .. page .. "/"))
    return map(document:select("article"), function(v)
        local title = v:selectFirst(".title a")
        local link = v:selectFirst(".cover"):attr("style"):match("url%b()")
        link = link:sub(5, #link - 1)
        return Novel {
            title = title:text(),
            link = shrinkURL(title:attr("href")),
            imageURL = link
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
