####
library(maptools)
library(raster)
library(rgdal)



lc_type<-c("ENF","DBF","MF","WSA","OSH","GRA","WET")
lc_col<-c("palegreen4","yellowgreen","lightseagreen",
          "tan4","coral3","darkolivegreen",'royalblue4')

longlat <-  CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0")
ae<-"+proj=aeqd +lat_0=90 +lon_0=-0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"

# site_list<-read.csv("./retrieve_site/sites_used.csv",stringsAsFactors = F)
# site_list<-site_list[site_list$LOCATION_LAT>=35,]
# site_no<-dim(site_list)[1]
# write.csv(site_list,"./retrieve_site/sites_35N.csv",row.names = F)
setwd("/Users/yzhang/Project/SIF_phenology/")
site_list<-read.csv("./retrieve_site/sites_2000.csv",stringsAsFactors = F)
site_phenology<-read.csv("./retrieve_site/analysis/site_phenology_0.3_N30_clear_daily.csv",stringsAsFactors = F)
site_phenology_used<-site_phenology[!is.na(site_phenology$sos_gpp),]

######get the interannual variability
sites<-as.data.frame(table(site_phenology_used$site))
iav_sites<-sites$Var1[sites$Freq>=5]

ano_pheno<-as.data.frame(array(NA,dim=c(300,6)))
names(ano_pheno)<-c("site",'year','sos_gpp',"eos_gpp","sos_csif","eos_csif")
k=1
for(i in 1:length(iav_sites)){
  site_pheno<-site_phenology_used[site_phenology_used$site==iav_sites[i],]
  ano_pheno[k:(dim(site_pheno)[1]+k-1),1:2]<-site_pheno[,c(1,2)]
  ano_pheno$sos_gpp[k:(dim(site_pheno)[1]+k-1)]<-site_pheno$sos_gpp-mean(site_pheno$sos_gpp,na.rm=T)
  ano_pheno$eos_gpp[k:(dim(site_pheno)[1]+k-1)]<-site_pheno$eos_gpp-mean(site_pheno$eos_gpp,na.rm=T)
  ano_pheno$sos_csif[k:(dim(site_pheno)[1]+k-1)]<-site_pheno$sos_csif-mean(site_pheno$sos_csif,na.rm=T)
  ano_pheno$eos_csif[k:(dim(site_pheno)[1]+k-1)]<-site_pheno$eos_csif-mean(site_pheno$eos_csif,na.rm=T)
  k=k+dim(site_pheno)[1]
}
ano_pheno<-ano_pheno[!is.na(ano_pheno$site),]


comb_f<-list.files("./retrieve_site/combined_clear/",full.names = T)
for (i in 1:length(site_list$SITE_ID)){
  temp<-read.csv(comb_f[substr(basename(comb_f),1,6)==site_list$SITE_ID[i]],header = T)
  names(temp)[3]<-"CSIF"
  temp$igbp<-site_list$IGBP[i]
  years_used<-unique(site_phenology_used$year[site_phenology_used$site==site_list$SITE_ID[i]])
  data_used<-temp[!is.na(match(floor(temp$DATE/1000),years_used)),]
  #temp$nor_csif<-temp$CSIF/quantile(temp$CSIF,0.95,na.rm=T)
  #temp$nor_GPP<-temp$GPP_NT_VUT_REF/quantile(temp$GPP_NT_VUT_REF,0.95,na.rm=T)
  #temp$nor_ndvi<-temp$ndvi/quantile(temp$ndvi,0.95,na.rm=T)
  if (i==1){
    combined_data<-data_used
  }
  combined_data<-rbind(combined_data,data_used)
}

write.csv(combined_data,"./retrieve_site/analysis/combined_sites_data_clear.csv",row.names = F)

comb_data<-read.csv("./retrieve_site/analysis/combined_sites_data_clear.csv",stringsAsFactors = F)
good_obs<-comb_data[comb_data$NEE_VUT_REF_QC>0.8,]

lc_pch<-1:length(lc_type)
site_col<-lc_col[match(site_list$IGBP,lc_type)]
site_pch<-lc_pch[match(site_list$IGBP,lc_type)]

