-- {"id":638138592,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

local id = 638138592

local name = "NovelsHaven"

local baseURL = "https://novelshaven.com/"

local imageURL = "https://novelshaven.com/icon.png"

local chapterType = ChapterType.HTML

local startIndex = 1

local function shrinkURL(url, _)
    return url:gsub(".-novelshaven.com/", "")
end

local function expandURL(url, _)
    return baseURL .. url
end

local function getRSC(document)
    local payloads = {}
    local scripts = document:select("script")
    for i = 0, scripts:size() - 1 do
        local s = scripts:get(i)
        local raw = tostring(s)
        local marker = 'self.__next_f.push([1,"'
        local m_start = raw:find(marker, 1, true)
        if m_start then
            local cs = m_start + #marker
            local j = cs
            while j <= #raw do
                local c = raw:sub(j, j)
                if c == '\\' then
                    j = j + 2
                elseif c == '"' then
                    break
                else
                    j = j + 1
                end
            end
            local encoded = raw:sub(cs, j - 1)
            local decoded = encoded:gsub('\\"', '"'):gsub("\\n", "\n"):gsub("\\\\", "\\")
            table.insert(payloads, decoded)
        end
    end
    return table.concat(payloads)
end

local function extractSeriesFromRSC(rsc)
    local series = {}
    local seen = {}
    for slug in rsc:gmatch('"/series/([a-z0-9][a-z0-9%-]+)"') do
        if not slug:find("^chapter") and not slug:find("^ranking") and not seen[slug] then
            seen[slug] = true
            local ctx_start = rsc:find(slug, 1, true)
            if ctx_start then
                local ctx = rsc:sub(ctx_start, math.min(ctx_start + 3000, #rsc))
                local title = nil
                local skip = {["Chapters:"]=true, ["Views:"]=true, ["Bookmarks:"]=true, ["Ranking:"]=true}
                for v in ctx:gmatch('"children":"([^"]+)"') do
                    if not skip[v] and #v > 5 and not v:find("^inline%-") and not v:find("^flex") and not v:find("^lucide") and not v:find("^sr%-only") and not v:find("^text%-") and not v:find("^dark") then
                        title = v
                        break
                    end
                end
                local status = nil
                for _, s in ipairs({"Ongoing", "Completed", "Dropped", "Hiatus"}) do
                    if ctx:find('"children":"' .. s .. '"') then
                        status = s:lower()
                        break
                    end
                end
                local cover = ctx:match('"src":"(https://cdn%.novelshaven%.com/[^"]+)"')
                table.insert(series, {
                    slug = slug,
                    title = title,
                    status = status,
                    cover_url = cover
                })
            end
        end
    end
    return series
end

local function extractSeriesFromHTML(document)
    local series = {}
    local seen = {}
    local links = document:select('a[href^="/series/"]')
    for i = 0, links:size() - 1 do
        local a = links:get(i)
        local href = a:attr("href")
        if href then
            local slug = href:match("^/series/([a-z0-9][a-z0-9%-]+)$")
            if slug and not slug:find("^chapter") and not slug:find("^ranking") and not seen[slug] then
                seen[slug] = true
                local title = a:text()
                if not title or #title < 3 then title = slug end
                table.insert(series, {
                    slug = slug,
                    title = title
                })
            end
        end
    end
    return series
end

local function getPassage(chapterURL)
    local url = expandURL(chapterURL)
    local document = GETDocument(url)
    local article = document:selectFirst("article")
    if article then
        return pageOfElem(article, true)
    end
    return "Could not extract chapter content."
end

local function parseNovel(novelURL)
    local url = expandURL(novelURL)
    local document = GETDocument(url)
    local rsc = getRSC(document)
    local title = nil
    local title_el = document:selectFirst("h1")
    if title_el then title = title_el:text() end
    if not title or #title == 0 then title = rsc:match('"title":"([^"]+)"') end
    local cover = rsc:match('"cover_url":"(https://cdn%.novelshaven%.com/[^"]+)"')
    if not cover then
        local img = document:selectFirst("img")
        if img then cover = img:attr("src") end
    end
    local desc = rsc:match('"synopsis":"((?:[^"\\]|\\.)*)"')
    if desc then
        desc = desc:gsub("\\r\\n", "\n"):gsub("\\n", "\n"):gsub('\\"', '"')
    end
    local chapters = {}
    local seen_chapters = {}
    local html_chapters = document:select('a[href*="/chapter-"]')
    for i = 0, html_chapters:size() - 1 do
        local a = html_chapters:get(i)
        local href = a:attr("href")
        if href then
            local num = href:match("/chapter%-(%d+)")
            if num then
                local n = tonumber(num)
                if n and not seen_chapters[n] then
                    seen_chapters[n] = true
                    local link = href:gsub(".*novelshaven%.com", "")
                    if not link:find("^/") then link = "/" .. link end
                    table.insert(chapters, NovelChapter({
                        order = n,
                        title = "Chapter " .. n,
                        link = shrinkURL(link)
                    }))
                end
            end
        end
    end
    table.sort(chapters, function(a, b)
        local ao = a.order or 0
        local bo = b.order or 0
        return ao < bo
    end)
    return NovelInfo({
        title = title,
        imageURL = cover or imageURL,
        description = desc or "",
        chapters = chapters
    })
end

local function getListing(data)
    local page = data[PAGE]
    local document = GETDocument(expandURL("series?page=" .. page))
    local rsc = getRSC(document)
    local series = extractSeriesFromRSC(rsc)
    if #series == 0 then
        series = extractSeriesFromHTML(document)
    end
    return map(series, function(s)
        return Novel({
            title = s.title or s.slug,
            link = "/series/" .. s.slug,
            imageURL = s.cover_url or imageURL
        })
    end)
end

local function search(data)
    local query = data[QUERY]:lower()
    local page = data[PAGE]
    local results = {}
    local start_page = (page - 1) * 3 + 1
    for p = start_page, start_page + 2 do
        local document = GETDocument(expandURL("series?page=" .. p))
        local rsc = getRSC(document)
        local series = extractSeriesFromRSC(rsc)
        if #series == 0 then
            series = extractSeriesFromHTML(document)
        end
        if #series == 0 then break end
        for _, s in ipairs(series) do
            if s.title and s.title:lower():find(query, 1, true) then
                table.insert(results, Novel({
                    title = s.title,
                    link = "/series/" .. s.slug,
                    imageURL = s.cover_url or imageURL
                }))
            end
        end
    end
    return results
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
    isSearchIncrementing = true,
    search = search,
    imageURL = imageURL,
    chapterType = chapterType,
    startIndex = startIndex,
}
