require "std"

local tcol = { 0, 64, 48, 255 }

w, h = screen:size()
sys.hidemouse()
local floor = math.floor
local ceil = math.ceil
local spr = {}
local pan_mode
local map_mode=false

local SPRITE = ARGS[2] or 'sprite.spr'
local COLORS = 16
for c = 16, 32 do
  local r, g, b, a = gfx.pal(c)
  if r == 0 and g == 0 and b == 0 and a == 0 then
    if c % 2 == 1 then COLORS = COLORS + 1 end
    break
  end
  COLORS = 16 + c - 16 + 1
end
print("Detected "..COLORS.." color(s)")

local HCOLORS = COLORS/2

sys.title ("sprited: " .. SPRITE)

pal = {
  x = 0;
  y = 0;
  cw = 8;
  ch = 8;
  w = 8*2;
  h = (HCOLORS + 5)*8;
  base = 0; -- tiles base
  color = 0;
  lev = -1;
}

function pal:mode()
  local s = self
  s.color, s.map_color = s.map_color or 0, s.color
  if map_mode then
    s.h = (16 + 5)*8
  else
    s.h = (HCOLORS+5)*8
  end
end

function pal:select(x, y, c)
  x = self.x + x * 8
  y = self.y + y * 8
  screen:fill(x, y, 8, 8, c)
--  screen:poly({x, y,
--    x + 8 - 1,y,
--    x + 8 -1, y + 8 -1,
--    x, y + 8-1}, c)
end

local grid_mode = true
local sel_mode = false
local hand_mode = false
local hl_mode = false
local draw_mode = false

function pal:show()
  local s = self
  local w = s.cw
  local h = s.ch
  local x, y = self.x, self.y
  screen:clear(x-1, y-1, s.w+2, s.h+2, 5)
  local py = HCOLORS
  if map_mode then
    local fx, fy
    for y=0, 15 do
      screen:clear(x, y*h, w*2, h, {0, 0, 0, 255})
      grid:drawspr((s.base + y*2), x, y*h)
      grid:drawspr((s.base + y*2 + 1), x+w, y*h)
    end
    if s.color >= s.base and s.color < s.base + 32 then
      fx, fy = (s.color - s.base) % 2, math.floor((s.color - s.base) /2)
      screen:rect(x + fx*8, y + fy*8,
        x + fx*8 + w - 1, y + fy*8 + h - 1, 7)
    end
    py = 16
  else
    for y=0, HCOLORS-1 do
      screen:clear(x, y*h, w, h, y*2)
      screen:clear(x+w, y*h, w, h, y*2+1)
    end
    local c = s.color + (HCOLORS-1)
    if c >= COLORS then c = c - COLORS end
    y = s.y + math.floor(s.color/2)*h
    x = s.x + (s.color % 2)*w
    screen:rect(x, y, x+w-1, y+h-1, c)
  end
  if hand_mode then
    self:select(0, py, 7)
  end
  if grid_mode then
    self:select(1, py, 10)
  end
  if sel_mode then
    self:select(0, py+1, 7)
  end
  if hl_mode then
    self:select(1, py+1, 10)
  end
  if draw_mode == 'line' then
    self:select(0, py+2, 8)
  elseif draw_mode == 'box' then
    self:select(1, py+2, 8)
  elseif draw_mode == 'circle' then
    self:select(0, py+3, 8)
  elseif draw_mode == 'fill' then
    self:select(1, py+3, 8)
  end
  spr.Hand:blend(screen, s.x, py*8)
  spr.G:blend(screen, s.x + 8, py*8)
  spr.S:blend(screen, s.x, (py+1)*8)
  spr.HL:blend(screen, s.x + 8, (py+1)*8)
  spr.L:blend(screen, s.x, (py+2)*8)
  spr.B:blend(screen, s.x + 8, (py+2)*8)
  spr.C:blend(screen, s.x, (py+3)*8)
  spr.F:blend(screen, s.x + 8, (py+3)*8)
  if map_mode then
    self:select(0, py+4, 8)
  end
  spr.M:blend(screen, s.x, (py+4)*8)
  spr.H:blend(screen, s.x + 8, (py+4)*8)
end

function pal:pos2col(x, y)
  local s = self
  local w = s.cw
  local h = s.ch
  x = x - s.x
  y = y - s.y
  x = floor(x/w)
  y = floor(y/h)
  return x, y
end

function pal:mousewheel(e, x, y)
  if not map_mode then
    return
  end
  self.base = self.base - 2*e
  if self.base < 0 then self.base = 0 end
--  if (self.base+32) > 255 then self.base = 256-32 end
  return true
end

function pal:showcolor()
  if not map_mode then
    return
  end
  local n = self.color or 0
  if n >= self.base and n <= self.base + 31 then
    return
  end
  if n == -1 then n = 0 end
  self.base = math.floor(n / 2)*2
  return
end

