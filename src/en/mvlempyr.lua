-- {"id":1339243358,"ver":"1.0.11","libVer":"1.0.0","author":""}
local json = Require("dkjson")
local bigint = Require("bigint")


local id = 1339243358

local name = "MVLEMPYR"

local chapterType = ChapterType.HTML

local imageURL = "https://assets.mvlempyr.com/images/asset/LogoMage.webp"

--base Url for the site

local baseURL = "https://www.mvlempyr.com/"

local function shrinkURL(url, _)
    return url
end

local function expandURL(url, _)
	return url
end

local startIndex = 1

local matchingNovels = nil
local loadedPages = 0
local totalPages = nil
local pageQueryId = "c5c66f03"
local queryCache = {}

local function clearNovelsCache()
    matchingNovels = nil
    loadedPages = 0
    totalPages = nil
end

local function loadAllNovels(startPage, endPage, query)
    query = query:lower()
    local novels, seenLinks = {}, {}
    startPage = math.max(startPage or 1, 1)
    endPage = math.max(endPage or startPage + 19, startPage)
    
    local nextPageLink = nil
    local hasMatches = false
    
    for page = startPage, endPage do
        if loadedPages >= page then goto continue end
        loadedPages = loadedPages + 1
        local url = (baseURL .. "advance-search" .. (page > 1 and "?" .. pageQueryId .. "_page=" .. page or "")):gsub("(%w+://[^/]+)%.(com|net)(/|$)", "%1.space%3")
        local doc = GETDocument(url, { timeout = 60000, javascript = true })
        
        if page == 1 then
            local totalText = doc:selectFirst(".w-page-count.hide"):text()
            if totalText then
                local total = tonumber(totalText:match("Showing %d+ out of (%d+) novels")) or 0
                if total > 0 then totalPages = math.ceil(total / 15) end
            end
            local link = doc:selectFirst("a.w-pagination-next.next")
            if link and link:attr("href") then
                pageQueryId = link:attr("href"):match("%?([^=]+)_page=") or pageQueryId
            end
        end
        
        nextPageLink = doc:selectFirst("a.w-pagination-next.next")
        nextPageLink = nextPageLink and nextPageLink:attr("href") or nil 
        local elements, newNovelsFound = doc:select(".novelcolumn"), false
        for i = 0, elements:size() - 1 do
            local v = elements:get(i)
            local name = v:selectFirst("h2[fs-cmsfilter-field=\"name\"]")
            if not name then goto inner_continue end
            name = name:text()
            local link = v:selectFirst("a")
            if not link then goto inner_continue end
            link = link:attr("href")
            if not link or link == "" then goto inner_continue end
            link = baseURL .. link:gsub("^/", "")
            local key = link .. "|" .. name
            if seenLinks[key] then goto inner_continue end
            seenLinks[key] = true
            local image = v:selectFirst("img")
            image = image and image:attr("src") or imageURL
            local novel = { title = name, link = link, imageURL = image }
            table.insert(novels, novel)
            if name:lower():find(query, 1, true) then hasMatches = true end
            newNovelsFound = true
            ::inner_continue::
        end
        if not newNovelsFound then return novels, hasMatches, nextPageLink end
        ::continue::
    end
    return novels, hasMatches, nextPageLink
end

local function getPassage(chapterURL)
    local url = chapterURL:gsub("(%w+://[^/]+)%.net", "%1.space")
    local doc = GETDocument(url)
    return pageOfElem(doc:selectFirst("#chapter"), true)
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

local function parseNovel(novelURL)
    local doc = GETDocument(novelURL)
    local desc = ""
    map(doc:select(".synopsis p"), function(p) desc = desc .. '\n' .. p:text() end)
    local img = doc:selectFirst("img.novel-image2")
    img = img and img:attr("src") or imageURL
    local novel_code = doc:selectFirst("#novel-code"):text()
    local headers = HeadersBuilder():add("Origin", "https://www.mvlempyr.com"):build()
    local chapters, page = {}, 1
    repeat
        local data = json.GET("https://chap.mvlempyr.space/wp-json/wp/v2/posts?tags=" .. calculateTagId(novel_code) .. "&per_page=500&page=" .. page, headers)
        for i, v in next, data do
            table.insert(chapters, NovelChapter {
                order = v.acf.chapter_number,
                title = v.acf.ch_name,
                link = v.link
            })
        end
        page = page + 1
    until #data < 500
    return NovelInfo({
        title = doc:selectFirst(".novel-title2"):text():gsub("\n", ""),
        imageURL = img,
        description = desc,
        chapters = chapters
    })
end

local listing_page_parm
local function getListing(data)
    local document = GETDocument("https://www.mvlempyr.com/novels" .. (listing_page_parm and (listing_page_parm .. data[PAGE]) or ""))
    if not listing_page_parm then
        listing_page_parm = document:selectFirst(".g-tpage a.painationbutton.w--current, .g-tpage a.w-pagination-next")
        if not listing_page_parm then
            error(document)
        end
        listing_page_parm = listing_page_parm:attr("href")
        if not listing_page_parm then
            error("Failed to find listing href")
        end
        listing_page_parm = listing_page_parm:match("%?[^=]+=")
        if not listing_page_parm then
            error("Failed to find listing match")
        end
    end
    return map(document:select(".g-tpage div.searchlist[role=\"listitem\"] .novelcolumn .novelcolumimage a"), function(v)
        return Novel {
            title = v:attr("title"),
            link = "https://www.mvlempyr.com/" .. v:attr("href"),
            imageURL = v:selectFirst("img"):attr("src")
        }
    end)
end

local function search(data)
    local query = (data[QUERY] or ""):lower()
    local page = data[PAGE] or 1
    if queryCache[query] then
        matchingNovels = queryCache[query]
    else
        clearNovelsCache()
        matchingNovels = matchingNovels or {}
        local seenFiltered = {}
        local pageBatchSize, currentStartPage = 20, 1
        while true do
            local novels, hasMatches, nextPageLink = loadAllNovels(currentStartPage, currentStartPage + pageBatchSize - 1, query)
            if hasMatches then
                for _, novel in ipairs(novels) do
                    local title = novel.title:lower()
                    if title:find(query, 1, true) then
                        local key = novel.link .. "|" .. novel.title
                        if not seenFiltered[key] then
                            seenFiltered[key] = true
                            table.insert(matchingNovels, Novel {
                                title = novel.title,
                                link = novel.link,
                                imageURL = novel.imageURL
                            })
                        end
                    end
                end
            end
            if not nextPageLink then break end
            currentStartPage = currentStartPage + pageBatchSize
        end
        queryCache[query] = matchingNovels
    end

    local perPage = 20
    local startIndex = (page - 1) * perPage + 1
    local endIndex = math.min(startIndex + perPage - 1, #matchingNovels)
    if startIndex > #matchingNovels then return {} end
    local paged = {}
    for i = startIndex, endIndex do
        if matchingNovels[i] then table.insert(paged, matchingNovels[i]) end
    end
    return paged
end

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