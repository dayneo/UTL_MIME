@ECHO off

set srcdir=%~dp0source
set builddir=%~dp0build
set scriptname=utmime.sql

mkdir "%builddir%"

type "%srcdir%\UTL_MIME.pks"     >  "%builddir%\%scriptname%"
ECHO.                            >> "%builddir%\%scriptname%"
type "%srcdir%\UTL_MIME.pkb"     >> "%builddir%\%scriptname%"
ECHO.                            >> "%builddir%\%scriptname%"
