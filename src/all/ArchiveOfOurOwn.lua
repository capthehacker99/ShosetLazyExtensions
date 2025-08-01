-- {"id":236580412,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 236580412

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Archive of Our Own"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://archiveofourown.org/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://archiveofourown.org/images/ao3_logos/logo_42.png"
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
    return url:gsub(".-archiveofourown.org/", "")
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
	local url = expandURL(chapterURL .. "?view_adult=true")

	--- Chapter page, extract info from it.
	local document = GETDocument(url)
    local htmlElement = document:selectFirst("#chapters")
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
	local document = GETDocument(url .. "?view_adult=true")
    local allChapters = {}
    local chapters = document:select("#selected_id > option")
    if chapters:size() <= 0 then
        table.insert(allChapters, NovelChapter {
            title = (document:selectFirst(".chapter .title") or document:selectFirst(".title.heading")):text();
            link = novelURL;
        })
    else
        map(chapters, function (v)
            table.insert(allChapters, NovelChapter {
                title = v:text();
                link = novelURL .. "/chapters/" .. v:attr("value");
            })
        end)
    end
	return NovelInfo({
        title = document:selectFirst(".title.heading"):text():gsub("\n" ,"");
        imageURL = imageURL;
        chapters = AsList(allChapters);
    })
end

local function getListing(data)
    local document = GETDocument(expandURL("works/search?page=" .. data[PAGE] .. "&work_search[query]="))

    return mapNotNil(document:select(".work .header h4 a"), function(v)
        local link = v:attr("href")
        if not link:find("/works/") then
            return
        end
        return Novel {
            title = v:text(),
            link = link,
            imageURL = imageURL
        }
    end)
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
    local matched = data[QUERY]:match("/works/(%d+)/")
    if matched then
        return AsList({
            Novel {
                title = "URL Import",
                link = "/works/" .. matched,
                imageURL = imageURL
            }
        })
    end
    local document = GETDocument(expandURL("works/search?page=" .. data[PAGE] .. "&work_search[query]=" .. urlEncode(data[QUERY])))

    return mapNotNil(document:select(".work .header h4 a"), function(v)
        local link = v:attr("href")
        if not link:find("/works/") then
            return
        end
        return Novel {
            title = v:text(),
            link = link,
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
