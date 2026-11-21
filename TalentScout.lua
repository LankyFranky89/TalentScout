-- Talent Scout: preview-only talent presets. Never spends talent points.
-- WoW Forever uses the modern traits API (C_ClassTalents / C_Traits) for its 3-tree talents.
local f = CreateFrame("Frame")
local _, class, classID = UnitClass("player")
local PREFIX = "|cff66ccffTalent Scout:|r "
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

local ROLE_LABEL = { dps = "Damage", tank = "Tank", heal = "Healer" }
local ROLE_ICON = {
  dps = "Interface\\Icons\\INV_Sword_04",
  tank = "Interface\\Icons\\INV_Shield_06",
  heal = "Interface\\Icons\\Spell_Holy_HolyBolt",
}
local TREE_NAMES = {
  WARRIOR = { "Arms", "Fury", "Protection" }, PALADIN = { "Holy", "Protection", "Retribution" },
  HUNTER = { "Beast Mastery", "Marksmanship", "Survival" }, ROGUE = { "Assassination", "Combat", "Subtlety" },
  PRIEST = { "Discipline", "Holy", "Shadow" }, SHAMAN = { "Elemental", "Enhancement", "Restoration" },
  MAGE = { "Arcane", "Fire", "Frost" }, WARLOCK = { "Affliction", "Demonology", "Destruction" },
  DRUID = { "Balance", "Feral Combat", "Restoration" },
}
local function TabName(tab) return (TREE_NAMES[class] or {})[tab] or ("Tree " .. tab) end

