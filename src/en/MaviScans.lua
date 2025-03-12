-- {"id":2079065230,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 2079065230

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Mavi Scans"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://maviscans.blogspot.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://blogger.googleusercontent.com/img/a/AVvXsEiXhYwA3On04HGDqLsaJp8ooDYfPzFTDRHd2UuiqfiLDIqbXL71B0U2n-srC4nLsT018p-7Ta9LsLxPPN8uUsggav5eLYebJJbbTjhvJiXXpYdTh-GzYn2fj9I4ptWq0epWyy8X-2dGK1SqrGgaLwCM_T6CjyPbLgsmf-Sfym4u2X5Fiju4S75E_o7IvsA=s734"
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
    return url:gsub(".-maviscans.blogspot.com/", "")
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
    local htmlElement = document:selectFirst("#postBody")
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
    local selected = document:select("#postBody > p > a[href], #postBody > div > a, #postBody > div > span > a")
    local img = document:selectFirst("img[border]")
    img = img and img:attr("src") or imageURL
    local cur = selected:size() + 1
	return NovelInfo({
        title = document:selectFirst(".entry-title"):text():gsub("\n" ,""),
        imageURL = img,
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
    local data = dkjson.GET(expandURL("feeds/pages/default?max-results=1000&alt=json"))
    local novels = {}
    for _, v in next, data.feed.entry do
        for _, w in next, v.link do
            if w.type == "text/html" then
                local img = v["media$thumbnail"]
                img = img and img.url or imageURL
                table.insert(novels, Novel {
                    title = v.title["$t"],
                    link = shrinkURL(w.href),
                    imageURL = img
                })
                break
            end
        end
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
