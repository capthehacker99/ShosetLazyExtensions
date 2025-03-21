-- {"id":1553358903,"ver":"1.0.4","libVer":"1.0.4","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1553358903

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Fenrir Realm"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://fenrirealm.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://fenrirealm.com/img/logo/fenrir-logo.png"
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
    return url:gsub(".-fenrirealm.com/", "")
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
    local htmlElement = document:selectFirst("#reader-area")
    return pageOfElem(htmlElement, true)
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- base64
-- encoding
local function b64enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
local function b64dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
    --- Novel page, extract info from it.
    local data = dkjson.decode(b64dec(novelURL:match(".+#(.+)$")))
    local chapter_data = dkjson.GET(expandURL("api/novels/chapter-list/" .. data.slug))
    local raw_url = novelURL:match("(.+)#.+$")
    local chapters = {}
    for _, v in next, chapter_data do
        if not v.locked or v.locked.price == 0 then            
            table.insert(chapters, NovelChapter {
                order = v.index,
                title = v.title,
                link = raw_url .. "/chapter-" .. v.number
            })
        end
    end
    local tags = {}
    for _, v in next, data.tags do
        table.insert(tags, v.name)
    end
    local genres = {}
    for _, v in next, data.genres do
        table.insert(genres, v.name)
    end
    return NovelInfo({
        title = data.title,
        imageURL = expandURL(shrinkURL(data.cover)),
        description = data.description,
        alternativeTitles = data.alt_title and { data.alt_title } or nil,
        tags = tags,
        generes = genres,
        user = data.user and data.user.name or nil,
        chapters = chapters
    })
end

local function getListing(data)
    local page = data[PAGE]
    local data = dkjson.GET(expandURL("api/novels/filter?page=" .. page .. "&per_page=25&status=any&order=latest"))
    local chapters = {}
    for _, v in next, data.data do
        table.insert(chapters, Novel {
            title = v.title,
            link = "series/" .. v.slug .. "#" .. b64enc(dkjson.encode(v)),
            imageURL = v.cover and expandURL(shrinkURL(v.cover)) or imageURL,
            alternativeTitles = v.alt_title and { v.alt_title } or nil,
            description = v.description
        })
    end
    return chapters
end

local function urlEncode(str)
    if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-%_%.%~])", function(c)
            return ("%%%02X"):format(string.byte(c))
        end)
        str = str:gsub(" ", "+")
    end
    return str
end

local function search(data)
    local query = data[QUERY]
    local page = data[PAGE]
    local data = dkjson.GET(expandURL("api/novels/filter?page=" .. page .. "&per_page=25&status=any&order=latest&search=" .. urlEncode(query)))
    local chapters = {}
    for _, v in next, data.data do
        table.insert(chapters, Novel {
            title = v.title,
            link = "series/" .. v.slug .. "#" .. b64enc(dkjson.encode(v)),
            imageURL = expandURL(shrinkURL(v.cover)),
            alternativeTitles = v.alt_title and { v.alt_title } or nil,
            description = v.description
        })
    end
    return chapters
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
    search = search,
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
