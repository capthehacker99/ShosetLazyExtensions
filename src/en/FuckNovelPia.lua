-- {"id":891819725,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

local id = 891819725
local name = "FuckNovelPia"
local baseURL = "https://fucknovelpia.com/"
local imageURL = "https://fucknovelpia.com/apple-touch-icon.png"
local chapterType = ChapterType.HTML
local startIndex = 1

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

local function shrinkURL(url, _)
    return url:gsub(".-fucknovelpia.com/", ""):gsub("^/", "")
end

local function expandURL(url, _)
    return baseURL .. url
end

local function getPassage(chapterURL)
    local url = expandURL(chapterURL)
    local document = GETDocument(url)
    local content = document:selectFirst("#book-content, .reader")
    return pageOfElem(content, true)
end

local function parseNovel(novelURL)
    local url = expandURL(novelURL)
    local document = GETDocument(url)

    local title = document:selectFirst("h1.hero-title"):text()
    local coverStyle = document:selectFirst(".hero-media .cover"):attr("style")
    local coverURL = coverStyle:match("url%((.-)%)(.*)")
    if not coverURL then
        coverURL = coverStyle:match("url%((.-)%)")
    end

    local descEl = document:selectFirst(".hero-summary")
    local description = descEl and descEl:text() or ""

    local tags = {}
    map(document:select(".tags a"), function(v)
        table.insert(tags, v:text())
    end)

    local chapters = {}
    local chapterLinks = document:select("ul.chapter-list li a")
    map(chapterLinks, function(v)
        local order = #chapters + 1
        local titleEl = v:selectFirst(".chapter-item-main")
        local chTitle = titleEl and titleEl:text() or v:text()
        table.insert(chapters, NovelChapter {
            order = order,
            title = chTitle,
            link = shrinkURL(v:attr("href"))
        })
    end)

    return NovelInfo({
        title = title,
        imageURL = coverURL or "",
        description = description,
        chapters = chapters,
        tags = tags
    })
end

local function getListing(data)
    local document = GETDocument(expandURL("updates.php"))
    return map(document:select("a.update-card"), function(v)
        local img = v:selectFirst("img")
        local copy = v:selectFirst(".copy")
        return Novel {
            title = copy and copy:text() or "",
            link = shrinkURL(v:attr("href")),
            imageURL = img and img:attr("src") or ""
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local url = expandURL("search.php?q=" .. urlEncode(query) .. "&page=" .. page)
    local document = GETDocument(url)
    return map(document:select("article.card-book"), function(v)
        local link = v:selectFirst("a")
        local img = v:selectFirst(".cover img")
        local titleEl = v:selectFirst(".title")
        return Novel {
            title = titleEl and titleEl:text() or (link and link:text() or ""),
            link = shrinkURL(link:attr("href")),
            imageURL = img and img:attr("src") or ""
        }
    end)
end

return {
    id = id,
    name = name,
    baseURL = baseURL,
    listings = {
        Listing("Updates", false, getListing)
    },
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
