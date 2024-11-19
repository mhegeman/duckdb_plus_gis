# Script to get point and polygon data into tables in duckdb

# Load required libraries
library(sf)
library(duckdb)

# Read the shapefile
# Replace the file path with your actual shapefile path
polygon_data <- st_read("data/NYS_Civil_Boundaries/Counties_Shoreline.shp")

# Create a DuckDB connection, a new db will be created if it doesn't exist already
con <- dbConnect(duckdb(), dbdir = "spatial_db.duckdb")

# Make sure the spatial extension is installed and loaded
dbExecute(con,
          "INSTALL spatial;
          LOAD spatial;")

# Assuming spatial_data is your sf object
# Convert geometry to WKT
polygon_df <- data.frame(polygon_data)
polygon_df$geometry <- st_as_text(polygon_data$geometry)

# Create a table in DuckDB and load the data
dbWriteTable(con, "counties_polygon", polygon_df)

# Verify the data was loaded correctly
result <- dbGetQuery(con, "SELECT * FROM counties_polygon LIMIT 5")


# Add point data from a parquet file
points_file <- here::here("data", "campsite_amenities.parquet")

# Create table in DuckDB and load data
points_qry <- glue::glue("CREATE TABLE points AS
            SELECT  OBJECTID,
                    FACILITY,
                    ASSET,
                    PUBLIC_USE,
                    ST_Point(longitude, latitude) AS geom
            FROM '{points_file}';")
dbExecute(con, points_qry)

# Don't forget to close the connection when you're done
dbDisconnect(con)

