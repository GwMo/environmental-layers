####################################  INTERPOLATION OF TEMPERATURES  #######################################
#######################  Assessment of product part 3 functions: visuazilzation of temporal profiles of accuarcy and stations ##############################
#This script contains functions and uses the worklfow code applied to the globe. Results currently reside on NEX/PLEIADES NASA.
#Combining tables and figures for individual runs for years and tiles.
#AUTHOR: Benoit Parmentier 
#CREATED ON: 05/24/2016  
#MODIFIED ON: 01/28/2017            
#Version: 1
#PROJECT: Environmental Layers project     
#COMMENTS: fixing bugs in extraction from raster time series and missing day functions 
#TODO:
#1) Add plot broken down by year and region 
#2) Modify code for overall assessment accross all regions and year
#3) Clean up

#First source these files:
#Resolved call issues from R.
#source /nobackupp6/aguzman4/climateLayers/sharedModules2/etc/environ.sh 
#
#setfacl -Rmd user:aguzman4:rwx /nobackupp8/bparmen1/output_run10_1500x4500_global_analyses_pred_1992_10052015

##COMMIT: initial commmit: splitting functions and adding more
#
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
library(zoo)
library(xts)
library(lubridate)
library(mosaic)

###### Function used in the script #######
  
#Used to load RData object saved within the functions produced.
load_obj <- function(f){
  env <- new.env()
  nm <- load(f, env)[1]
  env[[nm]]
}


extract_date <- function(i,x,item_no=NULL){
  y <- unlist(strsplit(x[[i]],"_"))
  if(is.null(item_no)){
    date_str <- y[length(y)-2] #count from end
  }else{
    date_str <- y[item_no]
  }
  return(date_str)
}

gClip <- function(shp, bb, keep.attribs=TRUE,outDir=NULL,outSuffix=NULL,write=FALSE){
  #Purpose: clipping SpatialPolygonsDataFrame using another SpatialPolygonsDataFrame 
  #shp: input shapefile that we would like to clip
  #bb: input shapefile used for clipping, can be and extent raster object, matrix of coordinates 
  #keep.attribs: join attributes to spatial feature
  #outDir: output directory
  #outSuffix: output suffix attached to the name of new file
  
  #Authors: Benoit Parmentier, Modified code originating at: 
  #http://robinlovelace.net/r/2014/07/29/clipping-with-r.html
  
  #Comments: 
  #- Note that some attribute should be updated: e.g. areas, length etc. of original polygons
  #- Add bbox option for spdf
  #- Send error if different carthographic projection used
  
  ### BEGIN ####
  
  #First check inputs used from clipping, output dir and suffix
  
  if(class(bb) == "matrix"){
    b_poly <- as(extent(as.vector(t(bb))), "SpatialPolygons") #if matrix of coordinates
  }
  if(class(bb)=="SpatialPolygonsDataFrame"){
    b_poly <- bb #if polygon object, keep the same
  } 
  
  if(class(bb)=="SpatialPointsDataFrame"){
    b_poly <- as(extent(bb), "SpatialPolygons") #make a Spatial Polygon from raster extent
  }
  
  if(class(bb)=="exent"){
    b_poly <- as(extent(bb), "SpatialPolygons") #make a Spatial Polygon from raster extent
  }
  rm(bb) #remove from memory in case the polygon file is a giant dataset
  
  #If no output dir present, use the current dir
  if(is.null(outDir)){
    outDir=getwd()
  }
  #if no output suffix provided, use empty string for now
  if(is.null(outSuffix)){
    outSuffix=""
  }
  
  #Second, clip using rgeos library
  new.shape <- gIntersection(shp, b_poly, byid = T)
  
  #Third, join the atrribute back to the newly created object
  if(keep.attribs){
    #create a data.frame based on the spatial polygon object
    new.attribs <- data.frame(do.call(rbind,strsplit(row.names(new.shape)," ")),stringsAsFactors = FALSE)
    #test <-over(shp,bb)
    
    #new.attrib.data <- shp[new.attribs$X1,]@data #original data slot? #not a good way to extract...
    new.attrib.data <- as.data.frame(shp[new.attribs$X1,])
    row.names(new.shape) <- row.names(new.attrib.data)
    new.shape <-SpatialPolygonsDataFrame(new.shape, new.attrib.data) #Associate Polygons and attributes

  }
  
  if(write==TRUE){

    #Writeout shapefile (default format for now)
    infile_new.shape <- paste("clipped_spdf",outSuffix,".shp",sep="")
    writeOGR(new.shape,dsn= outDir,layer= sub(".shp","",infile_new.shape), 
           driver="ESRI Shapefile",overwrite_layer="TRUE")
  }

  
  return(new.shape)
}

