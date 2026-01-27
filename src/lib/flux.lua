-- Based on rxi's flux (simplified)
local flux = { tweens = {} }

local function check(value)
  return value
end

local function make_tween(obj, time, vars)
  local t = {
    obj = obj,
    rate = time > 0 and 1 / time or 0,
    progress = time > 0 and 0 or 1,
    vars = {}
  }
  
  for k, v in pairs(vars) do
    t.vars[k] = { start = obj[k], diff = v - obj[k] }
  end
  
  table.insert(flux.tweens, t)
  return t
end

function flux.to(obj, time, vars)
  return make_tween(obj, time, vars)
end

function flux.update(dt)
  for i = #flux.tweens, 1, -1 do
    local t = flux.tweens[i]
    t.progress = t.progress + t.rate * dt
    local p = t.progress
    local x = p * (2 - p) -- easeOutQuad
    
    for k, v in pairs(t.vars) do
      t.obj[k] = v.start + x * v.diff
    end
    
    if t.progress >= 1 then
      -- Snap to end
      for k, v in pairs(t.vars) do
        t.obj[k] = v.start + v.diff
      end
      table.remove(flux.tweens, i)
      if t.onComplete then t.onComplete() end
    end
  end
end

function flux.clear()
    flux.tweens = {}
end

return flux
