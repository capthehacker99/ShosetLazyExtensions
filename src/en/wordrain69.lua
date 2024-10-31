-- {"id":1085294623,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1085294623

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "wordrain69"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://wordrain69.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://wordrain69.com/storage/2024/06/cropped-IMG_20240623_094303.png"
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
    return url:gsub(".-wordrain69.com/", "")
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
    map(document:select(".manga-summary p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local title = document:selectFirst(".post-title h1")
    title = title and title:text():gsub("\n" ,"") or "Failed to obtain title"
    local img = document:selectFirst(".summary_image img")
    img = img and img:attr("src") or imageURL
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
    local page = data[PAGE]
    local doc = GETDocument(expandURL("page/" .. page .. "/"))
    return map(doc:select("#loop-content .page-item-detail > div > a"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("src") or imageURL
        return Novel {
            title = v:attr("title"),
            link = shrinkURL(v:attr("href")),
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
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
