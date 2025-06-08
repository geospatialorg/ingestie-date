#!/usr/bin/zsh

##############################################################################################################
#🛠 Publicare/actualizare frontieră linie
##############################################################################################################

#🎛 configurații

#🕹 activare mediu Anaconda cu bibliotecile necesare pentru procesare
source /home/ubuntu/anaconda3/etc/profile.d/conda.sh
conda activate geo

#🚏 definire căi date
ancpi_data_path="/storage/volumes/geoserver-1-storage/brute/institutii_romania/ancpi/limite_administrative"
out_data_path="/storage/volumes/geoserver-1-storage/administrative_boundaries/country"

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
gs_layer_title="Limite administrative - frontiera de stat, România (linie)"
gs_layer_abstract="Acest set de date conține limitele oficiale ale teritoriului României, în format vectorial de tip linie, procesat de comunitatea geo-spatial.org pe baza datelor publice furnizate de Agenția Națională de Cadastru și Publicitate Imobiliară."
gs_layer_keywords=("România" "frontiera de stat" "limite administrative" "vector" "linie")
gs_layer_metadata_link="https://services.geo-spatial.org/geonetwork/srv/eng/catalog.search#/metadata/a824c22d-6243-410e-a89a-d7d11199c077"
gs_layer_style="ro_admin_country_line"

#⚙️ Date
layer_name="ro_admin_country_line"

echo "
🛠 Procesare frontieră linie
"

#💾 creare versiune GPKG
echo "💾 creare versiune GPKG"
if [ -f ${out_data_path}/${layer_name}.gpkg ]; then
    rm ${out_data_path}/${layer_name}.gpkg
fi
ogr2ogr -of GPKG -lco FID=id -a_srs "EPSG:3844" -nln ${layer_name} -dialect sqlite -sql "SELECT a.localId AS border, a.beginVers AS version, a.Geometry AS geometry FROM Limita_administrativa_tara AS a" ${out_data_path}/${layer_name}.gpkg ${ancpi_data_path}/Limita_administrativa_tara.shp

#💾 creare versiune Shapefile
echo "💾 creare versiune Shapefile"
if [ -f ${out_data_path}/${layer_name}.zip ]; then
    rm ${out_data_path}/${layer_name}.zip
fi
ogr2ogr -lco ENCODING=UTF-8 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${out_data_path}/${layer_name}.shp ${out_data_path}/${layer_name}.gpkg

#📦 arhivare fișiere shp
echo "📦 arhivare fișiere shp"
zip -j ${out_data_path}/${layer_name}.zip ${out_data_path}/${layer_name}.dbf ${out_data_path}/${layer_name}.shp ${out_data_path}/${layer_name}.prj ${out_data_path}/${layer_name}.shx ${out_data_path}/${layer_name}.cpg

#💾 creare versiune FlatGeobuf
echo "💾 creare versiune FlatGeobuf"
if [ -f ${out_data_path}/${layer_name}.fgb ]; then
    rm ${out_data_path}/${layer_name}.fgb
fi
ogr2ogr -of FlatGeobuf -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" -nlt MULTILINESTRING ${out_data_path}/${layer_name}.fgb ${out_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoParquet
echo "💾 creare versiune GeoParquet"
if [ -f ${out_data_path}/${layer_name}.parquet ]; then
    rm ${out_data_path}/${layer_name}.parquet
fi
ogr2ogr -of Parquet -nlt MULTILINESTRING -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${out_data_path}/${layer_name}.parquet ${out_data_path}/${layer_name}.gpkg

#💾 creare versiune GeoJSON
echo "💾 creare versiune GeoJSON"
if [ -f ${out_data_path}/${layer_name}.geojson ]; then
    rm ${out_data_path}/${layer_name}.geojson
fi
ogr2ogr -of GeoJSON -t_srs EPSG:4326 -nln ${layer_name} -dialect sqlite -sql "SELECT a.id AS id, * FROM ${layer_name} AS a" ${out_data_path}/${layer_name}.geojson ${out_data_path}/${layer_name}.gpkg

#💾 creare versiune KML
echo "💾 creare versiune KML"
if [ -f ${out_data_path}/${layer_name}.kml ]; then
    rm ${out_data_path}/${layer_name}.kml
fi
ogr2ogr -of KML -t_srs EPSG:4326 -dsco NameField=name ${out_data_path}/${layer_name}.kml ${out_data_path}/${layer_name}.gpkg

#💾 creare versiune TopoJSON
echo "💾 creare versiune TopoJSON"
if [ -f ${out_data_path}/${layer_name}.topojson ]; then
    rm ${out_data_path}/${layer_name}.topojson
fi
mapshaper -i ${out_data_path}/${layer_name}.geojson -o format=topojson ${out_data_path}/${layer_name}.topojson

#💾 actualizarea setului de date în baza de date PostGIS
echo "💾 actualizarea setului de date în baza de date PostGIS"
ogr2ogr -of PostgreSQL PG:"host=${pg_host} port=${pg_port} user=${pg_user} dbname=${pg_db} password=${pg_pass}" -lco schema=${pg_schema} -lco GEOMETRY_NAME=geom -lco overwrite=yes ${out_data_path}/${layer_name}.gpkg ${layer_name} -skipfailures -overwrite

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
rm ${out_data_path}/${layer_name}.dbf ${out_data_path}/${layer_name}.shp ${out_data_path}/${layer_name}.prj ${out_data_path}/${layer_name}.shx ${out_data_path}/${layer_name}.cpg