function pal:click(x, y, mb, click, e)
  local x, y = self:pos2col(x, y)
  local c
  local py = HCOLORS
  if map_mode then
    py = 16
  end
  if y < py then
    if map_mode then
      c = self.base + x + y*2
    else
      c = x + y*2
    end
    self.color = c
  elseif y == py and x == 0 and click then -- hand mode
    hand_mode = not hand_mode
  elseif y == py and x == 1 and click then -- grid mode
    grid_mode = not grid_mode
  elseif y == py+1 and x == 0 and click then
    sel_mode = not sel_mode
    if not sel_mode then
      grid.sel_x1 = false
    end
    draw_mode = false
    hand_mode = false
  elseif y == py+1 and x == 1 and click then
    hl_mode = not hl_mode
  elseif y == py+2 and x == 0 and click then
    draw_mode = draw_mode ~= 'line' and 'line' or false
    sel_mode, grid.sel_x1 = false, false
  elseif y == py+2 and x == 1 and click then
    draw_mode = draw_mode ~= 'box' and 'box' or false
    sel_mode, grid.sel_x1 = false, false
  elseif y == py+3 and x == 0 and click then
    draw_mode = draw_mode ~= 'circle' and 'circle' or false
    sel_mode, grid.sel_x1 = false, false
  elseif y == py+3 and x == 1 and click then
    draw_mode = draw_mode ~= 'fill' and 'fill' or false
    sel_mode, grid.sel_x1 = false, false
  elseif y == py + 4 and x == 0 and e == 'mouseup' then
    switch_mode()
  elseif y == py + 4 and x == 1 and e == 'mouseup' then
    help_mode = not help_mode
  end
  return true
end

grid = {
  cache = {};
  x = 0;
  y = 0;
  w = 256;
  h = 256;
  xoff = 0;
  yoff = 0;
  grid = 16;
  max_grid = 256;
  min_grid = 8;
  lev = 1;
  pixels = {};
  history = {};
}

title = {
  x = 0;
  y = 256 - 8;
  lev = -1;
}

function fname(f)
  return map_mode and f:gsub("spr$", "map") or f
end

function title:show()
  local dirty = ' '
  if grid.dirty then
    dirty = '*'
  end
  local mx, my = input.mouse()
  local x, y = grid:pos2cell(mx, my)
  if grid:getsel() then
    local x1, y1, x2, y2 = grid:getsel()
    x, y = x2 - x1 + 1, y2 - y1 + 1
  end

  local info

  if map_mode and mx >= pal.x and my >= pal.y and
    mx < pal.x + pal.w and my < pal.y + 16*8 then
    mx, my = pal:pos2col(mx, my)
    info = string.format("x%-3d spr:%-3d %s%s",
    grid.grid, pal.base + my*2 + mx, fname(SPRITE), dirty)
  else
    info = string.format("x%-3d %3d:%-3d %s%s",
      grid.grid, x-1, y-1, fname(SPRITE), dirty)
  end

  local w, h = font:size(info)
  self.w = w
  self.h = h
  screen:fill(0, grid.h - 8, grid.w, grid.h - 8, { 0, 0, 0, 96 })
  gfx.print(info, self.x+1, self.y+1, 0)
  gfx.print(info, self.x, self.y, 15)
end

function title:click(x, y, mb, click)
  if not click then
    return true
  end
  local s = self
  x = x - s.x
  local w = font:size(string.format("x%-3d", grid.grid))
  local namew = font:size(string.format("%s ", fname(SPRITE)))
  if x >= s.w - namew then
    if mb.left then
      if map_mode then
        grid:savemap(fname(SPRITE))
      else
        grid:save(fname(SPRITE))
      end
    elseif mb.right then
      if map_mode then
        grid:savemap(fname(SPRITE))
      else
        grid:save(fname(SPRITE), true)
      end
    elseif mb.middle then
      grid.pixels = {}
      grid.history = {}
      grid.dirty = false
    end
  elseif x < w then
    if not grid:zoom(-1) then
      grid:zoom(0)
    end
  end
  return true
end

local obj = { pal, grid, title }

function switch_mode()
  map_mode = not map_mode
  for _, v in ipairs(obj) do
    if v.mode then
      v:mode()
    end
  end
  sys.input(true)
end

function grid:spr2pos(nr)
  local y = math.floor(nr / 16)*8
  local x = (nr % 16)*8
  return x, y
end

function grid:drawspr(nr, x, y, scale)
      local fx, fy = self:spr2pos(nr)
      grid:draw(fx, fy, 8, 8, x, y, scale)
end

