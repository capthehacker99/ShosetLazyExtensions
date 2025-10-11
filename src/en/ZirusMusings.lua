-- {"id":2069673422,"ver":"1.0.2","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 2069673422

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Ziru's Musings"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://www.zirusmusings.net/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://www.zirusmusings.net/images/nextImageExportOptimizer/logo-opt-320.WEBP"
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
    return url:gsub(".-zirusmusings.net/", "")
end

--- Expand a given URL.
---
--- Required.
---
--- @param url string Shrunk URL to expand.
--- @param _ int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Full URL.
local function expandURL(url, _)
    if url:find("^/") then
        return baseURL:sub(1, #baseURL - 1) .. url
    end
	return baseURL .. url
end

local function attribContains(attrib, substr)
    return function(element)
        local className = element:attr(attrib)
        return className ~= nil and className:find(substr) ~= nil
    end
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
    return pageOfElem(first(document:select("div"), attribContains("class", "Chapter_chapterText_")), true)
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
    local summaryContainerElem = first(document:select("div"), attribContains("class", "Series_seriesSummary"))
    local desc = ""
    if summaryContainerElem then
        map(summaryContainerElem:select("summaryContainerElem p"), function(p)
            desc = desc .. '\n\n' .. p:text()
        end)
    end
    local dataElem = document:selectFirst("script[id=\"__NEXT_DATA__\"]")
    if not dataElem then
        error("Novel data not found")
    end
    local coverElem = first(document:select("img"), attribContains("alt", "Series Cover"))
    local coverLink = expandURL(coverElem and coverElem:attr("src") or imageURL)
    local data = dkjson.decode(string.match(tostring(dataElem), "%b{}"))
    data = data.props.pageProps.data
    local chapters = {}
    local idx = 0
    for volIdx, vol in next, data.volumes do
        for chIdx, ch in next, vol.chapters do
            table.insert(chapters, NovelChapter {
                order = idx;
                title = "Vol. " .. tonumber(volIdx) .. " Ch. " .. tonumber(chIdx) .. " - " .. (ch.title or ch.subsubtitle);
                link = novelURL .. "/" .. ch.volume .. "/" .. ch.chapter;
            })
            idx = idx + 1
        end
    end
	return NovelInfo({
        title = data.name,
        imageURL = coverLink,
        description = desc,
        chapters = AsList(chapters)
    })
end

local function getListing()
    local document = GETDocument(expandURL("series"))
    local novels = {}
    local dataElem = document:selectFirst("script[id=\"__NEXT_DATA__\"]")
    if not dataElem then
        error("Novel data not found")
    end
    local data = dkjson.decode(string.match(tostring(dataElem), "%b{}"))
    data = data.props.pageProps.seriesData
    for _, v in next, data do
        table.insert(novels, Novel {
            title = v.name;
            link = "series/" .. v.seriesID;
            imageURL = expandURL(v.cover);
        })
    end
    return novels
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
