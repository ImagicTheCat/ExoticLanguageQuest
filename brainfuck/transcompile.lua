-- Lua 5.1
-- path: file path
-- target: (optional) bytecode, cpp, luajit
-- mem: (optional) brainfuck memory in bytes
local path, target, mem = ...
if not target then target = "bytecode" end
mem = tonumber(mem) or 30000

local file = io.open(path, "rb")
if not file then error("invalid file path") end
local data = file:read("*a")

-- parse brainfuck

local ops = {
  [">"] = {"ptr", 1},
  ["<"] = {"ptr", -1},
  ["+"] = {"val", 1},
  ["-"] = {"val", -1},
  ["."] = {"out", 1},
  [","] = {"in", 1},
  ["["] = {"loop_in", 1},
  ["]"] = {"loop_out", 1}
}

local bytecode = {}
do
  local mode
  local count = 0

  for i=1,string.len(data) do
    local c = string.sub(data,i,i)
    local op = ops[c]
    if op then
      if op[1] ~= mode then -- new op mode
        if mode then -- output previous op
          table.insert(bytecode, {mode, count})
        end

        count = 0
        mode = op[1]
      end

      count = count+op[2]
    end
  end

  -- last op
  if mode then
    table.insert(bytecode, {mode, count})
  end
end

-- transcompile

if target == "bytecode" then
  for _, bc in ipairs(bytecode) do
    print(bc[1], bc[2])
  end
elseif target == "cpp" then
  print([[
#include <cstdio>

int main(int argc, char **argv)
{
  ]])
  print("  char mem["..mem.."] = {0};")
  print("  char *ptr = mem;")

  for _, bc in ipairs(bytecode) do
    if bc[1] == "ptr" then
      print("  ptr+="..bc[2]..";")
    elseif bc[1] == "val" then
      print("  *ptr+="..bc[2]..";")
    elseif bc[1] == "in" then
      for i=1,bc[2] do
        print("  *ptr = getchar();")
      end
    elseif bc[1] == "out" then
      if bc[2] > 1 then
        print("  for(int i="..bc[2].."; i != 0; --i,putchar(*ptr));")
      else
        print("  putchar(*ptr);")
      end
    elseif bc[1] == "loop_in" then
      for i=1,bc[2] do print("  while(*ptr){") end
    elseif bc[1] == "loop_out" then
      for i=1,bc[2] do print("  }") end
    end
  end

  print([[
  return 0;
}
  ]])
elseif target == "luajit" then
  print([[local ffi = require("ffi")]])
  print("local mem = ffi.new(\"char["..mem.."]\")")
  print("local ptr = mem")
  print([=[
ffi.cdef([[
int getchar(void);
int putchar(int);
]])

local C = ffi.C
  ]=])

  for _, bc in ipairs(bytecode) do
    if bc[1] == "ptr" then
      print("ptr=ptr+"..bc[2])
    elseif bc[1] == "val" then
      print("ptr[0]=ptr[0]+"..bc[2])
    elseif bc[1] == "in" then
      for i=1,bc[2] do
        print("ptr[0] = C.getchar()")
      end
    elseif bc[1] == "out" then
      if bc[2] > 1 then
        print("for i=1,"..bc[2].." do C.putchar(ptr[0]) end")
      else
        print("C.putchar(ptr[0])")
      end
    elseif bc[1] == "loop_in" then
      for i=1,bc[2] do print("while ptr[0] ~= 0 do") end
    elseif bc[1] == "loop_out" then
      for i=1,bc[2] do print("end") end
    end
  end
else
  error("unknown target \""..target.."\"")
end