function grid:draw(fx, fy, w, h, x, y, scale)
  local s = self
  local pixels = map_mode and s.backpixels or s.pixels
  local spr = s.cache[string.format("%d-%d-%d-%d", fx, fy, w, h)]
  if not spr then
    spr = gfx.new(w, h)
    for yy=1, h do
      local r = pixels[fy+yy] or {}
      for xx=1, w do
        local c = r[fx+xx] or -1
        if c ~= -1 then
          spr:val(xx-1, yy-1, c)
        else
          local v = pixels[yy] and pixels[yy][xx] or -1
          spr:val(xx-1, yy-1, v == -1 and tcol or v) -- 0 sprite
        end
      end
    end
    s.cache[string.format("%d-%d-%d-%d", fx, fy, w, h)] = spr
  end
  spr:stretch(screen, x, y, w*(scale or 1), h*(scale or 1))
end

function grid:pan(dx, dy)
  self.xoff = self.xoff + dx
  self.yoff = self.yoff + dy
  if self.xoff < 0 then self.xoff = 0 end
  if self.yoff < 0 then self.yoff = 0 end
  if self.xoff + self.grid > self.w then self.xoff = self.w - self.grid end
  if self.yoff + self.grid > self.h then self.yoff = self.h - self.grid end
end

function grid:pos(x, y)
  if not x then
    return self.xoff, self.yoff
  end
  self.xoff = x
  self.yoff = y
  self:pan(0, 0)
end

function grid:zoom(inc)
  local s = self
  if inc > 0 then
    if s.grid > s.min_grid then
      s.grid = s.grid / 2
      if s.xoff ~= 0 and s.yoff ~= 0 then
        s:pan(s.grid/2, s.grid/2)
      end
      return true
    end
  elseif inc < 0 then
    if s.grid < s.max_grid then
      s:pan(-s.grid/2, -s.grid/2)
      s.grid = s.grid * 2
      return true
    end
  else
    s.grid = s.min_grid
    return true
  end
end

function grid:save(fname, sel)
  local s = self
  local colmap = {
    [-1] = '-',
    [0] = '0', [1] = '1', [2] = '2', [3] = '3',
    [4] = '4', [5] = '5', [6] = '6', [7] = '7',
    [8] = '8', [9] = '9', [10] = 'a', [11] = 'b',
    [12] = 'c', [13] = 'd', [14] = 'e', [15] = 'f',
  }
  for i = 0x67, 0x67+COLORS-16 do
    colmap[i-0x67+16] = string.char(i)
  end
  local y1,x1,y2,x2
  local cols = {}
  for y=1,s.max_grid do
    for x=1,s.max_grid do
      local c = s.pixels[y] and s.pixels[y][x] or -1
      if not cols[c] then
        cols[c] = c
      end
      if c ~= -1 then
        x1 = (not x1 or x1 > x) and x or x1
        x2 = (not x2 or x2 < x) and x or x2
        y1 = (not y1 or y1 > y) and y or y1
        y2 = (not y2 or y2 < y) and y or y2
      end
    end
  end
  if not x1 then
    return
  end
  x1, y1 = 1, 1 -- no spaces!
  if s.sel_x1 and sel then
    x1, y1, x2, y2 = s:getsel()
  end
  if sel then
    fname = string.format("%s-%d-%d-%d-%d.spr", fname:gsub("%.spr$", ""), x1, y1, x2, y2)
    print(fname)
  end
  local f, e = io.open(fname, "wb")
  if not f then
    return f, e
  end
  local p = ''
  for c=0,COLORS-1 do
    if cols[c] then
      p = p .. colmap[c]
    else
      p = p .. '-'
    end
  end
  f:write(string.format("%s\n", p))
  print(p)
  for y=y1,y2 do
    local l = s.pixels[y] or {}
    local r = ''
    for x=x1,x2 do
      local c = l[x] or -1
      r = r .. colmap[c]
    end
    f:write(string.format("%s\n", r))
    print(r)
  end
  f:close()
  s.dirty = false
end

function grid:pos2cell(x, y)
  local s = self
  x = x - s.x
  y = y - s.y
  local dx = floor(self.w / s.grid)
  x = floor(x/dx) + 1 + s.xoff
  y = floor(y/dx) + 1 + s.yoff
  return x, y
end

function grid:undo(x, y, mb)
  local s = self
  local n = #s.history
  if n < 1 then
    return
  end
  if n == 1 then
    s.dirty = false
  end
  local z = table.remove(s.history, n)
  if z.pixels then
    local i = 1
    for y = z.y1, z.y2 do
      s.pixels[y] = s.pixels[y] or {}
      for x = z.x1, z.x2 do
        s.pixels[y][x] = z.pixels[i]
        i = i + 1
      end
    end
    return
  end
  if z.val then
    s.pixels[z.y][z.x] = z.val
    return
  end
  for _, v in ipairs(z) do
    s.pixels[v.y][v.x] = v.val
  end
end

function grid:histadd(x1, y1, x2, y2)
  local s = self
  local b = {}
  if #s.history > 1024 then
    table.remove(s.history, 1)
  end
  if type(x1) == 'table' then
    table.insert(s.history, x1)
    return
  end
  if not x2 then
    table.insert(s.history, { x = x1, y = y1, val = s.pixels[y1][x1] or -1 })
    return
  end
  for y = y1, y2 do
    s.pixels[y] = s.pixels[y] or {}
    for x = x1, x2 do
      table.insert(b, s.pixels[y][x] or -1)
    end
  end
  table.insert(s.history, { x1 = x1, y1 = y1,
    x2 = x2, y2 = y2, pixels = b })
