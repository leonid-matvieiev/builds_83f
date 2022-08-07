0<1# :: ^
""" Со след строки bat-код до последнего :: и тройных кавычек
@setlocal enabledelayedexpansion & py -3 -x "%~f0" %*
@(IF !ERRORLEVEL! NEQ 0 echo ERRORLEVEL !ERRORLEVEL! & pause)
@exit /b !ERRORLEVEL! :: Со след строки py-код """

# print(dir())
ps_ = '__cached__' not in dir() or not __doc__

import re, os, sys, time
from time import localtime, sleep, strftime
from pathlib import Path


# ============================================================================
def print_name_min(p):
    parts = p.parts
    for i, part in reversed(list(enumerate(parts))):
        if part == '_PCSapr':
            break
    else:
        i = -1
    if i < 0:
        print(p)
    else:
        print('/'.join(parts[i - 1:]))


# ============================================================================
def normalise(arg):

    if not arg.exists():
        print(arg)
        print("    ? Не існує")
        return

    print_name_min(arg)
    ps = []
    if arg.is_file():
        if (arg.name != 'designer_Types.asm' and
            arg.name != 'designer_ConstsLCD.asm'):
            print("    ? Ім'я файлу не для нормалізації")
            return
        print("    Ім'я файлу для нормалізації")
        ps = [arg]
    elif arg.is_dir():
        ps = [*arg.rglob('designer_Types.asm'),
              *arg.rglob('designer_ConstsLCD.asm')]
        if not ps:
            print("    ? В теці файли для нормалізації не знайдені")
            return
        print("    Ім'я теки для нормалізації")
    else:
        print("    ? Має бути файл або тека")
        return

    for p in ps:
        print_name_min(p)

        txt = p.read_text('cp1251')

        if p.name == 'designer_Types.asm':
            frags = list(filter(len, re.split(
                r'(?ms)(^;-{20,}.+?\n{2,}(?=^;-{20,}|^;={20,}))', txt)))
            frags[1:-1] = sorted(frags[1:-1])

        elif p.name == 'designer_ConstsLCD.asm':
            frags = re.split(r'(?m)(^;={20,}\n)', txt)
            ss = frags[4].splitlines()
            frags[4] = '\n'.join(ss[:2] + sorted(ss[2:])) + '\n'

        txt2 = ''.join(frags)
        if txt == txt2:
            print(f"    Нормалізація не змінює файл")
        else:
#            p2 = Path(p.with_name(p.name + '.bak'))
#            p.rename(p2)
            p.write_text(txt2, 'cp1251')
            print(f"    Нормалізовано")
#-------------------------------------------------------------------------------

# ============================================================================
def main():

    print('Файли які м.б. нормалізовані:\n'
        '    "designer_Types.asm" або "designer_ConstsLCD.asm"')

    args = sys.argv[1:]
    if not args:
        args = [Path(sys.argv[0]).parent]

    for arg in args:
        normalise(Path(arg))
#-------------------------------------------------------------------------------

# ============================================================================
if __name__ == '__main__':

    main()

    if not (ps_ or '--waitendno' in sys.argv):
        os.system('timeout /t 60')
# ----------------------------------------------------------------------------
