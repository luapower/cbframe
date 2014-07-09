---
project: cbframe
tagline: callback frames for luajit
---

## `local cbframe = require'cbframe'`

Cbframe is a low-level helper module for the luajit ffi for creating ABI-agnostic callbacks.
I made it as a workaround for the problem of creating callbacks with pass-by-value struct
args and return values in [objc].

The idea is simple: your callbacks receive the [full state of the CPU] (all registers, and CPU flags even),
you can modify the state any way you want, and the CPU will be set with the modified state before the
callback returns. It's up to you to pick the function arguments from the right registers and/or stack,
and to put the return value into the right registers and/or stack, according to the calling convention
rules for your platform/compiler.

[full state of the CPU]: https://github.com/luapower/cbframe/blob/master/cbframe_x86_h.lua

You can use it to implement a full ABI in pure Lua with the help of [ffi_reflect].
Or, if you only have a few problematic callbacks that you need to work out, like I do, you can
discover where the arguments are on a case-by-case basis by inspecting the CPU state via
`cbframe.dump()`.
If in doubt, use [Agner Fog](http://www.agner.org/optimize/calling_conventions.pdf) (ABIs are a bitch).

Like ffi callbacks, cbframes are limited resources. You can create up to 1024
simultaneous cbframe objects (and you can change that limit in the code -
one callback slot is 7 bytes).

The API is simple. You don't even have to provide the function signature :)

~~~{.lua}
local foo = cbframe.new(function(cpu)
	cbframe.dump(cpu)       --inspect the CPU state
	local arg1 = cpu.RDI.s  --Linux/x64 ABI: int arg#1 in RDI
	cpu.RAX.s = arg1^2      --Linux/x64 ABI: return value in RAX
end)

--foo is the callback object, foo.p is the actual function pointer to use.
set_foo_callback(foo.p)

--cbframes are permanent by default just like ffi callbacks. tie them to the gc if you want.
ffi.gc(foo, foo.free)

--release the callback slot (or reuse it with foo:set(func)).
foo:free()
~~~
