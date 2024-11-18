library(duckdb)
library(duckdbfs)
library(DBI)
library(sf)
library(tidyverse)


con <- dbConnect(duckdb::duckdb(), dbdir = "test.duckdb")
load_spatial(con)

dbListTables(con)

# dbExecute(con, "DROP TABLE cleaned_points;")

points_file <- here::here("data", "points.parquet")
polygon_file <- here::here("data", "NYS_Civil_Boundaries", "Counties_Shoreline.shp")

qry2 <- glue::glue("CREATE TABLE points AS
            SELECT  pointid,
                    rowid,
                    ST_Point(longitude, latitude) AS geom
            FROM '{f}';")

dbExecute(con, qry2)



#Add polygons to duckbd


polygon_file <- "data/NYS_Civil_Boundaries/Counties_Shoreline.shp"
polygon <- st_read(polygon_file) |>
  mutate(rowid = row_number())



# df_with_geom <- st_write(polygon, dsn = NULL, driver = "GeoJSON", quiet = TRUE)
polygon$geometry <- st_as_text(st_geometry(polygon))

polygon_qry <- glue::glue("CREATE TABLE counties AS SELECT  rowid, NAME, ST_GeomFromText(geometry) AS geom
            FROM polygon;")


dbExecute(con, polygon_qry)


qry3 <- "SELECT *
         FROM cleaned_points"

test3 <- dbGetQuery(con, qry3) |>
  head(20) |>
  to_sf(crs = 4326, conn = con)
glimpse(test3)

# Now try your query with ST_AsWKB
test4 <- dbGetQuery(con, "SELECT pointid, sub_area, ST_AsText(geom) AS test FROM points") |>
  head(20) %>%
  st_as_sf(wkt = "test", crs = 4326)


library(ggplot2)
ggplot() +
  geom_sf(data = test4) +
  theme_minimal()

