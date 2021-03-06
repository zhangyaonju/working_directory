#############
################################
### calcualte the climate data for two growing periods
# 
### calcuate the peak to senescence mean SIF or NDVI for each year
library(ncdf4)
#setwd("/Users/yzhang/Project/SIF_phenology/")
## readin the SIF files
setwd("/rigel/glab/users/zy2309/PROJECT/SIF_phenology")
sif_pheno<-list.files("./pheno_hd_fixed_threshold_clear/",full.names = T,pattern = ".nc")

sos_file<-'./analysis/clear_daily_SOS_30N_fixed_stat.nc'
pos_file<-"./analysis/clear_daily_POS_30N_fixed_stat.nc"
eos_file<-"./analysis/clear_daily_EOS_30N_fixed_stat.nc"

##### get average EOS and SOS
eos_f<-nc_open(eos_file)
eos<-ncvar_get(eos_f,varid="MEAN")
xdim2<-eos_f$dim[["longitude"]]
ydim2<-eos_f$dim[["latitude"]]
nc_close(eos_f)
sos_f<-nc_open(sos_file)
sos<-ncvar_get(sos_f,varid="MEAN")
nc_close(sos_f)
pos_f<-nc_open(pos_file)
pos<-ncvar_get(pos_f,varid="MEAN")
nc_close(pos_f)

dim(eos)<-c(86400,1)
dim(sos)<-c(86400,1)
dim(pos)<-c(86400,1)


#### interpolate 8-day temperature to daily
spline_interpolate<-function(x){
  nyears<-length(x)/46
  if (sum(is.na(x))>100){
    return(rep(NA,365*nyears))
  }
  
  x_in<-(1:length(x)-0.5)/46
  x_out<-(1:(365*nyears)-0.5)/365
  spl_temp<-spline(x=x_in,y=x,xout=x_out)$y
  return(spl_temp)
}

####get 8-day LST and interpolate into daily values
###starting from 2002
nc_f<-nc_open("/rigel/glab/users/zy2309/PROJECT/SIF_phenology/data/MODIS_LST.nc")
tday<-ncvar_get(nc_f,"LST_Day")
tnight<-ncvar_get(nc_f,"LST_Night")
nc_close(nc_f)
tdaynorth<-tday[,241:360,]
dim(tdaynorth)<-c(720*120,690)
tday_d<-apply(tdaynorth,1,spline_interpolate)
tday_day<-t(tday_d)

tnightnorth<-tnight[,241:360,]
dim(tnightnorth)<-c(720*120,690)
tnight_d<-apply(tnightnorth,1,spline_interpolate)
tnight_day<-t(tnight_d)


### get MSWEP prec
precip_data<-array(NA,dim=c(720,120,6205))
precip_f<-list.files("/rigel/glab/users/zy2309/PROJECT/SIF_phenology/data/daily_data_RS/PREC/",full.names = T)
for (i in 1:length(precip_f)){
  ncf<-nc_open(precip_f[i])
  prec_y<-ncvar_get(ncf,'precipitation')
  precip_data[,,(i*365-364):(i*365)]<-prec_y[,241:360,]
  nc_close(ncf)
}


#### get 8day PAR and interpolate into daily values
### starting from 2001
radnc<-nc_open("/rigel/glab/users/zy2309/PROJECT/SIF_phenology/data/BESS_PAR.nc")
rad<-ncvar_get(radnc,"BESS_PAR")
nc_close(radnc)
par<-rad[,241:360,]
dim(par)<-c(86400,736)
par_d<-apply(par,1,spline_interpolate)
par_day<-t(par_d)


#all climate data starts from 2002 to 2016
precip_day<-precip_data[,,731:6205]   #unit daily precipitation mm/day
dim(precip_day)<-c(86400,5475)        
par_day<-par_day[,366:5840]           #PAR  w/m2


get_mean<-function(xts){
  #this is for temperature, modified into daily
  if (is.na(xts[457]*xts[458]))
    return(NA)
  else{
    st_abs<-ceiling(xts[457]*365)+90
    end_abs<-ceiling(xts[458]*365)+90
    ave_var<-mean(xts[st_abs:end_abs],na.rm=T)
    return(ave_var)
  }
}


