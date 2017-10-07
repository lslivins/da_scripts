import math, sys, os, dateutils, datetime, string, time
from numpy import *

datapath = os.environ['datapath']

oberrdict = {}
# here are the user-settable parameters.
# ob errors for NCEP ob types.
for ncode in range(1000):
    oberrdict[ncode]=1.e30
oberrdict[180] = 2.0
oberrdict[183] = 1.6
oberrdict[181] = 1.2
oberrdict[120] = 1.2
oberrdict[132] = 2.0
oberrdict[194] = 2.0
oberrdict[195] = 2.0
# 'real' observations
for ncode in range(300,400):
    cat = int(str(ncode)[-1])
    basin = int(str(ncode)[-2])
    if cat in [0,1]:
        oberrdict[ncode] = 3.0
    elif cat == 2:
        oberrdict[ncode] = 3.5
    else:
        oberrdict[ncode] = 4.5
    # Pac Storms should have larger error
    if basin in [1,2,8]:
	oberrdict[ncode] = 2.*oberrdict[ncode]
    # S. Hem storms should have larger error.
    if basin in [5,6,7]:
        oberrdict[ncode] = 3.*oberrdict[ncode] 
# observations derived from wind.
for ncode in range(500,599,10):
    basin = int(str(ncode)[-2])
    oberrdict[ncode]   = 4.0
    oberrdict[ncode+1] = 5.0
    oberrdict[ncode+2] = 5.5
    oberrdict[ncode+3] = 6.0
    oberrdict[ncode+4] = 6.0
    oberrdict[ncode+5] = 6.0 
    if basin in [1,2,8]:
        oberrdict[ncode] =   6.0 #2.*oberrdict[ncode]
        oberrdict[ncode+1] = 6.5 #2.*oberrdict[ncode+1]
        oberrdict[ncode+2] = 7.0 #2.*oberrdict[ncode+2]
        oberrdict[ncode+3] = 9.0#2.*oberrdict[ncode+3]
        oberrdict[ncode+4] = 9.0#2.*oberrdict[ncode+4]
        oberrdict[ncode+5] = 9.0#2.*oberrdict[ncode+5]
    if basin in [5,6,7]:
        oberrdict[ncode]   = 12.0#4.*oberrdict[ncode] 
        oberrdict[ncode+1] = 13.0#4.*oberrdict[ncode+1] 
        oberrdict[ncode+2] = 14.0#4.*oberrdict[ncode+2] 
        oberrdict[ncode+3] = 18.0#4.*oberrdict[ncode+3] 
        oberrdict[ncode+4] = 18.0#4.*oberrdict[ncode+4] 
        oberrdict[ncode+5] = 18.0#4.*oberrdict[ncode+5] 
# turn off TCs

# get analysis date (command line parameter YYYYMMDDHH)
analdate = sys.argv[1]
obsfileout = sys.argv[2]
fileout = open(obsfileout,'w')


# added by gpc
# get day of year, datetime instance corresponding to analysis time
yyyy,mm,dd,hh = dateutils.splitdate(analdate)
analtime = datetime.datetime(yyyy,mm,dd,hh,0)
# set the minute of analtime to zero


# estimate bias
lastndays = int(os.environ['lastndays'])
analdate2 = dateutils.dateshift(analdate,-6)
analdate1 = dateutils.dateshift(analdate2,-lastndays*24)
dates = dateutils.daterange(analdate1,analdate2,6)
ndays = len(dates)/4 
obdict = {}
t1 = time.clock()
for date in dates:
    pathobs = os.path.join(datapath,date)
    try:
        file_ob = open(os.path.join(pathobs,'psobs_prior.txt'))
    except:
        continue
    for line in file_ob:
#       skip first 64 chars in line (contains ob identification string)
        line = line[65:]
        obtyp = line[0:3]
        if obtyp not in ['120','181','183']: continue
        lonob = line[4:11]
        latob = line[12:18]
        zob = line[20:24]
        timeob = float(line[32:37] )
        ob = float(line[39:45])
        hx = float(line[47:53])
    #   linesplit = line.split()
    #   lonob = linesplit[1]
    #   latob = linesplit[2]
    #   zob  = linesplit[3]
    #   timeob = linesplit[5]
    #   ob = float(linesplit[6])
    #   hx = float(linesplit[7])
    #   dateob = dateutils.dateshift(date,int(float(timeob)))
        key = " %07s%06s %05s %03s" % (lonob,latob,zob,obtyp)
        if obdict.has_key(key):
            val = obdict[key]
            val.append((ob,hx,float(date),timeob))
            obdict[key] = val
        else:
            obdict[key] = [(ob,hx,float(date),timeob)]
    file_ob.close()
