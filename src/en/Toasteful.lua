-- {"id":1707688905,"ver":"1.0.2","libVer":"1.0.2","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1707688905

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Toasteful"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://www.toasteful.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://www.toasteful.com/favicon.ico"

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
    return url:gsub(".-toasteful.com/", "")
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
    local htmlElement = document:selectFirst("[itemprop=\"blogPost\"]")
    htmlElement:select(".ChapterNav"):remove()
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
    document:select("script"):remove()
    local img = document:selectFirst(".entry-content a > img")
    img = img and img:attr("src") or imageURL
    local title = document:selectFirst(".post-title > span")
    if title then
        title = title:text():gsub("\n" ,"")
    else
        title = "FAILED TO OBTAIN TITLE"
    end
        return NovelInfo({
            title = title,
            imageURL = img,
            chapters = AsList(
                map(filter(document:select(".entry-content div > a"), function(v)
                    return v:attr("href"):find(".html") ~= nil
                end), function(v)
                    return NovelChapter {
                        order = v,
                        title = v:text(),
                        link = shrinkURL(v:attr("href"))
                    }
                end)
            )

        })
    end

local function getListing()
    local document = GETDocument(baseURL .. "p/list-novel.html")

    return map(filter(document:select(".entry-content a"), function(v)
        local text = v:text()
        return text ~= "Report Error!"
    end), function(v)
        return Novel {
            title = v:text():gsub("[\r\n]", ""),
            link = shrinkURL(v:attr("href")),
            imageURL = imageURL
        }
    end)
end

local function search(data)
    local query = data[QUERY]
    local doc = GETDocument(expandURL("search?q=" .. query))
    return AsList(map(doc:select(".post-title > a"), function(tag)
        return Novel {
            title = tag:text(),
            link = shrinkURL(tag:attr("href")),
            imageURL = imageURL
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
    isSearchIncrementing = false,
    search = search,
	-- Optional values to change
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
