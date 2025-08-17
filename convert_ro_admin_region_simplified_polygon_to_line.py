import json
from collections import defaultdict
from osgeo import ogr
from shapely.geometry import shape, LineString
from shapely.ops import unary_union

# Activăm excepțiile pentru debugare
ogr.UseExceptions()

# === CONFIGURARE ===
input_file = "/storage/volumes/geoserver-1-storage/administrative_boundaries/region/ro_admin_region_simplified_polygon.gpkg"
input_layer_name = "ro_admin_region_simplified_polygon"
field_name_name = "name"
field_name_id = "regionCode"
output_file = "/storage/volumes/geoserver-1-storage/administrative_boundaries/region/ro_admin_region_simplified_line_tmp.gpkg"
output_layer_name = "ro_admin_region_simplified_line_tmp"

# === Citim poligoanele și preluăm valoarea version ===
source = ogr.Open(input_file)
layer = source.GetLayerByName(input_layer_name)
features = list(layer)

# Preluăm valoarea 'version' din primul poligon (identică în toate)
version_value = features[0].GetField("version")

# Dicționar cu segmentele normalizate și vecinii lor
segment_dict = defaultdict(list)

def normalize_segment(p1, p2):
    return (p1, p2) if p1 <= p2 else (p2, p1)

for feat in features:
    geom = shape(json.loads(feat.geometry().ExportToJson()))
    name = feat.GetField(field_name_name)
    code = feat.GetField(field_name_id)
    boundary = geom.boundary

    if boundary.geom_type == "LineString":
        coords = list(boundary.coords)
        for i in range(len(coords) - 1):
            seg = normalize_segment(coords[i], coords[i + 1])
            segment_dict[seg].append((name, code))
    elif boundary.geom_type == "MultiLineString":
        for part in boundary.geoms:
            coords = list(part.coords)
            for i in range(len(coords) - 1):
                seg = normalize_segment(coords[i], coords[i + 1])
                segment_dict[seg].append((name, code))

# Grupăm segmentele după perechi de vecini
neighbor_segments = defaultdict(list)

for (p1, p2), neighbors in segment_dict.items():
    geom = LineString([p1, p2])
    if len(neighbors) == 1:
        key = (neighbors[0], None)
    elif len(neighbors) == 2:
        key = tuple(sorted(neighbors))
    else:
        continue
    neighbor_segments[key].append(geom)

# === Creăm fișierul GeoPackage de ieșire ===
driver = ogr.GetDriverByName("GPKG")
driver.DeleteDataSource(output_file)
out_ds = driver.CreateDataSource(output_file)

srs = ogr.osr.SpatialReference()
srs.ImportFromEPSG(3844)

out_layer = out_ds.CreateLayer(output_layer_name, srs, geom_type=ogr.wkbMultiLineString)

# Cîmpuri: vecini + version
out_layer.CreateField(ogr.FieldDefn("leftRegion", ogr.OFTString))
out_layer.CreateField(ogr.FieldDefn("leftId", ogr.OFTInteger))
out_layer.CreateField(ogr.FieldDefn("rightRegion", ogr.OFTString))
out_layer.CreateField(ogr.FieldDefn("rightId", ogr.OFTInteger))

# Notă: câmpul 'version' este salvat ca text (nu OFTDate), deoarece:
# - ogr + GPKG nu salvează corect valorile OFTDate din Python
# - varianta string este stabilă, vizibilă și portabilă
out_layer.CreateField(ogr.FieldDefn("version", ogr.OFTString))

# Scriem segmentele cu atribute
for (left, right), seg_list in neighbor_segments.items():
    multi = unary_union(seg_list)
    if multi.is_empty:
        continue

    feat = ogr.Feature(out_layer.GetLayerDefn())
    if left:
        feat.SetField("leftRegion", left[0])
        feat.SetField("leftId", left[1])
    if right:
        feat.SetField("rightRegion", right[0])
        feat.SetField("rightId", right[1])

    # Setăm valoarea version ca șir (ex: '2025-01-01')
    feat.SetField("version", str(version_value))

    geom = ogr.CreateGeometryFromWkb(multi.wkb)
    feat.SetGeometry(geom)
    out_layer.CreateFeature(feat)
    feat = None

# Finalizăm
out_ds = None
source = None

print(f"✅ Fișierul '{output_file}' a fost generat cu succes.")
