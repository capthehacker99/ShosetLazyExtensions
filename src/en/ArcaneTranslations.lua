-- {"id":639193459,"ver":"1.0.6","libVer":"1.0.0","author":"","repo":"","dep":[]}
local dkjson = Require("dkjson")
--- Identification number of the extension.
--- Should be unique. Should be consistent in all references.
---
--- Required.
---
--- @type int
local id = 639193459

--- Name of extension to display to the user.
--- Should match index.
---
--- Required.
---
--- @type string
local name = "Novel Dex"

--- Base URL of the extension. Used to open web view in Shosetsu.
---
--- Required.
---
--- @type string
local baseURL = "https://noveldex.io/"

--- URL of the logo.
---
--- Optional, Default is empty.
---
--- @type string
local imageURL = "https://noveldex.io/_next/image?url=%2Fuploads%2Fsettings%2Flogo-9f6ca6403bb40c476fb1c57fa981d6bc.webp&w=256&q=75"
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
    return url:gsub(".-noveldex.io/", "")
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

local function bxor(a, b)
  local r, p = 0, 1
  while a > 0 or b > 0 do
    if (a % 2) ~= (b % 2) then r = r + p end
    a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
  end
  return r
end

local function band(a, b)
  local r, p = 0, 1
  while a > 0 and b > 0 do
    if (a % 2) == 1 and (b % 2) == 1 then r = r + p end
    a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
  end
  return r
end

local function bor(a, b)
  local r, p = 0, 1
  while a > 0 or b > 0 do
    if (a % 2) == 1 or (b % 2) == 1 then r = r + p end
    a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
  end
  return r
end

local function lshift(x, n) return x * (2 ^ n) end

local function rshift(x, n) return math.floor(x / (2 ^ n)) end

local function mul32(a, b)
  local r = 0
  while b > 0 do
    if b % 2 == 1 then r = (r + a) % 4294967296 end
    a = (a * 2) % 4294967296
    b = math.floor(b / 2)
  end
  return r
end

local function derive_key(hint, ts, nonce)
  local s = hint .. "|" .. ts .. "|" .. nonce
  local hash = 0x811c9dc5
  for i = 1, #s do
    hash = bxor(hash, s:byte(i))
    hash = mul32(hash, 0x1000193)
  end
  local key = {}
  for i = 0, 31 do
    hash = bxor(hash, band(i * 0x9e3779b9, 0xFFFFFFFF))
    hash = mul32(hash, 0x1000193)
    key[i+1] = band(hash, 0xFF)
  end
  return key
end

local function xor_decrypt(data, key)
  local res = {}
  for i = 1, #data do
    res[i] = bxor(data[i], key[(i-1) % #key + 1])
  end
  return res
end

local function bytes_to_str(bytes)
  local chars = {}
  for i = 1, #bytes do chars[i] = string.char(bytes[i]) end
  return table.concat(chars)
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64map = {}
for i = 1, 64 do b64map[b64chars:sub(i,i)] = i - 1 end

local function base64_decode(s)
  s = s:gsub("[^%w%+/=]", "")
  local res = {}
  for i = 1, #s, 4 do
    local chunk = s:sub(i, i+3)
    local a = b64map[chunk:sub(1,1)] or 0
    local b = b64map[chunk:sub(2,2)] or 0
    local c = b64map[chunk:sub(3,3)] or 0
    local d = b64map[chunk:sub(4,4)] or 0
    local n = bor(bor(lshift(a, 18), lshift(b, 12)), bor(lshift(c, 6), d))
    res[#res+1] = band(rshift(n, 16), 0xFF)
    if chunk:sub(3,3) ~= "=" then res[#res+1] = band(rshift(n, 8), 0xFF) end
    if chunk:sub(4,4) ~= "=" then res[#res+1] = band(n, 0xFF) end
  end
  return res
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
    local has_encrypt;
    map(document:select("script"), function(val)
        if has_encrypt then return end
        for a in tostring(val):gmatch("(%b())") do
            local div_match, _ = a:match("xorEncryption\":(%b{})")
            if div_match then
                local decoded = dkjson.decode(div_match)
                has_encrypt = decoded
                return
            end
        end
        return
    end)
    local result;
    map(document:select("script"), function(val)
        if has_encrypt then
            for a in tostring(val):gmatch("(%b())") do
                local b64_match, _ = a:match("\"([0-9a-zA-Z+/=]*)\"")
                if b64_match then
                    local new_result = base64_decode(b64_match)
                    if not result or #new_result > #result then
                        result = new_result
                    end
                end
            end
        else
            if result then return end
            for a in tostring(val):gmatch("(%b())") do
                local div_match, _ = a:match("\"\\u003cdiv\\u003e(.*)\\u003c/div\\u003e")
                if div_match then
                    result = div_match
                    return
                end
            end
        end
        return
    end)
    if has_encrypt then
        local key = derive_key(has_encrypt.partialKeyHint, has_encrypt.timestamp, has_encrypt.clientNonce)
        local decrypted_bytes = xor_decrypt(result, key)
        result = bytes_to_str(decrypted_bytes)
    end
    if not result then
        error("Passage content not found")
    end
    result = dkjson.decode("{\"text\":\"" .. result .. "\"}").text
    return pageOfElem(Document("<body>" .. result .. "</body>"):selectFirst("body"), true)
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
    local series;
    local chapters_data;
    map(document:select("script"), function(val)
        local script_val = tostring(val)
        local series_match = script_val:match("series\\\":(%b{})")
        if series_match then
            local raw_json, _ = series_match:gsub("\\\"", "\""):gsub("\\\\n", "\\n"):gsub("\\\\r", "\\r")
            local parsed_series = dkjson.decode(raw_json)
            if parsed_series then
                series = parsed_series
            end
        end
        local chapters_data_match = script_val:match("chapters\\\":(%b[])")
        if chapters_data_match then
            local raw_json, _ = chapters_data_match:gsub("\\\"", "\""):gsub("\\\\n", "\\n"):gsub("\\\\r", "\\r")
            local parsed_chapters_data = dkjson.decode(raw_json)
            if parsed_chapters_data then
                chapters_data = parsed_chapters_data
            end
        end
    end)
    if not series then
        error("Series data not found")
    end
    if not chapters_data then
        error("Chapters data not found")
    end
    local chapters = {}
    for _, chapter in next, chapters_data do
        if not chapter.isLocked then
            table.insert(chapters, NovelChapter {
                order = chapter.number,
                title = chapter.title,
                link = novelURL .. "/chapter/" .. chapter.number
            })
        end
    end
	return NovelInfo({
        title = series.title,
        imageURL = expandURL(series.coverImage),
        description = series.description,
        chapters = AsList(chapters)
    })
end

local function getListing(data)
    local novel_data = dkjson.GET(expandURL("api/series?page=" .. data[PAGE] .. "&limit=100"))
    local novels = {}
    for _, v in next, novel_data.data do
        table.insert(novels, Novel {
            title = v.title,
            link = "series/novel/" .. v.urlSlug,
            imageURL = expandURL(v.coverImage)
        })
    end
    return AsList(novels)
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local novel_data = dkjson.GET(expandURL("api/series?q=" .. urlEncode(query) .. "&page=" .. page .. "&limit=100"))
    local novels = {}
    for _, v in next, novel_data.data do
        table.insert(novels, Novel {
            title = v.title,
            link = "series/novel/" .. v.urlSlug,
            imageURL = expandURL(v.coverImage)
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
