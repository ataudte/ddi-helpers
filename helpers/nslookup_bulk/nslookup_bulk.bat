@echo off
set OUTPUTFILE=results.txt
set ERRORFILE=error.txt
set DNSSERVER=10.20.30.40
set RECORDTYPE=NS
set lookup=list-of-fqdns.txt
for /f %%i in (%lookup%) do @nslookup -querytype=%RECORDTYPE% %%i %DNSSERVER% 1>>%OUTPUTFILE% 2>>%ERRORFILE%
