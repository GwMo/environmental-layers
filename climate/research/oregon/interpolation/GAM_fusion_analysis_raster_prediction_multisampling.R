##################    MULTI SAMPLING GAM FUSION METHOD ASSESSMENT ####################################
############################ Merging LST and station data ##########################################
#This script interpolates tmax values using MODIS LST and GHCND station data                      #
#interpolation area. It requires the text file of stations and a shape file of the study area.    #       
#Note that the projection for both GHCND and study area is lonlat WGS84.                          #
#AUTHOR: Benoit Parmentier                                                                        #
#DATE: 08/15/2012                                                                                 #
#PROJECT: NCEAS INPLANT: Environment and Organisms --TASK#363--                                   #
###################################################################################################

###Loading R library and packages                                                      
library(gtools)                                         # loading some useful tools 
library(mgcv)                                           # GAM package by Simon Wood
library(sp)                                             # Spatial pacakge with class definition by Bivand et al.
library(spdep)                               # Spatial pacakge with methods and spatial stat. by Bivand et al.
library(rgdal)                               # GDAL wrapper for R, spatial utilities
library(gstat)                               # Kriging and co-kriging by Pebesma et al.
library(fields)                              # NCAR Spatial Interpolation methods such as kriging, splines
library(raster)                              # Hijmans et al. package for raster processing
library(rasterVis)
library(parallel)                            # Urbanek S. and Ripley B., package for multi cores & parralel processing

### Parameters and argument

infile1<- "ghcn_or_tmax_covariates_06262012_OR83M.shp"             #GHCN shapefile containing variables for modeling 2010                 
#tinfile2<-"list_10_dates_04212012.txt"                     #List of 10 dates for the regression
infile2<-"list_2_dates_04212012.txt"
#infile2<-"list_365_dates_04212012.txt"
infile3<-"LST_dates_var_names.txt"                        #LST dates name
infile4<-"models_interpolation_05142012.txt"              #Interpolation model names
infile5<-"mean_day244_rescaled.rst"                       #Raster or grid for the locations of predictions
#infile6<-"lst_climatology.txt"
infile6<-"LST_files_monthly_climatology.txt"
inlistf<-"list_files_05032012.txt"                        #Stack of images containing the Covariates

#path<-"/home/parmentier/Data/IPLANT_project/data_Oregon_stations"
path<-"/home/parmentier/Data/IPLANT_project/methods_interpolation_comparison"
#path<-"/home/parmentier/Data/IPLANT_project/data_Oregon_stations_GAM"
#path<-"/home/parmentier/Data/IPLANT_project/data_Oregon_stations_07152012"     #Jupiter LOCATION on Atlas for kriging"
#path<-"M:/Data/IPLANT_project/data_Oregon_stations"   #Locations on Atlas

setwd(path)
#Station location of the study area
stat_loc<-read.table(paste(path,"/","location_study_area_OR_0602012.txt",sep=""),sep=",", header=TRUE)
#GHCN Database for 1980-2010 for study area (OR) 
data3<-read.table(paste(path,"/","ghcn_data_TMAXy1980_2010_OR_0602012.txt",sep=""),sep=",", header=TRUE)

nmodels<-8   #number of models running
y_var_name<-"dailyTmax"
predval<-1
prop<-0.3                                                                           #Proportion of testing retained for validation   
#prop<-0.25
seed_number<- 100  #if seedzero then no seed?                                                                 #Seed number for random sampling
out_prefix<-"_365d_GAM_fusion_multisamp2_0823012"                #User defined output prefix

bias_val<-0            #if value 1 then training data is used in the bias surface rather than the all monthly stations
nb_sample<-15
prop_min<-0.1
prop_max<-0.7
step<-0.1

#source("fusion_function_07192012.R")
source("GAM_fusion_function_multisampling_08232012.R")
############ START OF THE SCRIPT ##################
#
#
### Step 0/Step 6 in Brian's code...preparing year 2010 data for modeling 
#

###Reading the station data and setting up for models' comparison
filename<-sub(".shp","",infile1)             #Removing the extension from file.
ghcn<-readOGR(".", filename)                 #reading shapefile 

CRS<-proj4string(ghcn)                       #Storing projection information (ellipsoid, datum,etc.)

mean_LST<- readGDAL(infile5)                 #Reading the whole raster in memory. This provides a grid for kriging
proj4string(mean_LST)<-CRS                   #Assigning coordinate information to prediction grid.

