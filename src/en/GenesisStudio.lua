-- {"id":1035923222,"ver":"1.1.0","libVer":"1.0.0","author":"","repo":"","dep":[]}
local json = Require("dkjson")

local id = 1035923222
local name = "Genesis Studio"
local baseURL = "https://genesistudio.com/"
local imageURL = "https://genesistudio.com/favicon-32x32.png"
local chapterType = ChapterType.HTML
local startIndex = 1

local function shrinkURL(url, _)
    return url:gsub(".-genesistudio.com/", "")
end

local function expandURL(url, _)
    return baseURL .. url
end

local function getCoverURL(novel)
    if novel.coverFile and novel.coverFile.filename_disk then
        return "https://genesistudio.com/cdn-cgi/image/width=256,format=avif/https://api.genesistudio.com/storage/v1/object/public/directus/" .. novel.coverFile.filename_disk
    end
    return imageURL
end

local function getPassage(chapterURL)
    local url = expandURL(chapterURL)
    local document = GETDocument(url)
    local htmlElement = document:selectFirst(".novel-content")
    if htmlElement then
        return pageOfElem(htmlElement, true)
    end
    local slug, chapterNum = chapterURL:match("novels/([^/]+)/chapter%-(%d+)")
    if not slug then
        error("Failed to parse chapter URL")
    end
    local novelData = json.GET("https://genesistudio.com/api/directus/novels?filter[slug]=" .. slug .. "&limit=1")
    if not novelData or #novelData == 0 then
        error("Novel not found: " .. slug)
    end
    local novelUUID = novelData[1].id
    local chaptersResp = json.GET("https://genesistudio.com/api/novels-chapter/" .. novelUUID)
    local chapters = chaptersResp and chaptersResp.data and chaptersResp.data.chapters or {}
    local chapterId = nil
    for _, ch in ipairs(chapters) do
        if ch.chapter_number == tonumber(chapterNum) then
            chapterId = ch.id
            break
        end
    end
    if not chapterId then
        error("Chapter not found")
    end
    local contentResp = json.GET("https://genesistudio.com/api/chapters/" .. chapterId .. "/content")
    if contentResp and contentResp.data and contentResp.data.chapter_content then
        return contentResp.data.chapter_content
    end
    error("Failed to get chapter content")
end

local function parseNovel(novelURL)
    local slug = novelURL:match("novels/([^/]+)")
    if not slug then
        error("Failed to parse novel URL")
    end
    local novelData = json.GET("https://genesistudio.com/api/directus/novels?filter[slug]=" .. slug .. "&limit=1")
    if not novelData or #novelData == 0 then
        error("Novel not found: " .. slug)
    end
    local novel = novelData[1]
    local chapters = {}
    local chaptersResp = json.GET("https://genesistudio.com/api/novels-chapter/" .. novel.id)
    local chaptersData = chaptersResp and chaptersResp.data and chaptersResp.data.chapters or {}
    for _, ch in ipairs(chaptersData) do
        table.insert(chapters, NovelChapter {
            order = ch.chapter_number,
            title = ch.chapter_title,
            link = "novels/" .. slug .. "/chapter-" .. ch.chapter_number
        })
    end
    return NovelInfo({
        title = novel.novel_title,
        imageURL = getCoverURL(novel),
        description = novel.synopsis,
        chapters = chapters
    })
end

local function getListing()
    local data = json.GET("https://genesistudio.com/api/directus/novels?limit=-1")
    local novels = {}
    if not data then
        return novels
    end
    for _, novel in ipairs(data) do
        local slug = novel.slug or novel.abbreviation
        if slug then
            table.insert(novels, Novel {
                title = novel.novel_title,
                link = "novels/" .. slug,
                imageURL = getCoverURL(novel)
            })
        end
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
    local result = json.GET("https://genesistudio.com/api/directus/novels?filter[novel_title][_contains]=" .. urlEncode(query) .. "&limit=-1")
    local novels = {}
    if not result then
        return novels
    end
    for _, novel in ipairs(result) do
        local slug = novel.slug or novel.abbreviation
        if slug then
            table.insert(novels, Novel {
                title = novel.novel_title,
                link = "novels/" .. slug,
                imageURL = getCoverURL(novel)
            })
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
    hasSearch = true,
    isSearchIncrementing = false,
    search = search,
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
