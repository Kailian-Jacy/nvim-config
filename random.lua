-- random.lua — a little grab bag of Lua
local function fib(n)
  local a, b = 0, 1
  for _ = 1, n do
    a, b = b, a + b
  end
  return a
end

local fruits = { "apple", "banana", "cherry", "date" }
math.randomseed(os.time())

local picked = fruits[math.random(#fruits)]
print("Today's fruit: " .. picked)

for i = 1, 8 do
  print(string.format("fib(%d) = %d", i, fib(i)))
end

local total = 0
for _, word in ipairs(fruits) do
  total = total + #word
end
print("Total letters in fruit list: " .. total)
