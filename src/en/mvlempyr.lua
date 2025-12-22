-- {"id":1339243358,"ver":"1.1.8","libVer":"1.0.10","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
local bigint = Require("bigint")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1339243358

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "MVLEMPYR"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://www.mvlempyr.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://assets.mvlempyr.com/images/asset/LogoMage.webp"
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
	local url = expandURL(chapterURL):gsub("(%w+://[^/]+)%.io", "%1.io")

	--- Chapter page, extract info from it.
	local document = GETDocument(url)
    local htmlElement = document:selectFirst("#chapter")
    return pageOfElem(htmlElement, true)
end

local function calculateTagId(novel_code)
    local t = bigint.new("1999999997")
    local c = bigint.modulus(bigint.new("7"), t);
    local d = tonumber(novel_code);
    local u = bigint.new(1);
    while d > 0 do
        -- print(bigint.unserialize(t, "string"), bigint.unserialize(c, "string"), d, bigint.unserialize(u, "string"))
        if (d % 2) == 1 then
            u = bigint.modulus((u * c), t)
        end
        c = bigint.modulus((c * c), t);
        d = math.floor(d/2);
    end
    return bigint.unserialize(u, "string")
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
    local desc = ""
    map(document:select(".synopsis p"), function(p)
        desc = desc .. '\n' .. p:text()
    end)
    local img = document:selectFirst("img.novel-image2")
    img = img and img:attr("src") or imageURL
    local novel_code = document:selectFirst("#novel-code"):text()
    local headers = HeadersBuilder():add("Origin", "https://www.mvlempyr.com"):build()
    local chapters = {}
    local page = 1
    repeat
        local chapter_data = dkjson.GET("https://chap.heliosarchive.online/wp-json/wp/v2/posts?tags=" .. calculateTagId(novel_code) .. "&per_page=500&page=" .. page, headers)
        for i, v in next, chapter_data do
            table.insert(chapters, NovelChapter {
                order = v.acf.chapter_number,
                title = v.acf.ch_name,
                link = shrinkURL(v.link):gsub("chap.heliosarchive.online", "www.mvlempyr.io")
            })
        end
        page = page + 1
    until #chapter_data < 500
	return NovelInfo({
        title = document:selectFirst(".novel-title2"):text():gsub("\n" ,"www.mvlempyr.io"),
        imageURL = img,
        description = desc,
        chapters = chapters
    })
end

local function getListing(data)
    local data = dkjson.GET("https://chap.heliosarchive.online/wp-json/wp/v2/mvl-novels?per_page=100&offset=" .. (100 * data[PAGE] - 100))
    local novels = {}
    for _, novel in next, data do
        table.insert(novels, Novel {
            title = novel.name,
            link = "https://www.mvlempyr.io/novel/" .. novel.slug,
            imageURL = "https://assets.mvlempyr.io/images/600/" .. novel["novel-code"] .. ".webp"
        })
    end
    return novels
end

local searchHelper = {}

local function search(data)
    local matched = data[QUERY]:match("/novel/(.*)")
    if matched then
        return AsList({
            Novel {
                title = "URL Import",
                link = "https://www.mvlempyr.io/novel/" .. matched,
                imageURL = imageURL
            }
        })
    end
    local query = data[QUERY]:lower()
    local origPage = data[PAGE]
    local page = origPage
    if searchHelper[query] == nil then
        searchHelper = {[query] = {}}
    else
        page = searchHelper[query][page - 1]
        if page == nil then
            page = origPage
        else
            page = page + 1
        end
    end
    local novels = {}
    local idx = 0
    while #novels == 0 and idx < 200 do
        local data = dkjson.GET("https://chap.heliosarchive.online/wp-json/wp/v2/mvl-novels?per_page=200&offset=" .. (200 * page - 200))
        for _, novel in next, data do
            if novel.name:lower():match(query) then
                table.insert(novels, Novel {
                    title = novel.name,
                    link = "https://www.mvlempyr.io/novel/" .. novel.slug,
                    imageURL = "https://assets.mvlempyr.io/images/600/" .. novel["novel-code"] .. ".webp"
                })
            end
        end
        page = page + 1
        idx = idx + 1
    end
    searchHelper[query][origPage] = page
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
    hasSearch = true,
    isSearchIncrementing = true,
    hasCloudFlare = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
