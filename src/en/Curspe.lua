-- {"id":1113924916,"ver":"1.0.0","libVer":"1.0.0","author":"","repo":"","dep":["dkjson"]}
local dkjson = Require("dkjson")

local id = 1113924916

local name = "Curspe"

local baseURL = "https://curspe.com/"

local imageURL = "https://curspe.com/wp-content/uploads/2025/11/cropped-ava_211686_1749960656-192x192.jpg"

local chapterType = ChapterType.HTML

local startIndex = 1

local function shrinkURL(url, _)
	return url:gsub(".-curspe.com/", "")
end

local function expandURL(url, _)
	return baseURL .. url
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

local function extractCover(novel)
	local embedded = novel["_embedded"]
	if embedded then
		local media = embedded["wp:featuredmedia"]
		if type(media) == "table" and media[1] then
			local sizes = media[1]["media_details"] and media[1]["media_details"]["sizes"] or {}
			for _, size in ipairs({ "novel-cover-single", "novel-cover", "medium", "full" }) do
				if sizes[size] and sizes[size]["source_url"] then
					return sizes[size]["source_url"]
				end
			end
			if media[1]["source_url"] then
				return media[1]["source_url"]
			end
		end
	end
	return imageURL
end

local function getPassage(chapterURL)
	local url = expandURL(chapterURL)
	local slug = url:match("/chapter%-([^/]+)/")
	if not slug then
		error("chapter slug not found: " .. url)
	end
	local data = dkjson.GET(expandURL("wp-json/wp/v2/chapter?slug=chapter-" .. slug .. "&_fields=id,title,slug,link,content"))
	if type(data) ~= "table" or not data[1] or not data[1]["content"] then
		error("chapter content not found")
	end
	local content = data[1]["content"]["rendered"]
	return pageOfElem(Document(content), true)
end

local function fetchDoc(url)
	for _ = 1, 3 do
		local ok, doc = pcall(GETDocument, url)
		if ok and doc then
			return doc
		end
	end
	return nil
end

local function parseNovel(novelURL)
	local url = expandURL(novelURL)
	local slug = url:match("/novels/([^/]+)/")
	local doc = fetchDoc(url)
	if not doc then
		return NovelInfo({ title = "Unknown", description = "" })
	end
	if not slug then
		slug = (url .. "/"):match("/([^/]+)/$") or ""
	end

	local title = ""
	local t = doc:selectFirst(".wn-title")
	if t then title = t:text() end

	local cover = nil
	local img = doc:selectFirst(".wn-cover img")
	if img then cover = img:attr("src") end
	if not cover or cover == "" then cover = imageURL end

	local description = ""
	local syn = doc:selectFirst(".wn-synopsis")
	if syn then description = syn:text() end

	local details = {}
	local n = 0
	map(doc:select(".wn-meta .wn-meta-value"), function(v)
		n = n + 1
		table.insert(details, n, v:text())
	end)

	local authors = {}
	if details[1] and details[1] ~= "" then
		table.insert(authors, details[1])
	end

	local extras = {}
	if details[2] and details[2] ~= "" then
		table.insert(extras, "Origin: " .. details[2])
	end
	if details[3] and details[3] ~= "" then
		table.insert(extras, "Status: " .. details[3])
	end
	if #extras > 0 then
		description = description .. "\n\n" .. table.concat(extras, "\n")
	end

	local chapters = {}
	local seen = {}
	map(doc:select(".wn-chapter-item"), function(v)
		local href = v:attr("href") or ""
		if href:find(slug, 1, true) and href:find("/chapter-", 1, true) and not seen[href] then
			seen[href] = true
			local num = (href:match("[-/]chapter%-%d+") or ""):match("%d+") or (#chapters + 1)
			local ctitle = "Chapter " .. num
			local ct = v:selectFirst(".wn-chapter-title")
			if ct then ctitle = ct:text() end
			table.insert(chapters, NovelChapter({
				order = tonumber(num) or (#chapters + 1),
				title = ctitle,
				link = shrinkURL(href)
			}))
		end
	end)

	return NovelInfo({
		title = title,
		imageURL = cover,
		description = description,
		authors = #authors > 0 and authors or nil,
		chapters = chapters
	})
end

local function getListing(data)
	local page = data[PAGE]
	local novels = dkjson.GET(expandURL("wp-json/wp/v2/webnovel?per_page=100&page=" .. page .. "&_embed=wp:featuredmedia"))
	if type(novels) ~= "table" then
		return {}
	end
	local results = {}
	for _, v in ipairs(novels) do
		table.insert(results, Novel({
			title = v["title"] and v["title"]["rendered"] or "Unknown",
			link = shrinkURL(v["link"]),
			imageURL = extractCover(v)
		}))
	end
	return results
end

local function search(data)
	local query = data[QUERY]
	local page = data[PAGE]
	local novels = dkjson.GET(expandURL("wp-json/wp/v2/webnovel?search=" .. urlEncode(query) .. "&per_page=100&page=" .. page .. "&_embed=wp:featuredmedia"))
	if type(novels) ~= "table" then
		return {}
	end
	local results = {}
	for _, v in ipairs(novels) do
		table.insert(results, Novel({
			title = v["title"] and v["title"]["rendered"] or "Unknown",
			link = shrinkURL(v["link"]),
			imageURL = extractCover(v)
		}))
	end
	return results
end

return {
	id = id,
	name = name,
	baseURL = baseURL,
	listings = {
		Listing("All", true, getListing)
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