import sys
import datetime
import dateutils
import math
obsfile = sys.argv[1]
fileout = open(sys.argv[2],'w')
analdate = sys.argv[3]
yyyy,mm,dd,hh = dateutils.splitdate(analdate)
analtime = datetime.datetime(yyyy,mm,dd,hh,0)
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
#for ncode in range(500,599,10):
#    basin = int(str(ncode)[-2])
#    oberrdict[ncode]   = 1.0e10
#    oberrdict[ncode+1] = 1.0e10
#    oberrdict[ncode+2] = 1.0e10
#    oberrdict[ncode+3] = 1.0e10
#    oberrdict[ncode+4] = 1.0e10
#    oberrdict[ncode+5] = 1.0e10
badstatname = []
obtype = 'P'
for line in open(obsfile):
# '%-19s %3i %01s %7.2f %6.2f %5i %6.2f %8.2f %8.2f %5.2f %30s %13s' % (obid,nceptype,obtype,longitude,latitude,elevation,analtime_offset,ob,slpob,pserr,statname,providerobid)
# 999122003000000533 183 P  183.83 -13.23     0   0.00  1007.50 1007.80  1.60    0.00 0 1 1 0 0 0 1009.23  0.47   1.43 1008.96 
# 1.16   0.36   -3            HIHIFO (ILE WALLIS)  917530-99999 
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
    #analtime_offset = float(linesplit[6]) 
    nceptype = int(linesplit[1])
    longitude = float(linesplit[3])
    latitude = float(linesplit[4])
    elevation = int(linesplit[5])
    
    ob = float(linesplit[7])
    slpob = float(linesplit[8])
    pserr = oberrdict[nceptype]
    statname = line[-57:-27]
    statid = line[-26:-13]
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
    #key = '%7.2f %6.2f %5i %3i' % (longitude,latitude,elevation,nceptype) 
    # no bias correction.
    bias = 1.e30
    stringout = '%-19s %3i %01s %7.2f %6.2f %5i %6.2f %7.1f %7.1f %10.3e %5.2f %30s %13s\n' % (obid,nceptype,obtype,longitude,latitude,elevation,analtime_offset,ob,slpob,bias,pserr,statname,statid)
    fileout.write(stringout)
fileout.close()
