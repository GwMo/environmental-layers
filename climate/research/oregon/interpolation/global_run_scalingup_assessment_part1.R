####################################  INTERPOLATION OF TEMPERATURES  #######################################
############################  Script for assessment of scaling up on NEX: part 1 ##############################
#This script uses the worklfow code applied to the globe. Results currently reside on NEX/PLEIADES NASA.
#The purpose is to create as set of functions to diagnose and assess quickly a set of predictd tiles.
#Part 1 create summary tables and inputs files for figure in part 2 and part 3.
#AUTHOR: Benoit Parmentier 
#CREATED ON: 03/23/2014  
#MODIFIED ON: 12/28/2015            
#Version: 4
#PROJECT: Environmental Layers project  
#TO DO:
# - 
# - Make this a function...
# - Drop mosaicing from the script
#
#First source these files:
#Resolved call issues from R.
#source /nobackupp6/aguzman4/climateLayers/sharedModules2/etc/environ.sh  
#MODULEPATH=$MODULEPATH:/nex/modules/files
#module load pythonkits/gdal_1.10.0_python_2.7.3_nex

# These are the names and number for the current subset regions used for global runs:
#reg1 - North America (NAM)
#reg2 - Europe (WE)
#reg3 - Asia 
#reg4 - South America (SAM)
#reg5 - Africa (AF)
#reg6 - East Asia and Australia 

#################################################################################################

### Loading R library and packages        
#library used in the workflow production:
library(gtools)                              # loading some useful tools 
library(mgcv)                                # GAM package by Simon Wood
library(sp)                                  # Spatial pacakge with class definition by Bivand et al.
library(spdep)                               # Spatial pacakge with methods and spatial stat. by Bivand et al.
library(rgdal)                               # GDAL wrapper for R, spatial utilities
library(gstat)                               # Kriging and co-kriging by Pebesma et al.
library(fields)                              # NCAR Spatial Interpolation methods such as kriging, splines
library(raster)                              # Hijmans et al. package for raster processing
library(gdata)                               # various tools with xls reading, cbindX
library(rasterVis)                           # Raster plotting functions
library(parallel)                            # Parallelization of processes with multiple cores
library(maptools)                            # Tools and functions for sp and other spatial objects e.g. spCbind
library(maps)                                # Tools and data for spatial/geographic objects
library(reshape)                             # Change shape of object, summarize results 
library(plotrix)                             # Additional plotting functions
library(plyr)                                # Various tools including rbind.fill
library(spgwr)                               # GWR method
library(automap)                             # Kriging automatic fitting of variogram using gstat
library(rgeos)                               # Geometric, topologic library of functions
#RPostgreSQL                                 # Interface R and Postgres, not used in this script
library(gridExtra)
#Additional libraries not used in workflow
library(pgirmess)                            # Krusall Wallis test with mulitple options, Kruskalmc {pgirmess}  
library(colorRamps)
  
#### FUNCTION USED IN SCRIPT
  
function_analyses_paper1 <- "global_run_scalingup_assessment_part1_functions_02112015.R" #PARAM12
script_path <- "/nobackupp8/bparmen1/env_layers_scripts" #path to script
source(file.path(script_path,function_analyses_paper1)) #source all functions used in this script 

##############################
#### Parameters and constants  

#Make this a function
#reg1 (North Am), reg2(Europe),reg3(Asia), reg4 (South Am), reg5 (Africa), reg6 (Australia-Asia)
#master directory containing the definition of tile size and tiles predicted
in_dir1 <- "/nobackupp6/aguzman4/climateLayers/out/"
#/nobackupp6/aguzman4/climateLayers/out_15x45/1982

#region_names <- c("reg23","reg4") #selected region names, #PARAM2 
region_names <- c("reg4")
#region_names <- c("1992") #no specific region here so use date
#region_names <- c("reg1","reg2","reg3","reg4","reg5","reg6") #selected region names, #PARAM2
#region_namesb <- c("reg_1b","reg_1c","reg_2b","reg_3b","reg_6b") #selected region names, #PARAM2

y_var_name <- "dailyTmax" #PARAM3
interpolation_method <- c("gam_CAI") #PARAM4
out_prefix<-"run_global_analyses_pred_12282015" #PARAM5

#output_run10_1500x4500_global_analyses_pred_2003_04102015/

#out_dir<-"/data/project/layers/commons/NEX_data/" #On NCEAS Atlas
#out_dir <- "/nobackup/bparmen1/" #on NEX
out_dir <- "/nobackupp8/bparmen1/" #PARAM6
#out_dir <-paste(out_dir,"_",out_prefix,sep="")
create_out_dir_param <- TRUE #PARAM7

CRS_locs_WGS84 <- CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +towgs84=0,0,0") #Station coords WGS84, #PARAM8

