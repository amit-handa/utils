# Migrating to Mac from Ubuntu

pros:
* fonts are amazing
* display is great.
cons:
* limited features in terms of remapping key combos. listed in Issues section. mostly, are solved/workaround.

## Issues
* issue: hate touch bar. no tactile feedback on touching `esc`
* solution: map caps lock to escape.

* issue: window vertical resize is missing
* solution: installed mjolnir. created few lua functions (./init.lua) to do the same. also, used it for moving windows horizontally.

* issue: ctrl, fn key positions are swapped
* solution: use karabiner. remap fn key to ctrl key. made life far better.

* issue: alt+p doesnt work in terminal
* background: in place of alt, there is command key. option key is equivalent to alt key, for mac. so need to do two things:
	* swap command and option keys. solution: it can be done in keyboard prefs->modifier keys-> update option, command key mappings.
	* command+p is mapped to 'print'. It cant be modified in terminal app. possible solution is to use iterm2 app but even that is complicated since apparently, cmd+p cant be remapped.
		* solution: workaround. use diff key combo to backward/forward search. found command+t/g is unmapped. so used it instead.

* terminal: used novel color scheme. a little brighter than usual.
* command line editing: ctrl+a to move to beg, +e to move to end. ctrl+u to clear till beginning, +k to clear till end. option+arrows to move wordwise left/right. option+D to delete word, forward. ctrl+W to delete word backward.

* issue: key press&hold in mac doesnt repeat the key. instead, it can be configured to type something else.
* solution: disable this behaviour. `defaults write -g ApplePressAndHoldEnabled -bool false` -> restart

* issue: migrate data from ubuntu to mac.
* solution: ssh/scp didnt work. both laptops in same network. TL/DR: install filezilla and then, copying worked.

* issue: bash autocomplete doesnt work. kubectl isnt working
* solution: bash on mac is old.
  * [upgrade it](https://medium.com/merapar/fixing-bash-autocompletion-on-macos-for-kubectl-and-kops-e87f019652e8)
  * also, install xcode, macports, compile bash and [bash-completion](https://github.com/cykerway/complete-alias)