site_loc<-SpatialPoints(site_list[c(8,7)], proj4string=longlat)
proj_site<-spTransform(site_loc,ae)

longlat <-  CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0")
ae<-"+proj=aeqd +lat_0=90 +lon_0=-0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"


plot_lat<-function(lat){
  norths<-rep(lat,181)
  easts<- -90:90*2
  
  lati <- cbind(easts, norths)	
  lati <- rbind(lati, lati[1,])	# creates a matrix with two colums
  proj_lat <- SpatialPolygons(list(Polygons(list(Polygon(lati)), 1)))	# create a polygon from this matrix
  proj4string(proj_lat) <- longlat
  replat<-spTransform(proj_lat,ae)
  return(replat)
}

plot_long<-function(lon){
  # if (lon==-180){
  #   norths<- 10:16*5
  #   easts<- rep(lon,7)
  # }else{
  # 
  # }
  norths<- 6:16*5
  easts<- rep(lon,11)
  
  long <- cbind(easts, norths)	
  long <- rbind(long, long[1,])	# creates a matrix with two colums
  proj_lon <- SpatialPolygons(list(Polygons(list(Polygon(long)), 1)))	# create a polgon from this matrix
  proj4string(proj_lon) <- longlat
  replon<-spTransform(proj_lon,ae)
  return(replon)
}

plotlatlong<-function(){
  for (i in 3:8){
    prjlat<-plot_lat(i*10)
    lines(prjlat,lty=8,col='grey50',lwd=0.5)
  }
  
  for (i in -6:5){
    prolon<-plot_long(i*30)
    lines(prolon,lty=8,col='grey50',lwd=0.5)
  }
  
  lines(repcoa,col='black',lwd=0.2)
}



border<-plot_lat(30)
lat60<-plot_lat(60)

### coastlines
library(rgdal)
library(maptools)
library(rgeos)
library(raster)
land<-shapefile("/Users/yzhang/Data/GIS_data/global/ne_110m_land.shp")#ne_110m_coastline.shp")
repland<-gBuffer(spTransform(land,ae),byid=T,width=0)
bordercrop<-gBuffer(border,byid=T,width=0)
cropland<-intersect(repland,bordercrop)


###read the stat data
#cropcoast<-crop(coastline,extent(-180,180,30,90))
csif<-read.csv("/Users/yzhang/Project/SIF_phenology/analysis/csif_stat/CSIF.csv")
osif<-read.csv("/Users/yzhang/Project/SIF_phenology/analysis/csif_stat/OCO_2_SIF.csv")
ndvi<-read.csv('/Users/yzhang/Project/SIF_phenology/analysis/csif_stat/ndvi.csv')
evi<-read.csv('/Users/yzhang/Project/SIF_phenology/analysis/csif_stat/evi.csv')
csif_yd<-rep(2014:2017,each=92)*1000+rep(1:92*4,4)-2
csif_yd[c(92,184,276,368)]<-csif_yd[c(92,184,276,368)]-1
csif_date<-strptime(csif_yd,format = "%Y%j")

osif_yd<-osif$yearmonth*100+15
osif_date<-strptime(osif_yd,format= "%Y%m%d")

vi_yd<-rep(2014:2017,each=23)*1000+rep(1:23*16,4)-8
vi_date<-strptime(vi_yd,format = "%Y%j")
axis_yd<-2014:2018*10000+101
axis_date<-strptime(axis_yd,format= "%Y%m%d")
osif_yd<-osif$yearmonth*100+1
osif_axis<-strptime(osif_yd,format= "%Y%m%d")

data_col<-c("#E7003E","#FF7A00","#03899C","#5DE100")
pdf("/Users/yzhang/Dropbox/YAOZHANG/paper/2018_SIF_phenology/Fig1_mcd_0.3_30N_clear.pdf",width=11,height=11)

par(fig=c(0,1,0.66,1),mar=c(3.4,3.4,1.4,7.4),mgp=c(3,0.3,0),oma=c(1,1,1,1))