#day_to_mosaic <- c("19920101","19920102","19920103,19920104,19920105")
#day_to_mosaic <- NULL #if day to mosaic is null then mosaic all dates?
year_predicted <- 1984:2004

file_format <- ".tif" #format for mosaiced files #PARAM10
NA_flag_val <- -9999  #No data value, #PARAM11
num_cores <- 6 #number of cores used #PARAM13

#Models used.
#list_models<-c("y_var ~ s(lat,lon,k=4) + s(elev_s,k=3) + s(LST,k=3)",
#               "y_var ~ s(lat,lon,k=5) + s(elev_s,k=3) + s(LST,k=3)",
#               "y_var ~ s(lat,lon,k=8) + s(elev_s,k=4) + s(LST,k=4)",
                                  
#module_path <- "/nobackupp6/aguzman4/climateLayers/sharedCode/" #PARAM14
#mosaics script #PARAM 15
#shell global mosaic script #PARAM 16
#gather station data

########################## START SCRIPT #########################################

#Need to make this a function to run as a job...

######################## PART0: Read content of predictions first.... #####


in_dir_list <- list.dirs(path=in_dir1,recursive=FALSE) #get the list regions processed for this run
#basename(in_dir_list)
in_dir_list<- lapply(region_names,FUN=function(x,y){y[grep(paste(x,"$",sep=""),basename(y),invert=FALSE)]},
                                               y=in_dir_list) 

in_dir_list_all  <- unlist(lapply(in_dir_list,function(x){list.dirs(path=x,recursive=F)}))
in_dir_list <- in_dir_list_all
#in_dir_list <- in_dir_list[grep("bak",basename(basename(in_dir_list)),invert=TRUE)] #the first one is the in_dir1

#this was changed on 10052015 because the shapefiles were not matching!!!
#in_dir_list_tmp <- list.dirs(path=in_dir1,recursive=FALSE) #get the list regions processed for this run
#in_dir_subset <- in_dir_list_tmp[grep("subset",basename(in_dir_list_tmp),invert=FALSE)] #select directory with shapefiles...
#in_dir_shp <- file.path(in_dir_subset,"shapefiles")
#in_dir_list_tmp <- list.dirs(path=in_dir1,recursive=FALSE) #get the list regions processed for this run
in_dir_subset <- in_dir_list_all[grep("subset",basename(in_dir_list_all),invert=FALSE)] #select directory with shapefiles...
in_dir_shp <- file.path(in_dir_subset,"shapefiles")


#select only directories used for predictions
in_dir_reg <- in_dir_list[grep(".*._.*.",basename(in_dir_list),invert=FALSE)] #select directory with shapefiles...
#in_dir_reg <- in_dir_list[grep("july_tiffs",basename(in_dir_reg),invert=TRUE)] #select directory with shapefiles...
in_dir_list <- in_dir_reg
    

in_dir_list <- in_dir_list[grep("bak",basename(basename(in_dir_list)),invert=TRUE)] #the first one is the in_dir1
#list of shapefiles used to define tiles
in_dir_shp_list <- list.files(in_dir_shp,".shp",full.names=T)

## load problematic tiles or additional runs
#modify later...

#system("ls /nobackup/bparmen1")

if(create_out_dir_param==TRUE){
  out_dir <- create_dir_fun(out_dir,out_prefix)
  setwd(out_dir)
}else{
  setwd(out_dir) #use previoulsy defined directory
}

setwd(out_dir)

##raster_prediction object : contains testing and training stations with RMSE and model object

list_raster_obj_files <- lapply(in_dir_list,FUN=function(x){list.files(path=x,pattern="^raster_prediction_obj.*.RData",full.names=T)})
basename(dirname(list_raster_obj_files[[1]]))
list_names_tile_coord <- lapply(list_raster_obj_files,FUN=function(x){basename(dirname(x))})
list_names_tile_id <- paste("tile",1:length(list_raster_obj_files),sep="_")
names(list_raster_obj_files)<- list_names_tile_id

lf_covar_obj <- lapply(in_dir_list,FUN=function(x){list.files(path=x,pattern="covar_obj.*.RData",full.names=T)})
lf_covar_tif <- lapply(in_dir_list,FUN=function(x){list.files(path=x,pattern="covar.*.tif",full.names=T)})

#sub_sampling_obj_daily_gam_CAI_10.0_-75.0.RData
#sub_sampling_obj_gam_CAI_10.0_-75.0.RData

lf_sub_sampling_obj_files <- lapply(in_dir_list,FUN=function(x){list.files(path=x,pattern=paste("^sub_sampling_obj_",interpolation_method,".*.RData",sep=""),full.names=T)})
lf_sub_sampling_obj_daily_files <- lapply(in_dir_list,FUN=function(x){list.files(path=x,pattern="^sub_sampling_obj_daily.*.RData",full.names=T)})

