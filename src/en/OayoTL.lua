-- {"id":114035263,"ver":"1.0.5","libVer":"1.0.5","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 114035263

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "OayoTL"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://oayo.ink/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://oayo.ink/wp-content/uploads/2024/10/cropped-logo-1.png"
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
    return url:gsub(".-oayo.ink/", ""):gsub(".-oayo0.wordpress.com/", "")
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
    local htmlElement = document:selectFirst(".entry-content")
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
    local entry_content = document:selectFirst(".entry-content")
    local found_p = false
    local author = "Unknown"
    local desc = ""
    local found_synopsis = false
    local end_of_p = false
    map(entry_content:children(), function(v)
        if end_of_p then return end
        local is_p = tostring(v):match("^<p")
        if is_p then
            local p_text = v:text()
            if found_synopsis then
                desc = desc .. p_text .. "\n\n"
            else
                local cur_author = p_text:match("^Author: (.+)")
                if cur_author then
                    author = cur_author
                elseif p_text == "Synopsis:" then
                    found_synopsis = true
                end
            end
        end
        if found_p then
            if not is_p then
                end_of_p = true
            end
        elseif is_p then
            found_p = true
        end
    end)
    local img = document:selectFirst(".wp-block-image img")
    local links = {}
    map(document:select(".wp-block-query-pagination-numbers a"), function(v)
        table.insert(links, v:attr("href"))
    end)
    local chapters = {}
    local function get_chapters(doc)
        map(doc:select(".wp-block-post-template li a"), function(v)
            table.insert(chapters, NovelChapter {
                order = v,
                title = v:text(),
                link = shrinkURL(v:attr("href"))
            })
        end)
    end
    get_chapters(document)
    for _, page in next, links do
        get_chapters(GETDocument(url .. page))
    end
    for i = 1, math.floor(#chapters/2) do
        local j = #chapters - i + 1
        chapters[i], chapters[j] = chapters[j], chapters[i]
    end

    local header = document:selectFirst(".wp-block-heading strong") or document:selectFirst(".wp-block-heading")
	return NovelInfo({
        title = header:text():gsub("\n" ,""),
        authors = { author },
        description = desc,
        imageURL = img and img:attr("src") or imageURL,
        chapters = AsList(
            chapters
        )
    })
end

local function getListing()
    local document = GETDocument(expandURL("webnovel-tl/"))
    return map(document:select(".entry-content > ul > li a"), function(v)
        return Novel {
            title = v:text(),
            link = shrinkURL(v:attr("href")),
            imageURL = imageURL
        }
    end)
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
    hasSearch = false,
	-- Optional values to change
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
