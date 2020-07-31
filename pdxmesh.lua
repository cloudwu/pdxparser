--[[

From : https://forum.paradoxplaza.com/forum/threads/import-export-paradox-mesh-tool.1009625/

.mesh file format
========================================================================================================================
    header    (@@b@ for binary, @@t@ for text)
    pdxasset    (int)  number of assets?
        object    (object)  parent item for all 3D objects
            shape    (object)
                ...  multiple shapes, used for meshes under different node transforms
            shape    (object)
                mesh    (object)
                    ...  multiple meshes per shape, used for different material IDs
                mesh    (object)
                    ...
                mesh    (object)
                    p    (float)  verts
                    n    (float)  normals
                    ta    (float)  tangents
                    u0    (float)  UVs
                    tri    (int)  triangles
                    aabb    (object)
                        min    (float)  min bounding box
                        max    (float)  max bounding box
                    material    (object)
                        shader    (string)  shader name
                        diff    (string)  diffuse texture
                        n    (string)  normal texture
                        spec    (string)  specular texture
                    skin    (object)
                        bones    (int)  num skin influences
                        ix    (int)  skin bone ids
                        w    (float)  skin weights
                skeleton    (object)
                    bone    (object)
                        ix    (int)  index
                        pa    (int)  parent index, omitted for root
                        tx    (float)  transform, 3*4 matrix
        locator    (object)  parent item for all locators
            node    (object)
                p    (float)  position
                q    (float)  quarternion
                pa    (string)  parent
]]

local print_r = require "print_r"

local function readfile(filename)
	local f = assert(io.open(filename, "rb"))
	local content = f:read "a"
	f:close()
	return content
end

local function parse_data(content, pos)
	local t, n, pos = string.unpack("<c1i", content, pos)
	local result
	if t == "i" or t == "f" then
		result = {}
		local fmt = "<" .. t
		for i = 1, n do
			result[i], pos = string.unpack(fmt, content, pos)
		end
	elseif t == "s" then
		assert(n == 1, "Multiple strings")
		result, pos = string.unpack("<s4", content, pos)
		if result:byte(-1) == 0 then
			result = result:sub(1, -2)
		end
	else
		error ("Unknown type " .. t)
	end
	return result, pos
end

local function parse_object(content, pos)
	local _, npos = content:find("^%[+", pos)
	npos = npos + 1
	local depth = npos - pos
	local name
	name, pos = string.unpack("z", content, npos)
	return name, depth, pos
end

local function parse(content, pos, list)
	local c = content:sub(pos, pos)
	if c == "!" then
		local key, value
		key, pos = string.unpack("s1", content, pos+1)
		value, pos = parse_data(content, pos)
		local tree = list[list.depth]
		tree[key] = value
	elseif c == '[' then
		local name, depth
		name, depth, pos = parse_object(content, pos)
		if depth < list.depth then
			list.depth = depth
		else
			assert(depth == list.depth)
		end
		local tree = list[depth]
		local child = {}
		tree[name] = child
		depth = depth + 1
		list.depth = depth
		list[depth] = child
	else
		assert(c == "", "Unknown tag " .. c)
		return
	end
	return pos
end

local function main(filename)
	local content = readfile(filename)
	assert( content:sub(1, 4) == "@@b@" )

	local pos = 5
	local root = {}
	local depth_list = { depth = 1, root }

	repeat
		pos = parse(content, pos, depth_list)
	until pos == nil

	local r = depth_list[1]

	print_r(r)
end

main(...)

