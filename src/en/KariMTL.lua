local json = Require("dkjson")
-- {"id":-1,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":["foo","bar"]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1440948051

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Kari MTL"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://karimtl.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://karimtl.com/wp-content/uploads/2023/11/cropped-pngwing.com_-1.png"

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
    return url:gsub(".-karimtl.com/", "")
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
    local htmlElement = document:selectFirst(".bs-blog-post")
    htmlElement:select("#donation-msg, #novel_nav"):remove()
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
    document:select("script"):remove()
    local img = document:selectFirst("#novel_info img")
    img = img and img:attr("src") or imageURL
    local desc = document:selectFirst("#novel_info_right")
    if desc then
        local full_str = ""
        map(desc:select("p"), function(p)
            full_str = full_str .. '\n' .. p:text()
        end)
        desc = full_str
    end
    local selected = document:select(".novel_index > li > a")
    local cur = selected:size() + 1
	return NovelInfo({
        title = document:selectFirst(".title a"):text():gsub("\n" ,""),
        imageURL = img,
        description = desc,
        chapters = AsList(
            map(filter(selected, function(v)
                return v:attr("href"):find("karimtl.com") ~= nil
            end), function(v)
                cur = cur - 1;
                return NovelChapter {
                    order = v,
                    title = v:text(),
                    link = shrinkURL(v:attr("href"))
                }
            end)
        )

    })
end

local function process_image(img)
    if not img then
        return imageURL
    end
    local style = img:attr("style")
    if not style then
        return imageURL
    end
    local url = style:gmatch("url%([^ \n\t\r)]*")()
    if not url or #url < 5 then
        return imageURL
    end
    return url:sub(5)
end

local function getListing()
    local document = GETDocument(baseURL)
    local info = document:selectFirst("#tc-caf-frontend-scripts-js-extra")
    if not info then
        return {}
    end
    info = tostring(info):gmatch("{[^}]*")()
    if not info then
        return {}
    end
    info = json.decode(info .. '}')
    local req = Request(
        POST(info.ajax_url, nil,
            FormBodyBuilder()
                :add("action", "get_filter_posts")
                :add("nonce", info.nonce)
                :add("params[page]", "1")
                :add("params[tax]", "post_tag")
                :add("params[post-type]", "post")
                :add("params[term]", "417,418,443,419,422,423,433,436,431,437,415,428,438,394,424,439,429,441,420,425,442,421,434,440,435,416,427,426,430,432")
                :add("params[per-page]", "1000")
                :add("params[filter-id]", "8098")
                :add("params[caf-post-layout]", "post-layout3")
                :add("params[data-target-div]", ".data-target-div1")
                :build()
        )
    )
    info = json.decode(req:body():string())
    if info.status ~= 200 then
        return {}
    end
    local listing = Document(info.content)
    return map(listing:select("article > div"), function(v)
        local title = v:select("div > .caf-post-title a")
        return Novel {
            title = title:text(),
            link = shrinkURL(title:attr("href")),
            imageURL = process_image(v:selectFirst(".caf-featured-img-box"))
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
