#!/usr/bin/zsh

##############################################################################################################
#🛠 Publicare/actualizare UAT, România (linie, geometrie simplificată, București unificat)
##############################################################################################################

#🎛 configurații

#🕹 activare mediu Anaconda cu bibliotecile necesare pentru procesare
source /home/ubuntu/anaconda3/etc/profile.d/conda.sh
conda activate geo

#🚏 definire căi date
lau_data_path="/storage/volumes/geoserver-1-storage/administrative_boundaries/lau"

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
gs_layer_title="Limite administrative - UAT, România (linie, geometrie simplificată, București unificat)"
gs_layer_abstract="Set de date este derivat din stratul \"Limite administrative - UAT, România (linie, geometrie simplificată)\". Geometria originală a fost procesată pentru a elimina limitele interne dintre sectoarele Municipiului București. Este util pentru afișarea rapidă a limitelor UAT în aplicații unde se dorește reprezentarea Municipiului București ca o singură entitate."
gs_layer_keywords=("România" "UAT" "limite administrative" "vector" "linie" "București unificat", "geometrie simplificată")
gs_layer_metadata_link="https://services.geo-spatial.org/geonetwork/srv/eng/catalog.search#/metadata/74ed32a9-c001-4765-a3ec-5fd516053dcc"
gs_layer_style="administrative-boundaries:ro_admin_lau_bucharest_merged_line"

#⚙️ Date
layer_name="ro_admin_lau_simplified_bucharest_merged_line"

echo "
🛠  Procesare UAT, România (linie, geometrie simplificată, București unificat)
"

#💾 creare versiune GeoPackage cu ștergerea limitelor interne dintre sectoare și păstrarea conturului Municipiului București (și înlocuirea leftLAU/rightLAU din sector în București)
echo "💾 creare versiune GeoPackage"
if [ -f ${lau_data_path}/${layer_name}.gpkg ]; then
rm ${lau_data_path}/${layer_name}.gpkg
fi
ogr2ogr -of GPKG -lco FID=id -nln ${layer_name} \
  -dialect sqlite \
  -sql "SELECT
           id,
           CASE
             WHEN leftLAU IN ('București Sectorul 1', 'București Sectorul 2', 'București Sectorul 3',
                              'București Sectorul 4', 'București Sectorul 5', 'București Sectorul 6')
             THEN 'București'
             ELSE leftLAU
           END AS leftLAU,
           CASE
             WHEN rightLAU IN ('București Sectorul 1', 'București Sectorul 2', 'București Sectorul 3',
                               'București Sectorul 4', 'București Sectorul 5', 'București Sectorul 6')
             THEN 'București'
             ELSE rightLAU
           END AS rightLAU,
           leftId,
           rightId,
           version,
           legalStat,
           geometry
        FROM ro_admin_lau_simplified_line
        WHERE id NOT IN (9010, 9011, 9012, 9633, 9215, 9009, 9013, 9014, 9015)" \
  ${lau_data_path}/${layer_name}.gpkg ${lau_data_path}/ro_admin_lau_simplified_line.gpkg

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
ogr2ogr -of FlatGeobuf -nlt MULTILINESTRING -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a WHERE a.geometry IS NOT NULL" ${lau_data_path}/${layer_name}.fgb ${lau_data_path}/${layer_name}.gpkg

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
ogr2ogr -of GeoJSON -t_srs EPSG:4326 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a WHERE a.geometry IS NOT NULL" ${lau_data_path}/${layer_name}.geojson ${lau_data_path}/${layer_name}.gpkg

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
mapshaper -i ${lau_data_path}/${layer_name}.geojson -o format=topojson ${lau_data_path}/${layer_name}.topojson

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

#💾 Setare stil implicit
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
rm ${lau_data_path}/${layer_name}.dbf ${lau_data_path}/${layer_name}.shp ${lau_data_path}/${layer_name}.prj ${lau_data_path}/${layer_name}.shx ${lau_data_path}/${layer_name}.cpg
