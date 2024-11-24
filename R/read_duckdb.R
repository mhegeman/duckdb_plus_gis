library(duckdb)
library(sf)
library(tidyverse)


con <- dbConnect(duckdb(), dbdir = "spatial_db.duckdb")

dbExecute(con,
          "INSTALL spatial;
           LOAD spatial;")

dbListTables(con)


# Query the top 5 largest counties in New York State by area
counties_qry <- "
SELECT *
FROM counties_polygon
ORDER BY ST_Area(ST_GeomFromText(geometry)) DESC
LIMIT 5
"

top_5_df <- dbGetQuery(con, counties_qry)
# Convert back to sf object for mapping
top_5_sf <- st_as_sf(top_5_df, wkt = "geometry") |> st_transform(crs = 32618)

# Query all of the campsites

campsite_query <- "
SELECT OBJECTID, FACILITY, ASSET, PUBLIC_USE, ST_AsText(geom) AS geometry
FROM points
"

campsite_df <- dbGetQuery(con, campsite_query)
# Convert back to sf object for mapping
campsite_sf <- st_as_sf(campsite_df, wkt = "geometry")

# Plot to check your work. This data is in NAD83 so it map look a little different
ggplot() +
  geom_sf(data = top_5_sf, fill = "lightgreen") +
  geom_sf(data = campsite_sf, color = "darkblue") +
  theme_minimal() +
  labs(title = "Top 5 largest counties in New York State") +
  theme(plot.title = element_text(hjust = 0.5))
