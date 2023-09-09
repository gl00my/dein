local proc = {}

local function cur_skip(text, pos)
  local l = 1
  local k = 0
  while l < (pos or 1) do
    local len = utf.next(text, l)
    if len == 0 then
      break
    end
    k = k + 1
    l = l + len
  end
  return k
end

local function text_match(w, fn, ...)
  local s, e = w.buf.cur, #w.buf.text
  local text = w.buf:gettext(s, e)
  local start, fin = fn(text, ...)
  if not start then
    s, e = 1, w.buf.cur
    text = w.buf:gettext(s, e)
    start, fin = fn(text, ...)
  end
  if not start then
    return
  end
  w.buf:resetsel()
  w.buf.cur = s + cur_skip(text, start)
  fin = s + cur_skip(text, fin) + 1
  w.buf:setsel(w.buf.cur, fin)
  w.buf.cur = fin
  w:visible()
end

local function text_replace(w, fn, a, b)
  if not w.buf:issel() or not b then
    return text_match(w, fn, a)
  end
  local s, e = w.buf:range()
  local text = w.buf:gettext(s, e)
  text = fn(text, a, b)
  w.buf:history 'start'
  w.buf:setsel(s, e + 1)
  w.buf:cut()
  w.buf:input(text)
  w.buf:history 'end'
  w:visible()
end

local function grep(path, rex, err)
  for _, fn in ipairs(sys.readdir(path)) do
    local p = (path ..'/'..fn):gsub("/+", "/")
    if sys.isdir(p) then
      grep(p, rex, err)
    else
      local f = io.open(p, "rb")
      if f then
        local nr = 0
        for l in f:lines() do
          nr = nr + 1
          if l:find(rex) then
            err:printf("%s:%d %q\n", p, nr, l)
            coroutine.yield()
          end
        end
        f:close()
      end
    end
  end
end

function proc.grep(w, rex)
  w = w:output()
  w:run(function()
    grep(sys.dirname(w.frame:getfilename()), rex, w)
  end)
end

--luacheck: push
--luacheck: ignore 432
local sub_delims = {
  ["/"] = true,
  [":"] = true,
}

function proc.gsub(w, text)
  return proc.sub(w, text, true)
end

function proc.sub(w, text, glob)
  w = w:winmenu()
  if not w then return end
  text = text:strip()
  local c = text:sub(1,1)
  local a
  if sub_delims[c] then
    a = text:split(c)
    table.remove(a, 1)
  else
    a = { text }
  end
  text_replace(w, function(text, a, b)
    if glob then
      if not b then
        return text:find(a)
      end
      text = text:gsub(a, b)
      return text
    end
    if not b then
      return text:findln(a)
    end
    local t = ''
    for l in text:lines(true) do
      l = l:gsub(a, b)
      t = t .. l
    end
    return t
  end, a[1], a[2])
end

function proc.find(w, pat)
  return proc.sub(w, pat)
end

function proc.select(w, pat)
  return proc.gsub(w, pat)
end
--[[
function proc.fmt(w)
  w = w:winmenu()
  if not w then return end
  local s, e = w.buf:range()
  local b = {}
  local len = 0
  w.buf:history('cut', s, e - s + 1)
  local t = ''
  for i = 1, #w.buf.text do
    table.insert(b, w.buf.text[i])
    if i >= s and i <= e then
      t = t .. w.buf.text[i]
      len = len + 1
      if len >= 60 then
        t = t .. '\n'
        len = 0
      end
    end
  end
  w.buf.cur = s
  w.buf:input(t)
end
]]--
proc['!'] = function(w, pat)
  os.execute(pat)
end

proc['<'] = function(w, pat)
  w = w:output()
  local f = io.popen(pat, "r")
  if not f then return end
  local p = w:run(function()
    for l in f:lines() do
      w:input(l ..'\n')
      coroutine.yield()
    end
    f:close()
  end)
  p.kill = function()
    if f then
      f:close()
      f = nil
    end
  end
end

--luacheck: pop

return proc
