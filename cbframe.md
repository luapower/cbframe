---
project: cbframe
tagline: callback frames for luajit
---

Cbframe is a low-level helper module for the luajit ffi for creating ABI-agnostic callbacks.
I made it as a workaround for the problem of creating callbacks that accept pass-by-value
struct args and return values.

The idea is simple: your callbacks receive the full state of the CPU (all registers, and CPU flags even),
you can modify the state any way you want, and the CPU will be set with the modified state before the
callback returns. It's up to you to pick the function arguments from the right registers and/or stack,
and to put the return value into the right registers and/or stack, according to the ABI rules of your
platform/compiler.

> To change the stack, update the memory around ESP (RSP) directly, and update ESP (RSP).

You can implement the full ABI rules on top of it, or if you only have a few problematic callbacks
to work out, you can discover how arguments are passed in each case by using the included CPU state dumper.

Like ffi callbacks, cbframes are limited resources. There's a hard 1024 limit on them, which you can
change in the code.

The API is similar to that of ffi callbacks:

~~~{.lua}
local cbframe = require'cbframe'

local foo_cbframe = cbframe.new(function(cpu)
	cbframe.dump(cpu)       --inspect the CPU state
	local arg1 = cpu.RDI.s  --Linux/x64 ABI: int arg#1 in RDI
	cpu.RAX.s = arg1^2      --Linux/x64 ABI: return value in RAX
end)

--don't pass cbframe to your callback-setting function, pass cbframe.p instead.
set_foo_callback(foo_cbframe.p)

--make a cbframe permanent by untying it from the gc.
ffi.gc(cbframe, nil)

--release the callback slot (or reuse it with cbframe:set(func)).
cbframe:free()
~~~
