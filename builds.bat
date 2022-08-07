0<1# :: ^
""" Со след строки bat-код до последнего :: и тройных кавычек
@setlocal enabledelayedexpansion & py -3 -x "%~f0" %*
@(IF !ERRORLEVEL! NEQ 0 echo ERRORLEVEL !ERRORLEVEL! & pause)
@exit /b !ERRORLEVEL! :: Со след строки py-код """

# print(dir())
ps_ = '__cached__' not in dir() or not __doc__

""" Скрипт для автоматизации создания прошивок
  Скрипт обновляет дату-время изменения проекта по
  последней дате-времени модификации используемого файла
  и варианты представления версии ПО
"""
#  Команды Студии для вызова батников
#  $(MSBuildProjectDirectory)\vers_dt.bat --waitendno
#  $(MSBuildProjectDirectory)\postbuild.bat  $(OutputFileName) --waitendno

import zlib  # crc = '%08X' % zlib.crc32(txt.encode('utf8'))
import os, sys, shlex, subprocess, time, re
from os.path import exists, join, split, splitext, abspath
from glob import glob
# from multiprocessing import Pool
from multiprocessing.dummy import Pool
import win32clipboard as clip
from pprint import pprint
from pathlib import Path


incs = glob(r'C:\Program Files*\Atmel\Studio\7.0\packs'
            r'\atmel\ATmega_DFP\*\avrasm\inc\m2561def.inc')
if not incs:
    print('Файл "m2561def.inc" не знайдений')
    time.sleep(10)
    exit()
FINC = max(incs)
FEXE = join(FINC.split('packs')[0],
            r'toolchain\avr8\avrassembler\avrasm2.exe')
if not exists(FEXE):
    print('Файл "avrasm2.exe" не знайдений')
    time.sleep(10)
    exit()

# Имя общей папки проекта для архивов и др.
subdir_loc_out_prj = r'PC8xn-PR9'
HISTOR_FNE_MASK = '*CPU_PR9_v?_KBU_история.txt'
HISTOR_FNE_NAME = 'CPU_PR9_v0_KBU_история.txt'
arx_fmt1 = '.zip'
arx_fmt2 = '.7z'
dir_loc_in = 'Debug'
dir_bins = r'..\bins'
rar_exe = r'D:\Portables\WinRAR\App\WinRAR\WinRAR.exe'
z7_exe = r'"C:\Program Files\7-Zip\7z.exe"'
dir_net_83H_soft = None
dir_net_83H_arx = None
bins = []
fn_dev_pat2 = ''
ds = ''

fpn_vers_dt = "vers_dt"
fe_vers_dt = ".inc"
fpne_vers_dt = fpn_vers_dt + fe_vers_dt

mapping = {  # 'HTP'
    'PC83AB3': 'HTP_B02',
    'PC83B3':  'HTP_H02',
    'PC83BC3': 'HTP_B03',
    'PC83A3':  'HTP_B01',
    'PC83C3':  'HTP_H0X',
}

#===============================================================================
def get_kinds_params():
    global kinds, params
    fp0 = Path(sys.argv[0]).parent / 'Devices'
    aizdi = {fp.parent.relative_to(fp0).parts[0]
            for fp in fp0.rglob('designer_MapROM.inc') if re.search(
                r' *\.equ MapROM_vrIOAI_RX_BData_DI_OffsetIX = 0x000[^0] ;',
                fp.read_text(encoding='cp1251'))}
    ts = sorted({fp.parent.relative_to(fp0).parts[::2]
                    for fp in fp0.rglob('designer_Types.asm')} &
                {fp.parent.relative_to(fp0).parts[::2]
                    for fp in fp0.rglob('designer_ConstsLCD.asm')} &
                {fp.parent.relative_to(fp0).parts[::2]
                    for fp in fp0.rglob('designer_MenuWimdowFunctions.asm')})
    params = {}
    for t0, t1 in ts:
        if t1.upper() in ('NTR', 'HTP'):
            fold = mapping[t0[:-2]] + t0[-2:]
            name = fold
        else:
            fold = f'83_{t0[4:]}'
            name = f'{fold}_{t1}'
        params[name] = (fold, t0[2:], f'MENU_{t1}', name)
        if t0 in aizdi:
            params[name + '_ADI'] = (fold, t0[2:], f'MENU_{t1}', 'AI_DI_USE', name)
    kinds = sorted(params)
