-- {"id":500669541,"ver":"1.0.1","libVer":"1.0.1","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 500669541

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Aries Translation"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://ariestranslation.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://ariestranslation.com/wp-content/uploads/2024/05/Purple-Abstract-A-Letter-Free-Logo.png"
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
    return url:gsub(".-ariestranslation.com/", "")
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
    map(document:select("[itemprop=\"description\"] p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local img = document:selectFirst(".thumbook > .thumb > img")
    img = img and img:attr("src") or imageURL
    local selected = document:select(".eplister > ul > li > a")
    local cur = selected:size() + 1
	return NovelInfo({
        title = document:selectFirst(".entry-title"):text():gsub("\n" ,""),
        imageURL = img,
        description = desc,
        chapters = AsList(
            map(selected, function(v)
                cur = cur - 1
                return NovelChapter {
                    order = cur,
                    title = v:selectFirst(".epl-title"):text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )
    })
end

local function getListing()
    local document = GETDocument(expandURL("series/"))
    return map(document:select("#content .listupd > article .mdthumb > a"), function(v)
        local pic = v:selectFirst("img")
        return Novel {
            title = pic:attr("title"),
            link = shrinkURL(v:attr("href")),
            imageURL = pic:attr("src")
        }
    end)
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

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("page/" .. page .. "/?s=" .. urlEncode(query)))
    return map(document:select("#content .listupd > article .mdthumb > a"), function(v)
        local pic = v:selectFirst("img")
        return Novel {
            title = pic:attr("title"),
            link = shrinkURL(v:attr("href")),
            imageURL = pic:attr("src")
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
