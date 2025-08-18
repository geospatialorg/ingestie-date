#!/usr/bin/zsh

##############################################################################################################
#🛠 Publicare/actualizare UAT, România (poligon)
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
gs_layer_title="Limite administrative - UAT, România (poligon)"
gs_layer_abstract="Set de date care conține limitele oficiale ale unităților administrativ-teritoriale (UAT) din România, în format vectorial de tip poligon, procesat de comunitatea geo-spatial.org pe baza datelor publice furnizate de Agenția Națională de Cadastru și Publicitate Imobiliară. Versiunea curentă reflectă organizarea administrativ-teritorială valabilă în România anului 2025."
gs_layer_keywords=("România" "UAT" "limite administrative" "vector" "poligon")
gs_layer_metadata_link="https://services.geo-spatial.org/geonetwork/srv/eng/catalog.search#/metadata/5d90a442-0659-4ad9-9af1-9b890b2ff0c8"
gs_layer_style="administrative-boundaries:ro_admin_lau_polygon_labels"
gs_layer_secondary_style="administrative-boundaries:ro_admin_lau_polygon"

#⚙️ Date
layer_name="ro_admin_lau_polygon"

echo "
🛠 Procesare UAT, România (poligon)
 "

echo "💾 Încărcare date în SQLite"

#💾 încărcare SHP ANCPI în SQLite
ogr2ogr  -of "SQLite" -a_srs "EPSG:3844" -lco LAUNDER=NO ${tmp_data_path}/uat.db ${ancpi_data_path}/Unitate_administrativa_UAT.shp

#💾 încărcare tabel regiuni de dezvoltare în SQLite
csvsql --db sqlite:///${tmp_data_path}/uat.db --insert ${ins_data_path}/siruta_zone.csv

#💾 încărcare tabel județe în SQLite
csvsql --db sqlite:///${tmp_data_path}/uat.db --insert ${ins_data_path}/siruta_judete.csv

#💾 conversie MDB în CSV
mdb-export ${ins_data_path}/siruta.mdb siruta_rez > ${tmp_data_path}/siruta.csv

#💾 formatare CSV: se elimină câmpurile nerelevante (FSJ, FS2, FS3, fictiv); se formatează câmpurile de tip text ca "lowercase"; se convertesc câmpurile SIRUTA, CODP și SIRSUP din notarea științifică în format integer
awk -F, 'BEGIN{printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n","siruta","denloc","codp","jud","sirsup","tip","niv","med","regiune","fsl", "rang")} NR>1{printf("%.0f,%s,%.0f,%d,%.0f,%d,%d,%s,%d,%s,%s\n",$1,tolower($2),$3,$4,$5,$6,$7,$8,$9,$13,$14)}' ${tmp_data_path}/siruta.csv > ${tmp_data_path}/siruta_corectat.csv

#💾 înlocuire diacritice incorecte ("ș" și "ț" din sedilă în virgulă; se corectează "ă")
sed -i -e 's/ş/ș/g' -e 's/ţ/ț/g' -e 's/ã/ă/g' ${tmp_data_path}/siruta_corectat.csv

#💾 conversie cîmpuri de tip text din "lowercase" în "titlecase" - este exceptat primul rînd, cel cu numele de coloane
sed -i '2,$s/.*/\L&/; 2,$s/[a-z]*/\u&/g' ${tmp_data_path}/siruta_corectat.csv

#💾 înlocuire prepoziții folosite în numele de localități din "titlecase" înapoi în "lowercase"
sed -i -e 's/ De / de /g' -e 's/ Din / din /g' -e 's/ La / la /g' -e 's/ Pe / pe /g' -e 's/ Cu / cu /g' -e 's/ Lui / lui /g' -e 's/ Cel / cel /g' -e 's/ Sub / sub /g' -e 's/ In / în /g' -e 's/ ii/ II/g' -e 's/Municipiul //g' -e 's/Oraș //g' ${tmp_data_path}/siruta_corectat.csv

#💾 încărcare tabel SIRUTA în SQLITE
csvsql --db sqlite:///${tmp_data_path}/uat.db --insert ${tmp_data_path}/siruta_corectat.csv

#💾 creare fișier final în SQLITE prin unirea datele originale optimizate (ex: câmpurile redundante eliminate) cu cele din tabelele SIRUTA
ogr2ogr -of "SQLite" -append -dsco SPATIALITE=YES -lco LAUNDER=NO -a_srs EPSG:3844 -nln ro_admin_lau_polygon -sql "SELECT CAST(a.natCode AS INTEGER) AS natCode, TRIM(b.denloc) AS name, a.natLevName AS natLevName, CAST(c.jud AS INTEGER) AS countyId, CAST(c.siruta AS INTEGER) AS countyCode, c.denj AS county, c.mnemonic AS countyMn, CAST(d.zona AS INTEGER) AS regionId, CAST(d.siruta AS INTEGER) AS regionCode, d.denzona AS region, a.beginvers AS version, a.GEOMETRY FROM Unitate_administrativa_UAT AS a LEFT JOIN siruta_corectat AS b ON (a.natcode = b.siruta) LEFT JOIN siruta_judete AS c ON (c.jud=b.jud) LEFT JOIN siruta_zone AS d ON (c.zona=d.zona)" ${tmp_data_path}/uat.db ${tmp_data_path}/uat.db

