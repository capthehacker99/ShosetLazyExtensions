-- {"id":685751804,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":[]}

--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 685751804

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Shin Translations"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://shintranslations.com/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://shintranslations.com/wp-content/uploads/2025/04/cropped-ShinLogoNew2-200x200.webp"

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
	return url:gsub("^https?://shintranslations%.com/", "")
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

--- Build the series listing URL for a page.
---
--- @param page number Page index, starting at 1.
--- @return string Full listing URL.
local function listingURL(page)
	if page <= 1 then
		return baseURL .. "series/"
	end
	return baseURL .. "series/page/" .. page .. "/"
end

--- Convert a series listing page into a list of novels.
---
--- @param document Document Parsed listing page.
--- @param query string|nil Optional query used to filter cards by title or summary.
--- @return table List of Novel.
local function parseNovelCards(document, query)
	return mapNotNil(document:select("article.post"), function(card)
		local anchor = card:selectFirst("h2.post__title a")
		if not anchor then
			return nil
		end
		local title = anchor:text()
		if not title or title == "" then
			return nil
		end
		if query and query ~= "" then
			local summary = card:selectFirst("section.post__main")
			local haystack = title
			if summary then
				haystack = haystack .. " " .. summary:text()
			end
			if not haystack:lower():find(query, 1, true) then
				return nil
			end
		end
		return Novel {
			title = title,
			link = shrinkURL(anchor:attr("href"))
		}
	end)
end

--- Strip leading and trailing whitespace from a string.
---
--- @param text string Text to trim.
--- @return string Trimmed text.
local function trim(text)
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	text = text:gsub("^\194\160+", ""):gsub("\194\160+$", "")
	return text
end

--- Labels used by the series description for its metadata block.
local METADATA_LABELS = {
	"Novel title",
	"English title",
	"Alternative title",
	"Alternative titles",
	"Shortened title",
	"Author",
	"Illustrator",
	"Translator",
	"Editor",
	"Proofreader",
}

--- Check whether a paragraph starts a series metadata label.
---
--- @param text string Paragraph text.
--- @return boolean True when the paragraph is a metadata label.
local function isMetadata(text)
	for _, label in ipairs(METADATA_LABELS) do
		if text:find(label, 1, true) == 1 and text:sub(#label + 1):match("^%s*:") then
			return true
		end
	end
	return false
end

--- Remove advertisements and subscription widgets from the series content.
---
--- @param content Element The series content element.
local function cleanupContent(content)
	content:select("div.code-block"):remove()
	content:select("div.wp-block-group"):remove()
	content:select("div.wp-block-jetpack-subscriptions"):remove()
	content:select("div.more-link-wrapper"):remove()
	content:select("hr"):remove()
	content:select("h3"):remove()
	content:select("span[id^=more-]"):remove()
end

--- Get a chapter passage based on its chapterURL.
---
--- Required.
---
--- @param chapterURL string The chapters shrunken URL.
--- @return string Strings in lua are byte arrays.
local function getPassage(chapterURL)
	local document = GETDocument(expandURL(chapterURL))
	local content = document:selectFirst("#chapter-content")
	if not content then
		error("Could not find chapter content for " .. chapterURL)
	end
	content:select("script"):remove()
	content:select("style"):remove()
	content:select("div.code-block"):remove()
	content:select("div.wp-block-group"):remove()
	content:select("div.wp-block-jetpack-subscriptions"):remove()
	return pageOfElem(content, true)
end

--- Load info on a novel.
---
--- Required.
---
--- @param novelURL string shrunken novel url.
--- @return NovelInfo
local function parseNovel(novelURL)
	local document = GETDocument(expandURL(novelURL))

	local titleElement = document:selectFirst(".collection__title")
	local content = document:selectFirst(".collection__content")

	local author = nil
	local description = ""

	if content then
		map(content:select("p"), function(paragraph)
			local text = trim(paragraph:text())
			if author == nil then
				local value = text:match("^Authors?%s*:%s*(.+)$")
				if value then
					value = trim(value)
					if value ~= "" then
						author = value
					end
				end
			end
		end)

		cleanupContent(content)

		local paragraphs = {}
		local skipRest = false
		map(content:select("p"), function(paragraph)
			if skipRest then
				return
			end
			local text = trim(paragraph:text())
			if text == "" then
				return
			end
			if isMetadata(text) then
				skipRest = true
				return
			end
			table.insert(paragraphs, text)
		end)
		description = table.concat(paragraphs, "\n\n")
	end

	if description == "" then
		local meta = document:selectFirst("meta[name=description]")
		if meta then
			description = meta:attr("content") or ""
		end
	end

	local status = NovelStatus.UNKNOWN
	local hasOngoing = false
	local hasCompleted = false
	map(document:select(".card__footer-status"), function(element)
		local classes = element:attr("class") or ""
		if classes:find("_ongoing", 1, true) then
			hasOngoing = true
		elseif classes:find("_completed", 1, true) then
			hasCompleted = true
		end
	end)
	if hasOngoing then
		status = NovelStatus.PUBLISHING
	elseif hasCompleted then
		status = NovelStatus.COMPLETED
	end

	local volumeLinks = {}
	map(document:select("h3.card__title a"), function(anchor)
		local href = anchor:attr("href")
		if href and href ~= "" then
			table.insert(volumeLinks, href)
		end
	end)

	-- The site lists the newest volume first, while chapters ascend inside a volume.
	local chapters = {}
	local coverURL = nil
	for i = #volumeLinks, 1, -1 do
		local volumeDocument = GETDocument(volumeLinks[i])
		if coverURL == nil then
			local cover = volumeDocument:selectFirst(".story__thumbnail-image")
			if cover then
				coverURL = cover:attr("src")
			end
		end
		map(volumeDocument:select("a.chapter-group__list-item-link"), function(anchor)
			local link = anchor:attr("href")
			if link == nil or link == "" then
				return
			end
			local chapterTitle = trim(anchor:text())
			if chapterTitle == "" then
				return
			end
			table.insert(chapters, NovelChapter {
				order = #chapters + 1,
				title = chapterTitle,
				link = shrinkURL(link)
			})
		end)
	end

	if coverURL == nil then
		local cover = document:selectFirst(".card__image img")
		if cover then
			coverURL = cover:attr("src")
		end
	end

	return NovelInfo {
		title = titleElement and trim(titleElement:text()) or name,
		imageURL = coverURL or imageURL,
		description = description,
		authors = author and { author } or nil,
		genres = mapNotNil(document:select(".collection__taxonomies a.tag-pill"), function(tag)
			local text = trim(tag:text())
			if text == "" then
				return nil
			end
			return text
		end),
		status = status,
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
	return AsList(parseNovelCards(GETDocument(listingURL(page))))
end

--- Search for novels by filtering the series listing on title and summary.
---
--- Optional.
---
--- @param data table Contains QUERY and PAGE.
--- @return table List of Novel.
local function search(data)
	local query = data[QUERY] or ""
	local results = {}
	local page = startIndex
	while page <= 50 do
		local document = GETDocument(listingURL(page))
		map(parseNovelCards(document, query), function(novel)
			table.insert(results, novel)
		end)
		if not document:selectFirst("a.next.page-numbers") then
			break
		end
		page = page + 1
	end
	return AsList(results)
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
	isSearchIncrementing = false,
	search = search,
	imageURL = imageURL,
	chapterType = chapterType,
	startIndex = startIndex,
}
