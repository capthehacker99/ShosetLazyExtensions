-- {"id":930283970,"ver":"1.1.0","libVer":"1.0.0","author":"","repo":"","dep":[]}
local json = Require("dkjson")

local id = 930283970
local name = "Otaku Translation"
local baseURL = "https://otakutl.blogspot.com/"
local imageURL = "https://otakutl.blogspot.com/favicon.ico"
local chapterType = ChapterType.HTML
local startIndex = 1

local genreLabels = {
    "Romance", "BL", "SCI-FI", "Action", "Adventure", "Comedy", "Fantasy",
    "Slice of Life", "Eastern fantasy", "Western Fantasy", "Sci-Fi",
    "Eastern Fantasy", "Western fantasy", "Mystery", "Horror", "Tragedy",
    "Harem", "Martial Arts", "Psychological", "Supernatural", "Xianxia",
    "Xuanhuan", "Mature", "Seinen", "Shounen", "Josei", "Yaoi", "Yuri",
    "Gender Bender", "School Life", "Smut"
}

local genreSet = {}
for _, label in ipairs(genreLabels) do
    genreSet[label] = true
end

local feedURL = "https://otakutl.blogspot.com/feeds/posts/default?alt=json"

local function shrinkURL(url, _)
    return url
end

local function expandURL(url, _)
    return url
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

local function getPassage(chapterURL)
    local document = GETDocument(chapterURL)
    local htmlElement = document:selectFirst(".post-body.entry-content")
    if not htmlElement then
        htmlElement = document:selectFirst(".post-body")
    end
    return pageOfElem(htmlElement, true)
end

local function parseNovel(novelURL)
    local novelName = novelURL:match("search/label/(.+)$")
    if not novelName then
        error("Failed to parse novel name from URL")
    end
    novelName = novelName:gsub("+", " "):gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    local feedData = json.GET(feedURL .. "&category=" .. urlEncode(novelName) .. "&max-results=100")
    local feed = feedData and feedData.feed
    if not feed or not feed.entry then
        error("No entries found for: " .. novelName)
    end
    local chapters = {}
    for i, entry in ipairs(feed.entry) do
        local link = ""
        if entry.link and #entry.link > 0 then
            for _, l in ipairs(entry.link) do
                if l.rel == "alternate" then
                    link = l.href
                    break
                end
            end
        end
        local chapterTitle = entry.title and entry.title["$t"] or ("Chapter " .. i)
        table.insert(chapters, NovelChapter {
            order = i,
            title = chapterTitle,
            link = link
        })
    end
    return NovelInfo({
        title = novelName,
        imageURL = imageURL,
        chapters = chapters
    })
end

local function getListing()
    local feedData = json.GET(feedURL .. "&max-results=0")
    local seen = {}
    local novels = {}
    if feedData and feedData.feed and feedData.feed.category then
        for _, cat in ipairs(feedData.feed.category) do
            local term = cat.term
            if term and not genreSet[term] and not seen[term] then
                seen[term] = true
                table.insert(novels, Novel {
                    title = term,
                    link = baseURL .. "search/label/" .. urlEncode(term),
                    imageURL = imageURL
                })
            end
        end
    end
    return novels
end

return {
    id = id,
    name = name,
    baseURL = baseURL,
    listings = {
        Listing("Default", false, getListing)
    },
    getPassage = getPassage,
    parseNovel = parseNovel,
    shrinkURL = shrinkURL,
    expandURL = expandURL,
    hasSearch = false,
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
