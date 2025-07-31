# Simplify the .pbf file containing the road network of the city of São Paulo so
# that it can be opened in QGIS to verify streets with cycling infrastructure
# and park areas. Some columns and types of 'highway' are discarded.

library('tidyverse')
library('tidylog')
library('sf')
library('mapview')


# Directory structure
data_folder     <- '../data'


# ------------------------------------------------------------------------------
# 1. Read OSM map for São Paulo in full
# ------------------------------------------------------------------------------

# The road network file for the municipality can be very large and may not be
# fully read using read_sf() below. This is especially the case for São Paulo –
# all road network files for other cities in Brazil are under 25 MB, while São
# Paulo's is nearly 120 MB. To be safe, we will read the file as .gpkg to
# ensure the entire road network is loaded.
# osm_sp <- read_sf(map_file, layer = 'lines') # don't use

# Read network files as .gpkg. About this issue, see:
# https://github.com/ropensci/osmextract/issues/12
read_from_gpkg <- function(path) {
  gpkg_file <- paste0(tempfile(), ".gpkg")
  gdal_utils(
    util = "vectortranslate",
    source = path,
    destination = gpkg_file,
    options = c("-f", "GPKG", "lines")
  )
  res <- st_read(gpkg_file, quiet = TRUE)
  names(res)[which(names(res) == "geom")] <- "geometry"
  st_geometry(res) <- "geometry"
  res
}

# Open OSM's .pbf for the city of São Paulo
osm_sp_full <- sprintf('%s/sao_paulo-latest.osm.pbf', data_folder)
osm_sp_full <- read_from_gpkg(osm_sp_full)


# ------------------------------------------------------------------------------
# 2. Simplify OSM map for São Paulo
# ------------------------------------------------------------------------------

# Remove everything that is not road network
osm_sp <- osm_sp_full %>% filter(is.na(waterway) &
                                   is.na(aerialway) &
                                   is.na(barrier) &
                                   is.na(man_made))


# Simplify database and discard unnecessary columns
osm_sp <- osm_sp %>% select(-c(waterway, aerialway, barrier, man_made, z_order))

# Remove certain types of structure - all were manually checked in the map
no_use <- c("raceway", "proposed", "construction", "elevator", "bus_stop",
            "platform", "emergency_bay", "crossing", "services")
osm_sp <- osm_sp %>% filter(!highway %in% no_use)

# Remove road network in which highway is null
osm_sp <- osm_sp %>% filter(!is.na(highway))

# Order by osm_id to export
osm_sp <- osm_sp %>% arrange(osm_id)


# ------------------------------------------------------------------------------
# 3. Insert markings for different types of cycling infrastructure
# ------------------------------------------------------------------------------

# Insert general marking for cycling infrastructure
osm_sp_cycling <- osm_sp
osm_sp_cycling <- osm_sp_cycling %>% mutate(infra_ciclo = case_when(highway == 'cycleway' ~ TRUE,
                                                                      TRUE ~ NA))

# Tentar marcar vias que possuem infraestrutura cicloviária - essa informação
# pode aparecer na coluna 'other_tags' ou diretamente na coluna de highway
osm_sp_cycling <-
  osm_sp_cycling %>%
  mutate(infra_ciclo = case_when(str_detect(other_tags, '"cycleway"=>"lane"') ~ TRUE,
                                 str_detect(other_tags, '"cycleway:left"=>"lane"') ~ TRUE,
                                 str_detect(other_tags, '"cycleway:right"=>"lane"') ~ TRUE,
                                 str_detect(other_tags, '"cycleway:both"=>"lane"') ~ TRUE,
                                 str_detect(other_tags, '"cycleway:left"=>"shared_lane"') ~ TRUE,
                                 str_detect(other_tags, '"cycleway:right"=>"shared_lane"') ~ TRUE,
                                 str_detect(other_tags, '"cycleway"=>"shared_lane"') ~ TRUE,
                                 # Estruturas de ciclovias ou em calçadas
                                 highway == 'cycleway'~ TRUE,
                                 highway == 'footway' & str_detect(other_tags, '"bicycle"=>"designated"') ~ TRUE,
                                 highway == 'pedestrian' & str_detect(other_tags, '"bicycle"=>"designated"') ~ TRUE,
                                 # Alguém marcou ciclofaixas nos acostamentos de rodovias...
                                 str_detect(other_tags, '"cycleway:left"=>"shoulder"') ~ FALSE,
                                 str_detect(other_tags, '"cycleway:right"=>"shoulder"') ~ FALSE,
                                 TRUE ~ NA)) %>%
  mutate(infra_ciclo_tp = case_when(str_detect(other_tags, '"cycleway"=>"lane"') ~ 'ciclofaixa',
                                    str_detect(other_tags, '"cycleway:left"=>"lane"') ~ 'ciclofaixa',
                                    str_detect(other_tags, '"cycleway:right"=>"lane"') ~ 'ciclofaixa',
                                    str_detect(other_tags, '"cycleway:both"=>"lane"') ~ 'ciclofaixa',
                                    str_detect(other_tags, '"cycleway:left"=>"shared_lane"') ~ 'ciclorrota',
                                    str_detect(other_tags, '"cycleway:right"=>"shared_lane"') ~ 'ciclorrota',
                                    str_detect(other_tags, '"cycleway"=>"shared_lane"') ~ 'ciclorrota',
                                    highway == 'cycleway' & !str_detect(other_tags, '"foot"=>"designated"') ~ 'ciclovia',
                                    highway == 'cycleway' & str_detect(other_tags, '"cycleway"=>"crossing"') ~ 'ciclofaixa',
                                    highway == 'cycleway' & str_detect(other_tags, '"foot"=>"designated"') & !str_detect(other_tags, '"segregated"=>"no"') ~ 'calçadada partilhada',
                                    highway == 'cycleway' & str_detect(other_tags, '"foot"=>"designated"') & str_detect(other_tags, '"segregated"=>"no"') ~ 'calçadada compartilhada',
                                    highway == 'footway' & str_detect(other_tags, '"bicycle"=>"designated"') ~ 'calçadada partilhada',
                                    highway == 'pedestrian' & str_detect(other_tags, '"bicycle"=>"designated"') ~ 'calçadada compartilhada',
                                    TRUE ~ NA))


# osm_sp_cycling %>% st_drop_geometry() %>% select(highway) %>% distinct()
# osm_sp_cycling %>% filter(str_detect(other_tags, '"cycleway:right"=>"shoulder"'))


# Exportar a base resultante
st_write(osm_sp_cycling, sprintf('%s/sao_paulo_osm_filtrado.gpkg', pasta_dados_out), driver = 'GPKG', append = FALSE, delete_layer = TRUE)
