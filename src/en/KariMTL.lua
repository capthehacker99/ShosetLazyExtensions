-- {"id":1440948051,"ver":"1.0.5","libVer":"1.0.5","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1440948051

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Kari MTL"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://karistudio.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://karimtl.com/wp-content/uploads/2023/11/cropped-pngwing.com_-1.png"

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
    return url:gsub(".-karistudio.com/", "")
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
    local htmlElement = document:selectFirst(".bs-blog-post")
    htmlElement:select("#donation-msg, #novel_nav"):remove()
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
    local img = document:selectFirst("#novel_cover")
    img = img and img:attr("src") or imageURL
    local desc = document:selectFirst(".desc_div")
    if desc then
        local full_str = ""
        map(desc:select("p"), function(p)
            full_str = full_str .. '\n' .. p:text()
        end)
        desc = full_str
    end
    local selected = document:select(".novel_index > a")
    local cur = selected:size() + 1
	return NovelInfo({
        title = document:selectFirst(".title"):text():gsub("\n" ,""),
        imageURL = img,
        description = desc,
        chapters = AsList(
            map(filter(selected, function(v)
                return v:attr("href"):find("karistudio.com") ~= nil
            end), function(v)
                cur = cur - 1;
                return NovelChapter {
                    order = cur,
                    title = v:text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )

    })
end

local function getListing()
    local document = GETDocument(expandURL("novels/"))
    return map(document:select(".novel-list > .novel-item"), function(v)
        return Novel {
            title = v:selectFirst("p"):text(),
            link = shrinkURL(v:attr("href")),
            imageURL = v:selectFirst("img"):attr("src")
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