end

function grid:fliph()
  local s = self
  local x1, y1, x2, y2 = s:getsel()
  if not x1 then
    return
  end

  local empty = s:isempty(x1, y1, x2, y2)
  if not empty then
    s:histadd(x1, y1, x2, y2)
  end

  local xc = x1 + floor((x2 - x1)/2)
  for y=y1,y2 do
    s.pixels[y] = s.pixels[y] or {}
    for x=x1,xc do
      local tmp = s.pixels[y][x]
      s.pixels[y][x] = s.pixels[y][x2-(x-x1)]
      s.pixels[y][x2-(x-x1)] = tmp
      s.dirty = true
    end
  end
end

function grid:flipv()
  local s = self
  local x1, y1, x2, y2 = s:getsel()
  if not x1 then
    return
  end

  local empty = s:isempty(x1, y1, x2, y2)
  if not empty then
    s:histadd(x1, y1, x2, y2)
  end

  local yc = y1 + floor((y2 - y1)/2)
  for x=x1,x2 do
    for y=y1,yc do
      s.pixels[y] = s.pixels[y] or {}
      local tmp = s.pixels[y][x]
      s.pixels[y][x] = s.pixels[y2-(y-y1)][x]
      s.pixels[y2-(y-y1)][x] = tmp
      s.dirty = true
    end
  end
end

function grid:paste()
  local s = self
  if not s.clipboard then
    return
  end
  local x, y = input.mouse()
  local tox, toy = s:pos2cell(x, y)
  s:histadd(tox, toy,
    tox + s.clipboard.w - 1,
    toy + s.clipboard.h - 1)
  for y=1, s.clipboard.h do
    s.pixels[toy+y-1] = s.pixels[toy+y-1] or {}
    for x=1,s.clipboard.w do
      s.pixels[toy+y-1][x+tox-1] = s.clipboard[y][x]
    end
  end
  s.sel_x1, s.sel_y1, s.sel_x2, s.sel_y2 = tox, toy,
    tox + s.clipboard.w - 1, toy + s.clipboard.h - 1
end

function grid:isempty(x1, y1, x2, y2)
  local s = self
  local col
  for y = y1, y2 do
    for x = x1, x2 do
      col = s.pixels[y] and s.pixels[y][x]
      if col and col ~= -1 then
        col = true
        break
      end
    end
  end
  return not (col == true)
end

function grid:cut(copy)
  local s = self
  local x1, y1, x2, y2 = s:getsel()
  if not x1 then
    return
  end
  s.clipboard = {}

  local empty = s:isempty(x1, y1, x2, y2)

  if not empty and not copy then
    s:histadd(x1, y1, x2, y2)
  end

  for y = y1, y2 do
    s.clipboard[y - y1 + 1] = {}
    s.pixels[y] = s.pixels[y] or {}
    for x = x1, x2 do
      s.clipboard[y - y1 + 1][x - x1 + 1] = s.pixels[y][x]
      if not copy then
        s.pixels[y][x] = -1
        s.dirty = true
      end
    end
  end
  s.clipboard.w = x2 - x1 + 1
  s.clipboard.h = y2 - y1 + 1
  return true
end

function grid:savemap(fname)
  local s = self
  local f = io.open(fname, "wb")
  if not f then return false end
  print(fname)
  local w, h = 0, 0
  for y=1,s.max_grid do
    if s.map[y] then h = y end
    if s.map[y] then
      for x=1,s.max_grid do
        if s.map[y][x] and x > w then w = x end
      end
    end
  end
  for y=1, h do
    s.map[y] = s.map[y] or {}
    local r=''
    for x=1, w do
      r = r ..string.format("%02x", s.map[y][x] or 0 )
    end
    print(r)
    f:write(r..'\n')
  end
  f:close()
  s.dirty = false
  return true
end

function grid:loadmap(fname)
  local f = io.open(fname, "rb")
  if not f then return false end
  local map = {}
  local y = 0
  for l in f:lines() do
    y = y + 1
    map[y] = {}
    for x = 1, l:len(), 2 do
      map[y][(x-1)/2+1] = tonumber(l:sub(x, x+1), 16)
    end
  end
  f:close()
  return map
end

