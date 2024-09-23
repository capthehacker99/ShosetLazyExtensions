-- {"id":622276777,"ver":"1.0.1","libVer":"1.0.1","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 622276777

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "JP Translations for Fun"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://jptranslation5.wordpress.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://jptranslation5.wordpress.com/wp-content/uploads/2023/10/wp-1698671266386.jpg"
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
    return url:gsub(".-jptranslation5.wordpress.com/", "")
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
    local htmlElement = document:selectFirst(".entry-content")
    htmlElement:select("div, script, span, hr"):remove()
    local found_toc = false;
    map(htmlElement:select("p"), function(v)
        local link = v:selectFirst("a")
        if not link then
            return
        end
        if found_toc then
            v:remove()
            return
        end
        if link:text() == "ToC" then
            found_toc = true;
            v:remove()
        end
    end)
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
    map(document:select(".entry-content > blockquote > p"), function(p)
        desc = desc .. '\n\n' .. p:text()
    end)
    local img = document:selectFirst(".wp-block-image img")
    if img then
        img = img:attr("data-orig-file")
    end
    img = img or imageURL
    local title = document:selectFirst(".entry-title")
    if title then
        title = title:text():gsub("\n" ,"")
    end
    title = title or ""

    return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = AsList(
            map(document:select(".wp-block-list > li > a"), function(v)
                return NovelChapter {
                    title = v:text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )
    })
end

local function getListing()
    local document = GETDocument(baseURL)
    local last_img;
    local found = {}
    local novels = {}
    map(document:select(".entry-content > figure, .entry-content > blockquote"), function(v)
        local img = v:selectFirst("img")
        if img then
            last_img = img
            return
        end
        local link = v:selectFirst("a")
        if not link then
            return
        end
        local actual_link = link:attr("href")
        found[actual_link] = true
        table.insert(novels, Novel {
            title = link:text(),
            link = shrinkURL(actual_link),
            imageURL = last_img and (last_img:attr("data-orig-file") or imageURL) or imageURL
        })
        last_img = nil
    end)
    map(document:select(".menu > .nav-menu > li a"), function(v)
        local text = v:text()
        if text == "About" then
            return
        end
        local link = v:selectFirst("a"):attr("href")
        if found[link] then
            return
        end
        table.insert(novels, Novel {
            title = text,
            link = shrinkURL(link),
            imageURL = imageURL
        })
    end)
    return AsList(novels)
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
