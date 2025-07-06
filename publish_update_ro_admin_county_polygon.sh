#!/usr/bin/zsh

##############################################################################################################
#🛠 Publicare/actualizare Județe, România (poligon)
##############################################################################################################

#🎛 configurații

#🕹 activare mediu Anaconda cu bibliotecile necesare pentru procesare
source /home/ubuntu/anaconda3/etc/profile.d/conda.sh
conda activate geo

#🚏 definire căi date
ins_data_path="/storage/volumes/geoserver-1-storage/brute/institutii_romania/ins/siruta"
ancpi_data_path="/storage/volumes/geoserver-1-storage/brute/institutii_romania/ancpi/limite_administrative"
county_data_path="/storage/volumes/geoserver-1-storage/administrative_boundaries/county"
tmp_data_path="/storage/volumes/geoserver-1-storage/tmp"

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
gs_layer_title="Limite administrative - județe, România (poligon)"
gs_layer_abstract="Setul de date conține limitele oficiale ale județelor din România, în format vectorial de tip poligon, procesat de comunitatea geo-spatial.org pe baza datelor publice furnizate de Agenția Națională de Cadastru și Publicitate Imobiliară. Versiunea curentă reflectă organizarea administrativ-teritorială valabilă în România anulului 2025."
gs_layer_keywords=("România" "județe" "limite administrative" "vector" "poligon")
gs_layer_metadata_link="https://services.geo-spatial.org/geonetwork/srv/eng/catalog.search#/metadata/0cf21019-7f4c-41ce-b1cb-3cac94a62d2e   "
gs_layer_style="administrative-boundaries:ro_admin_county_polygon_labels"
gs_layer_secondary_style="administrative-boundaries:ro_admin_county_polygon"

#⚙️ Date
layer_name="ro_admin_county_polygon"

echo "
🛠 Procesare Județe, România (poligon)
 "

echo "💾 Încărcare date în SQLite"

#💾 încărcare SHP ANCPI în SQLite
ogr2ogr -of "SQLite" -a_srs "EPSG:3844" -lco LAUNDER=NO ${tmp_data_path}/judete.db ${ancpi_data_path}/Unitate_administrativa_judet.shp

#💾 încărcare tabel regiuni de dezvoltare în SQLite
csvsql --db sqlite:///${tmp_data_path}/judete.db --insert ${ins_data_path}/siruta_zone.csv

#💾 încărcare tabel județe în SQLITE
csvsql --db sqlite:///${tmp_data_path}/judete.db --insert ${ins_data_path}/siruta_judete.csv

ogr2ogr -of "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ${layer_name} -sql "SELECT a.OGC_FID AS id, CAST(b.jud AS INTEGER) AS countyId, CAST(b.siruta AS INTEGER) AS countyCode, b.denj AS name, b.mnemonic, CAST(c.zona AS INTEGER) AS regionId, CAST(c.siruta AS INTEGER)  AS regionCode, c.denzona AS region, CAST(b.FSJ AS INTEGER) AS sortCode, a.beginvers AS version, a.GEOMETRY FROM Unitate_administrativa_judet AS a LEFT JOIN siruta_judete AS b ON (a.natcode = b.siruta) LEFT JOIN siruta_zone AS c ON (b.zona=c.zona)" ${tmp_data_path}/judete.db ${tmp_data_path}/judete.db

#💾 creare fișiere GeoPackage
echo "💾 creare fișiere GeoPackage"
if [ -f ${county_data_path}/${layer_name}.gpkg ]; then
    rm ${county_data_path}/${layer_name}.gpkg
fi
ogr2ogr -of GPKG -lco FID=id -nln ${layer_name} -a_srs EPSG:3844 -dialect sqlite -sql "SELECT GEOMETRY AS geometry, * FROM ${layer_name}" ${county_data_path}/${layer_name}.gpkg ${tmp_data_path}/judete.db

#💾 creare fișiere Esri Shapefile
echo "💾 creare fișiere Esri Shapefile"
if [ -f ${county_data_path}/${layer_name}.zip ]; then
    rm ${county_data_path}/${layer_name}.zip