#-------------------------------------------------------------------------------
get_kinds_params()
'''
pprint(params)
a=5
{'83_A3F1_RU': ('83_A3F1', '83A3F1', 'MENU_RU', '83_A3F1_RU'),
 '83_A3F1_RU_ADI': ('83_A3F1', '83A3F1', 'MENU_RU', 'AI_DI_USE', '83_A3F1_RU'),
 '83_AB3F1_RU': ('83_AB3F1', '83AB3F1', 'MENU_RU', '83_AB3F1_RU'),
 '83_AB3F1_UA': ('83_AB3F1', '83AB3F1', 'MENU_UA', '83_AB3F1_UA'),
 '83_B3F1_RU': ('83_B3F1', '83B3F1', 'MENU_RU', '83_B3F1_RU'),
 '83_B3F1_RU_ADI': ('83_B3F1', '83B3F1', 'MENU_RU', 'AI_DI_USE', '83_B3F1_RU'),
 '83_BC3F1_RU': ('83_BC3F1', '83BC3F1', 'MENU_RU', '83_BC3F1_RU'),
 '83_C3F1_RU': ('83_C3F1', '83C3F1', 'MENU_RU', '83_C3F1_RU')}
[0] - фрагмент імені папки на сервері
[1:-1] - параметри компіляції
[-1] - фрагмент імені файла до версії (з мовою, якщо 83)
'''

#===============================================================================
def build(dev):
    if dev in params:
        print(f'build({dev})')  # \n
    else:
        mess = f'build({dev}) не передбачено'
        print(mess)  # \n
        return mess

    fpn_in = join(dir_loc_in, dev)
    fpne_coded = f'{fpn_in}_CODED.bin'

    # Очистить папку "Debug" от предыд результатов компиляции
    if exists(dir_loc_in):
        oss('del', f"{fpn_in}*.*")  #* Повернути назад
# os.remove(s) f.unlink() 000 and

    dir_loc_out_dev = join(dir_loc_out_prj, 'Releases-' + dev)

    # Папки проекта для ус-в
    if not exists(dir_loc_out_dev):
        os.makedirs(dir_loc_out_dev)
    if flag_net_use:
        dir_net_83H_dev = join(dir_net_83H_soft, 'Прошивки_CPU_' + params[dev][0])
        if not exists(join(dir_net_83H_dev, 'bins_old')):
            os.makedirs(join(dir_net_83H_dev, 'bins_old'))
        if not exists(join(dir_net_83H_dev, 'maps')):
            os.makedirs(join(dir_net_83H_dev, 'maps'))

    defs = '-D DEF_' + ' -D DEF_'.join(params[dev][1:-1])
    cle = clpf.format(dev, defs)
    cal = subprocess.Popen(shlex.split(cle), stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT)
    result = cal.communicate()[0]
#    print(result.decode('cp1251'))

    # Проверить наличия результирующих файлов
    if not (exists(f"{fpn_in}.hex")
#        and exists(fpne_coded)
        and exists(f"{fpn_in}.map")):
        mess = ('Немає всіх необхідних файлів\n'
            f'    {dev}.hex и {dev}.map')
        print(mess)
        fpne_nohex = f'{fpn_in}_bad.txt'
        with open(fpne_nohex, 'wb') as fp:
            fp.write(bytes(re.sub(r'\s+', ' ', cle), encoding='cp1251') + b'\r\n' + result)
        os.system(f'start {fpne_nohex}')
        return mess

    # Получение бинарника
    kv = os.system(f'hex2bin.exe -c {fpn_in}.hex')
    mess = f'{dev}: {("", "Не ")[kv and 1]}Створено файл {fpn_in}.bin'
    print(mess)
    if kv or not exists(f"{fpn_in}.bin"):
        return kv or mess
    # Шифрование бинарника
    kv = os.system(f'CoderPC830.exe 310185 {fpn_in}.bin')
    mess = f'{dev}: {("", "Не ")[kv and 1]}Створено файл {fpn_in}_CODED.bin'
    print(mess)
    if kv or not exists(f"{fpn_in}_CODED.bin"):
        return kv or mess
    # Удаление ненужного бинарника
    oss('del', fpn_in + ".bin")

    # Считывание нового шифрованного BIN-файла и рассчёт контр суммы
    with open(fpne_coded, 'rb') as fp:
        new_bin = bytearray(fp.read())
        crc = '%08X' % zlib.crc32(new_bin)
    print(f'Зчитано файл {fpne_coded}, вирахувано його CRC')

    # Предыдущие версии BIN-файлов