## This will be part of the raster_obj function
#debug(create_raster_prediction_obj)
#out_prefix_str <- paste(basename(in_dir_list),out_prefix,sep="_") 
#lf_raster_obj <- create_raster_prediction_obj(in_dir_list,interpolation_method, y_var_name,out_prefix_str,out_path_list=NULL)

################################################################
######## PART 1: Generate tables to collect information:
######## over all tiles in North America 

##Function to collect all the tables from tiles into a table
###Table 1: Average accuracy metrics
###Table 2: daily accuracy metrics for all tiles

#First create table of tiles under analysis and their coord
df_tile_processed <- data.frame(tile_coord=basename(in_dir_list))
df_tile_processed$tile_id <- unlist(list_names_tile_id) #Arbitrary tiling number!!
df_tile_processed$path_NEX <- in_dir_list
  
##Quick exploration of raster object
#Should be commented out to make this a function
robj1 <- try(load_obj(list_raster_obj_files[[3]])) #This is an example tile
#robj1 <- load_obj(lf_raster_obj[4]) #This is tile tile

names(robj1)
names(robj1$method_mod_obj[[2]]) #for January 1, 2010
names(robj1$method_mod_obj[[2]]$dailyTmax) #for January
names(robj1$method_mod_obj[[11]]) #for January 1, 2010
names(robj1$method_mod_obj[[11]]$dailyTmax) #for January

names(robj1$clim_method_mod_obj[[1]]$data_month) #for January
names(robj1$validation_mod_month_obj[[1]]$data_s) #for January with predictions
#Get the number of models predicted
nb_mod <- length(unique(robj1$tb_diagnostic_v$pred_mod))
list_formulas <- (robj1$clim_method_mod_obj[[1]]$formulas)
dates_predicted <- (unique(robj1$tb_diagnostic_v$date))


#list_tb_diagnostic_v <- mclapply(lf_validation_obj,FUN=function(x){try( x<- load_obj(x)); try(extract_from_list_obj(x,"metrics_v"))},mc.preschedule=FALSE,mc.cores = 6)                           
#names(list_tb_diagnostic_v) <- list_names_tile_id

################
#### Table 1: Average accuracy metrics per tile and predictions

#can use a maximum of 6 cores on the NEX Bridge
#For 43 tiles but only xx RData boject it takes xxx min
#summary_metrics_v_list <- mclapply(list_raster_obj_files[5:6],FUN=function(x){try( x<- load_obj(x)); try(x[["summary_metrics_v"]]$avg)},mc.preschedule=FALSE,mc.cores = 2)                           

summary_metrics_v_list <- mclapply(list_raster_obj_files,FUN=function(x){try( x<- load_obj(x)); try(x[["summary_metrics_v"]]$avg)},mc.preschedule=FALSE,mc.cores = num_cores)                         
#summary_metrics_v_list <- lapply(summary_metrics_v_list,FUN=function(x){try(x$avg)})
names(summary_metrics_v_list) <- list_names_tile_id

summary_metrics_v_tmp <- remove_from_list_fun(summary_metrics_v_list)$list
df_tile_processed$metrics_v <- as.integer(remove_from_list_fun(summary_metrics_v_list)$valid)
#Now remove "try-error" from list of accuracy)

summary_metrics_v_NA <- do.call(rbind.fill,summary_metrics_v_tmp) #create a df for NA tiles with all accuracy metrics
#tile_coord <- lapply(1:length(summary_metrics_v_list),FUN=function(i,x){rep(names(x)[i],nrow(x[[i]]))},x=summary_metrics_v_list)
#add the tile id identifier
tile_id_tmp <- lapply(1:length(summary_metrics_v_tmp),
                     FUN=function(i,x,y){rep(y[i],nrow(x[[i]]))},x=summary_metrics_v_tmp,y=names(summary_metrics_v_tmp))
#adding tile id summary data.frame
summary_metrics_v_NA$tile_id <-unlist(tile_id_tmp)
summary_metrics_v_NA$n <- as.integer(summary_metrics_v_NA$n)

summary_metrics_v_NA <- merge(summary_metrics_v_NA,df_tile_processed[,1:2],by="tile_id")

tx<-strsplit(as.character(summary_metrics_v_NA$tile_coord),"_")
lat<- as.numeric(lapply(1:length(tx),function(i,x){x[[i]][1]},x=tx))
long<- as.numeric(lapply(1:length(tx),function(i,x){x[[i]][2]},x=tx))
summary_metrics_v_NA$lat <- lat
summary_metrics_v_NA$lon <- long

write.table(as.data.frame(summary_metrics_v_NA),
            file=file.path(out_dir,paste("summary_metrics_v2_NA_",out_prefix,".txt",sep="")),sep=",")