fi
ogr2ogr -lco ENCODING=UTF-8 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${county_data_path}/${layer_name}.shp ${county_data_path}/${layer_name}.gpkg

#📦 arhivare fișiere shp
echo "📦 arhivare fișiere shp"
zip -j ${county_data_path}/${layer_name}.zip ${county_data_path}/${layer_name}.dbf ${county_data_path}/${layer_name}.shp ${county_data_path}/${layer_name}.prj ${county_data_path}/${layer_name}.shx  ${county_data_path}/${layer_name}.cpg

#💾 creare versiune FlatGeobuf
echo "💾 creare versiune FlatGeobuf"
if [ -f ${county_data_path}/${layer_name}.fgb ]; then
    rm ${county_data_path}/${layer_name}.fgb
fi
ogr2ogr -of FlatGeobuf -nlt MULTIPOLYGON -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${county_data_path}/${layer_name}.fgb ${county_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoParquet
echo "💾 creare versiune GeoParquet"
if [ -f ${county_data_path}/${layer_name}.parquet ]; then
    rm ${county_data_path}/${layer_name}.parquet
fi
ogr2ogr -of Parquet -nlt MULTIPOLYGON -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${county_data_path}/${layer_name}.parquet ${county_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoJSON
echo "💾 creare versiune GeoJSON"
if [ -f ${county_data_path}/${layer_name}.geojson ]; then
    rm ${county_data_path}/${layer_name}.geojson
fi
ogr2ogr -of GeoJSON -t_srs EPSG:4326 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${county_data_path}/${layer_name}.geojson ${county_data_path}/${layer_name}.gpkg

#💾 creare versiune KML
echo "💾 creare versiune KML"
if [ -f ${county_data_path}/${layer_name}.kml ]; then
    rm ${county_data_path}/${layer_name}.kml
fi
ogr2ogr -of KML -t_srs EPSG:4326 -dsco NameField=name ${county_data_path}/${layer_name}.kml ${county_data_path}/${layer_name}.gpkg

#💾 creare versiune TopoJSON
echo "💾 creare versiune TopoJSON"
if [ -f ${county_data_path}/${layer_name}.topojson ]; then
    rm ${county_data_path}/${layer_name}.topojson
fi
mapshaper -i ${county_data_path}/${layer_name}.geojson -o format=topojson ${county_data_path}/${layer_name}.topojson

#💾 actualizarea setului de date în baza de date PostGIS
echo "💾 actualizarea setului de date în baza de date PostGIS"
ogr2ogr -of PostgreSQL PG:"host=${pg_host} port=${pg_port} user=${pg_user} dbname=${pg_db} password=${pg_pass}" -lco schema=${pg_schema} -lco GEOMETRY_NAME=geom -lco overwrite=yes ${county_data_path}/${layer_name}.gpkg ${layer_name} -skipfailures -overwrite

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

#💾 Setare stil implicit + atașare stil suplimentar
echo "🎨 Setare stil implicit + atașare stil suplimentar..."
curl -s -u $gs_user:$gs_pass -XPUT -H "Content-type: text/xml" \
  -d "<layer>
         <defaultStyle>
             <name>${gs_layer_style##*:}</name>
         </defaultStyle>
         <styles>
             <style>
                 <name>${gs_layer_secondary_style##*:}</name>
             </style>
         </styles>
     </layer>" \
  "${gs_url}/rest/layers/${gs_workspace}:${layer_name}"

echo "✅ Stratul ${layer_name} a fost adăugat și configurat cu succes în GeoServer."

#🗑️ Ștergere fișiere intermediare
echo "🗑️ Ștergere fișiere Shapefile"
rm ${county_data_path}/${layer_name}.dbf ${county_data_path}/${layer_name}.shp ${county_data_path}/${layer_name}.prj ${county_data_path}/${layer_name}.shx ${county_data_path}/${layer_name}.cpg
