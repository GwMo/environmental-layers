# R code to plot latitudinal profiles of mean slope, along with both
# RMSE and correlation coefficients comparing fused layers with both the
# raw ASTER and with the Canada DEM
#
# Jim Regetz
# NCEAS
# Created on 08-Jun-2011

library(raster)

datadir <- "/home/regetz/media/temp/terrain/slope"

# load slope rasters
s.aster <- raster(file.path(datadir, "aster_300straddle_s.tif"))
s.srtm <- raster(file.path(datadir, "srtm_150below_s.tif"))
s.uncor <- raster(file.path(datadir, "fused_300straddle_s.tif"))
s.enblend <- raster(file.path(datadir, "fused_300straddle_enblend_s.tif"))
s.bg <- raster(file.path(datadir, "fused_300straddle_blendgau_s.tif"))
s.can <- raster(file.path(datadir, "cdem_300straddle_s.tif"))

# extract raster latitudes for later
lats300 <- yFromRow(s.aster, 1:nrow(s.aster))
lats150 <- yFromRow(s.srtm, 1:nrow(s.srtm))

# initialize output pdf device driver
pdf("slope-assessment.pdf", height=8, width=11.5)


#
# plot latitudinal profiles of mean slope
#

par(mfrow=c(2,2), omi=c(1,1,1,1))

ylim <- c(1, 6)

plot(lats300, rowMeans(as.matrix(s.can), na.rm=TRUE), type="l",
    xlab="Latitude", ylab="Mean slope", ylim=ylim)
text(min(lats300), max(ylim)-0.5, pos=4, font=3, labels="Original DEMs")
lines(lats300, rowMeans(as.matrix(s.aster), na.rm=TRUE), col="blue")
lines(lats150, rowMeans(as.matrix(s.srtm), na.rm=TRUE), col="red")
legend("topright", legend=c("ASTER", "SRTM", "CDED"), col=c("blue",
    "red", "black"), lty=c(1, 1), bty="n")
abline(v=60, col="red", lty=2)
mtext(expression(paste("Latitudinal profiles of mean slope (",
    136*degree, "W to ", 96*degree, "W)")), adj=0, line=2, font=2)

plot(lats300, rowMeans(as.matrix(s.uncor), na.rm=TRUE), type="l",
    xlab="Latitude", ylab="Mean slope", ylim=ylim)
text(min(lats300), max(ylim)-0.5, pos=4, font=3, labels="simple fused")
abline(v=60, col="red", lty=2)

plot(lats300, rowMeans(as.matrix(s.enblend), na.rm=TRUE), type="l",
    xlab="Latitude", ylab="Mean slope", ylim=ylim)
text(min(lats300), max(ylim)-0.5, pos=4, font=3, labels="multires spline")
abline(v=60, col="red", lty=2)

plot(lats300, rowMeans(as.matrix(s.bg), na.rm=TRUE), type="l",
    xlab="Latitude", ylab="Mean slope", ylim=ylim)
text(min(lats300), max(ylim)-0.5, pos=4, font=3, labels="gaussian blend")
abline(v=60, col="red", lty=2)


#
# plot latitudinal profiles of RMSE
#

# simple helper function to calculate row-wise RMSEs
rmse <- function(r1, r2, na.rm=TRUE, use) {
    diffs <- abs(as.matrix(r1) - as.matrix(r2))
    if (!missing(use)) diffs[!use] <- NA
    sqrt(rowMeans(diffs^2, na.rm=na.rm))
}

par(mfrow=c(2,3), omi=c(1,1,1,1))

# ...with respect to ASTER
plot(lats300, rmse(s.uncor, s.aster), type="l", xlab="Latitude",
    ylab="RMSE", ylim=c(0, 5))
lines(lats150, rmse(crop(s.uncor, extent(s.srtm)), s.srtm), col="blue")
legend("topright", legend=c("ASTER", "SRTM"), col=c("black", "blue"),
    lty=c(1, 1), bty="n")
text(min(lats300), 4.5, pos=4, font=3, labels="simple fused")
abline(v=60, col="red", lty=2)
mtext(expression(paste(
    "Slope discrepancies with respect to separate ASTER/SRTM components (",
    136*degree, "W to ", 96*degree, "W)")), adj=0, line=2, font=2)

plot(lats300, rmse(s.enblend, s.aster), type="l", xlab="Latitude",
    ylab="RMSE", ylim=c(0, 5))
lines(lats150, rmse(crop(s.enblend, extent(s.srtm)), s.srtm), col="blue")
legend("topright", legend=c("ASTER", "SRTM"), col=c("black", "blue"),
    lty=c(1, 1), bty="n")
text(min(lats300), 4.5, pos=4, font=3, labels="multires spline")
abline(v=60, col="red", lty=2)