ghcn <- transform(ghcn,Northness = cos(ASPECT*pi/180)) #Adding a variable to the dataframe
ghcn <- transform(ghcn,Eastness = sin(ASPECT*pi/180))  #adding variable to the dataframe.
ghcn <- transform(ghcn,Northness_w = sin(slope*pi/180)*cos(ASPECT*pi/180)) #Adding a variable to the dataframe
ghcn <- transform(ghcn,Eastness_w = sin(slope*pi/180)*sin(ASPECT*pi/180))  #adding variable to the dataframe.

#Remove NA for LC and CANHEIGHT
ghcn$LC1[is.na(ghcn$LC1)]<-0
ghcn$LC3[is.na(ghcn$LC3)]<-0
ghcn$CANHEIGHT[is.na(ghcn$CANHEIGHT)]<-0

dates <-readLines(paste(path,"/",infile2, sep=""))
LST_dates <-readLines(paste(path,"/",infile3, sep=""))
models <-readLines(paste(path,"/",infile4, sep=""))

##Extracting the variables values from the raster files                                             

lines<-read.table(paste(path,"/",inlistf,sep=""), sep=" ")                  #Column 1 contains the names of raster files
inlistvar<-lines[,1]
inlistvar<-paste(path,"/",as.character(inlistvar),sep="")
covar_names<-as.character(lines[,2])                                         #Column two contains short names for covaraites

s_raster<- stack(inlistvar)                                                  #Creating a stack of raster images from the list of variables.
layerNames(s_raster)<-covar_names                                            #Assigning names to the raster layers
projection(s_raster)<-CRS

#stat_val<- extract(s_raster, ghcn3)                                          #Extracting values from the raster stack for every point location in coords data frame.
pos<-match("ASPECT",layerNames(s_raster)) #Find column with name "value"
r1<-raster(s_raster,layer=pos)             #Select layer from stack
pos<-match("slope",layerNames(s_raster)) #Find column with name "value"
r2<-raster(s_raster,layer=pos)             #Select layer from stack
N<-cos(r1*pi/180)
E<-sin(r1*pi/180)
Nw<-sin(r2*pi/180)*cos(r1*pi/180)   #Adding a variable to the dataframe
Ew<-sin(r2*pi/180)*sin(r1*pi/180)   #Adding variable to the dataframe.

pos<-match("LC1",layerNames(s_raster)) #Find column with name "value"
LC1<-raster(s_raster,layer=pos)             #Select layer from stack
s_raster<-dropLayer(s_raster,pos)
LC1[is.na(LC1)]<-0
pos<-match("LC3",layerNames(s_raster)) #Find column with name "value"
LC3<-raster(s_raster,layer=pos)             #Select layer from stack
s_raster<-dropLayer(s_raster,pos)
LC3[is.na(LC3)]<-0
pos<-match("CANHEIGHT",layerNames(s_raster)) #Find column with name "value"
CANHEIGHT<-raster(s_raster,layer=pos)             #Select layer from stack
s_raster<-dropLayer(s_raster,pos)
CANHEIGHT[is.na(CANHEIGHT)]<-0

xy<-coordinates(r1)  #get x and y projected coordinates...
xy_latlon<-project(xy, CRS, inv=TRUE) # find lat long for projected coordinats (or pixels...)
lon<-raster(xy_latlon) #Transform a matrix into a raster object ncol=ncol(r1), nrow=nrow(r1))
ncol(lon)<-ncol(r1)
nrow(lon)<-nrow(r1)
extent(lon)<-extent(r1)
projection(lon)<-CRS  #At this stage this is still an empty raster with 536 nrow and 745 ncell 
lat<-lon
values(lon)<-xy_latlon[,1]
values(lat)<-xy_latlon[,2]

r<-stack(N,E,Nw,Ew,lon,lat,LC1,LC3,CANHEIGHT)
rnames<-c("Northness","Eastness","Northness_w","Eastness_w", "lon","lat","LC1","LC3","CANHEIGHT")
layerNames(r)<-rnames
s_raster<-addLayer(s_raster, r)

#s_sgdf<-as(s_raster,"SpatialGridDataFrame") #Conversion to spatial grid data frame

####### Preparing LST stack of climatology...

#l=list.files(pattern="mean_month.*rescaled.rst")
l <-readLines(paste(path,"/",infile6, sep=""))
molst<-stack(l)  #Creating a raster stack...
#setwd(old)
molst<-molst-273.16  #K->C          #LST stack of monthly average...
idx <- seq(as.Date('2010-01-15'), as.Date('2010-12-15'), 'month')
molst <- setZ(molst, idx)
layerNames(molst) <- month.abb


