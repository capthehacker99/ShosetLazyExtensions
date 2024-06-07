-- {"id":114035263,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 114035263

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "OayoTL"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://oayo.ink/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://oayo0.wordpress.com/wp-content/uploads/2024/05/site-logo.png?w=512"
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
    return url:gsub(".-oayo.ink/", ""):gsub(".-oayo0.wordpress.com/", "")
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
    document:select("script"):remove()
    local img = document:selectFirst(".wp-block-image img")
    local max_page = 1;
    map(document:select(".wp-block-query-pagination-numbers a"), function(v)
        local cur_page = tonumber(v)
        if cur_page and cur_page > max_page then
            max_page = cur_page
        end
    end)
    local function get_chapters(document)
        return map(document:select(".wp-block-post-template li a"), function(v)
            return NovelChapter {
                order = v,
                title = v:text(),
                link = shrinkURL(v:attr("href"))
            }
        end)
    end
    local chapters = {}
    for i = 1, max_page do
        local cur_chaps = get_chapters(GETDocument(url .. "?query-9-page=" .. i))
        for j = 1, #cur_chaps do
            table.insert(chapters, cur_chaps[j])
        end
    end
    for i = 1, math.floor(#chapters/2) do
        local j = #chapters - i + 1
        chapters[i], chapters[j] = chapters[j], chapters[i]
    end
	return NovelInfo({
        title = document:selectFirst(".wp-block-heading strong"):text():gsub("\n" ,""),
        imageURL = img and img:attr("src") or imageURL,
        chapters = AsList(
            chapters
        )
    })
end

local function getListing()
    local document = GETDocument(baseURL)
    return map(filter(document:select(".wp-block-navigation a"), function(v)
        return v:attr("href") ~= "https://oayo.ink/notice/"
    end), function(v)
        return Novel {
            title = v:selectFirst("span"):text(),
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
	-- Optional values to change
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
