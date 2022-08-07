import glob, os
incs = glob.glob(r'C:\Program Files*\Atmel\Studio\7.0\packs\atmel\ATmega_DFP\*\avrasm\inc\m2561def.inc')
incs and os.startfile(sorted(incs)[-1])

