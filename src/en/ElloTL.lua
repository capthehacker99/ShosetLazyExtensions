-- {"id":1584024299,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1584024299

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "ElloTL"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://ellotl.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://i3.wp.com/ellotl.com/wp-content/uploads/2024/03/cropped-ello-logo-final-1-192x192.png"

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
    return url:gsub(".-ellotl.com/", "")
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
    local htmlElement = document:selectFirst(".entry-content");
    htmlElement:select(".wp-block-buttons, .wp-block-button, .has-background.has-white-color"):remove();
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
    local img = document:selectFirst(".thumb > img")
    img = img and img:attr("src") or imageURL
    local title = document:selectFirst(".entry-title")
    title = title and title:text():gsub("\n" ,"") or "FAILED TO OBTAIN TITLE"
    local chapters = document:select(".eplisterfull > ul > li > a")
    local i = chapters:size() + 1;
    return NovelInfo({
        title = title,
        imageURL = img,
        chapters = AsList(
            map(chapters, function(v)
                i = i - 1;
                local title = v:selectFirst(".epl-title");
                return NovelChapter {
                    order = i,
                    title = (title and title:text() or "UNKNOWN TITLE"),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )
    })
end

local function getListing()
    local document = GETDocument(baseURL .. "/series")

    return AsList(map(document:select(".maindet > .inmain > .mdthumb > a"), function(v)
        local img = v:selectFirst("img");
        return Novel {
            title = (v:attr("oldtitle") or ""):gsub("[\r\n]", ""),
            link = shrinkURL(v:attr("href")),
            imageURL = (img and img:attr("src") or imageURL)
        }
    end))
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("page/" .. page .. "/?s=" .. query))
    return AsList(map(document:select(".maindet > .inmain > .mdthumb > a"), function(v)
        local img = v:selectFirst("img");
        return Novel {
            title = (v:attr("oldtitle") or ""):gsub("[\r\n]", ""),
            link = shrinkURL(v:attr("href")),
            imageURL = (img and img:attr("src") or imageURL)
        }
    end))
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
    hasSearch = true,
    isSearchIncrementing = true,
    search = search,
    -- Optional values to change
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
