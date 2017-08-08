local p = require "pdx"
local print_r = require "print_r"
local f = assert(io.open "test.txt")
local text = f:read "a"

local v, err = p.parse(text)

if v then
	print_r(v)
else
	print(err)
end


