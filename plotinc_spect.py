import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys, os
import dateutils
from dateutils import daterange
from netCDF4 import Dataset
from spharm import Spharmt, getspecindx
from matplotlib.ticker import FormatStrFormatter,FuncFormatter,LogLocator

def getrms(diff,coslats):
    meancoslats = coslats.mean()
    return np.sqrt((coslats*diff**2).mean()/meancoslats)

def getvarspectrum(dataspec,indxm,indxn,ntrunc):
    varspect = np.zeros(ntrunc+1,np.float)
    nlm = (ntrunc+1)*(ntrunc+2)/2
    for n in range(nlm):
        if indxm[n] == 0:
            varspect[indxn[n]] += (0.5*dataspec[n]*np.conj(dataspec[n])).real
        else:
            varspect[indxn[n]] += (dataspec[n]*np.conj(dataspec[n])).real
    return varspect


#expt1 = sys.argv[1]
#expt2 = sys.argv[2]
#date1 = sys.argv[3]
#date2 = sys.argv[4]
expt = 'C192C384_tst'
date = '2016011512'
title1 = 'hybenvar'
title2 = 'hybenvar2'
var = 'tmpmidlayer'
#var = 'pressfc'
nlev = 25

spec1 = None; spec2 = None; spec3 = None; spec4 = None


# get first guess for expt 2 (hybrid cov/envar)
datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt
print datapath
print date
filename = os.path.join(os.path.join(datapath,date),'sfg_%s_fhr06_ensmean.nc4' % date)
nc = Dataset(filename)
if spec1 is None:
    lons = nc['lon'][:]
    lats = nc['lat'][::-1]
    nlats = len(lats); nlons = len(lons)
    lons2, lats2 = np.meshgrid(lons, lats)
    re = 6.3712e6; ntrunc=nlats-1
    spec = Spharmt(nlons,nlats,rsphere=re,gridtype='regular',legfunc='computed')
    indxm, indxn = getspecindx(ntrunc)
    degree = indxn.astype(np.float)
if var == 'pressfc':
    fg = nc[var][0,::-1,...]
else:
    fg = nc[var][0,nlev,::-1,...]
nc.close()
    
# get enkf increment from hybrid gain expt
datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt
filename = os.path.join(os.path.join(datapath,date),'sanl_%s_fhr06_%s.nc4' % (date,title1))
print filename
nc = Dataset(filename)
if var == 'pressfc':
    inc = nc[var][0,::-1,...] - fg
else:
    inc = nc[var][0,nlev,::-1,...] - fg
nc.close()

print inc.min(), inc.max(), inc.min(), inc.max()
print 'global RMS',title1,getrms(inc,np.cos(np.radians(lats2)))

incspec = spec.grdtospec(inc)
spec1 = getvarspectrum(incspec,indxm,indxn,ntrunc)

# get hybrid cov increment (expt2)
datapath = '/scratch3/BMC/gsienkf/whitaker/%s' % expt
print datapath
filename = os.path.join(os.path.join(datapath,date),'sanl_%s_fhr06_%s.nc4' % (date,title2))
nc = Dataset(filename)
if var == 'pressfc':
    inc = nc[var][0,::-1,...] - fg
else:
    inc = nc[var][0,nlev,::-1,...] - fg
nc.close()
print inc.min(), inc.max(), inc.min(), inc.max()
print 'global RMS',title2,getrms(inc,np.cos(np.radians(lats2)))

incspec = spec.grdtospec(inc)
spec2 = getvarspectrum(incspec,indxm,indxn,ntrunc)
    
print 'global RMS spectra',title1,title2,np.sqrt(spec1.sum()), np.sqrt(spec2.sum())
plt.semilogy(np.arange(ntrunc+1),spec1,color='r',linewidth=2,\
        label=title1)
plt.semilogy(np.arange(ntrunc+1),spec2,color='k',linewidth=2,\
        label=title2)
plt.legend(loc=0)
plt.ylim(1.e-5,1.e-2)
plt.xlim(0,180)
plt.xlabel('total wavenumber')
plt.ylabel('increment variance')
plt.title('Increment spectrum %s nlev=%s (%s)' % (var,nlev,date))
plt.savefig('spectrum_test.png')
plt.show()
