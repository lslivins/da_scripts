"""
Compute surface pressure forward operator using native grid FV3 history files.
"""
from netCDF4 import Dataset
import numpy as np
import time, cPickle, sys, os
from mpi4py import MPI
# fortran module for writing GSI diagnostic files
from write_diag import write_diag
import f90nml # read fortran namelists.

# mpirun -np 64 /contrib/anaconda/2.3.0/bin/python psop_fv3_mpi.py

comm = MPI.COMM_WORLD
nanals = comm.size
nmem = comm.rank + 1
member = 'mem%03i' % nmem

# set constants.
rlapse_stdatm = 0.0065
grav = 9.80665; rd = 287.05; cp = 1004.6; rv=461.5
kap1 = (rd/cp)+1.0
kapr = (cp/rd)

# read from fortran namelist (on every task).
nml = f90nml.read('psop.nml')
res = nml['psop_nml']['res']
date = nml['psop_nml']['date']
ntimes = nml['psop_nml']['ntimes']
fhmin = nml['psop_nml']['fhmin']
fhout = nml['psop_nml']['fhout']
nlev = nml['psop_nml']['nlev']
obsfile = nml['psop_nml']['obsfile']
picklefile = nml['psop_nml']['meshfile']
if nml['psop_nml'].has_key('zthresh'):
    zthresh = nml['psop_nml']['zthresh']
else:
    zthresh = 1000.
if nml['psop_nml'].has_key('delz_const'):
    delz_const = nml['psop_nml']['zthresh']
else:
    delz_const = 0.001
datapath = os.path.join(nml['psop_nml']['datapath'],member)

def preduce(ps,tpress,tv,zmodel,zob):
# compute MAPS pressure reduction from model to station elevation
# See Benjamin and Miller (1990, MWR, p. 2100)
# uses 'effective' surface temperature extrapolated
# from virtual temp tv at pressure tpress 
# using US standard atmosphere lapse rate.
# Avoids diurnal cycle effects that affect actual surface temp.
# Arguments:
# ps - surface pressure to reduce (mb).
# tpress - pressure to extrapolate tv down to surface from (mb).
# t - virtual temp. at pressure tpress (K).
# zmodel - model orographic height (m).
# zob - station height (m).
# Constants: rd, rlapse_stdatm, grav
   alpha = rd*rlapse_stdatm/grav
   # from Benjamin and Miller (http://dx.doi.org/10.1175/1520-0493(1990)118<2099:AASLPR>2.0.CO;2) 
   t0 = tv*(ps/tpress)**alpha # eqn 4 from B&M
   preduce = ps*((t0 + rlapse_stdatm*(zob-zmodel))/t0)**(1./alpha) # eqn 1 from B&M
   return preduce

def palt(ps,zs):
# compute QNH altimeter setting (in mb) given ps (in mb), zs (in m).
# see WAF, Sept 1998, p 833-850 (Pauley) section 2c
   t0 = 288.15; p0 = 1013.25
   alpha = rd*rlapse_stdatm/grav
   palt = ps*(1.+(rlapse_stdatm*zs/t0)*(p0/ps)**alpha)**(1./alpha)
   return palt


# read pre-computed and pickled stripack triangulation (on root only).

if comm.rank == 0:
    tri = cPickle.load(open(picklefile,'rb'))
else:
    tri = None
tri = comm.bcast(tri, root=0)

# read in ps obs (on root only).

if comm.rank == 0:
    olats = []; olons = []; obs = []; zobs = []; times = []; stdevorig = []; bias = []
    stattype = []; statinfo = []
    f = open(obsfile)
    for line in f:
        statid = line[0:19]
        statname = line[87:117]
        obid = line[118:131]
        # skip first 19 chars in line (contains ob identification string)
        line = line[20:]
        #statinfo.append(statid+' '+statname+' '+obid) # 64 chars
        statinfo.append(obid[-8:]) # only 8 chars allowed without mods to EnKF
        try:
            lon = float(line[6:13])
            lat = float(line[14:20])
            ob = float(line[35:41])
            t = float(line[28:33])
            zob = float(line[21:26])
            b = float(line[51:61])
            err = float(line[61:67])
            ncepid = int(line[0:3])
        except ValueError:
            continue
        stattype.append(ncepid)
        olons.append(lon)
        olats.append(lat)
        zobs.append(zob)
        times.append(t)
        obs.append(ob)
        bias.append(b)
        stdevorig.append(err)
    f.close()
    olons = np.radians(np.array(olons))
    olats = np.radians(np.array(olats))
    obs = np.array(obs); times = np.array(times); zobs = np.array(zobs)
    bias = np.array(bias); stdevorig = np.array(stdevorig)
    bias = np.where(bias < 1.e20, bias, 0)
    stattype = np.array(stattype)
    nobs = len(obs)
    print 'nobs = ',nobs
    print 'min/max lons',np.degrees(olons.min()),np.degrees(olons.max())
    print 'min/max lats',np.degrees(olats.min()),np.degrees(olats.max())
    print 'min/max obs',obs.min(),obs.max()
    print 'min/max times',times.min(),times.max()
    print 'min/max bias',bias.min(),bias.max()
    print 'min/max zobs',zobs.min(),zobs.max()
    print 'min/max stdevorig',stdevorig.min(),stdevorig.max()
    nobs = comm.bcast(nobs, root=0)
