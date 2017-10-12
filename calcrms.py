from netCDF4 import Dataset
import numpy as np
import time, cPickle, sys, os
import dateutils
import pygrib

def getmean(diff,coslats):
    meancoslats = coslats.mean()
    return (coslats*diff).mean()/meancoslats

date1 = sys.argv[1]
date2 = sys.argv[2]
dates = dateutils.daterange(date1,date2,6)

var = 'z'
level = 500
res = 96   
nlons = 240; nlats = 121
latbound = 21 # boundary between tropics and extra-tropics
datapath = '../../C%s_iau_psonly' % res
picklefile = 'C%s_grid.pickle' % res
analfile = '../../erainterim/erainterim_1999_%smb_ztuv.grib2' % level

tri = cPickle.load(open(picklefile,'rb'))

olons_deg = (360./nlons)*np.arange(nlons)
olats_deg = -90 + (360./nlons)*np.arange(nlats)
olons = np.radians(olons_deg); olats = np.radians(olats_deg)
olons, olats = np.meshgrid(olons, olats)
latbound = 21
latslist = olats_deg.tolist()
latnh = latslist.index(latbound)
latsh = latslist.index(-latbound)
coslats = np.cos(olats)
coslatssh = coslats[:latsh+1,:]
coslatsnh = coslats[latnh:,:]
coslatstr = coslats[latsh:latnh+1,:]

grbs = pygrib.open(analfile)

rmsnhall=[];rmsshall=[];rmstrall=[];rmsglall=[]
sprdnhall=[];sprdshall=[];sprdtrall=[];sprdglall=[]
bias = None
for date in dates:
    datem1 = dateutils.dateshift(date,6)
    for grb in grbs:
        grbdate = '%06i%04i' % (grb.dataDate,grb.dataTime)
        if grbdate == date+'00' and grb.shortName == var and grb.level == level:
            if var == 'z':
                verif_data = grb.values[::-1,:]/9.8066
            else:
                verif_data = grb.values[::-1,:]
            break
    #print verif_data.shape, verif_data.min(), verif_data.max()
    # read ensemble mean and spread data from tiled  history files.
    cube_data_mean = np.zeros((6,res,res),np.float32)
    cube_data_sprd = np.zeros((6,res,res),np.float32)
    for ntile in range(1,7,1):
        datafile = '%s/%s/ensmean/plevensmean.tile%s.nc'% (datapath,date,ntile)
        nc = Dataset(datafile)
        cube_data_mean[ntile-1,:,:] = nc['%s%s'%(var,level)][0,:,:]
        nc.close()
        datafile = '%s/%s/ensmean/plevenssprd.tile%s.nc'% (datapath,date,ntile)
        nc = Dataset(datafile)
        cube_data_sprd[ntile-1,:,:] = nc['%s%s'%(var,level)][0,0,:,:]
        nc.close()
    cube_data_mean = cube_data_mean.reshape(6*res*res)
    cube_data_sprd = cube_data_sprd.reshape(6*res*res)
    # interpolate tiles to lat/lon grid
    latlon_data_mean = tri.interp_linear(olons,olats,cube_data_mean)
    latlon_data_sprd = tri.interp_linear(olons,olats,cube_data_sprd)
    #print latlon_data_mean.shape, latlon_data_mean.min(), latlon_data_mean.max()
    #print latlon_data_sprd.shape, latlon_data_sprd.min(), latlon_data_sprd.max()
    err = verif_data - latlon_data_mean
    if bias is None:
        bias = err/len(dates)
    else:
        bias += err/len(dates)
    sprd = latlon_data_sprd
    #import matplotlib.pyplot as plt
    #plt.figure()
    #clevs = np.arange(-100,101,10)
    #cs = plt.contourf(olons_deg,olats_deg,err,clevs,cmap=plt.cm.bwr,extend='both')
    #plt.title('error')
    #plt.colorbar()
    #plt.figure()
    #clevs = np.arange(0,51,5)
    #cs = plt.contourf(olons_deg,olats_deg,sprd,clevs,cmap=plt.cm.hot_r,extend='both')
    #plt.title('spread')
    #plt.colorbar()
    #plt.show()
    #raise SystemExit
    rmssh = np.sqrt(getmean(err[:latsh+1,:]**2,coslatssh))
    rmsnh = np.sqrt(getmean(err[latnh:,:]**2,coslatsnh))
    rmstr = np.sqrt(getmean(err[latsh:latnh+1,:]**2,coslatstr))
    rmsgl = np.sqrt(getmean(err**2,coslats))
    sprdsh = getmean(sprd[:latsh+1,:],coslatssh)
    sprdnh = getmean(sprd[latnh:,:],coslatsnh)
    sprdtr = getmean(sprd[latsh:latnh+1,:],coslatstr)
    sprdgl = getmean(sprd,coslats)
    rmsnhall.append(rmsnh); sprdnhall.append(sprdnh)
    rmsshall.append(rmssh); sprdshall.append(sprdsh)
    rmstrall.append(rmstr); sprdtrall.append(sprdtr)
    rmsglall.append(rmsgl); sprdglall.append(sprdgl)
    print '%s %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f' %\
    (date,rmsnh,rmstr,rmssh,rmsgl,sprdnh,sprdtr,sprdsh,sprdgl)
rmsnh = np.asarray(rmsnhall); sprdnh = np.asarray(sprdnhall)
rmssh = np.asarray(rmsshall); sprdsh = np.asarray(sprdshall)
rmstr = np.asarray(rmstrall); sprdnh = np.asarray(sprdtrall)
rmsgl = np.asarray(rmsglall); sprdnh = np.asarray(sprdglall)
print '%s-%s %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f' %\
(date1,date2,rmsnh.mean(),rmstr.mean(),rmssh.mean(),rmsgl.mean(),\
sprdnh.mean(),sprdtr.mean(),sprdsh.mean(),sprdgl.mean())

#import matplotlib.pyplot as plt
#plt.figure()
#clevs = np.arange(-50,51,5)
#cs = plt.contourf(olons_deg,olats_deg,bias,clevs,cmap=plt.cm.bwr,extend='both')
#plt.title('bias')
#plt.colorbar()
#plt.show()
