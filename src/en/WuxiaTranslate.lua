-- {"id":1946264740,"ver":"1.0.1","libVer":"1.0.1","author":"","repo":"","dep":["dkjson"]}
local dkjson = Require("dkjson")

local id = 1946264740

local name = "WuxiaTranslate"

local baseURL = "https://wuxiatranslation.com/"

local imageURL = "https://wuxiatranslate.com/logo.png"

local chapterType = ChapterType.HTML

local startIndex = 1

local FALLBACK_URL = "https://efrkglhpnooqmqhwfkfb.supabase.co"
local FALLBACK_KEY = "sb_publishable_rs7n1XJd6XdyQQGZjggufQ_lnDleqqr"

local SUPABASE_URL = nil
local ANON_KEY = nil
local configLoaded = false

local function loadConfig()
    if configLoaded then return end
    configLoaded = true
    local ok, doc = pcall(GETDocument, "https://wuxiatranslation.com/")
    if not ok or not doc then
        SUPABASE_URL, ANON_KEY = FALLBACK_URL, FALLBACK_KEY
        return
    end
    local jsFile = nil
    map(doc:select("script[type='module']"), function(s)
        local src = s:attr("src")
        if src and src:match("index%-[%w]+%.js") then
            jsFile = src
        end
    end)
    if not jsFile then
        SUPABASE_URL, ANON_KEY = FALLBACK_URL, FALLBACK_KEY
        return
    end
    if jsFile:sub(1, 1) == "/" then
        jsFile = "https://wuxiatranslation.com" .. jsFile
    end
    local ok2, req = pcall(Request, GET(jsFile))
    if not ok2 or not req then
        SUPABASE_URL, ANON_KEY = FALLBACK_URL, FALLBACK_KEY
        return
    end
    local js = req:body():string()
    local url = js:match('"https://[%w%-]+%.supabase%.co"')
    local key = js:match('"sb_publishable_[%w_]+"')
    if url and key then
        SUPABASE_URL = url:sub(2, -2)
        ANON_KEY = key:sub(2, -2)
    else
        SUPABASE_URL, ANON_KEY = FALLBACK_URL, FALLBACK_KEY
    end
end

local function supabaseHeaders()
    return HeadersBuilder()
        :add("apikey", ANON_KEY)
        :add("Authorization", "Bearer " .. ANON_KEY)
        :build()
end

local function shrinkURL(url, _)
    return url:gsub(".-wuxiatranslation.com/", "")
end

local function expandURL(url, _)
    return baseURL .. url
end

local function getPassage(chapterURL)
    loadConfig()
    local parts = {}
    for part in chapterURL:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    if #parts < 3 then
        error("Invalid chapter URL: " .. chapterURL)
    end
    local novel_slug = parts[2]
    local chapter_slug = parts[3]

    local data = dkjson.POST(
        SUPABASE_URL .. "/rest/v1/rpc/get_chapter_by_slug",
        { p_novel_slug = novel_slug, p_chapter_slug = chapter_slug },
        supabaseHeaders()
    )

    if type(data) ~= "table" then
        error("Chapter not found")
    end
    if #data == 0 then
        error("RPC returned empty array for slug=" .. novel_slug .. " chap=" .. chapter_slug)
    end
    local chapter = data[1] or data
    if not chapter.content then
        error("No content in chapter response")
    end

    local content = chapter.content
    content = content:gsub("<p>&nbsp;</p>", "")
    content = content:gsub("<p>", "\n")
    content = content:gsub("</p>", "")
    return pageOfElem(Document(content), true)
end

local function parseNovel(novelURL)
    loadConfig()
    local slug = novelURL:gsub("^novel/", "")

    local novelData = dkjson.GET(
        SUPABASE_URL .. "/rest/v1/novels?select=*&slug=eq." .. slug .. "&publish_status=eq.Published",
        supabaseHeaders()
    )

    if type(novelData) ~= "table" or #novelData == 0 then
        return NovelInfo({ title = "Not Found", description = "" })
    end

    local novel = novelData[1]
    local novel_id = novel.id

    local chapterData = dkjson.GET(
        SUPABASE_URL .. "/rest/v1/chapters?select=id,title,sort_order,coins,release_date&novel_id=eq." .. novel_id .. "&status=eq.Published&order=sort_order.asc&limit=1000",
        supabaseHeaders()
    )

    local chapters = {}
    if type(chapterData) == "table" then
        for _, ch in ipairs(chapterData) do
            local coinText = ""
            if ch.coins and ch.coins > 0 then
                coinText = " [" .. ch.coins .. " coins]"
            end
            table.insert(chapters, NovelChapter({
                order = ch.sort_order,
                title = ch.title .. coinText,
                link = "novel/" .. slug .. "/chapter-" .. ch.sort_order
            }))
        end
    end

    local desc = novel.description or ""
    local genres = novel.genres
    local tags = novel.tags
    local tagStrings = {}
    if type(genres) == "table" then
        for _, g in ipairs(genres) do
            table.insert(tagStrings, g)
        end
    end
    if type(tags) == "table" then
        for _, t in ipairs(tags) do
            table.insert(tagStrings, t)
        end
    end

    return NovelInfo({
        title = novel.title,
        imageURL = novel.cover_image or imageURL,
        description = desc .. "\n\nStatus: " .. (novel.status or "Unknown") ..
            "\nAuthor: " .. (novel.author or "Unknown") ..
            "\nType: " .. (novel.type or "Unknown") ..
            "\nViews: " .. tostring(novel.public_views or 0),
        chapters = chapters,
        authors = novel.author and { novel.author } or nil,
        tags = #tagStrings > 0 and tagStrings or nil
    })
end

local function getListing(data)
    loadConfig()
    local page = data[PAGE]
    local limit = 48
    local offset = (page - 1) * limit

    local novels = dkjson.GET(
        SUPABASE_URL .. "/rest/v1/novels?select=title,slug,cover_image,author,public_views,genres&publish_status=eq.Published&order=public_views.desc&offset=" .. offset .. "&limit=" .. limit,
        supabaseHeaders()
    )

    if type(novels) ~= "table" then
        return {}
    end

    local results = {}
    for _, novel in ipairs(novels) do
        table.insert(results, Novel({
            title = novel.title .. " (" .. tostring(novel.public_views or 0) .. " views)",
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
    local limit = 20
    local offset = (page - 1) * limit

    local encoded = query:gsub("%%", "%%%%"):gsub(" ", "+")

    local novels = dkjson.GET(
        SUPABASE_URL .. "/rest/v1/novels?select=title,slug,cover_image,author,public_views&publish_status=eq.Published&or=(title.ilike.*" .. encoded .. "*,author.ilike.*" .. encoded .. "*)&offset=" .. offset .. "&limit=" .. limit,
        supabaseHeaders()
    )

    if type(novels) ~= "table" then
        return {}
    end

    local results = {}
    for _, novel in ipairs(novels) do
        table.insert(results, Novel({
            title = novel.title .. " - " .. (novel.author or "Unknown"),
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
        Listing("Popular", true, getListing)
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