#💾 creare versiune GeoPackage
echo "💾 creare versiune GeoPackage"
if [ -f ${lau_data_path}/ro_admin_lau_polygon.gpkg ]; then
    rm ${lau_data_path}/ro_admin_lau_polygon.gpkg
fi
ogr2ogr -of GPKG -lco FID=id -a_srs EPSG:3844 -nln ro_admin_lau_polygon -dialect sqlite -sql "SELECT GEOMETRY AS geometry, * FROM ro_admin_lau_polygon" ${lau_data_path}/ro_admin_lau_polygon.gpkg ${tmp_data_path}/uat.db

#💾 creare fișiere Esri Shapefile
echo "💾 creare fișiere Esri Shapefile"
if [ -f ${lau_data_path}/ro_admin_lau_polygon.zip ]; then
    rm ${lau_data_path}/ro_admin_lau_polygon.zip
fi
ogr2ogr -lco ENCODING=UTF-8 -nln ro_admin_lau_polygon -dialect sqlite -sql "SELECT a.id AS id, * FROM ro_admin_lau_polygon AS a" ${lau_data_path}/ro_admin_lau_polygon.shp ${lau_data_path}/ro_admin_lau_polygon.gpkg

#📦 arhivare fișiere shp
echo "📦 arhivare fișiere shp"
zip -j ${lau_data_path}/ro_admin_lau_polygon.zip ${lau_data_path}/ro_admin_lau_polygon.dbf ${lau_data_path}/ro_admin_lau_polygon.shp ${lau_data_path}/ro_admin_lau_polygon.prj ${lau_data_path}/ro_admin_lau_polygon.shx ${lau_data_path}/ro_admin_lau_polygon.cpg

#💾 creare versiune FlatGeobuf
echo "💾 creare versiune FlatGeobuf"
if [ -f ${lau_data_path}/ro_admin_lau_polygon.fgb ]; then
    rm ${lau_data_path}/ro_admin_lau_polygon.fgb
fi
ogr2ogr -of FlatGeobuf -nlt MULTIPOLYGON -nln ro_admin_lau_polygon -dialect sqlite -sql "SELECT a.id AS id, * FROM ro_admin_lau_polygon AS a" ${lau_data_path}/ro_admin_lau_polygon.fgb ${lau_data_path}/ro_admin_lau_polygon.gpkg

#💾 creare versiune GeoParquet
echo "💾 creare versiune GeoParquet"
if [ -f ${lau_data_path}/ro_admin_lau_polygon.parquet ]; then
    rm ${lau_data_path}/ro_admin_lau_polygon.parquet
fi
ogr2ogr -of Parquet -nlt MULTIPOLYGON -nln ro_admin_lau_polygon -dialect sqlite -sql "SELECT a.id AS id, * FROM ro_admin_lau_polygon AS a" ${lau_data_path}/ro_admin_lau_polygon.parquet ${lau_data_path}/ro_admin_lau_polygon.gpkg

#💾 creare versiune GeoJSON
echo "💾 creare versiune GeoJSON"
if [ -f ${lau_data_path}/ro_admin_lau_polygon.geojson ]; then
    rm ${lau_data_path}/ro_admin_lau_polygon.geojson
fi
ogr2ogr -of GeoJSON -t_srs EPSG:4326 -nln ro_admin_lau_polygon -dialect sqlite -sql "SELECT a.id AS id, * FROM ro_admin_lau_polygon AS a" ${lau_data_path}/ro_admin_lau_polygon.geojson ${lau_data_path}/ro_admin_lau_polygon.gpkg

#💾 creare versiune KML
echo "💾 creare versiune KML"
if [ -f ${lau_data_path}/ro_admin_lau_polygon.kml ]; then
    rm ${lau_data_path}/ro_admin_lau_polygon.kml
fi
ogr2ogr -of KML -t_srs EPSG:4326 -dsco NameField=name ${lau_data_path}/ro_admin_lau_polygon.kml ${lau_data_path}/ro_admin_lau_polygon.gpkg

#💾 creare versiune TopoJSON
echo "💾 creare versiune TopoJSON"
if [ -f ${lau_data_path}/ro_admin_lau_polygon.topojson ]; then
    rm ${lau_data_path}/ro_admin_lau_polygon.topojson
fi
mapshaper -i ${lau_data_path}/ro_admin_lau_polygon.geojson -o format=topojson ${lau_data_path}/ro_admin_lau_polygon.topojson

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
rm ${lau_data_path}/${layer_name}.dbf ${lau_data_path}/${layer_name}.shp ${lau_data_path}/${layer_name}.prj ${lau_data_path}/${layer_name}.shx ${lau_data_path}/${layer_name}.cpg ${tmp_data_path}/uat.db ${tmp_data_path}/siruta.csv ${tmp_data_path}/siruta_corectat.csv
