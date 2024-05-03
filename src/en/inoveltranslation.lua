-- {"id":516385957,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}
local json = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 516385957

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "inoveltranslation"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://inoveltranslation.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://inoveltranslation.com/favicon.ico"
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
    return url:gsub(".-inoveltranslation.com/", "")
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
	local url = "https://api.inoveltranslation.com/" .. chapterURL
    local data = json.GET(url)
    local src = "<h1>" .. (data.title or "") .. "</h1><p>" .. (data.notes or "") .. "</p>"
    for token in string.gmatch(data.content or "", "[^\n]+") do
        if token ~= "" then
            src = src .. "<p>" .. token .. "</p>"
        end
    end
    return pageOfElem(Document(src), true)
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
    local novel_info = json.GET("https://api.inoveltranslation.com/" .. novelURL)
	local chapter_list = json.GET("https://api.inoveltranslation.com/" .. novelURL .. "/feed")
    local chapters = {}
    if chapter_list.chapters then
        for _, chapter in pairs(chapter_list.chapters) do
            if not chapter.tierId then
                table.insert(chapters, NovelChapter {
                    order = chapter.id,
                    title = "Vol. " .. chapter.volume .. " Ch. " .. chapter.chapter .. ' ' .. chapter.title,
                    link = "chapters/" .. chapter.id
                })
            end
        end
    end
    return NovelInfo({
        title = novel_info.title,
        imageURL = novel_info.cover and ("https://api.inoveltranslation.com/image/" .. novel_info.cover.filename) or (baseURL .. "placeholder.png"),
        chapters = chapters
    })
end

local function getListing()
    local novels = json.GET("https://api.inoveltranslation.com/novels")
    local return_value = {}
    for _, novel in pairs(novels.novels) do
        table.insert(return_value,  Novel {
            title = novel.title,
            link = "novels/" .. novel.id,
            imageURL = novel.cover and ("https://api.inoveltranslation.com/image/" .. novel.cover.filename) or (baseURL .. "placeholder.png")
        })
    end
    return return_value
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