calculate_climate<-function(year){
  #get precipitation for this year +90 days (3 month) from previous year
  precip_year<-precip_day[,((year-2002)*365-90):((year-2001)*365)]
  tday_year<-tday_day[,((year-2002)*365-90):((year-2001)*365)]
  tnight_year<-tnight_day[,((year-2002)*365-90):((year-2001)*365)]
  par_year<-par_day[,((year-2002)*365-90):((year-2001)*365)]
  
  ### growing season
  prec_dat<-cbind(precip_year,sos,eos)
  s2e_d_precip<-apply(prec_dat,1,get_mean)
  
  temp_dat<-cbind(tday_year,sos,eos)
  s2e_d_tday<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tnight_year,sos,eos)
  s2e_d_tnight<-apply(temp_dat,1,get_mean)
  
  par_dat<-cbind(par_year,sos,eos)
  s2e_d_par<-apply(par_dat,1,get_mean)
  
  #### first half_growing season
  prec_dat<-cbind(precip_year,sos,pos)
  s2p_d_precip<-apply(prec_dat,1,get_mean)
  
  temp_dat<-cbind(tday_year,sos,pos)
  s2p_d_tday<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tnight_year,sos,pos)
  s2p_d_tnight<-apply(temp_dat,1,get_mean)
  
  prec_dat<-cbind(par_year,sos,pos)
  s2p_d_par<-apply(par_dat,1,get_mean)
  
  ## calculate the second half temp and precipitation
  tday_dat<-cbind(tday_year,pos,eos)
  p2e_d_tday<-apply(temp_dat,1,get_mean)
  tday_dat<-cbind(tnight_year,pos,eos)
  p2e_d_tnight<-apply(temp_dat,1,get_mean)
  
  prec_dat<-cbind(precip_year,pos,eos)
  p2e_d_precip<-apply(prec_dat,1,get_mean)
  
  par_dat<-cbind(par_year,pos,eos)
  p2e_d_par<-apply(par_dat,1,get_mean)
  ##################################
  ##----------------------------------------------
  ### calculate the average 1 month pre-season temperature
  temp_dat<-cbind(tday_year,sos-1/12,sos)
  presos1mon_tday<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tday_year,eos-1/12,eos)
  preeos1mon_tday<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tday_year,pos-1/24,pos+1/24)
  peak_tday<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tnight_year,sos-1/12,sos)
  presos1mon_tnight<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tnight_year,eos-1/12,eos)
  preeos1mon_tnight<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tnight_year,pos-1/24,pos+1/24)
  peak_tnight<-apply(temp_dat,1,get_mean)
  
  par_dat<-cbind(par_year,sos-1/12,sos)
  presos1mon_par<-apply(par_dat,1,get_mean)
  
  par_dat<-cbind(par_year,eos-1/12,eos)
  preeos1mon_par<-apply(par_dat,1,get_mean)
  
  par_dat<-cbind(par_year,pos-1/24,pos+1/24)
  peak_par<-apply(par_dat,1,get_mean)
  
  prec_dat<-cbind(precip_year,sos-1/12,sos)
  presos1mon_prec<-apply(prec_dat,1,get_mean)
  
  prec_dat<-cbind(precip_year,eos-1/12,eos)
  preeos1mon_prec<-apply(prec_dat,1,get_mean)
  
  prec_dat<-cbind(precip_year,pos-1/24,pos+1/24)
  peak_prec<-apply(prec_dat,1,get_mean)
  
  ### calculate the average 2 month pre-season temperature
  temp_dat<-cbind(tday_year,sos-2/12,sos)
  presos2mon_tday<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tday_year,eos-2/12,eos)
  preeos2mon_tday<-apply(temp_dat,1,get_mean)
  
  
  temp_dat<-cbind(tnight_year,sos-2/12,sos)
  presos2mon_tnight<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tnight_year,eos-2/12,eos)
  preeos2mon_tnight<-apply(temp_dat,1,get_mean)
  
  
  par_dat<-cbind(par_year,sos-2/12,sos)
  presos2mon_par<-apply(par_dat,1,get_mean)
  
  par_dat<-cbind(par_year,eos-2/12,eos)
  preeos2mon_par<-apply(par_dat,1,get_mean)
  
  
  prec_dat<-cbind(precip_year,sos-2/12,sos)
  presos2mon_prec<-apply(prec_dat,1,get_mean)
  
  prec_dat<-cbind(precip_year,eos-2/12,eos)
  preeos2mon_prec<-apply(prec_dat,1,get_mean)
  
  
  ### calculate the average 3 month pre-season temperature
  temp_dat<-cbind(tday_year,sos-3/12,sos)
  presos3mon_tday<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tday_year,eos-3/12,eos)
  preeos3mon_tday<-apply(temp_dat,1,get_mean)
  
  
  temp_dat<-cbind(tnight_year,sos-3/12,sos)
  presos3mon_tnight<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tnight_year,eos-3/12,eos)
  preeos3mon_tnight<-apply(temp_dat,1,get_mean)
  
  
  par_dat<-cbind(par_year,sos-3/12,sos)
  presos3mon_par<-apply(par_dat,1,get_mean)
  
  par_dat<-cbind(par_year,eos-3/12,eos)
  preeos3mon_par<-apply(par_dat,1,get_mean)
  
  
  prec_dat<-cbind(precip_year,sos-3/12,sos)
  presos3mon_prec<-apply(prec_dat,1,get_mean)
  
  prec_dat<-cbind(precip_year,eos-3/12,eos)
  preeos3mon_prec<-apply(prec_dat,1,get_mean)
  
  
  ### calculate the average half month pre-season temperature
  temp_dat<-cbind(tday_year,sos-1/24,sos)
  presos0mon_tday<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tday_year,eos-1/24,eos)
  preeos0mon_tday<-apply(temp_dat,1,get_mean)
  
  
  temp_dat<-cbind(tnight_year,sos-1/24,sos)
  presos0mon_tnight<-apply(temp_dat,1,get_mean)
  
  temp_dat<-cbind(tnight_year,eos-1/24,eos)
  preeos0mon_tnight<-apply(temp_dat,1,get_mean)
  
  
  par_dat<-cbind(par_year,sos-1/24,sos)
  presos0mon_par<-apply(par_dat,1,get_mean)
  
  par_dat<-cbind(par_year,eos-1/24,eos)
  preeos0mon_par<-apply(par_dat,1,get_mean)
  
  
  prec_dat<-cbind(precip_year,sos-1/24,sos)
  presos0mon_prec<-apply(prec_dat,1,get_mean)
  
  prec_dat<-cbind(precip_year,eos-1/24,eos)
  preeos0mon_prec<-apply(prec_dat,1,get_mean)
  
  ##************************************************
  ### write data to pheno
  #year_pheno<-sif_pheno[substr(basename(sif_pheno),33,36)==year]
  #phenoin<-nc_open(year_pheno)
  
  
  s2e_prec<-ncvar_def("s2e_prec",'',list(xdim2,ydim2),-9999,compression=9)
  p2e_prec<-ncvar_def("p2e_prec",'',list(xdim2,ydim2),-9999,compression=9)
  s2p_prec<-ncvar_def("s2p_prec",'',list(xdim2,ydim2),-9999,compression=9)
  s2e_tday<-ncvar_def("s2e_tday",'',list(xdim2,ydim2),-9999,compression=9)
  s2p_tday<-ncvar_def("s2p_tday",'',list(xdim2,ydim2),-9999,compression=9)
  p2e_tday<-ncvar_def("p2e_tday",'',list(xdim2,ydim2),-9999,compression=9)
  s2e_tnight<-ncvar_def("s2e_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  s2p_tnight<-ncvar_def("s2p_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  p2e_tnight<-ncvar_def("p2e_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  s2e_par<-ncvar_def("s2e_par",'',list(xdim2,ydim2),-9999,compression=9)
  s2p_par<-ncvar_def("s2p_par",'',list(xdim2,ydim2),-9999,compression=9)
  p2e_par<-ncvar_def("p2e_par",'',list(xdim2,ydim2),-9999,compression=9)
  p_tday<-ncvar_def("p_tday","",list(xdim2,ydim2),-9999,compression=9)
  p_tnight<-ncvar_def("p_tnight","",list(xdim2,ydim2),-9999,compression=9)
  pre_start1_tday<-ncvar_def("pre_start1_tday",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end1_tday<-ncvar_def("pre_end1_tday",'',list(xdim2,ydim2),-9999,compression=9)
  pre_start1_tnight<-ncvar_def("pre_start1_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end1_tnight<-ncvar_def("pre_end1_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  p_par<-ncvar_def("p_par","",list(xdim2,ydim2),-9999,compression=9)
  pre_start1_par<-ncvar_def("pre_start1_par",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end1_par<-ncvar_def("pre_end1_par",'',list(xdim2,ydim2),-9999,compression=9)
  p_prec<-ncvar_def("p_prec","",list(xdim2,ydim2),-9999,compression=9)
  pre_start1_prec<-ncvar_def("pre_start1_prec",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end1_prec<-ncvar_def("pre_end1_prec",'',list(xdim2,ydim2),-9999,compression=9)
  
  pre_start2_tday<-ncvar_def("pre_start2_tday",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end2_tday<-ncvar_def("pre_end2_tday",'',list(xdim2,ydim2),-9999,compression=9)
  pre_start2_tnight<-ncvar_def("pre_start2_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end2_tnight<-ncvar_def("pre_end2_tnight",'',list(xdim2,ydim2),-9999,compression=9)

  pre_start2_par<-ncvar_def("pre_start2_par",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end2_par<-ncvar_def("pre_end2_par",'',list(xdim2,ydim2),-9999,compression=9)

  pre_start2_prec<-ncvar_def("pre_start2_prec",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end2_prec<-ncvar_def("pre_end2_prec",'',list(xdim2,ydim2),-9999,compression=9)
  
  pre_start3_tday<-ncvar_def("pre_start3_tday",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end3_tday<-ncvar_def("pre_end3_tday",'',list(xdim2,ydim2),-9999,compression=9)
  pre_start3_tnight<-ncvar_def("pre_start3_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end3_tnight<-ncvar_def("pre_end3_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  
  pre_start3_par<-ncvar_def("pre_start3_par",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end3_par<-ncvar_def("pre_end3_par",'',list(xdim2,ydim2),-9999,compression=9)
  
  pre_start3_prec<-ncvar_def("pre_start3_prec",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end3_prec<-ncvar_def("pre_end3_prec",'',list(xdim2,ydim2),-9999,compression=9)
  
  pre_start0_tday<-ncvar_def("pre_start0_tday",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end0_tday<-ncvar_def("pre_end0_tday",'',list(xdim2,ydim2),-9999,compression=9)
  pre_start0_tnight<-ncvar_def("pre_start0_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end0_tnight<-ncvar_def("pre_end0_tnight",'',list(xdim2,ydim2),-9999,compression=9)
  
  pre_start0_par<-ncvar_def("pre_start0_par",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end0_par<-ncvar_def("pre_end0_par",'',list(xdim2,ydim2),-9999,compression=9)
  
  pre_start0_prec<-ncvar_def("pre_start0_prec",'',list(xdim2,ydim2),-9999,compression=9)
  pre_end0_prec<-ncvar_def("pre_end0_prec",'',list(xdim2,ydim2),-9999,compression=9)
  

  year_climate<-paste("./pheno_hd_fixed_threshold_climate/clear_rs/",year,"_climate_csif_clear_daily.nc",sep="")
  if (file.exists(year_climate)){
    file.remove(year_climate)
  }
  phenoin<-nc_create(year_climate,list(s2e_tday,s2p_tday,p2e_tday,
                                       s2e_tnight,s2p_tnight,p2e_tnight,
                                       s2e_prec,s2p_prec,p2e_prec,
                                       s2e_par,s2p_par,p2e_par,
                                       pre_start1_tday,pre_end1_tday,p_tday,
                                       pre_start1_tnight,pre_end1_tnight,p_tnight,
                                       pre_start1_par,pre_end1_par,p_par,
                                       pre_start1_prec,pre_end1_prec,p_prec,
                                       pre_start2_tday,pre_end2_tday,
                                       pre_start2_tnight,pre_end2_tnight,
                                       pre_start2_par,pre_end2_par,
                                       pre_start2_prec,pre_end2_prec,
                                       pre_start3_tday,pre_end3_tday,
                                       pre_start3_tnight,pre_end3_tnight,
                                       pre_start3_par,pre_end3_par,
                                       pre_start3_prec,pre_end3_prec,
                                       pre_start0_tday,pre_end0_tday,
                                       pre_start0_tnight,pre_end0_tnight,
                                       pre_start0_par,pre_end0_par,
                                       pre_start0_prec,pre_end0_prec
                                       ))
  ncvar_put(phenoin,s2e_prec,s2e_d_precip)
  ncvar_put(phenoin,p2e_prec,p2e_d_precip)
  ncvar_put(phenoin,s2p_prec,s2p_d_precip)
  ncvar_put(phenoin,s2e_tday,s2e_d_tday)
  ncvar_put(phenoin,s2p_tday,s2p_d_tday)
  ncvar_put(phenoin,p2e_tday,p2e_d_tday)
  ncvar_put(phenoin,s2e_tnight,s2e_d_tnight)
  ncvar_put(phenoin,s2p_tnight,s2p_d_tnight)
  ncvar_put(phenoin,p2e_tnight,p2e_d_tnight)
  ncvar_put(phenoin,s2e_par,s2e_d_par)
  ncvar_put(phenoin,s2p_par,s2p_d_par)
  ncvar_put(phenoin,p2e_par,p2e_d_par)
  ##----------------------------------------------
  ncvar_put(phenoin,pre_start1_tday,presos1mon_tday)
  ncvar_put(phenoin,pre_end1_tday,preeos1mon_tday)
  ncvar_put(phenoin,p_tday,peak_tday)
  ncvar_put(phenoin,pre_start1_tnight,presos1mon_tnight)
  ncvar_put(phenoin,pre_end1_tnight,preeos1mon_tnight)
  ncvar_put(phenoin,p_tnight,peak_tnight)
  ncvar_put(phenoin,pre_start1_par,presos1mon_par)
  ncvar_put(phenoin,pre_end1_par,preeos1mon_par)
  ncvar_put(phenoin,p_par,peak_par)
  ncvar_put(phenoin,pre_start1_prec,presos1mon_prec)
  ncvar_put(phenoin,pre_end1_prec,preeos1mon_prec)
  ncvar_put(phenoin,p_prec,peak_prec)
  
  ##----------------------------------------------
  ncvar_put(phenoin,pre_start2_tday,presos2mon_tday)
  ncvar_put(phenoin,pre_end2_tday,preeos2mon_tday)
  ncvar_put(phenoin,pre_start2_tnight,presos2mon_tnight)
  ncvar_put(phenoin,pre_end2_tnight,preeos2mon_tnight)
  ncvar_put(phenoin,pre_start2_par,presos2mon_par)
  ncvar_put(phenoin,pre_end2_par,preeos2mon_par)
  ncvar_put(phenoin,pre_start2_prec,presos2mon_prec)
  ncvar_put(phenoin,pre_end2_prec,preeos2mon_prec)
  ##----------------------------------------------
  ncvar_put(phenoin,pre_start3_tday,presos3mon_tday)
  ncvar_put(phenoin,pre_end3_tday,preeos3mon_tday)
  ncvar_put(phenoin,pre_start3_tnight,presos3mon_tnight)
  ncvar_put(phenoin,pre_end3_tnight,preeos3mon_tnight)
  ncvar_put(phenoin,pre_start3_par,presos3mon_par)
  ncvar_put(phenoin,pre_end3_par,preeos3mon_par)
  ncvar_put(phenoin,pre_start3_prec,presos3mon_prec)
  ncvar_put(phenoin,pre_end3_prec,preeos3mon_prec)
  ##----------------------------------------------
  ncvar_put(phenoin,pre_start0_tday,presos0mon_tday)
  ncvar_put(phenoin,pre_end0_tday,preeos0mon_tday)
  ncvar_put(phenoin,pre_start0_tnight,presos0mon_tnight)
  ncvar_put(phenoin,pre_end0_tnight,preeos0mon_tnight)
  ncvar_put(phenoin,pre_start0_par,presos0mon_par)
  ncvar_put(phenoin,pre_end0_par,preeos0mon_par)
  ncvar_put(phenoin,pre_start0_prec,presos0mon_prec)
  ncvar_put(phenoin,pre_end0_prec,preeos0mon_prec)
  ##************************************************
  nc_close(phenoin)
}

for (year in 2003:2016){
  print(year)
  calculate_climate(year)
}


#####################################
#######   analysis the partial corrlation between cSIF growing season with SOS when Tmean and precip fixed.
#####################################

## get the average of SOS, CSIF, Tmean and Precip
library(ppcor)
library(ncdf4)
setwd("/rigel/glab/users/zy2309/PROJECT/SIF_phenology/")
sif_pheno<-list.files("./pheno_hd_fixed_threshold_clear/",full.names = T,pattern = ".nc")
sif_climate<-list.files("./pheno_hd_fixed_threshold_climate/clear_rs/",full.names = T,pattern = ".nc")
#sif_climate_era<-list.files("./pheno_hd_fixed_threshold_climate/clear_era/",full.names = T,pattern = ".nc")

p2e_csif<-array(NA,dim=c(86400,14))
s2p_csif<-array(NA,dim=c(86400,14))
s2e_csif<-array(NA,dim=c(86400,14))
ann_csif<-array(NA,dim=c(86400,14))
sos<-array(NA,dim=c(86400,14))
eos<-array(NA,dim=c(86400,14))

s2e_tday<-array(NA,dim=c(86400,14))
s2e_tnight<-array(NA,dim=c(86400,14))
s2p_tday<-array(NA,dim=c(86400,14))
s2p_tnight<-array(NA,dim=c(86400,14))
p2e_tday<-array(NA,dim=c(86400,14))
p2e_tnight<-array(NA,dim=c(86400,14))

s2e_prec<-array(NA,dim=c(86400,14))
s2p_prec<-array(NA,dim=c(86400,14))
p2e_prec<-array(NA,dim=c(86400,14))

s2e_par<-array(NA,dim=c(86400,14))
s2p_par<-array(NA,dim=c(86400,14))
p2e_par<-array(NA,dim=c(86400,14))

pre_start1_tday<-array(NA,dim=c(86400,14))
pre_end1_tday<-array(NA,dim=c(86400,14))
p_tday<-array(NA,dim=c(86400,14))

pre_start1_tnight<-array(NA,dim=c(86400,14))
pre_end1_tnight<-array(NA,dim=c(86400,14))
p_tnight<-array(NA,dim=c(86400,14))

pre_start1_par<-array(NA,dim=c(86400,14))
pre_end1_par<-array(NA,dim=c(86400,14))
p_par<-array(NA,dim=c(86400,14))

pre_start1_prec<-array(NA,dim=c(86400,14))
pre_end1_prec<-array(NA,dim=c(86400,14))
p_prec<-array(NA,dim=c(86400,14))

pre_start2_tday<-array(NA,dim=c(86400,14))
pre_end2_tday<-array(NA,dim=c(86400,14))

pre_start2_tnight<-array(NA,dim=c(86400,14))
pre_end2_tnight<-array(NA,dim=c(86400,14))

pre_start2_par<-array(NA,dim=c(86400,14))
pre_end2_par<-array(NA,dim=c(86400,14))

pre_start2_prec<-array(NA,dim=c(86400,14))
pre_end2_prec<-array(NA,dim=c(86400,14))

pre_start3_tday<-array(NA,dim=c(86400,14))
pre_end3_tday<-array(NA,dim=c(86400,14))

pre_start3_tnight<-array(NA,dim=c(86400,14))
pre_end3_tnight<-array(NA,dim=c(86400,14))

pre_start3_par<-array(NA,dim=c(86400,14))
pre_end3_par<-array(NA,dim=c(86400,14))

pre_start3_prec<-array(NA,dim=c(86400,14))
pre_end3_prec<-array(NA,dim=c(86400,14))

pre_start0_tday<-array(NA,dim=c(86400,14))
pre_end0_tday<-array(NA,dim=c(86400,14))

pre_start0_tnight<-array(NA,dim=c(86400,14))
pre_end0_tnight<-array(NA,dim=c(86400,14))

pre_start0_par<-array(NA,dim=c(86400,14))
pre_end0_par<-array(NA,dim=c(86400,14))

pre_start0_prec<-array(NA,dim=c(86400,14))
pre_end0_prec<-array(NA,dim=c(86400,14))


for (year in 2003:2016){
  year_pheno<-sif_pheno[substr(basename(sif_pheno),35,38)==year]
  phenoin<-nc_open(year_pheno)
  p2e_csif[,year-2002]<-ncvar_get(phenoin,'p2s_csif')
  s2p_csif[,year-2002]<-ncvar_get(phenoin,'s2p_csif')
  s2e_csif[,year-2002]<-ncvar_get(phenoin,'s2s_csif')
  ann_csif[,year-2002]<-ncvar_get(phenoin,'ann_csif')
  sos[,year-2002]<-ncvar_get(phenoin,'SOS')*365+2.5
  eos[,year-2002]<-ncvar_get(phenoin,'EOS')*365+2.5
  xdim<-phenoin$dim[["longitude"]]
  ydim<-phenoin$dim[["latitude"]]
  nc_close(phenoin)
}


for (year in 2003:2016){
  year_climate<-sif_climate[substr(basename(sif_climate),1,4)==year]
  climatein<-nc_open(year_climate)
  
  s2e_tday[,year-2002]<-ncvar_get(climatein,'s2e_tday')
  s2e_tnight[,year-2002]<-ncvar_get(climatein,'s2e_tnight')
  s2p_tday[,year-2002]<-ncvar_get(climatein,'s2p_tday')
  s2p_tnight[,year-2002]<-ncvar_get(climatein,'s2p_tnight')
  p2e_tday[,year-2002]<-ncvar_get(climatein,'p2e_tday')
  p2e_tnight[,year-2002]<-ncvar_get(climatein,'p2e_tnight')
  
  s2e_prec[,year-2002]<-ncvar_get(climatein,'s2e_prec')
  s2p_prec[,year-2002]<-ncvar_get(climatein,'s2p_prec')
  p2e_prec[,year-2002]<-ncvar_get(climatein,'p2e_prec')
  
  s2e_par[,year-2002]<-ncvar_get(climatein,'s2e_par')
  s2p_par[,year-2002]<-ncvar_get(climatein,'s2p_par')
  p2e_par[,year-2002]<-ncvar_get(climatein,'p2e_par')
  
  pre_start1_tday[,year-2002]<-ncvar_get(climatein,'pre_start1_tday')
  pre_end1_tday[,year-2002]<-ncvar_get(climatein,'pre_end1_tday')
  p_tday[,year-2002]<-ncvar_get(climatein,'p_tday')
  
  pre_start1_tnight[,year-2002]<-ncvar_get(climatein,'pre_start1_tnight')
  pre_end1_tnight[,year-2002]<-ncvar_get(climatein,'pre_end1_tnight')
  p_tnight[,year-2002]<-ncvar_get(climatein,'p_tnight')
  
  pre_start1_par[,year-2002]<-ncvar_get(climatein,'pre_start1_par')
  pre_end1_par[,year-2002]<-ncvar_get(climatein,'pre_end1_par')
  p_par[,year-2002]<-ncvar_get(climatein,'p_par')
  
  pre_start1_prec[,year-2002]<-ncvar_get(climatein,'pre_start1_prec')
  pre_end1_prec[,year-2002]<-ncvar_get(climatein,'pre_end1_prec')
  p_prec[,year-2002]<-ncvar_get(climatein,'p_prec')
  
  pre_start2_tday[,year-2002]<-ncvar_get(climatein,'pre_start2_tday')
  pre_end2_tday[,year-2002]<-ncvar_get(climatein,'pre_end2_tday')
  
  pre_start2_tnight[,year-2002]<-ncvar_get(climatein,'pre_start2_tnight')
  pre_end2_tnight[,year-2002]<-ncvar_get(climatein,'pre_end2_tnight')
  
  pre_start2_par[,year-2002]<-ncvar_get(climatein,'pre_start2_par')
  pre_end2_par[,year-2002]<-ncvar_get(climatein,'pre_end2_par')
  
  pre_start2_prec[,year-2002]<-ncvar_get(climatein,'pre_start2_prec')
  pre_end2_prec[,year-2002]<-ncvar_get(climatein,'pre_end2_prec')
  
  pre_start3_tday[,year-2002]<-ncvar_get(climatein,'pre_start3_tday')
  pre_end3_tday[,year-2002]<-ncvar_get(climatein,'pre_end3_tday')
  
  pre_start3_tnight[,year-2002]<-ncvar_get(climatein,'pre_start3_tnight')
  pre_end3_tnight[,year-2002]<-ncvar_get(climatein,'pre_end3_tnight')
  
  pre_start3_par[,year-2002]<-ncvar_get(climatein,'pre_start3_par')
  pre_end3_par[,year-2002]<-ncvar_get(climatein,'pre_end3_par')
  
  pre_start3_prec[,year-2002]<-ncvar_get(climatein,'pre_start3_prec')
  pre_end3_prec[,year-2002]<-ncvar_get(climatein,'pre_end3_prec')
  
  pre_start0_tday[,year-2002]<-ncvar_get(climatein,'pre_start0_tday')
  pre_end0_tday[,year-2002]<-ncvar_get(climatein,'pre_end0_tday')
  
  pre_start0_tnight[,year-2002]<-ncvar_get(climatein,'pre_start0_tnight')
  pre_end0_tnight[,year-2002]<-ncvar_get(climatein,'pre_end0_tnight')
  
  pre_start0_par[,year-2002]<-ncvar_get(climatein,'pre_start0_par')
  pre_end0_par[,year-2002]<-ncvar_get(climatein,'pre_end0_par')
  
  pre_start0_prec[,year-2002]<-ncvar_get(climatein,'pre_start0_prec')
  pre_end0_prec[,year-2002]<-ncvar_get(climatein,'pre_end0_prec')

  nc_close(climatein)
}

calculate_partial_correlation<-function(dat){
  if (sum(is.na(dat))>=1)
    return(c(NA,NA))
  n<-length(dat)
  dim(dat)<-c(14,n/14)
  pcor_re<-pcor.test(dat[,1],dat[,2],dat[,3:(n/14)],method="pearson")
  return(c(pcor_re$estimate,pcor_re$p.value))
}

calculate_correlation<-function(dat){
  if (sum(is.na(dat))>=1)
    return(c(NA,NA))
  dim(dat)<-c(14,2)
  cor_re<-cor.test(dat[,1],dat[,2],method="pearson")
  return(c(cor_re$estimate,cor_re$p.value))
}

calculate_multivariate_regression<-function(dat){
  if (sum(is.na(dat))>=1)
    return(rep(NA,5))
  n<-length(dat)
  dim(dat)<-c(14,n/14)
  reg_re<-lm(dat[,1]~dat[,2]+dat[,3]+dat[,4])
  return(c(reg_re$coefficients,summary(reg_re)$r.squared))
}

##### calculate correlation
cal_cor<-function(data,fileout){
  data[data< -990]<-NA
  cor_data<-apply(data,1,calculate_correlation)
  coef<-cor_data[1,]
  coef[is.nan(coef)]<- -999.9
  dim(coef)<-c(720,120)
  pv<-cor_data[2,]
  pv[is.nan(pv)]<- -999.9
  dim(pv)<-c(720,120)
  
  cor_coef<-ncvar_def("cor_coef",'',list(xdim,ydim),-999.9,prec="double",compression=9)
  cor_pv<-ncvar_def("cor_pv",'',list(xdim,ydim),-999.9,prec="double",compression=9)
  ncout<-nc_create(fileout,list(cor_coef,cor_pv))
  ncvar_put(ncout,cor_coef,coef)
  ncvar_put(ncout,cor_pv,pv)
  nc_close(ncout)
}

##### calculate partial correlation
cal_pcor<-function(data,fileout){
  data[data< -990]<-NA
  pcor_data<-apply(data,1,calculate_partial_correlation)
  pcoef<-pcor_data[1,]
  pcoef[is.nan(pcoef)]<- -999.9
  dim(pcoef)<-c(720,120)
  ppv<-pcor_data[2,]
  ppv[is.nan(ppv)]<- -999.9
  dim(ppv)<-c(720,120)
  
  pcor_coef<-ncvar_def("pcor_coef",'',list(xdim,ydim),-999.9,prec="double",compression=9)
  pcor_pv<-ncvar_def("pcor_pv",'',list(xdim,ydim),-999.9,prec="double",compression=9)
  ncout<-nc_create(fileout,list(pcor_coef,pcor_pv))
  ncvar_put(ncout,pcor_coef,pcoef)
  ncvar_put(ncout,pcor_pv,ppv)
  nc_close(ncout)
}

##### calculate multivariate regression
cal_reg<-function(data,fileout){
  data[data< -990]<-NA
  pcor_data<-apply(data,1,calculate_multivariate_regression)
  pcoef<-pcor_data[1:4,]
  pcoef[is.nan(pcoef)]<- -999.9
  dim(pcoef)<-c(4,720,120)
  ppv<-pcor_data[5,]
  ppv[is.nan(ppv)]<- -999.9
  dim(ppv)<-c(720,120)
  vdim<-ncdim_def("coef_id",units = "",vals = 1:4)
  reg_coef<-ncvar_def("regress_coef",'',list(vdim,xdim,ydim),-999.9,prec="double",compression=9)
  reg_rsq<-ncvar_def("regress_rsq",'',list(xdim,ydim),-999.9,prec="double",compression=9)
  ncout<-nc_create(fileout,list(reg_coef,reg_rsq))
  ncvar_put(ncout,reg_coef,pcoef)
  ncvar_put(ncout,reg_rsq,ppv)
  nc_close(ncout)
}

###### calculate the SOS effect on SIF EOS, etc
if (T){
  ##########calculate the pcor between sos and csif_P2S
  eos_csif<-cbind(sos,p2e_csif,s2e_tday,s2e_prec,s2e_par)
  fileout<-"./analysis/correlation_clear_rs/pcor_sos_csif_p2e.nc"
  cal_pcor(eos_csif,fileout)
  ###########################
  eos_csif<-cbind(sos,p2e_csif)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_csif_p2e.nc"
  cal_cor(eos_csif,fileout)
  
  ##########calculate the pcor between sos and csif_S2P
  
  sos_csif<-cbind(sos,s2p_csif,s2e_tday,s2p_prec,s2p_par)
  fileout<-"./analysis/correlation_clear_rs/pcor_sos_csif_s2p.nc"
  cal_pcor(sos_csif,fileout)
  
  #######################
  sos_csif<-cbind(sos,s2p_csif)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_csif_s2p.nc"
  cal_cor(sos_csif,fileout)
  
  ##########calculate the pcor between sos and csif_S2S
  sos_csif<-cbind(sos,s2e_csif,s2e_tday,s2e_prec)
  fileout<-"./analysis/correlation_clear_rs/pcor_sos_csif_s2e.nc"
  cal_pcor(sos_csif,fileout)
  
  
  #######################
  sos_csif<-cbind(sos,s2e_csif)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_csif_s2e.nc"
  cal_cor(sos_csif,fileout)
  
  
  ##########calculate the pcor between sos and eos
  sos_eos<-cbind(sos,eos,s2e_tday,s2e_prec,s2e_par)
  fileout<-"./analysis/correlation_clear_rs/pcor_sos_eos.nc"
  cal_pcor(sos_eos,fileout)
  
  ####################################
  sos_eos<-cbind(sos,eos)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_eos.nc"
  cal_cor(sos_eos,fileout)
}



###### calculate the controlling factors of SOS EOS
if (T){
  ##########calculate the cor between sos and eos and pre season tday
  sos_eos<-cbind(sos,pre_start1_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre1_tday.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start2_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre2_tday.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start3_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre3_tday.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start0_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre0_tday.nc"
  cal_cor(sos_eos,fileout)
  ####################################   Tnight
  sos_eos<-cbind(sos,pre_start1_tnight)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre1_tnight.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start2_tnight)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre2_tnight.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start3_tnight)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre3_tnight.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start0_tnight)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre0_tnight.nc"
  cal_cor(sos_eos,fileout)
  
  ####################################     Prec
  sos_eos<-cbind(sos,pre_start1_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre1_prec.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start2_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre2_prec.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start3_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre3_prec.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start0_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre0_prec.nc"
  cal_cor(sos_eos,fileout)
  
  ####################################     PAR
  sos_eos<-cbind(sos,pre_start1_par)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre1_par.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start2_par)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre2_par.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start3_par)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre3_par.nc"
  cal_cor(sos_eos,fileout)
  sos_eos<-cbind(sos,pre_start0_par)
  fileout<-"./analysis/correlation_clear_rs/cor_sos_pre0_par.nc"
  cal_cor(sos_eos,fileout)
}


if(T){

  ############ eos and late season temperature
  eos_eos<-cbind(eos,pre_end1_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre1_tday.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end2_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre2_tday.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end3_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre3_tday.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end0_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre0_tday.nc"
  cal_cor(eos_eos,fileout)
  ####################################   Tnight
  eos_eos<-cbind(eos,pre_end1_tnight)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre1_tnight.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end2_tnight)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre2_tnight.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end3_tnight)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre3_tnight.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end0_tnight)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre0_tnight.nc"
  cal_cor(eos_eos,fileout)
  
  ####################################     Prec
  eos_eos<-cbind(eos,pre_end1_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre1_prec.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end2_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre2_prec.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end3_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre3_prec.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end0_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre0_prec.nc"
  cal_cor(eos_eos,fileout)
  
  
  ####################################     PAR
  eos_eos<-cbind(eos,pre_end1_par)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre1_par.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end2_par)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre2_par.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end3_par)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre3_par.nc"
  cal_cor(eos_eos,fileout)
  eos_eos<-cbind(eos,pre_end0_par)
  fileout<-"./analysis/correlation_clear_rs/cor_eos_pre0_par.nc"
  cal_cor(eos_eos,fileout)

}


###
if (T){
  ##########calculate the pcor between eos and pre season tday
  cli_eos<-cbind(eos,pre_end1_tday,pre_end1_par,pre_end1_prec)
  fileout<-"./analysis/correlation_clear_rs/pcor_eos_pre1_tday.nc"
  cal_pcor(cli_eos,fileout)
  cli_eos<-cbind(eos,pre_end1_par,pre_end1_tday,pre_end1_prec)
  fileout<-"./analysis/correlation_clear_rs/pcor_eos_pre1_par.nc"
  cal_pcor(cli_eos,fileout)
  cli_eos<-cbind(eos,pre_end1_prec,pre_end1_par,pre_end1_tday)
  fileout<-"./analysis/correlation_clear_rs/pcor_eos_pre1_prec.nc"
  cal_pcor(cli_eos,fileout)
}


if (T){
  eos_csif<-cbind(eos-sos,s2e_tday)
  fileout<-"./analysis/correlation_clear_rs/cor_lgs_t_p2e.nc"
  cal_cor(eos_csif,fileout)
  eos_csif<-cbind(eos-sos,s2e_prec)
  fileout<-"./analysis/correlation_clear_rs/cor_lgs_p_p2e.nc"
  cal_cor(eos_csif,fileout)
  eos_csif<-cbind(eos-sos,s2e_par)
  fileout<-"./analysis/correlation_clear_rs/cor_lgs_r_p2e.nc"
  cal_cor(eos_csif,fileout)
}



setwd("/rigel/glab/users/zy2309/PROJECT/SIF_phenology")
sos_file<-'./analysis/clear_daily_SOS_30N_fixed_stat.nc'
pos_file<-"./analysis/clear_daily_POS_30N_fixed_stat.nc"
eos_file<-"./analysis/clear_daily_EOS_30N_fixed_stat.nc"

##### get average EOS and SOS
eos_f<-nc_open(eos_file)
eos_mean<-ncvar_get(eos_f,varid="MEAN")
xdim2<-eos_f$dim[["longitude"]]
ydim2<-eos_f$dim[["latitude"]]
nc_close(eos_f)
sos_f<-nc_open(sos_file)
sos_mean<-ncvar_get(sos_f,varid="MEAN")
nc_close(sos_f)
pos_f<-nc_open(pos_file)
pos_mean<-ncvar_get(pos_f,varid="MEAN")
nc_close(pos_f)
lgs_in_days<-rep(as.vector((eos_mean-sos_mean)*365),14)
dim(lgs_in_days)<-c(86400,14)
#################### regression analysis
if (T){
  eos_csif<-cbind((eos-sos),s2e_tday,s2e_prec*lgs_in_days,s2e_par)
  fileout<-"./analysis/correlation_clear_rs/reg_lgs_t_p_r_s2e.nc"
  cal_reg(eos_csif,fileout)
  eos_csif<-cbind(eos,pre_end1_tday,pre_end1_prec*30,pre_end1_par)
  fileout<-"./analysis/correlation_clear_rs/reg_eos_1mon_t_p_r.nc"
  cal_reg(eos_csif,fileout)
}



