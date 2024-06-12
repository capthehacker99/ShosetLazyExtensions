-- {"id":1548078204,"ver":"1.0.1","libVer":"1.0.1","author":"","repo":"","dep":[]}
local json = Require("dkjson")

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1548078204

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Story Seedling"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://storyseedling.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://storyseedling.com/wp/wp-includes/images/w-logo-blue-white-bg.png"
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
    return url:gsub(".-storyseedling.com/", "")
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
    local htmlElement = document:selectFirst("main > .justify-center")
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
    local desc = ""
    map(document:select(".order-3 > .order-2 > span"), function(p)
        desc = desc .. p:text()
    end)
    local selected = document:select(".bg-accent .grid > a")
    local cur = selected:size() + 1
	return NovelInfo({
        title = document:selectFirst(".text-white h1"):text():gsub("\n" ,""),
        imageURL = document:selectFirst(".justify-self-center > div > img"):attr("src"),
        description = desc,
        chapters = AsList(
            map(selected, function(v)
                cur = cur - 1
                return NovelChapter {
                    order = cur,
                    title = v:selectFirst(".truncate"):text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )
    })
end

local function getListing()
    local doc = GETDocument(baseURL)
    return map(doc:select(".flex-1 > .flex-wrap > .flex-grow"), function(v)
        local title = v:selectFirst("a")
        return Novel {
            title = title:text(),
            link = shrinkURL(title:attr("href")),
            imageURL = v:selectFirst("img"):attr("src")
        }
    end)
end


local function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local nonce = ""
    for i = 1, 29 do
        nonce = nonce .. tostring(math.random(0, 9))
    end
    local content = "-----------------------------" .. nonce .. "\r\nContent-Disposition: form-data; name=\"search\"\r\n\r\n" .. query .. "\r\n-----------------------------" .. nonce .. "\r\nContent-Disposition: form-data; name=\"orderBy\"\r\n\r\nrecent\r\n-----------------------------" .. nonce .. "\r\nContent-Disposition: form-data; name=\"curpage\"\r\n\r\n" .. page .. "\r\n-----------------------------" .. nonce .. "\r\nContent-Disposition: form-data; name=\"post\"\r\n\r\n40245250ea\r\n-----------------------------" .. nonce .. "\r\nContent-Disposition: form-data; name=\"action\"\r\n\r\nfetch_browse\r\n-----------------------------" .. nonce .. "--\r\n"
    local req = Request(
        POST("https://storyseedling.com/ajax",
            HeadersBuilder()
                :add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; rv:126.0) Gecko/20100101 Firefox/126.0")
                :add("Accept", "*/*")
                :add("Accept-Language", "en-US,en;q=0.5")
                :add("Origin", "null")
                :add("Connection", "keep-alive")
                :add("Sec-Fetch-Dest", "empty")
                :add("Sec-Fetch-Mode", "cors")
                :add("Sec-Fetch-Site", "same-origin")
                :add("Sec-GPC", "1")
                :add("Priority", "u=4")
                :build(),
            RequestBody(content, MediaType("multipart/form-data; boundary=---------------------------" .. nonce))
        )
    )
    local data = json.decode(req:body():string())
    if data.success ~= true then
        return {}
    end
    local novels = {}
    for _, obj in next, data.data.posts do
        table.insert(novels, Novel {
            title = obj.title,
            link = shrinkURL(obj.permalink),
            imageURL = obj.bigThumbnail
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
