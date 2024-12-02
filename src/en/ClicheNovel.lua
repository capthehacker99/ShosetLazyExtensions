-- {"id":622317729,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 622317729

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Cliche Novel"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://clichenovel.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://s0.wp.com/i/webclip.png"
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
    return url:gsub(".-clichenovel.com/", "")
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
    htmlElement:select("p.has-huge-font-size"):remove()
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
    if novelURL:find("category/") then
        local document = GETDocument(url)
        local title = document:selectFirst(".page-title > .page-description")
        title = title and title:text() or "Unknown Title"
        local img = document:selectFirst(".post-thumbnail img")
        img = img and img:attr("src") or imageURL
        local max_page = 1
        map(document:select(".pagination > div > a"), function(v)
            local n = v:text():match("%d+")
            if n then
                max_page = math.max(max_page, tonumber(n))
            end
        end)
        local chapters = {}
        local function parsePage(page)
            map(page:select("article"), function(v)
                local link = v:selectFirst(".entry-title > a")
                local title = v:selectFirst(".entry-content > p"):text()
                local order = tonumber(link:text():match("%d+$"))
                table.insert(chapters, NovelChapter {
                    order = order,
                    title = title,
                    link = shrinkURL(link:attr("href"))
                })
            end)
        end
        parsePage(document)
        for i = 2, max_page do
            parsePage(GETDocument(url .. "/page/" .. i))
        end
        return NovelInfo({
            title = title:gsub("\n" ,""),
            imageURL = img,
            description = nil,
            chapters = chapters
        })
    end
	--- Novel page, extract info from it.
	local document = GETDocument(url)
    local title = document:selectFirst(".entry-title")
    title = title and title:text() or "Unknown Title"
    local img = document:selectFirst(".wp-block-image > img")
    img = img and img:attr("src") or imageURL
    local desc = ""
    map(document:select(".entry-content > div > div > p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
	return NovelInfo({
        title = title:gsub("\n" ,""),
        imageURL = img,
        description = desc,
        chapters = AsList(
            map(document:select(".wp-block-list > li > a"), function(v)
                return NovelChapter {
                    order = v,
                    title = v:text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )
    })
end

local function getListing()
    local document = GETDocument(expandURL("about/"))

    return mapNotNil(document:select(".entry-content > div > div"), function(v)
        local img = v:selectFirst("img")
        img = img and img:attr("src") or imageURL
        local link = v:selectFirst("a")
        if not link then return end
        return Novel {
            title = link:text(),
            link = shrinkURL(link:attr("href")),
            imageURL = img
        }
    end)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local document = GETDocument(expandURL("page/" .. page .. "/?s=" .. query))
    return map(document:select("a[rel='category tag']"), function(v)
        return Novel {
            title = v:text(),
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
    hasSearch = true,
    isSearchIncrementing = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
