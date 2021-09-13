# GIMP-Palette-to-Apple-Color-Picker
A Swift program to convert GIMP Palette Files (gpl) to Apple Color Picker (clr) files that I whipped up one afternoon.

## Purpose
Basically I had a number of palette files for GIMP that I thought would be nice to have as color library in macOS. This program will process all the files in a particular directory (in the code, it's `~/Downloads/Embroidery Color Palettes`) and write out a `.clr` file in the `/Users/<user>/Library/Colors/<Palette Name>.clr` directory.

Hope this helps someone!
