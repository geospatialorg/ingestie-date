#!/usr/bin/zsh

##############################################################################################################
#🛠 Macroregiuni, România (linie, geometrie simplificată)
##############################################################################################################

#🎛 configurații

#🕹 activare mediu Anaconda cu bibliotecile necesare pentru procesare
source /home/ubuntu/anaconda3/etc/profile.d/conda.sh
conda activate geo

#🚏 definire căi date
macroregion_data_path="/storage/volumes/geoserver-1-storage/administrative_boundaries/macroregion"


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
gs_layer_title="Macroregiuni, România (linie, geometrie simplificată)"
gs_layer_abstract="Set de date care conține limitele macroregiunilor din România, în format vectorial de tip linie, procesat de comunitatea geo-spatial.org pe baza datelor publice furnizate de Agenția Națională de Cadastru și Publicitate Imobiliară și Institutul Național de Statistică. Geometria originală a fost simplificată pentru scenariile în care este nevoie de o afișare rapidă a datelor sau reprezentarea la scări mici (ex: aplicații cartografice web)."
gs_layer_keywords=("România" "macroregiuni" "limite administrative" "vector" "linie" "geometrie simplificată")
gs_layer_metadata_link="https://services.geo-spatial.org/geonetwork/srv/eng/catalog.search#/metadata/9bdbf76d-a3e8-4327-a16e-a4a45345c0b9"
gs_layer_style="administrative-boundaries:ro_admin_macroregion_simplified_line"


#⚙️ Date
layer_name="ro_admin_macroregion_simplified_line"

echo "
🛠 Procesare Macroregiuni, România (linie)
"

#💾 creare versiune GeoPackage
echo "💾 creare versiune GeoPackage"
if [ -f ${macroregion_data_path}/${layer_name}.gpkg ]; then
    rm ${macroregion_data_path}/${layer_name}.gpkg
fi

#💾 apelează script Python pentru conversie și crearea câmpurilor leftName, leftId, respectiv rightName și rightId
echo "💾 apelează script Python pentru conversie"
python convert_ro_admin_macroregion_simplified_polygon_to_line.py

#💾 creare fișier GeoPackage final
echo "💾 creare fișier GeoPackage final"
ogr2ogr -of GPKG -lco FID=id -nln ${layer_name} -nlt MULTILINESTRING ${macroregion_data_path}/${layer_name}.gpkg ${macroregion_data_path}/${layer_name}_tmp.gpkg

#💾 creare fișiere Esri Shapefile
echo "💾 creare fișiere Esri Shapefile"
if [ -f ${macroregion_data_path}/${layer_name}.zip ]; then
    rm ${macroregion_data_path}/${layer_name}.zip
fi
ogr2ogr -lco ENCODING=UTF-8 -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${macroregion_data_path}/${layer_name}.shp ${macroregion_data_path}/${layer_name}.gpkg

#📦 arhivare fișiere shp
echo "📦 arhivare fișiere shp"
zip -j ${macroregion_data_path}/${layer_name}.zip ${macroregion_data_path}/${layer_name}.dbf ${macroregion_data_path}/${layer_name}.shp ${macroregion_data_path}/${layer_name}.prj ${macroregion_data_path}/${layer_name}.shx ${macroregion_data_path}/${layer_name}.cpg

#💾 creare versiune FlatGeobuf
echo "💾 creare versiune FlatGeobuf"
if [ -f ${macroregion_data_path}/${layer_name}.fgb ]; then
    rm ${macroregion_data_path}/${layer_name}.fgb
fi
ogr2ogr -of FlatGeobuf -nlt MULTILINESTRING -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${macroregion_data_path}/${layer_name}.fgb ${macroregion_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoParquet
echo "💾 creare versiune GeoParquet"
if [ -f ${macroregion_data_path}/${layer_name}.parquet ]; then
    rm ${macroregion_data_path}/${layer_name}.parquet
fi
ogr2ogr -of Parquet -nlt MULTILINESTRING ${macroregion_data_path}/${layer_name}.parquet ${macroregion_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoJSON
echo "💾 creare versiune GeoJSON"
if [ -f ${macroregion_data_path}/${layer_name}.geojson ]; then
    rm ${macroregion_data_path}/${layer_name}.geojson
fi
ogr2ogr -of GeoJSON -t_srs EPSG:4326 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${macroregion_data_path}/${layer_name}.geojson ${macroregion_data_path}/${layer_name}.gpkg

#💾 creare versiune KML
echo "💾 creare versiune KML"
if [ -f ${macroregion_data_path}/${layer_name}.kml ]; then
    rm ${macroregion_data_path}/${layer_name}.kml
fi
ogr2ogr -of KML -t_srs EPSG:4326 -dsco NameField=name ${macroregion_data_path}/${layer_name}.kml ${macroregion_data_path}/${layer_name}.gpkg

#💾 creare versiune TopoJSON
echo "💾 creare versiune TopoJSON"
if [ -f ${macroregion_data_path}/${layer_name}.topojson ]; then
    rm ${macroregion_data_path}/${layer_name}.topojson
fi
mapshaper -i ${macroregion_data_path}/${layer_name}.shp -o format=topojson ${macroregion_data_path}/${layer_name}.topojson

#💾 actualizarea setului de date în baza de date PostGIS
echo "💾 actualizarea setului de date în baza de date PostGIS"
ogr2ogr -of PostgreSQL PG:"host=${pg_host} port=${pg_port} user=${pg_user} dbname=${pg_db} password=${pg_pass}" -lco schema=${pg_schema} -lco GEOMETRY_NAME=geom -lco overwrite=yes ${macroregion_data_path}/${layer_name}.gpkg ${layer_name} -skipfailures -overwrite

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
rm ${macroregion_data_path}/${layer_name}.dbf ${macroregion_data_path}/${layer_name}.shp ${macroregion_data_path}/${layer_name}.prj ${macroregion_data_path}/${layer_name}.shx ${macroregion_data_path}/${layer_name}.cpg ${macroregion_data_path}/ro_admin_macroregion_simplified_line_tmp.gpkg
