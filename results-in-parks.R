library(ggmap)
library(jsonlite)
library(tidyverse)
require(sp)
library(rgdal)
library(ridigbio)
#library(leaflet)
#library(viridis)

# TODO: figure out proper labels on graph
# TODO: not all parks draw a polygon. Problem with implementation or with their data?
# TODO: is there an api field / method for "has geopoint"?

IDIGBIO_API_RESULTS_FILE = "./data/idigbio_api_results.json"
RECORDS_WITHIN_BOUNDS_OUTPUT = "./output/records_within_bounds.csv"
RESTRICT_TO_SPECIFIC_PARK_CODES = FALSE


####################
# Step: get data from iDigBio
idigbio_api_results = tibble()

if (!file.exists(IDIGBIO_API_RESULTS_FILE)) {
  idigbio_api_results = as_tibble(idig_search_records(rq = list(
      stateprovince = "Florida"
    ),
    fields = c("uuid", "etag", "geopoint", "recordset", "stateprovince", 
               "institutioncode", "phylum", "basisofrecord", "kingdom", 
               "data.dwc:coordinateUncertaintyInMeters", "institutionid", 
               "collectioncode", "country", "county", "catalognumber"),
    limit = 1000)
  )
  write_json(idigbio_api_results, IDIGBIO_API_RESULTS_FILE)
  
} else {
  # It is critical to include simplifyVector = TRUE or else it reads back as a list.
  idigbio_api_results = as_tibble(read_json(IDIGBIO_API_RESULTS_FILE, simplifyVector = TRUE))
}


# clean our data. Note that backticks are important for picking up proper column
api_results_clean = idigbio_api_results %>% 
  filter(!is.na(`geopoint.lon`)) %>% 
  filter(!is.na(`geopoint.lat`)) %>% 
  mutate(lon = as.numeric (`geopoint.lon`)) %>% 
  mutate(lat = as.numeric (`geopoint.lat`)) %>% 
  rownames_to_column(var = "id")
  

########################################
# Step: Read in the shape data
# 
#  rgdal requires gdal, which might lead to frustrations getting it installed/compiled
nps_shapes = readOGR(dsn="nps_boundary/Current_Shapes/Data_Store/06-06-12_Posting", layer="nps_boundary")

# nearly half of the entire national list doesn't have a state value
# and we have no other way to restrict them
# we'll shortcut this for now with finding the codes manually
# Other options include perhaps the NPS API
# 
# if we don't restrict somehow, the map will draw ALL the parks, even without matching records
# Another option would be to do the opposite lookup and restrict the parks to only parks that have 
# point matches inside of them.
park_codes_of_interest = c("BICY", "BISC", "CANA", "CASA", "DESO", "DRTO", "EVER", "FOCA", "FOMA", "GUIS", "GUGE", "TIMU")

# dplyr filter will not work here with S4 object (TODO), so we'll get a logical vector of matches first.
matches_vector = nps_shapes@data$UNIT_CODE %in% park_codes_of_interest
nps_shapes_in_fl = nps_shapes[matches_vector,]

########################################
# Step: create a SpatialPointsDataFrame that we can use to search
# 
# data.frame() creates a new dataframe based on the df argument
api_results_spdf = data.frame(api_results_clean)

# coordinates() takes a dataframe and creates a SpatialPointsDataFrame
coordinates(api_results_spdf) = c("lon", "lat")

# In order to be mapped together, points and shapes need to be using the same project system.
# we've checked that they're the same projection system by viewing:
# nps_shapes@proj4string
# which shows:
# CRS arguments:
#  +proj=longlat +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +no_defs 
# 
# and so we know it's "safe" to assign it
#
proj4string(api_results_spdf) <- proj4string(nps_shapes)


########################################
# Step: perform intersection search

# compute a df full of true/false for whether it intersects with our areas of interest
intersections <- over(api_results_spdf, nps_shapes_in_fl[,"UNIT_CODE"]) 

# assign those true/false values back into our data
# any result with a unit code set will be an overlap
# any result without a unit code in overlap_code is not within the bounds
api_results_clean$overlap_code = intersections$UNIT_CODE

# now filter out points that don't fall within the boundaries
points_that_overlap = api_results_clean %>% 
  filter(! is.na(overlap_code))

# ggmap needs a data frame, so we're now going to change it back.
nps_shapes_that_intersect_df = fortify(nps_shapes_in_fl)

park_id_lookup = nps_shapes_in_fl@data %>% 
  rownames_to_column(var = "park_id") %>% 
  select(park_id, UNIT_CODE) %>% 



# "Error in fix.by(by.x, x) : 'by' must specify a uniquely valid column"
nps_shapes_that_intersect_df <- merge(nps_shapes_that_intersect_df, park_id_lookup, by.x = "id", by.y = "park_id", all.x = TRUE)

# now lets squish the park code ("UNIT_CODE") in so we have a friendly label
#nps_shapes_that_intersect %>% 
# mutate(park_code = as.numeric (`geopoint.lon`))

write_tsv(points_that_overlap, RECORDS_WITHIN_BOUNDS_OUTPUT)

########################################
# Step: set up mapping

# these will add some extra room along the edges of our map
netagive_margin = -1
positive_margin = 1

bounding_box = c("left" = min(points_that_overlap$lon) + netagive_margin, 
                 "bottom" = min(points_that_overlap$lat) + netagive_margin, 
                 "right"=max(points_that_overlap$lon) + positive_margin, 
                 "top" = max(points_that_overlap$lat) + positive_margin
  )


# if you try using get_map(),  you might see this: 
# "Error: Google now requires an API key. See ?register_google for details."
# 
# So we'll use a stamen map below.  Note that this requires us to specify the bounding box
m = get_stamenmap(bbox = bounding_box, zoom = 7, maptype = "toner-lite", source = "stamen" )

########################################
# map 1
# a plot of all search result records with geopoints before doing the intersection search
map_1_subtitle = paste("Total records with geopoints:", api_results_clean %>% summarise(n = n()))

ggmap(m,
      base_layer = ggplot(api_results_clean, aes(x = lon, y = lat)) + 
      ggtitle("All points from search results", subtitle = map_1_subtitle) 
      ) + 
  geom_polygon(aes(x = long, y = lat, group = group, fill = UNIT_CODE), 
               data = nps_shapes_that_intersect_df, alpha = 0.5) + 
  geom_point(data = api_results_clean, aes(shape = kingdom, color = kingdom), alpha = 0.7)



########################################
# map 2
# a plot of all search result records within the boundaries of interest
map_2_subtitle = paste("Total records in bounds:",  
                       points_that_overlap %>% summarise(n = n()),
                       " / ",
                       api_results_clean %>% summarise(n = n()))

ggmap(m,
      base_layer = ggplot(points_that_overlap, aes(x = lon, y = lat, alpha = 0.7))+ 
        ggtitle("Search results within park bounds", subtitle = map_2_subtitle)
) + 
  geom_polygon(aes(x = long, y = lat, group = group, fill = id), 
               data = nps_shapes_that_intersect_df, alpha = 0.7) + 
  geom_point(data = points_that_overlap, aes(shape = kingdom, color= substr(institutioncode, 1, 6)))
