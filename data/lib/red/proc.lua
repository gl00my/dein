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

local function text_match(w, glob, fn, ...)
  local s, e = (glob and 1 or w.buf.cur), #w.buf.text
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

local function text_replace(w, glob, fn, a, b)
  if a and (not w.buf:issel() or not b) then
    return text_match(w, glob, fn, a)
  end
  local s, e = w.buf:range()
  local text = w.buf:gettext(s, e)
  text = fn(text, a, b)
  w.buf:history 'start'
  w.buf:setsel(s, e + 1)
  w.buf:cut()
  w.buf:input(text)
  w.buf:history 'end'
  if not a then
    w.buf:setsel(s, w:cur()+1)
  end
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
          end
          if nr % 1000 == 0 then
            coroutine.yield(1/100)
          end
        end
        f:close()
      end
      coroutine.yield(1/50)
    end
  end
end

function proc.dump(w)
  local data = w:winmenu()
  if not data then return end
  w = w:output('+dump')
  local s, e = data.buf:range()
  local text = data.buf:gettext(s, e)
  for i = 1, #text, 16 do
    local a, t = ''
    t = string.format("%04x | ", (i - 1)/16)
    for k = 0, 15 do
      local b = string.byte(text, i + k)
      if not b then
        for _ = k, 15 do
          t = t .. '   '
        end
        break
      end
      t = t .. string.format("%02x", b) .. ' '
      if b < 32 then
        b = 46
      end
      a = a .. string.char(b)
    end
    w:printf("%s| %s\n",t, a)
  end
end

