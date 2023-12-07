# rewin

rewin provides a convenient way to reference a place in your filesystem without needing to keep open a seperate window or pane.


## Features
- Mark a location: this allows you to mark the location you want to refer to. This location is then the default when you open the reference window.
- Open window: Allows you to open a floating window showing the reference location. This window is non focusable so won't interupt any other window switching.
- Enter the window: Is there an important part of the reference just out of sight? Quickly enter the window to adjust the view, then exit again.
- Close window: shortcut to closing the reference window if it is open, saves having to manually enter a command to do it.
- List marks: If you haven't set the default mark, this option will list the available ones to select from.


## Installation

Install as with any other plugin, packer for example:

<!-- setup:start -->

```lua
use "jamiedsmith95/rewin"

```

<!-- setup:end -->


## Configuration

To setup the plugin put the following into the init.lua
```lua
require("rewin").setup {
  makewin = {
  },
  floatinglist = {
  }
}


```
The main options that can be set are for the reference window itself and for the floating list.
These are optional and if not set default values are used.



Keybindings need to be set by setting the desired mapping to <Plug>makeWin for each of the functions:
```lua
map('n',"<your_binding>", "<Plug>makeWin")
map('n',"<your_binding>", "<Plug>closeWin")
map('n',"<your_binding>", "<Plug>listSelect")
map('n',"<your_binding>", "<Plug>winSwitch")
map('n',"<your_binding>", "<Plug>setBuf")
map('n',"<your_binding>", "<Plug>selectItem")

```
where 'n' represents the mode, <your_binding> represents the lhs of the mapping and <Plug>... represents the rhs. Otherwise set these however you usually set your mappings I just use map() for demonsration.
Make sure to set selectItem if you have listSelect mapped otherwise you won't be able to leave the list without closing the window.