else:
    nobs = None; statinfo = []
    nobs = comm.bcast(nobs, root=0)
    olats = np.empty(nobs,np.float)
    olons = np.empty(nobs,np.float)
    obs = np.empty(nobs,np.float)
    times = np.empty(nobs,np.float)
    zobs = np.empty(nobs,np.float)
    stdevorig = np.empty(nobs,np.float)
    bias = np.empty(nobs,np.float)
    stattype = np.empty(nobs,np.int)

#print 'nobs on task %s = %s' % (comm.rank,nobs)
comm.Bcast(olons,root=0)
comm.Bcast(olats,root=0)
comm.Bcast(obs,root=0)
comm.Bcast(olons,root=0)
comm.Bcast(olats,root=0)
comm.Bcast(times,root=0)
comm.Bcast(bias,root=0)
comm.Bcast(zobs,root=0)
comm.Bcast(stdevorig,root=0)
comm.Bcast(stattype,root=0)
statinfo = comm.bcast(statinfo, root=0)
statinfo2 = np.array(statinfo, dtype='c').T

iuseob = np.zeros(nobs, np.int8)
iuseob = np.where(np.logical_and(times >= -3, times <= 3), 1, 0)
if comm.rank == 0: print nobs-iuseob.sum(),' obs have invalid time'
altob = palt(obs, zobs)
nobs_before = iuseob.sum()
iuseob = np.where(np.logical_and(iuseob, np.logical_and(altob >= 850, altob <= 1090)), 1, 0)
if comm.rank == 0: print nobs_before-iuseob.sum(),' obs have out of range altimeter setting'

# read data from history files.
# (a different ensemble member is read on each task)

t1 = time.clock()
psmodel = np.empty((ntimes,6,res,res),np.float64)
tmodel = np.empty((ntimes,6,res,res),np.float64)
pmodel = np.empty((ntimes,6,res,res),np.float64)
zsmodel = np.empty((6,res,res),np.float64)
nlevs = None
for ntile in range(1,7,1):
    datafile = '%s/fv3_history.tile%s.nc'% (datapath,ntile)
    try:
        nc = Dataset(datafile)
    except:
        raise IOError('cannot open %s' % datafile)
    if nlevs is None:
        nlevs = len(nc.dimensions['pfull'])
    for ntime in range(0,ntimes): # skip first time
        psmodel[ntime,ntile-1,:,:] = 0.01*nc['ps'][ntime]
        tmodel[ntime,ntile-1,:,:] = nc['temp'][ntime,nlevs-nlev,:,:] +\
        (rv/rd-1.0)*nc['sphum'][ntime,nlevs-nlev,:,:]
        try:
            pmodel[ntime,ntile-1,:,:] = 0.01*nc['pfhy'][ntime,nlevs-nlev,:,:]
        except:
            pmodel[ntime,ntile-1,:,:] = 0.01*nc['pfnh'][ntime,nlevs-nlev,:,:]
    zsmodel[ntile-1,:,:] = nc['zs'][:]
psmodel = psmodel.reshape((ntimes,6*res*res))
zsmodel = zsmodel.reshape((6*res*res))
tmodel = tmodel.reshape((ntimes,6*res*res))
pmodel = pmodel.reshape((ntimes,6*res*res))
if comm.rank == 0:
    print 'min/max/mean ps %s' % member,psmodel.min(), psmodel.max(), psmodel.mean()
    print 'min/max/mean zs %s' % member,zsmodel.min(), zsmodel.max(), zsmodel.mean()
    print 'min/max/mean t at level %s %s' % (nlev,member), tmodel.min(), tmodel.max(), tmodel.mean()
    print 'min/max/mean p at level %s %s' % (nlev,member), pmodel.min(), pmodel.max(), pmodel.mean()
    print 'read data from history files took ',time.clock()-t1,' secs'
    
