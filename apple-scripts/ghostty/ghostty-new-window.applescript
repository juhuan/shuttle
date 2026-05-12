--for testing uncomment the "on run" block
--on run
--	set argsCmd to "ps aux | grep [s]sh"
--	set argsTheme to "Homebrew"
--	set argsTitle to "Custom title"
--	scriptRun(argsCmd, argsTheme, argsTitle)
--end run

on scriptRun(argsCmd, argsTheme, argsTitle)
	set withCmd to (argsCmd)
	CommandRun(withCmd)
end scriptRun

on CommandRun(withCmd)
	tell application "/Applications/Ghostty.app"
		set surfaceConfig to new surface configuration
		set newWindow to new window with configuration surfaceConfig
		set newTerminal to focused terminal of selected tab of newWindow
		input text withCmd to newTerminal
		send key "enter" to newTerminal
		focus newTerminal
	end tell
end CommandRun
