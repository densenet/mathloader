-- @densenet

-- mathloader
-- a string loader for stringified geometric algebra kernels
-- the input code needs to be conformal to the model below:
-- rules: <subexp> = <"a["<number>"]*b["<number>"]">
--				<exp> = <subexp> <<"+"|"-"><subexp>>*
-- given the rules above, the source can be expressed:
--[=[
<"t["<index>"]="<exp>>* | "\n"*
]=]


local n, x, l, r = bit32.bnot, bit32.bxor, bit32.lshift, bit32.rshift

local repl, band = bit32.replace, bit32.band

type u32 = number
type bitcode = { u32 }
type i64 = number

type instructions = { i64 }
type idxlist0 =  { i64 }
type idxlist1 = { i64 }

local function kcompile(idxwidth: u32, src: string): bitcode
	-- 0: if no more nonzero instructions - exit
	-- 		otherwise - a, t = t, table.create(#t, 0)
	-- 1: t[.]= (assign)
	-- 2: +a[.]*b[.] (plusmulaccess)
	-- 3: -a[.]*b[.] (submulaccess)
	
	-- instructions are 2 bits
	-- indices are idxwidth bits, must be a multiple of two.
	
	if idxwidth % 2 ~= 0 then
		error("idxwidth must be an even number")
	end
	
	local program = {0}
	
	do
		local SIZE_IN = #src
		local ptr = 1
		local ins_ptr = 1
		local ins_depth = 0
		
		local function push(width: u32, chunk: u32)
			local fragment = 0
			repeat
				fragment = math.min(32 - ins_depth, width)
				
				program[ins_ptr] = repl(program[ins_ptr], band(chunk, n(l(-1, fragment))), ins_depth, fragment)
				
				chunk = r(chunk, fragment)
				
				ins_depth += fragment
				
				if ins_depth == 32 then
					ins_depth = 0
					ins_ptr += 1
					program[ins_ptr] = 0
				end
				
				width -= fragment
				
				if width < 0 then
					error("width underflow")
				end
				if ins_depth > 32 then
					error("ins_depth overflow")
				end
				if fragment <= 0 then
					error("fragment is not a positive number")
				end
			until width == 0
		end
		
		local byte = -1
		local function parse_index()
			local num = 0
			repeat
				byte = string.byte(src, ptr) - 48
				if byte > 9 or byte < 0 then
					error(string.format("nan: %s; ptr: %d", string.char(byte + 48), ptr))
				end
				num = num * 10 + byte
				ptr += 1
			until string.byte(src, ptr) == 93
			push(idxwidth, num - 1)
		end
		
		-- instruction loop	
		while ptr < SIZE_IN do
			byte = string.byte(src, ptr)
			if byte == 61 then
				if string.byte(src, ptr + 1) == 45 then
					byte = 45
					ptr += 1
				else
					byte = 43
				end
			end
			if byte == 10 then
				ptr += 1
			elseif byte == 116 then
				push(2, 1)
				ptr += 2
				parse_index()
				ptr += 1
			elseif byte == 43 then
				push(2, 2)
				ptr += 3
				parse_index()
				ptr += 4
				parse_index()
				ptr += 1
			elseif byte == 45 then
				push(2, 3)
				ptr += 3
				parse_index()
				ptr += 4
				parse_index()
				ptr += 1
			else
				error(string.format("syntax error: %x (%s)", byte, string.char(byte)))
			end
		end
	end
	
	return program
end

local function kexe(_index0, _index1, _index2, _index3, _index4)
	local DATASIZE = #_index0
	return function(t,a,b)
		local index0,index1,index2,index3,index4 = _index0,_index1,_index2,_index3,_index4
		local t_idx = 0
		local acc = 0
		
		local i0, i1, i2, i3, i4 = 0, 0, 0, 0, 0
		
		for i = 1, DATASIZE do
			i0, i1, i2 = index0[i], index1[i], index2[i]
			
			if i0 == -2 then
				i3, i4 = index3[i], index4[i]
				acc=acc+a[i1]*b[i2]+a[i3]*b[i4]
			elseif i0 == -3 then
				i3, i4 = index3[i], index4[i]
				acc=acc+a[i1]*b[i2]-a[i3]*b[i4]
			elseif i0 == -4 then
				i3, i4 = index3[i], index4[i]
				acc=acc-a[i1]*b[i2]+a[i3]*b[i4]
			elseif i0 == -5 then
				i3, i4 = index3[i], index4[i]
				acc=acc-a[i1]*b[i2]-a[i3]*b[i4]
			elseif i0 == 0 then
				acc=acc+a[i1]*b[i2]
			elseif i0 == -1 then
				acc=acc-a[i1]*b[i2]
			else
				t[t_idx] = acc
				acc, t_idx = 0, i0
			end
		end
		if t_idx then
			t[t_idx] = acc
		end
	end
end

local function kdata(idxwidth: u32, raw: bitcode): (instructions, idxlist0, idxlist1, idxlist0, idxlist1)
	local index0: instructions = {}
	local index1: idxlist0 = {}
	local index2: idxlist1 = {}
	local index3: idxlist0 = {}
	local index4: idxlist1 = {}
	
	-- load
	do
		local RAWSIZE = #raw
		local ins_ptr = 1
		local ins_depth = 0
		
		local function pop_index(): u32
			local readw = idxwidth
	
			local idx = 0
			repeat
				local fragment = math.min(32 - ins_depth, readw)
		
				idx = repl(idx, bit32.extract(raw[ins_ptr], ins_depth, fragment), idxwidth - readw, fragment)
		
				readw -= fragment
		
				ins_depth += fragment
		
				if ins_depth == 32 then
					ins_ptr += 1
					ins_depth = 0
				end
		
			until readw == 0
	
			return idx + 1
		end
		
		while ins_ptr <= RAWSIZE do
			local ins = bit32.extract(raw[ins_ptr], ins_depth, 2)
			
			ins_depth += 2
			if ins_depth == 32 then
				ins_depth = 0
				ins_ptr += 1
			end
			
			local N = #index0

			if ins == 1 then
				index0[N + 1] = pop_index()
				index1[N + 1] = -1
				index2[N + 1] = -1
				index3[N + 1] = -1
				index4[N + 1] = -1
			elseif ins == 2 then
				if index0[N] == 0 then
					index0[N] = -2
					index3[N] = pop_index()
					index4[N] = pop_index()
				elseif index0[N] == -1 then
					index0[N] = -4
					index3[N] = pop_index()
					index4[N] = pop_index()
				else
					index0[N + 1] = 0
					index1[N + 1] = pop_index()
					index2[N + 1] = pop_index()
					index3[N + 1] = -1
					index4[N + 1] = -1
				end
			elseif ins == 3 then
				if index0[N] == 0 then
					index0[N] = -3
					index3[N] = pop_index()
					index4[N] = pop_index()
				elseif index0[N] == -1 then
					index0[N] = -5
					index3[N] = pop_index()
					index4[N] = pop_index()
				else
					index0[N + 1] = -1
					index1[N + 1] = pop_index()
					index2[N + 1] = pop_index()
					index3[N + 1] = -1
					index4[N + 1] = -1
				end
			else
				break
			end
		end
	end
	
	return index0, index1, index2, index3, index4
end

local function mdata(src: string): (instructions, idxlist0, idxlist1, idxlist0)
	-- instructions:
	-- t[.]=C -- 1
	-- t[.]=C*t[.] -- 2
	-- t[.]=t[.] -- 3
	-- t[.]=-t[.] -- 4
	local index0: { u32 } = {}
	local index1: { u32 } = {}
	local index2: { u32 } = {}
	local index3: { u32 } = {}
	
	do
		local lhs, rhs = table.unpack(src:split"=")
	
		assert(lhs ~= nil and rhs ~= nil, "mload: no equals sign in src")

		local l0, l1 = lhs:split",", rhs:split","
	
		local n = #l0
	
		do
			local n1 = #l1
			assert(n == n1, string.format("mload: lopsided assignment (lhs term count: %d; rhs count: %d)", n, n1))
		end
	
		local term0, term1
		for i = 1, n do
			term0, term1 = l0[i], l1[i]
			local idx = term0:match"t%[(%d+)%]"
			local neg, coef = term1:match"^(%-?)(%d*)[*]?"
			local rhs_idx = term1:match"t%[(%d+)%]$"
		
			if rhs_idx ~= nil then
				if coef ~= "" then
					index0[i] = 2
					index1[i] = tonumber(idx) :: number
					index2[i] = (if neg == "" then 1 else -1) * tonumber(coef) :: number
					index3[i] = tonumber(rhs_idx) :: number
				else
					index0[i]=if neg=="" then 3 else 4
					index1[i]=tonumber(idx)::number
					index2[i]=0
					index3[i]=tonumber(rhs_idx)::number
				end
			else
				if coef==nil then
					coef=0
				end
				index0[i] = 1
				index1[i] = tonumber(idx) :: number
				index2[i] = (if neg == "" then 1 else -1) * tonumber(coef) :: number
				index3[i] = -1
			end
		end
	end
	
	return index0, index1, index2, index3
end

local function mexe(_index0, _index1, _index2, _index3)
	local PROGSIZE = #_index0
	return function(t)
		local _t = table.create(#t)
		local i0, i1, i2, i3
		for i = 1, PROGSIZE do
			i0, i1, i2, i3 = _index0[i], _index1[i], _index2[i], _index3[i]
			if i0 == 3 then
				_t[i1] = t[i3]
			elseif i0 == 4 then
				_t[i1] = -t[i3]
			elseif i0 == 2 then
				_t[i1] = i2*t[i3]
			else
				_t[i1] = i2
			end
		end
		
		return _t
	end
end

local __RELEASE = true
if __RELEASE then
	return {
		kcompile = kcompile,
		kdata = kdata,
		kexe = kexe,
		kload = function(...) return kexe(kdata(...)) end,
		mdata = mdata,
		mexe = mexe,
		mload = function(...) return mexe(mdata(...)) end,
	}
end
