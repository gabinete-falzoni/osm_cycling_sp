library('tidyverse')
library('tidylog')
library('sf')
library('osmdata')
library('osmextract')
# library('mapview')

# Directory structure
data_folder     <- '../data'


# ------------------------------------------------------------------------------
# Extract OSM roads for the city of São Paulo
# ------------------------------------------------------------------------------

# Polygon for the city of São Paulo, present at 'data_folder' for convenience
poly_file <- sprintf('%s/sp.poly', data_folder)
sp_poly <- read_poly(poly_file, crs = 'OGC:CRS84')
# mapview(sp_poly)

# Build OSM query for roads, based on bounding box for the polygon
osm_query <- opq(bbox = st_bbox(sp_poly)) %>% add_osm_feature(key = 'highway')

# Download data - should take just a couple of minutes but use a lot of RAM
osm_data <- osmdata_sf(osm_query) # 6.3 GB of memory size

# Extract roads based on the city's polygon
osm_roads <- osm_data$osm_lines %>% st_intersection(sp_poly)

# There are duplicated column names - remove them
any(duplicated(toupper(names(osm_roads))))
which(duplicated(toupper(names(osm_roads))))
names(osm_roads)[168] # 'fixme' is duplicated with 'FIXME'
osm_roads <- osm_roads %>% rename(fixme2 = fixme)


# ------------------------------------------------------------------------------
# Cycling infrastructure
# ------------------------------------------------------------------------------

# Cycling infrastructure: if any of the cycleway columns is not NA or highway is cycleway or footway
cycle_osm <- osm_roads %>% filter(if_any(matches('cycleway'), ~ !is.na(.x)) | highway %in% c('cycleway', 'footway'))
# mapview(cycle_osm)

# Simplify columns
# names(cycle_osm)
cycle_osm <-
  cycle_osm %>% select(osm_id, name, matches('bicycle'), matches('cycleway'), foot, footway, segregated, highway) %>%
  select(!matches('disused'))

# Remove cycleway:both == 'no'
cycle_osm <- cycle_osm %>% filter(`cycleway:both` != 'no' | is.na(`cycleway:both`))

# Remove motorways with cycleway:shoulder
cycle_osm <- cycle_osm %>% filter(`cycleway:right` != 'shoulder' | is.na(`cycleway:right`))
# cycle_osm <- cycle_osm %>% filter(!(str_detect(highway, 'motorway') & if_any(matches('cycleway'), ~ .x == 'shoulder')))
# %>% select(matches('cycleway'), highway)

# Remove constructions
cycle_osm <- cycle_osm %>% filter(highway != 'construction')

# Remove all NA-only columns
cycle_osm <- cycle_osm %>% select(!where(~ all(is.na(.))))

# Type of cycling infrastructure
# Run mutate in different steps, since some specific categories should override
# more general ones - this can only happen in after the first mutate takes place
cycle_osm <-
  cycle_osm %>%
  # Ciclovia - Cycle tracks
  mutate(infra_ciclo = case_when(highway == 'cycleway' ~ 'ciclovia',
                                 TRUE ~ NA_character_)) %>%
  # Ciclofaixas - Cycle lanes
  mutate(infra_ciclo = case_when(
    if_any(c(cycleway, `cycleway:left`, `cycleway:right`, `cycleway:both`), ~ . == 'lane') ~ 'ciclofaixa',
    TRUE ~ infra_ciclo)) %>%
  # Ciclorrotas - Shared streets
  mutate(infra_ciclo = case_when(
    if_any(c(cycleway, `cycleway:left`, `cycleway:right`), ~ . == 'shared_lane') ~ 'ciclorrota',
    TRUE ~ infra_ciclo)) %>%
  # Some cycle lanes are designed as crossings
  mutate(infra_ciclo = case_when(highway == 'cycleway' & cycleway == 'crossing' ~ 'ciclofaixa',
                                 TRUE ~ infra_ciclo)) %>%
  # Calçada partilhada - Sidewalk with segregated cycleway
  mutate(infra_ciclo = case_when(highway == 'cycleway' & foot == 'designated' & segregated == 'yes' ~ 'calçadada partilhada',
                                 highway == 'footway' & bicycle == 'designated' ~ 'calçadada partilhada',
                                 TRUE ~ infra_ciclo)) %>%
  # Calçada compartilhada - Shared sidewalk
  mutate(infra_ciclo = case_when(highway == 'cycleway' & foot == 'designated' & segregated == 'no' ~ 'calçadada compartilhada',
                                 highway == 'pedestrian' & bicycle == 'designated' ~ 'calçadada compartilhada',
                                 TRUE ~ infra_ciclo))


# cycle_osm %>%
#   st_drop_geometry() %>%
#   filter(osm_id == '810899020') %>%
#   select(osm_id, name, matches('bicycle'), matches('cycleway'), foot, footway, segregated, highway, infra_ciclo) %>%
#   select(!where(~ all(is.na(.))))
#
# osm_roads %>%
#   st_drop_geometry() %>%
#   filter(osm_id == '810899020') %>%
#   select(osm_id, name, matches('bicycle'), matches('cycleway'), foot, footway, segregated, highway) %>%
#   select(!where(~ all(is.na(.)))) %>%
#   mutate(infra_ciclo = case_when(
#     if_any(c(cycleway), ~ . == 'shared_lane') ~ 'ciclorrota',
#     TRUE ~ NA_character_))

# Check valuer per column
# result <- map(cycle_osm, ~ count(tibble(value = .x), value))

# Check valuer per column
# cycle_osm %>%
#   st_drop_geometry() %>%
#   filter(highway == 'cycleway' & foot == 'designated') %>%
#   group_by(highway, foot, segregated) %>%
#   tally()

# Export only cycling infrastructure
cycle_osm <- cycle_osm %>% filter(!is.na(infra_ciclo))

out_file <- sprintf('%s/cycle_osm_sp.gpkg', data_folder)
st_write(cycle_osm, out_file, driver = 'GPKG', append = FALSE, delete_layer = TRUE)