##    flag_idnt_bin = False
    flag_new_bin = True
    fpne_olds = sorted(glob(join(dir_loc_out_dev, '*CPU_*_v*.bin')))

    # Считывание старых шифрованных BIN-файлов и сверка с имеющимся
    for fpne_old in reversed(fpne_olds):
        with open(fpne_old, 'rb') as fp:
            old_bin = fp.read()
        if (new_bin[:0x300] == old_bin[:0x300] and
            # Проп дату-время-версию байтами и строкой до имени после тбл
            new_bin[0x330:] == old_bin[0x330:]):     # 8 + 20 + 20
            flag_new_bin = False
            break

    verN = (new_bin[0x306] ^ 0xD2) * 256 + (new_bin[0x307] ^ 0xE9)
    vers = f'{verN // 100}_{verN % 100:02d}'
    fn_out = fn_dev_pat2 % (params[dev][-1], vers, dt2)
    fne_bin_out = fn_out + f'_{crc}.bin'  # Для нов бін і маск Стар бінс
    fne_bin_msk = fn_dev_pat2 % (params[dev][-1], f'{verN // 100}_*', '*_*.bin')

    # Для истории
    if flag_new_bin:
        bins.append(f'{fne_bin_out}')
    else:
        fne_old = split(fpne_old)[-1]
        bins.append(f'= {fne_old}')

    if 'p' in ds:
        return 0

    if not flag_new_bin:
        # Знайдено аналогічний бінарник
        if 'b' not in ds:
            tmp = join(dir_bins, split(fpne_old)[-1])
            oss('move', fpne_coded, tmp)

        # Копирование совпавшего шифрованного бинарника в сетевую папку, но он там д.б.
        if flag_net_use:
            oss('copy', fpne_old, dir_net_83H_dev)
        # В локальной он уже есть и уже пригодился
        oss('del', f"{fpn_in}.*")
    else:
        # аналогічного бінарника не Знайдено
        # Переименование, копирование hex, map, шифрованного bin файлов
        # HEX-файл в локальную папку
        oss('move', f'{fpn_in}.hex', f'{join(dir_loc_out_dev, fn_out)}.hex')
        # MAP-файл в локальную и сетевую папку
        if flag_net_use:
            oss('copy', f'{fpn_in}.map', f'{join(dir_net_83H_dev, "maps", fn_out)}.map')
#        oss('copy', f'{fpn_in}.map', f'{join(dir_bins, fn_out)}.map')
        oss('move', f'{fpn_in}.map', f'{join(dir_loc_out_dev, fn_out)}.map')

        #-----------------------------------------------------------------------
        # Шифрованный бинарник в сетевую папку и локальную
        if flag_net_use:
            # Резервирование старых шифрованных бинарников в сетевую папку bins_old
            # по правильній масці (без VДТCRC), коли точно є новий
            oss('move', join(dir_net_83H_dev, fne_bin_msk),
                        join(dir_net_83H_dev, 'bins_old'))
            oss('copy', fpne_coded, join(dir_net_83H_dev, fne_bin_out))
        if 'b' not in ds:
            oss('copy', fpne_coded, join(dir_bins, fne_bin_out))
        oss('move', fpne_coded, join(dir_loc_out_dev, fne_bin_out))

        # Оставляем только 5 последних комплектов файлов, остальные удаляем
        fpne_olds = sorted(glob(join(dir_loc_out_dev, '*CPU_*_v*.bin')))
        osts = [split(fpne)[-1].rsplit('_', 1)[0]  for fpne in fpne_olds[-5:]]
        for fpne in glob(join(dir_loc_out_dev, '*CPU_*_v*.*')):
            for ost in osts:
                if split(fpne)[-1].startswith(ost):
                    break  # Этого не трогаем, такое начало есть среди нужных
            else:
                oss('del', fpne)  # Этого удаляем, его начала нет среди нужных
    return 0
#-------------------------------------------------------------------------------

#===============================================================================
def oss(scom, src, dst=''):
    b, c = split(src)
    a, b = split(b)
    if scom == "del":
        p = f'{scom} {join(b, c)}'
        cmd = f'{scom} /Q "{src}"'
    elif scom == "rmdir":
        p = f'{scom} {join(b, c)}'
        cmd = f'{scom} /Q /S "{src}"'
    else:
        d, e = split(dst)
        a, d = split(d)
        p = f'{scom} {join(b, c)}\n=> {join(d, e)}'
        cmd = f'{scom} /Y "{src}" "{dst}"'
    k = os.system(cmd)
#    print(cmd)
    print(f'{("True", "False")[bool(k)]} <= {p}')
    return k
#-------------------------------------------------------------------------------


#===============================================================================
def sum_ist(ist_loc: str, ist_net: str) -> str:
    # Деление историй на уникальные блоки (при совп, остаётся первый)
    loc_drecs = {}
    for rec in filter(None, ist_loc.split('\n\n')):
        srec = re.sub(r'\s+', '', rec).lower()
        if srec not in loc_drecs:  # or len(loc_drecs[srec]) > len(rec):
            loc_drecs[srec] = rec
    net_drecs = {}
    for rec in filter(None, ist_loc.split('\n\n')):
        srec = re.sub(r'\s+', '', rec).lower()
        if srec not in net_drecs:  # or len(net_drecs[srec]) > len(rec):
            net_drecs[srec] = rec

    # Индексация общих блоков
    loc_srecs, loc_recs = zip(*loc_drecs.items())
    net_srecs, net_recs = zip(*net_drecs.items())
    inds = sorted((loc_srecs.index(srec), net_srecs.index(srec))
                        for srec in set(loc_srecs) & set(net_srecs))

    # Грубо деление на одинарные (совпадающие) и двойные блоки
    blocks = []
    i0, j0 = 0, 0
    for i, j in inds:
        if i - i0 == j - j0 == 0:
            if blocks:
                # дополнение/продолжение последнего одинарного
                blocks[-1][0].append(net_recs[i])
            else:
                # Создание первого одинарного с 1-й записью
                blocks.append([[net_recs[i]]])
        else:
            # Создание очередного двойного и одинарного с 1-й записью
            blocks.append([loc_recs[i0:i], net_recs[j0:j]])
            blocks.append([[net_recs[i]]])
            com_flag = 1
        i0, j0 = i + 1, j + 1
    if not (len(loc_recs) - i0 == len(net_recs) - j0 == 0):
        # Создание последнего двойного
        blocks.append([loc_recs[i0:], net_recs[j0:]])

    # соединение блоков с Обработкой двойных блоков (превращение в одинарные)
    rez = []
    for i, block in enumerate(blocks):
        if len(block) == 1:
            rez += block[0]
            continue
        if not block[0] or not block[1]:  # простая
            rez += block[0] + block[1]
            continue
        rez += sum_ist2(block)  # посложнее
    return '\n\n'.join(rez)
