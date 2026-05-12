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
		if it is not running or (count windows) is 0 then
			set targetWindow to new window with configuration surfaceConfig
			set targetTerminal to focused terminal of selected tab of targetWindow
		else
			set targetWindow to front window
			set targetTab to new tab in targetWindow with configuration surfaceConfig
			set targetTerminal to focused terminal of targetTab
		end if
		input text withCmd to targetTerminal
		send key "enter" to targetTerminal
		focus targetTerminal
	end tell
end CommandRun