plot_stations_val_by_date <- function(i,list_param){
  #
  #
  #function to plot residuals by date
  #
  
  #####
  
  l_dates <- list_param$l_dates
  model_name <- list_param$model_name
  station_type_name <- list_param$station_type_name
  var_selected <- list_param$var_selected
  #list_df_points_dates <- 
  df_combined_data_points <- list_param$df_combined_data_points
  countries_shp <- list_param$countries_shp
  proj_str <- list_param$proj_str
  out_suffix <- list_param$out_suffix
  out_dir <- list_param$out_dir
  
  ### STARTFUNCTION ####
    
  date_processed <- l_dates[i]
  
  df_points <- subset(df_combined_data_points,date==date_processed)
  #df_points <- list_df_points_dates[[i]]
  #plot(df_points)
  freq_tile_id <- as.data.frame(table(df_points$tile_id))
  freq_tile_id$date <- date_processed
  names(freq_tile_id) <- c("tile_id","freq","date")
    
  #plot(df_points,add=T)
  coordinates(df_points) <- cbind(df_points$x,df_points$y)
  #proj4string(df_points) <- CRS_locs_WGS84
  proj4string(df_points) <- proj_str
  # # No spatial duplicates
  df_points_day <- remove.duplicates(df_points) #remove duplicates...
  #plot(df_points_day)
  #dim(df_points_day)
  #dim(df_points)
  #plot(df_points)
  
  ##layer to be clipped
  if(class(countries_shp)!="SpatialPolygonsDataFrame"){
    reg_layer <- readOGR(dsn=dirname(countries_shp),sub(".shp","",basename(countries_shp)))
  }else{
    reg_layer <- countries_shp
  }

  #extent_df_points_day <- extent(df_points_day)
  
  reg_layer_clipped <- gClip(shp=reg_layer, bb=df_points_day , keep.attribs=TRUE,outDir=NULL,outSuffix=NULL)
  
  #data_stations_var_pred <- aggregate(id ~ date, data = data_stations, min)
  #data_stations_var_pred <- aggregate(id ~ x + y + date + dailyTmax + mod1 + res_mod1 , data = data_stations, min)
  
  #change the formula later on to use different y_var_name (tmin and precip)
  data_stations_var_pred <- aggregate(id ~ x + y + date + dailyTmax + res_mod1 + tile_id + reg ,data = df_points, mean ) #+ mod1 + res_mod1 , data = data_stations, min)
  dim(data_stations_var_pred)
  #> dim(data_stations_var_pred)
  #[1] 11171     5

  data_stations_var_pred$date_str <- data_stations_var_pred$date
  data_stations_var_pred$date <- as.Date(strptime(data_stations_var_pred$date_str,"%Y%m%d"))
  coordinates(data_stations_var_pred) <- cbind(data_stations_var_pred$x,data_stations_var_pred$y)
  #data_stations_var_pred$constant <- c(1000,2000)
  #plot(data_stations_var_pred)
  #plot(reg_layer)
  #res_pix <- 1200
  res_pix <- 800
  col_mfrow <- 1
  row_mfrow <- 1
  
  png_filename <- paste("Figure_ac_metrics_map_stations_location_",station_type_name,"_",model_name,"_",y_var_name,"_",date_processed,
                       "_",out_suffix,".png",sep="")
  png(filename=png_filename,
        width=col_mfrow*res_pix,height=row_mfrow*res_pix)
  #plot(data_stations_var_pred
  #p_shp <- spplot(reg_layer_clipped,"ISO3" ,col.regions=NA, col="black") #ok problem solved!!
  #title("(a) Mean for 1 January")
  #p <- bubble(data_stations_var_pred,"constant",main=paste0("Average Residuals by validation stations ",
  #                                                      date_processed,
  #                                                      "for ",var_selected))
  #p <- spplot(data_stations_var_pred,"constant",col.regions=NA, col="black",
  #            main=paste0("Average Residuals by validation stations ",pch=3,cex=10,
  #            date_processed, "for ",var_selected))

  #p1 <- p+p_shp
  #try(print(p1)) #error raised if number of missing values below a threshold does not exist
  
  title_str <- paste0("Stations ",station_type_name," on ",date_processed, " for ",y_var_name," ", var_selected)
  plot(reg_layer_clipped,main=title_str)
  plot(data_stations_var_pred,add=T,cex=0.5,col="blue")
  legend("topleft",legend=paste("n= ", nrow(data_stations_var_pred)),bty = "n")
  
  dev.off()
  
  res_pix <- 800
  col_mfrow <- 1
  row_mfrow <- 1
  png_filename <- paste("Figure_ac_metrics_map_stations",station_type_name,"averaged","_fixed_intervals_",model_name,y_var_name,date_processed,
                       out_suffix,".png",sep="_")
  png(filename=png_filename,
        width=col_mfrow*res_pix,height=row_mfrow*res_pix)
    
  #model_name[j]
  title_str <- paste0("Average Residuals by ",station_type_name," stations ",date_processed, " for ",y_var_name," ", var_selected)
  #p_shp <- layer(sp.polygons(reg_layer, lwd=1, col='black'))
  p_shp <- spplot(reg_layer,"ISO3" ,col.regions=NA, col="black") #ok problem solved!!
  #title("(a) Mean for 1 January")
  class_intervals <- c(-20,-10,-5,-4,-3,-2,-1,0,1,2,3,4,5,10,20)
  p <- bubble(data_stations_var_pred,zcol="res_mod1",key.entries = class_intervals , 
              fill=F, #plot circle with filling
              #col= matlab.like(length(class_intervals)),
              main=title_str)
  p1 <- p + p_shp
  try(print(p1)) #error raised if number of missing values below a threshold does not exist
  
  dev.off()

  #### Add additional plot with quantiles and min max?...
  
  
  #library(classInt)
  #breaks.qt <- classIntervals(palo_alto$PrCpInc, n = 6, style = "quantile", intervalClosure = "right")
  #spplot(palo_alto, "PrCpInc", col = "transparent", col.regions = my.palette, 
  #  at = breaks.qt$brks)

  #### histogram of values
  res_pix <- 800
  col_mfrow <- 1
  row_mfrow <- 1
  png_filename <- paste("Figure_ac_metrics_histograms_stations",station_type_name,"averaged",model_name,y_var_name,date_processed,
                       out_suffix,".png",sep="_")
  png(filename=png_filename,
        width=col_mfrow*res_pix,height=row_mfrow*res_pix)

  title_str <- paste0("Stations ",station_type_name," on ",date_processed, " for ",y_var_name," ", var_selected)

  h<- histogram(data_stations_var_pred$res_mod1,breaks=seq(-50,50,5),
                main=title_str)
  
  print(h)
  dev.off()
  
  ##Make data.frame with dates for later use!!
  #from libary mosaic
  df_basic_stat <- fav_stats(data_stations_var_pred$res_mod1)
  df_basic_stat$date <- date_processed
  #df_basic_stat$reg <- reg
  #quantile(data_stations_var_pred$res_mod1,c(1,5,10,90,95,99))
  df_quantile_val <- quantile(data_stations_var_pred$res_mod1,c(0.01,0.05,0.10,0.45,0.50,0.55,0.90,0.95,0.99))
  #names(df_quantile_val)
  #as.list(df_quantile_val)
  #df_test <- data.frame(names(df_quantile_val))[numeric(0), ]


  #quantile(c(1,5,10,90,95,99),data_stations_var_pred$res_mod1,)
  #rmse(data_stations_var_pred$res_mod1)
  
  plot_obj <- list(data_stations_var_pred,df_basic_stat,df_quantile_val,freq_tile_id)
  names(plot_obj) <- c("data_stations_var_pred","df_basic_stat","df_quantile_val","freq_tile_id")
   
  return(plot_obj)
}