#-------------------------------------------------------------------------------


#===============================================================================
def sum_ist2(block):
    # Обработка двойного блокa c непустыми субблоками
    outs = [[], []]
    dtvms = [set(), set()]
    for i in range(2):
        for rec in block[i]:
            dtvs = re.findall(r'(?:FW_)?CPU_\w+_v(\d+_\d+)_(?:KBU_)?([^_]+)_([^_]+)_', rec)
            if dtvs:
                dtvm = max((d, ''.join(filter(str.isdigit, t)), v) for v, d, t in dtvs)
                if outs[i] and not outs[i][-1][1]:
                    # с НЕ пустой dtvm надо подвязывать к
                    # Предыдущей с пустой dtvm, давая свою dtvm
                    outs[i][-1][0] += '\n' + rec
                    outs[i][-1][1] = dtvm
                else:  # иначе, создавать с НЕ пустой dtvm
                    outs[i].append((rec, dtvm))
                dtvms[i].add(dtvm)
            else:
                if outs[i]:
                    # с пустой dtvm надо подвязывать к
                    # Предыдущим с пустой или НЕ пустой dtvm
                    outs[i][-1][0] += '\n' + rec
                else:
                    # если Предыдущих нет, создавать первый с пустой dtvm
                    outs[i].append((rec, ()))

    # К сетевой версии добавляем отсутствующие (по макс времени) локальные блоки
    dtvms = dtvms[0] & dtvms[1]  # совпадающие dtvm
    while outs[0]:  # Перебор локальных блоков удаляя
        rec0, dtvm0 = outs[0].pop()
        if dtvm0 in dtvms:
            continue  # При совпадении dtvm оставляем сетевую версию
        for i, (rec1, dtvm1) in reversed(enumerate(outs[1])):
            if dtvm1 > dtvm0:
                # если перебираемое время больше вставляемого, вставляем после
                outs[1].insert(i + 1, (rec0, dtvm0))
                break
        else:
            # если перебираемые времена меньше вставляемого, вставляем перед
            outs[1].insert(0, (rec0, dtvm0))

    return outs[1]
#-------------------------------------------------------------------------------

#===============================================================================
def file_vers_dt_get():
    print(f'Зчитування версії і дати-часу проекту з "{fpne_vers_dt}"')
    with open(fpne_vers_dt, encoding='cp1251') as fx:
        txt = fx.read()

    m1 = re.search(r'\#define\s+PO_CPU_VERSION_FRAC_STR\s+"(\d+)"', txt)
    m2 = re.search(r'\#define\s+PO_CPU_VERSION_INT_NUM\s+(\d+)', txt)
    if m1: vfi1 = int(m1.group(1))
    if m2: vfi2 = int(m2.group(1))
    vfi = max(vfi1, vfi2)  # дробова частина версії (кількість сотих)

    dt = re.search(r'\#define\s+PO_CPU_DT_STR\s+"([^"]+)"', txt).group(1)
    Lfn = re.search(r'\#define\s+LAST_FILE_NAME\s+"([^"]*)"', txt).group(1)
    return vfi, dt, Lfn
#-------------------------------------------------------------------------------

#===============================================================================
def file_vers_dt_set(vfi, dtf):
    with open(fpne_vers_dt, encoding='cp1251') as fp:
        txt = fp.read()

    txt = re.sub(r'(\#define\s+PO_CPU_VERSION_FRAC_STR\s+)"\d+"',
                r'\1"%02d"' % vfi, txt)
    txt = re.sub(r'(\#define\s+PO_CPU_VERSION_FRAC_NUM\s+)\d+',
                r'\g<1>%s' % vfi, txt)

    txt = re.sub(r'(\#define\s+PO_CPU_DT_STR\s+)"[^"]+"', r'\1"%s"' % dtf, txt)
    with open(fpne_vers_dt, 'w', encoding='cp1251') as fp:
        fp.write(txt)
