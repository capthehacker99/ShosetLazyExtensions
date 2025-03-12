-- {"id":347719483,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 347719483

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Lazy Translations"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://lazytranslations.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://i0.wp.com/lazytranslations.com/wp-content/uploads/2020/08/cropped-profile-lazykun.jpg?ssl=1"
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
    return url:gsub(".-lazytranslations.com/", "")
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
    local click_my_image = false
    map(htmlElement:select("p.has-larger-font-size"), function(x)
        if x:text():find("Click my image to go to the chapter") then
            click_my_image = true
        end
    end)
    if click_my_image then
        document = GETDocument(expandURL(shrinkURL(htmlElement:selectFirst("figure > a"):attr("href"))))
        htmlElement = document:selectFirst(".entry-content")
    end
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
    local img = document:selectFirst(".wp-block-image img")
    img = img and img:attr("src") or imageURL
    local title = "";
    local trigger_title = false;
    local desc = "";
    local trigger_desc = false;
    map(document:select("entry-content > h3"), function(p)
        local txt = p:text()
        if trigger_desc then
            desc = desc .. txt
            trigger_desc = false
            return
        end
        if trigger_title then
            title = title .. txt
            trigger_title = false
            return
        end
        trigger_desc = false
        trigger_title = false
    end)
	return NovelInfo({
        title = title:gsub("\n" ,""),
        imageURL = img,
        description = desc,
        chapters = AsList(
            mapNotNil(document:select("p a"), function(v)
                local link = shrinkURL(v:attr("href"))
                if link == "" or link:find("akismet.com/privacy") or link:find("membership-account/membership-levels") then
                    return
                end
                return NovelChapter {
                    order = cur,
                    title = v:text(),
                    link = link
                }
            end)
        )
    })
end

local function getListing()
    local document = GETDocument(baseURL)
    local values = {}
    map(document:select("#primary-menu > li"), function(x)
        local y = x:selectFirst("a"):text()
        if(y:find("Translations") or y:find("Originals")) then
            map(x:select("li a[href]"), function(z)
                table.insert(values, Novel {
                    title = z:text(),
                    link = shrinkURL(z:attr("href")),
                    imageURL = imageURL
                })
            end)
        end
    end)
    return values
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
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
