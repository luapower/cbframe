local ffi = require'ffi'
local cbframe = require'cbframe'

--test float converters
local function test_conv()
	local f80 = ffi.new'uint8_t[10]'
	cbframe.float64to80(1/8, f80)
	local f64 = cbframe.float80to64(f80)
	assert(f64 == 1/8)
end

local function test_cbframe(cpu)
	local function f1(cpu)
		cbframe.dump(cpu)
		cpu.RAX.u = 7654321
	end
	local cb1 = cbframe.new(f1)

	local cb2 = cbframe.new(function(cpu)
		cbframe.dump(cpu)
		cpu.RAX.u = 4321
	end)

	local cf1 = ffi.cast('int(__cdecl*)(float, int, int, int, int, int)', cb1.p)
	local ret = cf1(12345.6, 0x3333, 0x4444, 0x5555, 0x6666, 0x7777)
	assert(ret == 7654321)

	local f2 = ffi.cast('int(__cdecl*)(float, int, int, int, int, int)', cb2.p)
	local ret = f2(12345.6, 0x3333, 0x4444, 0x5555, 0x6666, 0x7777)
	assert(ret == 4321)

	cb1:free()
	cb2:free()
end

test_conv()
test_cbframe()

