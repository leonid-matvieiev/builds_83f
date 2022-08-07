0<1# :: ^
""" Со след строки bat-код до последнего :: и тройных кавычек
@setlocal enabledelayedexpansion & py -3 -x "%~f0" %*
@(IF !ERRORLEVEL! NEQ 0 echo ERRORLEVEL !ERRORLEVEL! & timeout /t 10)
@exit /b !ERRORLEVEL! :: Со след строки py-код """

# print(dir())
ps_ = '__cached__' not in dir() or not __doc__

""" Скрипт, обновляющий дату-время изменения проекта по
  последней дате-времени модификации используемого файла
  и варианты представления версии ПО.
    Если при запуске нажать "HOME" или "SHIFT" или в параметрах
  коммандной строки будет "--dtold", то поиск последней
  даты-времени модификации файла производиться не будет.
    Если в параметрах коммандной строки будет "--waitendno",
  то 20-секундной паузы перед закрытием окна не будет.
$(MSBuildProjectDirectory)\vers_dt.bat --waitendno
post-build2.bat  $(MSBuildProjectDirectory) $(SolutionName)
"""

from fnmatch import fnmatch
import os, time, sys, re
from os.path import join, split, splitext, abspath, exists

#===============================================================================
def calc_dt_last_file():
    def fnmatch_s(f, fms):
        for fm in fms:
            if fnmatch(f, fm):
                return True
            if f.startswith(fm):
                return True
        return False

    root = split(abspath(sys.argv[0]))[0]  # '.'  #
    no_dirs = ("Debug", "Release")
    no_files = ('*.componentinfo.xml', "*.asmproj", "*.py", "*.bat", "*.png",
            r"*\as_comp_options.inc", r"*\dev_selector.inc", "vers_dt.inc")

    tmax, nmax = 0, ''
    no_dirs2 = sorted(map(lambda x: join(root, x), no_dirs))
    for p, ds, fs in os.walk(root):
        if fnmatch_s(p, no_dirs2):
            continue
        for f in fs:
            ntmp = join(p, f)
            if fnmatch_s(ntmp, list(map(lambda x: join(root, x), no_files))):
                continue
            ttmp = os.path.getmtime(ntmp)
            if tmax < ttmp:
                tmax, nmax = ttmp, ntmp
    return tmax, nmax
#-------------------------------------------------------------------------------

txt = '''\
#define  PO_CPU_VERSION  "  0.00"  ; д.б. 6 символов от "  0.00" до "655.35"
#define  PO_CPU_DT_STR   "2000.00.00 00:00"  ; д.б. 16 символов
#define  PO_CPU_DT_NUMS  0, 0, 0, 0, 0, 0, 0, 0  ; д.б. 8 байт
#define  LAST_FILE_NAME  ""
'''

#===============================================================================
def print_file_name_time(tmax, nmax):
    global txt
    fpne_inc = splitext(sys.argv[0])[0] + '.inc'
    if exists(fpne_inc):
        with open(fpne_inc, encoding='cp1251') as fp:
            txt = fp.read()

    m1 = re.search(r'\#define\s+PO_CPU_VERSION_FRAC_STR\s+"(\d+)"', txt)
    m2 = re.search(r'\#define\s+PO_CPU_VERSION_INT_NUM\s+(\d+)', txt)
    if m1: vfi1 = int(m1.group(1))
    if m2: vfi2 = int(m2.group(1))
    vfi = max(vfi1, vfi2)  # дробова частина версії (кількість сотих)
    print(end=f'vN.{vfi:02d}  ')

    if not tmax:
        m3 = re.search(r'\#define\s+PO_CPU_DT_STR\s+"([^"]+)"', txt)
        if m3:
            st = re.split(r'[- :/\t;.]', m3.group(1))
            tmax = time.mktime(tuple(map(int, st + [0,0,0,0])))

    tl = time.localtime(tmax)
    ts = time.strftime('%Y.%m.%d %H:%M', tl)
    print(f'{ts} {split(nmax)[-1]}')

    txt = re.sub(r'(\#define\s+PO_CPU_VERSION_FRAC_STR\s+)"\d+"',
                r'\1"%02d"' % vfi, txt)
    txt = re.sub(r'(\#define\s+PO_CPU_VERSION_FRAC_NUM\s+)\d+',
                r'\g<1>%s' % vfi, txt)

    txt = re.sub(r'(\#define\s+PO_CPU_DT_STR\s+)"[^"]+"', r'\1"%s"' % ts, txt)
    txt = re.sub(r'(\#define\s+PO_CPU_DT_NUMS\s+)\d+(?:,\s*\d+)+',
                r'\g<1>%s' % ", ".join(map(str, [tl[0] % 100, *tl[1:5]])), txt)
    txt = re.sub(r'(\#define\s+LAST_FILE_NAME\s+)"[^"]*"',
                r'\1"%s"' % split(nmax)[-1], txt)

    with open(fpne_inc, 'w', encoding='cp1251') as fp:
        fp.write(txt)
#-------------------------------------------------------------------------------


#===============================================================================
def main():
    try:
        import win32api
        if (win32api.GetKeyState(0x24) & 0x80 or  # < 0 HOME  Для AtStud
            win32api.GetKeyState(0x10) & 0x80 or  # < 0 SHIFT:
            '--dtold' in sys.argv[1:]):
            print_file_name_time(0, '')
            # Время будет взято из строки PO_CPU_DT_STR файла vers_dt.inc
            return
    except ModuleNotFoundError:
        pass
    print_file_name_time(*calc_dt_last_file())
#-------------------------------------------------------------------------------


#===============================================================================
if __name__ == '__main__':
    main()
    print('Ok!')
    if not (ps_ or '--waitendno' in sys.argv[1:]):
        os.system('timeout /t 20')
'''
    win32api.GetKeyState(0x12) < 0 # ALT
    win32api.GetKeyState(0x11) < 0 # CTRL
    win32api.GetKeyState(0x10) < 0 # SHIFT
    win32api.GetKeyState(0x5B) < 0 # LWIN
    win32api.GetKeyState(0x5C) < 0 # RWIN
    win32api.GetKeyState(0x24) < 0 # HOME  ???
# 0 или 1 - клавиша отжата
# (-127) или (-128) - клавиша нажата
'''
