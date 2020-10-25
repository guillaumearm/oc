local colors = require('colors')
local os = require('os')
local c = require('component')

local noop = function() end

local setPal = c and c.gpu and c.gpu.setPaletteColor or noop

if not setPal then
  printError('Error: 99_color_palette.lua is unable to find the current gpu')
  os.sleep(4)
end

-- Monokai theme
setPal(colors.white, 0xF8F8F2)
setPal(colors.black, 0x272822)
setPal(colors.yellow, 0xE6DB74)
setPal(colors.pink, 0xF92672)
setPal(colors.gray, 0x75715E)
setPal(colors.silver, 0x90908A)
setPal(colors.cyan, 0x66D9EF)
setPal(colors.purple, 0xAE81FF)

-- Basic other colors
setPal(colors.green, 0x00DB00)
setPal(colors.blue, 0x0049FF)
setPal(colors.lightblue, 0x0092FF)
setPal(colors.magenta, 0xFF24FF)
setPal(colors.orange, 0xFF6D00)
setPal(colors.lime, 0x00FF80)
setPal(colors.red, 0xFF0000)
setPal(colors.brown, 0x332400)