function grid:mode()
  local s = self
  s.history = {}
  s.cache = {}
  s.clipboard = {}
  s.dirty, s.backdirty = s.backdirty, s.dirty
  s.xoff, s.xoffback = s.xoffback or 0, s.xoff
  s.yoff, s.yoffback = s.yoffback or 0, s.yoff
  s.grid, s.gridback = s.gridback or 16, s.grid
  if map_mode then
    s.backpixels = s.pixels
    if not s.map then -- try load
      s.map = s:loadmap(fname(SPRITE)) or {}
    end
    s.pixels = s.map
    s.bookmarks, s.backbookmarks = s.backbookmarks or {}, s.bookmarks or {}
  else
    s.map, s.pixels = s.pixels, s.backpixels
    s.bookmarks, s.backbookmarks = s.backbookmarks or {}, s.bookmarks or {}
  end
end

function grid:mousewheel(e)
  self:zoom(-e)
  return true
end

function grid:click(x, y, mb, click, e)
  local s = self
  if pan_mode or e == 'mouseup' then
    return
  end
  x, y = s:pos2cell(x, y)
  if not x then
    return
  end
  if draw_mode or sel_mode then
    if click then
      if draw_mode == 'fill' then
        if mb.right then
          s:fill(x, y, -1, s:get(x, y))
        else
          s:fill(x, y, pal.color, s:get(x, y))
        end
        return true
      end
      if mb.right then
        self.sel_x1, self.sel_y1 = false, false
        return true
      end
      self.sel_x1, self.sel_y1 = x, y
      self.sel_x2, self.sel_y2 = x, y
      return true
    end
    self.sel_x2, self.sel_y2 = x, y
    return true
  end
  if mb.middle then
    pal.color = s:get(x, y)
    pal:showcolor()
    if pal.color == -1 then
      pal.color = 0
    end
    return true
  end
  s.pixels[y] = s.pixels[y] or {}
  local oval = s.pixels[y][x]
  local nval = not mb.right and pal.color or nil
  if oval ~= nval then
    s:histadd(x, y)
    s.dirty = true
  end
  s.pixels[y][x] = nval
  return true
end

function grid:get(x, y)
  local s = self
  if x <= 0 or y <= 0 or x > s.w or y > s.h then
    return false
  end
  return s.pixels[y] and s.pixels[y][x] or -1
end

function grid:set(x, y, c)
  if x < 1 or x > self.w or y < 1 or y > self.h then
    return
  end
  self.pixels[y] = self.pixels[y] or {}
  self.pixels[y][x] = c
end

function grid:getsel(nosort)
  local s = self
  if not s.sel_x1 then
    return
  end
  if nosort then
    return s.sel_x1, s.sel_y1, s.sel_x2, s.sel_y2
  end
  local xmin = math.min(s.sel_x1, s.sel_x2)
  local ymin = math.min(s.sel_y1, s.sel_y2)
  local xmax = math.max(s.sel_x1, s.sel_x2)
  local ymax = math.max(s.sel_y1, s.sel_y2)
  return xmin, ymin, xmax, ymax
end

function grid:show_line(x1, y1, x2, y2, c, draw)
  local s = self
  local dx = x2 - x1
  local dy = y2 - y1
  local steps = math.max(math.max(math.abs(dx), math.abs(dy)), 1)
  local x_step = dx / steps
  local y_step = dy / steps
  local dd = floor(s.w / s.grid)
  if draw then
    local xmin = math.min(x1, x2)
    local ymin = math.min(y1, y2)
    local xmax = math.max(x1, x2)
    local ymax = math.max(y1, y2)
    s:histadd(xmin, ymin, xmax, ymax)
  end
  for i = 0, steps do
    local x, y = math.round(x1) - s.xoff - 1, math.round(y1) - s.yoff - 1
    screen:clear(x*dd, y*dd, dd, dd, c)
    if draw then
      x, y = math.round(x1), math.round(y1)
      s.pixels[y] = s.pixels[y] or {}
      s.pixels[y][x] = c
      s.dirty = true
    end
    x1 = x1 + x_step
    y1 = y1 + y_step
  end
end

function grid:show_box(x1, y1, x2, y2, c, draw)
  local s = self
  local dd = floor(s.w / s.grid)
  if draw then
    s:histadd(x1, y1, x2, y2)
  end
  for x=x1,x2 do
    local xx, yy = x - s.xoff - 1, y1 - s.yoff - 1
    screen:clear(xx*dd, yy*dd, dd, dd, c)
    yy = y2 - s.yoff - 1
    screen:clear(xx*dd, yy*dd, dd, dd, c)
    if draw then
      s.pixels[y1] = s.pixels[y1] or {}
      s.pixels[y1][x] = c
      s.pixels[y2] = s.pixels[y2] or {}
      s.pixels[y2][x] = c
      s.dirty = true
    end
  end
  for y=y1,y2 do
    local xx, yy = x1 - s.xoff - 1, y - s.yoff - 1
    screen:clear(xx*dd, yy*dd, dd, dd, c)
    xx = x2 - s.xoff - 1
    screen:clear(xx*dd, yy*dd, dd, dd, c)
    if draw then
      s.pixels[y] = s.pixels[y] or {}
      s.pixels[y][x1] = c
      s.pixels[y][x2] = c
    end
  end
end


