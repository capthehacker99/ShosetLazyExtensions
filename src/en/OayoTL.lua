-- {"id":114035263,"ver":"1.1.0","libVer":"1.1.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
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
local imageURL = "https://www.oayo.ink/favicon.ico"
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
	local data = dkjson.GET(chapterURL)
    local html = "<body>"
    local function populatePassage(x)
        for k, v in next, x do
            if k == "text" then
                html = html .. "<p>" .. v .. "</p>"
            end
            if type(v) == "table" then
                populatePassage(v)
            end
        end
    end
    populatePassage(data)
    return pageOfElem(Document(html .. "</body>"):selectFirst("body"), true)
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
    local data = dkjson.GET(novelURL .. "?populate[novel_chapters][sort][0]=num_chapter:asc").data.attributes
    local desc = ""
    local function populateDesc(x)
        for k, v in next, x do
            if k == "text" then
                desc = desc .. v .. "\n\n"
            end
            if type(v) == "table" then
                populateDesc(v)
            end
        end
    end
    populateDesc(data.text_synopsis)
    local chapters = {}
    for _, v in next, data.novel_chapters.data do
        table.insert(chapters, NovelChapter {
            order = v.attributes.num_chapter,
            title = v.attributes.name_chapter,
            link = "https://api.oayo.ink/api/novel-chapters/" .. v.id
        })
    end
	return NovelInfo({
        title = data.name_set,
        authors = { data.name_author or "Unknown" },
        description = desc,
        imageURL = imageURL,
        chapters = AsList(
            chapters
        )
    })
end

local function getListing(data)
    local novel_data = dkjson.GET("https://api.oayo.ink/api/novel-sets/?sort[0]=updatedAt:desc&populate[novel_chapters][fields][0]=id&populate[novel_chapters][fields][1]=name_chapter&populate[novel_chapters][fields][2]=num_chapter&populate[novel_chapters][fields][3]=publishedAt&pagination[page]=" ..  data[PAGE] .. "&pagination[pageSize]=12")
    local novels = {}
    for _, novel in next, novel_data.data do
        table.insert(novels, Novel {
            title = novel.attributes.name_set,
            link = "https://api.oayo.ink/api/novel-sets/" .. novel.id,
            imageURL = imageURL
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
        Listing("Default", true, getListing)
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