#################
###Table 2: daily validation/testing accuracy metrics for all tiles
#this takes about 55min
#tb_diagnostic_v_list <- lapply(list_raster_obj_files,FUN=function(x){x<-load_obj(x);x[["tb_diagnostic_v"]]})                           
tb_diagnostic_v_list <- mclapply(list_raster_obj_files,FUN=function(x){try(x<-load_obj(x));try(x[["tb_diagnostic_v"]])},mc.preschedule=FALSE,mc.cores = num_cores)                           

names(tb_diagnostic_v_list) <- list_names_tile_id
tb_diagnostic_v_tmp <- remove_from_list_fun(tb_diagnostic_v_list)$list
#df_tile_processed$tb_diag <- remove_from_list_fun(tb_diagnostic_v_list)$valid

tb_diagnostic_v_NA <- do.call(rbind.fill,tb_diagnostic_v_tmp) #create a df for NA tiles with all accuracy metrics
tile_id_tmp <- lapply(1:length(tb_diagnostic_v_tmp),
                     FUN=function(i,x,y){rep(y[i],nrow(x[[i]]))},x=tb_diagnostic_v_tmp,y=names(tb_diagnostic_v_tmp))

tb_diagnostic_v_NA$tile_id <- unlist(tile_id_tmp) #adding identifier for tile

tb_diagnostic_v_NA <- merge(tb_diagnostic_v_NA,df_tile_processed[,1:2],by="tile_id")

write.table((tb_diagnostic_v_NA),
            file=file.path(out_dir,paste("tb_diagnostic_v_NA","_",out_prefix,".txt",sep="")),sep=",")

#################
###Table 3: monthly fit/training accuracy information for all tiles

## Monthly fitting information
tb_month_diagnostic_s_list <- mclapply(list_raster_obj_files,FUN=function(x){try(x<-load_obj(x));try(x[["tb_month_diagnostic_s"]])},mc.preschedule=FALSE,mc.cores = num_cores)                           

names(tb_month_diagnostic_s_list) <- list_names_tile_id
tb_month_diagnostic_s_tmp <- remove_from_list_fun(tb_month_diagnostic_s_list)$list
#df_tile_processed$tb_diag <- remove_from_list_fun(tb_diagnostic_v_list)$valid

tb_month_diagnostic_s_NA <- do.call(rbind.fill,tb_month_diagnostic_s_tmp) #create a df for NA tiles with all accuracy metrics
tile_id_tmp <- lapply(1:length(tb_month_diagnostic_s_tmp),
                     FUN=function(i,x,y){rep(y[i],nrow(x[[i]]))},x=tb_month_diagnostic_s_tmp,y=names(tb_month_diagnostic_s_tmp))

tb_month_diagnostic_s_NA$tile_id <- unlist(tile_id_tmp) #adding identifier for tile

tb_month_diagnostic_s_NA <- merge(tb_month_diagnostic_s_NA,df_tile_processed[,1:2],by="tile_id")

date_f<-strptime(tb_month_diagnostic_s_NA$date, "%Y%m%d")   # interpolation date being processed
tb_month_diagnostic_s_NA$month<-strftime(date_f, "%m")          # current month of the date being processed

write.table((tb_month_diagnostic_s_NA),
            file=file.path(out_dir,paste("tb_month_diagnostic_s_NA","_",out_prefix,".txt",sep="")),sep=",")

#################
###Table 4: daily fit/training accuracy information with predictions for all tiles

## daily fit info:

tb_diagnostic_s_list <- mclapply(list_raster_obj_files,FUN=function(x){try(x<-load_obj(x));try(x[["tb_diagnostic_s"]])},mc.preschedule=FALSE,mc.cores = num_cores)                           

names(tb_diagnostic_s_list) <- list_names_tile_id
tb_diagnostic_s_tmp <- remove_from_list_fun(tb_diagnostic_s_list)$list
#df_tile_processed$tb_diag <- remove_from_list_fun(tb_diagnostic_v_list)$valid

tb_diagnostic_s_NA <- do.call(rbind.fill,tb_diagnostic_s_tmp) #create a df for NA tiles with all accuracy metrics
tile_id_tmp <- lapply(1:length(tb_diagnostic_s_tmp),
                     FUN=function(i,x,y){rep(y[i],nrow(x[[i]]))},x=tb_diagnostic_s_tmp,y=names(tb_diagnostic_s_tmp))

tb_diagnostic_s_NA$tile_id <- unlist(tile_id_tmp) #adding identifier for tile

tb_diagnostic_s_NA <- merge(tb_diagnostic_s_NA,df_tile_processed[,1:2],by="tile_id")

write.table((tb_diagnostic_s_NA),
            file=file.path(out_dir,paste("tb_diagnostic_s_NA","_",out_prefix,".txt",sep="")),sep=",")

##### Table 5: Add later on: daily info
### with also data_s and data_v saved!!!

#Insert here...compute input and predicted ranges to spot potential errors?

