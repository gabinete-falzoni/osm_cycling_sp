# Downloads OSM map for Southeast Brazil and isolates São Paulo city from it. Resulting
# file is sao_paulo-latest.osm.pbf. Requires installed 'osmosis' in system to run

# About Osmosis: https://github.com/openstreetmap/osmosis (in Debian, install with apt)
# Using osmosis to cut a polygon: https://github.com/eqasim-org/sao_paulo/blob/master/docs/howto.md
# Examples of osmosis uses: https://wiki.openstreetmap.org/wiki/Osmosis/Examples


library('tidyverse')
library('tidylog')
library('httr')
# library('sf')
# library('mapview')

# Directory structure
data_folder     <- '../data'


# ------------------------------------------------------------------------------
# 1. Preparatory steps: download OSM PBF file; create São Paulo poly file
# ------------------------------------------------------------------------------

# Manually download the PBF file for the Southeast region of Brazil from the website
# http://download.geofabrik.de/south-america/brazil/sudeste.html
# Save it in the folder '../data/sudeste-latest.osm.pbf'.

# A polyline for the city of São Paulo is also needed. For convenience, the file
# is already present at the same 'data' folder: '../data/sp.poly'
poly_file <- sprintf('%s/sp.poly', data_folder)

# Below are links to help generate it and step-by-step instructions:

# About the .poly format to be used:
# https://wiki.openstreetmap.org/wiki/Osmconvert
# https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format

# To use Osmosis, a polygon in .poly format for São Paulo must be created.
# The easiest way is:
# 1. Open the administrative boundaries map of São Paulo from Geosampa in QGIS;
# 2. Install a plugin called "Export OSM Poly", which appears as "osmpoly_export";
# 3. Use the plugin button that appears in the menu to export the layer in .poly format;
# 4. For convenience, rename the polygon "sp.poly" to "sp.poly".

# Increase timeout value for large downloads
options(timeout = 10000)

# Download PBF file from OSM for Southeast Brazil
url <- 'https://download.geofabrik.de/south-america/brazil/sudeste-latest.osm.pbf'
pbf_file <- sprintf('%s/%s', data_folder, basename(url))


# File size
response <- httr::HEAD(url)
download_size <- httr::headers(response)[["Content-Length"]]
# Download and check success via file sizes
result <- try({ download.file(url, pbf_file)} , silent = FALSE)
if (file.size(pbf_file) == download_size) {
  print('PBF file correctly downloaded')
} else {
  warning('PBF file NOT downloaded in full. Consider increasing the timeout value for large downloads')
}


# ------------------------------------------------------------------------------
# 2. Isolate São Paulo city from OSM main map
# ------------------------------------------------------------------------------

# Resulting file should have about ~107 MB
out_pbf_file <- sprintf('%s/sao_paulo-latest.osm.pbf', data_folder)

# This step should take about 2h15min to run - change osmosis path according to system
osmosis_path <- sprintf("/usr/bin/osmosis")
arg_o1 <- sprintf('--read-pbf file="%s"', pbf_file)
arg_o2 <- sprintf('--bounding-polygon file="%s"', poly_file)
arg_o3 <- sprintf('--write-pbf file="%s"', out_pbf_file)
system2(command = osmosis_path, args = c(arg_o1, arg_o2, arg_o3))