# interpolate to ob locations.
t1 = time.clock()
zsmodel_interp = tri.interp_linear(olons,olats,zsmodel)
psmodel_interp = np.empty((ntimes,nobs),np.float64)
tmodel_interp = np.empty((ntimes,nobs),np.float64)
pmodel_interp = np.empty((ntimes,nobs),np.float64)
for ntime in range(ntimes):
    psmodel_interp[ntime] = tri.interp_linear(olons,olats,psmodel[ntime])
    tmodel_interp[ntime] = tri.interp_linear(olons,olats,tmodel[ntime])
    pmodel_interp[ntime] = tri.interp_linear(olons,olats,pmodel[ntime])
# linear interpolation in time.
dtob = (fhmin+times)/fhout
idtob  = dtob.astype(np.int)
idtobp = idtob+1
idtobp = np.minimum(idtobp,ntimes-1)
delt = dtob - idtob.astype(np.float64)
anal_ob = np.empty(nobs, np.float64)
anal_obp = np.empty(nobs, np.float64)
anal_obt = np.empty(nobs, np.float64)
for nob in range(nobs):
    anal_ob[nob] = (1.-delt[nob])*psmodel_interp[idtob[nob],nob] + delt[nob]*psmodel_interp[idtobp[nob],nob]
    anal_obp[nob] = (1.-delt[nob])*pmodel_interp[idtob[nob],nob] + delt[nob]*pmodel_interp[idtobp[nob],nob]
    anal_obt[nob] = (1.-delt[nob])*tmodel_interp[idtob[nob],nob] + delt[nob]*tmodel_interp[idtobp[nob],nob]

# adjust interpolated model forecast pressure to station height
anal_ob = preduce(anal_ob, anal_obp, anal_obt, zobs, zsmodel_interp)
if comm.rank == 0: print 'interpolation %s points took' % nobs,time.clock()-t1,' secs'

zdiff = np.abs(zobs - zsmodel_interp)
# adjust ob error based on diff between station and model height.
# (GSI uses 0.005 for delz_const)
stdev = stdevorig + delz_const*zdiff

nobs_before = iuseob.sum()
iuseob = np.where(np.logical_and(iuseob, zdiff < zthresh), 1, 0)
if comm.rank == 0: print nobs_before-iuseob.sum(),' obs have too large an orography mismatch'

# compute ensemble mean on root task.
ensmean_ob = np.zeros(anal_ob.shape, anal_ob.dtype)
comm.Reduce(anal_ob, ensmean_ob, op=MPI.SUM, root=0)

olons = np.degrees(olons); olats = np.degrees(olats)
if comm.rank == 0:
    # write out text file.
    ensmean_ob = ensmean_ob/nanals
    ominusf = (obs-ensmean_ob)[iuseob.astype(np.bool)]
    print 'ens mean rms O-F for %s obs' % iuseob.sum(),np.sqrt((ominusf**2).mean())
    
    fout = open('psobs_prior.txt','w')
    for nob in range(nobs):
        if stdev[nob] > 99.99: stdev[nob] = 99.99
        stringout = '%-64s %3i %7.2f %6.2f %5i %5i %6.2f %7.1f %7.1f %5.2f %5.2f %1i\n' % (statinfo[nob],stattype[nob],olons[nob],olats[nob],zobs[nob],np.rint(zsmodel_interp[nob]),times[nob],obs[nob],ensmean_ob[nob],stdevorig[nob],stdev[nob],iuseob[nob])
        fout.write(stringout)
    fout.close()

# write each ensemble member (one per task)
stdev = np.where(iuseob == 0, 1.e10, stdev)
idate = int(date)
diagfile = "diag_conv_ges.%s_mem%03i" % (idate,nmem)
write_diag(diagfile,comm.rank,idate,statinfo2,stattype,olons,olats,times,obs,zobs,stdev,stdevorig,anal_ob,zsmodel_interp,bias)

# write ensemble mean on root task
if comm.rank == 0:
    diagfile = "diag_conv_ges.%s_ensmean" % idate
    write_diag(diagfile,comm.rank,idate,statinfo2,stattype,olons,olats,times,obs,zobs,stdev,stdevorig,ensmean_ob,zsmodel_interp,bias)