### Make this part a function...this is repetitive
##### SPDF of Monhtly Station info
#load data_month for specific tiles
#10.45pm
#data_month <- extract_from_list_obj(robj1$clim_method_mod_obj,"data_month")
#names(data_month) #this contains LST means (mm_1, mm_2 etc.) as well as TMax and other info

#data_month_s_list <- mclapply(list_raster_obj_files,FUN=function(x){try(x<-load_obj(x));try(x$validation_mod_month_obj[["data_s"]])},mc.preschedule=FALSE,mc.cores = 6)                           
data_month_s_list <- mclapply(list_raster_obj_files,FUN=function(x){try(x<-load_obj(x));try(extract_from_list_obj(x$validation_mod_month_obj,"data_s"))},mc.preschedule=FALSE,mc.cores = 6)                           
#test <- mclapply(list_raster_obj_files[1:6],FUN=function(x){try(x<-load_obj(x));try(extract_from_list_obj(x$validation_mod_month_obj,"data_s"))},mc.preschedule=FALSE,mc.cores = 6)                           

names(data_month_s_list) <- list_names_tile_id

data_month_tmp <- remove_from_list_fun(data_month_s_list)$list
#df_tile_processed$metrics_v <- remove_from_list_fun(data_month_s_list)$valid

tile_id <- lapply(1:length(data_month_tmp),
                  FUN=function(i,x){rep(names(x)[i],nrow(x[[i]]))},x=data_month_tmp)
data_month_NAM <- do.call(rbind.fill,data_month_tmp) #combined data_month for "NAM" North America
data_month_NAM$tile_id <- unlist(tile_id)

write.table((data_month_NAM),
            file=file.path(out_dir,paste("data_month_s_NAM","_",out_prefix,".txt",sep="")),sep=",")

#Get validation data?? Find other object from within the dir 
#Som region don't have validation data at monthly time scale.

#### SPDF of daily Station info
#load data_month for specific tiles
#data_month <- extract_from_list_obj(robj1$clim_method_mod_obj,"data_month")
#names(data_month) #this contains LST means (mm_1, mm_2 etc.) as well as TMax and other info

data_day_s_list <- mclapply(list_raster_obj_files,FUN=function(x){try(x<-load_obj(x));try(extract_from_list_obj(x$validation_mod_obj,"data_s"))},mc.preschedule=FALSE,mc.cores = num_cores)    
data_day_v_list <- mclapply(list_raster_obj_files,FUN=function(x){try(x<-load_obj(x));try(extract_from_list_obj(x$validation_mod_obj,"data_v"))},mc.preschedule=FALSE,mc.cores = num_cores)    

names(data_day_s_list) <- list_names_tile_id
names(data_day_v_list) <- list_names_tile_id

data_day_s_tmp <- remove_from_list_fun(data_day_s_list)$list
data_day_v_tmp <- remove_from_list_fun(data_day_v_list)$list

#df_tile_processed$metrics_v <- remove_from_list_fun(data_month_s_list)$valid

tile_id <- lapply(1:length(data_day_s_tmp),
                  FUN=function(i,x){rep(names(x)[i],nrow(x[[i]]))},x=data_day_s_tmp)
data_day_s_NAM <- do.call(rbind.fill,data_day_s_tmp) #combined data_month for "NAM" North America
data_day_s_NAM$tile_id <- unlist(tile_id)

tile_id <- lapply(1:length(data_day_v_tmp),
                  FUN=function(i,x){rep(names(x)[i],nrow(x[[i]]))},x=data_day_v_tmp)
data_day_v_NAM <- do.call(rbind.fill,data_day_v_tmp) #combined data_month for "NAM" North America
data_day_v_NAM$tile_id <- unlist(tile_id)

write.table((data_day_s_NAM),
            file=file.path(out_dir,paste("data_day_s_NAM","_",out_prefix,".txt",sep="")),sep=",")
write.table((data_day_v_NAM),
            file=file.path(out_dir,paste("data_day_v_NAM","_",out_prefix,".txt",sep="")),sep=",")

#### Recover subsampling data
#For tiles with many stations, there is a subsampling done in terms of distance (spatial pruning) and 
#in terms of station numbers if there are still too many stations to consider. This is done at the 
#daily and monthly stages.

#lf_sub_sampling_obj_files <- lapply(in_dir_list,FUN=function(x){list.files(path=x,pattern=paste("^sub_sampling_obj_",interpolation_method,".*.RData",sep=""),full.names=T)})
#lf_sub_sampling_obj_daily_files <- lapply(in_dir_list,FUN=function(x){list.files(path=x,pattern="^sub_sampling_obj_daily.*.RData",full.names=T)})
#sub_sampling_obj <- try(load_obj(lf_sub_sampling_obj_files[[3]])) #This is an example tile
#data_removed contains the validation data...
#this data can be used for validation of the product. Note that it may be missing for some tiles
#as no stations are removed if there are too enough stations in the tile
#this will need to be checked later on...

