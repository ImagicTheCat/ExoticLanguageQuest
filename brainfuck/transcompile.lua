-- Lua 5.1
-- path: file path
-- target: (optional) bytecode, cpp, luajit
-- mem: (optional) brainfuck memory in bytes
local path, target, mem = ...
if not target then target = "bytecode" end

local file = io.open(path, "rb")
if not file then error("invalid file path") end
local data = file:read("*a")

-- parse brainfuck

local function get_op(c)
  if c == ">" then return {"ptr", 1}
  elseif c == "<" then return {"ptr", -1}
  elseif c == "+" then return {"val", 1}
  elseif c == "-" then return {"val", -1}
  elseif c == "." then return {"out", 1}
  elseif c == "," then return {"in", 1}
  elseif c == "[" then return {"loop", 1}
  elseif c == "]" then return {"loop", -1}
  end
end

local bytecode = {}
do
  local mode
  local count = 0

  for i=1,string.len(data) do
    local c = string.sub(data,i,i)
    local op = get_op(c)
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
    elseif bc[1] == "loop" then
      if bc[2] > 0 then
        for i=1,bc[2] do print("  while(*ptr){") end
      else
        for i=1,-bc[2] do print("  }") end
      end
    end
  end

  print([[
  return 0;
}
  ]])
elseif target == "luajit" then
  print([[local ffi = require("ffi")]])
  print("local mem = ffi.new(\"char["..mem.."]\")")
  print("local ptr = 0")
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
      print("mem[ptr]=mem[ptr]+"..bc[2])
    elseif bc[1] == "in" then
      for i=1,bc[2] do
        print("mem[ptr] = C.getchar()")
      end
    elseif bc[1] == "out" then
      if bc[2] > 1 then
        print("for i=1,"..bc[2].." do C.putchar(mem[ptr]) end")
      else
        print("C.putchar(mem[ptr])")
      end
    elseif bc[1] == "loop" then
      if bc[2] > 0 then
        for i=1,bc[2] do print("while mem[ptr] ~= 0 do") end
      else
        for i=1,-bc[2] do print("end") end
      end
    end
  end
else
  error("unknown target \""..target.."\"")
end
