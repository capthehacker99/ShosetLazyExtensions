-- {"id":636374773,"ver":"1.0.1","libVer":"1.0.1","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 636374773

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "MyDramaNovel"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://mydramanovel.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://mydramanovel.com/wp-content/uploads/2024/10/MyDramaNovel-e1728301732121.webp"
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
    return url:gsub(".-mydramanovel.com/", "")
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
    return pageOfElem(document:selectFirst(".tdb_single_content"), true)
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
    local title = document:select(".tdb-title-text")
    title = title and title:text() or nil

    local desc = ""
    map(document:select(".td_block_wrap > .tdb-block-inner > p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local found = {}

    return NovelInfo({
        title = title,
        imageURL = imageURL,
        description = desc,
        chapters = mapNotNil(document:select(".td-module-meta-info .entry-title > a, .wpb_wrapper .td_block_inner > .td-cpt-post h3 > a"), function(v)
            local link = shrinkURL(v:attr("href"))
            if found[link] then
                return nil
            end
            found[link] = true
            return NovelChapter {
                order = v,
                title = v:text(),
                link = link
            }
        end)
    })
end

local function getListing()
    local document = GETDocument(expandURL("novels/"))

    return map(document:select(".td-ct-wrap > .td-ct-item"), function(v)
        return Novel {
            title = v:selectFirst(".td-ct-item-name"):text(),
            link = shrinkURL(v:attr("href")),
            imageURL = imageURL
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
    hasSearch = false,
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