#-------------------------------------------------------------------------------


#===============================================================================
def copy_adv2_to_hoard():
    with open(fpne_macro2) as fx:
        m = re.search(r'\bmacro_mnem_adv[23].inc\b', fx.read(100))
    if not m:
        print('? В файлі немає імені macro_mnem_adv[23].inc')
        return
    oss('copy', fpne_macro2, join(split(fpne_macro3)[0], m.group(0)))
#-------------------------------------------------------------------------------


# ============================================================================
def print_name_min(p):
    parts = p.parts
    for i, part in reversed(list(enumerate(parts))):
        if part == '_PCSapr':
            print('/'.join(parts[i - 1:]))
            break
    else:
        print(p)
#-------------------------------------------------------------------------------


# ============================================================================
def normalise():

    arg = Path(sys.argv[0]).parent
    print_name_min(arg)
    ps = [*arg.rglob('designer_Types.asm'),
          *arg.rglob('designer_ConstsLCD.asm')]
    if not ps:
        print("    ? В теці файли для нормалізації не знайдені")
        return

    ns = []
    for p in ps:
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
        if txt != txt2:
#            p2 = Path(p.with_name(p.name + '.bak'))
#            p.rename(p2)
            p.write_text(txt2, 'cp1251')
            ns.append(p)

    print(f"    ! Нормалізовано {len(ns)} з {len(ps)} файлів")
    for p in ns:
        print_name_min(p)
#-------------------------------------------------------------------------------

FILE_THREADS_NUMBER = 10
fpne_macro2 = r'common_asm_lib\macro_mnem_adv2.inc'
fpne_macro3 = r'..\..\hoard\macro_mnem_adv\macro_mnem_adv3.inc'


#===============================================================================
def main():
    global dir_net_83H_soft, dir_net_83H_arx, fn_dev_pat2, dt2
    global clpf, flag_net_use, dir_loc_out_prj, ds

    normalise()

    file_vers_dt_old = file_vers_dt_get()
    print(f'vN.%s  %s  %s' % file_vers_dt_old[:3])
    print(f'Формування нового файлу "{fpne_vers_dt}" з версією і датою-часом проекту')
    cle = f'call {fpn_vers_dt}.bat --waitendno'
    kv = os.system(cle)
    # Проверка ДТ результирующего файла
    if time.time() - os.path.getmtime(fpne_vers_dt) > 5:
        print(f'? Файл {fpne_vers_dt} створено давно')
        return

    print('    Вибір пристрою для обробки')
    print('\n'.join('%s - %s' % t for t in enumerate(kinds, 1)))
    print(' m - без багатозадачності\n'
          ' v - без повідомлення усім у Вайбер\n'
          ' M - макро 2\n'
          ' r - без релизної опції\n'
          ' b - без бінарників в архіві\n'
          ' p - тільки перевірка ідентичності\n'
          ' C - з компіляцією\n'
          ' N - з мережевими операціями\n'
          ' D - диф архів, якщо без комп або з комп але і != 0\n'
          ' A - альтернативні шляхи\n'
          ' t - не змінювати версію-дату-час у файлі\n'
          ' V - інкремент номеру версії, якщо не "t"\n'
          '     В історії п.б. актуальний опис'
          )
    print('  ПЕРЕВІРИТИ/ПІДКОРЕГУВАТИ ІСТОРІЮ ДО АКТУАЛЬНОСТІ !!!')
    if len(sys.argv) > 1:
        ds = sys.argv[1]
        print("Параметри роботи: ")
    else:
        pass
        ds = input("Введіть параметри роботи: ")