#print 'time to read in data = ',time.clock()-t1

#t1 = time.clock()
biasdict = {}
for key, vals in obdict.items():
    obarray = array(vals)
    observations = obarray[:,0]
    forecasts = obarray[:,1]
    obdates = [str(int(fdate)) for fdate in obarray[:,2].tolist()]
    obfits = observations - forecasts
    if len(forecasts) < 2: continue
    days = []
    for date in obdates:
        if date[0:8] not in days:
            days.append(date[0:8])
    count = len(days) # one per day
    # paired sample standard deviation.
    covmat = 2.*cov(forecasts,observations)
    stdev = covmat[0,0]+covmat[1,1]-2.*covmat[0,1]
    corr = covmat[0,1]/sqrt(covmat[0,0]*covmat[1,1])
    if stdev < 1.e-5: stdev = 1.e-5
    stdev = sqrt(stdev)
    if lastndays < 1 or count < ndays/2: # must have at least half the total number of days.
        sig = 1.e30
    else:
        sig = 1.96*stdev/sqrt(count) # two-sided 5% level.
    bias = obfits.mean()
    if abs(bias) > sig: 
        biasdict[key] = bias
    #obstdev = sqrt(covmat[1,1])
    # if observation variance very small, set bias to -1.e30 (check later)
    #if obstdev < 0.1: 
    #    biasdict[key] = -1.e30
#print 'time to process data = ',time.clock()-t1

#t1 = time.clock()
badstatname = []
badstatids = []
obtype = 'P'
pathobs = os.path.join(datapath,analdate)
for line in open(os.path.join(pathobs,'psobfile')):
#1999103121000000013 181 P   39.30  44.30   323   0.00   985.50  999.40  1.20   -1.22
    linesplit = line.split()
    if not linesplit: continue # skip blank lines??
    obid = linesplit[0]
    dateob = linesplit[0][0:12]
    try:
        yyyy,mm,dd,hh = dateutils.splitdate(dateob)
    except ValueError:
        continue
    try:
        minute = int(dateob[10:12])
    except ValueError:
        continue
    if minute > 60: minute = 0
    obtime = datetime.datetime(yyyy,mm,dd,hh,minute)
    difftime = obtime - analtime
    hrsdiff = 24.0*difftime.days + float(difftime.seconds)/3600.0
    analtime_offset = hrsdiff
    obtyp = linesplit[1]
    nceptype = int(obtyp)
    lonob = linesplit[3]
    latob = linesplit[4]
    longitude = float(lonob)
    latitude = float(latob)
    zob = linesplit[5]
    elevation = int(zob)
    
    ob = float(linesplit[7])
    slpob = float(linesplit[8])
    pserr = oberrdict[nceptype]
    statname = line[-57:-27]
    statid = line[-26:-13]
   # could add ship ID and Deck ID here from ICOADS; they are [-12:] together
# bad elevation check
    if elevation < -400 or elevation > 9000:
        continue
# blacklist stations.
    if (statname.lstrip()).rstrip() in badstatname:
       continue  
# skip stations with bogus latitudes.
    if math.fabs(latitude) > 90.: 
        continue
# skip stations with id > 400:
#   if nceptype >= 400 and nceptype < 500:
#       continue
# skip stations with huge errors.
    if pserr > 1.e20: 
        continue
    # bias correct observation.
    key = " %07s%06s %05s %03s" % (lonob,latob,zob,obtyp)
    if biasdict.has_key(key):
        bias = biasdict[key]
    else:
        bias = 1.e30
    # no bias correction.
    #bias = 1.e30
    stringout = '%-19s %3i %01s %7.2f %6.2f %5i %6.2f %7.1f %7.1f %10.3e %5.2f %30s %13s\n' % (obid,nceptype,obtype,longitude,latitude,elevation,analtime_offset,ob,slpob,bias,pserr,statname,statid)
    fileout.write(stringout)
fileout.close()
#print 'time to write out data',time.clock()-t1