function grid:fill(x, y, c, t)
  t = t or -1
  local q = {}
  local s = self
  local function inside(x, y)
    if x < 1 or y < 1 or
      x > s.w or x > s.h then
      return false
    end
    return s:get(x, y) == t
  end
  local function enq(x1, x2, y, dy)
    table.insert(q, { x1, x2, y, dy })
  end
  if not inside(x, y) or t == c then
    return
  end
  local v = s:get(x,y)
  enq(x, x, y, 1)
  enq(x, x, y - 1, -1)
  local hist = {}
  while #q > 0 do
    v = table.remove(q, 1)
    local x1, x2, y, dy = v[1], v[2], v[3], v[4]
    x = x1
    if inside(x, y) then
      while inside(x - 1, y) do
        table.insert(hist, { x = x - 1, y = y, val = t})
        s:set(x - 1, y, c)
        x = x - 1
      end
    end
    if x < x1 then
      enq(x, x1 - 1, y - dy, -dy)
    end
    while x1 <= x2 do
      while inside(x1, y) do
        table.insert(hist, { x = x1, y = y, val = t})
        s:set(x1, y, c)
        x1 = x1 + 1
        enq(x, x1 - 1, y + dy, dy)
        if x1 - 1 > x2 then
          enq(x2 + 1, x1 - 1, y - dy, -dy)
        end
      end
      x1 = x1 + 1
      while x1 < x2 and not inside(x1, y) do
        x1 = x1 + 1
      end
      x = x1
    end
  end
  if #hist > 0 then
    s.dirty = true
  end
  s:histadd(hist)
end

local function ellipse(x0, y0, x1, y1, pixel)
  local a, b = x1-x0, y1-y0
  local b1 = b % 2
  local dx, dy = 4*(1-a)*b*b, 4*(b1+1)*a*a
  local err = dx+dy+b1*a*a

  y0 = y0 + floor(0.5*(b + 1))
  y1 = y0 - b1
  a = 8*a*a
  b1 = 8*b*b

  repeat
    pixel(x1, y0)
    pixel(x0, y0)
    pixel(x0, y1)
    pixel(x1, y1)

    local e2 = err + err
    if e2 <= dy then
      y0 = y0 + 1
      y1 = y1 - 1
      dy = dy + a
      err = err + dy
    end
    if e2 >= dx or (err + err) > dy then
      x0 = x0 + 1
      x1 = x1 - 1
      dx = dx + b1
      err = err + dx
    end
  until x0 > x1

  while y0 - y1 < b do
    pixel(x0 - 1, y0)
    pixel(x1 + 1, y0)
    pixel(x0-1, y1)
    pixel(x1+1, y1)

    y0 = y0 + 1
    y1 = y1 - 1
  end
end

function grid:show_circle(x1, y1, x2, y2, c, draw)
  local s = self
  local dd = floor(s.w / s.grid)
  if draw then
    s:histadd(x1, y1, x2, y2)
  end
  local dd = floor(s.w / s.grid)
  ellipse(x1, y1, x2, y2, function(x, y)
    local xx, yy = x - s.xoff - 1, y - s.yoff - 1
    screen:clear(xx*dd, yy*dd, dd, dd, c)
    if draw then
      s.pixels[y] = s.pixels[y] or {}
      s.pixels[y][x] = c
      s.dirty = true
    end
  end)
end

