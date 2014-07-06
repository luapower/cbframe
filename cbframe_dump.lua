local ffi = require'ffi'
require'cbframe_x86_h'
require'dynasm'
local cvt80to64 = require'cbframe_x86'.cvt80to64

local EFLAGS = {
	title = 'FLAGS', stitle = 'FLAGS', mdfield = 'EFLAGS',
	fields = {'CF', 'PF', 'AF', 'ZF', 'SF', 'TF', 'IF', 'DF', 'OF',
				'IOPL', 'NT', 'RF', 'VM', 'AC', 'VIF', 'VIP', 'ID'},
	descr = {
		CF    = 'Carry',
		PF    = 'Parity',
		AF    = 'Auxiliary carry',
		ZF    = 'Zero',
		SF    = 'Sign',
		TF    = 'Trap',
		IF    = 'Interrupt enable',
		DF    = 'Direction',
		OF    = 'Overflow',
		IOPL  = 'I/O Priviledge level',
		NT    = 'Nested task',
		RF    = 'Resume',
		VM    = 'Virtual 8086 mode',
		AC    = 'Alignment check',
		VIF   = 'Virutal interrupt',
		VIP   = 'Virtual interrupt pending',
		ID    = 'ID',
	},
}

local FSW = {
	title = 'FPU STATUS WORD', stitle = 'FSW', mdfield = 'FSW',
	fields = {'I', 'D', 'Z', 'O', 'U', 'P', 'SF', 'IR', 'C0', 'C1', 'C2', 'TOP', 'C3', 'B'},
	descr = {
		I   = 'Invalid operation exception',
		D   = 'Denormalized exception',
		Z   = 'Zero divide exception',
		O   = 'Overflow exception',
		U   = 'Underflow exception',
		P   = 'Precision exception',
		SF  = 'Stack Fault exception',
		IR  = 'Interrupt Request',
		C0  = 'C0',
		C1  = 'C1',
		C2  = 'C2',
		TOP = 'TOP',
		C3  = 'C3',
		B   = 'Busy',
	},
}

local FCW = {
	title = 'FPU CONTROL WORD', stitle = 'FCW', mdfield = 'FCW',
	fields = {'IM', 'DM', 'ZM', 'OM', 'UM', 'PM', 'IEM', 'PC', 'RC', 'IC'},
	descr = {
		IM  = 'Invalid operation mask',
		DM  = 'Denormalized operand mask',
		ZM  = 'Zero divide mask',
		OM  = 'Overflow mask',
		UM  = 'Underflow mask',
		PM  = 'Precision mask',
		IEM = 'Interrupt Enable mask',
		PC  = 'Precision Control mask',
		RC  = 'Rounding Control mask',
		IC  = 'Infinity Control mask',
	},
}

local MXCSR = {
	title = 'SSE CONTROL/STATUS FLAG', stitle = 'MXCSR', mdfield = 'MXCSR',
	fields = {'IE', 'DE', 'ZE', 'OE', 'UE', 'PE', 'DAZ', 'IM',
				'DM', 'ZM', 'OM', 'UM', 'PM', 'RM', 'FZ'},
	descr = {
		FZ	 = 'Flush To Zero',
		RM  = 'Round Mode',
		PM  = 'Precision Mask',
		UM  = 'Underflow Mask',
		OM  = 'Overflow Mask',
		ZM  = 'Divide By Zero Mask',
		DM  = 'Denormal Mask',
		IM  = 'Invalid Operation Mask',
		DAZ = 'Denormals Are Zero',
		PE  = 'Precision Flag',
		UE  = 'Underflow Flag',
		OE  = 'Overflow Flag',
		ZE  = 'Divide By Zero Flag',
		DE  = 'Denormal Flag',
		IE  = 'Invalid Operation Flag',
	},
}

local x64 = ffi.arch == 'x64'
local _ = string.format
local out = function(...) io.stdout:write(...) end
local s = ('-'):rep(x64 and 140 or 96)
local hr = function() out(s, '\n') end

--https://github.com/Itseez/opencv/blob/master/modules/core/include/opencv2/core/cvdef.h
local function isnan(q)
	return bit.band(q.hi.u, 0x7fffffff) + (q.lo.u ~= 0 and 1 or 0) > 0x7ff00000
end

local function isnanf(d)
	return bit.band(d.u, 0x7fffffff) + (d.lo.u ~= 0 and 1 or 0) > 0x7ff00000
end