######  Preparing tables for model assessment: specific diagnostic/metrics

#Model assessment: specific diagnostics/metrics
results_AIC<- matrix(1,1,nmodels+3)  
results_GCV<- matrix(1,1,nmodels+3)
results_DEV<- matrix(1,1,nmodels+3)
#results_RMSE_f<- matrix(1,length(models)+3)

#Model assessment: general diagnostic/metrics 
results_RMSE <- matrix(1,1,nmodels+4)
results_MAE <- matrix(1,1,nmodels+4)
results_ME <- matrix(1,1,nmodels+4)       #There are 8+1 models
results_R2 <- matrix(1,1,nmodels+4)       #Coef. of determination for the validation dataset

results_RMSE_f<- matrix(1,1,nmodels+4)    #RMSE fit, RMSE for the training dataset
results_MAE_f <- matrix(1,1,nmodels+4)

######## Preparing monthly averages from the ProstGres database

# do this work outside of (before) this function
# to avoid making a copy of the data frame inside the function call
date1<-ISOdate(data3$year,data3$month,data3$day) #Creating a date object from 3 separate column
date2<-as.POSIXlt(as.Date(date1))
data3$date<-date2
d<-subset(data3,year>=2000 & mflag=="0" ) #Selecting dataset 2000-2010 with good quality: 193 stations
#May need some screeing??? i.e. range of temp and elevation...
d1<-aggregate(value~station+month, data=d, mean)  #Calculate monthly mean for every station in OR
id<-as.data.frame(unique(d1$station))     #Unique station in OR for year 2000-2010: 193 but 7 loss of monthly avg    

dst<-merge(d1, stat_loc, by.x="station", by.y="STAT_ID")   #Inner join all columns are retained

#This allows to change only one name of the data.frame
pos<-match("value",names(dst)) #Find column with name "value"
names(dst)[pos]<-c("TMax")
dst$TMax<-dst$TMax/10                #TMax is the average max temp for monthy data
#dstjan=dst[dst$month==9,]  #dst contains the monthly averages for tmax for every station over 2000-2010

######### Preparing daily values for training and testing

#Screening for bad values: value is tmax in this case
#ghcn$value<-as.numeric(ghcn$value)
ghcn_all<-ghcn
ghcn_test<-subset(ghcn,ghcn$value>-150 & ghcn$value<400)
ghcn_test2<-subset(ghcn_test,ghcn_test$ELEV_SRTM>0)
ghcn<-ghcn_test2
#coords<- ghcn[,c('x_OR83M','y_OR83M')]

##Sampling: training and testing sites.

#set.seed(seed_number)                        #Using a seed number allow results based on random number to be compared...
nel<-length(dates)
dates_list<-vector("list",nel) #list of one row data.frame

prop_range<-(seq(from=prop_min,to=prop_max,by=step))*100
sn<-length(dates)*nb_sample*length(prop_range)

for(i in 1:length(dates)){
  d_tmp<-rep(dates[i],nb_sample*length(prop_range)) #repeating same date
  s_nb<-rep(1:nb_sample,length(prop_range))         #number of random sample per proportion
  prop_tmp<-sort(rep(prop_range, nb_sample))
  tab_run_tmp<-cbind(d_tmp,s_nb,prop_tmp)
  dates_list[[i]]<-tab_run_tmp
}

sampling_dat<-as.data.frame(do.call(rbind,dates_list))
names(sampling_dat)<-c("date","run_samp","prop")

for(i in 2:3){            # start of the for loop #1
  sampling_dat[,i]<-as.numeric(as.character(sampling_dat[,i]))  
}

sampling_dat$date<- as.character(sampling_dat[,1])
#ghcn.subsets <-lapply(dates, function(d) subset(ghcn, date==d)) #this creates a list of 10 or 365 subsets dataset based on dates
ghcn.subsets <-lapply(as.character(sampling_dat$date), function(d) subset(ghcn, date==d)) #this creates a list of 10 or 365 subsets dataset based on dates
  
sampling<-vector("list",length(ghcn.subsets))