function grid:show()
  local s = self
  local mx, my = input.mouse()
  mx, my = s:pos2cell(mx, my)
  local dx = floor(self.w / s.grid)
  screen:clear(s.x, s.y, s.w, s.h, 1)
  local Xd = spr.X:size()
  Xd = math.round((dx-Xd)/2)
  for y=1,s.grid do
    for x=1,s.grid do
      local c = s.pixels[y+s.yoff] and s.pixels[y+s.yoff][x+s.xoff]
      if not c or c == -1 then
        screen:clear(s.x+(x-1)*dx, s.y+(y-1)*dx, dx, dx, tcol)
        if s.grid < 128 then
          spr.X:blend(screen, s.x+(x-1)*dx + Xd, s.y+(y-1)*dx + Xd)
        end
      else
        if map_mode then
          s:drawspr(c, s.x+(x-1)*dx, s.y+(y-1)*dx, dx/8)
        else
          screen:clear(s.x+(x-1)*dx, s.y+(y-1)*dx, dx, dx, c)
        end
      end
      if hl_mode and  mx == s.xoff + x and my == s.yoff + y then
        c = (c or -1)+ HCOLORS
        if c >= COLORS then c = COLORS - c end
        c = { gfx.pal(c) }
        c[4] = 164
        screen:fill(s.x+(x-1)*dx, s.y+(y-1)*dx, dx, dx, c)
      end
    end
  end
  if s.grid < 128 and grid_mode then
    screen:rect(s.x, s.y, s.x + s.w, s.y + s.h, 0)
    for x=1,s.grid do

      local colx = (((s.xoff + x - 1)%8 == 0) and 2) or 0
      local coly = (((s.yoff + x - 1)%8 == 0) and 2) or 0

      screen:line(s.x+(x-1)*dx, s.y, (x-1)*dx, s.y + s.h,
        colx)
      screen:line(s.x, s.y+(x-1)*dx, s.x+s.w, s.y+(x-1)*dx,
        coly)
    end
  end
  if grid.sel_x1 then
    local xmin, ymin, xmax, ymax = s:getsel()
    if xmax < s.xoff or ymax < s.yoff or xmin > s.xoff + s.grid or
      ymin > s.yoff + s.grid then
        return
    end
    local dx = floor(s.w / s.grid)
    if draw_mode == 'line' then
      xmin, ymin, xmax, ymax = s:getsel(true)
      s:show_line(xmin, ymin, xmax, ymax, pal.color)
    elseif draw_mode == 'box'  then
      s:show_box(xmin, ymin, xmax, ymax, pal.color)
    elseif draw_mode == 'circle' then
      s:show_circle(xmin, ymin, xmax, ymax, pal.color)
    end
    xmin, ymin, xmax, ymax = s:getsel()
    xmin = xmin - 1; ymin = ymin - 1
    screen:rect((xmin - s.xoff)*dx, (ymin - s.yoff)*dx,
      (xmax - s.xoff)*dx, (ymax - s.yoff)*dx, 7)
    screen:rect((xmin - s.xoff)*dx+1, (ymin - s.yoff)*dx+1,
      (xmax - s.xoff)*dx-1, (ymax - s.yoff)*dx-1, 8)
  end
end

local d, e = gfx.new(SPRITE, true) -- true - load data

if d then
  grid.pixels = d
end

function switch_ui()
  if pal.x == 0 then
    pal.x = w - pal.w
    title.x = w - title.w - 1
  else
    pal.x = 0
    title.x = 0
  end
end

grid.bookmarks = {}
function proc_inp(r, e, a, b, c, d)
  if r == 'text' then
    if e == '+' then
      grid:zoom(1)
    elseif e == '-' then
      grid:zoom(-1)
    end
  elseif r == 'keyup' then
    if e == 'space' then
      pan_mode = nil
    end
  elseif r == 'keydown' then
    if e == 'f1' then
      help_mode = not help_mode
    elseif e == 'tab' then
      switch_ui()
    elseif e == 'm' then
      switch_mode()
    elseif e == 'f2' then
      grid:save(fname(SPRITE))
    elseif e == 'z' then
      grid:undo()
    elseif e == 'c' and input.keydown'ctrl' then
      grid:cut(true)
    elseif e == 'x' and input.keydown'ctrl' then
      grid:cut()
    elseif e == 'v' and input.keydown'ctrl' then
      grid:paste()
    elseif e == 's' and input.keydown'ctrl' then
      grid:save(fname(SPRITE))
    elseif e == 'h' then
      grid:fliph()
    elseif e == 'v' then
      grid:flipv()
    elseif string.byte(e) >= string.byte('0')
      and string.byte(e) <= string.byte('9') then
      if input.keydown'ctrl' then
        print("Bookmark added: ", e)
        grid.bookmarks[e] = { x = grid.xoff, y = grid.yoff }
      elseif grid.bookmarks[e] then
        grid.xoff, grid.yoff = grid.bookmarks[e].x, grid.bookmarks[e].y
      end
    end
  elseif r == 'mouseup' then
    if draw_mode == 'line' then
      local x1, y1, x2, y2 = grid:getsel(true)
      if x1 then
        grid:show_line(x1, y1, x2, y2, pal.color, true)
        grid.sel_x1 = false
      end
    elseif draw_mode == 'box'  then
      local x1, y1, x2, y2 = grid:getsel()
      if x1 then
        grid:show_box(x1, y1, x2, y2, pal.color, true)
        grid.sel_x1 = false
      end
    elseif draw_mode == 'circle'  then
      local x1, y1, x2, y2 = grid:getsel()
      if x1 then
        grid:show_circle(x1, y1, x2, y2, pal.color, true)
        grid.sel_x1 = false
      end
    end
  end
  if not pan_mode and (r == 'keydown' and  e == 'space' or
    r == 'mousedown' and hand_mode) then
    local ox, oy = input.mouse()
    local x, y = grid:pos()
    pan_mode =  { ox, oy, x, y }
  elseif pan_mode then
    local x, y, mb = input.mouse()
    local dd = grid.w / grid.grid
    local dx = floor((x - pan_mode[1])/dd)
    local dy = floor((y - pan_mode[2])/dd)
    grid:pos(pan_mode[3] - dx, pan_mode[4] - dy)
    if (not hand_mode and not input.keydown 'space') or (hand_mode and not mb.left) then
      pan_mode = nil
    end
  elseif r == 'keydown' and e == 'right' then
    grid:pan(input.keydown"shift" and grid.grid or 1, 0)
  elseif r == 'keydown' and e == 'left' then
    grid:pan(input.keydown"shift" and -grid.grid or -1, 0)
  elseif  r == 'keydown' and e == 'up' then
    grid:pan(0, input.keydown"shift" and -grid.grid or -1)
  elseif  r == 'keydown' and e == 'down' then
    grid:pan(0, input.keydown"shift" and grid.grid or 1)
  end
  return r ~= nil