data_month_v_subsampling_list <- mclapply(lf_sub_sampling_obj_files,FUN=function(x){try(x<-load_obj(x));try(extract_from_list_obj(x$validation_mod_month_obj,"data_removed"))},mc.preschedule=FALSE,mc.cores = 6)                           
#test <- mclapply(list_raster_obj_files[1:6],FUN=function(x){try(x<-load_obj(x));try(extract_from_list_obj(x$validation_mod_month_obj,"data_s"))},mc.preschedule=FALSE,mc.cores = 6)                           

names(data_month_v_subsampling_list) <- list_names_tile_id

data_month_v_subsampling_tmp <- remove_from_list_fun(data_month_v_subsampling_list)$list
#df_tile_processed$metrics_v <- remove_from_list_fun(data_month_s_list)$valid
#if no stations have been removed then there are no validation stations !!!
if(length(data_month_v_subsampling_tmp)!=0){
  
  tile_id <- lapply(1:length(data_month_v_subsampling_tmp),
                  FUN=function(i,x){try(rep(names(x)[i],nrow(x[[i]])))},x=data_month_v_subsampling_tmp)
  data_month_v_subsmapling_NAM <- do.call(rbind.fill,ddata_month_v_subsampling_tmp) #combined data_month for "NAM" North America
  data_month_v_subsampling_NAM$tile_id <- unlist(tile_id)

  write.table((data_month_v_subsampling_NAM),
            file=file.path(out_dir,paste("data_month_v_subsampling_NAM","_",out_prefix,".txt",sep="")),sep=",")

}

## Do the same for daily...
## End of potential function started in line 317...this section will be cut down for simplicity

######################################################
####### PART 3: EXAMINE STATIONS AND MODEL FITTING ###

### Stations and model fitting ###
#summarize location and number of training and testing used by tiles

names(robj1$clim_method_mod_obj[[1]]$data_month) # monthly data for January
#names(robj1$validation_mod_month_obj[[1]]$data_s) # daily for January with predictions
#note that there is no holdout in the current run at the monthly time scale:

robj1$clim_method_mod_obj[[1]]$data_month_v #zero rows for testing stations at monthly timescale
#load data_month for specific tiles
data_month <- extract_from_list_obj(robj1$clim_method_mod_obj,"data_month")

names(data_month) #this contains LST means (mm_1, mm_2 etc.) as well as TMax and other info

use_day=TRUE
use_month=TRUE
 
#list_raster_obj_files <- c("/data/project/layers/commons/NEX_data/output_run3_global_analyses_06192014/output10Deg/reg1//30.0_-100.0/raster_prediction_obj_gam_CAI_dailyTmax30.0_-100.0.RData",
#                    "/data/project/layers/commons/NEX_data/output_run3_global_analyses_06192014/output10Deg/reg1//30.0_-105.0/raster_prediction_obj_gam_CAI_dailyTmax30.0_-105.0.RData")

list_names_tile_id <- df_tile_processed$tile_id
list_raster_obj_files[list_names_tile_id]
#list_names_tile_id <- c("tile_1","tile_2")
list_param_training_testing_info <- list(list_raster_obj_files[list_names_tile_id],use_month,use_day,list_names_tile_id)
names(list_param_training_testing_info) <- c("list_raster_obj_files","use_month","use_day","list_names_tile_id")
 
list_param <- list_param_training_testing_info
#debug(extract_daily_training_testing_info)
#pred_data_info <- extract_daily_training_testing_info(1,list_param=list_param_training_testing_info)
pred_data_info <- mclapply(1:length(list_raster_obj_files[list_names_tile_id]),FUN=extract_daily_training_testing_info,list_param=list_param_training_testing_info,mc.preschedule=FALSE,mc.cores = num_cores)
#pred_data_info <- mclapply(1:length(list_raster_obj_files[list_names_tile_id][1:6]),FUN=extract_daily_training_testing_info,list_param=list_param_training_testing_info,mc.preschedule=FALSE,mc.cores = 6)
#pred_data_info <- lapply(1:length(list_raster_obj_files),FUN=extract_daily_training_testing_info,list_param=list_param_training_testing_info)
#pred_data_info <- lapply(1:length(list_raster_obj_files[1]),FUN=extract_daily_training_testing_info,list_param=list_param_training_testing_info)

pred_data_info_tmp <- remove_from_list_fun(pred_data_info)$list #remove data not predicted
##Add tile nanmes?? it is alreaready there
#names(pred_data_info)<-list_names_tile_id
pred_data_month_info <- do.call(rbind,lapply(pred_data_info_tmp,function(x){x$pred_data_month_info}))
pred_data_day_info <- do.call(rbind,lapply(pred_data_info_tmp,function(x){x$pred_data_day_info}))

#putput inforamtion in csv !!
write.table(pred_data_month_info,
            file=file.path(out_dir,paste("pred_data_month_info_",out_prefix,".txt",sep="")),sep=",")
