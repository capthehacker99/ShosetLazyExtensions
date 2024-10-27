-- ABNF from RFC 3629
--
-- UTF8-octets = *( UTF8-char )
-- UTF8-char = UTF8-1 / UTF8-2 / UTF8-3 / UTF8-4
-- UTF8-1 = %x00-7F
-- UTF8-2 = %xC2-DF UTF8-tail
-- UTF8-3 = %xE0 %xA0-BF UTF8-tail / %xE1-EC 2( UTF8-tail ) /
-- %xED %x80-9F UTF8-tail / %xEE-EF 2( UTF8-tail )
-- UTF8-4 = %xF0 %x90-BF 2( UTF8-tail ) / %xF1-F3 3( UTF8-tail ) /
-- %xF4 %x80-8F 2( UTF8-tail )
-- UTF8-tail = %x80-BF

-- 0xxxxxxx                            | 007F   (127)
-- 110xxxxx	10xxxxxx                   | 07FF   (2047)
-- 1110xxxx	10xxxxxx 10xxxxxx          | FFFF   (65535)
-- 11110xxx	10xxxxxx 10xxxxxx 10xxxxxx | 10FFFF (1114111)

local pattern = '[%z\1-\127\194-\244][\128-\191]*'

-- helper function
local posrelat =
function (pos, len)
    if pos < 0 then
        pos = len + pos + 1
    end

    return pos
end

local utf8 = {}

-- THE MEAT

-- maps f over s's utf8 characters f can accept args: (visual_index, utf8_character, byte_index)
utf8.map =
function (s, f, no_subs)
    local i = 0

    if no_subs then
        for b, e in s:gmatch('()' .. pattern .. '()') do
            i = i + 1
            local c = e - b
            f(i, c, b)
        end
    else
        for b, c in s:gmatch('()(' .. pattern .. ')') do
            i = i + 1
            f(i, c, b)
        end
    end
end

-- THE REST

-- generator for the above -- to iterate over all utf8 chars
utf8.chars =
function (s, no_subs)
    return coroutine.wrap(function () return utf8.map(s, coroutine.yield, no_subs) end)
end

-- returns the number of characters in a UTF-8 string
utf8.len =
function (s)
    -- count the number of non-continuing bytes
    return select(2, s:gsub('[^\128-\193]', ''))
end

-- replace all utf8 chars with mapping
utf8.replace =
function (s, map)
    return s:gsub(pattern, map)
end

-- reverse a utf8 string
utf8.reverse =
function (s)
    -- reverse the individual greater-than-single-byte characters
    s = s:gsub(pattern, function (c) return #c > 1 and c:reverse() end)

    return s:reverse()
end

-- strip non-ascii characters from a utf8 string
utf8.strip =
function (s)
    return s:gsub(pattern, function (c) return #c > 1 and '' end)
end

-- like string.sub() but i, j are utf8 strings
-- a utf8-safe string.sub()
utf8.sub =
function (s, i, j)
    local l = utf8.len(s)

    i =       posrelat(i, l)
    j = j and posrelat(j, l) or l

    if i < 1 then i = 1 end
    if j > l then j = l end

    if i > j then return '' end

    local diff = j - i
    local iter = utf8.chars(s, true)

    -- advance up to i
    for _ = 1, i - 1 do iter() end

    local c, b = select(2, iter())

    -- i and j are the same, single-charaacter sub
    if diff == 0 then
        return string.sub(s, b, b + c - 1)
    end

    i = b

    -- advance up to j
    for _ = 1, diff - 1 do iter() end

    c, b = select(2, iter())

    return string.sub(s, i, b + c - 1)
end

local string_char = string.char
utf8.char = function(cp)
    if cp < 128 then
        return string_char(cp)
    end
    local suffix = cp % 64
    local c4 = 128 + suffix
    cp = (cp - suffix) / 64
    if cp < 32 then
        return string_char(192 + cp, c4)
    end
    suffix = cp % 64
    local c3 = 128 + suffix
    cp = (cp - suffix) / 64
    if cp < 16 then
        return string_char(224 + cp, c3, c4)
    end
    suffix = cp % 64
    cp = (cp - suffix) / 64
    return string_char(240 + cp, 128 + suffix, c3, c4)
end

local OR = 1
local XOR = 3
local AND = 4

local function bitoper(a, b, oper)
    local r, m, s = 0, 2^31
    repeat
        s,a,b = a+b+m, a%m, b%m
        r,m = r + m*oper%(s-a-b), m/2
    until m < 1
    return r
end

utf8.byte = function(buf, len, i)
    len = #buf
    i = 1
    local c1 = buf:byte(i, i)
    i = i + 1
    if c1 <= 0x7F then
        return c1 --ASCII
    elseif c1 < 0xC2 then
        --invalid
    elseif c1 <= 0xDF then --2-byte
        if i < len then
            local c2 = buf:byte(i, i)
            if c2 >= 0x80 and c2 <= 0xBF then
                return (bitoper(c1, 0x1F, AND) * (2^6))
                        + bitoper(c2, 0x3F, AND)
            end
        end
    elseif c1 <= 0xEF then --3-byte
        if i < len + 1 then
            local c2, c3 = buf:byte(i, i), buf:byte(i + 1, i + 1)
            if not (
                    c2 < 0x80 or c2 > 0xBF
                            or c3 < 0x80 or c3 > 0xBF
                            or (c1 == 0xE0 and c2 < 0xA0)
                            or (c1 == 0xED and c2 > 0x9F)
            ) then
                return (bitoper(c1, 0x0F, AND) * (2^12))
                        + (bitoper(c2, 0x3F, AND) * (2^6))
                        + bitoper(c3, 0x3F, AND)
            end
        end
    elseif c1 <= 0xF4 then --4-byte
        if i < len + 2 then
            local c2, c3, c4 = buf:byte(i, i), buf:byte(i + 1, i + 1), buf:byte(i + 2, i + 2)
            if not (
                    c2 < 0x80 or c2 > 0xBF
                            or c3 < 0x80 or c3 > 0xBF
                            or c3 < 0x80 or c3 > 0xBF
                            or c4 < 0x80 or c4 > 0xBF
                            or (c1 == 0xF0 and c2 < 0x90)
                            or (c1 == 0xF4 and c2 > 0x8F)
            ) then
                return (bitoper(c1, 0x07, AND) * (2^18))
                        + (bitoper(c2, 0x3F, AND) * (2^12))
                        + (bitoper(c3, 0x3F, AND) * (2^6))
                        + bitoper(c4, 0x3F, AND)
            end
        end
    end
    return c1 --invalid
end

return utf8