end

title:show()
switch_ui()
HELP = [[Keys:
z      - undo
ctrl-c - copy selection
ctrl-x - cut selection
ctrl-v - paste
h/v    - flip selection
cursor - pan (+shift by grid)
space  - pan (hold+mouse)
+/-    - zoom
^0..9  - make bookmark
0...9  - jump to bookmark
tab    - change layout
m      - map mode
lmb    - put pixel
rmb    - erase pixel
mmb    - get color
wheel  - zoom
lmb on [scale]    - zoom out
lmb on [filename] - save
rmb on [filename] - save selection
mmb on [filename] - erase
Legend:
^   - control
lmb - left mouse button
rmb - right mouse button
mmb - middle mouse button
[filename] - on the status line
[scale]    - on the status line
]]
function run()
  local curw, curh = spr.Cur:size()
  while sys.running() do
    local r, v, a, b = sys.input()
    local mx, my, mb = input.mouse()
    if v == 'middle' then
      mb[v] = r == 'mousedown'
    end
    if help_mode then
      screen:clear {0xff, 0xff, 0xe8, 0xff}
      if r == 'keydown' or r == 'mousedown' then
        help_mode = 1
      end
      if (r == 'keyup' or r == 'mouseup') and help_mode == 1 then
        help_mode = false
      end
      gfx.print(HELP, 0, 0, 0, true) -- warp words
      gfx.print("Here is the status line.", 0, h - 16, 0)
      screen:clear(0, h - 8, w, h - 8, 1)
      title:show()
    elseif r then
      proc_inp(r, v, a, b)
      if (mb.left or mb.right or mb.middle or r == 'mousewheel' or r == 'mouseup') then
        for _, o in ipairs(obj) do
          local mx, my, mb = input.mouse()
          if mx >= o.x and my >= o.y and
            mx < o.x + o.w and
            my < o.y + o.h then
            if r == 'mousewheel' then
              if o.mousewheel and o:mousewheel(v, mx, my) then
                break
              end
            elseif o:click(mx, my, mb, r == 'mousedown', r) then
              break
            end
          end
        end
      end
    end
    if not help_mode then
      screen:clear(1)
      table.sort(obj, function(a, b) return a.lev > b.lev end)
      for _, v in ipairs(obj) do
        v:show()
      end
      table.sort(obj, function(a, b) return a.lev <= b.lev end)
    end
    if mx < 0 or my < 0 or mx > w or my > h then
      sys.hidemouse(false)
      nomouse = false
    elseif not nomouse then
      sys.hidemouse()
      nomouse = true
    end
    spr.Cur:blend(screen, mx - floor(curw/2), my - floor(curh/2))
    gfx.flip(1, true) -- wait for event
  end
end

spr.L = gfx.new [[
------6------d--
--------
------6-
-----6--
----6---
---6----
--6-----
-6------
--------
]]

spr.B = gfx.new [[
------6------d--
--------
-666666-
-6----6-
-6----6-
-6----6-
-6----6-
-666666-
--------
]]

spr.C = gfx.new [[
------6------d--
--------
---66---
--6--6--
-6----6-
-6----6-
--6--6--
---66---
--------
]]

spr.Cur = gfx.new [[
0------7--------
---0---
---7---
---0---
0707070
---0---
---7---
---0---
]]

spr.HL = gfx.new [[
--------89------
--------
-88--88-
-8----8-
---99---
---99---
-8----8-
-88--88-
--------
]]

spr.Hand = gfx.new [[
---------------f
--fff---
--ffff--
--ffff--
f-fffff-
fffffff-
fffffff-
-fffff--
--ffff--
]]

spr.X = gfx.new [[
*
*---*
-*-*-
--*--
-*-*-
*---*
]]

spr.G = gfx.new [[
--------------e-
--e--e--
--e--e--
eeeeeeee
--e--e--
--e--e--
eeeeeeee
--e--e--
--e--e--
]]

spr.S = gfx.new [[
------------c---
--------
-cc--cc-
-c----c-
--------
--------
-c----c-
-cc--cc-
--------
]]

spr.F = gfx.new [[
------6---a--d--
--------
---a6---
--a666--
-a66666-
-a66666-
-a-666--
----6---
--------
]]

spr.M = gfx.new [[
-----------b----
------
-b-b-b
------
-b-b-b
------
-b-b-b
]]

spr.H = gfx.new [[
------------c---
--ccc-
-c---c
-----c
---cc-
---c--
------
---c--
]]

run()
