#!/usr/bin/zsh

##############################################################################################################
#🛠 Publicare/actualizare Regiuni dezvoltare, România (poligon)
##############################################################################################################

#🎛 configurații

#🕹 activare mediu Anaconda cu bibliotecile necesare pentru procesare
source /home/ubuntu/anaconda3/etc/profile.d/conda.sh
conda activate geo

#🚏 definire căi date
county_data_path="/storage/volumes/geoserver-1-storage/administrative_boundaries/county"
region_data_path="/storage/volumes/geoserver-1-storage/administrative_boundaries/region"


#⚙️ PostGIS
pg_host="localhost"
pg_port=5432
pg_user="user"
pg_db="geospatial"
pg_pass="pass"
pg_schema="romania"

#⚙️ GeoServer
gs_url="http://localhost:8080/geoserver"
gs_user="user"
gs_pass="pass"
gs_workspace="administrative-boundaries"
gs_store="administrative-boundaries"
gs_layer_title="Limite administrative - Regiuni dezvoltare, România (poligon)"
gs_layer_abstract="Set de date ce conține limitele regiunilor de dezvoltare din România, în format vectorial de tip poligon, procesat de comunitatea geo-spatial.org pe baza datelor publice furnizate de Agenția Națională de Cadastru și Publicitate Imobiliară și Institutul Național de Statistică. Versiunea curentă reflectă organizarea administrativ-teritorială valabilă în România anulului 2025."
gs_layer_keywords=("România" "regiuni de dezvoltare" "limite administrative" "vector" "poligon")
gs_layer_metadata_link="https://services.geo-spatial.org/geonetwork/srv/eng/catalog.search#/metadata/b12a299a-1d61-4cfe-9db1-b9cc056279c0"
gs_layer_style="administrative-boundaries:ro_admin_region_polygon_labels"
gs_layer_style="administrative-boundaries:ro_admin_region_polygon"


#⚙️ Date
layer_name="ro_admin_region_polygon"

echo "
🛠 Procesare frontieră poligon
"

#💾 creare versiune GeoPackage
echo "💾 creare versiune GeoPackage"
if [ -f ${region_data_path}/${layer_name}.gpkg ]; then
    rm ${region_data_path}/${layer_name}.gpkg
fi
ogr2ogr -of GPKG -lco FID=id -dialect sqlite -sql "SELECT ST_Union(geometry) AS geometry, region AS name, regionId AS regionId, regionCode AS regionCode FROM ro_admin_county_polygon GROUP BY regionId" -nln ${layer_name} ${region_data_path}/${layer_name}.gpkg ${county_data_path}/ro_admin_county_polygon.gpkg

#💾 creare fișiere Esri Shapefile
echo "💾 creare fișiere Esri Shapefile"
if [ -f ${region_data_path}/${layer_name}.zip ]; then
    rm ${region_data_path}/${layer_name}.zip
fi
ogr2ogr -lco ENCODING=UTF-8 -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${region_data_path}/${layer_name}.shp ${region_data_path}/${layer_name}.gpkg

#📦 arhivare fișiere shp
echo "📦 arhivare fișiere shp"
zip -j ${region_data_path}/${layer_name}.zip ${region_data_path}/${layer_name}.dbf ${region_data_path}/${layer_name}.shp ${region_data_path}/${layer_name}.prj ${region_data_path}/${layer_name}.shx ${region_data_path}/${layer_name}.cpg

#💾 creare versiune FlatGeobuf
echo "💾 creare versiune FlatGeobuf"
if [ -f ${region_data_path}/${layer_name}.fgb ]; then
    rm ${region_data_path}/${layer_name}.fgb
fi
ogr2ogr -of FlatGeobuf -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" -nlt MULTIPOLYGON ${region_data_path}/${layer_name}.fgb ${region_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoParquet
echo "💾 creare versiune GeoParquet"
if [ -f ${region_data_path}/${layer_name}.parquet ]; then
    rm ${region_data_path}/${layer_name}.parquet
