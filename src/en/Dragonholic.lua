-- {"id":1567186593,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

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
local baseURL = "https://dragonholic.com/"

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
    return url:gsub(".-dragonholic.com/", "")
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
    htmlElement:select(".chapter-warning"):remove()
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
    map(document:select(".summary__content p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local title = document:selectFirst(".post-title h1")
    title = title and title:text():gsub("\n" ,"") or "Failed to obtain title"
    local img = document:selectFirst(".summary_image img")
    img = img and img:attr("data-src") or imageURL
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
    local form = FormBodyBuilder()
            :add("action", "madara_load_more")
            :add("page", page)
            :add("template", "madara-core/content/content-archive")
            :add("vars[paged]", "1")
            :add("vars[orderby]", "meta_value_num")
            :add("vars[template]", "archive")
            :add("vars[sidebar]", "full")
            :add("vars[post_type]", "wp-manga")
            :add("vars[post_status]", "publish")
            :add("vars[meta_key]", "_latest_update")
            :add("vars[order]", "desc")
            :add("vars[meta_query][relation]", "AND")
            :add("vars[manga_archives_item_layout]", "big_thumbnail")
        :build()
    local document = RequestDocument(POST(expandURL("wp-admin/admin-ajax.php"), DEFAULT_HEADERS(), form))
    return map(document:select("[title]"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("data-src") or imageURL
        img = img or imageURL
        return Novel {
            title = v:attr("title"),
            link = shrinkURL(v:attr("href")),
            imageURL = img
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local form = FormBodyBuilder()
        :add("action", "madara_load_more")
        :add("page", page)
        :add("template", "madara-core/content/content-search")
        :add("vars[s]", query)
        :add("vars[orderby]", "")
        :add("vars[paged]", "1")
        :add("vars[template]", "search")
        :add("vars[meta_query][0][relation]", "AND")
        :add("vars[meta_query][relation]", "AND")
        :add("vars[post_type]", "wp-manga")
        :add("vars[post_status]", "publish")
        :add("vars[manga_archives_item_layout]", "big_thumbnail")
        :build()
    local document = RequestDocument(POST(expandURL("wp-admin/admin-ajax.php"), DEFAULT_HEADERS(), form))
    return map(document:select("[title]"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("data-src") or imageURL
        img = img or imageURL
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
    hasSearch = true,
    isSearchIncrementing = true,
    search = search,
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