write.table(pred_data_day_info,
            file=file.path(out_dir,paste("pred_data_day_info_",out_prefix,".txt",sep="")),sep=",")

######################################################
####### PART 4: Get shapefile tiling with centroids ###

#get shape files for the region being assessed:

list_shp_world <- list.files(path=in_dir_shp,pattern=".*.shp",full.names=T)
l_shp <- gsub(".shp","",basename(list_shp_world))
l_shp <- sub("shp_","",l_shp)

#l_shp <- unlist(lapply(1:length(list_shp_world),
#                       FUN=function(i){paste(strsplit(list_shp_world[i],"_")[[1]][3:4],collapse="_")}))
l_shp <- unlist(lapply(1:length(l_shp),
                       FUN=function(i){paste(strsplit(l_shp[i],"_")[[1]][1:2],collapse="_")}))

df_tiles_all <- as.data.frame(as.character(unlist(list_shp_world)))
df_tiles_all$tile_coord <- l_shp
#names(df_tiles_all) <- "list_shp_world"
names(df_tiles_all) <- c("shp_files","tile_coord")
matching_index <- match(basename(in_dir_list),l_shp)
list_shp_reg_files <- list_shp_world[matching_index]
df_tile_processed$shp_files <-list_shp_reg_files
#df_tile_processed$shp_files <- ""
#df_tile_processed$tile_coord <- as.character(df_tile_processed$tile_coord)
#test <- df_tile_processed
#test$shp_files <- NULL
#test3 <- merge(test,df_tiles_all,by=c("tile_coord"))
#test3 <- merge(df_tiles_all,test,by=c("tile_coord"))
#merge(df_tile_processed,df_tiles_all,by="shp_files")

tx<-strsplit(as.character(df_tile_processed$tile_coord),"_")
lat<- as.numeric(lapply(1:length(tx),function(i,x){x[[i]][1]},x=tx))
long<- as.numeric(lapply(1:length(tx),function(i,x){x[[i]][2]},x=tx))
df_tile_processed$lat <- lat
df_tile_processed$lon <- long

#put that list in the df_processed and also the centroids!!
write.table(df_tile_processed,
            file=file.path(out_dir,paste("df_tile_processed_",out_prefix,".txt",sep="")),sep=",")


write.table(df_tiles_all,
            file=file.path(out_dir,paste("df_tiles_all_",out_prefix,".txt",sep="")),sep=",")

#Copy to local home directory on NAS-NEX
#
dir.create(file.path(out_dir,"shapefiles"))
file.copy(list_shp_world,file.path(out_dir,"shapefiles"))

#save a list of all files...
write.table(df_tiles_all,
            file=file.path(out_dir,"shapefiles",paste("df_tiles_all_",out_prefix,".txt",sep="")),sep=",")

########### LAST PART: COPY SOME DATA BACK TO ATLAS #####

#This will be a separate script?? or function?
#this part cannot be automated...

### This assumes the tree structure has been replicated on Atlas:
#for i in 1:length(df_tiled_processed$tile_coord)
#output_atlas_dir <- "/data/project/layers/commons/NEX_data/output_run3_global_analyses_06192014/output10Deg/reg1"
#output_atlas_dir <- "/data/project/layers/commons/NEX_data/output_run5_global_analyses_08252014/output20Deg"
output_atlas_dir <- file.path("/data/project/layers/commons/NEX_data/",out_dir)

#output_run10_1500x4500_global_analyses_pred_1992_10052015
#Make directories on ATLAS
#for (i in 1:length(df_tile_processed$tile_coord)){
#  create_dir_fun(file.path(output_atlas_dir,as.character(df_tile_processed$tile_coord[i])),out_suffix=NULL)
#}  

#Make directories on ATLAS for shapefiles
#for (i in 1:length(df_tile_processed$tile_coord)){
#  create_dir_fun(file.path(output_atlas_dir,as.character(df_tile_processed$tile_coord[i]),"/shapefiles"),out_suffix=NULL)
#}  

### Create dir locally and on Atlas

Atlas_dir <- file.path("/data/project/layers/commons/NEX_data/",basename(out_dir))#,"output/subset/shapefiles")
#Atlas_hostname <- "parmentier@atlas.nceas.ucsb.edu"
#cmd_str <- paste("ssh ",Atlas_hostname,"mkdir",Atlas_dir, sep=" ")

#Atlas_dir_mosaic <- file.path("/data/project/layers/commons/NEX_data/",basename(out_dir),"mosaics")
#Atlas_hostname <- "parmentier@atlas.nceas.ucsb.edu"
#cmd_str <- paste("ssh ",Atlas_hostname,"mkdir",Atlas_dir_mosaic, sep=" ")

