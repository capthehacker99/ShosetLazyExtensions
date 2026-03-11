-- {"id":568428406,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 568428406

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Gadgetized Panda Translation"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://gadgetizedpanda.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://gadgetizedpanda.com/wp-content/uploads/2023/06/oig.png?w=1024"
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
    return url:gsub(".-gadgetizedpanda.com/", "")
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

local blacklists = {
    "^Ko%-fi link",
    "^link for more information",
    "^Latest Updates",
    "^%[email protected%]",
    "^List of",
    "^projects",
    "^Personal Projects",
    "^Completed/On%-Hold/Caught%-Up",
    "^Amazon Link",
    "^↩︎"
}

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
    local stage = 0
    map(document:select(".entry-content p"), function(p)
        if stage == 0 then
            local text = p:text()
            if text:find("Synopsis") then
                stage = 1
            end
            return
        end
        if stage == 1 then
            local class = p:attr("class")
            if class:find("large%-font") then
                stage = 2
                return
            end
            desc = desc .. '\n' .. p:text()
        end
    end)
    local selected = document:select(".entry-content a")
	return NovelInfo({
        title = document:selectFirst(".entry-title"):text():gsub("\n" ,""),
        imageURL = imageURL,
        description = desc,
        chapters = AsList(
            mapNotNil(selected, function(v)
                local title = v:text()
                for _, black in next, blacklists do
                    if title:find(black) then
                        return
                    end
                end
                local link = v:attr("href")
                if link:find("ko%-fi") or link:find("announcement%-translation%-requests%-open") then
                    return
                end
                return NovelChapter {
                    order = v,
                    title = title,
                    link = shrinkURL(link)
                }
            end)
        )

    })
end

local function getListing(data)
    local page = data[PAGE]
    local document = GETDocument(expandURL("page/" .. page))

    local novels = {}

    map(document:select("#main p a, #main figure > a"), function(v)
        local label = v:text()
        for _, black in next, blacklists do
            if label:find(black) then
                return
            end
        end
        local link = v:attr("href")
        if #label ~= 0 and not novels[link] then
            novels[link] = {label, imageURL}
        end
        local img = v:selectFirst("img")
        if img then
            if novels[link] then
                novels[link][2] = img:attr("src")
            end
        end
    end)
    local novel_list = {}
    for k, v in next, novels do
        table.insert(novel_list, Novel {
            title = v[1],
            link = shrinkURL(k),
            imageURL = v[2]
        })
    end
    return AsList(novel_list)
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
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
