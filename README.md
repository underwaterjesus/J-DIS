# J-DIS
Julia Digital Image Steganography is a Julia application that uses Least Significant Bit Steganography to hide files in digital images.<br><br>
The purpose of this project is to become more familiar with the Julia programming language in a fun and interesting way, as my final year project in university will be primarily written in Julia. Because this is just a fun project to further other goals long term support is unlikely, but hopefully others find it intersesting and useful too.<br><br>
- [Overview](#overview "Overview")
- [Dependencies](#julia-package-dependencies "Julia Package Dependencies")
- [Future Versions](#future-versions--current-issues "Future Versions / Current Issues")
- [Tutorial](#how-to-use-j-dis "How To Use J-DIS")
<br><br>

## Overview
J-DIS is a steganography application capable of hiding .txt, .doc/.docx, .pdf and .zip files in .png and .jpg/.jpeg images. It does this by embedding the file data in the two least significant bits of a number of bytes in an image. The program can decode these files again, automatically determining the type of file that was originally hidden.<br><br>
J-DIS consists of only one file, which is run from the command line. It is not a Julia module and does not export any functions or macros. A tutorial on how to use J-DIS is given below.<br><br>

## Julia Package Dependencies
J-DIS uses the follwing packages:
- [Images](https://juliaimages.org/latest/ "JuliaImages")
- [FileIO](https://github.com/JuliaIO/FileIO.jl "JuliaIO/FileIO")
- [Printf](https://docs.julialang.org/en/v1/stdlib/Printf/ "Printf")
- [ArgMacros](https://github.com/zachmatson/ArgMacros.jl "ArgMacros")
- [Suppressor](https://github.com/JuliaIO/Suppressor.jl "JuliaIO/Suppressor")
<br><br>

## Future Versions / Current Issues
Currently J-DIS only works with two dimensional images. An image that is a single rowor column of pixels will crash the program. This should hopefully be rectified in the near future.<br><br>
J-DIS can only embed files in .png and .jpg/.jpeg files, and always produces a .png as output when embedding files. More image types may be supported as input/output files in the future.<br><br>

## How To Use J-DIS
**TUTORIAL AND HELPFUL SCREENSHOTS COMING VERY SOON**
