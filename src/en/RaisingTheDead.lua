-- {"id":1658695508,"ver":"1.0.3","libVer":"1.0.3","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1658695508

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Raising The Dead"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://rtd.moe/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://d2fcrrxq70ovip.cloudfront.net/wp-content/uploads/2018/03/cropped-54060-e1521967394198-4-192x192.jpg"
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
    return url:gsub(".-rtd.moe/", "")
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
    local htmlElement = document:selectFirst("main")
    htmlElement:select(".flex.justify-center.items-center.text-center"):remove()
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
    -- if document:selectFirst(".postsby") then
    --     -- It's a category, fuck it.
    --     local selected = document:select("article header h2 a")
    --     local cur = selected:size() + 1
    --     return NovelInfo({
    --         title = document:selectFirst(".postsby span span"):text():gsub("\n" ,""),
    --         imageURL = imageURL,
    --         description = "",
    --         chapters = AsList(
    --             map(selected, function(v)
    --                 cur = cur - 1
    --                 return NovelChapter {
    --                     order = cur,
    --                     title = v:text(),
    --                     link = shrinkURL(v:attr("href"))
    --                 }
    --             end)
    --         )
    --     })
    -- end
    local desc = ""
    map(document:select(".novel-description p"), function(v)
        desc = desc .. v:text() .. "\n\n"
    end)
    local selected = document:select("tbody > tr > td > a")
    local cur = selected:size() + 1
	return NovelInfo({
        title = document:selectFirst("main h1.font-bold"):text():gsub("\n" ,""),
        imageURL = imageURL,
        description = desc,
        chapters = AsList(
            map(selected, function(v)
                cur = cur - 1
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
    local document = GETDocument(expandURL("translated-novels/"))
    local novels = {}
    local function addNovel(v)
        local img = v:selectFirst("img.card-image")
        img = img and img:attr("src") or imageURL
        table.insert(novels, Novel {
            title = v:text(),
            link = shrinkURL(v:selectFirst(".card-title a"):attr("href")),
            imageURL = expandURL(shrinkURL(img))
        })
    end
    map(document:select(".novel-card"), addNovel)
    document = GETDocument(expandURL("original-novels/"))
    map(document:select(".novel-card"), addNovel)
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
