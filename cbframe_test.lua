local ffi = require'ffi'
local cbframe = require'cbframe'
local dump = require'cbframe_dump'

local function test()
	local cb1 = cbframe.new(function(rd)
		print'here1'
		--dump(rd)
		rd.EAX.u = 7654321
	end)

	local cb2 = cbframe.new(function(rd)
		print'here2'
		--dump(rd)
		rd.EAX.u = 654321
	end)

	local f1 = ffi.cast('int(__cdecl*)(float, int, int, int, int, int)', cb1.ptr)
	local ret = f1(12345.6, 0x3333, 0x4444, 0x5555, 0x6666, 0x7777)
	assert(ret == 7654321)

	local f2 = ffi.cast('int(__cdecl*)(float, int, int, int, int, int)', cb2.ptr)
	local ret = f2(12345.6, 0x3333, 0x4444, 0x5555, 0x6666, 0x7777)
	assert(ret == 654321)

	cb1:free()
	cb2:free()
end

test()

local cb = cbframe.new(function(rd)
	dump(rd)
	rd.EAX.u = 7654321
end)
assert(cb.slot == 0)
local f = ffi.cast('int(__cdecl*)(float, int, int, int, int, int)', cb.ptr)
local ret = f(12345.6, 0x3333, 0x4444, 0x5555, 0x6666, 0x7777)
assert(ret == 7654321)
