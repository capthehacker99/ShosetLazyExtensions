-- {"id":472808831,"ver":"1.0.4","libVer":"1.0.4","author":"","repo":"","dep":[]}
local json = Require("dkjson")
local DELAY_AMOUNT = 1250
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
local baseURL = "https://ranobes.net/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://ranobes.net/templates/Dark/images/favicon.ico"
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
    return url:gsub(".-ranobes.net/", "")
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
    if document:selectFirst("#content > .cf-turnstile") then
        error("Antiflood triggered, please resolve in webview")
    end
    local htmlElement = document:selectFirst("#arrticle")
    return pageOfElem(htmlElement, true)
end

local function expandIfNeeded(link)
    if link:sub(1, 1) == "/" then
        return expandURL(link)
    end
    return link
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
    if document:selectFirst("#content > .cf-turnstile") then
        error("Antiflood triggered, please resolve in webview")
    end
    local genres = {}
    map(document:select("#mc-fs-genre .links > a"), function(v)
        table.insert(genres, v:text())
    end)
    local tags = {}
    map(document:select("#mc-fs-keyw .links a"), function(v)
        table.insert(tags, v:text())
    end)
    local authors = {}
    map(document:select("[itemprop=\"creator\"] > a"), function(v)
        table.insert(authors, v:text())
    end)
    local chapters_link = document:selectFirst(".read-continue"):attr("href")
    local chapters = {}
    local high = 100000
    local max_page = 0
    delay(DELAY_AMOUNT)
    local first_page = GETDocument(expandURL(chapters_link))
    local function add_chapters(page)
        if page:selectFirst("#content > .cf-turnstile") then
            return
        end
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
            return true
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
    delay(DELAY_AMOUNT)
    add_chapters(first_page)
    for i = 2, max_page do
        delay(DELAY_AMOUNT)
        if add_chapters(GETDocument(expandURL(chapters_link .. "page/" .. i .. "/"))) then
            break
        end
    end
	return NovelInfo({
        title = document:selectFirst("h1.title"):text():gsub("\n" ,""),
        imageURL = expandIfNeeded(document:selectFirst(".poster img"):attr("src")),
        description = document:selectFirst(".r-desription .cont-text,[itemprop=\"description\"]"):text(),
        chapters = chapters,
        genres = genres,
        tags = tags,
        authors = authors
    })
end

local function getListing(data)
    local page = data[PAGE]
    local document = GETDocument(expandURL("novels/page/" .. page .."/"))
    if document:selectFirst("#content > .cf-turnstile") then
        error("Antiflood triggered, please resolve in webview")
    end
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
    if document:selectFirst("#content > .cf-turnstile") then
        error("Antiflood triggered, please resolve in webview")
    end
    return mapNotNil(document:select("article"), function(v)
        local title = v:selectFirst(".title a")
        if title then
            local link = v:selectFirst(".cover"):attr("style"):match("url%b()")
            link = link:sub(5, #link - 1)
            return Novel {
                title = title:text(),
                link = shrinkURL(title:attr("href")),
                imageURL = link
            }
        end
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
    hasCloudFlare = true,
    isSearchIncrementing = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
