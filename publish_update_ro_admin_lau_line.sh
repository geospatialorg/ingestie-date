#!/usr/bin/zsh

##############################################################################################################
#🛠 Publicare/actualizare UAT linie
##############################################################################################################

#🎛 configurații

#🕹 activare mediu Anaconda cu bibliotecile necesare pentru procesare
source /home/ubuntu/anaconda3/etc/profile.d/conda.sh
conda activate geo

#🚏 definire căi date
ins_data_path="/storage/volumes/geoserver-1-storage/brute/institutii_romania/ins/siruta"
ancpi_data_path="/storage/volumes/geoserver-1-storage/brute/institutii_romania/ancpi/limite_administrative"
lau_data_path="/storage/volumes/geoserver-1-storage/administrative_boundaries/lau"
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
gs_layer_title="Limite administrative - UAT, România (linie)"
gs_layer_abstract="Acest set de date conține limitele oficiale ale unităților administrative (UAT) din România, în format vectorial de tip linie, procesat de comunitatea geo-spatial.org pe baza datelor publice furnizate de Agenția Națională de Cadastru și Publicitate Imobiliară. Atributele includ denumirea și codul SIRUTA a celor două UAT-uri care împart respectiva limită, statutul legal (dacă limita a fost sau nu agreată oficial de către cele două UAT-uri) și versiunea setului de date. Versiunea curentă reflectă organizarea administrativ-teritorială valabilă în România anulului 2025."
gs_layer_keywords=("România" "UAT" "limite administrative" "vector" "linie")
gs_layer_metadata_link="https://services.geo-spatial.org/geonetwork/srv/eng/catalog.search#/metadata/e4d24e1e-f749-4425-806f-1c33dabd20f2"
gs_layer_style="administrative-boundaries:ro_admin_lau_line"

#⚙️ Date
layer_name="ro_admin_lau_line"

echo "
🛠 Procesare UAT linie
 "

ogr2ogr -of SQLite -append -a_srs "EPSG:3844" ${tmp_data_path}/uat.db ${ancpi_data_path}/Limita_administrativa_UAT.shp

sqlite3 ${tmp_data_path}/uat.db "CREATE TABLE split_siruta AS SELECT id, substr(localid, 1, instr(localid, '.') - 1) AS leftId, substr(localid, instr(localid, '.') + 1) AS rightId FROM Limita_administrativa_UAT"

ogr2ogr -of "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ${layer_name} -sql "SELECT a.OGC_FID AS id, c.name AS leftLAU, d.name AS rightLAU, CAST(b.leftId AS INTEGER) AS leftId, CAST(b.rightId AS INTEGER) AS rightId, a.beginvers AS version, a.legalStat AS legalStat, a.GEOMETRY FROM Limita_administrativa_UAT AS a LEFT JOIN split_siruta AS b ON (a.id = b.id) LEFT JOIN ro_admin_lau_polygon AS c ON (b.leftId=c.natCode) LEFT JOIN ro_admin_lau_polygon AS d ON (b.rightId=d.natCode)" ${tmp_data_path}/uat.db ${tmp_data_path}/uat.db

#💾 creare versiune GeoPackage
echo "💾 creare versiune GeoPackage"
if [ -f ${lau_data_path}/${layer_name}.gpkg ]; then
    rm ${lau_data_path}/${layer_name}.gpkg
fi
ogr2ogr -of GPKG -lco FID=id -a_srs EPSG:3844 -nlt MULTILINESTRING -nln ${layer_name} -dialect sqlite -sql "SELECT GEOMETRY AS geometry, * FROM ${layer_name}" ${lau_data_path}/${layer_name}.gpkg ${tmp_data_path}/uat.db

#💾 creare fișiere Esri Shapefile
echo "💾 creare fișiere Esri Shapefile"
if [ -f ${lau_data_path}/${layer_name}.zip ]; then
    rm ${lau_data_path}/${layer_name}.zip
fi
ogr2ogr -lco ENCODING=UTF-8 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${lau_data_path}/${layer_name}.shp ${lau_data_path}/${layer_name}.gpkg

#📦 arhivare fișiere shp
echo "📦 arhivare fișiere shp"
zip -j ${lau_data_path}/${layer_name}.zip ${lau_data_path}/${layer_name}.dbf ${lau_data_path}/${layer_name}.shp ${lau_data_path}/${layer_name}.prj ${lau_data_path}/${layer_name}.shx ${lau_data_path}/${layer_name}.cpg

#💾 creare versiune FlatGeobuf
echo "💾 creare versiune FlatGeobuf"
if [ -f ${lau_data_path}/${layer_name}.fgb ]; then
    rm ${lau_data_path}/${layer_name}.fgb
fi
ogr2ogr -of FlatGeobuf -nlt MULTILINESTRING -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${lau_data_path}/${layer_name}.fgb ${lau_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoParquet
echo "💾 creare versiune GeoParquet"
if [ -f ${lau_data_path}/${layer_name}.parquet ]; then
    rm ${lau_data_path}/${layer_name}.parquet
fi
ogr2ogr -of Parquet -nlt MULTILINESTRING -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${lau_data_path}/${layer_name}.parquet ${lau_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoJSON
echo "💾 creare versiune GeoJSON"
if [ -f ${lau_data_path}/${layer_name}.geojson ]; then
    rm ${lau_data_path}/${layer_name}.geojson
fi
ogr2ogr -of GeoJSON -t_srs EPSG:4326 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${lau_data_path}/${layer_name}.geojson ${lau_data_path}/${layer_name}.gpkg

#💾 creare versiune KML
echo "💾 creare versiune KML"
if [ -f ${lau_data_path}/${layer_name}.kml ]; then
    rm ${lau_data_path}/${layer_name}.kml
fi
ogr2ogr -of KML -t_srs EPSG:4326 -dsco NameField=name ${lau_data_path}/${layer_name}.kml ${lau_data_path}/${layer_name}.gpkg

#💾 creare versiune TopoJSON
echo "💾 creare versiune TopoJSON"
if [ -f ${lau_data_path}/${layer_name}.topojson ]; then
    rm ${lau_data_path}/${layer_name}.topojson
fi
mapshaper -i ${lau_data_path}/${layer_name}.shp -o format=topojson ${lau_data_path}/${layer_name}.topojson

#💾 actualizarea setului de date în baza de date PostGIS
echo "💾 actualizarea setului de date în baza de date PostGIS"
ogr2ogr -of PostgreSQL PG:"host=${pg_host} port=${pg_port} user=${pg_user} dbname=${pg_db} password=${pg_pass}" -lco schema=${pg_schema} -lco GEOMETRY_NAME=geom -lco overwrite=yes ${lau_data_path}/${layer_name}.gpkg ${layer_name} -skipfailures -overwrite

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
     </layer>" \
  "${gs_url}/rest/layers/${gs_workspace}:${layer_name}"

echo "✅ Stratul ${layer_name} a fost adăugat și configurat cu succes în GeoServer."

#🗑️ Ștergere fișiere intermediare
echo "🗑️ Ștergere fișiere Shapefile"
rm ${lau_data_path}/${layer_name}.dbf ${lau_data_path}/${layer_name}.shp ${lau_data_path}/${layer_name}.prj ${lau_data_path}/${layer_name}.shx ${lau_data_path}/${layer_name}.cpg ${tmp_data_path}/uat.db ${tmp_data_path}/siruta.csv ${tmp_data_path}/siruta_corectat.csv