#    ds = '1NCAM'       # для отладки
#    ds = '123NCAM'     # для отладки
#    ds = 'MAm5CN'      # для отладки
#    ds = '123456CNMA'  # для отладки
    print(ds)
    kind_nums = {*map(str, range(1, 1 + len(kinds)))}
    #---------------------------------------------------------------------------
    badsym = set(ds) - set("ACNMmvrpDVtb \t/") - kind_nums
    if badsym:
        print(f'?    Недопустимі символи "{"".join(badsym)}" параметрів')
        return
    devs = [kinds[int(d) - 1] for d in sorted(set(ds) & kind_nums)]

    flag_no_compile = not devs or 'C' not in ds
    flag_net_use = devs and 'N' in ds or False
    flag_pool_use = 'm' not in ds
    flag_dif_arx = 'D' in ds
    if 0 and 'r' in ds:   # не релиз
        clpf = '"%s" -fI -o Debug/{0}.hex -m Debug/{0}.map \
                -W+ie -i "%s" -D DEF_CLI {1} \
                main.asm' % (FEXE, FINC)  # -l Debug/{0}.lss
    else:   # релиз
        clpf = '"%s" -fI -o Debug/{0}.hex -m Debug/{0}.map \
                -W+ie -i "%s" -D DEF_CLI {1} -D DEF_HERE_IS_RELEASE \
                main.asm' % (FEXE, FINC)  # -l Debug/{0}.lss
    #---------------------------------------------------------------------------
    print(f'Визначення даты-часу проекту і формування "{fpne_vers_dt}"')
    file_vers_dt_cur = file_vers_dt_get()
    vfi, dt = file_vers_dt_cur[:2]
    if set(ds) & set('tV'):  # Необходимость внесения изменений в файл до компиляции
        if 't' in ds:
            dt = file_vers_dt_old[1]  # версия-дата-время в файле старые
            file_ = file_vers_dt_old[2]
            # версия-дата-время для имя архива текущие
        elif 'V' in ds:
            vfi += 1
            # дата-время текущие, версия +1 в файле и в имя архива
            file_ = file_vers_dt_cur[2]
        file_vers_dt_set(vfi, dt)
        print(f'vN.%02d  %s  %s' % (vfi, dt, file_))
    else:
        print(f'vN.%02d  %s  %s' % file_vers_dt_cur[:3])

    dt2 = dt.strip().replace(".","-").replace(" ","_").replace(":","")
    fn_dev_pat2 = f'CPU_%s_v%s_%s'

    if 'A' in ds:  #  0 or 0 and
        dir_loc_out = r'D:\Builds_d'   # Имя всеобщей папки
    else:
        dir_loc_out = r'D:\Builds'   # Имя всеобщей папки
    dir_loc_out_prj = join(dir_loc_out, subdir_loc_out_prj)
#
    if flag_net_use:
        print('Знаходження доступних мережевих шляхів')
        if 'A' in ds:
            SERV_ADR = dir_loc_out
        else:
            for SERV_ADR in (r'\\192.168.100.102', r'\\Ws_kbu'):
                if exists('\\'.join((SERV_ADR, 'kbu'))):
                    break
            else:
                print(f'Нмає "KBU"')
                return
        dir_net_83H_soft = '\\'.join((SERV_ADR, r'kbu\PC83H\Soft'))
        dir_net_83H_arx = '\\'.join((SERV_ADR, r'ArcProjects\Matveev\PC83H'))
        if 'A' in ds:
            if not exists(dir_net_83H_soft):
                os.makedirs(dir_net_83H_soft)
            if not exists(dir_net_83H_arx):
                os.makedirs(dir_net_83H_arx)

    tbegin = time.perf_counter()

    if not flag_no_compile:

        if 'M' not in ds and exists(fpne_macro3):
            copy_adv2_to_hoard()
            oss('copy', fpne_macro3, fpne_macro2)

        if exists(dir_bins):
            os.system(f'rd /q /s {dir_bins} >nul')
        os.makedirs(dir_bins)

        print('    Вибрано створення прошивок для пристроїв:')
        print('\n'.join(devs))

        print('    Чекайте, тривала операція ...')