fi
ogr2ogr -of Parquet -nlt MULTIPOLYGON ${region_data_path}/${layer_name}.parquet ${region_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoJSON
echo "💾 creare versiune GeoJSON"
if [ -f ${region_data_path}/${layer_name}.geojson ]; then
    rm ${region_data_path}/${layer_name}.geojson
fi
ogr2ogr -of GeoJSON -t_srs EPSG:4326 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${region_data_path}/${layer_name}.geojson ${region_data_path}/${layer_name}.gpkg

#💾 creare versiune KML
echo "💾 creare versiune KML"
if [ -f ${region_data_path}/${layer_name}.kml ]; then
    rm ${region_data_path}/${layer_name}.kml
fi
ogr2ogr -of KML -t_srs EPSG:4326 -dsco NameField=name ${region_data_path}/${layer_name}.kml ${region_data_path}/${layer_name}.gpkg

#💾 creare versiune TopoJSON
echo "💾 creare versiune TopoJSON"
if [ -f ${region_data_path}/${layer_name}.topojson ]; then
    rm ${region_data_path}/${layer_name}.topojson
fi
mapshaper -i ${region_data_path}/${layer_name}.geojson -o format=topojson ${region_data_path}/${layer_name}.topojson

#💾 actualizarea setului de date în baza de date PostGIS
echo "💾 actualizarea setului de date în baza de date PostGIS"
ogr2ogr -of PostgreSQL PG:"host=${pg_host} port=${pg_port} user=${pg_user} dbname=${pg_db} password=${pg_pass}" -lco schema=${pg_schema} -lco GEOMETRY_NAME=geom -lco overwrite=yes ${region_data_path}/${layer_name}.gpkg ${layer_name} -skipfailures -overwrite

#🖇 indexare date PostGIS
psql -h ${pg_host} -p ${pg_port} -U ${pg_user} -d ${pg_db} -c "
CREATE INDEX ${layer_name}_geom_idx ON romania.${layer_name} USING GIST (geom);
CLUSTER romania.${layer_name} USING ${layer_name}_geom_idx;"

#💾 publicarea/actualizarea serviciilor de date
echo "💾 publicarea/actualizarea serviciilor de date"

#❌ ștergere strat existent (dacă există)
echo "🔍 Verificare dacă există stratul."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u $gs_user:$gs_pass \
  "${gs_url}/rest/layers/${gs_workspace}:${layer_name}.xml")

if [ "$HTTP_STATUS" == "200" ]; then
    echo "⚠️  Stratul există. Se șterge."
    curl -s -u $gs_user:$gs_pass -XDELETE \
      "${gs_url}/rest/layers/${gs_workspace}:${layer_name}?recurse=true"
    echo "🗑️  Stratul a fost șters."
else
    echo "✅ Nu există strat cu acest nume."
fi

#💾 creare strat
echo "➕ Creare strat ${layer_name}"
curl -s -u $gs_user:$gs_pass -XPOST -H "Content-type: text/xml" \
  -d "<featureType>
         <name>${layer_name}</name>
         <nativeName>${layer_name}</nativeName>
         <title>${gs_layer_title}</title>
         <abstract>${gs_layer_abstract}</abstract>
     </featureType>" \
  "${gs_url}/rest/workspaces/${gs_workspace}/datastores/${gs_store}/featuretypes"

#💾 adăugare detalii suplimentare (keywords și metadata link)
echo "📝 Actualizare metadate"
keywords_xml=""
for keyword in "${gs_layer_keywords[@]}"; do
    keywords_xml+="<string>${keyword}</string>"
done

curl -s -u $gs_user:$gs_pass -XPUT -H "Content-type: text/xml" \
-d "<featureType>
        <keywords>
            ${keywords_xml}
        </keywords>
        <metadataLinks>
            <metadataLink>
                <type>text/xml</type>
                <metadataType>ISO19115:2003</metadataType>
                <content>${gs_layer_metadata_link}</content>
            </metadataLink>
        </metadataLinks>
    </featureType>" \
"${gs_url}/rest/workspaces/${gs_workspace}/datastores/${gs_store}/featuretypes/${layer_name}"

#💾 Setare stil implicit
echo "🎨 Setare stil ${gs_layer_style}..."
curl -s -u $gs_user:$gs_pass -XPUT -H "Content-type: text/xml" \
  -d "<layer>
         <defaultStyle>
             <name>${gs_layer_style}</name>
         </defaultStyle>
     </layer>" \
  "${gs_url}/rest/layers/${gs_workspace}:${layer_name}"

echo "✅ Stratul ${layer_name} a fost adăugat și configurat cu succes în GeoServer."

#🗑️ Ștergere fișiere intermediare
echo "🗑️ Ștergere fișiere Shapefile"
rm ${region_data_path}/${layer_name}.dbf ${region_data_path}/${layer_name}.shp ${region_data_path}/${layer_name}.prj ${region_data_path}/${layer_name}.shx ${region_data_path}/${layer_name}.cpg
