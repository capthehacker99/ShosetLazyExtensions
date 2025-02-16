-- {"id":930283970,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 930283970

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Otaku Translation"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://otakutl.blogspot.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://otakutl.blogspot.com/favicon.ico"
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
    return url
end

--- Expand a given URL.
---
--- Required.
---
--- @param url string Shrunk URL to expand.
--- @param _ int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Full URL.
local function expandURL(url, _)
	return url
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
    local htmlElement = document:selectFirst(".post")
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
    local title = document:selectFirst("h3[itemprop=\"name\"]"):text()
    local img = document:selectFirst("img")
    img = img and img:attr("src") or "https://picsum.photos/200/300"
    local desc = ""
    map(document:select("#editdescription p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
	return NovelInfo({
        title = title,
        imageURL = img,
        description = desc,
        chapters = AsList(
            mapNotNil(document:select(".entry-content span > a"), function(v)
                local link = v:attr("href")
                if not link or link == "" then return end
                return NovelChapter {
                    title = v:text(),
                    link = shrinkURL(link)
                }
            end)
        )
    })
end

local function getListing()
    local visited = {}
    local novels = {}
    local function visit(url)
        if url == "" or visited[url] or not (url:find("otakutl.blogspot.com") or url:find("darbloodage.blogspot.com")) or url:find("privacy-policy.html$") then return end
        local document = GETDocument(url)
        visited[url] = true
        map(document:select(".post"), function(v)
            local atag = v:selectFirst(".post-title a")
            if not atag then return end
            local link = atag:attr("href")
            if link == "" then return end
            visited[link] = true
            local img = v:selectFirst("[itemprop=\"image_url\"]")
            img = img and img:attr("content") or "https://picsum.photos/200/300"
            table.insert(
                novels,
                Novel {
                    title = atag:text(),
                    link = link,
                    imageURL = img
                }
            )
        end)
        map(document:select(".entry-content a"), function(v)
            visit(v:attr("href"))
        end)
    end
    visit("https://otakutl.blogspot.com/p/list-of-translations.html")
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
