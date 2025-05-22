-- {"id":626239047,"ver":"1.0.1","libVer":"1.0.1","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 626239047

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "FanFiction"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://www.fanfiction.net/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://www.fanfiction.net/static/icons3/ff-icon-192.png"
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
    return url:gsub(".-fanfiction.net/", "")
end

--- Expand a given URL.
---
--- Required.
---
--- @param url string Shrunk URL to expand.
--- @param _ int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Full URL.
local function expandURL(url, _)
    if url:find("^http") then
        return url
    end
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
    local htmlElement = document:selectFirst("#storytext,#storycontent")
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
    local desc = document:selectFirst("#profile_top div.xcontrast_txt")
    desc = desc and desc:text() or ""
    local title = document:selectFirst("#profile_top b.xcontrast_txt")
    title = title and title:text() or "Unknown Title"
    local img = novelURL:match("#([^#]+)$")
    img = img and expandURL(img) or baseURL
    local chapter_selector = document:selectFirst("#chap_select")
    local left, right;
    if chapter_selector then
        left, right = chapter_selector:attr("onchange"):match("=%s*'([^']*)[^+]*+[^+]*+[^']*'([^']*)'")
    end
    return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = chapter_selector and AsList(
            map(chapter_selector:select("option"), function(v)
                local idx = v:attr("value")
                return NovelChapter {
                    order = idx,
                    title = v:text(),
                    link = shrinkURL(left .. idx .. right)
                }
            end)
        ) or {
            NovelChapter {
                order = 0,
                title = title,
                link = novelURL
            }
        }
    })
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

local function getListing()
    local document = GETDocument(expandURL("j/0/0/0/"))

    return map(document:select("#content_wrapper_inner .z-list > a.stitle"), function(v)
        local img = v:selectFirst("img")
        if img then
            local imgo = img:attr("data-original")
            if not imgo or #imgo <=0 then
                imgo = img:attr("src")
            end
            img = imgo
        else
            img = imageURL
        end
        return Novel {
            title = v:text(),
            link = shrinkURL(v:attr("href") .. "#".. urlEncode(img)),
            imageURL = expandURL(img)
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("search/?keywords=" .. urlEncode(query) ..  "&ready=1&type=story&ppage=" .. page))
    return map(document:select("#content_wrapper_inner .z-list > a.stitle"), function(v)
        local img = v:selectFirst("img")
        if img then
            local imgo = img:attr("data-original")
            if not imgo or #imgo <=0 then
                imgo = img:attr("src")
            end
            img = imgo
        else
            img = imageURL
        end
        return Novel {
            title = v:text(),
            link = shrinkURL(v:attr("href") .. "#".. urlEncode(img)),
            imageURL = expandURL(img)
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
    hasSearch = true,
    isSearchIncrementing = true,
    search = search,
    hasCloudFlare = true,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