sub_sampling_by_dist <- function(target_range_nb=c(10000,10000),dist_val=0.0,max_dist=NULL,step_val,data_in){
  #Function to select stations data that are outside a specific spatial range from each other
  #Parameters:
  #max_dist: maximum spatial distance at which to stop the pruning
  #min_dist: minimum distance to start pruning the data
  #step_val: spatial distance increment
  #Note that we are assuming that the first columns contains ID with name col of "id".
  #Note that the selection is based on unique id of original SPDF so that replicates screened.
  
  data_in$id <- as.character(data_in$id)
  data <- data_in
  
  #Now only take unique id in the shapefile!!!
  #This step is necessary to avoid the large calculation of matrix distance with replicates
  #unique(data$id)
  data <- aggregate(id ~ x + y , data=data,min)
  coordinates(data) <- cbind(data$x,data$y)
  proj4string(data) <- proj4string(data_in)
  
  target_min_nb <- target_range_nb[1]
  #target_min_nb <- target_range_day_nb[1]
  
  #station_nb <- nrow(data_in)
  station_nb <- nrow(data)
  if(is.null(max_dist)){
    while(station_nb > target_min_nb){
      data <- remove.duplicates(data, zero = dist_val) #spatially sub sample...
      dist_val <- dist_val + step_val
      station_nb <- nrow(data)
    }
    #setdiff(as.character(data$id),as.character(data_in$id))
    #ind.selected <-match(as.character(data$id),as.character(data_in$id)) #index of stations row selected
    #ind.removed  <- setdiff(1:nrow(data_in), ind.selected) #index of stations rows removed 
    id_selected <- as.character(data$id)
    id_removed <- setdiff(unique(as.character(data_in$id)),as.character(data$id))

  }
  if(!is.null(max_dist)){
    
    while(station_nb > target_min_nb & dist_val < max_dist){ 
      data <- remove.duplicates(data, zero = dist_val) #spatially sub sample...
      #id_rm <- zerodist(data, zero = dist_val, unique.ID = FALSE)
      #data_rm <- data[id_rm,]
      dist_val <- dist_val + step_val
      station_nb <- nrow(data)
    }
    #ind.selected <- match(as.character(data$id),as.character(data_in$id))
    id_selected <- as.character(data$id)
    id_removed <- setdiff(unique(as.character(data_in$id)),as.character(data$id))
  #  ind.removed  <- setdiff(1:nrow(data_in), ind.selected)
  }
    
  #data_rm <- data_in[ind.removed,]
  data_rm <- subset(data_in, id %in% id_removed)
  data_tmp <- data #store the reduced dataset with only id, for debugging purpose
  
  #data <- subset(data_in, id %in% data$id) #select based on id
  data <-subset(data_in, id %in% id_selected) #select based on id
  
  #data <- data_in[ind.selected,]
  obj_sub_sampling <- list(data,dist_val,data_rm) #data.frame selected, minimum distance, data.frame stations removed
  names(obj_sub_sampling) <- c("data","dist","data_rm")
  return(obj_sub_sampling)
}

