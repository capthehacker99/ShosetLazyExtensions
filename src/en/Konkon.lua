-- {"id":1991726384,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")

local id = 1991726384
local name = "Konkon"
local baseURL = "https://konkon.ink/"
local imageURL = "https://konkon.ink/logo.png"
local chapterType = ChapterType.HTML
local startIndex = 1

local apiBase = "https://api-k.konkon.ink/api/public/"

local function shrinkURL(url, _)
    return url
end

local function expandURL(url, _)
    return url
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64encode(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i)
    end
    local result = {}
    for i = 1, #bytes, 3 do
        local b1 = bytes[i]
        local b2 = bytes[i + 1]
        local b3 = bytes[i + 2]
        local c1 = math.floor(b1 / 4)
        local c2 = (b1 % 4) * 16 + math.floor((b2 or 0) / 16)
        result[#result + 1] = b64chars:sub(c1 + 1, c1 + 1)
        result[#result + 1] = b64chars:sub(c2 + 1, c2 + 1)
        if b2 then
            local c3 = (b2 % 16) * 4 + math.floor((b3 or 0) / 64)
            result[#result + 1] = b64chars:sub(c3 + 1, c3 + 1)
        else
            result[#result + 1] = "="
        end
        if b3 then
            local c4 = b3 % 64
            result[#result + 1] = b64chars:sub(c4 + 1, c4 + 1)
        else
            result[#result + 1] = "="
        end
    end
    return table.concat(result)
end

local function mediaURL(key)
    if not key then return imageURL end
    return apiBase .. "media/k/" .. b64encode(key)
end

local function getPassage(chapterURL)
    local resp = dkjson.GET(chapterURL)
    if resp.data and resp.data.content then
        return pageOfElem(Document("<body>" .. resp.data.content .. "</body>"):selectFirst("body"), true)
    end
    error("Failed to get chapter content")
end

local function parseNovel(novelURL)
    local resp = dkjson.GET(novelURL .. "?page=1&per_page=500")
    local nd = resp.data
    local chapters = {}
    local lastPage = nd.chapters_pagination.last_page
    for page = 1, lastPage do
        if page > 1 then
            resp = dkjson.GET(novelURL .. "?page=" .. page .. "&per_page=500")
            nd = resp.data
        end
        for _, vol in ipairs(nd.volumes or {}) do
            for _, ch in ipairs(vol.chapters or {}) do
                table.insert(chapters, NovelChapter {
                    order = ch.sort_order,
                    title = ch.title,
                    link = apiBase .. "chapters/" .. ch.id
                })
            end
        end
    end
    local desc = ""
    if nd.description then
        desc = nd.description:gsub("%<[^>]*>", "")
    end
    local genres = {}
    for _, g in ipairs(nd.genres or {}) do
        table.insert(genres, g.name)
    end
    return NovelInfo({
        title = nd.title,
        authors = { nd.author_name or "Unknown" },
        description = desc,
        imageURL = mediaURL(nd.featured_image_key),
        chapters = AsList(chapters),
        genres = genres
    })
end

local function getListing(data)
    local page = data[PAGE]
    local resp = dkjson.GET(apiBase .. "novels?page=" .. page .. "&per_page=20")
    local novels = {}
    for _, v in ipairs(resp.data or {}) do
        table.insert(novels, Novel {
            title = v.title,
            link = apiBase .. "novels/" .. v.slug,
            imageURL = mediaURL(v.featured_image_thumb_medium_key or v.featured_image_key)
        })
    end
    return novels
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
    local resp = dkjson.GET(apiBase .. "search?q=" .. urlEncode(query))
    local novels = {}
    for _, v in ipairs(resp.results or {}) do
        table.insert(novels, Novel {
            title = v.title,
            link = apiBase .. "novels/" .. v.slug,
            imageURL = v.featured_image_url or mediaURL(v.featured_image_key)
        })
    end
    return novels
end

return {
    id = id,
    name = name,
    baseURL = baseURL,
    listings = {
        Listing("Default", true, getListing)
    },
    getPassage = getPassage,
    parseNovel = parseNovel,
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    hasSearch = true,
    isSearchIncrementing = false,
    search = search,
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
