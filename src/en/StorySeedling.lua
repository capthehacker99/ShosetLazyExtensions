-- {"id":1548078204,"ver":"1.0.12","libVer":"1.0.12","author":"","repo":"","dep":[]}
local json = Require("dkjson")
local utf8 = Require("utf8")

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
    htmlElement:select("[x-data=\"{open:false}\"]"):remove()
    local prob_cipher = htmlElement:selectFirst("[ax-load][x-data]")
    if prob_cipher then
        local tk = prob_cipher:attr("x-data")
        if tk:find("loadChapter%(") then
            tk = tk:match("'[a-f0-9]+'%)")
            tk = tk:sub(2, #tk - 2)
            local res = RequestDocument(POST(
                url .. "/content",
                HeadersBuilder()
                    :add("X-Nonce", tk)
                    :build(),
                RequestBody("{\"captcha_response\":\"\"}", MediaType("application/json"))
            ))
            local all = ""
            map(res:select("*"), function(v)
                local text = v:text()
                if text:find("cls[a-f0-9]+") then
                    return
                end
                local new_text = ""
                for i, ch, bi in utf8.chars(text) do
                    local ch = utf8.byte(ch)
                    if ch >= 12098 and ch <= 12123 then
                        new_text = new_text .. utf8.char(ch - 12033)
                    elseif ch >= 12124 and ch <= 12149 then
                        new_text = new_text .. utf8.char(ch - 12027)
                    else
                        new_text = new_text .. utf8.char(ch)
                    end
                end
                if new_text:find("Story Seedling") then
                    return
                end
                if #new_text == 0 then
                    return
                end
                all = all .. "<p>" .. new_text .. "</p>"
            end)
            return pageOfElem(Document(all), true)
        end
    end
    return pageOfElem(htmlElement, true)
end

local function get_csrf_token(doc)
    local csrf_token;
    map(doc:select("[x-data]"), function(v)
        local tk = v:attr("x-data")
        if not tk or not (tk:find("toc%(") or tk:find("browse%(")) then return true end
        tk = tk:match("'[a-f0-9]+'%)")
        if not tk then return true end
        csrf_token = tk:sub(2, #tk - 2)
    end)
    if csrf_token then return csrf_token end
    error("CSRF token not found.")
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
	local url = expandURL(novelURL)
    local novel_id = string.match(novelURL, "%d+")
	--- Novel page, extract info from it.
	local document = GETDocument(url)
    local csrf_token = get_csrf_token(document)
    local desc = ""
    map(document:select("div.grid > div > p"), function(p)
        desc = desc .. p:text()
    end)
    local tags = AsList(map(document:select("div.flex > a.rounded"), function(p)
        return p:text()
    end))
    local author = document:selectFirst("span ~ a")
    author = author and { author:text() } or nil;
    local title = document:selectFirst(".text-white h1"):text():gsub("\n" ,"")
    local image = document:selectFirst(".justify-self-center > div > img"):attr("src")
    local nonce = ""
    for i = 1, 29 do
        nonce = nonce .. tostring(math.random(0, 9))
    end
    local content = "-----------------------------" .. nonce .. "\r\nContent-Disposition: form-data; name=\"post\"\r\n\r\n" .. csrf_token .. "\r\n-----------------------------" .. nonce .. "\r\nContent-Disposition: form-data; name=\"id\"\r\n\r\n" .. novel_id .. "\r\n-----------------------------" .. nonce .. "\r\nContent-Disposition: form-data; name=\"action\"\r\n\r\nseries_toc\r\n-----------------------------" .. nonce .. "--\r\n"
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
    local str = req:body():string()
    local chapters = {};
    local data = json.decode(str)
    if data.success == true then
        for i, v in next, (data.data or {}) do
            if not v.is_locked then
                table.insert(chapters, NovelChapter {
                    order = tonumber(i);
                    title = v.title;
                    link = shrinkURL(v.url)
                });
            end
        end
    end
	return NovelInfo({
        title = title,
        imageURL = image,
        description = desc,
        chapters = chapters,
        authors = author,
        tags = tags
    })
end

local function getListing()
    local doc = GETDocument(baseURL)
    local tab = map(doc:select(".flex-wrap > .flex-col"), function(v)
        local title = v:selectFirst(".flex > a.text-center")
        return Novel {
            title = title:text(),
            link = shrinkURL(title:attr("href")),
            imageURL = v:selectFirst("img"):attr("src")
        }
    end)
    -- For cloudflare shit
    table.insert(tab, Novel {
        title = "Cloudflare chapter verification",
        link = "series/172082/1/",
        imageURL = "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Flogodownload.org%2Fwp-content%2Fuploads%2F2016%2F10%2FCloudflare-logo.png&f=1&nofb=1&ipt=5720d6dda9a90de4477790a76d2355aa1274c6ce3816c447ce20a0fb337106dd&ipo=images"
    })
    return tab
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
    local doc = GETDocument(expandURL("browse"))
    local hash = get_csrf_token(doc)
    local nonce = ""
    for i = 1, 29 do
        nonce = nonce .. tostring(math.random(0, 9))
    end
    local content = "-----------------------------" .. nonce ..
            "\r\nContent-Disposition: form-data; name=\"search\"\r\n\r\n" .. query .. "\r\n-----------------------------" .. nonce ..
            "\r\nContent-Disposition: form-data; name=\"status\"\r\n\r\nany\r\n-----------------------------" .. nonce ..
            "\r\nContent-Disposition: form-data; name=\"orderBy\"\r\n\r\nrecent\r\n-----------------------------" .. nonce ..
            "\r\nContent-Disposition: form-data; name=\"curpage\"\r\n\r\n" .. page .. "\r\n-----------------------------" .. nonce ..
            "\r\nContent-Disposition: form-data; name=\"post\"\r\n\r\n" .. hash .. "\r\n-----------------------------" .. nonce ..
            "\r\nContent-Disposition: form-data; name=\"action\"\r\n\r\nfetch_browse\r\n-----------------------------" .. nonce ..
            "--\r\n"
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
    for _, obj in next, data.data.posts or {} do
        table.insert(novels, Novel {
            title = obj.title,
            link = shrinkURL(obj.permalink),
            imageURL = obj.bigThumbnail or obj.thumbnail
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
    hasCloudFlare = true,
    isSearchIncrementing = true,
    search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