for(i in 1:length(ghcn.subsets)){
  n<-nrow(ghcn.subsets[[i]])
  prop<-(sampling_dat$prop[i])/100
  ns<-n-round(n*prop)   #Create a sample from the data frame with 70% of the rows
  nv<-n-ns              #create a sample for validation with prop of the rows
  ind.training <- sample(nrow(ghcn.subsets[[i]]), size=ns, replace=FALSE) #This selects the index position for 70% of the rows taken randomly
  ind.testing <- setdiff(1:nrow(ghcn.subsets[[i]]), ind.training)
  sampling[[i]]<-ind.training
}

######## Prediction for the range of dates and sampling data

#gam_fus_mod<-mclapply(1:length(dates), runGAMFusion,mc.preschedule=FALSE,mc.cores = 8) #This is the end bracket from mclapply(...) statement
#gam_fus_mod<-mclapply(1:1, runGAMFusion,mc.preschedule=FALSE,mc.cores = 8) #This is the end bracket from mclapply(...) statement
gam_fus_mod_s<-mclapply(1:length(ghcn.subsets), runGAMFusion,mc.preschedule=FALSE,mc.cores = 2) #This is the end bracket from mclapply(...) statement
#gam_fus_mod2<-mclapply(11:11, runGAMFusion,mc.preschedule=FALSE,mc.cores = 1) #This is the end bracket from mclapply(...) statement


## Plotting and saving diagnostic measures
accuracy_tab_fun<-function(i,f_list){
tb<-f_list[[i]][[3]]
return(tb)
}


tb<-gam_fus_mod_s[[1]][[3]][0,]  #empty data frame with metric table structure that can be used in rbinding...
tb_tmp<-gam_fus_mod_s #copy

for (i in 1:length(tb_tmp)){
  tmp<-tb_tmp[[i]][[3]]
  tb<-rbind(tb,tmp)
}
rm(tb_tmp)

for(i in 4:ncol(tb)){            # start of the for loop #1
  tb[,i]<-as.numeric(as.character(tb[,i]))  
}

metrics<-as.character(unique(tb$metric))
tb_metric_list<-vector("list",length(metrics))

for(i in 1:length(metrics)){            # start of the for loop #1  
  metric_name<-paste("tb_",metrics[i],sep="")
  tb_metric<-subset(tb, metric==metrics[i])
  tb_metric<-cbind(tb_metric,sampling_dat[,2:3])
  assign(metric_name,tb_metric)
  tb_metric_list[[i]]<-tb_metric
}

#tb_diagnostic1<-rbind(tb_RMSE,tb_MAE,tb_ME,tb_R2)
tb_diagnostic<-do.call(rbind,tb_metric_list)

avg_list<-vector("list",nmodels+1)

for (i in 1:(nmodels+1)){
  formag<-paste("mod",i,sep="")
  form<-as.formula(paste(formag,"~prop+metric"))
  avg_all1<-aggregate(form, data=tb_diagnostic, mean) 
  file<-paste("agg_metrics_",formag,out_prefix,".txt")
  write.table(avg_all1,file=file,sep=",")
  avg_list[[i]]<-avg_all1
}

test<-aggregate(mod9 ~ prop + metric + dates, data=tb_diagnostic, mean)
data_plot<-as.matrix(subset(avg_list[[9]],metric=="RMSE" & dates=="20100102"))

#x<- matrix(1,1,nmodels+3)  
y<- matrix(1,7,2)  

y[,1]<-as.numeric(data_plot[,4])
y[,2]<-as.numeric(data_plot[,5])

x<-cbind(unique(test$prop),unique(test$prop))
plot(x,y,col=c("red","blue"))
lines(x,y,col=c("red","blue"))
plot(data_plot[,4:5]~prop_t)

plot(x,y)
plot(prop,mod1,data=subset(test,metric=="RMSE" & dates=="20100101"))

write.table(tb_diagnostic, file= paste(path,"/","results2_fusion_Assessment_measure",out_prefix,".txt",sep=""), sep=",")
write.table(tb, file= paste(path,"/","results2_fusion_Assessment_measure_all",out_prefix,".txt",sep=""), sep=",")
save(gam_fus_mod_s,file= paste(path,"/","results2_fusion_Assessment_measure_all",out_prefix,".RData",sep=""))
#tb<-as.data.frame(tb_diagnostic1)

#write.table(tb_1, file= paste(path,"/","results2_fusion_Assessment_measure1",out_prefix,".txt",sep=""), sep=",")

#write.table(tb_diagnostic2, file= paste(path,"/","results_fusion_Assessment_measure2",out_prefix,".txt",sep=""), sep=",")

#### END OF SCRIPT