local function dump(rd)

	local function out_qwords(qwords)
		local fmt = '%-8s 0x%08X%08X %19s %16d %16d %19s %19s %8d %8d %8d %8d\n'
		out(_(            '%-8s %18s %19s %16s %16s %19s %19s %8s %8s %8s %8s\n',
			'name', '0x', 'd', 'dw1', 'dw0', 'd1', 'd0', 'w3', 'w2', 'w1', 'w0'))
		hr()
		for name, qword in qwords() do
			out(_(fmt, name,
				qword.hi.uval,
				qword.lo.uval,
				isnan(qword) and 'nan' or _('%19g', qword.fval),
				qword.hi.sval,
				qword.lo.sval,
				isnanf(qword.hi) and 'nan' or _('%19g', qword.hi.fval),
				isnanf(qword.lo) and 'nan' or _('%19g', qword.lo.fval),
				qword.hi.hi.sval,
				qword.hi.lo.sval,
				qword.lo.hi.sval,
				qword.lo.lo.sval))
		end
		out'\n'
	end

	local function out_dwords(dwords)
		local fmt = '%-8s 0x%08X %16d %19s %8d %8d %4d %4d %4d %4d\n'
		out(_(       '%-8s   %8s %16s %19s %8s %8s %4s %4s %4s %4s\n',
			'name', '0x', 'dw', 'f', 'w1', 'w0', 'b3', 'b2', 'b1', 'b0'))
		hr()
		for name, dword in dwords() do
			out(_(fmt, name,
				dword.u,
				dword.s,
				isnanf(dword) and 'nan' or _('%19g', dword.f),
				dword.hi.s,
				dword.lo.s,
				dword.hi.hi.s,
				dword.hi.lo.s,
				dword.lo.hi.s,
				dword.lo.lo.s))
		end
		out'\n'
	end

	local cpu_regs = x64 and {
		'RAX', 'RBX', 'RCX', 'RDX',
		'RSI', 'RDI', 'RBP', 'RSP',
		'R8', 'R9', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15',
	} or {
		'EAX', 'EBX', 'ECX', 'EDX',
		'ESI', 'EDI', 'EBP', 'ESP',
	}

	local function out_gpr(rd)
		local out_words = x64 and out_qwords or out_dwords
		out_words(function()
			local i = 0
			return function()
				i = i + 1
				if not cpu_regs[i] then return end
				return cpu_regs[i]:lower(), rd[cpu_regs[i]]
			end
		end)
	end

	local function out_xmm_d(rd)
		out_dwords(function()
			return coroutine.wrap(function()
				local n = x64 and 16 or 8
				for i=0,n do
					for j=0,3 do
						coroutine.yield('xmm'..i..'.d'..j, rd.XMM[i].dwords[j])
					end
				end
			end)
		end)
	end

	local function out_xmm_q(rd)
		out_qwords(function()
			return coroutine.wrap(function()
				local n = x64 and 16 or 8
				for i=0,n-1 do
					for j=0,1 do
						coroutine.yield('xmm'..i..'.q'..j, rd.XMM[i].qwords[j])
					end
				end
			end)
		end)
	end

	local function out_xmm(rd, q)
		if q then out_xmm_q(rd) else out_xmm_d(rd) end
	end

	local function out_stack(rd)
		local out_words = x64 and out_qwords or out_dwords
		out_words(function()
			local i = -1
			return function()
				i = i + 1
				if i >= rd.stack_size then return end
				local name = _((x64 and 'r' or 'e')..'sp+%d', tostring(i) * (x64 and 8 or 4))
				return name, x64 and rd.stack[i] or rd.stack[i].lo
			end
		end)
	end

	local function getbit(n, v)
		return bit.band(v, bit.lshift(1, n)) ~= 0
	end

	local function out_streg(rd, n, k)
		if not getbit(7-n, rd.FTWX.val) then return end
		out(_('st(%d)   ', n), _('%s    ', glue.tohex(ffi.string(rd.FPR[k].bytes, 10))),
			_('%g', cvt80to64(rd.FPR[k].bval)), '\n')
	end

	local function out_fpr(rd)
		hr()
		for i=0,7 do
			out_streg(rd, i, i)
		end
		out'\n'
	end

	local function flag_dumper(def)
		local function longdump(rd)
			out(_('%s:\n', def.title))
			hr()
			local mdfield = type(def.mdfield) == 'string' and rd[def.mdfield] or def.mdfield(rd)
			for i,name in ipairs(def.fields) do
				out(_('%-8s', name), _('%-8d', mdfield[name]), def.descr[name], '\n')
			end
			out'\n'
		end
		local function shortdump(rd)
			out(_('%-5s ', def.stitle))
			local mdfield = type(def.mdfield) == 'string' and rd[def.mdfield] or def.mdfield(rd)
			for i,name in ipairs(def.fields) do
				out(_('%-2s=%d ', name, mdfield[name]))
			end
			out'\n'
		end
		return function(rd, long)
			if long then longdump(rd) else shortdump(rd) end
		end
	end

	local out_eflags = flag_dumper(EFLAGS)
	local out_fsw    = flag_dumper(FSW)
	local out_fcw    = flag_dumper(FCW)
	local out_mxcsr  = flag_dumper(MXCSR)

	out_gpr(rd)
	out_fpr(rd)
	out_xmm(rd, x64 and 1)
	--out_stack(rd)

	out_eflags(rd)
	out_mxcsr(rd)
	out_fsw(rd)
	out_fcw(rd)
end

if not ... then
	local rd = ffi.new'RegDump'
	dump(rd)
end

return dump