plot(NA,ylim=c(0,0.4),xlim=c(as.POSIXct(csif_date[1]),as.POSIXct(csif_date[368])),axes=F,xlab="",ylab="")
lines(osif_date,osif$all,col=data_col[1],lwd=3)
polygon(c(osif_date[c(1:43,45:48)],rev(osif_date[c(1:43,45:48)])),
        c(osif$all[c(1:43,45:48)]+osif$all_sd[c(1:43,45:48)],
          rev(osif$all[c(1:43,45:48)]-osif$all_sd[c(1:43,45:48)])),
        col=adjustcolor(data_col[1],alpha.f = 0.2),border = NA)
lines(csif_date,csif$all,col=adjustcolor(data_col[2],alpha.f = 0.7),lwd=3)
polygon(c(csif_date,rev(csif_date)),c(csif$all+csif$all_sd,rev(csif$all-csif$all_sd)),
        col=adjustcolor(data_col[2],alpha.f = 0.2),border = NA)

axis(2,las=2,at=c(0:4/10),tck = -0.02)
axis.POSIXct(1,at=axis_date,labels=format(axis_date,"%Y-%m-%d"),tck = -0.02)
axis.POSIXct(1,at=osif_axis,labels=rep("",48),tck = -0.01)
mtext(side=2,line=1.8,expression(paste("SIF (mW m"^-2,"nm"^-1,"sr"^-1,")",sep="")))
mtext(side=4,line=1.8,expression("NDVI"),col=data_col[3])
box()
par(new=T)
plot(NA,ylim=c(0.2,0.85),xlim=c(as.POSIXct(csif_date[1]),as.POSIXct(csif_date[368])),axes=F,xlab="",ylab="")
lines(vi_date,ndvi$all/10000,col=data_col[3],lwd=3)
# polygon(c(vi_date,rev(vi_date)),c(ndvi$all/10000+ndvi$all_sd/10000,rev(ndvi$all/10000-ndvi$all_sd/10000)),
#         col=adjustcolor('blue',alpha.f = 0.2),border = NA)
axis(4,las=2,at=c(2:9/10),tck = -0.02)
par(new=T)
plot(NA,ylim=c(0.1,0.5),xlim=c(as.POSIXct(csif_date[1]),as.POSIXct(csif_date[368])),axes=F,xlab="",ylab="")
lines(vi_date,evi$all/10000,col=data_col[4],lwd=3)
# polygon(c(vi_date,rev(vi_date)),c(evi$all/10000+evi$all_sd/10000,rev(evi$all/10000-evi$all_sd/10000)),
#         col=adjustcolor('darkgreen',alpha.f = 0.2),border = NA)
axis(4,line=3.5,las=2,at=c(1:5/10),tck = -0.02)
mtext(side=4,line=5.3,expression("EVI"),col=data_col[4])
mtext(side=2,line=2.5,'a',cex=1,font=2,padj=-11,las=2)
legend("topleft",c(expression('SIF'[OCO-2]),"CSIF","NDVI","EVI"),
       col=data_col,lty=c(1,1,1,1),lwd=c(3,3,3,3),bty="n")

#### -----------------------------------------
##  a
par(fig=c(0,0.33,0.33,0.66),mar=c(0.4,0.4,0.4,0.4),new=T)
plot(border)
plot(cropland,col='beige',lwd=0.2,add=T)
plotlatlong()


points(proj_site,col=site_col,pch=site_pch)
mtext(side=2,line=-0.5,"b",cex=1,font=2,padj=-13,las=2)
legend("bottomright",lc_type,col=lc_col,pch=lc_pch,cex=0.7,bg = 'white')

#### -----------------------------------------
##  b

