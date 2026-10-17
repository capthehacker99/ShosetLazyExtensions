-- {"id":1401762246,"ver":"1.0.2","libVer":"1.0.1","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 1401762246

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "WuxiaClick"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://wuxia.click/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://wuxia.click/favicon.ico"
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

--- CDN that hosts every novel cover.
---
--- @type string
local cdnURL = "https://cdn.wuxiaworld.eu/"

--- Cached Next.js build id. Required by the `_next/data` endpoints and
--- resolved from the site HTML so it is never hard coded.
---
--- @type string|nil
local buildID = nil

--- Percent-encode a string so it can be embedded in a path or query segment.
---
--- @param str string String to encode.
--- @return string Encoded string.
local function urlEncode(str)
	if not str then
		return nil
	end
	return (str:gsub("([^%w%-%_%.%~])", function(c)
		return ("%%%02X"):format(string.byte(c))
	end))
end

--- Read (and cache) the current Next.js build id from the site HTML.
---
--- @return string Current build id.
local function getBuildID()
	if buildID then
		return buildID
	end
	local html = dkjson.GET(baseURL)
	buildID = type(html) == "string" and html:match('"buildId":"([^"]+)"') or nil
	if not buildID then
		error("Unable to determine WuxiaClick build id")
	end
	return buildID
end

--- Get a `_next/data` JSON payload. If the build id has rotated the request
--- returns the 404 HTML page, so the build id is refreshed and retried once.
---
--- @param path string Path following the build id, including any query string.
--- @return table Decoded JSON payload.
local function getData(path)
	for _ = 1, 2 do
		local data = dkjson.GET(baseURL .. "_next/data/" .. getBuildID() .. "/" .. path)
		if type(data) == "table" then
			return data
		end
		buildID = nil
	end
	error("WuxiaClick data request failed: " .. path)
end

--- Build the cover image URL for a novel, falling back to the extension logo.
---
--- @param novel table Novel entry with `coverKey` and/or `coverOriginal`.
--- @return string Cover image URL.
local function coverURL(novel)
	if novel.coverKey then
		return cdnURL .. novel.coverKey .. "-480.webp"
	elseif novel.coverOriginal then
		return cdnURL .. novel.coverOriginal
	end
	return imageURL
end

--- Collect the `name` field from each entry in a list.
---
--- @param items table[]|nil List of entries exposing a `name` field.
--- @return table List of names.
local function names(items)
	local result = {}
	if items then
		for _, v in ipairs(items) do
			if v.name then
				table.insert(result, v.name)
			end
		end
	end
	return result
end

--- Shrink the website url down. This is for space saving purposes.
---
--- Required.
---
--- @param url string Full URL to shrink.
--- @param _ int Either KEY_CHAPTER_URL or KEY_NOVEL_URL.
--- @return string Shrunk URL.
local function shrinkURL(url, _)
	return url:gsub("^https?://[^/]+/", ""):gsub("^/", "")
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
	local document = GETDocument(expandURL(chapterURL))
	local content = document:selectFirst("#chapter-content")
	if not content then
		error("Unable to locate chapter content")
	end

	--- Strip ads that the site injects between paragraphs.
	map(content:select("aside, div.adsense-slot, ins.adsbygoogle"), function(v)
		v:remove()
	end)

	return pageOfElem(content, true)
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
	local slug = novelURL:gsub("^/", ""):gsub("^novel/", "")
	local payload = getData("novel/" .. slug .. ".json")
	local novel = payload.pageProps.novel
	slug = novel.slug or slug

	--- Chapter list endpoint caps out at 200 entries, so page through it.
	local chapters = {}
	local cursor = nil
	repeat
		local input = '{"0":{"json":{"novelId":' .. novel.id .. ',"limit":200'
			.. (cursor and ',"cursor":' .. cursor or "") .. '}}}'
		local response = dkjson.GET(baseURL .. "api/trpc/chapter.list?batch=1&input=" .. urlEncode(input))
		local result = response and response[1] and response[1].result
			and response[1].result.data and response[1].result.data.json
		if not result then
			break
		end
		for _, v in ipairs(result.items) do
			table.insert(chapters, NovelChapter {
				order = v.number,
				title = v.title,
				link = "chapter/" .. slug .. "-" .. v.number
			})
		end
		cursor = result.nextCursor
	until not cursor

	local authors = {}
	if novel.author and novel.author.name then
		table.insert(authors, novel.author.name)
	end

	return NovelInfo {
		title = novel.title,
		alternativeTitles = novel.altTitles,
		link = "novel/" .. slug,
		imageURL = coverURL(novel),
		description = novel.description,
		genres = names(novel.genres),
		tags = names(novel.tags),
		authors = authors,
		chapters = AsList(chapters)
	}
end

--- Get the default listing of novels.
---
--- Required.
---
--- @param data table Listing data, containing the current page.
--- @return table List of Novel entries.
local function getListing(data)
	local page = data and data[PAGE] or startIndex
	local payload = getData("browse.json?page=" .. page)

	local novels = {}
	for _, v in ipairs(payload.pageProps.listing.items) do
		table.insert(novels, Novel {
			title = v.title,
			link = "novel/" .. v.slug,
			imageURL = coverURL(v)
		})
	end
	return AsList(novels)
end

--- Search for novels matching the user query.
---
--- @param data table Search data, containing the query and current page.
--- @return table List of Novel entries.
local function search(data)
	local page = data[PAGE]
	local query = data[QUERY]
	local payload = getData("search/" .. urlEncode(query) .. ".json?page=" .. page)

	local novels = {}
	for _, v in ipairs(payload.pageProps.result.items) do
		table.insert(novels, Novel {
			title = v.title,
			link = "novel/" .. v.slug,
			imageURL = coverURL(v)
		})
	end
	return AsList(novels)
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
