-- {"id":1846546104,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":["dkjson"]}

local dkjson = Require("dkjson")

local id = 1846546104

local name = "LightNovelAsia"

local baseURL = "https://lightnovelasia.com/"

local imageURL = "https://lightnovelasia.com/favicon.ico"

local chapterType = ChapterType.HTML

local startIndex = 1

local SUPABASE_URL = nil
local ANON_KEY = nil
local configLoaded = false

local function loadConfig()
    if configLoaded then return end
    configLoaded = true
    local ok, doc = pcall(GETDocument, "https://lightnovelasia.com/")
    if not ok or not doc then
        error("Failed to load LightNovelAsia website")
    end
    local jsFile = nil
    map(doc:select("script[type='module']"), function(s)
        local src = s:attr("src")
        if src and src:match("index%-[%w%-]+%.js") then
            jsFile = src
        end
    end)
    if not jsFile then
        error("Could not find JS bundle on LightNovelAsia")
    end
    if jsFile:sub(1, 1) == "/" then
        jsFile = "https://lightnovelasia.com" .. jsFile
    end
    local ok2, req = pcall(Request, GET(jsFile))
    if not ok2 or not req then
        error("Failed to fetch LightNovelAsia JS bundle")
    end
    local js = req:body():string()
    local url = js:match('"https://[%w%-]+%.supabase%.co"')
    local key = js:match('"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9%.[%w%-_]+%.[%w%-_]+"')
    if url and key then
        SUPABASE_URL = url:sub(2, -2)
        ANON_KEY = key:sub(2, -2)
    else
        error("Could not discover Supabase credentials from LightNovelAsia")
    end
end

local function supabaseHeaders()
    return HeadersBuilder()
        :add("apikey", ANON_KEY)
        :add("Authorization", "Bearer " .. ANON_KEY)
        :build()
end

local function cleanHtml(html)
    if not html then return "" end
    html = html:gsub('<div[^>]*class="[^"]*watermark[^"]*"[^>]*>.-</div>', '')
    html = html:gsub('Published from this site', '')
    html = html:gsub('<br%s*/?>', '\n')
    html = html:gsub('<p[^>]*>', '\n\n')
    html = html:gsub('</p>', '')
    html = html:gsub('<[^>]+>', '')
    html = html:gsub('\n{3,}', '\n\n')
    return html:match('^%s*(.-)%s*$')
end

local function shrinkURL(url, _)
    return url:gsub(".-lightnovelasia%.com/", "")
end

local function expandURL(url, _)
    return baseURL .. url
end

local function getPassage(chapterURL)
    loadConfig()
    local slug = chapterURL:match("novel/([^/]+)")
    local chapterNum = chapterURL:match("chapter%-(%d+)")
    if not slug or not chapterNum then
        error("Invalid chapter URL: " .. chapterURL)
    end

    local ok, data = pcall(dkjson.POST,
        SUPABASE_URL .. "/functions/v1/get-chapter",
        {
            p_novel_slug = slug,
            p_chapter_number = tonumber(chapterNum),
            p_chapter_id = nil
        },
        supabaseHeaders()
    )

    if not ok then
        error("Chapter fetch failed: " .. tostring(data))
    end

    if type(data) == "string" then
        local parsed = dkjson.decode(data)
        if parsed then data = parsed end
    end

    local content = nil
    if type(data) == "table" then
        if data.chapter and data.chapter.content then
            content = data.chapter.content
        elseif data.content then
            content = data.content
        elseif type(data[1]) == "table" and data[1].content then
            content = data[1].content
        end
    end

    if not content or #content == 0 then
        error("No content in chapter response")
    end

    content = content:gsub("&nbsp;", " ")
    local doc = Document("<html><body>" .. content .. "</body></html>")
    return pageOfElem(doc:selectFirst("body"), true)
end

local function parseNovel(novelURL)
    loadConfig()
    local slug = novelURL:match("novel/([^/]+)")
    if not slug then
        error("Invalid novel URL: " .. novelURL)
    end

    local ok, novelData = pcall(dkjson.POST,
        SUPABASE_URL .. "/rest/v1/rpc/get_novel_for_display",
        { p_slug = slug },
        supabaseHeaders()
    )

    if not ok then
        error("RPC call failed for " .. slug .. ": " .. tostring(novelData))
    end
    if type(novelData) == "table" and novelData[1] then
        novelData = novelData[1]
    end
    if type(novelData) ~= "table" or not novelData.id then
        error("Novel not found: " .. slug)
    end

    local novel_id = novelData.id

    local chapters = {}
    local offset = 0
    local limit = 100
    local totalFetched = 0

    while true do
        local chapterData = dkjson.POST(
            SUPABASE_URL .. "/rest/v1/rpc/get_novel_toc",
            {
                p_novel_id = novel_id,
                p_is_paid = false,
                p_limit = limit,
                p_offset = offset,
                p_sort_asc = true
            },
            supabaseHeaders()
        )

        if type(chapterData) ~= "table" or #chapterData == 0 then break end

        for _, ch in ipairs(chapterData) do
            local title = ch.title or ("Chapter " .. (ch.chapter_number or ""))
            table.insert(chapters, NovelChapter({
                order = ch.chapter_number or ch.sort_order or #chapters + 1,
                title = title,
                link = "novel/" .. slug .. "/chapter-" .. (ch.chapter_number or #chapters)
            }))
        end

        totalFetched = totalFetched + #chapterData
        local totalCount = chapterData[1] and chapterData[1].total_count or totalFetched
        if totalFetched >= totalCount then break end
        offset = offset + limit
    end

    local desc = novelData.description or ""
    local tagStrings = {}
    if type(novelData.genres) == "table" then
        for _, g in ipairs(novelData.genres) do
            table.insert(tagStrings, g)
        end
    end
    if type(novelData.tags) == "table" then
        for _, t in ipairs(novelData.tags) do
            table.insert(tagStrings, t)
        end
    end

    return NovelInfo({
        title = novelData.title,
        imageURL = novelData.cover_image or imageURL,
        description = cleanHtml(desc) .. "\n\nStatus: " .. (novelData.status or "Unknown") ..
            "\nAuthor: " .. (novelData.author or "Unknown") ..
            "\nType: " .. (novelData.type or "Unknown") ..
            "\nCountry: " .. (novelData.country or "Unknown"),
        chapters = chapters,
        authors = novelData.author and { novelData.author } or nil,
        tags = #tagStrings > 0 and tagStrings or nil
    })
end

local function getListing(data)
    loadConfig()
    local page = data[PAGE]
    local limit = 20
    local offset = (page - 1) * limit

    local novels = dkjson.POST(
        SUPABASE_URL .. "/rest/v1/rpc/get_latest_updates",
        { limit_count = limit, offset_count = offset },
        supabaseHeaders()
    )

    if type(novels) ~= "table" then
        return {}
    end

    local results = {}
    for _, novel in ipairs(novels) do
        table.insert(results, Novel({
            title = novel.title,
            link = "novel/" .. novel.slug,
            imageURL = novel.cover_image or imageURL
        }))
    end
    return results
end

local function getPopularListing()
    loadConfig()
    local period = "week"

    local novels = dkjson.POST(
        SUPABASE_URL .. "/rest/v1/rpc/get_popular_novels",
        { p_period = period },
        supabaseHeaders()
    )

    if type(novels) ~= "table" then
        return {}
    end

    local results = {}
    for _, novel in ipairs(novels) do
        table.insert(results, Novel({
            title = novel.title,
            link = "novel/" .. novel.slug,
            imageURL = novel.cover_image or imageURL
        }))
    end
    return results
end

local function search(data)
    loadConfig()
    local query = data[QUERY]
    local page = data[PAGE]
    local limit = 24
    local offset = (page - 1) * limit

    local encoded = query:gsub('"', '%%22'):gsub("'", '%%27')

    local novels = dkjson.GET(
        SUPABASE_URL .. "/rest/v1/novels"
        .. "?select=id,title,slug,cover_image,author,status,country"
        .. "&publish_status=eq.Published"
        .. '&or=(title.ilike.%22%25' .. encoded .. '%25%22,original_title.ilike.%25' .. encoded .. '%25)'
        .. "&order=created_at.desc"
        .. "&offset=" .. offset
        .. "&limit=" .. limit,
        supabaseHeaders()
    )

    if type(novels) ~= "table" then
        return {}
    end

    local results = {}
    for _, novel in ipairs(novels) do
        table.insert(results, Novel({
            title = novel.title .. " (" .. (novel.country or "") .. ")",
            link = "novel/" .. novel.slug,
            imageURL = novel.cover_image or imageURL
        }))
    end
    return results
end

return {
    id = id,
    name = name,
    baseURL = baseURL,
    listings = {
        Listing("Latest", true, getListing),
        Listing("Popular", false, getPopularListing)
    },
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
