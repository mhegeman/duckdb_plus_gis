library(duckdb)
library(sf)
library(ggplot2)


# connect to the database and load the spatial package
con <- dbConnect(duckdb(), dbdir = "spatial_db.duckdb")

dbExecute(con,
          "INSTALL spatial;
           LOAD spatial;")

# Explore the data
dbListTables(con)

dbGetQuery(con, "DESCRIBE counties_polygon")
dbGetQuery(con, "DESCRIBE points")

check_polygons <- dbGetQuery(con,
                             "SELECT *
                FROM counties_polygon p
                limit 10")

check_points <- dbGetQuery(con,
                           "SELECT * FROM points p
                           LIMIT 10")

# write a query for duckdb that returns only the polygons from the "counties_polygon' table that has points from the "points" table within them



county_query <- "
SELECT DISTINCT p.*
FROM counties_polygon p
INNER JOIN (
    SELECT
        FACILITY,
        geom
    FROM (
        SELECT *,
        ROW_NUMBER() OVER (PARTITION BY FACILITY ORDER BY FACILITY) as rn
        FROM points
    ) ranked
    WHERE rn = 1
) pt
  ON ST_Contains(
    ST_GeomFromText(p.geometry),
    pt.geom
  )
"

county_df <- dbGetQuery(con, county_query)
# Convert back to sf object for mapping
county_sf <- st_as_sf(county_df, wkt = "geometry", crs = 26918)
# The data is originally in NAD83/UTM Zone 18N, transforming it to WGS84
county_sf_WGS84 <- county_sf |>
  st_transform(4326)

# I also want the full county dataset for use on the map later
all_counties_query <- "
SELECT DISTINCT p.*
FROM counties_polygon p"

all_counties_df <- dbGetQuery(con, all_counties_query)
all_counties_sf <- st_as_sf(all_counties_df, wkt = "geometry", crs = 26918)
all_counties_sf_WGS84 <- all_counties_sf |>
  st_transform(4326)

# Query all of the campsites to plot on top of the polygons
# There are many points per campsite (FACILITY), but we only need the first point for each campsite
campsite_query <- "
SELECT FACILITY, ST_AsText(FIRST(geom)) AS geometry
FROM points
GROUP BY FACILITY
"

campsite_df <- dbGetQuery(con, campsite_query)
# Convert back to sf object for mapping
campsite_sf <- st_as_sf(campsite_df, wkt = "geometry", crs = 26918)
# The data is originally in NAD83/UTM Zone 18N, transforming it to WGS84
campsite_sf_WGS84 <- campsite_sf |>
  st_transform(4326)


ggplot() +
  # Add base map tiles
  ggspatial::annotation_map_tile(type = "cartolight", zoom = 6) +  # OpenStreetMap tiles
  geom_sf(data = all_counties_sf_WGS84,
          fill = "white",
          alpha = 0.1,
          color = "darkgrey") +
  # Add base counties layer with transparency and borders
  geom_sf(data = county_sf_WGS84,
          fill = "lightgreen",
          alpha = 0.2,
          color = "darkgrey") +
  # Add points with better visibility
  geom_sf(data = campsite_sf_WGS84,
          fill = "darkblue",
          color = "white",
          size = 3,
          shape = 21) +  # filled circle with border
  # Enhanced title and captions
  labs(title = "Counties in NY State that contain DEC campgrounds",
       caption = "Data source: DEC") +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.caption = element_text(hjust = 0, size = 8, color = "grey50")
  )



ggsave("ny_counties_campgrounds.png", width = 8, height = 6, dpi = 300)