local function Builds()
  local list = {}
  for _, b in ipairs((TalentScout_Builds and TalentScout_Builds[class]) or {}) do list[#list + 1] = b end
  for _, b in ipairs((TalentScoutDB and TalentScoutDB.custom) or {}) do list[#list + 1] = b end
  return list
end
local function CurrentBuild()
  local b = Builds()
  return b[(TalentScoutDB and TalentScoutDB.build) or 1] or b[1]
end
local function Parse(entry)
  local name, n = entry:match("^(.-):(%d+)$")
  return name, tonumber(n) or 1
end

-- ---------- Reading talents through C_Traits ----------
local cache = { byName = {}, byNode = {}, count = 0, err = nil }
local prereqOf = {}  -- nodeID -> { nodeIDs with an arrow pointing to it }

local function SpellName(spellID)
  if not spellID then return end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
  if GetSpellInfo then return (GetSpellInfo(spellID)) end
end

local function ReadTalents()
  local byName, byNode, count = {}, {}, 0
  cache.err = nil
  local ok, err = pcall(function()
    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then cache.err = "no active talent config"; return end
    cache.configID = configID
    local cfg = C_Traits.GetConfigInfo(configID)
    local treeIDs = cfg and cfg.treeIDs or {}
    cache.treeIDs = treeIDs
    local raw, minX, maxX, subTrees = {}, math.huge, -math.huge, {}
    prereqOf = {}
    for treeIndex, treeID in ipairs(treeIDs) do
      for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.ID and info.ID ~= 0 then
          local entryID = (info.activeEntry and info.activeEntry.entryID) or (info.entryIDs and info.entryIDs[1])
          local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
          local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
          local name = def and ((def.overrideName ~= "" and def.overrideName) or SpellName(def.spellID or def.overriddenSpellID))
          if name then
            raw[#raw + 1] = { name = name, nodeID = nodeID, rank = info.currentRank or info.activeRank or 0,
              max = info.maxRanks, x = info.posX or 0, y = info.posY or 0, entryID = entryID, spellID = def and (def.spellID or def.overriddenSpellID),
              icon = def and (def.overrideIcon or (C_Spell and C_Spell.GetSpellTexture and (def.spellID or def.overriddenSpellID) and C_Spell.GetSpellTexture(def.spellID or def.overriddenSpellID))), sub = info.subTreeID, treeIndex = treeIndex }
            if info.posX then minX = math.min(minX, info.posX); maxX = math.max(maxX, info.posX) end
            if info.subTreeID then subTrees[info.subTreeID] = true end
            for _, e in ipairs(info.visibleEdges or {}) do
              if e.targetNode then prereqOf[e.targetNode] = prereqOf[e.targetNode] or {}; table.insert(prereqOf[e.targetNode], nodeID) end
            end
          end
        end
      end
    end
    -- Which of the three trees is each talent in?
    local subList = {}
    for id in pairs(subTrees) do subList[#subList + 1] = id end
    table.sort(subList)
    local subIndex = {}
    for i, id in ipairs(subList) do subIndex[id] = i end
    local width = (maxX - minX); if width <= 0 then width = 1 end
    for _, t in ipairs(raw) do
      if #treeIDs > 1 then t.tab = t.treeIndex
      elseif #subList > 1 and t.sub then t.tab = subIndex[t.sub]
      else t.tab = math.min(3, math.floor((t.x - minX) / (width / 3 + 0.001)) + 1) end
      byName[t.name] = t; byNode[t.nodeID] = t; count = count + 1
    end
    local minY = math.huge
    for _, t in ipairs(raw) do minY = math.min(minY, t.y) end
    for _, t in ipairs(raw) do
      t.row = math.floor((t.y - minY) / 600 + 0.5) + 1
      t.requires = {}
      for _, pid in ipairs(prereqOf[t.nodeID] or {}) do
        local pt = byNode[pid]
        if pt then table.insert(t.requires, pt.name) end
      end
    end
  end)
  if not ok then cache.err = tostring(err) end
  cache.byName, cache.byNode, cache.count = byName, byNode, count
  return byName
end

local function UnspentPoints()
  if GetNumUnspentTalents then local ok, n = pcall(GetNumUnspentTalents); if ok and n then return n end end
  if UnitCharacterPoints then return UnitCharacterPoints("player") or 0 end
  return 0
end

local function MainTab(build, map)
  local per = {}
  for _, e in ipairs(build.order) do
    local name, n = Parse(e)
    local t = map[name]
    if t then per[t.tab] = (per[t.tab] or 0) + n end
  end
  local best, bestN = nil, -1
  for tab, n in pairs(per) do if n > bestN then best, bestN = tab, n end end
  return best
end

-- Expands a preset into a point-by-point list, adding arrow requirements (at full rank) first.
local function ExpandOrder(build, map)
  local steps, have, total = {}, {}, 0
  local function addPoint(name)
    have[name] = (have[name] or 0) + 1
    steps[#steps + 1] = name
  end
  local function ensureReqs(name, depth)
    local t = map[name]
    if not t or depth > 5 then return end
    for _, req in ipairs(t.requires or {}) do
      local rt = map[req]
      if rt then
        ensureReqs(req, depth + 1)
        while (have[req] or 0) < (rt.max or 1) do addPoint(req) end
      end
    end
  end
  for _, e in ipairs(build.order) do
    local name, n = Parse(e)
    for _ = 1, n do
      if (have[name] or 0) == 0 then ensureReqs(name, 0) end
      local t = map[name]
      if not t or (have[name] or 0) < (t.max or 99) then addPoint(name) end
    end
  end
  -- stay within the 51 points a character gets
  while #steps > 51 do table.remove(steps) end
  return steps
end

local function Analyse()
  local build = CurrentBuild()
  if not build then return end
  local map = cache.byName
  local targets, nextName, nextTarget = {}, nil, nil
  for _, name in ipairs(ExpandOrder(build, map)) do
    targets[name] = (targets[name] or 0) + 1
    local t = map[name]
    if not nextName and t and t.rank < targets[name] then nextName, nextTarget = name, targets[name] end
  end
  return targets, nextName, nextTarget
end


-- ---------- What a talent gives YOU (exact, from your current stats) ----------
local STAT_INDEX = { strength = 1, agility = 2, stamina = 3, intellect = 4, spirit = 5 }
local descCache = {}
local function RankDesc(t, rank)
  if not (t.entryID and rank and rank > 0 and C_Traits.GetTraitDescription) then return nil end
  local key = t.entryID .. ":" .. rank
  if descCache[key] == nil then
    local ok, d = pcall(C_Traits.GetTraitDescription, t.entryID, rank)
    descCache[key] = (ok and d) or false
  end
  return descCache[key] or nil
end

-- Which kind of talent is this, and what number does a rank give?
local function Classify(desc)
  if not desc then return end
  local d = desc:lower()
  local stat, v = d:match("increases your total (%a+) by ([%d%.]+)%%")
  if not stat then stat, v = d:match("increases your (%a+) by ([%d%.]+)%%") end
  if stat and STAT_INDEX[stat] then return "stat:" .. stat, tonumber(v) end
  v = d:match("armor value from items by ([%d%.]+)%%"); if v then return "itemarmor", tonumber(v) end
  v = d:match("critical strike with all spells and attacks by ([%d%.]+)%%"); if v then return "crit", tonumber(v) end
  v = d:match("your chance to hit by ([%d%.]+)%%"); if v then return "hit", tonumber(v) end
  v = d:match("parry chance by ([%d%.]+)%%"); if v then return "parry", tonumber(v) end
  v = d:match("dodge chance by ([%d%.]+)%%"); if v then return "dodge", tonumber(v) end
  v = d:match("defense skill by (%d+)"); if v then return "defense", tonumber(v) end
  local spell, sec = desc:match("cooldown of your (.-) spell by (%d+) sec")
  if not spell then spell, sec = desc:match("cooldown of your (.-) ability by (%d+) sec") end
  if spell then return "cd:" .. spell, tonumber(sec) end
end

local function ValueAt(t, rank)
  if not rank or rank <= 0 then return 0 end
  local kind, v = Classify(RankDesc(t, rank))
  return v or 0, kind
end

local function ItemArmor()
  local total = 0
  for slot = 1, 19 do
    local data = C_TooltipInfo and C_TooltipInfo.GetInventoryItem and C_TooltipInfo.GetInventoryItem("player", slot)
    for _, line in ipairs((data and data.lines) or {}) do
      local txt = line.leftText
      if txt and issecretvalue and issecretvalue(txt) then txt = nil end
      local ok, n = pcall(function() return txt and txt:match("^(%d+) Armor$") end)
      n = ok and n or nil
      if n then total = total + tonumber(n); break end
    end
  end
  return total
end

local function Round(x) return math.floor(x + 0.5) end

-- WoW Forever can hand addons "secret" numbers (no maths allowed). Treat those as unknown.
local function Plain(v)
  if v == nil then return nil end
  if issecretvalue then local ok, sec = pcall(issecretvalue, v); if not ok or sec then return nil end end
  if canaccessvalue then local ok, can = pcall(canaccessvalue, v); if not ok or not can then return nil end end
  if type(v) ~= "number" then return nil end
  return v
end

-- gain(kind, pctOrValue) relative to having 0 ranks, using the talent's current rank to back out its bonus
local function Gainer(t)
  local kind = select(2, ValueAt(t, t.max or 1))
  if not kind then return end
  local now = ValueAt(t, t.rank)
  if kind:find("^stat:") then
    local idx = STAT_INDEX[kind:sub(6)]
    local _, total = UnitStat("player", idx)
    total = Plain(total)
    if not total then return end
    local base = total / (1 + now / 100)
    local label = kind:sub(6):gsub("^%l", string.upper)
    return kind, function(v) return Round(base * v / 100) end, function(n) return ("+%d %s"):format(n, label) end
  elseif kind == "itemarmor" then
    local items = ItemArmor()
    return kind, function(v) return Round(items * v / 100) end, function(n) return ("+%d armor"):format(n) end
  elseif kind == "defense" then
    return kind, function(v) return v end, function(n) return ("+%d defense"):format(n) end
  elseif kind == "crit" or kind == "hit" or kind == "parry" or kind == "dodge" then
    return kind, function(v) return v end, function(n) return ("+%s%% %s"):format(n, kind) end
  elseif kind:find("^cd:") then
    return kind, function(v) return v end, function(n) return ("-%ds cooldown"):format(n) end
  end
end

local function CurrentOf(kind)
  local ok, v = pcall(function()
    if kind == "crit" and GetCritChance then return Plain(GetCritChance()) end
    if kind == "parry" and GetParryChance then return Plain(GetParryChance()) end
    if kind == "dodge" and GetDodgeChance then return Plain(GetDodgeChance()) end
    if kind == "defense" and UnitDefense then
      local b, m = UnitDefense("player"); b, m = Plain(b), Plain(m) or 0
      return b and (b + m)
    end
  end)
  return ok and v or nil
end

-- Lines for a tooltip: next point and full rank
local function EffectLines(t)
  if not t then return end
  local kind, gain, fmt = Gainer(t)
  if not kind then return end
  local r, max = t.rank or 0, t.max or 1
  local lines = {}
  local function withNow(delta)
    local cur = CurrentOf(kind)
    if not cur then return "" end
    if kind == "defense" then return (" (%d -> %d)"):format(cur, cur + delta) end
    return (" (%.1f%% -> %.1f%%)"):format(cur, cur + delta)
  end
  if kind:find("^cd:") then
    local spell = kind:sub(4)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell)
    local baseMs = info and GetSpellBaseCooldown and Plain(GetSpellBaseCooldown(info.spellID))
    if baseMs and baseMs > 0 then
      local base = baseMs / 1000
      local full = ValueAt(t, max)
      lines[#lines + 1] = ("%s cooldown: %ds -> %ds at %d/%d"):format(spell, base, base - full, max, max)
    end
    return lines
  end
  local nowG, maxG = gain(ValueAt(t, r)), gain(ValueAt(t, max))
  if r < max then
    local nextG = gain(ValueAt(t, r + 1)) - nowG
    lines[#lines + 1] = ("Next point: %s%s"):format(fmt(nextG), withNow(nextG))
    lines[#lines + 1] = ("At %d/%d: %s"):format(max, max, fmt(maxG))
  else
    lines[#lines + 1] = ("At %d/%d (now): %s"):format(max, max, fmt(maxG))
  end
  return lines
end

local function AddEffectToTooltip(tt, t)
  local ok, lines = pcall(EffectLines, t)
  if not ok then lines = nil end
  if not lines or #lines == 0 then return end
  tt:AddLine(" ")
  tt:AddLine("Talent Scout - for you:", 0.4, 0.8, 1)
  for _, l in ipairs(lines) do tt:AddLine(l, 0.3, 1, 0.3) end
  tt:Show()
end

-- Whole-preset summary (stat talents at the preset's planned ranks, vs. no points)
local PresetSummaryRaw
local function PresetSummary(build)
  local ok, parts = pcall(PresetSummaryRaw, build)
  return ok and parts or {}
end
PresetSummaryRaw = function(build)
  local counts = {}
  for _, name in ipairs(ExpandOrder(build, cache.byName)) do counts[name] = (counts[name] or 0) + 1 end
  local totals, order, fmts = {}, {}, {}
  for name, n in pairs(counts) do
    local t = cache.byName[name]
    if t then
      local kind, gain, fmt = Gainer(t)
      if kind and not kind:find("^cd:") then
        if not totals[kind] then totals[kind] = 0; order[#order + 1] = kind; fmts[kind] = fmt end
        totals[kind] = totals[kind] + gain(ValueAt(t, math.min(n, t.max or n)))
      end
    end
  end
  table.sort(order)
  local parts = {}
  for _, k in ipairs(order) do parts[#parts + 1] = fmts[k](totals[k]) end
  return parts
end

-- ---------- Finding the talent window ----------
local function TalentsFrame()
  if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame then return PlayerSpellsFrame.TalentsFrame, PlayerSpellsFrame end
  if ClassTalentFrame and ClassTalentFrame.TalentsTab then return ClassTalentFrame.TalentsTab, ClassTalentFrame end
  if PlayerTalentFrame then return PlayerTalentFrame, PlayerTalentFrame end
end

local function ButtonNodeID(b)
  if b.GetNodeID then local ok, id = pcall(b.GetNodeID, b); if ok and id then return id end end
  if b.nodeID then return b.nodeID end
  if b.GetNodeInfo then local ok, i = pcall(b.GetNodeInfo, b); if ok and i then return i.ID end end
end

local function ForEachTalentButton(cb)
  local tf = TalentsFrame()
  if not tf then return end
  if tf.EnumerateAllTalentButtons then
    for b in tf:EnumerateAllTalentButtons() do
      local id = ButtonNodeID(b)
      if id then cb(b, id) end
    end
    return
  end
  local function walk(fr, depth)
    if depth > 6 then return end
    for _, c in ipairs({ fr:GetChildren() }) do
      local id = ButtonNodeID(c)
      if id and cache.byNode[id] then cb(c, id) else walk(c, depth + 1) end
    end
  end
  walk(tf, 0)
end

-- ---------- Preview overlay ----------
local overlays, labels = {}, {}
local function GetOverlay(btn)
  local o = overlays[btn]
  if o then return o end
  o = CreateFrame("Frame", nil, btn)
  o:SetAllPoints(btn)
  o:SetFrameLevel(btn:GetFrameLevel() + 5)
  o.tint = o:CreateTexture(nil, "OVERLAY")
  o.tint:SetPoint("TOPLEFT", 4, -4); o.tint:SetPoint("BOTTOMRIGHT", -4, 4)
  o.tint:SetColorTexture(0.2, 1, 0.2, 0.2)
  o.glow = o:CreateTexture(nil, "OVERLAY")
  o.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  o.glow:SetBlendMode("ADD"); o.glow:SetVertexColor(0.3, 1, 0.3)
  o.glow:SetPoint("CENTER"); o.glow:SetSize(btn:GetWidth() * 1.8, btn:GetHeight() * 1.8)
  o.badge = o:CreateTexture(nil, "OVERLAY")
  o.badge:SetColorTexture(0, 0.25, 0, 0.9)
  o.badge:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2); o.badge:SetSize(16, 14)
  o.text = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  o.text:SetPoint("CENTER", o.badge, "CENTER", 0, 0)
  -- rotating ring of light behind the icon (sits under the talent button)
  o.ringFrame = CreateFrame("Frame", nil, btn:GetParent() or btn)
  o.ringFrame:SetFrameLevel(math.max(0, btn:GetFrameLevel() - 1))
  o.ringFrame:SetPoint("CENTER", btn, "CENTER")
  o.ringFrame:SetSize(btn:GetWidth() * 2.4, btn:GetHeight() * 2.4)
  o.ring = o.ringFrame:CreateTexture(nil, "ARTWORK")
  o.ring:SetAllPoints(); o.ring:SetTexture("Interface\\Cooldown\\starburst")
  o.ring:SetBlendMode("ADD"); o.ring:SetVertexColor(1, 0.85, 0.35, 0.9)
  o.ring2 = o.ringFrame:CreateTexture(nil, "ARTWORK")
  o.ring2:SetPoint("CENTER"); o.ring2:SetSize(btn:GetWidth() * 1.8, btn:GetHeight() * 1.8)
  o.ring2:SetTexture("Interface\\Cooldown\\star4")
  o.ring2:SetBlendMode("ADD"); o.ring2:SetVertexColor(0.5, 1, 0.5, 0.7)
  o.spin = o.ringFrame:CreateAnimationGroup(); o.spin:SetLooping("REPEAT")
  local r1 = o.spin:CreateAnimation("Rotation"); r1:SetTarget(o.ring); r1:SetDegrees(-360); r1:SetDuration(8)
  local r2 = o.spin:CreateAnimation("Rotation"); r2:SetTarget(o.ring2); r2:SetDegrees(360); r2:SetDuration(6)
  o.ringFrame:Hide()
  o.anim = o.spin
  overlays[btn] = o
  return o
end

local LockReason, ValidSet, RuleError
local tipHooked = {}
local rec = nil          -- recording state: { steps = {}, role = "dps" }
local captures = {}      -- talent button -> click catcher used while recording
local strip              -- "coming up next" icon strip
local recBar             -- recording toolbar
local UpdatePreview


-- ---------- Talent rules for recording (rows need 5 pts per row above; arrows need full rank) ----------
local function TreePoints(counts, tab, belowRow)
  local n = 0
  for name, c in pairs(counts) do
    local t = cache.byName[name]
    if t and t.tab == tab and (not belowRow or t.row < belowRow) then n = n + c end
  end
  return n
end

LockReason = function(t, counts)
  local need = ((t.row or 1) - 1) * 5
  local have = TreePoints(counts, t.tab, t.row)
  if have < need then
    return ("%s needs %d points in %s first (you have %d)."):format(t.name, need, TabName(t.tab), have)
  end
  for _, req in ipairs(t.requires or {}) do
    local rt = cache.byName[req]
    if rt and (counts[req] or 0) < (rt.max or 1) then
      return ("%s needs %s at %d/%d first."):format(t.name, req, rt.max or 1, rt.max or 1)
    end
  end
end

ValidSet = function(counts)
  for name, c in pairs(counts) do
    if c > 0 then
      local t = cache.byName[name]
      if t then
        local need = ((t.row or 1) - 1) * 5
        if TreePoints(counts, t.tab, t.row) < need then
          return false, ("%s would lose its %d points in %s above it."):format(name, need, TabName(t.tab))
        end
        for _, req in ipairs(t.requires or {}) do
          local rt = cache.byName[req]
          if rt and (counts[req] or 0) < (rt.max or 1) then
            return false, ("%s depends on %s."):format(name, req)
          end
        end
      end
    end
  end
  return true
end

RuleError = function(msg)
  if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 1, 0.2, 0.2) end
  Print("|cffff5555" .. msg .. "|r")
end

local function RecCounts()
  local c = {}
  for _, n in ipairs(rec.steps) do c[n] = (c[n] or 0) + 1 end
  return c
end

local function GetCapture(btn, nodeID)
  local c = captures[btn]
  if not c then
    c = CreateFrame("Button", nil, btn)
    c:SetAllPoints(btn); c:SetFrameLevel(btn:GetFrameLevel() + 40)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:SetScript("OnClick", function(self, button)
      local t = cache.byNode[self.nodeID]
      if not (t and rec) then return end
      local counts = RecCounts()
      local have = counts[t.name] or 0
      if button == "RightButton" then
        if have == 0 then return end
        counts[t.name] = have - 1
        local ok, why = ValidSet(counts)
        if not ok then RuleError("Can't remove: " .. why) return end
        for i = #rec.steps, 1, -1 do if rec.steps[i] == t.name then table.remove(rec.steps, i); break end end
      else
        if have >= (t.max or 1) then RuleError(t.name .. " is already at max rank.") return end
        if #rec.steps >= 51 then RuleError("All 51 points are used.") return end
        local why = LockReason(t, counts)
        if why then RuleError(why) return end
        rec.steps[#rec.steps + 1] = t.name
      end
      UpdatePreview()
    end)
    c.lock = c:CreateTexture(nil, "OVERLAY")
    c.lock:SetPoint("TOPLEFT", 3, -3); c.lock:SetPoint("BOTTOMRIGHT", -3, 3)
    c.lock:SetColorTexture(0, 0, 0, 0.6)
    c:SetScript("OnEnter", function(self)
      local t = cache.byNode[self.nodeID]
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if t and t.spellID then GameTooltip:SetSpellByID(t.spellID) elseif t then GameTooltip:AddLine(t.name) end
      if t then AddEffectToTooltip(GameTooltip, t) end
      if t and rec then
        local why = ((RecCounts()[t.name] or 0) == 0) and LockReason(t, RecCounts())
        if why then GameTooltip:AddLine(why, 1, 0.3, 0.3, true) end
      end
      GameTooltip:AddLine("Recording: left-click add a point, right-click remove one", 0.4, 0.8, 1, true)
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    captures[btn] = c
  end
  c.nodeID = nodeID
  return c
end

-- the steps still to take, grouped: { {name=, to=, icon=, spellID=}, ... }
local function Upcoming(build, max)
  local out, counts = {}, {}
  for _, name in ipairs(ExpandOrder(build, cache.byName)) do
    counts[name] = (counts[name] or 0) + 1
    local t = cache.byName[name]
    if t and t.rank < counts[name] then
      local last = out[#out]
      if last and last.name == name then last.to = counts[name]
      else
        if #out >= max then break end
        out[#out + 1] = { name = name, to = counts[name], icon = t.icon, spellID = t.spellID }
      end
    end
  end
  return out
end

local function UpdateStrip(build, mainTab)
  if not strip then return end
  local lbl = mainTab and labels[mainTab]
  if rec or not (TalentScoutDB.preview and build and lbl) then strip:Hide() return end
  local list = Upcoming(build, 5)
  if #list == 0 then strip:Hide() return end
  strip:ClearAllPoints(); strip:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
  strip:SetWidth(#list * 28 + 36)
  for i = 1, 5 do
    local b, it = strip.icons[i], list[i]
    if it then
      b:Show(); b.tex:SetTexture(it.icon or 134400)
      b.num:SetText(i); b.rank:SetText(it.to)
      b.spellID, b.name, b.to = it.spellID, it.name, it.to
      b.tex:SetDesaturated(i > 1); b.tex:SetAlpha(i == 1 and 1 or 0.75)
    else b:Hide() end
  end
  strip:Show()
end

local lastOff = nil
local function CheckOffPlan(silent)
  if not (TalentScoutDB and TalentScoutDB.preview) or rec then lastOff = nil; return end
  local targets = Analyse()
  if not targets then return end
  local now = {}
  for name, t in pairs(cache.byName) do
    if t.rank > (targets[name] or 0) then now[name] = true end
  end
  if lastOff and not silent then
    for name in pairs(now) do
      if not lastOff[name] then
        Print(("|cffff5555Off-preset:|r %s (the preset has %d). The preset carries on from your current talents."):format(name, targets[name] or 0))
      end
    end
  end
  lastOff = now
end

UpdatePreview = function()
  local show = TalentScoutDB and TalentScoutDB.preview
  local targets, nextName
  local recCounts = rec and RecCounts()
  if rec then targets = recCounts
  elseif show then targets, nextName = Analyse() end
  local used, usedCap = {}, {}
  ForEachTalentButton(function(btn, nodeID)
    local t = cache.byNode[nodeID]
    if not tipHooked[btn] then
      tipHooked[btn] = true
      btn:HookScript("OnEnter", function(self)
        local id = ButtonNodeID(self)
        if id and cache.byNode[id] and GameTooltip:IsOwned(self) then AddEffectToTooltip(GameTooltip, cache.byNode[id]) end
      end)
    end
    if rec and t and btn:IsShown() then
      local c = GetCapture(btn, nodeID); c:Show(); usedCap[c] = true
      c.lock:SetShown(((recCounts[t.name] or 0) == 0) and LockReason(t, recCounts) ~= nil)
    end
    if not (t and btn:IsShown() and targets) then return end
    local target = targets[t.name] or 0
    local off = (not rec) and t.rank > target
    if target == 0 and not off then return end
    local o = GetOverlay(btn)
    used[o] = true
    o:Show()
    o.text:SetText(target)
    if rec then
      o.badge:SetColorTexture(0, 0.15, 0.35, 0.95); o.text:SetTextColor(0.5, 0.8, 1)
      o.tint:SetColorTexture(0.3, 0.6, 1, 0.25); o.tint:Show()
      o.glow:Hide(); o.anim:Stop(); o.ringFrame:Hide()
      return
    end
    if off then
      o.badge:SetColorTexture(0.35, 0, 0, 0.95); o.text:SetTextColor(1, 0.35, 0.35)
      o.tint:Hide()
      o.glow:SetVertexColor(1, 0.15, 0.15); o.glow:Show()
      o.anim:Stop(); o.ringFrame:Hide()
      return
    end
    o.badge:SetColorTexture(0, 0.25, 0, 0.9)
    local done = t.rank >= target
    o.text:SetTextColor(done and 0.6 or 0.3, done and 0.6 or 1, done and 0.6 or 0.3)
    o.tint:SetColorTexture(0.2, 1, 0.2, 0.2); o.tint:SetShown(not done)
    o.glow:SetVertexColor(0.3, 1, 0.3)
    if t.name == nextName then
      o.glow:Show(); o.ringFrame:Show()
      if not o.anim:IsPlaying() then o.anim:Play() end
    else
      o.anim:Stop(); o.glow:Hide(); o.ringFrame:Hide()
    end
  end)
  for _, o in pairs(overlays) do
    if not used[o] then o.anim:Stop(); o.ringFrame:Hide(); o:Hide() end
  end
  for _, c in pairs(captures) do if not usedCap[c] then c:Hide() end end
  local b = CurrentBuild()
  local main = b and MainTab(b, cache.byName)
  for p, lbl in pairs(labels) do
    if show and b and p == main and not rec then lbl:SetText("|cff33ff33" .. b.name .. "|r") else lbl:SetText("") end
  end
  UpdateStrip(b, main)
  if recBar and rec then recBar:Refresh() end
end

-- ---------- Recording your own preset ----------
local ROLE_ORDER = { "dps", "tank", "heal" }
local function StopRecording()
  rec = nil
  if recBar then recBar:Hide() end
  UpdatePreview()
end

local function SaveRecording()
  if not rec or #rec.steps == 0 then Print("Click some talents first.") return end
  local name = recBar.name:GetText()
  if not name or name:match("^%s*$") then name = "My preset " .. (#(TalentScoutDB.custom or {}) + 1) end
  local order = {}
  for _, n in ipairs(rec.steps) do
    local last = order[#order]
    if last and last.name == n then last.n = last.n + 1 else order[#order + 1] = { name = n, n = 1 } end
  end
  local entries = {}
  for _, e in ipairs(order) do entries[#entries + 1] = e.name .. ":" .. e.n end
  TalentScoutDB.custom = TalentScoutDB.custom or {}
  table.insert(TalentScoutDB.custom, { role = rec.role, name = name, order = entries, custom = true })
  TalentScoutDB.build = #Builds(); TalentScoutDB.preview = true
  Print(("Saved preset |cff33ff33%s|r (%d points). Shift-click it in the right-click menu to delete it."):format(name, #rec.steps))
  StopRecording()
end

local function StartRecording()
  local tf = TalentsFrame()
  if not tf then Print("Open your talent window first.") return end
  ReadTalents()
  rec = { steps = {}, role = (CurrentBuild() and CurrentBuild().role) or "dps" }
  if not recBar then
    local layer = tf.ButtonsParent or tf
    recBar = CreateFrame("Frame", nil, layer, BackdropTemplateMixin and "BackdropTemplate" or nil)
    recBar:SetFrameLevel(layer:GetFrameLevel() + 120)
    recBar:SetSize(640, 34)
    recBar:SetPoint("TOP", tf, "TOP", 0, -52)
    if recBar.SetBackdrop then
      recBar:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      recBar:SetBackdropBorderColor(0.3, 0.6, 1)
    end
    recBar.dot = recBar:CreateTexture(nil, "OVERLAY"); recBar.dot:SetSize(10, 10); recBar.dot:SetPoint("LEFT", 10, 0)
    recBar.dot:SetColorTexture(1, 0.2, 0.2)
    local blink = recBar.dot:CreateAnimationGroup(); blink:SetLooping("BOUNCE")
    local ba = blink:CreateAnimation("Alpha"); ba:SetFromAlpha(1); ba:SetToAlpha(0.2); ba:SetDuration(0.6); blink:Play()
    recBar.count = recBar:CreateFontString(nil, "OVERLAY", "GameFontNormal"); recBar.count:SetPoint("LEFT", recBar.dot, "RIGHT", 6, 0)
    recBar.name = CreateFrame("EditBox", nil, recBar, "InputBoxTemplate")
    recBar.name:SetSize(150, 20); recBar.name:SetPoint("LEFT", 160, 0); recBar.name:SetAutoFocus(false)
    recBar.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    recBar.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    recBar.nameHint = recBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    recBar.nameHint:SetPoint("BOTTOMLEFT", recBar.name, "TOPLEFT", -4, 0); recBar.nameHint:SetText("Preset name")
    local function mk(label, w, x, fn)
      local b = CreateFrame("Button", nil, recBar, "UIPanelButtonTemplate")
      b:SetSize(w, 22); b:SetPoint("LEFT", x, 0); b:SetText(label); b:SetScript("OnClick", fn)
      return b
    end
    recBar.role = mk("", 92, 320, function()
      for i, r in ipairs(ROLE_ORDER) do if r == rec.role then rec.role = ROLE_ORDER[i % 3 + 1]; break end end
      recBar:Refresh()
    end)
    mk("Undo", 56, 418, function() if rec and #rec.steps > 0 then table.remove(rec.steps); UpdatePreview() end end)
    mk("Clear", 56, 478, function() if rec then wipe(rec.steps); UpdatePreview() end end)
    mk("Save", 50, 538, SaveRecording)
    mk("X", 26, 594, StopRecording)
    function recBar:Refresh()
      if not rec then return end
      self.count:SetText(("Recording  %d / 51"):format(#rec.steps))
      self.role:SetText(ROLE_LABEL[rec.role])
    end
  end
  recBar.name:SetText("")
  recBar:Show(); recBar:Refresh()
  if menu then menu:Hide() end
  Print("Recording: left-click talents in the order you want, right-click to remove. Nothing is spent. Press Save when done.")
  UpdatePreview()
end

-- ---------- Preset menu ----------
local menu
local function ShowMenu(anchor, tab)
  ReadTalents()
  if not menu then
    menu = CreateFrame("Frame", "TalentScoutMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    menu:SetFrameStrata("DIALOG"); menu:SetClampedToScreen(true)
    if menu.SetBackdrop then
      menu:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      menu:SetBackdropBorderColor(0.7, 0.6, 0.35)
    end
    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal"); menu.title:SetPoint("TOPLEFT", 10, -8)
    menu.note = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); menu.note:SetPoint("TOPLEFT", 10, -24)
    menu.rows = {}
    menu:SetScript("OnUpdate", function(self)
      if IsMouseButtonDown() and not self:IsMouseOver() and not (self.anchor and self.anchor:IsMouseOver()) then self:Hide() end
    end)
  end
  local items = {}
  for i, b in ipairs(Builds()) do
    if MainTab(b, cache.byName) == tab then items[#items + 1] = { idx = i, build = b } end
  end
  items[#items + 1] = { record = true }
  items[#items + 1] = { clear = true }
  menu.title:SetText("Talent Scout - " .. TabName(tab))
  menu.note:SetText(#items == 2 and "No presets for this tree yet" or "Preview only - no points are spent")
  for _, r in ipairs(menu.rows) do r:Hide() end
  for k, item in ipairs(items) do
    local r = menu.rows[k]
    if not r then
      r = CreateFrame("Button", nil, menu); r:SetSize(250, 24)
      r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 4, 0)
      r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
      r.check:SetSize(18, 18); r.check:SetPoint("RIGHT", -2, 0)
      r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      menu.rows[k] = r
    end
    r:SetPoint("TOPLEFT", 8, -40 - (k - 1) * 26)
    if item.record or item.clear then r:SetScript("OnEnter", nil); r:SetScript("OnLeave", nil) end
    if item.record then
      r.icon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up"); r.text:SetText("New preset (record)"); r.check:Hide()
      r:SetScript("OnClick", function() menu:Hide(); StartRecording() end)
    elseif item.clear then
      r.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); r.text:SetText("Hide preview"); r.check:Hide()
      r:SetScript("OnClick", function() TalentScoutDB.preview = false; menu:Hide(); UpdatePreview() end)
    else
      local role = item.build.role or "dps"
      r.icon:SetTexture(ROLE_ICON[role])
      r.text:SetText((item.build.custom and "|cff66ccff*|r " or "") .. ROLE_LABEL[role] .. ": " .. item.build.name)
      r.check:SetShown(TalentScoutDB.preview and TalentScoutDB.build == item.idx)
      r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(item.build.name)
        local parts = PresetSummary(item.build)
        if #parts > 0 then
          GameTooltip:AddLine("Gives you (from your current stats):", 0.4, 0.8, 1)
          for _, p in ipairs(parts) do GameTooltip:AddLine("  " .. p, 0.3, 1, 0.3) end
        end
        if item.build.custom then GameTooltip:AddLine("Shift-click to delete", 0.7, 0.7, 0.7) end
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r:SetScript("OnClick", function()
        if item.build.custom and IsShiftKeyDown() then
          for ci, cb in ipairs(TalentScoutDB.custom or {}) do
            if cb == item.build then table.remove(TalentScoutDB.custom, ci); break end
          end
          TalentScoutDB.build = 1; TalentScoutDB.treePick = {}
          Print("Deleted preset " .. item.build.name .. ".")
          menu:Hide(); UpdatePreview(); return
        end
        TalentScoutDB.build = item.idx; TalentScoutDB.preview = true
        TalentScoutDB.treePick = TalentScoutDB.treePick or {}; TalentScoutDB.treePick[tab] = item.idx
        menu:Hide(); ReadTalents(); UpdatePreview()
        local _, nextName, nextTarget = Analyse()
        if nextName then Print(("Previewing %s - next: |cff33ff33%s|r (rank %d)"):format(item.build.name, nextName, nextTarget)) end
      end)
    end
    r:Show()
  end
  menu:SetSize(270, 48 + #items * 26)
  menu.anchor = anchor
  menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  menu:Show()
end

-- ---------- Attaching to the talent window ----------
local hooked, ticker = false, nil
local hitAreas = {}
local function HookTalentUI()
  if hooked then return end
  local tf, root = TalentsFrame()
  if not tf then return end
  hooked = true
  for p = 1, 3 do
    -- invisible click area over each spec header (icon + name)
    local layer = tf.ButtonsParent or tf
    local hit = CreateFrame("Button", nil, layer)
    hit:SetFrameStrata(layer:GetFrameStrata())
    hit:SetFrameLevel(layer:GetFrameLevel() + 100)
    hit.debugTex = hit:CreateTexture(nil, "OVERLAY")
    hit.debugTex:SetAllPoints(); hit.debugTex:SetColorTexture(1, 0, 0, 0.35); hit.debugTex:Hide()
    hitAreas[#hitAreas + 1] = hit
    hit:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    hit:GetHighlightTexture():SetAlpha(0.25)
    local lbl = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetJustifyH("LEFT")
    local function place()
      local col = tf:GetWidth() / 3
      hit:ClearAllPoints()
      hit:SetPoint("TOPLEFT", tf, "TOPLEFT", col * (p - 1) + 111, -120)
      hit:SetSize(76 + #TabName(p) * 6.3, 47)
      lbl:ClearAllPoints(); lbl:SetPoint("BOTTOMLEFT", tf, "BOTTOMLEFT", col * (p - 1) + 22, 62)
    end
    place(); tf:HookScript("OnSizeChanged", place)
    hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hit:SetScript("OnClick", function(self, button)
      if button == "RightButton" then ShowMenu(self, p) return end
      if menu then menu:Hide() end
      ReadTalents()
      -- presets that are built around this tree
      local choices = {}
      for i, b in ipairs(Builds()) do if MainTab(b, cache.byName) == p then choices[#choices + 1] = i end end
      if #choices == 0 then Print("No presets for " .. TabName(p) .. " yet.") return end
      TalentScoutDB.treePick = TalentScoutDB.treePick or {}
      local pick = TalentScoutDB.treePick[p]
      local valid = false
      for _, i in ipairs(choices) do if i == pick then valid = true end end
      if not valid then pick = choices[1] end
      if TalentScoutDB.preview and TalentScoutDB.build == pick then
        TalentScoutDB.preview = false; UpdatePreview()
        Print("Preview off.")
      else
        TalentScoutDB.build = pick; TalentScoutDB.preview = true; UpdatePreview()
        local _, nextName, nextTarget = Analyse()
        Print("Previewing " .. CurrentBuild().name .. (nextName and (" - next: |cff33ff33" .. nextName .. "|r (rank " .. nextTarget .. ")") or ""))
      end
    end)
    hit:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Talent Scout - " .. TabName(p))
      GameTooltip:AddLine("Left-click: preview this tree's preset (click again to hide)", 1, 1, 1, true)
      GameTooltip:AddLine("Right-click: choose a Damage / Tank / Healer preset", 1, 1, 1, true)
      GameTooltip:AddLine("Preview only - no points are spent.", 0.6, 0.6, 0.6, true)
      GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    labels[p] = lbl
  end
  if not strip then
    local layer = tf.ButtonsParent or tf
    strip = CreateFrame("Frame", nil, layer)
    strip:SetFrameLevel(layer:GetFrameLevel() + 60); strip:SetHeight(28)
    strip.title = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    strip.title:SetPoint("LEFT", 0, 0); strip.title:SetText("Next:")
    strip.icons = {}
    for i = 1, 5 do
      local b = CreateFrame("Button", nil, strip)
      b:SetSize(22, 22); b:SetPoint("LEFT", 34 + (i - 1) * 28, 0)
      b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints()
      b.border = b:CreateTexture(nil, "OVERLAY"); b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
      b.border:SetPoint("CENTER"); b.border:SetSize(38, 38)
      b.num = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.num:SetPoint("TOPLEFT", -3, 3)
      b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); b.rank:SetPoint("BOTTOMRIGHT", 2, -2)
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.spellID then GameTooltip:SetSpellByID(self.spellID) else GameTooltip:AddLine(self.name or "?") end
        GameTooltip:AddLine(("Step %d: take it to rank %d"):format(i, self.to or 0), 0.3, 1, 0.3)
        if self.name and cache.byName[self.name] then AddEffectToTooltip(GameTooltip, cache.byName[self.name]) end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      strip.icons[i] = b
    end
    strip:Hide()
  end
  local function onShow()
    ReadTalents(); UpdatePreview(); CheckOffPlan(true)
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(0.5, function()
      if not tf:IsVisible() then ticker:Cancel(); ticker = nil; if rec then StopRecording() end; return end
      UpdatePreview()
    end)
  end
  tf:HookScript("OnShow", onShow)
  if tf:IsVisible() then onShow() end
end

-- ---------- Reminders ----------
local function Remind(force)
  local points = UnspentPoints()
  if points <= 0 and not force then return end
  local build = CurrentBuild()
  if not build then Print("No presets for your class yet.") return end
  ReadTalents()
  if cache.count == 0 then Print("Can't read your talents yet (" .. tostring(cache.err) .. ").") return end
  local _, nextName, nextTarget = Analyse()
  if nextName then
    Print(("%s - next: |cff33ff33%s|r (rank %d). Unspent points: %d"):format(build.name, nextName, nextTarget, points))
  else
    Print(build.name .. " is complete!")
  end
end

-- ---------- Debug report ----------
local dbgWin
local function ShowDebugWindow(text)
  if not dbgWin then
    dbgWin = CreateFrame("Frame", "TalentScoutDebug", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    dbgWin:SetSize(560, 380); dbgWin:SetPoint("CENTER"); dbgWin:SetFrameStrata("DIALOG")
    dbgWin:SetMovable(true); dbgWin:EnableMouse(true); dbgWin:RegisterForDrag("LeftButton")
    dbgWin:SetScript("OnDragStart", dbgWin.StartMoving); dbgWin:SetScript("OnDragStop", dbgWin.StopMovingOrSizing)
    if dbgWin.SetBackdrop then
      dbgWin:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    end
    local t = dbgWin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", 12, -10); t:SetText("Talent Scout debug - Ctrl+A, Ctrl+C, then paste to Claude")
    local close = CreateFrame("Button", nil, dbgWin, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 0, 0)
    local sf = CreateFrame("ScrollFrame", nil, dbgWin, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -32); sf:SetPoint("BOTTOMRIGHT", -32, 12)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetFontObject(ChatFontNormal); eb:SetWidth(510); eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() dbgWin:Hide() end)
    sf:SetScrollChild(eb)
    dbgWin.eb = eb
  end
  dbgWin.eb:SetText(text); dbgWin:Show(); dbgWin.eb:SetFocus(); dbgWin.eb:HighlightText()
end

local function RunDebug()
  local L = {}
  local function add(s) L[#L + 1] = s end
  local v, b, _, iface = GetBuildInfo()
  add(("Build %s (%s), interface %s, class %s"):format(tostring(v), tostring(b), tostring(iface), tostring(class)))
  ReadTalents()
  add(("configID=%s trees=%s talents read=%d err=%s unspent=%s"):format(tostring(cache.configID),
    cache.treeIDs and #cache.treeIDs or "nil", cache.count, tostring(cache.err), tostring(UnspentPoints())))
  local list = {}
  for _, t in pairs(cache.byName) do list[#list + 1] = t end
  table.sort(list, function(a, c) if a.tab ~= c.tab then return a.tab < c.tab end if a.y ~= c.y then return a.y < c.y end return a.x < c.x end)
  for i, t in ipairs(list) do
    if i > 120 then add("..."); break end
    local desc
    if C_Traits.GetTraitDescription and t.entryID then
      local ok, d = pcall(C_Traits.GetTraitDescription, t.entryID, math.max(1, t.max or 1)); if ok then desc = d end
    end
    if (not desc or desc == "") and t.spellID and C_Spell and C_Spell.GetSpellDescription then
      local ok, d = pcall(C_Spell.GetSpellDescription, t.spellID); if ok then desc = d end
    end
    desc = tostring(desc or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\r\n]+", " ")
    if #desc > 140 then desc = desc:sub(1, 140) .. "..." end
    add(("[%s] y=%s x=%s %s %d/%s%s - %s"):format(TabName(t.tab), tostring(t.y), tostring(t.x), t.name, t.rank, tostring(t.max),
      (#(t.requires or {}) > 0) and (" (needs " .. table.concat(t.requires, ", ") .. ")") or "", desc))
  end
  local tf, root = TalentsFrame()
  add(("talent frame: %s (root %s), shown=%s"):format(tf and (tf:GetDebugName() or "?") or "none",
    root and (root:GetDebugName() or "?") or "none", tostring(tf and tf:IsVisible())))
  local n, matched = 0, 0
  ForEachTalentButton(function(_, id) n = n + 1; if cache.byNode[id] then matched = matched + 1 end end)
  add(("talent buttons: %d, matched to talents: %d"):format(n, matched))
  for _, bb in ipairs(Builds()) do
    local total, missing = 0, {}
    for _, e in ipairs(bb.order) do
      local name, k = Parse(e); total = total + k
      if not cache.byName[name] then missing[#missing + 1] = name end
    end
    add(("preset %s: %d pts, main tree %s, unknown: %s"):format(bb.name, total, TabName(MainTab(bb, cache.byName) or 0),
      #missing > 0 and table.concat(missing, ", ") or "none"))
  end
  ShowDebugWindow(table.concat(L, "\n"))
end


-- ---------- Dump every class's talent tree (view-only, nothing is changed) ----------
local CLASS_IDS = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }
local function SpecForClass(cid)
  if GetSpecializationInfoForClassID then
    local ok, specID = pcall(GetSpecializationInfoForClassID, cid, 1)
    if ok and specID then return specID end
  end
  if CSI and CSI.GetSpecIDs then
    local ok, ids = pcall(CSI.GetSpecIDs, cid)
    if ok and type(ids) == "table" and ids[1] then return ids[1] end
  end
end
local function DumpTree(L, classFile, configID, treeID)
  local rows, minX, maxX = {}, math.huge, -math.huge
  for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
    local info = C_Traits.GetNodeInfo(configID, nodeID)
    if info and info.ID and info.ID ~= 0 then
      local entryID = (info.activeEntry and info.activeEntry.entryID) or (info.entryIDs and info.entryIDs[1])
      local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
      local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
      local spellID = def and (def.spellID or def.overriddenSpellID)
      local name = def and ((def.overrideName ~= "" and def.overrideName) or SpellName(spellID))
      if name then
        local desc
        if C_Traits.GetTraitDescription then local ok, d = pcall(C_Traits.GetTraitDescription, entryID, math.max(1, info.maxRanks or 1)); if ok then desc = d end end
        if (not desc or desc == "") and spellID and C_Spell and C_Spell.GetSpellDescription then local ok, d = pcall(C_Spell.GetSpellDescription, spellID); if ok then desc = d end end
        desc = tostring(desc or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\r\n]+", " ")
        if #desc > 110 then desc = desc:sub(1, 110) .. "..." end
        rows[#rows + 1] = { x = info.posX or 0, y = info.posY or 0, name = name, max = info.maxRanks or 0, desc = desc }
        minX = math.min(minX, info.posX or 0); maxX = math.max(maxX, info.posX or 0)
      end
    end
  end
  local width = maxX - minX; if width <= 0 then width = 1 end
  local minY = math.huge
  for _, r in ipairs(rows) do minY = math.min(minY, r.y) end
  for _, r in ipairs(rows) do
    r.tab = math.min(3, math.floor((r.x - minX) / (width / 3 + 0.001)) + 1)
    r.row = math.floor((r.y - minY) / 600 + 0.5) + 1
  end
  table.sort(rows, function(a, c) if a.tab ~= c.tab then return a.tab < c.tab end if a.row ~= c.row then return a.row < c.row end return a.x < c.x end)
  local names = TREE_NAMES[classFile] or {}
  for _, r in ipairs(rows) do
    L[#L + 1] = ("%s|%s|r%d|%s|%d|%s"):format(classFile, names[r.tab] or r.tab, r.row, r.name, r.max, r.desc)
  end
  return #rows
end

local function DumpAll()
  local L = {}
  local VIEW = (Constants and Constants.TraitConsts and Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID) or -3
  local ownConfig = C_ClassTalents.GetActiveConfigID()
  for _, cid in ipairs(CLASS_IDS) do
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo(cid)
    local classFile = info and info.classFile or tostring(cid)
    local ok, err = pcall(function()
      local specID = SpecForClass(cid)
      local treeID = specID and C_ClassTalents.GetTraitTreeForSpec(specID)
      if not treeID then L[#L + 1] = classFile .. ": no tree (spec " .. tostring(specID) .. ")"; return end
      local n = 0
      if classFile == class and ownConfig then
        n = DumpTree(L, classFile, ownConfig, treeID)
      else
        if C_ClassTalents.InitializeViewLoadout then pcall(C_ClassTalents.InitializeViewLoadout, specID, 60) end
        if C_ClassTalents.ViewLoadout then pcall(C_ClassTalents.ViewLoadout, {}) end
        n = DumpTree(L, classFile, VIEW, treeID)
        if n == 0 and ownConfig then n = DumpTree(L, classFile, ownConfig, treeID) end
      end
      if n == 0 then L[#L + 1] = classFile .. ": tree " .. treeID .. " found but no talents readable" end
    end)
    if not ok then L[#L + 1] = classFile .. ": ERROR " .. tostring(err) end
  end
  ShowDebugWindow(table.concat(L, "\n"))
end

local function OpenTalents()
  local tf = TalentsFrame()
  if tf and tf:IsVisible() then return end
  if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then pcall(PlayerSpellsUtil.ToggleClassTalentFrame)
  elseif ToggleTalentFrame then pcall(ToggleTalentFrame) end
end

-- ---------- Slash ----------
SLASH_TALENTSCOUT1 = "/tscout"
SLASH_TALENTSCOUT2 = "/tsc"
SlashCmdList.TALENTSCOUT = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  local cmd, arg = msg:match("^(%S*)%s*(.*)$")
  if cmd == "debug" then
    OpenTalents()
    C_Timer.After(0.6, function() HookTalentUI(); RunDebug() end)
  elseif cmd == "showhit" or cmd == "showit" or cmd == "show" then
    HookTalentUI()
    if not hooked then Print("|cffff5555Talent window not found yet - open it (N) and try again.|r") return end
    TalentScoutDB.showHit = not TalentScoutDB.showHit
    for _, h in ipairs(hitAreas) do h.debugTex:SetShown(TalentScoutDB.showHit) end
    Print("Click areas " .. (TalentScoutDB.showHit and "shown in red" or "hidden") .. " (" .. #hitAreas .. " found)")
  elseif cmd == "summary" then
    ReadTalents()
    local b = CurrentBuild()
    if not b then Print("No preset.") return end
    local parts = PresetSummary(b)
    Print(b.name .. " gives you: " .. (#parts > 0 and table.concat(parts, ", ") or "no stat talents"))
  elseif cmd == "record" then
    OpenTalents(); C_Timer.After(0.6, function() HookTalentUI(); StartRecording() end)
  elseif cmd == "dumpall" then
    DumpAll()
  elseif cmd == "list" then
    for i, b in ipairs(Builds()) do Print(("%d. [%s] %s%s"):format(i, ROLE_LABEL[b.role or "dps"], b.name, i == (TalentScoutDB.build or 1) and " |cff33ff33(active)|r" or "")) end
  elseif cmd == "build" and tonumber(arg) and Builds()[tonumber(arg)] then
    TalentScoutDB.build = tonumber(arg); TalentScoutDB.preview = true; ReadTalents(); UpdatePreview()
    Print("Previewing: " .. CurrentBuild().name)
  elseif cmd == "role" and ROLE_LABEL[arg] then
    for i, b in ipairs(Builds()) do
      if (b.role or "dps") == arg then
        TalentScoutDB.build = i; TalentScoutDB.preview = true; ReadTalents(); UpdatePreview()
        Print("Previewing: " .. b.name); return
      end
    end
    Print("No " .. ROLE_LABEL[arg]:lower() .. " presets for your class.")
  elseif cmd == "hide" then
    TalentScoutDB.preview = not TalentScoutDB.preview; UpdatePreview()
    Print("Preview " .. (TalentScoutDB.preview and "on" or "off"))
  elseif cmd == "mouse" then
    local foc = (GetMouseFoci and GetMouseFoci()[1]) or (GetMouseFocus and GetMouseFocus())
    local d = 0
    while foc and d < 8 do
      Print((d == 0 and "Under mouse: " or "  parent: ") .. tostring(foc.GetDebugName and foc:GetDebugName() or foc:GetName()))
      foc = foc:GetParent(); d = d + 1
    end
  elseif cmd == "remind" then
    TalentScoutDB.noRemind = not TalentScoutDB.noRemind
    Print("Level-up reminders " .. (TalentScoutDB.noRemind and "off" or "on"))
  else
    Remind(true)
    Print("Open your talents and left-click a spec to preview, right-click for presets.")
    Print("Something broken? Type /tsc debug")
    Print("Commands: /tsc list | build <n> | role dps/tank/heal | hide | record | summary | showhit | debug | dumpall | mouse | remind")
  end
end

-- ---------- Events ----------
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LEVEL_UP")
for _, e in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_TREE_CHANGED" }) do
  pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "TalentScout" then
      TalentScoutDB = TalentScoutDB or {}
      if TalentScoutDB.build == nil then TalentScoutDB.build = 1 end
      if TalentScoutDB.preview == nil then TalentScoutDB.preview = true end
    elseif not hooked and type(arg1) == "string" and (arg1:find("Talent") or arg1:find("PlayerSpells")) then
      C_Timer.After(0, HookTalentUI)
    end
  elseif event == "PLAYER_LOGIN" then
    local tries = 0
    C_Timer.NewTicker(2, function(t)
      tries = tries + 1
      if hooked or tries > 300 then t:Cancel() return end
      HookTalentUI()
    end)
    if not TalentScout_Builds then Print("|cffff5555Builds.lua failed to load - presets missing.|r") end
    HookTalentUI()
    C_Timer.After(5, function() if not TalentScoutDB.noRemind then Remind() end end)
  elseif event == "PLAYER_LEVEL_UP" then
    C_Timer.After(1, function() if not TalentScoutDB.noRemind then Remind() end end)
  else
    C_Timer.After(0.2, function() ReadTalents(); UpdatePreview(); CheckOffPlan() end)
  end
end)