par(fig=c(0,0.33,0,0.33),mar=c(3.4,3.4,1.4,1.4),new=T)
plot(NA,xlim=c(0, 1.),ylim=c(0,20),axes=F,xlab="",ylab="")
#plot(NA,xlim=c(0, 1.3),ylim=c(0,1.3),axes=F,xlab="",ylab="")
for (i in 1:7){
  biome_dat<-good_obs[good_obs$igbp==lc_type[i],]
  points(biome_dat$CSIF,biome_dat$GPP_NT_VUT_REF,col=lc_col[i],pch=lc_pch[i],cex=0.3)
  reg<-cor.test(biome_dat$CSIF,biome_dat$GPP_NT_VUT_REF)
  text(1.05,10-1.25*i,substitute(paste(italic(r),"=",a,sep=""),
                                 list(a=formatC(round(reg$estimate,2),format='f',digits = 2,flag="0"))),
       pos=2,col=lc_col[i])
}
axis(1,tck = -0.02)
axis(2,las=2,tck = -0.02,las=2)
mtext(side=1,line=1.8,expression(paste("CSIF (mW m"^-2,"nm"^-1,"sr"^-1,")",sep="")))
mtext(side=2,line=1.8,expression(paste("GPP (gC m"^-2,"day"^-1,")",sep="")))
mtext(side=2,line=2.5,'c',cex=1,font=2,padj=-11,las=2)
box()


#### -----------------------------------------
##  c
par(fig=c(0.33,0.66,0.33,0.66),mar=c(3.4,3.4,1.4,1.4),new=T)
plot(NA,xlim=c(0, 220),ylim=c(0,220),axes=F,xlab="",ylab="")
for (lc in 1:length(lc_type)){
  site_name_biome<-site_list$SITE_ID[site_list$IGBP==lc_type[lc]]
  biome_pheno<-site_phenology_used[!is.na(match(site_phenology_used$site,site_name_biome)),]
  points((biome_pheno$sos_gpp%%1)*365+2.5,(biome_pheno$sos_csif%%1)*365+2.5,col=lc_col[lc],pch=lc_pch[lc])
}
corr<-cor.test(site_phenology_used$sos_gpp%%1,site_phenology_used$sos_csif%%1)
reg<-lm(site_phenology_used$sos_gpp%%1~site_phenology_used$sos_csif%%1-1)
text(220,220/16*2.5,substitute(paste(italic(r),"=",a,'   n=',b,sep=""),
                               list(a=formatC(round(corr$estimate,2),format='f',digits = 2,flag="0"),
                                    b=corr$parameter)),
     pos=2)
text(220,220/16*1.5,substitute(paste("RMSE=",a,sep=""),
                               list(a=formatC(sqrt(mean((reg$residuals)^2))*365,2),
                                    format='f',digits = 2,flag="0")),
     pos=2)

axis(1,tck = -0.02)
axis(2,las=2,tck = -0.02)
box()
abline(0,1,lty=3,col="grey70")
mtext(side=1,line=1.8,expression("SOP"[EC]) )
mtext(side=2,line=1.8,expression("SOP"[CSIF]))
mtext(side=2,line=2.5,'d',cex=1,font=2,padj=-11,las=2)
#### -----------------------------------------
##  d
par(fig=c(0.33,0.66,0,0.33),mar=c(3.4,3.4,1.4,1.4),new=T)
plot(NA,xlim=c(150, 365),ylim=c(150,365),axes=F,xlab="",ylab="")
for (lc in 1:length(lc_type)){
  site_name_biome<-site_list$SITE_ID[site_list$IGBP==lc_type[lc]]
  biome_pheno<-site_phenology_used[!is.na(match(site_phenology_used$site,site_name_biome)),]
  points((biome_pheno$eos_gpp%%1)*365+2.5,(biome_pheno$eos_csif%%1)*365+2.5,col=lc_col[lc],pch=lc_pch[lc])
}
corr<-cor.test(site_phenology_used$eos_gpp%%1,site_phenology_used$eos_csif%%1)
reg<-lm(site_phenology_used$eos_gpp%%1~site_phenology_used$eos_csif%%1-1)
text(365,150+215/16*2.5,substitute(paste(italic(r),"=",a,'   n=',b,sep=""),
                                   list(a=formatC(round(corr$estimate,2),format='f',digits = 2,flag="0"),
                                        b=corr$parameter)),
     pos=2)
