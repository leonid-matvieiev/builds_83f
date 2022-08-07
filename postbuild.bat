@echo off
rem  Команды Студии для вызова батников
rem  $(MSBuildProjectDirectory)\vers_dt.bat --waitendno
rem  $(MSBuildProjectDirectory)\postbuild.bat  $(OutputFileName) --waitendno
rem  echo $(MSBuildProjectDirectory) = %0
rem  echo $(SolutionName) = %1

del /Q "*.bin"
hex2bin.exe  -c "%1.hex"
CoderPC830.exe 310185 "%1.bin"

del /Q "%1.tmp"

del /Q "%1.lss"

exit /b

del /Q "%1.bin"
del /Q "%1.hex"
del /Q "%1.map"
del /Q "%1.obj"  Нужен для прошивки сразу, при помощи F5
