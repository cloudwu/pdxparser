local parser = {}

local pattern = {
	macro = "@(%a%w*)",
	open = "{",
	close = "}",
	number = "([+-]?%d+%.?%d*)",
	string = '"',
	comment = "#",
	cr = "\n\r?",
	sign = "([<>=])",
	atom = "(%a+[%w._]*)",
	eos = "$",
}

for k,v in pairs(pattern) do
	pattern[k] = "^[ \t]*"..v
end

local parse_list	-- function parse_list

local function read_string(state)
	local offset = state.offset
	while true do
		local from, to, value = string.find(state.text, '(\\*")', offset)
		if value == nil then
			error "broken string"
		end
		if #value % 2 == 1 then
			local str = string.sub(state.text, state.offset, to - 1)
			if string.find(str, "\n", 1, true) then
				error "string contains \\n"
			end
			state.offset = to + 1
			return str
		end
		offset = to + 1
	end
end

local function skip_comment(state)
	local from = string.find(state.text, "\n", state.offset, true)
	if from then
		state.offset = from
	else
		state.offset = #state.text + 1
	end
end

local function next_atom(state)
	for k,v in pairs(pattern) do
		local from, to, value = string.find(state.text, v, state.offset)
		if from then
			state.offset = to + 1
			if k == "number" then
				return k, tonumber(value)
			elseif k == "string" then
				return k, read_string(state)
			elseif k == "comment" then
				skip_comment(state)
				return k
			else
				if k == "cr" then
					state.line = state.line + 1
				end
				return k, value
			end
		end
	end
	error "Unknown token"
end

local function macro_define(state, key)
	local pat, value = next_atom(state)
	assert(pat == "sign" and value == "=", "Need =")
	local pat, value = next_atom(state)
	if pat == "number" or
		pat == "atom" or
		pat == "string"
	then
		state.macro[key] = value
		return
	end
	error "Macro define error"
end

local function parse_number(state)
	local what, value = next_atom(state)
	if what == "macro" then
		local v = state.macro[value]
		if v then
			return v
		end
		error("Undefined macro " .. value)
	end
	if what == "number" then
		return value
	end
	return nil, what, value
end

local function parse_value(state)
	local v , what, value = parse_number(state)
	if v then
		return v
	end
	if what == "string" or what == "atom" then
		return value
	end
	if what == "open" then
		local list, term = parse_list(state)
		assert(term == "close", "Need } ")
		return list
	end
	error("Syntax error")
end

local function parse_one(state)
	local pat, value = next_atom(state)
	if pat == "eos" or pat == "close" then
		return nil, pat
	end
	if state.newline then
		if pat == "macro" then
			macro_define(state, value)
			return parse_one(state)
		else
			state.newline = false
		end
	end
	if pat == "comment" then
		return parse_one(state)
	end
	if pat == "cr" then
		state.newline = true
		return parse_one(state)
	end

	if pat == "number" or pat == "string" or pat == "atom" then
		return value
	end
	if pat == "open" then
		local list, term = parse_list(state)
		assert(term == "close", "Need }")
		return list
	end
	if pat == "sign" then
		local v, addi = parse_one(state)
		if v == nil or addi then
			error "Syntax error"
		end
		return v, value
	end
	if pat == "macro" then
		return value
	end
	error ("Invalid token " .. pat)
end

-- local function parse_list
function parse_list(state)
	local list = {}
	while true do
		local value, pat = parse_one(state)
		if value then
			if pat then
				local key = table.remove(list)
				if key == nil then
					error "Syntax error"
				end
				assert(type(key) ~= "table", "list can't be key")
				if pat == "=" then
					table.insert(list, { key, value })
				else
					table.insert(list, { pat, key, value })
				end
			else
				table.insert(list, value)
			end
		else
			return list, pat
		end
	end
end

local function parse(state)
	local list, term = parse_list(state)
	assert(term == "eos", "Syntax error")
	return list
end

function parser.parse(text)
	local state = {
		line = 1,
		newline = true,
		text = text,
		offset = 1,
		macro = {},
	}
	local ok, value = pcall(parse,state)
	if not ok then
		return nil, string.format("Syntax error at line (%d) : %s", state.line, value)
	else
		return value
	end
end

return parser
