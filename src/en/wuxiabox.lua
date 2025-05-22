-- {"id":469256382,"ver":"1.0.2","libVer":"1.0.2","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 469256382

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "WuxiaBox"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://www.wuxiabox.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://www.wuxiabox.com/d/img/logo.png"
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
    return url:gsub(".-wuxiabox.com/", "")
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
    local htmlElement = document:selectFirst(".chapter-content")
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
    local img = document:select(".cover img")
    local title = document:select(".novel-title")
    local desc = ""
    map(document:select(".summary .content p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local doc_str = tostring(document)
    local max_page = 0
    for p in doc_str:gmatch("\"/e/extend/[a-z0-9]+%.php%?page=([0-9]+)&a?m?p?;?wjm=[a-zA-Z0-9-]+\"") do
        local cur_page = tonumber(p)
        if cur_page > max_page then
            max_page = cur_page
        end
    end
    local part_a, part_b = tostring(document):match("\"/(e/extend/[a-z0-9]+.php%?page=)[0-9]+&a?m?p?;?(wjm=[a-zA-Z0-9-]+)\"")
    local chapters = {}
    local function request_chapter(page)
        local doc = GETDocument(expandURL(part_a .. page .. '&' .. part_b))
        local selected = doc:select(".chapter-list a")
        map(selected, function(v)
            local title = v:selectFirst(".chapter-title")
            title = title and title:text() or v:attr("title")
            table.insert(chapters, NovelChapter {
                order = cur,
                title = title,
                link = shrinkURL(v:attr("href"))
            })
        end)
    end
    for i = 0, max_page do
        request_chapter(i)
    end
	return NovelInfo({
        title = title:text():gsub("\n" ,""),
        imageURL = expandURL(img:attr("data-src")),
        description = desc,
        chapters = chapters
    })
end

local function getListing()
    local document = GETDocument(baseURL)

    return map(document:select(".novel-item > a"), function(v)
        return Novel {
            title = v:attr("title"),
            link = shrinkURL(v:attr("href")),
            imageURL = expandURL(v:selectFirst("img"):attr("data-src"))
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    print("SEARCH " .. query)
    local url = expandURL("e/search/index.php?page=" .. page)
    local document = RequestDocument(POST(url, DEFAULT_HEADERS(), FormBodyBuilder():add("show", "title")
        :add("tempid", "1")
        :add("tbname", "news")
        :add("keyboard", query)
        :build()))
    return map(document:select(".novel-item > a"), function(v)
        return Novel {
            title = v:attr("title"),
            link = shrinkURL(v:attr("href")),
            imageURL = expandURL(v:selectFirst("img"):attr("data-src"))
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
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