#
#
#
#
#
#
#
#
#
#
#
#

        # flag_pool_use - с мультипроцессингом
        if not flag_pool_use:
            rezs = list(map(build, devs))
        else:
            pool = Pool(FILE_THREADS_NUMBER)
            rezs = pool.map(build, devs)
        #    rezs = pool.map_async(build, devs).get()
            pool.close()
            pool.join()  # Очікування заверш build_runs, для роботы в фоні

        # Проверка нормальности компиляций и выход с сообщением
        if any(rezs):
            [rez and print(rez) for rez in rezs]
            print("Не все Ок, Розбирайся")
            return
        print("Компіляції завершені без явних помилок")

    if 'p' in ds:
        dt = time.perf_counter() - tbegin
        print(f'\nЧас роботи {dt:0.3f} сек '
            f'({time.strftime("%M:%S", time.localtime(dt))})\n')
        print(f'Доповнення в історію\n{chr(10).join(bins)}\n')
        return

    # Поиск и загрузка локальной истории
    ist_loc_fpnes = glob(join('..', HISTOR_FNE_MASK))
    if ist_loc_fpnes:
        ist_loc_fpne = ist_loc_fpnes[0]
        with open(ist_loc_fpne, 'r', encoding='cp1251') as fp:
            ist_loc = fp.read()  # lines

    if not flag_net_use:
        ist_net_fpnes = []
        ist_net = ''
    elif ist_loc_fpnes:
        # Поиск и загрузка соответствующей сетевой истории
        ist_net_fpnes = glob(join(dir_net_83H_soft, split(ist_loc_fpne)[-1]))
        if ist_net_fpnes:
            ist_net_fpne = ist_net_fpnes[0]
            with open(ist_net_fpne, 'r', encoding='cp1251') as fp:
                ist_net = fp.read()
    else:
        # Поиск и загрузка сетевой истории, первой попавшейся
        ist_net_fpnes = glob(join(dir_net_83H_soft, HISTOR_FNE_MASK))
        if ist_net_fpnes:
            ist_net_fpne = ist_net_fpnes[0]
            with open(ist_net_fpne, 'r', encoding='cp1251') as fp:
                ist_net = fp.read()

    # Выбор истории из существующих
    if not ist_net_fpnes and not ist_loc_fpnes:
        ist_loc_fpne = join('..', HISTOR_FNE_NAME)
        if flag_net_use:
            ist_net_fpne = join(dir_net_83H_soft, HISTOR_FNE_NAME)
        ist = ''
    elif not ist_net_fpnes:
        if flag_net_use:
            ist_net_fpne = join(dir_net_83H_soft, split(ist_loc_fpne)[-1])
        ist = ist_loc
    elif not ist_loc_fpnes:
        ist_loc_fpne = join('..', split(ist_net_fpne)[-1])
        ist = ist_net
    else:
        ist_loc_fpne = join('..', split(ist_loc_fpne)[-1])
        ist = sum_ist(ist_loc, ist_net)

    dir_loc_out_arx = join(dir_loc_out_prj, 'Sources')
    # Папки проекта для исходников
    if not exists(dir_loc_out_arx):
        os.makedirs(dir_loc_out_arx)

    # Новое полное имя архива
    prj_fold = split(split(abspath(os.curdir))[0])[-1][2:]
    fn_arx = f'CPU_{prj_fold}_vN_{vfi:02d}_{dt2}'
    for i in range(flag_dif_arx, 1000):
        fne_arx2 = f'{fn_arx}_{i}{arx_fmt2}'
        fpne_loc_out_arx = join(dir_loc_out_arx, fne_arx2)
        if not exists(fpne_loc_out_arx):
            break
    else:
        fne_arx2 = None
        print('Не мажливо підібрати імя архіву')
        return

    if flag_net_use:
        fpne_net_83H_arx = join(dir_net_83H_arx, fne_arx2)

    if fne_arx2 is None:
        return
    # Дополнение истории в папках: локальной, сервера и в Билд/Проект
    if not bins:
        ist_add = f'{fne_arx2}\n'
    else:
        ist_add = f'{fne_arx2}\n{chr(10).join(bins)}\n'
    ist = ist_add + ist
    print(end=f'Доповнення в історію\n{ist_add}')

    with open(ist_loc_fpne, 'w', encoding='cp1251') as fp:
        fp.write(ist)
    if flag_net_use:
        os.system(f'attrib -R "{ist_net_fpne}"')
        oss('copy', ist_loc_fpne, dir_net_83H_soft)
        os.system(f'attrib +R "{ist_net_fpne}"')
    oss('copy', ist_loc_fpne, dir_loc_out_prj)
    print(f'Історія доповнена і скопійована, створення архіву')

    # архивация
    arx_tmp1 = fr"..\tmp{arx_fmt1}"
    # oss('del', arx_tmp1)

    var_arx = "-ai"
    if flag_dif_arx:
        if flag_no_compile:
            var_arx = "-ao"
        elif i:
            var_arx = "-ao"
    # -ai	Игнорировать файловые атрибуты
    # -ao	Добавить файлы с установленным атрибутом "Архивный"
    rarcom = (f'{rar_exe} a -ep1 -ed -ac '
              f'-x{abspath("Debug")} -x{abspath("Debug_")} '
              f'{var_arx} {arx_tmp1} {abspath(".")} "..\\*.atsln" '
              f'"{join("..", HISTOR_FNE_MASK)}"%s' %
              (exists(dir_bins) and f' "{dir_bins}"' or ''))
#    print(rarcom)
    kv = os.system(rarcom)

    # Ожидание архива на всяк случай
    for i in range(3):
        time.sleep(1.0)
        if exists(arx_tmp1):
            print(f'Створено архів "{arx_tmp1}"')
            break
    else:
        input(f'Архів "{arx_tmp1}" не створено. Жми "Enter" ...')
        if not exists(arx_tmp1): return

    # Размер архива 1
    os.system(f'for %1 in ("{arx_tmp1}") do @echo Размір ZIP-архіву %~z1 байт')

    print("Створення каталогу для перепаковки архіву")
    if exists(dir_bins):
        os.system(f'rd /q /s {dir_bins} >nul')
        for i in range(10):
            if not exists(dir_bins):
                break
            time.sleep(0.5)
    os.makedirs(dir_bins)
    os.system(f'{z7_exe} x {arx_tmp1} -o{dir_bins}')
    arx_tmp2 = fr"..\tmp{arx_fmt2}"
    os.system(f'{z7_exe} a -ssw  -mmt=10 -mx9 -stl  {arx_tmp2} ./{dir_bins}/*')
    os.system(f'rd /q /s {dir_bins} >nul')
    oss('del', arx_tmp1)

    # Размер архива 2
    os.system(f'for %1 in ("{arx_tmp2}") do @echo Размер 7z-архива %~z1 байт')

    # Перемещение архива куда надо
    if flag_net_use:
        oss('copy', arx_tmp2, fpne_net_83H_arx)
    oss('move', arx_tmp2, fpne_loc_out_arx)
    dt = time.perf_counter() - tbegin
    print(f'\Час роботы {dt:0.3f} сек '
        f'({time.strftime("%M:%S", time.localtime(dt))})\n')

    # Отправка сообщения в Вайбер и Копирование буфер
    vitxt = ist.split('\n\n', 1)[0]