text(365,150+215/16*1.5,substitute(paste("RMSE=",a,sep=""),
                                   list(a=formatC(sqrt(mean((reg$residuals)^2))*365,2),
                                        format='f',digits = 2,flag="0")),
     pos=2)

axis(1,tck = -0.02)
axis(2,las=2,tck = -0.02)
box()
abline(0,1,lty=3,col="grey70")
mtext(side=1,line=1.8,expression("EOP"[EC]) )
mtext(side=2,line=1.8,expression("EOP"[CSIF]))
mtext(side=2,line=2.5,'e',cex=1,font=2,padj=-11,las=2)


#### -----------------------------------------
##  e
par(fig=c(0.66,1,0.33,0.66),mar=c(3.4,3.4,1.4,1.4),new=T)
plot(NA,xlim=c(-40, 40),ylim=c(-40,40),axes=F,xlab="",ylab="")
for (lc in 1:length(lc_type)){
  site_name_biome<-site_list$SITE_ID[site_list$IGBP==lc_type[lc]]
  biome_pheno<-ano_pheno[!is.na(match(ano_pheno$site,site_name_biome)),]
  points((biome_pheno$sos_gpp)*365,(biome_pheno$sos_csif)*365,col=lc_col[lc],pch=lc_pch[lc])
}
corr<-cor.test(ano_pheno$sos_gpp,ano_pheno$sos_csif)
reg<-lm(ano_pheno$sos_gpp~ano_pheno$sos_csif)
text(40,80/16*2.5-40,substitute(paste(italic(r),"=",a,'   n=',b,sep=""),
                               list(a=formatC(round(corr$estimate,2),format='f',digits = 2,flag="0"),
                                    b=corr$parameter)),
     pos=2)
text(40,80/16*1.5-40,substitute(paste("RMSE=",a,sep=""),
                               list(a=formatC(sqrt(mean((reg$residuals)^2))*365,2),
                                    format='f',digits = 2,flag="0")),
     pos=2)

axis(1,tck = -0.02)
axis(2,las=2,tck = -0.02)
box()
abline(0,1,lty=3,col="grey70")
mtext(side=1,line=1.8,expression("SOP"[EC]) )
mtext(side=2,line=1.8,expression("SOP"[CSIF]))
mtext(side=2,line=2.5,'f',cex=1,font=2,padj=-11,las=2)
#### -----------------------------------------
##  f
par(fig=c(0.66,1,0,0.33),mar=c(3.4,3.4,1.4,1.4),new=T)
plot(NA,xlim=c(-40, 40),ylim=c(-40,40),axes=F,xlab="",ylab="")
for (lc in 1:length(lc_type)){
  site_name_biome<-site_list$SITE_ID[site_list$IGBP==lc_type[lc]]
  biome_pheno<-ano_pheno[!is.na(match(ano_pheno$site,site_name_biome)),]
  points((biome_pheno$eos_gpp)*365,(biome_pheno$eos_csif)*365,col=lc_col[lc],pch=lc_pch[lc])
}
corr<-cor.test(ano_pheno$eos_gpp,ano_pheno$eos_csif)
reg<-lm(ano_pheno$eos_gpp~ano_pheno$eos_csif-1)
text(40,-40+80/16*2.5,substitute(paste(italic(r),"=",a,'   n=',b,sep=""),
                                   list(a=formatC(round(corr$estimate,2),format='f',digits = 2,flag="0"),
                                        b=corr$parameter)),
     pos=2)
text(40,-40+80/16*1.5,substitute(paste("RMSE=",a,sep=""),
                                   list(a=formatC(sqrt(mean((reg$residuals)^2))*365,2),format='f',digits = 2,flag="0")),
     pos=2)


axis(1,tck = -0.02)
axis(2,las=2,las=2,tck = -0.02)
box()
abline(0,1,lty=3,col="grey70")
mtext(side=1,line=1.8,expression("EOP"[EC]) )
mtext(side=2,line=1.8,expression("EOP"[CSIF]))
mtext(side=2,line=2.5,'g',cex=1,font=2,padj=-11,las=2)

dev.off()

