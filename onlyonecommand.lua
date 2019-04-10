#!/usr/bin/lua5.2
--[[
Converts a series of commands into one command that can be executed in a command block. If it doesn't fit in the 32767 char limit, multiple commands are created. This program generates Minecraft 1.8 commands for Minecraft 1.8 command blocks.

usage:
onlyonecommand [commands] [output]
commands: a file with a list of commands to be executed, one per line (commands are executed in that order as well)
output: the file where the output command is saved
If the amount of commands you've given is too big to fit them into one command, it will be split up into multiple commands and each command will be written on a new line.
It is also possible that the game can't handle so many commandblock falling sand entities on top of each other, so this takes care of that as well.
default files are stdin and stdout

In the input file, you might want to execute something relative to the starting command block. This is possible:
setblock %x %y %z air
...will remove the original command block
summon Pig %1x %y %z
...will summon a pig next to the original command block
so:
%[number]x|y|z
will be offset to the original command block
negative numbers are also possible:
%-1y
...means one block underneath the original command block
you can even use decimals: %-.3z is valid
]]

local io = require("io")
local math = require("math")
local os = require("os")
local string = require("string")
local table = require("table")

local args = {...}

local maxlen = 32767
local maxsize = 150
local outermost = "summon FallingSand ~ ~1 ~ {Block:redstone_block,Time:1,Riding:{\n}}" -- \n can't occur inside the commands themselves because it's one command per line
local template = "id:FallingSand,Block:command_block,Time:1,TileEntityData:{Command:\n},Riding:{\n}"
local bottom = "id:FallingSand,Block:stone,Time:1"
local function escape(s)
  local i = 1
  local changed = false
  while i <= #s do
    if s:sub(i,i) == "\\" then
      changed = true
      s = s:sub(1,i-1) .. "\\\\" .. s:sub(i+1,-1)
      i = i + 2
    elseif s:sub(i,i) == "\"" then
      changed = true
      s = s:sub(1,i-1) .. "\\\"" .. s:sub(i+1,-1)
      i = i + 2
    else
      i = i + 1
    end
  end
  if changed or s:find(",",1,true) then
    return "\"" .. s .. "\""
  else
    return s
  end
end

local function tonumber_fix(s)
  if s == "" then
    return 0
  else
    return tonumber(s)
  end
end

local function format(s,...)
  local args = {...}
  local first = s:find("\n",1,true)
  local i = 1
  while first and args[i] do
    s = s:sub(1,first - 1) .. args[i] .. s:sub(first + 1,-1)
    i = i + 1
    first = s:find("\n",first + 1,true)
  end
  return s
end

local function relcoord(s,x,y,z,line)
  local i = 1
  while i <= #s do
    if s:sub(i,i) == "%" then
      if s:sub(i+1,i+1) == "%" then
        s = s:sub(1,i) .. s:sub(i+2,-1)
      else
        local first = s:find("[xyz]",i,false)
	local offset
	if first then
	  offset = tonumber_fix(s:sub(i+1,first - 1))
	  if not offset then
	    io.stderr:write("error at line #" .. line .. ": invalid offset\n")
	    os.exit()
	  end
	  local coord = s:sub(first,first) == "x" and x or s:sub(first,first) == "y" and y or z
	  s = s:sub(1,i-1) .. "~" .. (offset - coord ~= 0 and tostring(offset - coord) or "") .. s:sub(first + 1,-1)
	end
      end
    else
      i = i + 1
    end
  end
  return s
end

local function topcommand(height)
  return format(template,relcoord("fill %1x %2y %z %1x ~-1 %z redstone_block",0,height + 2,0,-1),
	 format(template,relcoord("fill %x %1y %z %1x ~2 %z air",0,height + 1,0,-1)))
end

--------------------------------------------------------------------------------

local input,output = io.stdin,io.stdout
if args[1] then
  local reason
  input,reason = io.open(args[1],"r")
  if not input then
    io.stderr:write("couldn't open file " .. args[1] .. " for reading: " .. reason .. ".\n")
    os.exit()
  end
end
if args[2] then
  local reason
  output,reason = io.open(args[2],"w")
  if not output then
    io.stderr:write("couldn't open file " .. args[2] .. " for writing: " .. reason .. ".\n")
    os.exit()
  end
end
    
local commands = {}
repeat
  local line = input:read()
  table.insert(commands,line)
until not line
input:close()

local first = 1
local last = 1
local savethis = false
local thiscommand
while last <= #commands do
  thiscommand = "\n"
  for i=last,first,-1 do
    thiscommand = format(thiscommand,format(template,relcoord(escape(commands[i]),0,first - i + 2,0,i)))
  end
  thiscommand = format(thiscommand,bottom)
  thiscommand = format(topcommand(last - first + 2),thiscommand)
  thiscommand = format(outermost,thiscommand)
  if #thiscommand > maxlen or last - first + 5 > maxsize then
    savethis = true
    last = last - 1
  elseif savethis then
    output:write(thiscommand .. "\n")
    first = last + 1
    last = first
    savethis = false
  else
    last = last + 1
  end
end
output:write(thiscommand .. "\n")

if output ~= io.stdout then
  output:close()
end