query_for_station_lat_long <- function(point_val,df_points_spdf,step_x=0.25,step_y=0.25){
  #make this function better using gbuffer later!!!, works for now 
  #Improve: circular query + random within it
  y_val <- point_val[2]
  x_val <- point_val[1]
  
  y_val_tmp <- y_val + step_y
  if(x_val>0){
    x_val_tmp <- x_val - step_x
  }else{
    x_val_tmp <- x_val + step_x
  }


  test_df <- subset(df_points_spdf,(y_val < df_points_spdf$y & df_points_spdf$y < y_val_tmp))
  test_df2 <- subset(test_df,(x_val < test_df$x & test_df$x < x_val_tmp))
  #plot(test_df2)
 if(nrow(test_df2)>0){
   df_selected <- test_df2[1,]
 }else{
   df_selected <- NULL
 }
 
 return(df_selected)
}



finding_missing_dates <- function(date_start,date_end,list_dates){
  #this assumes daily time steps!!
  #can be improved later on
  
  #date_start <- "19840101"
  #date_end <- "19991231"
  date1 <- as.Date(strptime(date_start,"%Y%m%d"))
  date2 <- as.Date(strptime(date_end,"%Y%m%d"))
  dates_range <- seq.Date(date1, date2, by="1 day") #sequence of dates

  missing_dates <- setdiff(as.character(dates_range),as.character(list_dates))
  #df_dates_missing <- data.frame(date=missing_dates)
  #which(df_dates$date%in%missing_dates)
  #df_dates_missing$missing <- 1
  
  df_dates <- data.frame(date=as.character(dates_range),missing = 0) 

  df_dates$missing[df_dates$date %in% missing_dates] <- 1
  #a$flag[a$id %in% temp] <- 1

  missing_dates_obj <- list(missing_dates,df_dates)
  names(missing_dates_obj) <- c("missing_dates","df_dates")
  return(missing_dates_obj)
}



#Functions used in the validation metric script
calc_val_metrics<-function(x,y){
  #This functions calculates accurayc metrics on given two vectors.
  #Arguments: list of fitted models, raster stack of covariates
  #Output: spatial grid data frame of the subset of tiles
  #s_sgdf<-as(r_stack,"SpatialGridDataFrame") #Conversion to spatial grid data frame
  
  residuals<-x-y
  mae<-mean(abs(residuals),na.rm=T)
  rmse<-sqrt(mean((residuals)^2,na.rm=T))
  me<-mean(residuals,na.rm=T)
  r<-cor(x,y,use="complete")
  m50<-median(residuals,na.rm=T)
  metrics_dat<-as.data.frame(cbind(mae,rmse,me,r,m50))
  names(metrics_dat)<-c("mae","rmse","me","r","m50")
  metrics_obj<-list(metrics_dat,as.data.frame(residuals))
  names(metrics_obj)<-c("metrics_dat","residuals")
  return(metrics_obj)
}


############################ END OF SCRIPT ##################################