plot(lats300, rmse(s.bg, s.aster), type="l", xlab="Latitude",
    ylab="RMSE", ylim=c(0, 5))
lines(lats150, rmse(crop(s.bg, extent(s.srtm)), s.srtm), col="blue")
legend("topright", legend=c("ASTER", "SRTM"), col=c("black", "blue"),
    lty=c(1, 1), bty="n")
text(min(lats300), 4.5, pos=4, font=3, labels="gaussian blend")
abline(v=60, col="red", lty=2)

# ...with respect to CDEM
plot(lats300, rmse(s.uncor, s.can), type="l", xlab="Latitude",
    ylab="RMSE", ylim=c(0, 5))
text(min(lats300), 4.5, pos=4, font=3, labels="simple fused")
abline(v=60, col="red", lty=2)
mtext(expression(paste(
    "Slope discrepancies with respect to Canada DEM (",
    136*degree, "W to ", 96*degree, "W)")), adj=0, line=2, font=2)

plot(lats300, rmse(s.enblend, s.can), type="l", xlab="Latitude",
    ylab="RMSE", ylim=c(0, 5))
text(min(lats300), 4.5, pos=4, font=3, labels="multires spline")
abline(v=60, col="red", lty=2)

plot(lats300, rmse(s.bg, s.can), type="l", xlab="Latitude",
    ylab="RMSE", ylim=c(0, 5))
text(min(lats300), 4.5, pos=4, font=3, labels="gaussian blend")
abline(v=60, col="red", lty=2)


#
# plot latitudinal profiles of correlation coefficients
#

# simple helper function to calculate row-wise correlation coefficients
corByLat <- function(r1, r2, rows) {
    if (missing(rows)) {
        rows <- 1:nrow(r1)
    }
    m1 <- as.matrix(r1)
    m2 <- as.matrix(r2)
    sapply(rows, function(row) cor(m1[row,], m2[row,],
        use="pairwise.complete.obs"))
}

par(mfrow=c(2,3), omi=c(1,1,1,1))

ylim <- c(0.65, 1)

# ...with respect to ASTER
plot(lats300, corByLat(s.uncor, s.aster), type="l", xlab="Latitude",
    ylab="Correlation", ylim=ylim)
lines(lats150, corByLat(crop(s.uncor, extent(s.srtm)), s.srtm), col="blue")
legend("bottomright", legend=c("ASTER", "SRTM"), col=c("black", "blue"),
    lty=c(1, 1), bty="n")
text(min(lats300), min(ylim), pos=4, font=3, labels="simple fused")
abline(v=60, col="red", lty=2)
mtext(expression(paste(
    "Slope correlations with respect to separate ASTER/SRTM components (",
    136*degree, "W to ", 96*degree, "W)")), adj=0, line=2, font=2)

plot(lats300, corByLat(s.enblend, s.aster), type="l", xlab="Latitude",
    ylab="Correlation", ylim=ylim)
lines(lats150, corByLat(crop(s.enblend, extent(s.srtm)), s.srtm), col="blue")
legend("bottomright", legend=c("ASTER", "SRTM"), col=c("black", "blue"),
    lty=c(1, 1), bty="n")
text(min(lats300), min(ylim), pos=4, font=3, labels="multires spline")
abline(v=60, col="red", lty=2)

plot(lats300, corByLat(s.bg, s.aster), type="l", xlab="Latitude",
    ylab="Correlation", ylim=ylim)
lines(lats150, corByLat(crop(s.bg, extent(s.srtm)), s.srtm), col="blue")
legend("bottomright", legend=c("ASTER", "SRTM"), col=c("black", "blue"),
    lty=c(1, 1), bty="n")
text(min(lats300), min(ylim), pos=4, font=3, labels="gaussian blend")
abline(v=60, col="red", lty=2)

# ...with respect to CDEM
plot(lats300, corByLat(s.uncor, s.can), type="l", xlab="Latitude",
    ylab="Correlation", ylim=ylim)
text(min(lats300), min(ylim), pos=4, font=3, labels="simple fused")
abline(v=60, col="red", lty=2)
mtext(expression(paste(
    "Slope correlations with respect to Canada DEM (",
    136*degree, "W to ", 96*degree, "W)")), adj=0, line=2, font=2)

plot(lats300, corByLat(s.enblend, s.can), type="l", xlab="Latitude",
    ylab="Correlation", ylim=ylim)
text(min(lats300), min(ylim), pos=4, font=3, labels="multires spline")
abline(v=60, col="red", lty=2)

plot(lats300, corByLat(s.bg, s.can), type="l", xlab="Latitude",
    ylab="Correlation", ylim=ylim)
text(min(lats300), min(ylim), pos=4, font=3, labels="gaussian blend")
abline(v=60, col="red", lty=2)

# close pdf device driver
dev.off()