#Atlas_dir_shapefiles <- file.path("/data/project/layers/commons/NEX_data/",basename(out_dir),"shapefiles")
Atlas_hostname <- "parmentier@atlas.nceas.ucsb.edu"
#cmd_str <- paste("ssh ",Atlas_hostname,"mkdir",Atlas_dir_shapefiles, sep=" ")

#locally on NEX
#cmd_str <- paste(" mkdir ",out_dir,"/{mosaic,shapefiles,tiles}", sep="")
cmd_str <- paste(" mkdir ",out_dir,"/{mosaic,tiles}", sep="") #create both dir 
system(cmd_str)

#create remotely on Atlas
cmd_str <- paste("ssh ",Atlas_hostname," mkdir ",Atlas_dir,"/{/,mosaic,shapefiles,tiles}", sep="")
system(cmd_str)

#Copy summary textfiles back to atlas

Atlas_dir <- file.path("/data/project/layers/commons/NEX_data/",basename(out_dir))#,"output/subset/shapefiles")
Atlas_hostname <- "parmentier@atlas.nceas.ucsb.edu"
lf_cp_f <- list.files(out_dir,full.names=T,pattern="*.txt")#copy all files can filter later
filenames_NEX <- paste(lf_cp_f,collapse=" ")  #copy raster prediction object
cmd_str <- paste("scp -p",filenames_NEX,paste(Atlas_hostname,Atlas_dir,sep=":"), sep=" ")
system(cmd_str)

#cp -rp ./*/gam_CAI_dailyTmax_predicted_mod1_0_1_19920103_30_*.tif /nobackupp8/bparmen1//output_run10_1500x4500_global_analyses_pred_1992_10052015/tiles
#system("scp -p ./*.txt parmentier@atlas.nceas.ucsb.edu:/data/project/layers/commons/NEX_data/output_run6_global_analyses_09162014")
#system("scp -p ./*.txt ./*.tif parmentier@atlas.nceas.ucsb.edu:/data/project/layers/commons/NEX_data/output_run2_global_analyses_05122014")

#### COPY SHAPEFILES, TIF MOSAIC, COMBINED TEXT FILES etc...

#Copy all shapefiles in one unique directory

Atlas_dir <- file.path("/data/project/layers/commons/NEX_data/",basename(out_dir),"shapefiles")
Atlas_hostname <- "parmentier@atlas.nceas.ucsb.edu"
lf_cp_shp <- df_tile_processed$shp_files #get all the files...
list_shp_world
lf_cp_shp_pattern <- gsub(".shp","*",basename(lf_cp_shp))
lf_cp_shp_pattern <- file.path(dirname(lf_cp_shp),lf_cp_shp_pattern)

filenames_NEX <- paste(lf_cp_shp_pattern,collapse=" ")  #copy raster prediction object

cmd_str <- paste("scp -p",filenames_NEX,paste(Atlas_hostname,Atlas_dir,sep=":"), sep=" ")
system(cmd_str)

###### COPY MOSAIC files

#Copy region mosaics back to atlas

Atlas_dir <- file.path("/data/project/layers/commons/NEX_data/",basename(out_dir),"mosaics")
Atlas_hostname <- "parmentier@atlas.nceas.ucsb.edu"
lf_cp_f <- list.files(out_dir,full.names=T,pattern="*reg.*.tif")#copy all files can filter later
filenames_NEX <- paste(lf_cp_f,collapse=" ")  #copy raster prediction object
cmd_str <- paste("scp -p",filenames_NEX,paste(Atlas_hostname,Atlas_dir,sep=":"), sep=" ")
system(cmd_str)

##################### END OF SCRIPT ######################

###Mosaic ...
#python mosaicUsingGdalMerge.py /nobackupp6/aguzman4/climateLayers/output1000x3000_km/reg5/ /nobackupp6/aguzman4/climateLayers/output1000x3000_km/reg5/mosaics/
#specify which month you want to process with the '-m' option. 
#To do select dates you can use the '--date' option and use the format YYYYMMDD, 
#can do multiple dates at a time by separating them with a comma.

#python mosaicUsingGdalMerge.py /nobackupp6/aguzman4/climateLayers/output1000x3000_km/reg5/ /nobackupp6/aguzman4/climateLayers/output1000x3000_km/reg5/mosaics/ --date 20100101,20100102,20100103,20100104
#python /nobackupp6/aguzman4/climateLayers/sharedCode/mosaicUsingGdalMerge.py /nobackupp6/aguzman4/climateLayers/output1000x3000_km/reg2/ /nobackupp6/aguzman4/climateLayers/output1000x3000_km/reg2/mosaics/ --date 20100101,20100102,20100103,20100104
#python /nobackupp6/aguzman4/climateLayers/sharedCode/mosaicUsingGdalMerge.py /nobackupp6/aguzman4/climateLayers/output1000x3000_km/reg2/ /nobackupp6/aguzman4/climateLayers/output1000x3000_km/reg2/mosaics/ --m 1"

