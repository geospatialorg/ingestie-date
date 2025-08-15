import json
from collections import defaultdict
from osgeo import ogr
from shapely.geometry import shape, LineString
from shapely.ops import unary_union

# Activăm excepțiile pentru a vedea erorile clare din ogr
ogr.UseExceptions()

# === CONFIGURARE ===
input_file = "/storage/volumes/geoserver-1-storage/administrative_boundaries/region/ro_admin_region_polygon.gpkg"           # fișierul sursă cu poligoane
input_layer_name = "ro_admin_region_polygon"          # numele stratului de poligoane
field_name_name = "name"                              # câmpul cu denumirea regiunii
field_name_id = "regionCode"                          # câmpul cu codul numeric al regiunii
output_file = "/storage/volumes/geoserver-1-storage/administrative_boundaries/region/ro_admin_region_line_tmp.gpkg"         # fișierul rezultat (linii)
output_layer_name = "ro_admin_region_line_tmp"        # numele stratului rezultat

# === Citim poligoanele din fișierul de intrare ===
source = ogr.Open(input_file)
layer = source.GetLayerByName(input_layer_name)
features = list(layer)

# === Dicționar care va conține toate segmentele de frontieră ===
# cheia = segmentul normalizat (punct1, punct2), valoarea = listă de regiuni (name, id)
segment_dict = defaultdict(list)

# Funcție care normalizează un segment (îl ordonează astfel încât să poată fi comparat ușor)
def normalize_segment(p1, p2):
    return (p1, p2) if p1 <= p2 else (p2, p1)

# Parcurgem fiecare poligon pentru a extrage conturul sub formă de segmente individuale
for feat in features:
    # Convertim geometria în format shapely
    geom = shape(json.loads(feat.geometry().ExportToJson()))
    name = feat.GetField(field_name_name)
    code = feat.GetField(field_name_id)
    boundary = geom.boundary  # obținem conturul poligonului

    # Dacă este un simplu LineString (de obicei la poligoane simple)
    if boundary.geom_type == "LineString":
        coords = list(boundary.coords)
        for i in range(len(coords) - 1):
            seg = normalize_segment(coords[i], coords[i+1])
            segment_dict[seg].append((name, code))
    # Dacă este un MultiLineString (poligoane cu găuri sau compuse)
    elif boundary.geom_type == "MultiLineString":
        for part in boundary.geoms:
            coords = list(part.coords)
            for i in range(len(coords) - 1):
                seg = normalize_segment(coords[i], coords[i+1])
                segment_dict[seg].append((name, code))

# === Grupăm segmentele după perechea de vecini (unul sau doi) ===
# cheia = (vecin1, vecin2), valoarea = listă de geometrii LineString
neighbor_segments = defaultdict(list)

for (p1, p2), neighbors in segment_dict.items():
    geom = LineString([p1, p2])  # recreăm geometria segmentului

    if len(neighbors) == 1:
        # limită exterioară – un singur vecin
        key = (neighbors[0], None)
    elif len(neighbors) == 2:
        # frontieră între două regiuni – sortăm pentru consistență
        key = tuple(sorted(neighbors))
    else:
        # segment partajat de mai mult de două regiuni – invalid topologic
        continue

    neighbor_segments[key].append(geom)

# === Creăm fișierul de ieșire GeoPackage ===
driver = ogr.GetDriverByName("GPKG")
driver.DeleteDataSource(output_file)  # ștergem fișierul anterior dacă există
out_ds = driver.CreateDataSource(output_file)

# Definim sistemul de coordonate EPSG:3844 (Stereo 70 – România)
srs = ogr.osr.SpatialReference()
srs.ImportFromEPSG(3844)

# Cream layerul de tip MultiLineString cu CRS specificat
out_layer = out_ds.CreateLayer(output_layer_name, srs, geom_type=ogr.wkbMultiLineString)

# Adăugăm câmpurile care vor conține informații despre vecini
out_layer.CreateField(ogr.FieldDefn("leftName", ogr.OFTString))  # numele regiunii din stânga
out_layer.CreateField(ogr.FieldDefn("leftId", ogr.OFTInteger))   # id-ul regiunii din stânga
out_layer.CreateField(ogr.FieldDefn("rightName", ogr.OFTString)) # numele regiunii din dreapta
out_layer.CreateField(ogr.FieldDefn("rightId", ogr.OFTInteger))  # id-ul regiunii din dreapta

# === Scriem segmentele dizolvate în funcție de perechea de vecini ===
for (left, right), seg_list in neighbor_segments.items():
    multi = unary_union(seg_list)  # dizolvăm segmentele cu aceiași vecini

    if multi.is_empty:
        continue

    feat = ogr.Feature(out_layer.GetLayerDefn())
    if left:
        feat.SetField("leftName", left[0])
        feat.SetField("leftId", left[1])
    if right:
        feat.SetField("rightName", right[0])
        feat.SetField("rightId", right[1])

    geom = ogr.CreateGeometryFromWkb(multi.wkb)
    feat.SetGeometry(geom)
    out_layer.CreateFeature(feat)
    feat = None

# === Închidem fișierele ===
out_ds = None
source = None

print(f"✅ Fișierul '{output_file}' a fost generat corect.")