function proc.grep(w, rex)
  if not rex then return end
  local path = w:data() and w:data():path()
  w = w:output('+grep')
  w:run(function()
    grep(sys.dirname(path or w.frame:getfilename()), rex, w)
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
  text = text:strip():gsub("\\[tnr]", { ["\\t"] = "\t", ["\\n"] = "\n", ["\\r"] = "\r" })
  local c = text:sub(1,1)
  local a
  if sub_delims[c] then
    a = text:split(c)
    table.remove(a, 1)
    if a[2] == '' and not a[3] then a[2] = false end
  else
    a = { text }
  end
  text_replace(w, not not glob, function(text, a, b)
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
local function is_space(c)
  return c == ' ' or c == '\t' or c == '\n'
end
function proc.fmt(w, width)
  width = tonumber(width) or 60
  w = w:winmenu()
  if not w then return end
  local s, e = w.buf:range()
  local b = {}
  local len = 0
  local t = {}
  local c, last
  for i = 1, #w.buf.text do
    c = w.buf.text[i]
    if i >= s and i <= e then
      if c == '\n' and not is_space(w.buf.text[i+1])
        and not is_space(w.buf.text[i-1]) then c = ' ' end
      table.insert(t, c)
      len = len + 1
      if len >= width then
        if not last then
          table.insert(t, '\n')
          len = 0
        else
          len = #t - last
          table.insert(t, last + 1, '\n')
          last = false
        end
      elseif c == '\n' then
        len = 0
        last = false
      elseif c == ' ' or c == '\t' then
        last = #t
      end
    else
      table.insert(b, c)
    end
  end
  w:history 'start'
  w:history('cut', s, e - s + 1)
  w:set(b)
  w:cur(s)
  w:input(t)
  w:history 'end'
end

proc['!'] = function(_, pat)
  if pat:empty() then return end
  local p = thread.start(function()
    local prog = thread:read()
    if PLATFORM ~= 'Windows' then
      prog = prog .. ' &'
    end
    os.execute(prog)
  end)
  p:write(pat:unesc())
  p:detach()
end

local function pipe_shell()
  local poll = require("red/poll").poll
  local poll_mode = not not poll
  poll = poll or function(_) return true end
  local function read_sym(f)
    local t, b = '', ''
    while b and (t == '' or t:byte(#t) >= 128) do
      while b and poll(f) do
        b = f:read(1)
        if not b then break end
        t = t .. b
        if (not poll_mode or t:len() > 256) and
          b:byte(1) < 128 then b = false end
      end
    end
    return t ~= '' and t
  end
  local prog, cwd = thread:read()
  if cwd then
    prog = string.format("cd %q && %s", cwd, prog)
  end
  local f, e = io.popen(prog, "r")
  thread:write(not not f, e)
  if not f then return end
  f:setvbuf 'no'
  local t = true
  while t do
    t = read_sym(f)
    if t then
      thread:write(t)
    end
  end
  f:close()
  thread:write '\1eof'
end

local function pipe_proc()
  require "std"
  local prog = thread:read()
  local f, e = io.popen(prog, "r")
  thread:write(not not f, e)
  if not f then return end
  f:setvbuf 'no'
  local pre
  while true do
    local chunk = f:read(512)
    if not chunk then
      if pre then
        thread:write(pre)
      end
      break
    end
    chunk = (pre or '') .. chunk
    for l in chunk:lines(true) do
      if not l:endswith '\n' then
        pre = l
        break
      end
      thread:write(l)
    end
  end
  f:close()
  thread:write '\1eof'
end

local function pipe(w, prog, inp, sh)
  local tmp
  if prog:empty() then
    return
  end
  if PLATFORM ~= 'Windows' and inp == true then
    tmp = os.tmpname()
    os.remove(tmp)
    if not os.execute("mkfifo "..tmp) then
      return
    end
    prog = string.format("eval %q", prog)
    prog = '( ' ..prog.. ' ) <' .. (inp and tmp or '/dev/null') .. ' 2>&1'
  elseif type(inp) == 'string' then
    tmp = inp
  end
  local p = thread.start(sh and pipe_shell or pipe_proc)
  local ret = { }
  p:write(prog, w.cwd or false)
  local r, e = p:read()
  if not r then
    w:input(e..'\n')
    return
  end
  if tmp then
    ret.fifo = io.open(tmp, "a")
    ret.fifo:setvbuf 'no'
  end
  r = w:run(function()
    w:history 'start'
    local l
    while l ~= '\1eof' and not ret.stopped do
      while p:poll() do
        l = p:read()
        if l == '\1eof' then
          break
        end
        w.buf:input(l)
      end
      coroutine.yield(inp ~= true and 1/50)
    end
    if sh then
      w:input '$ '
    end
    w:history 'end'
    if tmp then
      os.remove(tmp)
    end
    ret.stopped = true
    if ret.fifo then
      ret.fifo:close()
      ret.fifo = nil
    end
    p:wait()
  end)
  ret.routine = r
  r.kill = function()
    if ret.fifo then
      ret.fifo:close()
      ret.fifo = nil
    end
    if not ret.stopped then
      p:err("kill")
      p:detach()
      ret.stopped = true
    end
  end
  return ret
end

proc["i+"] = function(w)
  w = w:winmenu()
  if not w then return end
  local ts = w:getconf 'ts'
  local tab_sp = w:getconf 'spaces_tab'
  local tab = '\t'
  if tab_sp then
    tab = string.rep(" ", ts)
  end
  text_replace(w, false, function(text)
    local t = ''
    for l in text:lines(true) do
      t = t .. tab .. l
    end
    return t
  end)
end

proc["i-"] = function(w)
  w = w:winmenu()
  if not w then return end
  local ts = w:getconf 'ts'
  local tab_sp = w:getconf 'spaces_tab'
  local tab = '\t'
  if tab_sp then
    tab = string.rep(" ", ts)
  end
  text_replace(w, false, function(text)
    local t = ''
    for l in text:lines(true) do
      if l:startswith(tab) then
        l = l:sub(tab:len()+1)
      end
      t = t .. l
    end
    return t
  end)
end

proc['>'] = function(w, prog)
  local data = w:data()
  if not data then return end

  local tmp = os.tmpname()
  local f = io.open(tmp, "wb")
  if not f then
    return
  end
  f:write(data.buf:gettext(data.buf:range()))
  f:close()
  pipe(w:output('+Output'), prog..' '..tmp, tmp)
end

proc['<'] = function(w, prog)
  pipe(w:output(), prog)
end

function proc.Codepoint(w)
  local data = w:winmenu()
  if not data then return end
  local sym = data.buf.text[data:cur()]
  local cp = utf.codepoint(sym)
  local cur = w:cur()
  w.buf:input(" "..string.format("0x%x", cp))
  w:cur(cur)
end

function proc.Line(w)
  if not w.frame.frame then -- main menu
    return
  end
  local cur = w:cur()
  w.buf:input(" :"..tostring(w.frame:win().buf:line_nr()))
  w:cur(cur)
end

function proc.Clear(w)
  w = w:winmenu()
  if not w then return end
  w.buf:setsel(1, #w.buf.text + 1)
  w.buf:cut()
  w.buf.cur = 1
  w:visible()
end

local shell = {}

function shell:delete()
  if not self.prog or
    not self.prog.routine or
    self.prog.stopped then
    return
  end
  self.prog.routine.kill()
  self.prog.stopped = true
end

function shell:escape()
  if not self.prog or self.prog.stopped or
    not self.prog.fifo then
    return
  end
  self.prog.fifo:close()
  self.prog.fifo = nil
end

function shell:newline()
  self.buf:linestart()
  local t = ''
  for i = self.buf.cur, #self.buf.text do
    t = t .. self.buf.text[i]
  end
  t = t:gsub("^[^%$]*%$", ""):strip()
  self.buf:lineend()
  self.buf:input '\n'
  local cmd = t:split(1)
  if self.prog and not self.prog.stopped then
    if self.prog.fifo then
      self.prog.fifo:write(t..'\n')
      self.prog.fifo:flush()
    end
  elseif cmd[1] == 'cd' and #cmd == 2 then
    cmd[2] = cmd[2]:unesc()
    local cwd = (self.cwd or '.').. '/' .. cmd[2]
    if sys.is_absolute_path(cmd[2]) then
      cwd = cmd[2]
    end
    if not sys.isdir(cwd) then
      self.buf:input("Error\n")
    else
      self.cwd = sys.realpath(cwd) .. '/'
      self.buf:input(self.cwd..'\n')
    end
    self.buf:input '$ '
  elseif t:empty() then
    self.buf:input '$ '
  else
    self.prog = pipe(self, t, true, true)
  end
end

function proc.win(w)
  w = w:output("+win")
  if not w.win_shell then
    w.win_shell = true
    w:input("$ ")
  end
  w.newline = shell.newline
  w.escape = shell.escape
  w.delete = shell.delete
end

--luacheck: pop

if PLATFORM ~= 'Windows' then
proc['|'] = function(w, prog)
  local data = w:data()
  if not data then return end
  local ret = pipe(w:data(), prog, true)
  if not ret or not ret.fifo then
    return
  end
  local s, e = data.buf:range()
  data.buf:setsel(s, e + 1)
  local txt = data.buf:gettext(s, e)
  w:data():run(function()
--    data.buf:cut()
    while txt ~= '' do
      ret.fifo:write(txt:sub(1, 256))
      txt = txt:sub(257)
      coroutine.yield(1/50)
    end
    ret.fifo:close()
    ret.fifo = nil
  end)
end
end

return proc
