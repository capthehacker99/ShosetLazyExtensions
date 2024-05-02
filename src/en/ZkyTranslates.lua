-- {"id":-1,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":["foo","bar"]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 774525766

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Zky Translates"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://zkytl.wordpress.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://zkytl.files.wordpress.com/2020/07/wp-1595477604772.jpg"

--- Shosetsu tries to handle cloudflare protection if this is set to true.
---
--- Optional, Default is false.
---
--- @type boolean
local hasCloudFlare = false

--- If the website has search.
---
--- Optional, Default is true.
---
--- @type boolean
local hasSearch = false

--- If the websites search increments or not.
---
--- Optional, Default is true.
---
--- @type boolean
local isSearchIncrementing = false

--- Filters to display via the filter fab in Shosetsu.
---
--- Optional, Default is none.
---
--- @type Filter[] | Array
local searchFilters = {}

--- Internal settings store.
---
--- Completely optional.
---  But required if you want to save results from [updateSetting].
---
--- Notice, each key is surrounded by "[]" and the value is on the right side.
--- @type table
local settings = {}

--- Settings model for Shosetsu to render.
---
--- Optional, Default is empty.
---
--- @type Filter[] | Array
local settingsModel = {}

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
--- @param type int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Shrunk URL.
local function shrinkURL(url, type)
    return url:gsub(".-zkytl.wordpress.com/", "")
end

--- Expand a given URL.
---
--- Required.
---
--- @param url string Shrunk URL to expand.
--- @param type int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Full URL.
local function expandURL(url, type)
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
    htmlElement:select("div, hr"):remove()
    map(htmlElement:select("p"), function(v)
        if v:selectFirst("a") ~= nil then
            v:remove()
        end
    end)
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
    local img = document:selectFirst(".entry-content img")
    img = img and img:attr("src") or imageURL
	return NovelInfo({
        title = document:selectFirst(".entry-title"):text():gsub("\n" ,""),
        imageURL = img,
        chapters = AsList(
                map(filter(document:select(".entry-content a"), function(v)
                    local processed = v:text():lower()
                    return v:attr("href"):find("zkytl.wordpress.com") ~= nil
                end), function(v)
                    return NovelChapter {
                        order = v,
                        title = v:text(),
                        link = shrinkURL(v:attr("href"))
                    }
                end)
        )

    })
end

local title_alias = {
    IGO = "The Commoner-Born Imperial General Officer Rises Through the Ranks by Crushing His Incompetent Noble Superiors.",
    UDS = "Unpopular Dungeon Streamer: I Went Viral After Saving A Super Popular And Beautiful Influencer. (Dropped)",
    SLO = "The Slothful Villainous Noble",
    BSO = "Blade Skill Online: With Trash Job ‘Summoner’, Weakest Weapon ‘Bow’, and Rotten Stat ‘Luck’, I Rise to Be the ‘Last Boss’!",
    ZAM = "Kiraware Yūsha ni Tensei Shitanode Aisare Yūsha o Mezashimasu! ~ Subete no 「Zama~a」Furagu o Heshiotte Kenjitsu ni Kurashitai!~",
    PAW = "Pawahara Seijo no Osananajimi to Zetsuen Shitara, Nanimokamo ga Umaku Iku Yō ni Natte Saikyō no Bōken-sha ni Natta ~ Tsuideni Yasashikute Kawaii Yome mo Takusan Dekita ~ (WN)",
    LVL = "[Reberu] ga Arunara Agerudesho? Mobukyara ni Tensei Shita Ore wa Gēmu Chishiki o Ikashi, Hitasura Reberu o Age Tsudzukeru",
    MSM = "A Sword Master Childhood Friend Power Harassed Me Harshly, So I Broke Off Our Relationship And Make A Fresh Start At The Frontier As A Magic Swordsman.",
    OTO = "Oto Tsukai wa Shi to Odoru",
}

local function convert_title(title)
    return title_alias[title] or title
end

local function getListing()
    local document = GETDocument(baseURL)

    return map(filter(document:select("#primary-menu > li > a"), function(v)
        local text = v:text()
        return text ~= "Home" and text ~= "Contact"
    end), function(v)
        return Novel {
            title = convert_title(v:text()),
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
