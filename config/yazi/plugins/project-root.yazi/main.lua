--- @sync entry
-- `leave`, unless that would go above $IDE_ROOT. Without IDE_ROOT it behaves like plain `leave`.
return {
	entry = function()
		local root = os.getenv("IDE_ROOT")
		local cwd = tostring(cx.active.current.cwd)
		if root and root ~= "" then
			root = root:gsub("/+$", "")
			if cwd == root or cwd:sub(1, #root + 1) ~= root .. "/" then
				return
			end
		end
		ya.emit("leave", {})
	end,
}
