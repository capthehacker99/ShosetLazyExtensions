-- {"id":1567186593,"ver":"1.0.1","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1567186593

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Dragonholic"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://dragonholictranslations.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://dragonholic.com/wp-content/uploads/2024/09/cropped-favicon-32x32.png"
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
local startIndex = 0

--- Shrink the website url down. This is for space saving purposes.
---
--- Required.
---
--- @param url string Full URL to shrink.
--- @param _ int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Shrunk URL.
local function shrinkURL(url, _)
    return url:gsub(".-dragonholictranslations.com/", "")
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
    local htmlElement = document:selectFirst("main .container > .border")
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
    local desc = ""
    map(document:select(".prose p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local title = document:selectFirst("h1")
    title = title and title:text():gsub("\n" ,"") or "Failed to obtain title"
    local img = document:selectFirst(".summary_image img")
    img = img and img:attr("data-src") or imageURL
    local ch_list = document:selectFirst("#chapter-list-container")
    local series_id = ch_list:attr("x-data"):match("seriesId:%s+(%d+)")
    local chapters_doc = dkjson.GET(expandURL("/api/chapters?series_id=" .. series_id .. "&sort_order=asc&per_page=1000000000"))
    local chapters = {}
    for _, v in next, chapters_doc.chapters do
        if not v.is_premium then
            table.insert(chapters, NovelChapter {
                order = tonumber(v.chapter_order) or v.chapter_order,
                title = v.name .. " - " .. (v.subtitle or ""),
                link = novelURL .. "/" .. v.slug .. "/"
            })
        end
    end
    return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = AsList(chapters),
    })
end

local function getListing(data)
    local page = data[PAGE]
    local document = GETDocument(expandURL("/browse/page/" .. page .. "/?sort=new&order=desc"))
    return map(document:select("#series-list-container > div > a"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("data-src") or imageURL
        img = img or imageURL
        return Novel {
            title = v:selectFirst("h3"):text(),
            link = shrinkURL(v:attr("href")),
            imageURL = img
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    if #query < 3 then
        query = query .. (" "):rep(3-#query)
    end
    local data = dkjson.GET(expandURL("/api/search?q=" .. urlEncode(query) .. "&per_page=10&page=" .. page .. "&types[]=series"))
    local novels = {}
    for _, v in next, data.results do
        table.insert(novels, Novel {
            title = v.title,
            link = shrinkURL(v.url),
            imageURL = v.thumbnail or imageURL
        })
    end
    return AsList(novels)
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