#    print(vitxt)
    devs0 = sorted(set(re.findall(r'(?:(=) )?CPU_([^_]+_[^_]+_[^_]+_[^_]+)_.+\.bin', vitxt)))
    devs = ", ".join("".join(dev) for dev in devs0)
    vdts = re.findall(r'CPU_83H-\w_v([0-9N]+)_(\d+)_(\d{4})-(\d{2})-(\d{2})_'
                        r'(\d{2})(\d{2})_\d+%s' % arx_fmt2, vitxt)[0]
    vers = '.'.join(vdts[:2])
    dt = '.'.join(reversed(vdts[2:5])) + '_' + ':'.join(vdts[5:])
    vitxt = ''.join(re.split(r'(\n[ \+\-\t])', vitxt, maxsplit=1)[-2:])
    vitxt = (('Нові ', 'На сервері нові')[flag_net_use] + ' вихідники' +
             ('', f' і прошивки ЦПУ для пристроїв: {devs}')[bool(devs0)] +
              f'. Версія {vers} від {dt}{vitxt}')
    clip.OpenClipboard()
    clip.EmptyClipboard()
    clip.SetClipboardText(vitxt, clip.CF_UNICODETEXT)
    clip.CloseClipboard()
    print('Текст повідомлення про результати роботи в буфері обміну')

    to_viber(vitxt, dir_loc_out != r'D:\Builds_d' and flag_net_use and 'v' not in ds)
#-------------------------------------------------------------------------------

from pywinauto.application import Application
import pywinauto
from lackey import click

#===============================================================================
def to_viber(vitxt, no_tst):
    try:
        app = Application(backend="uia").start(join(os.environ["LOCALAPPDATA"], r'Viber\Viber.exe'))
        app.wait_cpu_usage_lower(30, 5)
        dlg = Application(backend="uia").connect(title='Viber').top_window()
    except pywinauto.findbestmatch.MatchError:
        print('pywinauto.findbestmatch.MatchError')
        return
    except pywinauto.application.AppStartError:
        print('pywinauto.application.AppStartError')
        return
    except pywinauto.findwindows.ElementNotFoundError:
        print('pywinauto.findwindows.ElementNotFoundError')
        return

    if not dlg:
        print('Немає діалогового вікна Вайбер, повідомлення не відправлено')
        return

    if no_tst:
        fpne_png_mask = r'pngs\kbu*.png'
        chat_name = 'КБУ'
    else:
        fpne_png_mask = r'pngs\moizam*.png'
        chat_name = 'Мои заметки'
    kadabra = 'aaldshgjasldg'  # без пробелов

    dlg.type_keys('{ESC}^f^a{DEL}{ENTER}{TAB}{PAUSE 0.5}')
    dlg.type_keys('{ESC}^f^a' + chat_name + '{ENTER}{TAB}{PAUSE 2}', with_spaces=True)
    if not my_click(fpne_png_mask):
        return

    dlg.type_keys('{ESC}^f^' + kadabra + '{ENTER}{TAB}{PAUSE 2}')
    if not my_click(fpne_png_mask):
        return

    dlg.type_keys('^a' + my_replace(vitxt) + '{ENTER}', with_spaces=True)
#    dlg.type_keys('^a^v' + '{ENTER}', with_spaces=True)
    dlg.type_keys('{ESC}^f^a{DEL}{ENTER}{TAB}{PAUSE 0.5}')
#-------------------------------------------------------------------------------

# спец-символы: + SHIFT, ^ CTRL, % ALT, ~ ENTER, (, ), [, ], {, },
key_maps = (
	(r'([][{}()+^%~])', r'{\1}', ),
#	(' ', '{SPACE}', ),
	(r'\n', '^{ENTER}', ),
)

#===============================================================================
def my_replace(s):
    for d in key_maps:
        s = re.sub(d[0], d[1], s)
    return s
#-------------------------------------------------------------------------------

#===============================================================================
def my_click(fpne_png_mask):
    for fpne_png in glob(fpne_png_mask):
        try:
            click(fpne_png)
            return True
        except :
            pass
    print(f'фрагмент по "{fpne_png_mask}" не знайдено')
#-------------------------------------------------------------------------------


#===============================================================================
if __name__ == '__main__':
    main()
    if 'M' not in ds:
        oss('copy', join(split(fpne_macro3)[0],
                        split(fpne_macro2)[-1]), fpne_macro2)
    if not (ps_ or '--waitendno' in sys.argv):
#        input('\nЖми Enter для выхода ...')
#        os.system('timeout /t 60')
        os.system('pause')
