0<1# :: ^
""" Со след строки bat-код до последнего :: и тройных кавычек
@setlocal enabledelayedexpansion & py -3 -x "%~f0" %*
@(IF !ERRORLEVEL! NEQ 0 echo ERRORLEVEL !ERRORLEVEL! & timeout /t 10)
@exit /b !ERRORLEVEL! :: Со след строки py-код """

# print(dir())
ps_ = '__cached__' not in dir() or not __doc__

from time import time, strftime, localtime, gmtime
import sys, os
from os.path import getmtime, join


#===============================================================================
def main():
    t0 = getmtime('times.txt')
    t1 = time()
    dt = t1 - t0
    s = (f"time used "
         f"{strftime('%M:%S', gmtime(int(dt)))}{str(dt - int(dt))[1:5]} = "
         f"{strftime('%H:%M:%S', localtime(t1))} - "
         f"{strftime('%H:%M:%S %d.%m.%Y', localtime(t0))}")
    print(s)
    with open(join(sys.argv[1], 'times.txt'), 'a') as fx:
        fx.write(s)
#-------------------------------------------------------------------------------


#===============================================================================
if __name__ == '__main__':
    main()
    if not (ps_ or '--waitendno' in sys.argv[1:]):
        os.system('timeout /t 20')
