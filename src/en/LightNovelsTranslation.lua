-- {"id":861033045,"ver":"1.0.0","libVer":"1.0.1","author":"","repo":"","dep":["dkjson"]}
local dkjson = Require("dkjson")

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 861033045

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Light Novels Translations"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://lightnovelstranslations.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://lightnovelstranslations.com/wp-content/uploads/2020/12/cropped-favicon-32px-192x192.png"

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
	return url:gsub(".-lightnovelstranslations%.com/", "")
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

--- Percent-encode a string for use in a URL query.
---
--- @param str string Text to encode.
--- @return string Encoded text.
local function urlEncode(str)
	if str then
		str = str:gsub("([^%w %-%_%.%~])", function(c)
			return ("%%%02X"):format(string.byte(c))
		end)
		str = str:gsub(" ", "+")
	end
	return str
end

--- Build the browse URL for a given page and optional query.
---
--- @param page number Page index, starting at 1.
--- @param query string|nil Search query, nil for the default listing.
--- @return string Full browse URL.
local function browseURL(page, query)
	local path = "browse/"
	if page > 1 then
		path = "browse/page/" .. page .. "/"
	end
	local params = {}
	if query ~= nil then
		table.insert(params, "field-search=" .. urlEncode(query))
		table.insert(params, "status=all")
		table.insert(params, "type=all")
	end
	table.insert(params, "sortby=most-recent")
	return baseURL .. path .. "?" .. table.concat(params, "&")
end

--- Convert a browse page into a list of novels.
---
--- @param document Document Parsed browse page.
--- @return table List of Novel.
local function parseNovelCards(document)
	return mapNotNil(document:select("article.read_list-story-item"), function(card)
		local anchor = card:selectFirst("h3 a")
		if not anchor then
			return nil
		end
		local image = card:selectFirst(".item_thumb img")
		local coverURL = image and image:attr("src") or nil
		if coverURL and (coverURL:find("banner%-wordmark") or coverURL:find("no%-image")) then
			coverURL = nil
		end
		return Novel {
			title = anchor:text(),
			link = shrinkURL(anchor:attr("href")),
			imageURL = coverURL
		}
	end)
end

--- Get a chapter passage based on its chapterURL.
---
--- Required.
---
--- @param chapterURL string The chapters shrunken URL.
--- @return string Strings in lua are byte arrays.
local function getPassage(chapterURL)
	local document = GETDocument(expandURL(chapterURL))
	local content = document:selectFirst(".text_story")
	if not content then
		error("Could not find chapter content for " .. chapterURL)
	end
	content:select("script"):remove()
	content:select("style"):remove()
	return pageOfElem(content, true)
end

--- Map the site status text onto a NovelStatus.
---
--- @param value string Status text from the site.
--- @return NovelStatus Mapped status.
local function toNovelStatus(value)
	local text = (value or ""):lower()
	if text:find("ongoing") or text:find("publishing") then
		return NovelStatus.PUBLISHING
	elseif text:find("completed") or text:find("complete") then
		return NovelStatus.COMPLETED
	elseif text:find("hiatus") or text:find("paused") then
		return NovelStatus.PAUSED
	end
	return NovelStatus.UNKNOWN
end

--- Fetch every chapter of a single volume, following the chapter page links.
---
--- @param novelPath string Shrunken novel path, such as "novel/slug/".
--- @param volumeId string Volume identifier used by the table of contents.
--- @param total number Expected number of chapters in the volume.
--- @param chapters table Chapter list that chapters are appended to.
local function fetchVolumeChapters(novelPath, volumeId, total, chapters)
	local collected = 0
	local seen = {}
	local page = 1
	while page <= 50 do
		local url = baseURL .. novelPath .. "?tab=table_contents&lnt_volume=" .. volumeId .. "&lnt_fragment=toc"
		if page > 1 then
			url = url .. "&lnt_page=" .. page
		end
		local payload = dkjson.GET(url)
		local html = payload and payload.data and payload.data.html
		if not html then
			break
		end
		local document = Document("<body>" .. html .. "</body>")
		local rows = document:select("li.chapter-item")
		if rows:size() == 0 then
			break
		end
		local before = #chapters
		map(rows, function(item)
			local classes = item:attr("class") or ""
			if classes:find("lock") and not classes:find("unlock") then
				return
			end
			local chapterId = item:attr("data-chapter-id")
			if chapterId == nil or chapterId == "" or seen[chapterId] then
				return
			end
			local anchor = item:selectFirst("a")
			if not anchor then
				return
			end
			local title = anchor:attr("title")
			if title == nil or title == "" then
				title = anchor:text()
			end
			title = title:gsub("^%d+%.%s*", "")
			seen[chapterId] = true
			collected = collected + 1
			table.insert(chapters, NovelChapter {
				order = #chapters + 1,
				title = title,
				link = shrinkURL(anchor:attr("href"))
			})
		end)
		if #chapters == before or (total > 0 and collected >= total) then
			break
		end
		page = page + 1
	end
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
	local document = GETDocument(expandURL(novelURL))

	local titleElement = document:selectFirst(".novel_title h3")
	local imageElement = document:selectFirst(".novel-image img")
	local descriptionElement = document:selectFirst("#about .novel_text")
	local metaDescription = document:selectFirst("meta[name=description]")
	local statusElement = document:selectFirst(".novel_status")

	local novelImage = imageElement and imageElement:attr("src") or nil
	if novelImage and (novelImage:find("banner%-wordmark") or novelImage:find("no%-image")) then
		novelImage = nil
	end

	local description = descriptionElement and descriptionElement:text() or nil
	if description == nil or description == "" then
		description = metaDescription and metaDescription:attr("content") or ""
	end

	local author = nil
	map(document:select(".novel_detail_info li"), function(item)
		local label = item:selectFirst("span")
		if label and label:text():find("Author") then
			author = item:text():gsub("^%s*Author:%s*", "")
		end
	end)

	local genres = mapNotNil(document:select(".novel_tags_item span"), function(tag)
		local text = tag:text()
		if text == nil or text == "" then
			return nil
		end
		return text
	end)

	local chapters = {}
	map(document:select("a.lnt-volume-link"), function(volumeLink)
		local container = volumeLink:attr("aria-controls")
		local volumeId = container and container:match("lnt%-volume%-(%d+)")
		if not volumeId then
			local href = volumeLink:attr("href")
			volumeId = href and href:match("lnt_volume=(%d+)")
		end
		local countElement = volumeLink:selectFirst("span")
		local total = tonumber(countElement and countElement:text():match("(%d+)")) or 0
		if not volumeId then
			return
		end
		fetchVolumeChapters(novelURL, volumeId, total, chapters)
	end)

	return NovelInfo {
		title = titleElement and titleElement:text() or name,
		imageURL = novelImage or imageURL,
		description = description,
		authors = author and { author } or nil,
		genres = genres,
		status = toNovelStatus(statusElement and statusElement:text() or ""),
		chapters = chapters
	}
end

--- Get a list of novels for the default listing.
---
--- Required.
---
--- @param data table Contains PAGE.
--- @return table List of Novel.
local function getListing(data)
	local page = data[PAGE] or startIndex
	local document = GETDocument(browseURL(page, nil))
	return AsList(parseNovelCards(document))
end

--- Search for novels using the browse search.
---
--- Optional.
---
--- @param data table Contains QUERY and PAGE.
--- @return table List of Novel.
local function search(data)
	local query = data[QUERY]
	local page = data[PAGE] or startIndex
	local document = GETDocument(browseURL(page, query))
	return AsList(parseNovelCards(document))
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
